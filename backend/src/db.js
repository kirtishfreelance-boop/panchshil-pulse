import pg from 'pg';

const { Pool, types } = pg;

if (!process.env.DATABASE_URL) {
  console.error(
    'DATABASE_URL is not set. Point it at a Postgres database — Neon\'s free tier works:\n' +
      '  postgresql://user:password@host/dbname?sslmode=require'
  );
  process.exit(1);
}

/**
 * Return NUMERIC as a JavaScript number.
 *
 * node-postgres hands NUMERIC back as a string by default to protect precision
 * beyond 2^53. Money here is rupees with at most two decimals, so the loss of
 * range is irrelevant and the loss of type is not — every caller expects to do
 * arithmetic and JSON-serialise these.
 */
types.setTypeParser(types.builtins.NUMERIC, (value) => (value === null ? null : Number(value)));
types.setTypeParser(types.builtins.INT8, (value) => (value === null ? null : Number(value)));

/**
 * Timestamps are stored as `timestamptz` and read back as ISO-8601 UTC strings
 * rather than Date objects, which keeps the JSON payloads identical to what the
 * Flutter client already parses.
 */
const TIMESTAMPTZ_OID = 1184;
const TIMESTAMP_OID = 1114;
const toIso = (value) => (value === null ? null : new Date(value).toISOString());
types.setTypeParser(TIMESTAMPTZ_OID, toIso);
types.setTypeParser(TIMESTAMP_OID, toIso);

const connectionString = process.env.DATABASE_URL;

/** Neon and most hosted providers require TLS; a local server generally has none. */
const isLocal = /@(localhost|127\.0\.0\.1)/.test(connectionString);

export const pool = new Pool({
  connectionString,
  ssl: isLocal ? false : { rejectUnauthorized: false },
  // Neon's free tier caps connections, and Render free runs a single instance.
  max: Number(process.env.PG_POOL_MAX ?? 5),
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 15_000,
});

pool.on('error', (err) => {
  // A pooled connection dropped while idle. The pool replaces it; log and move on.
  console.error('Postgres pool error:', err.message);
});

/** Runs a statement and returns the full result. */
export const query = (text, params = []) => pool.query(text, params);

/** First row, or null. */
export async function one(text, params = []) {
  const { rows } = await pool.query(text, params);
  return rows[0] ?? null;
}

/** All rows. */
export async function many(text, params = []) {
  const { rows } = await pool.query(text, params);
  return rows;
}

/** Number of rows affected — used to turn a no-op UPDATE/DELETE into a 404. */
export async function affected(text, params = []) {
  const { rowCount } = await pool.query(text, params);
  return rowCount;
}

/** Runs `fn` inside a transaction on a single dedicated connection. */
export async function transaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export const closePool = () => pool.end();
