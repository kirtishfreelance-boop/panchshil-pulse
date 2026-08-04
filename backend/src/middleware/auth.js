import jwt from 'jsonwebtoken';
import { db, row } from '../db.js';

export const JWT_SECRET = process.env.JWT_SECRET ?? 'pulse-dev-secret-change-me';
const TOKEN_TTL = '30d';

export const issueToken = (user) =>
  jwt.sign({ sub: user.id, mobile: user.mobile }, JWT_SECRET, { expiresIn: TOKEN_TTL });

const findUser = db.prepare('SELECT * FROM users WHERE id = ?');

/**
 * The Pulse client sends its token three different ways depending on the screen
 * it was built in, so accept all of them.
 */
const extractToken = (req) => {
  const header = req.get('authorization');
  if (header?.startsWith('Bearer ')) return header.slice(7);
  return req.query.token ?? req.body?.token ?? null;
};

export const authenticate = (req, res, next) => {
  const token = extractToken(req);
  if (!token) {
    return res.status(401).json({ success: false, message: 'Missing authentication token.' });
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const user = row(findUser, payload.sub);
    if (!user) {
      return res.status(401).json({ success: false, message: 'Account no longer exists.' });
    }
    req.user = user;
    req.token = token;
    next();
  } catch {
    return res.status(401).json({ success: false, message: 'Session expired. Please sign in again.' });
  }
};

/** Resolves the site the request is scoped to: explicit param wins, else the user's active site. */
export const currentSiteId = (req) => Number(req.query.site_id ?? req.body?.site_id ?? req.user?.site_id ?? 1);
