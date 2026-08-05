import { Router } from 'express';

import { affected, many, one, transaction } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';

export const router = Router();

const num = (v) => (v === null || v === undefined ? 0 : Number(v));

const facilityJson = (f) => ({
  id: f.id,
  site_id: f.site_id,
  category_id: f.category_id,
  category_name: f.category_name ?? null,
  fac_type: f.fac_type ?? 'bookable',
  name: f.name,
  description: f.description,
  location: f.location,
  cover_image: f.cover_image,
  capacity: num(f.capacity),
  opens_at: f.opens_at,
  closes_at: f.closes_at,
  slot_minutes: num(f.slot_minutes),
  price_per_slot: num(f.price_per_slot),
  max_per_user: num(f.max_per_user),
  active: !!f.active,
});

const bookingJson = (b) => ({
  id: b.id,
  facility_id: b.facility_id,
  facility_name: b.facility_name ?? null,
  facility_location: b.location ?? null,
  cover_image: b.cover_image ?? null,
  starts_at: b.starts_at,
  ends_at: b.ends_at,
  status: b.status,
  amount_paid: num(b.amount_paid),
  notes: b.notes,
  created_at: b.created_at,
  is_past: new Date(b.ends_at) < new Date(),
});

// ---------------------------------------------------------------------------
// Browsing
// ---------------------------------------------------------------------------

