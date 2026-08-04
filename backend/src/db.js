import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const localPath = path.join(here, '..', 'pulse.db');

/**
 * PULSE_DB points the database at a mounted persistent disk in production.
 *
 * The same blueprint is used on plans that do not include a disk, where that
 * mount point does not exist. Rather than refuse to boot, fall back to the
 * container filesystem — the data will not survive a redeploy, but the service
 * comes up and says so.
 */
function resolveDbPath() {
  const configured = process.env.PULSE_DB;
  if (!configured) return localPath;

  const dir = path.dirname(configured);
  try {
    fs.mkdirSync(dir, { recursive: true });
    fs.accessSync(dir, fs.constants.W_OK);
    return configured;
  } catch {
    console.warn(
      `PULSE_DB is set to ${configured} but ${dir} is not writable — ` +
        'falling back to ephemeral storage. Attach a disk to keep data across deploys.'
    );
    return localPath;
  }
}

const dbPath = resolveDbPath();
console.log(`Database: ${dbPath}`);

export const db = new DatabaseSync(dbPath);

db.exec('PRAGMA journal_mode = WAL');
db.exec('PRAGMA foreign_keys = ON');

/// The schema mirrors the resource shapes the Pulse client expects: sites own
/// almost everything, and a user is scoped to one active site at a time.
db.exec(`
CREATE TABLE IF NOT EXISTS sites (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  city TEXT,
  address TEXT,
  logo_url TEXT,
  active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  firstname TEXT,
  lastname TEXT,
  email TEXT UNIQUE,
  mobile TEXT NOT NULL UNIQUE,
  country_code TEXT NOT NULL DEFAULT '+91',
  gender TEXT,
  company_name TEXT,
  designation TEXT,
  profile_image TEXT,
  site_id INTEGER REFERENCES sites(id),
  registered INTEGER NOT NULL DEFAULT 0,
  wallet_balance REAL NOT NULL DEFAULT 0,
  loyalty_points INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS user_sites (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  site_id INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, site_id)
);

CREATE TABLE IF NOT EXISTS otps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mobile TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_otps_mobile ON otps (mobile, id DESC);

CREATE TABLE IF NOT EXISTS event_categories (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT,
  site_id INTEGER REFERENCES sites(id)
);

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY,
  site_id INTEGER NOT NULL REFERENCES sites(id),
  category_id INTEGER REFERENCES event_categories(id),
  title TEXT NOT NULL,
  description TEXT,
  venue TEXT,
  cover_image TEXT,
  starts_at TEXT NOT NULL,
  ends_at TEXT,
  rsvp_by TEXT,
  is_paid INTEGER NOT NULL DEFAULT 0,
  amount REAL NOT NULL DEFAULT 0,
  capacity INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'published',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS event_registrations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  guests INTEGER NOT NULL DEFAULT 0,
  amount_paid REAL NOT NULL DEFAULT 0,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  ticket_code TEXT NOT NULL,
  attended INTEGER NOT NULL DEFAULT 0,
  attended_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (event_id, user_id)
);

CREATE TABLE IF NOT EXISTS user_calendars (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  UNIQUE (user_id, event_id)
);

CREATE TABLE IF NOT EXISTS noticeboards (
  id INTEGER PRIMARY KEY,
  site_id INTEGER NOT NULL REFERENCES sites(id),
  title TEXT NOT NULL,
  body TEXT,
  cover_image TEXT,
  category TEXT,
  expires_at TEXT,
  is_important INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS communities (
  id INTEGER PRIMARY KEY,
  site_id INTEGER NOT NULL REFERENCES sites(id),
  name TEXT NOT NULL,
  description TEXT,
  cover_image TEXT,
  category TEXT,
  members_count INTEGER NOT NULL DEFAULT 0,
  trending INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS community_members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  community_id INTEGER NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  status TEXT NOT NULL DEFAULT 'approved',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (community_id, user_id)
);

CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY,
  community_id INTEGER REFERENCES communities(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  body TEXT NOT NULL,
  image_url TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  body TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS like_things (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  likeable_type TEXT NOT NULL,
  likeable_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction TEXT NOT NULL DEFAULT 'heart',
  UNIQUE (likeable_type, likeable_id, user_id)
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount REAL NOT NULL,
  kind TEXT NOT NULL,
  note TEXT,
  reference TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'admin',
  last_login_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS admin_sessions (
  token TEXT PRIMARY KEY,
  admin_id INTEGER NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS service_categories (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT,
  route TEXT,
  service_tag TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1
);
`);

/**
 * Adds columns that later versions introduced. `CREATE TABLE IF NOT EXISTS`
 * leaves an existing table untouched, so a deployed database needs this to
 * pick up new fields without being wiped.
 */
function addColumnIfMissing(table, column, definition) {
  const existing = db.prepare(`PRAGMA table_info(${table})`).all();
  if (existing.some((c) => c.name === column)) return;
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
  console.log(`Migration: added ${table}.${column}`);
}

// SQLite refuses a non-constant DEFAULT in ALTER TABLE, so backfill instead.
addColumnIfMissing('otps', 'created_at', 'TEXT');
db.exec("UPDATE otps SET created_at = datetime('now') WHERE created_at IS NULL");

/** Rows come back as null-prototype objects; spread them into plain ones. */
export const rows = (stmt, ...args) => stmt.all(...args).map((r) => ({ ...r }));
export const row = (stmt, ...args) => {
  const r = stmt.get(...args);
  return r ? { ...r } : null;
};
