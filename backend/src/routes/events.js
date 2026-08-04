import { Router } from 'express';
import { db, row, rows } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';
import { eventJson } from '../serializers.js';

export const router = Router();

const upcoming = db.prepare(`SELECT * FROM events
  WHERE site_id = ? AND status = 'published' AND COALESCE(ends_at, starts_at) >= datetime('now')
  ORDER BY starts_at ASC LIMIT ? OFFSET ?`);
const past = db.prepare(`SELECT * FROM events
  WHERE site_id = ? AND status = 'published' AND COALESCE(ends_at, starts_at) < datetime('now')
  ORDER BY starts_at DESC LIMIT ? OFFSET ?`);
const byCategory = db.prepare(`SELECT * FROM events
  WHERE site_id = ? AND category_id = ? AND status = 'published' ORDER BY starts_at ASC`);
const findEvent = db.prepare('SELECT * FROM events WHERE id = ?');
const categories = db.prepare('SELECT * FROM event_categories ORDER BY id');
const inRange = db.prepare(`SELECT * FROM events
  WHERE site_id = ? AND status = 'published' AND date(starts_at) BETWEEN date(?) AND date(?)
  ORDER BY starts_at ASC`);

router.get('/pms/admin/events.json', authenticate, (req, res) => {
  const siteId = currentSiteId(req);
  const page = Math.max(1, Number(req.query.page ?? 1));
  const perPage = Math.min(50, Number(req.query.per_page ?? 20));
  const offset = (page - 1) * perPage;
  const list = req.query.past === 'true'
    ? rows(past, siteId, perPage, offset)
    : rows(upcoming, siteId, perPage, offset);

  res.json({
    success: true,
    page,
    per_page: perPage,
    events: list.map((e) => eventJson(e, req.user.id)),
  });
});

router.get('/pms/admin/events/categories.json', authenticate, (_req, res) => {
  res.json({ success: true, categories: rows(categories) });
});

router.get('/pms/admin/events/category_events.json', authenticate, (req, res) => {
  const siteId = currentSiteId(req);
  const categoryId = Number(req.query.category_id);
  if (!categoryId) {
    return res.status(422).json({ success: false, message: 'category_id is required.' });
  }
  res.json({
    success: true,
    events: rows(byCategory, siteId, categoryId).map((e) => eventJson(e, req.user.id)),
  });
});

router.get('/pms/admin/events/calendar_data.json', authenticate, (req, res) => {
  const siteId = currentSiteId(req);
  const from = req.query.from ?? new Date().toISOString().slice(0, 10);
  const to = req.query.to ?? new Date(Date.now() + 90 * 86_400_000).toISOString().slice(0, 10);
  const list = rows(inRange, siteId, from, to).map((e) => eventJson(e, req.user.id));

  // Grouped by day so the calendar screen can render dots without re-bucketing.
  const byDay = {};
  for (const e of list) {
    const key = e.starts_at.slice(0, 10);
    (byDay[key] ??= []).push(e);
  }
  res.json({ success: true, from, to, calendar_data: byDay });
});

const myRegistrations = db.prepare(`SELECT e.* FROM events e
  JOIN event_registrations r ON r.event_id = e.id
  WHERE r.user_id = ? ORDER BY e.starts_at DESC`);

// Must stay above the `:id.json` route below, or the param route swallows it.
router.get('/pms/admin/events/my_events.json', authenticate, (req, res) => {
  res.json({
    success: true,
    events: rows(myRegistrations, req.user.id).map((e) => eventJson(e, req.user.id)),
  });
});

router.get('/pms/admin/events/:id.json', authenticate, (req, res) => {
  const event = row(findEvent, Number(req.params.id));
  if (!event) return res.status(404).json({ success: false, message: 'Event not found.' });
  res.json({ success: true, event: eventJson(event, req.user.id) });
});

const findReg = db.prepare('SELECT * FROM event_registrations WHERE event_id = ? AND user_id = ?');
const insertReg = db.prepare(`INSERT INTO event_registrations
  (event_id, user_id, guests, amount_paid, payment_status, ticket_code)
  VALUES (?, ?, ?, ?, ?, ?)`);
const seatsUsed = db.prepare(
  'SELECT COUNT(*) AS c, COALESCE(SUM(guests), 0) AS g FROM event_registrations WHERE event_id = ?'
);
const debitWallet = db.prepare('UPDATE users SET wallet_balance = wallet_balance - ? WHERE id = ?');
const logTxn = db.prepare(
  "INSERT INTO wallet_transactions (user_id, amount, kind, note, reference) VALUES (?, ?, 'debit', ?, ?)"
);