router.get('/pms/admin/facility_categories.json', authenticate, async (req, res, next) => {
  try {
    const facType = req.query.fac_type ?? 'bookable';
    const categories = await many(
      `SELECT c.*, COUNT(f.id)::int AS facility_count
         FROM facility_categories c
         LEFT JOIN facilities f ON f.category_id = c.id AND f.active = TRUE
        WHERE c.site_id = $1 AND c.fac_type = $2
        GROUP BY c.id
        ORDER BY c.position, c.name`,
      [currentSiteId(req), facType]
    );
    res.json({ success: true, facility_categories: categories });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/facility_setups/available_facilities.json', authenticate, async (req, res, next) => {
  try {
    const params = [currentSiteId(req)];
    let where = 'f.site_id = $1 AND f.active = TRUE';

    if (req.query.category_id) {
      params.push(Number(req.query.category_id));
      where += ` AND f.category_id = $${params.length}`;
    }
    if (req.query.fac_type) {
      params.push(String(req.query.fac_type));
      where += ` AND c.fac_type = $${params.length}`;
    }

    const facilities = await many(
      `SELECT f.*, c.name AS category_name, c.fac_type
         FROM facilities f
         LEFT JOIN facility_categories c ON c.id = f.category_id
        WHERE ${where}
        ORDER BY f.name`,
      params
    );
    res.json({ success: true, facilities: facilities.map(facilityJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/facility_setups/:id.json', authenticate, async (req, res, next) => {
  try {
    const facility = await one(
      `SELECT f.*, c.name AS category_name, c.fac_type
         FROM facilities f
         LEFT JOIN facility_categories c ON c.id = f.category_id
        WHERE f.id = $1`,
      [Number(req.params.id)]
    );
    if (!facility) return res.status(404).json({ success: false, message: 'Facility not found.' });
    res.json({ success: true, facility: facilityJson(facility) });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Slot availability
// ---------------------------------------------------------------------------

/**
 * Slots are not stored — they are derived. Opening hours divided by
 * slot_minutes gives the grid; existing bookings mark entries taken.
 *
 * Storing every slot row for every facility for every future day would be a
 * large table that has to be regenerated whenever opening hours change. This
 * way, changing hours in the admin takes effect immediately.
 */
router.get('/pms/facility_bookings/slots_status.json', authenticate, async (req, res, next) => {
  try {
    const facilityId = Number(req.query.facility_id);
    const date = String(req.query.date ?? new Date().toISOString().slice(0, 10));

    const facility = await one('SELECT * FROM facilities WHERE id = $1', [facilityId]);
    if (!facility) return res.status(404).json({ success: false, message: 'Facility not found.' });

    const taken = await many(
      `SELECT starts_at, ends_at, user_id
         FROM facility_bookings
        WHERE facility_id = $1 AND status <> 'cancelled'
          AND starts_at::date = $2::date`,
      [facilityId, date]
    );

    const [openH, openM] = String(facility.opens_at).split(':').map(Number);
    const [closeH, closeM] = String(facility.closes_at).split(':').map(Number);
    const step = Number(facility.slot_minutes) || 60;

    const dayStart = new Date(`${date}T00:00:00`);
    const cursor = new Date(dayStart);
    cursor.setHours(openH, openM, 0, 0);
    const dayEnd = new Date(dayStart);
    dayEnd.setHours(closeH, closeM, 0, 0);

    const now = new Date();
    const slots = [];

    while (cursor < dayEnd) {
      const slotStart = new Date(cursor);
      const slotEnd = new Date(cursor.getTime() + step * 60_000);
      if (slotEnd > dayEnd) break;

      // Overlap test: two ranges collide unless one ends before the other starts.
      const clash = taken.find(
        (b) => new Date(b.starts_at) < slotEnd && new Date(b.ends_at) > slotStart
      );

      slots.push({
        starts_at: slotStart.toISOString(),
        ends_at: slotEnd.toISOString(),
        label: `${String(slotStart.getHours()).padStart(2, '0')}:${String(slotStart.getMinutes()).padStart(2, '0')}`,
        available: !clash && slotStart > now,
        mine: clash ? clash.user_id === req.user.id : false,
        reason: clash ? 'booked' : slotStart <= now ? 'past' : null,
      });

      cursor.setTime(slotEnd.getTime());
    }

    res.json({
      success: true,
      date,
      facility: facilityJson(facility),
      slots,
    });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Booking
// ---------------------------------------------------------------------------

router.post('/pms/facility_bookings.json', authenticate, async (req, res, next) => {
  try {
    const facilityId = Number(req.body?.facility_id);
    const startsAt = new Date(req.body?.starts_at);
    const endsAt = new Date(req.body?.ends_at);

    if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime()) || endsAt <= startsAt) {
      return res.status(422).json({ success: false, message: 'Choose a valid time slot.' });
    }
    if (startsAt < new Date()) {
      return res.status(422).json({ success: false, message: 'That slot is in the past.' });
    }

    const outcome = await transaction(async (client) => {
      // Lock the facility so two people cannot take the same slot at once.
      const { rows: facRows } = await client.query(
        'SELECT * FROM facilities WHERE id = $1 FOR UPDATE',
        [facilityId]
      );
      const facility = facRows[0];
      if (!facility) return { status: 404, body: { success: false, message: 'Facility not found.' } };
      if (!facility.active) {
        return { status: 422, body: { success: false, message: 'This facility is not bookable right now.' } };
      }

      const { rows: clashes } = await client.query(
        `SELECT id FROM facility_bookings
          WHERE facility_id = $1 AND status <> 'cancelled'
            AND starts_at < $3 AND ends_at > $2`,
        [facilityId, startsAt.toISOString(), endsAt.toISOString()]
      );
      if (clashes.length) {
        return {
          status: 409,
          body: { success: false, message: 'Someone just took that slot. Pick another.' },
        };
      }

      const { rows: mineRows } = await client.query(
        `SELECT COUNT(*)::int AS c FROM facility_bookings
          WHERE facility_id = $1 AND user_id = $2 AND status <> 'cancelled'
            AND ends_at > NOW()`,
        [facilityId, req.user.id]
      );
      const maxPerUser = Number(facility.max_per_user);
      if (maxPerUser > 0 && Number(mineRows[0].c) >= maxPerUser) {
        return {
          status: 422,
          body: {
            success: false,
            message: `You can hold ${maxPerUser} upcoming booking${maxPerUser === 1 ? '' : 's'} for this facility.`,
          },
        };
      }

      const price = Number(facility.price_per_slot);
      if (price > 0) {
        const { rows: walletRows } = await client.query(
          'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE',
          [req.user.id]
        );
        const balance = Number(walletRows[0]?.wallet_balance ?? 0);
        if (balance < price) {
          return {
            status: 402,
            body: {
              success: false,
              message: 'Insufficient wallet balance.',
              payable: price,
              wallet_balance: balance,
            },
          };
        }
        await client.query(
          'UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2',
          [price, req.user.id]
        );
        await client.query(
          `INSERT INTO wallet_transactions (user_id, amount, kind, note, reference)
           VALUES ($1, $2, 'debit', $3, $4)`,
          [req.user.id, -price, `Booking — ${facility.name}`, `FAC-${facility.id}`]
        );
      }

      const { rows: created } = await client.query(
        `INSERT INTO facility_bookings (facility_id, user_id, starts_at, ends_at, amount_paid, notes)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [
          facilityId,
          req.user.id,
          startsAt.toISOString(),
          endsAt.toISOString(),
          price,
          req.body?.notes ?? null,
        ]
      );

      return { status: 201, id: created[0].id, price };
    });

    if (outcome.body) return res.status(outcome.status).json(outcome.body);

    const booking = await one(
      `SELECT b.*, f.name AS facility_name, f.location, f.cover_image
         FROM facility_bookings b JOIN facilities f ON f.id = b.facility_id
        WHERE b.id = $1`,
      [outcome.id]
    );
    res.status(201).json({
      success: true,
      message: 'Booked.',
      amount_paid: outcome.price,
      booking: bookingJson(booking),
    });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/admin/facility_bookings.json', authenticate, async (req, res, next) => {
  try {
    const past = req.query.past === 'true';
    const bookings = await many(
      `SELECT b.*, f.name AS facility_name, f.location, f.cover_image
         FROM facility_bookings b
         JOIN facilities f ON f.id = b.facility_id
        WHERE b.user_id = $1 AND b.status <> 'cancelled'
          AND b.ends_at ${past ? '<' : '>='} NOW()
        ORDER BY b.starts_at ${past ? 'DESC' : 'ASC'}`,
      [req.user.id]
    );
    res.json({ success: true, bookings: bookings.map(bookingJson) });
  } catch (err) {
    next(err);
  }
});

/** Refunds to the wallet when the booking is cancelled with time to spare. */
router.delete('/pms/facility_bookings/:id.json', authenticate, async (req, res, next) => {
  try {
    const bookingId = Number(req.params.id);

    const outcome = await transaction(async (client) => {
      const { rows } = await client.query(
        'SELECT * FROM facility_bookings WHERE id = $1 AND user_id = $2 FOR UPDATE',
        [bookingId, req.user.id]
      );
      const booking = rows[0];
      if (!booking) return { status: 404, body: { success: false, message: 'Booking not found.' } };
      if (booking.status === 'cancelled') {
        return { status: 409, body: { success: false, message: 'Already cancelled.' } };
      }
      if (new Date(booking.starts_at) < new Date()) {
        return {
          status: 422,
          body: { success: false, message: 'This booking has already started.' },
        };
      }

      await client.query("UPDATE facility_bookings SET status = 'cancelled' WHERE id = $1", [
        bookingId,
      ]);

      const refund = Number(booking.amount_paid);
      if (refund > 0) {
        await client.query(
          'UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2',
          [refund, req.user.id]
        );
        await client.query(
          `INSERT INTO wallet_transactions (user_id, amount, kind, note, reference)
           VALUES ($1, $2, 'credit', 'Booking refund', $3)`,
          [req.user.id, refund, `FAC-${booking.facility_id}`]
        );
      }
      return { status: 200, refund };
    });

    if (outcome.body) return res.status(outcome.status).json(outcome.body);
    res.json({
      success: true,
      message: outcome.refund > 0 ? 'Cancelled and refunded to your wallet.' : 'Cancelled.',
      refunded: outcome.refund,
    });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

router.get('/document_folders.json', authenticate, async (req, res, next) => {
  try {
    const folders = await many(
      `SELECT f.*, COUNT(d.id)::int AS document_count,
              COALESCE(SUM(d.size_kb), 0)::int AS total_kb,
              MAX(d.updated_at) AS last_updated
         FROM document_folders f
         LEFT JOIN documents d ON d.folder_id = f.id
        WHERE f.site_id = $1
        GROUP BY f.id
        ORDER BY f.position, f.name`,
      [currentSiteId(req)]
    );
    res.json({ success: true, folders });
  } catch (err) {
    next(err);
  }
});

router.get('/documents.json', authenticate, async (req, res, next) => {
  try {
    const params = [currentSiteId(req)];
    let where = 'site_id = $1';

    if (req.query.folder_id) {
      params.push(Number(req.query.folder_id));
      where += ` AND folder_id = $${params.length}`;
    }
    if (req.query.q) {
      params.push(`%${String(req.query.q).trim()}%`);
      where += ` AND (title ILIKE $${params.length} OR COALESCE(description, '') ILIKE $${params.length})`;
    }

    const documents = await many(
      `SELECT * FROM documents WHERE ${where} ORDER BY updated_at DESC LIMIT 200`,
      params
    );
    res.json({ success: true, documents });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// SOS directory
// ---------------------------------------------------------------------------

router.get('/sos_contacts.json', authenticate, async (req, res, next) => {
  try {
    const contacts = await many(
      `SELECT * FROM sos_contacts WHERE site_id = $1
        ORDER BY is_urgent DESC, position, name`,
      [currentSiteId(req)]
    );

    // Grouped so the screen renders sections without re-bucketing.
    const grouped = {};
    for (const c of contacts) {
      (grouped[c.category] ??= []).push({ ...c, is_urgent: !!c.is_urgent });
    }

    res.json({
      success: true,
      categories: Object.keys(grouped),
      contacts: contacts.map((c) => ({ ...c, is_urgent: !!c.is_urgent })),
      grouped,
    });
  } catch (err) {
    next(err);
  }
});
