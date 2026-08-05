import { Router } from 'express';

import { affected, many, one, query, transaction } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';
import { eventJson } from '../serializers.js';

export const router = Router();

/**
 * One statement supplies everything an event card needs: its category, how many
 * seats are gone, and whether this viewer has registered or saved it. Doing it
 * per row would be four extra round trips per event.
 *
 * $1 is the viewer's user id.
 */
const EVENT_SELECT = `
  SELECT e.*,
         c.name AS category_name,
         COALESCE(s.seats_taken, 0) AS seats_taken,
         r.id          AS reg_id,
         r.guests      AS reg_guests,
         r.amount_paid AS reg_amount_paid,
         r.payment_status AS reg_payment_status,
         r.ticket_code AS reg_ticket_code,
         r.attended    AS reg_attended,
         r.attended_at AS reg_attended_at,
         (cal.id IS NOT NULL) AS in_calendar
    FROM events e
    LEFT JOIN event_categories c ON c.id = e.category_id
    LEFT JOIN (
      SELECT event_id, COUNT(*) + COALESCE(SUM(guests), 0) AS seats_taken
        FROM event_registrations GROUP BY event_id
    ) s ON s.event_id = e.id
    LEFT JOIN event_registrations r ON r.event_id = e.id AND r.user_id = $1
    LEFT JOIN user_calendars cal ON cal.event_id = e.id AND cal.user_id = $1
`;