const ticketCode = (eventId, userId) =>
  `PLS-${eventId}-${userId}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;

router.post('/pms/admin/events/:id/register.json', authenticate, (req, res) => {
  const event = row(findEvent, Number(req.params.id));
  if (!event) return res.status(404).json({ success: false, message: 'Event not found.' });
  if (row(findReg, event.id, req.user.id)) {
    return res.status(409).json({ success: false, message: 'You are already registered for this event.' });
  }
  if (new Date(event.ends_at ?? event.starts_at) < new Date()) {
    return res.status(422).json({ success: false, message: 'Registrations for this event have closed.' });
  }

  const guests = Math.max(0, Number(req.body?.guests ?? 0));
  const used = row(seatsUsed, event.id);
  const taken = (used?.c ?? 0) + (used?.g ?? 0);
  if (event.capacity > 0 && taken + 1 + guests > event.capacity) {
    return res.status(422).json({ success: false, message: 'Not enough seats left for that many guests.' });
  }

  const payable = event.is_paid ? event.amount * (1 + guests) : 0;
  const method = req.body?.payment_method ?? 'wallet';

  if (payable > 0 && method === 'wallet') {
    if (req.user.wallet_balance < payable) {
      return res.status(402).json({
        success: false,
        message: 'Insufficient wallet balance.',
        payable,
        wallet_balance: req.user.wallet_balance,
      });
    }
    debitWallet.run(payable, req.user.id);
    logTxn.run(req.user.id, -payable, event.title, `EVT-${event.id}`);
  }

  const code = ticketCode(event.id, req.user.id);
  insertReg.run(
    event.id,
    req.user.id,
    guests,
    payable,
    payable === 0 ? 'free' : method === 'wallet' ? 'paid' : 'pending',
    code
  );

  res.status(201).json({
    success: true,
    message: 'You are registered.',
    ticket_code: code,
    amount_paid: payable,
    event: eventJson(row(findEvent, event.id), req.user.id),
  });
});

const deleteReg = db.prepare('DELETE FROM event_registrations WHERE event_id = ? AND user_id = ?');

router.delete('/pms/admin/events/:id/register.json', authenticate, (req, res) => {
  const eventId = Number(req.params.id);
  const reg = row(findReg, eventId, req.user.id);
  if (!reg) return res.status(404).json({ success: false, message: 'You are not registered for this event.' });
  deleteReg.run(eventId, req.user.id);
  res.json({ success: true, message: 'Registration cancelled.' });
});

const findByTicket = db.prepare('SELECT * FROM event_registrations WHERE ticket_code = ?');
const markAttended = db.prepare(
  'UPDATE event_registrations SET attended = 1, attended_at = datetime(\'now\') WHERE id = ?'
);

/** Called by the QR scanner at the venue gate. */
router.post('/pms/admin/events/mark_attended', authenticate, (req, res) => {
  const code = req.body?.ticket_code ?? req.query.ticket_code;
  const reg = row(findByTicket, String(code ?? ''));
  if (!reg) return res.status(404).json({ success: false, message: 'This ticket is not valid.' });
  if (reg.attended) {
    return res.status(409).json({ success: false, message: 'This ticket has already been scanned.', attended_at: reg.attended_at });
  }
  markAttended.run(reg.id);
  const event = row(findEvent, reg.event_id);
  res.json({ success: true, message: 'Attendance marked.', event: eventJson(event, reg.user_id) });
});

const addCal = db.prepare('INSERT OR IGNORE INTO user_calendars (user_id, event_id) VALUES (?, ?)');
const removeCal = db.prepare('DELETE FROM user_calendars WHERE user_id = ? AND event_id = ?');
const myCal = db.prepare(`SELECT e.* FROM events e
  JOIN user_calendars c ON c.event_id = e.id WHERE c.user_id = ? ORDER BY e.starts_at ASC`);

router.post('/pms/admin/events/add_to_calendar.json', authenticate, (req, res) => {
  const eventId = Number(req.body?.event_id ?? req.query.event_id);
  if (!row(findEvent, eventId)) {
    return res.status(404).json({ success: false, message: 'Event not found.' });
  }
  addCal.run(req.user.id, eventId);
  res.json({ success: true, message: 'Added to your calendar.' });
});

router.delete('/pms/admin/events/add_to_calendar.json', authenticate, (req, res) => {
  removeCal.run(req.user.id, Number(req.body?.event_id ?? req.query.event_id));
  res.json({ success: true, message: 'Removed from your calendar.' });
});

router.get('/user_calendars.json', authenticate, (req, res) => {
  res.json({
    success: true,
    events: rows(myCal, req.user.id).map((e) => eventJson(e, req.user.id)),
  });
});
