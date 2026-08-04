import crypto from 'node:crypto';

import { db, row } from '../db.js';

const SESSION_DAYS = 7;

/**
 * scrypt via node:crypto — no native dependency, and the salt travels with the
 * hash so verification needs nothing else stored.
 */
export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

export function verifyPassword(password, stored) {
  const [scheme, salt, expected] = String(stored ?? '').split('$');
  if (scheme !== 'scrypt' || !salt || !expected) return false;
  const actual = crypto.scryptSync(password, salt, 64).toString('hex');
  const a = Buffer.from(actual, 'hex');
  const b = Buffer.from(expected, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const findAdminByEmail = db.prepare('SELECT * FROM admins WHERE lower(email) = lower(?)');
const findAdminById = db.prepare('SELECT * FROM admins WHERE id = ?');
const insertSession = db.prepare(
  'INSERT INTO admin_sessions (token, admin_id, expires_at) VALUES (?, ?, ?)'
);
const findSession = db.prepare('SELECT * FROM admin_sessions WHERE token = ?');
const deleteSession = db.prepare('DELETE FROM admin_sessions WHERE token = ?');
const purgeExpired = db.prepare("DELETE FROM admin_sessions WHERE datetime(expires_at) < datetime('now')");
const touchLogin = db.prepare("UPDATE admins SET last_login_at = datetime('now') WHERE id = ?");
const countAdmins = db.prepare('SELECT COUNT(*) AS c FROM admins');
const insertAdmin = db.prepare(
  'INSERT INTO admins (email, name, password_hash, role) VALUES (?, ?, ?, ?)'
);

/**
 * Creates the first administrator on an empty install.
 *
 * With no ADMIN_PASSWORD set, a random one is generated and printed once to the
 * server log. A hard-coded default would be public knowledge the moment the
 * repository is — this cannot be guessed, and only whoever can read the deploy
 * logs ever sees it.
 */
export function ensureBootstrapAdmin() {
  if ((row(countAdmins)?.c ?? 0) > 0) return syncOwnerPassword();

  const email = process.env.ADMIN_EMAIL ?? 'admin@panchshil.com';
  const generated = !process.env.ADMIN_PASSWORD;
  const password = process.env.ADMIN_PASSWORD ?? crypto.randomBytes(9).toString('base64url');

  insertAdmin.run(email, 'Administrator', hashPassword(password), 'owner');

  console.log('');
  console.log('  Created the first admin account for /admin');
  console.log(`    email:    ${email}`);
  if (generated) {
    console.log(`    password: ${password}`);
    console.log('    This is shown once. Set ADMIN_PASSWORD to choose your own.');
  } else {
    console.log('    password: taken from ADMIN_PASSWORD');
  }
  console.log('');

  return { email, generated };
}

const findOwner = db.prepare("SELECT * FROM admins WHERE role = 'owner' ORDER BY id LIMIT 1");
const updatePassword = db.prepare('UPDATE admins SET password_hash = ? WHERE id = ?');

/**
 * Lets ADMIN_PASSWORD act as a recovery path once the account exists: set it in
 * the host's environment, redeploy, and the owner password becomes that value.
 * Only somebody who already controls the deployment can do this.
 */
function syncOwnerPassword() {
  const desired = process.env.ADMIN_PASSWORD;
  if (!desired) return null;

  const owner = row(findOwner);
  if (!owner || verifyPassword(desired, owner.password_hash)) return null;

  updatePassword.run(hashPassword(desired), owner.id);
  console.log(`  Owner password reset from ADMIN_PASSWORD for ${owner.email}`);
  return { email: owner.email, reset: true };
}

export function login(email, password) {
  const admin = row(findAdminByEmail, String(email ?? '').trim());
  if (!admin || !verifyPassword(String(password ?? ''), admin.password_hash)) return null;

  purgeExpired.run();
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 86_400_000).toISOString();
  insertSession.run(token, admin.id, expiresAt);
  touchLogin.run(admin.id);

  return { token, expiresAt, admin: publicAdmin(admin) };
}

export function logout(token) {
  if (token) deleteSession.run(token);
}

export const publicAdmin = (a) => ({
  id: a.id,
  email: a.email,
  name: a.name,
  role: a.role,
  last_login_at: a.last_login_at,
});

const readToken = (req) => {
  const header = req.get('authorization');
  if (header?.startsWith('Bearer ')) return header.slice(7);
  return req.get('x-admin-token') ?? null;
};

export function requireAdmin(req, res, next) {
  const token = readToken(req);
  if (!token) {
    return res.status(401).json({ success: false, message: 'Sign in to continue.' });
  }

  const session = row(findSession, token);
  if (!session) {
    return res.status(401).json({ success: false, message: 'Sign in to continue.' });
  }
  if (new Date(session.expires_at) < new Date()) {
    deleteSession.run(token);
    return res.status(401).json({ success: false, message: 'Your session expired. Sign in again.' });
  }

  const admin = row(findAdminById, session.admin_id);
  if (!admin) {
    return res.status(401).json({ success: false, message: 'This account no longer exists.' });
  }

  req.admin = admin;
  req.adminToken = token;
  next();
}
