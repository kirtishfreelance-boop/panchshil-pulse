/**
 * Row shaping for API responses.
 *
 * These take rows that already carry every column they need — the queries in
 * the route files join and aggregate up front rather than looking values up per
 * row. Under SQLite the per-row lookups were cheap; against a network database
 * they would be one round trip each, so an events list would cost dozens.
 */

const num = (value) => (value === null || value === undefined ? 0 : Number(value));

export const userJson = (u) => ({
  id: u.id,
  firstname: u.firstname,
  lastname: u.lastname,
  full_name: [u.firstname, u.lastname].filter(Boolean).join(' '),
  email: u.email,
  mobile: u.mobile,
  country_code: u.country_code,
  gender: u.gender,
  company_name: u.company_name,
  designation: u.designation,
  profile_image: u.profile_image,
  site_id: u.site_id,
  registered: !!u.registered,
  wallet_balance: num(u.wallet_balance),
  loyalty_points: num(u.loyalty_points),
});

export const siteJson = (s) => ({
  id: s.id,
  name: s.name,
  city: s.city,
  address: s.address,
  logo_url: s.logo_url,
  active: !!s.active,
});

/**
 * Expects the event query to supply `category_name`, `seats_taken`, the
 * viewer's `reg_*` columns, and `in_calendar`.
 */
export const eventJson = (e) => {
  const capacity = num(e.capacity);
  const seatsTaken = num(e.seats_taken);
  const endsOrStarts = e.ends_at ?? e.starts_at;

  return {
    id: e.id,
    site_id: e.site_id,
    category_id: e.category_id,
    category_name: e.category_name ?? null,
    title: e.title,
    description: e.description,
    venue: e.venue,
    cover_image: e.cover_image,
    starts_at: e.starts_at,
    ends_at: e.ends_at,
    rsvp_by: e.rsvp_by,
    is_paid: !!e.is_paid,
    amount: num(e.amount),
    capacity,
    seats_taken: seatsTaken,
    seats_left: capacity > 0 ? Math.max(0, capacity - seatsTaken) : null,
    status: e.status,
    is_past: new Date(endsOrStarts) < new Date(),
    registration: e.reg_id
      ? {
          id: e.reg_id,
          guests: num(e.reg_guests),
          amount_paid: num(e.reg_amount_paid),
          payment_status: e.reg_payment_status,
          ticket_code: e.reg_ticket_code,
          attended: !!e.reg_attended,
          attended_at: e.reg_attended_at,
        }
      : null,
    in_calendar: !!e.in_calendar,
  };
};

export const noticeJson = (n) => ({
  id: n.id,
  site_id: n.site_id,
  title: n.title,
  body: n.body,
  cover_image: n.cover_image,
  category: n.category,
  is_important: !!n.is_important,
  expires_at: n.expires_at,
  created_at: n.created_at,
});

/** Expects `joined`, `membership_status` and `role` from a LEFT JOIN. */
export const communityJson = (c) => ({
  id: c.id,
  site_id: c.site_id,
  name: c.name,
  description: c.description,
  cover_image: c.cover_image,
  category: c.category,
  members_count: num(c.members_count),
  trending: !!c.trending,
  joined: !!c.joined,
  membership_status: c.membership_status ?? null,
  role: c.role ?? null,
});

const authorFrom = (row) =>
  row.author_id
    ? {
        id: row.author_id,
        full_name: [row.author_firstname, row.author_lastname].filter(Boolean).join(' '),
        profile_image: row.author_profile_image,
        designation: row.author_designation,
        company_name: row.author_company_name,
      }
    : null;

/** Expects author_* columns plus `comments_count`, `likes_count`, `my_reaction`. */
export const postJson = (p) => ({
  id: p.id,
  community_id: p.community_id,
  community_name: p.community_name ?? null,
  body: p.body,
  image_url: p.image_url,
  created_at: p.created_at,
  author: authorFrom(p),
  comments_count: num(p.comments_count),
  likes_count: num(p.likes_count),
  my_reaction: p.my_reaction ?? null,
});

export const commentJson = (c) => ({
  id: c.id,
  post_id: c.post_id,
  body: c.body,
  created_at: c.created_at,
  author: authorFrom(c),
});

export const txnJson = (t) => ({
  id: t.id,
  amount: num(t.amount),
  kind: t.kind,
  note: t.note,
  reference: t.reference,
  created_at: t.created_at,
});
