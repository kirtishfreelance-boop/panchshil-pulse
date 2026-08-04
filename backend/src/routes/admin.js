import { Router } from 'express';

import { db, row, rows } from '../db.js';
import {
  hashPassword,
  login,
  logout,
  publicAdmin,
  requireAdmin,
} from '../middleware/adminAuth.js';

export const router = Router();

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

router.post('/admin/api/login', (req, res) => {
  const result = login(req.body?.email, req.body?.password);
  if (!result) {
    return res.status(401).json({ success: false, message: 'Wrong email or password.' });
  }
  res.json({ success: true, ...result });
});

router.post('/admin/api/logout', requireAdmin, (req, res) => {
  logout(req.adminToken);
  res.json({ success: true });
});

router.get('/admin/api/me', requireAdmin, (req, res) => {
  res.json({ success: true, admin: publicAdmin(req.admin) });
});

// Everything past this point requires a signed-in administrator.
router.use('/admin/api', requireAdmin);

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

const counts = {
  users: db.prepare('SELECT COUNT(*) AS c FROM users'),
  events: db.prepare('SELECT COUNT(*) AS c FROM events'),
  upcoming: db.prepare(
    "SELECT COUNT(*) AS c FROM events WHERE COALESCE(ends_at, starts_at) >= datetime('now')"
  ),
  notices: db.prepare('SELECT COUNT(*) AS c FROM noticeboards'),
  communities: db.prepare('SELECT COUNT(*) AS c FROM communities'),
  posts: db.prepare('SELECT COUNT(*) AS c FROM posts'),
  registrations: db.prepare('SELECT COUNT(*) AS c FROM event_registrations'),
  attended: db.prepare('SELECT COUNT(*) AS c FROM event_registrations WHERE attended = 1'),
  revenue: db.prepare('SELECT COALESCE(SUM(amount_paid), 0) AS c FROM event_registrations'),
};

const recentRegistrations = db.prepare(`SELECT r.id, r.created_at, r.guests, r.amount_paid,
    r.payment_status, r.attended, r.ticket_code,
    e.title AS event_title, u.firstname, u.lastname, u.mobile
  FROM event_registrations r
  JOIN events e ON e.id = r.event_id
  JOIN users u ON u.id = r.user_id
  ORDER BY r.id DESC LIMIT 15`);

const signupsByDay = db.prepare(`SELECT date(created_at) AS day, COUNT(*) AS c
  FROM users WHERE created_at >= datetime('now', '-30 days')
  GROUP BY date(created_at) ORDER BY day`);

router.get('/admin/api/dashboard', (_req, res) => {
  const stats = {};
  for (const [key, stmt] of Object.entries(counts)) {
    stats[key] = row(stmt)?.c ?? 0;
  }
  res.json({
    success: true,
    stats,
    recent_registrations: rows(recentRegistrations),
    signups_by_day: rows(signupsByDay),
  });
});

// ---------------------------------------------------------------------------
// Generic resource plumbing
//
// Each resource declares its table and writable columns; the handlers below
// turn that into list / create / update / delete without repeating SQL.
// ---------------------------------------------------------------------------

const RESOURCES = {
  events: {
    table: 'events',
    order: 'starts_at DESC',
    columns: [
      'site_id', 'category_id', 'title', 'description', 'venue', 'cover_image',
      'starts_at', 'ends_at', 'rsvp_by', 'is_paid', 'amount', 'capacity', 'status',
    ],
    required: ['title', 'starts_at'],
    booleans: ['is_paid'],
    numbers: ['site_id', 'category_id', 'amount', 'capacity'],
  },
  noticeboards: {
    table: 'noticeboards',
    order: 'is_important DESC, created_at DESC',
    columns: ['site_id', 'title', 'body', 'cover_image', 'category', 'expires_at', 'is_important'],
    required: ['title'],
    booleans: ['is_important'],
    numbers: ['site_id'],
  },
  communities: {
    table: 'communities',
    order: 'name',
    columns: ['site_id', 'name', 'description', 'cover_image', 'category', 'trending'],
    required: ['name'],
    booleans: ['trending'],
    numbers: ['site_id'],
  },
  sites: {
    table: 'sites',
    order: 'name',
    columns: ['name', 'city', 'address', 'logo_url', 'active'],
    required: ['name'],
    booleans: ['active'],
    numbers: [],
  },
  event_categories: {
    table: 'event_categories',
    order: 'name',
    columns: ['name', 'icon', 'site_id'],
    required: ['name'],
    booleans: [],
    numbers: ['site_id'],
  },
  users: {
    table: 'users',
    order: 'id DESC',
    columns: [
      'firstname', 'lastname', 'email', 'mobile', 'country_code', 'gender',
      'company_name', 'designation', 'profile_image', 'site_id',
      'wallet_balance', 'loyalty_points',
    ],
    required: ['mobile'],
    booleans: [],
    numbers: ['site_id', 'wallet_balance', 'loyalty_points'],
  },
  posts: {
    table: 'posts',
    order: 'id DESC',
    columns: ['community_id', 'user_id', 'body', 'image_url'],
    required: ['body', 'user_id'],
    booleans: [],
    numbers: ['community_id', 'user_id'],
  },
};

