import crypto from 'node:crypto';

import { one, query } from '../db.js';

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

/**
 * Creates the first administrator on an empty install.
 *
 * With no ADMIN_PASSWORD set, a random one is generated and printed once to the
 * server log. A hard-coded default would be public knowledge the moment the
 * repository is — this cannot be guessed, and only whoever can read the deploy
 * logs ever sees it.
 *
 * When the account already exists, ADMIN_PASSWORD acts as a recovery path: set
 * it in the host's environment, redeploy, and the owner password becomes that
 * value. Only somebody who already controls the deployment can do this.
 */
export async function ensureBootstrapAdmin() {
  const count = await one('SELECT COUNT(*)::int AS c FROM admins');
  if ((count?.c ?? 0) > 0) return syncOwnerPassword();

  const email = process.env.ADMIN_EMAIL ?? 'admin@panchshil.com';
  const generated = !process.env.ADMIN_PASSWORD;
  const password = process.env.ADMIN_PASSWORD ?? crypto.randomBytes(9).toString('base64url');

  await query(
    "INSERT INTO admins (email, name, password_hash, role) VALUES ($1, $2, $3, 'owner')",
    [email, 'Administrator', hashPassword(password)]
  );

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

async function syncOwnerPassword() {
  const desired = process.env.ADMIN_PASSWORD;
  if (!desired) return null;

  const owner = await one("SELECT * FROM admins WHERE role = 'owner' ORDER BY id LIMIT 1");
  if (!owner || verifyPassword(desired, owner.password_hash)) return null;

  await query('UPDATE admins SET password_hash = $1 WHERE id = $2', [
    hashPassword(desired),
    owner.id,
  ]);
  console.log(`  Owner password reset from ADMIN_PASSWORD for ${owner.email}`);
  return { email: owner.email, reset: true };
}

export async function login(email, password) {
  const admin = await one('SELECT * FROM admins WHERE lower(email) = lower($1)', [
    String(email ?? '').trim(),
  ]);
  if (!admin || !verifyPassword(String(password ?? ''), admin.password_hash)) return null;

  await query('DELETE FROM admin_sessions WHERE expires_at < NOW()');

  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 86_400_000).toISOString();
  await query('INSERT INTO admin_sessions (token, admin_id, expires_at) VALUES ($1, $2, $3)', [
    token,
    admin.id,
    expiresAt,
  ]);
  await query('UPDATE admins SET last_login_at = NOW() WHERE id = $1', [admin.id]);

  return { token, expiresAt, admin: publicAdmin(admin) };
}

export async function logout(token) {
  if (token) await query('DELETE FROM admin_sessions WHERE token = $1', [token]);
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

export async function requireAdmin(req, res, next) {
  const token = readToken(req);
  if (!token) {
    return res.status(401).json({ success: false, message: 'Sign in to continue.' });
  }

  try {
    const session = await one('SELECT * FROM admin_sessions WHERE token = $1', [token]);
    if (!session) {
      return res.status(401).json({ success: false, message: 'Sign in to continue.' });
    }
    if (new Date(session.expires_at) < new Date()) {
      await query('DELETE FROM admin_sessions WHERE token = $1', [token]);
      return res
        .status(401)
        .json({ success: false, message: 'Your session expired. Sign in again.' });
    }

    const admin = await one('SELECT * FROM admins WHERE id = $1', [session.admin_id]);
    if (!admin) {
      return res.status(401).json({ success: false, message: 'This account no longer exists.' });
    }

    req.admin = admin;
    req.adminToken = token;
    next();
  } catch (err) {
    next(err);
  }
}
