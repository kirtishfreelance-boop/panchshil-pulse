import { query } from './db.js';

/**
 * Creates the schema if it is missing.
 *
 * Every statement is idempotent, so this runs on every boot and doubles as the
 * migration path — a new column added here appears on the next deploy without
 * anything being dropped.
 */
export async function ensureSchema() {
  await query(`
CREATE TABLE IF NOT EXISTS sites (
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  city          TEXT,
  address       TEXT,
  logo_url      TEXT,
  active        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS users (
  id             SERIAL PRIMARY KEY,
  firstname      TEXT,
  lastname       TEXT,
  email          TEXT UNIQUE,
  mobile         TEXT NOT NULL UNIQUE,
  country_code   TEXT NOT NULL DEFAULT '+91',
  gender         TEXT,
  company_name   TEXT,
  designation    TEXT,
  profile_image  TEXT,
  site_id        INTEGER REFERENCES sites(id) ON DELETE SET NULL,
  registered     BOOLEAN NOT NULL DEFAULT FALSE,
  wallet_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
  loyalty_points INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_sites (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  site_id INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, site_id)
);

CREATE TABLE IF NOT EXISTS otps (
  id         SERIAL PRIMARY KEY,
  mobile     TEXT NOT NULL,
  code       TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_otps_mobile ON otps (mobile, id DESC);

CREATE TABLE IF NOT EXISTS event_categories (
  id      SERIAL PRIMARY KEY,
  name    TEXT NOT NULL,
  icon    TEXT,
  site_id INTEGER REFERENCES sites(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS events (
  id          SERIAL PRIMARY KEY,
  site_id     INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES event_categories(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  description TEXT,
  venue       TEXT,
  cover_image TEXT,
  starts_at   TIMESTAMPTZ NOT NULL,
  ends_at     TIMESTAMPTZ,
  rsvp_by     TIMESTAMPTZ,
  is_paid     BOOLEAN NOT NULL DEFAULT FALSE,
  amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  capacity    INTEGER NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'published',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_site_start ON events (site_id, starts_at);

CREATE TABLE IF NOT EXISTS event_registrations (
  id             SERIAL PRIMARY KEY,
  event_id       INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  guests         INTEGER NOT NULL DEFAULT 0,
  amount_paid    NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  ticket_code    TEXT NOT NULL UNIQUE,
  attended       BOOLEAN NOT NULL DEFAULT FALSE,
  attended_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (event_id, user_id)
);

CREATE TABLE IF NOT EXISTS user_calendars (
  id       SERIAL PRIMARY KEY,
  user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  UNIQUE (user_id, event_id)
);

CREATE TABLE IF NOT EXISTS noticeboards (
  id           SERIAL PRIMARY KEY,
  site_id      INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  body         TEXT,
  cover_image  TEXT,
  category     TEXT,
  expires_at   TIMESTAMPTZ,
  is_important BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS communities (
  id            SERIAL PRIMARY KEY,
  site_id       INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  cover_image   TEXT,
  category      TEXT,
  members_count INTEGER NOT NULL DEFAULT 0,
  trending      BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS community_members (
  id           SERIAL PRIMARY KEY,
  community_id INTEGER NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role         TEXT NOT NULL DEFAULT 'member',
  status       TEXT NOT NULL DEFAULT 'approved',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (community_id, user_id)
);

CREATE TABLE IF NOT EXISTS posts (
  id           SERIAL PRIMARY KEY,
  community_id INTEGER REFERENCES communities(id) ON DELETE CASCADE,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body         TEXT NOT NULL,
  image_url    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS comments (
  id         SERIAL PRIMARY KEY,
  post_id    INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS like_things (
  id            SERIAL PRIMARY KEY,
  likeable_type TEXT NOT NULL,
  likeable_id   INTEGER NOT NULL,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction      TEXT NOT NULL DEFAULT 'heart',
  UNIQUE (likeable_type, likeable_id, user_id)
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id         SERIAL PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount     NUMERIC(12,2) NOT NULL,
  kind       TEXT NOT NULL,
  note       TEXT,
  reference  TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS service_categories (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  icon         TEXT,
  route        TEXT,
  service_tag  TEXT,
  position     INTEGER NOT NULL DEFAULT 0,
  active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS admins (
  id            SERIAL PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  name          TEXT,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'admin',
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_sessions (
  token      TEXT PRIMARY KEY,
  admin_id   INTEGER NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Amenities ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS facility_categories (
  id       SERIAL PRIMARY KEY,
  site_id  INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  name     TEXT NOT NULL,
  icon     TEXT,
  -- 'bookable' takes a time slot; 'requestable' is a request the estate team fulfils.
  fac_type TEXT NOT NULL DEFAULT 'bookable',
  position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS facilities (
  id             SERIAL PRIMARY KEY,
  site_id        INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  category_id    INTEGER REFERENCES facility_categories(id) ON DELETE SET NULL,
  name           TEXT NOT NULL,
  description    TEXT,
  location       TEXT,
  cover_image    TEXT,
  capacity       INTEGER NOT NULL DEFAULT 0,
  -- Local wall-clock opening hours, e.g. 06:00 to 22:00.
  opens_at       TIME NOT NULL DEFAULT '06:00',
  closes_at      TIME NOT NULL DEFAULT '22:00',
  slot_minutes   INTEGER NOT NULL DEFAULT 60,
  price_per_slot NUMERIC(12,2) NOT NULL DEFAULT 0,
  max_per_user   INTEGER NOT NULL DEFAULT 2,
  active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS facility_bookings (
  id          SERIAL PRIMARY KEY,
  facility_id INTEGER NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  starts_at   TIMESTAMPTZ NOT NULL,
  ends_at     TIMESTAMPTZ NOT NULL,
  status      TEXT NOT NULL DEFAULT 'confirmed',
  amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_bookings_facility_time
  ON facility_bookings (facility_id, starts_at);

-- Documents ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS document_folders (
  id          SERIAL PRIMARY KEY,
  site_id     INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  position    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS documents (
  id          SERIAL PRIMARY KEY,
  site_id     INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  folder_id   INTEGER REFERENCES document_folders(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT,
  file_url    TEXT NOT NULL,
  file_type   TEXT,
  size_kb     INTEGER NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- SOS directory -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS sos_contacts (
  id        SERIAL PRIMARY KEY,
  site_id   INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  role      TEXT,
  phone     TEXT NOT NULL,
  category  TEXT NOT NULL DEFAULT 'Emergency',
  -- Shown first and highlighted, for police/fire/ambulance style entries.
  is_urgent BOOLEAN NOT NULL DEFAULT FALSE,
  position  INTEGER NOT NULL DEFAULT 0
);
`);
}

/**
 * Sequences created by SERIAL do not know about rows inserted with an explicit
 * id, so the seed's fixed ids would collide with the first generated one.
 */
export async function resyncSequences() {
  const tables = [
    'sites', 'users', 'event_categories', 'events', 'event_registrations',
    'user_calendars', 'noticeboards', 'communities', 'community_members',
    'posts', 'comments', 'like_things', 'wallet_transactions',
    'service_categories', 'admins', 'otps',
    'facility_categories', 'facilities', 'facility_bookings',
    'document_folders', 'documents', 'sos_contacts',
  ];
  for (const table of tables) {
    await query(
      `SELECT setval(pg_get_serial_sequence('${table}', 'id'),
                     COALESCE((SELECT MAX(id) FROM ${table}), 0) + 1,
                     false)`
    );
  }
}