const resourceOr404 = (name, res) => {
  const spec = RESOURCES[name];
  if (!spec) {
    res.status(404).json({ success: false, message: `Unknown resource "${name}".` });
    return null;
  }
  return spec;
};

/**
 * Columns the database refuses to hold NULL. Read once at startup so a blank
 * form field can be dropped from the statement — letting the column default
 * apply on insert, and leaving it untouched on update — instead of being sent
 * as null and rejected.
 */
const notNullColumns = new Map();
for (const [name, spec] of Object.entries(RESOURCES)) {
  const info = db.prepare(`PRAGMA table_info(${spec.table})`).all();
  notNullColumns.set(
    name,
    new Set(info.filter((c) => c.notnull === 1 && c.name !== 'id').map((c) => c.name))
  );
}

/** Coerces incoming JSON into the shapes SQLite expects for this resource. */
function coerce(specName, spec, body) {
  const required = notNullColumns.get(specName) ?? new Set();
  const values = {};

  for (const col of spec.columns) {
    if (!(col in body)) continue;
    let value = body[col];

    if (spec.booleans.includes(col)) {
      value = value === true || value === 'true' || value === 1 ? 1 : 0;
    } else if (spec.numbers.includes(col)) {
      const blank = value === '' || value === null || value === undefined;
      value = blank ? null : Number(value);
      if (Number.isNaN(value)) value = null;
    } else if (typeof value === 'string') {
      value = value.trim();
      if (value === '') value = null;
    }

    // Never send null at a column that cannot take it.
    if (value === null && required.has(col)) continue;
    values[col] = value;
  }
  return values;
}

const missingFields = (spec, values, { partial }) =>
  spec.required.filter((f) => (partial ? f in values && !values[f] : !values[f]));

router.get('/admin/api/:resource', (req, res) => {
  const spec = resourceOr404(req.params.resource, res);
  if (!spec) return;

  const search = String(req.query.q ?? '').trim();
  const limit = Math.min(500, Number(req.query.limit ?? 200));

  let sql = `SELECT * FROM ${spec.table}`;
  const params = [];

  if (search) {
    // Search across the resource's own text columns only.
    const textCols = spec.columns.filter(
      (c) => !spec.numbers.includes(c) && !spec.booleans.includes(c)
    );
    if (textCols.length) {
      sql += ' WHERE ' + textCols.map((c) => `COALESCE(${c}, '') LIKE ?`).join(' OR ');
      params.push(...textCols.map(() => `%${search}%`));
    }
  }

  sql += ` ORDER BY ${spec.order} LIMIT ?`;
  params.push(limit);

  res.json({ success: true, records: rows(db.prepare(sql), ...params) });
});

router.post('/admin/api/:resource', (req, res) => {
  const spec = resourceOr404(req.params.resource, res);
  if (!spec) return;

  const values = coerce(req.params.resource, spec, req.body ?? {});
  const missing = missingFields(spec, values, { partial: false });
  if (missing.length) {
    return res.status(422).json({
      success: false,
      message: `These fields are required: ${missing.join(', ')}.`,
    });
  }

  const cols = Object.keys(values);
  if (!cols.length) {
    return res.status(422).json({ success: false, message: 'Nothing to save.' });
  }

  const sql = `INSERT INTO ${spec.table} (${cols.join(', ')})
    VALUES (${cols.map(() => '?').join(', ')})`;

  try {
    const info = db.prepare(sql).run(...cols.map((c) => values[c]));
    const record = row(
      db.prepare(`SELECT * FROM ${spec.table} WHERE rowid = ?`),
      Number(info.lastInsertRowid)
    );
    res.status(201).json({ success: true, record });
  } catch (err) {
    res.status(422).json({ success: false, message: friendlySqlError(err) });
  }
});

router.patch('/admin/api/:resource/:id', (req, res) => {
  const spec = resourceOr404(req.params.resource, res);
  if (!spec) return;

  const values = coerce(req.params.resource, spec, req.body ?? {});
  const missing = missingFields(spec, values, { partial: true });
  if (missing.length) {
    return res.status(422).json({
      success: false,
      message: `These fields cannot be blank: ${missing.join(', ')}.`,
    });
  }

  const cols = Object.keys(values);
  if (!cols.length) {
    return res.status(422).json({ success: false, message: 'Nothing to update.' });
  }

  const sql = `UPDATE ${spec.table} SET ${cols.map((c) => `${c} = ?`).join(', ')} WHERE id = ?`;

  try {
    const info = db.prepare(sql).run(...cols.map((c) => values[c]), Number(req.params.id));
    if (info.changes === 0) {
      return res.status(404).json({ success: false, message: 'Record not found.' });
    }
    const record = row(
      db.prepare(`SELECT * FROM ${spec.table} WHERE id = ?`),
      Number(req.params.id)
    );
    res.json({ success: true, record });
  } catch (err) {
    res.status(422).json({ success: false, message: friendlySqlError(err) });
  }
});

