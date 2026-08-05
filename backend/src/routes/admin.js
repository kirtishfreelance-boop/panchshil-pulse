import { Router } from 'express';

import { affected, many, one, query } from '../db.js';
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

router.post('/admin/api/login', async (req, res, next) => {
  try {
    const result = await login(req.body?.email, req.body?.password);
    if (!result) {
      return res.status(401).json({ success: false, message: 'Wrong email or password.' });
    }
    res.json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
});

router.post('/admin/api/logout', requireAdmin, async (req, res, next) => {
  try {
    await logout(req.adminToken);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

router.get('/admin/api/me', requireAdmin, (req, res) => {
  res.json({ success: true, admin: publicAdmin(req.admin) });
});

// Everything past this point requires a signed-in administrator.
router.use('/admin/api', requireAdmin);

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

router.get('/admin/api/dashboard', async (_req, res, next) => {
  try {
    const stats = await one(`
      SELECT
        (SELECT COUNT(*)::int FROM users)                             AS users,
        (SELECT COUNT(*)::int FROM events)                            AS events,
        (SELECT COUNT(*)::int FROM events
          WHERE COALESCE(ends_at, starts_at) >= NOW())                AS upcoming,
        (SELECT COUNT(*)::int FROM noticeboards)                      AS notices,
        (SELECT COUNT(*)::int FROM communities)                       AS communities,
        (SELECT COUNT(*)::int FROM posts)                             AS posts,
        (SELECT COUNT(*)::int FROM event_registrations)               AS registrations,
        (SELECT COUNT(*)::int FROM event_registrations
          WHERE attended = TRUE)                                      AS attended,
        (SELECT COALESCE(SUM(amount_paid), 0) FROM event_registrations) AS revenue
    `);

    const recent = await many(`
      SELECT r.id, r.created_at, r.guests, r.amount_paid, r.payment_status,
             r.attended, r.ticket_code,
             e.title AS event_title, u.firstname, u.lastname, u.mobile
        FROM event_registrations r
        JOIN events e ON e.id = r.event_id
        JOIN users u ON u.id = r.user_id
       ORDER BY r.id DESC LIMIT 15
    `);

    const signups = await many(`
      SELECT created_at::date AS day, COUNT(*)::int AS c
        FROM users WHERE created_at >= NOW() - INTERVAL '30 days'
       GROUP BY created_at::date ORDER BY day
    `);

    res.json({ success: true, stats, recent_registrations: recent, signups_by_day: signups });
  } catch (err) {
    next(err);
  }
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
    timestamps: ['starts_at', 'ends_at', 'rsvp_by'],
  },
  noticeboards: {
    table: 'noticeboards',
    order: 'is_important DESC, created_at DESC',
    columns: ['site_id', 'title', 'body', 'cover_image', 'category', 'expires_at', 'is_important'],
    required: ['title'],
    booleans: ['is_important'],
    numbers: ['site_id'],
    timestamps: ['expires_at'],
  },
  communities: {
    table: 'communities',
    order: 'name',
    columns: ['site_id', 'name', 'description', 'cover_image', 'category', 'trending'],
    required: ['name'],
    booleans: ['trending'],
    numbers: ['site_id'],
    timestamps: [],
  },
  sites: {
    table: 'sites',
    order: 'name',
    columns: ['name', 'city', 'address', 'logo_url', 'active'],
    required: ['name'],
    booleans: ['active'],
    numbers: [],
    timestamps: [],
  },
  event_categories: {
    table: 'event_categories',
    order: 'name',
    columns: ['name', 'icon', 'site_id'],
    required: ['name'],
    booleans: [],
    numbers: ['site_id'],
    timestamps: [],
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
    timestamps: [],
  },
  posts: {
    table: 'posts',
    order: 'id DESC',
    columns: ['community_id', 'user_id', 'body', 'image_url'],
    required: ['body', 'user_id'],
    booleans: [],
    numbers: ['community_id', 'user_id'],
    timestamps: [],
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
 * Columns the database refuses to hold NULL, read once on first use so a blank
 * form field can be dropped from the statement — letting the column default
 * apply on insert, and leaving it untouched on update.
 */
const notNullCache = new Map();

async function notNullColumns(specName, spec) {
  if (notNullCache.has(specName)) return notNullCache.get(specName);
  const rows = await many(
    `SELECT column_name FROM information_schema.columns
      WHERE table_name = $1 AND is_nullable = 'NO' AND column_name <> 'id'`,
    [spec.table]
  );
  const set = new Set(rows.map((r) => r.column_name));
  notNullCache.set(specName, set);
  return set;
}

/** Coerces incoming JSON into the shapes Postgres expects for this resource. */
async function coerce(specName, spec, body) {
  const required = await notNullColumns(specName, spec);
  const values = {};

  for (const col of spec.columns) {
    if (!(col in body)) continue;
    let value = body[col];

    if (spec.booleans.includes(col)) {
      value = value === true || value === 'true' || value === 1 || value === '1';
    } else if (spec.numbers.includes(col)) {
      const blank = value === '' || value === null || value === undefined;
      value = blank ? null : Number(value);
      if (Number.isNaN(value)) value = null;
    } else if (typeof value === 'string') {
      value = value.trim();
      if (value === '') value = null;
      // <input type="datetime-local"> sends "2026-08-16T10:00" with no zone.
      else if (spec.timestamps.includes(col)) value = new Date(value).toISOString();
    }

    // Never send null at a column that cannot take it.
    if (value === null && required.has(col)) continue;
    values[col] = value;
  }
  return values;
}

const missingFields = (spec, values, { partial }) =>
  spec.required.filter((f) => (partial ? f in values && !values[f] : !values[f]));

router.get('/admin/api/:resource', async (req, res, next) => {
  try {
    const spec = resourceOr404(req.params.resource, res);
    if (!spec) return;

    const search = String(req.query.q ?? '').trim();
    const limit = Math.min(500, Number(req.query.limit ?? 200));

    let sql = `SELECT * FROM ${spec.table}`;
    const params = [];

    if (search) {
      const textCols = spec.columns.filter(
        (c) => !spec.numbers.includes(c) && !spec.booleans.includes(c) && !spec.timestamps.includes(c)
      );
      if (textCols.length) {
        params.push(`%${search}%`);
        sql += ' WHERE ' + textCols.map((c) => `COALESCE(${c}, '') ILIKE $1`).join(' OR ');
      }
    }

    params.push(limit);
    sql += ` ORDER BY ${spec.order} LIMIT $${params.length}`;

    res.json({ success: true, records: await many(sql, params) });
  } catch (err) {
    next(err);
  }
});

router.post('/admin/api/:resource', async (req, res, next) => {
  try {
    const spec = resourceOr404(req.params.resource, res);
    if (!spec) return;

    const values = await coerce(req.params.resource, spec, req.body ?? {});
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

    const record = await one(
      `INSERT INTO ${spec.table} (${cols.join(', ')})
       VALUES (${cols.map((_, i) => `$${i + 1}`).join(', ')})
       RETURNING *`,
      cols.map((c) => values[c])
    );
    res.status(201).json({ success: true, record });
  } catch (err) {
    res.status(422).json({ success: false, message: friendlySqlError(err) });
  }
});

router.patch('/admin/api/:resource/:id', async (req, res, next) => {
  try {
    const spec = resourceOr404(req.params.resource, res);
    if (!spec) return;

    const values = await coerce(req.params.resource, spec, req.body ?? {});
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

    const record = await one(
      `UPDATE ${spec.table}
          SET ${cols.map((c, i) => `${c} = $${i + 1}`).join(', ')}
        WHERE id = $${cols.length + 1}
        RETURNING *`,
      [...cols.map((c) => values[c]), Number(req.params.id)]
    );
    if (!record) return res.status(404).json({ success: false, message: 'Record not found.' });
    res.json({ success: true, record });
  } catch (err) {
    res.status(422).json({ success: false, message: friendlySqlError(err) });
  }
});

router.delete('/admin/api/:resource/:id', async (req, res) => {
  const spec = resourceOr404(req.params.resource, res);
  if (!spec) return;
  try {
    const count = await affected(`DELETE FROM ${spec.table} WHERE id = $1`, [
      Number(req.params.id),
    ]);
    if (!count) return res.status(404).json({ success: false, message: 'Record not found.' });
    res.json({ success: true });
  } catch (err) {
    res.status(409).json({ success: false, message: friendlySqlError(err) });
  }
});

/** Turns Postgres constraint errors into something an administrator can act on. */
function friendlySqlError(err) {
  const humanise = (column) =>
    String(column ?? '')
      .replace(/_id$/, '')
      .split('_')
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(' ');

  switch (err?.code) {
    case '23502': // not_null_violation
      return `"${humanise(err.column)}" is required.`;
    case '23505': // unique_violation
      return 'Another record already uses that value.';
    case '23503': // foreign_key_violation
      return 'This record is still referenced elsewhere, or points at something that does not exist.';
    case '22P02': // invalid_text_representation
      return 'One of the values is not in the format this field expects.';
    default:
      return err?.message || 'Could not save that.';
  }
}

// ---------------------------------------------------------------------------
// Registrations — read-only list plus attendance control
// ---------------------------------------------------------------------------

router.get('/admin/api/events/:id/registrations', async (req, res, next) => {
  try {
    const registrations = await many(
      `SELECT r.*, u.firstname, u.lastname, u.mobile, u.email, u.company_name
         FROM event_registrations r
         JOIN users u ON u.id = r.user_id
        WHERE r.event_id = $1
        ORDER BY r.id DESC`,
      [Number(req.params.id)]
    );
    res.json({ success: true, registrations });
  } catch (err) {
    next(err);
  }
});

router.patch('/admin/api/registrations/:id/attendance', async (req, res, next) => {
  try {
    const attended = req.body?.attended === true || req.body?.attended === 'true';
    const count = await affected(
      `UPDATE event_registrations
          SET attended = $1, attended_at = CASE WHEN $1 THEN NOW() ELSE NULL END
        WHERE id = $2`,
      [attended, Number(req.params.id)]
    );
    if (!count) {
      return res.status(404).json({ success: false, message: 'Registration not found.' });
    }
    res.json({ success: true, attended });
  } catch (err) {
    next(err);
  }
});

router.delete('/admin/api/registrations/:id', async (req, res, next) => {
  try {
    const count = await affected('DELETE FROM event_registrations WHERE id = $1', [
      Number(req.params.id),
    ]);
    if (!count) {
      return res.status(404).json({ success: false, message: 'Registration not found.' });
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Administrators
// ---------------------------------------------------------------------------

router.get('/admin/api/team/list', async (_req, res, next) => {
  try {
    const admins = await many('SELECT * FROM admins ORDER BY id');
    res.json({ success: true, admins: admins.map(publicAdmin) });
  } catch (err) {
    next(err);
  }
});

router.post('/admin/api/team/invite', async (req, res) => {
  const email = String(req.body?.email ?? '').trim();
  const password = String(req.body?.password ?? '');
  if (!email || password.length < 8) {
    return res.status(422).json({
      success: false,
      message: 'Enter an email and a password of at least 8 characters.',
    });
  }
  try {
    await query(
      "INSERT INTO admins (email, name, password_hash, role) VALUES ($1, $2, $3, 'admin')",
      [email, String(req.body?.name ?? '').trim() || null, hashPassword(password)]
    );
    res.status(201).json({ success: true });
  } catch (err) {
    res.status(422).json({ success: false, message: friendlySqlError(err) });
  }
});

router.post('/admin/api/team/password', async (req, res, next) => {
  try {
    const password = String(req.body?.password ?? '');
    if (password.length < 8) {
      return res.status(422).json({
        success: false,
        message: 'Choose a password of at least 8 characters.',
      });
    }
    await query('UPDATE admins SET password_hash = $1 WHERE id = $2', [
      hashPassword(password),
      req.admin.id,
    ]);
    res.json({ success: true, message: 'Password changed.' });
  } catch (err) {
    next(err);
  }
});