router.get('/pms/admin/events.json', authenticate, async (req, res, next) => {
  try {
    const siteId = currentSiteId(req);
    const page = Math.max(1, Number(req.query.page ?? 1));
    const perPage = Math.min(50, Number(req.query.per_page ?? 20));
    const past = req.query.past === 'true';

    const rows = await many(
      `${EVENT_SELECT}
       WHERE e.site_id = $2 AND e.status = 'published'
         AND COALESCE(e.ends_at, e.starts_at) ${past ? '<' : '>='} NOW()
       ORDER BY e.starts_at ${past ? 'DESC' : 'ASC'}
       LIMIT $3 OFFSET $4`,
      [req.user.id, siteId, perPage, (page - 1) * perPage]
    );

    res.json({ success: true, page, per_page: perPage, events: rows.map(eventJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/events/categories.json', authenticate, async (_req, res, next) => {
  try {
    res.json({ success: true, categories: await many('SELECT * FROM event_categories ORDER BY id') });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/events/category_events.json', authenticate, async (req, res, next) => {
  try {
    const categoryId = Number(req.query.category_id);
    if (!categoryId) {
      return res.status(422).json({ success: false, message: 'category_id is required.' });
    }
    const rows = await many(
      `${EVENT_SELECT}
       WHERE e.site_id = $2 AND e.category_id = $3 AND e.status = 'published'
       ORDER BY e.starts_at ASC`,
      [req.user.id, currentSiteId(req), categoryId]
    );
    res.json({ success: true, events: rows.map(eventJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/events/calendar_data.json', authenticate, async (req, res, next) => {
  try {
    const from = req.query.from ?? new Date().toISOString().slice(0, 10);
    const to =
      req.query.to ?? new Date(Date.now() + 90 * 86_400_000).toISOString().slice(0, 10);

    const rows = await many(
      `${EVENT_SELECT}
       WHERE e.site_id = $2 AND e.status = 'published'
         AND e.starts_at::date BETWEEN $3::date AND $4::date
       ORDER BY e.starts_at ASC`,
      [req.user.id, currentSiteId(req), from, to]
    );

    // Grouped by day so the calendar screen renders dots without re-bucketing.
    const byDay = {};
    for (const row of rows) {
      const event = eventJson(row);
      const key = String(event.starts_at).slice(0, 10);
      (byDay[key] ??= []).push(event);
    }
    res.json({ success: true, from, to, calendar_data: byDay });
  } catch (err) {
    next(err);
  }
});

// Must stay above the `:id.json` route below, or the param route swallows it.
router.get('/pms/admin/events/my_events.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `${EVENT_SELECT} WHERE r.id IS NOT NULL ORDER BY e.starts_at DESC`,
      [req.user.id]
    );
    res.json({ success: true, events: rows.map(eventJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/events/:id.json', authenticate, async (req, res, next) => {
  try {
    const event = await one(`${EVENT_SELECT} WHERE e.id = $2`, [
      req.user.id,
      Number(req.params.id),
    ]);
    if (!event) return res.status(404).json({ success: false, message: 'Event not found.' });
    res.json({ success: true, event: eventJson(event) });
  } catch (err) {
    next(err);
  }
});

const ticketCode = (eventId, userId) =>
  `PLS-${eventId}-${userId}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;

router.post('/pms/admin/events/:id/register.json', authenticate, async (req, res, next) => {
  try {
    const eventId = Number(req.params.id);
    const guests = Math.max(0, Number(req.body?.guests ?? 0));
    const method = req.body?.payment_method ?? 'wallet';

    const result = await transaction(async (client) => {
      // Lock the event row so two people cannot take the last seat at once.
      const { rows: eventRows } = await client.query(
        'SELECT * FROM events WHERE id = $1 FOR UPDATE',
        [eventId]
      );
      const event = eventRows[0];
      if (!event) return { status: 404, body: { success: false, message: 'Event not found.' } };

      const { rows: existing } = await client.query(
        'SELECT id FROM event_registrations WHERE event_id = $1 AND user_id = $2',
        [eventId, req.user.id]
      );
      if (existing.length) {
        return {
          status: 409,
          body: { success: false, message: 'You are already registered for this event.' },
        };
      }

      if (new Date(event.ends_at ?? event.starts_at) < new Date()) {
        return {
          status: 422,
          body: { success: false, message: 'Registrations for this event have closed.' },
        };
      }

      const { rows: usedRows } = await client.query(
        `SELECT COUNT(*) + COALESCE(SUM(guests), 0) AS taken
           FROM event_registrations WHERE event_id = $1`,
        [eventId]
      );
      const taken = Number(usedRows[0]?.taken ?? 0);
      const capacity = Number(event.capacity);
      if (capacity > 0 && taken + 1 + guests > capacity) {
        return {
          status: 422,
          body: { success: false, message: 'Not enough seats left for that many guests.' },
        };
      }

      const payable = event.is_paid ? Number(event.amount) * (1 + guests) : 0;

      if (payable > 0 && method === 'wallet') {
        const { rows: walletRows } = await client.query(
          'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE',
          [req.user.id]
        );
        const balance = Number(walletRows[0]?.wallet_balance ?? 0);
        if (balance < payable) {
          return {
            status: 402,
            body: {
              success: false,
              message: 'Insufficient wallet balance.',
              payable,
              wallet_balance: balance,
            },
          };
        }
        await client.query(
          'UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2',
          [payable, req.user.id]
        );
        await client.query(
          `INSERT INTO wallet_transactions (user_id, amount, kind, note, reference)
           VALUES ($1, $2, 'debit', $3, $4)`,
          [req.user.id, -payable, event.title, `EVT-${event.id}`]
        );
      }

      const code = ticketCode(event.id, req.user.id);
      await client.query(
        `INSERT INTO event_registrations
           (event_id, user_id, guests, amount_paid, payment_status, ticket_code)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          event.id,
          req.user.id,
          guests,
          payable,
          payable === 0 ? 'free' : method === 'wallet' ? 'paid' : 'pending',
          code,
        ]
      );

      return { status: 201, code, payable };
    });

    if (result.body) return res.status(result.status).json(result.body);

    const event = await one(`${EVENT_SELECT} WHERE e.id = $2`, [req.user.id, eventId]);
    res.status(201).json({
      success: true,
      message: 'You are registered.',
      ticket_code: result.code,
      amount_paid: result.payable,
      event: eventJson(event),
    });
  } catch (err) {
    next(err);
  }
});

router.delete('/pms/admin/events/:id/register.json', authenticate, async (req, res, next) => {
  try {
    const count = await affected(
      'DELETE FROM event_registrations WHERE event_id = $1 AND user_id = $2',
      [Number(req.params.id), req.user.id]
    );
    if (!count) {
      return res
        .status(404)
        .json({ success: false, message: 'You are not registered for this event.' });
    }
    res.json({ success: true, message: 'Registration cancelled.' });
  } catch (err) {
    next(err);
  }
});

/** Called by the QR scanner at the venue gate. */
router.post('/pms/admin/events/mark_attended', authenticate, async (req, res, next) => {
  try {
    const code = String(req.body?.ticket_code ?? req.query.ticket_code ?? '');
    const reg = await one('SELECT * FROM event_registrations WHERE ticket_code = $1', [code]);
    if (!reg) return res.status(404).json({ success: false, message: 'This ticket is not valid.' });
    if (reg.attended) {
      return res.status(409).json({
        success: false,
        message: 'This ticket has already been scanned.',
        attended_at: reg.attended_at,
      });
    }

    await query(
      'UPDATE event_registrations SET attended = TRUE, attended_at = NOW() WHERE id = $1',
      [reg.id]
    );
    const event = await one(`${EVENT_SELECT} WHERE e.id = $2`, [reg.user_id, reg.event_id]);
    res.json({ success: true, message: 'Attendance marked.', event: eventJson(event) });
  } catch (err) {
    next(err);
  }
});

router.post('/pms/admin/events/add_to_calendar.json', authenticate, async (req, res, next) => {
  try {
    const eventId = Number(req.body?.event_id ?? req.query.event_id);
    const exists = await one('SELECT id FROM events WHERE id = $1', [eventId]);
    if (!exists) return res.status(404).json({ success: false, message: 'Event not found.' });

    await query(
      `INSERT INTO user_calendars (user_id, event_id) VALUES ($1, $2)
       ON CONFLICT (user_id, event_id) DO NOTHING`,
      [req.user.id, eventId]
    );
    res.json({ success: true, message: 'Added to your calendar.' });
  } catch (err) {
    next(err);
  }
});

router.delete('/pms/admin/events/add_to_calendar.json', authenticate, async (req, res, next) => {
  try {
    await query('DELETE FROM user_calendars WHERE user_id = $1 AND event_id = $2', [
      req.user.id,
      Number(req.body?.event_id ?? req.query.event_id),
    ]);
    res.json({ success: true, message: 'Removed from your calendar.' });
  } catch (err) {
    next(err);
  }
});

router.get('/user_calendars.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `${EVENT_SELECT} WHERE cal.id IS NOT NULL ORDER BY e.starts_at ASC`,
      [req.user.id]
    );
    res.json({ success: true, events: rows.map(eventJson) });
  } catch (err) {
    next(err);
  }
});