router.delete('/admin/api/:resource/:id', (req, res) => {
  const spec = resourceOr404(req.params.resource, res);
  if (!spec) return;
  try {
    const info = db
      .prepare(`DELETE FROM ${spec.table} WHERE id = ?`)
      .run(Number(req.params.id));
    if (info.changes === 0) {
      return res.status(404).json({ success: false, message: 'Record not found.' });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(409).json({ success: false, message: friendlySqlError(err) });
  }
});

/** Turns SQLite constraint text into something an administrator can act on. */
function friendlySqlError(err) {
  const message = String(err?.message ?? '');

  const notNull = message.match(/NOT NULL constraint failed: \w+\.(\w+)/);
  if (notNull) return `"${humanise(notNull[1])}" is required.`;

  const unique = message.match(/UNIQUE constraint failed: \w+\.(\w+)/);
  if (unique) return `Another record already uses that ${humanise(unique[1]).toLowerCase()}.`;

  if (message.includes('FOREIGN KEY')) {
    return 'This record is still referenced elsewhere, or points at something that does not exist.';
  }
  return message || 'Could not save that.';
}

const humanise = (column) =>
  column
    .replace(/_id$/, '')
    .split('_')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');

// ---------------------------------------------------------------------------
// Registrations — read-only list plus attendance control
// ---------------------------------------------------------------------------

const registrationsForEvent = db.prepare(`SELECT r.*, u.firstname, u.lastname, u.mobile,
    u.email, u.company_name
  FROM event_registrations r JOIN users u ON u.id = r.user_id
  WHERE r.event_id = ? ORDER BY r.id DESC`);

router.get('/admin/api/events/:id/registrations', (req, res) => {
  res.json({
    success: true,
    registrations: rows(registrationsForEvent, Number(req.params.id)),
  });
});

const setAttendance = db.prepare(
  `UPDATE event_registrations
   SET attended = ?, attended_at = CASE WHEN ? = 1 THEN datetime('now') ELSE NULL END
   WHERE id = ?`
);

router.patch('/admin/api/registrations/:id/attendance', (req, res) => {
  const attended = req.body?.attended === true || req.body?.attended === 'true' ? 1 : 0;
  const info = setAttendance.run(attended, attended, Number(req.params.id));
  if (info.changes === 0) {
    return res.status(404).json({ success: false, message: 'Registration not found.' });
  }
  res.json({ success: true, attended: !!attended });
});

router.delete('/admin/api/registrations/:id', (req, res) => {
  const info = db
    .prepare('DELETE FROM event_registrations WHERE id = ?')
    .run(Number(req.params.id));
  if (info.changes === 0) {
    return res.status(404).json({ success: false, message: 'Registration not found.' });
  }
  res.json({ success: true });
});

// ---------------------------------------------------------------------------
// Administrators
// ---------------------------------------------------------------------------

const listAdmins = db.prepare('SELECT * FROM admins ORDER BY id');

router.get('/admin/api/team/list', (_req, res) => {
  res.json({ success: true, admins: rows(listAdmins).map(publicAdmin) });
});

router.post('/admin/api/team/invite', (req, res) => {
  const email = String(req.body?.email ?? '').trim();
  const password = String(req.body?.password ?? '');
  if (!email || password.length < 8) {
    return res.status(422).json({
      success: false,
      message: 'Enter an email and a password of at least 8 characters.',
    });
  }
  try {
    db.prepare('INSERT INTO admins (email, name, password_hash, role) VALUES (?, ?, ?, ?)').run(
      email,
      String(req.body?.name ?? '').trim() || null,
      hashPassword(password),
      'admin'
    );
    res.status(201).json({ success: true });
  } catch (err) {
    res.status(422).json({ success: false, message: friendlySqlError(err) });
  }
});

router.post('/admin/api/team/password', (req, res) => {
  const password = String(req.body?.password ?? '');
  if (password.length < 8) {
    return res.status(422).json({
      success: false,
      message: 'Choose a password of at least 8 characters.',
    });
  }
  db.prepare('UPDATE admins SET password_hash = ? WHERE id = ?').run(
    hashPassword(password),
    req.admin.id
  );
  res.json({ success: true, message: 'Password changed.' });
});
