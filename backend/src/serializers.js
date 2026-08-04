import { db, row, rows } from './db.js';

const countRegs = db.prepare('SELECT COUNT(*) AS c, COALESCE(SUM(guests), 0) AS g FROM event_registrations WHERE event_id = ?');
const myReg = db.prepare('SELECT * FROM event_registrations WHERE event_id = ? AND user_id = ?');
const inCalendar = db.prepare('SELECT 1 AS x FROM user_calendars WHERE user_id = ? AND event_id = ?');
const catName = db.prepare('SELECT name FROM event_categories WHERE id = ?');

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
  wallet_balance: u.wallet_balance,
  loyalty_points: u.loyalty_points,
});

export const siteJson = (s) => ({
  id: s.id,
  name: s.name,
  city: s.city,
  address: s.address,
  logo_url: s.logo_url,
  active: !!s.active,
});

export const eventJson = (e, userId) => {
  const c = row(countRegs, e.id);
  const mine = userId ? row(myReg, e.id, userId) : null;
  const seatsTaken = (c?.c ?? 0) + (c?.g ?? 0);
  return {
    id: e.id,
    site_id: e.site_id,
    category_id: e.category_id,
    category_name: e.category_id ? row(catName, e.category_id)?.name ?? null : null,
    title: e.title,
    description: e.description,
    venue: e.venue,
    cover_image: e.cover_image,
    starts_at: e.starts_at,
    ends_at: e.ends_at,
    rsvp_by: e.rsvp_by,
    is_paid: !!e.is_paid,
    amount: e.amount,
    capacity: e.capacity,
    seats_taken: seatsTaken,
    seats_left: e.capacity > 0 ? Math.max(0, e.capacity - seatsTaken) : null,
    status: e.status,
    is_past: new Date(e.ends_at ?? e.starts_at) < new Date(),
    registration: mine
      ? {
          id: mine.id,
          guests: mine.guests,
          amount_paid: mine.amount_paid,
          payment_status: mine.payment_status,
          ticket_code: mine.ticket_code,
          attended: !!mine.attended,
          attended_at: mine.attended_at,
        }
      : null,
    in_calendar: userId ? !!row(inCalendar, userId, e.id) : false,
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

const memberOf = db.prepare('SELECT * FROM community_members WHERE community_id = ? AND user_id = ?');

export const communityJson = (c, userId) => {
  const mine = userId ? row(memberOf, c.id, userId) : null;
  return {
    id: c.id,
    site_id: c.site_id,
    name: c.name,
    description: c.description,
    cover_image: c.cover_image,
    category: c.category,
    members_count: c.members_count,
    trending: !!c.trending,
    joined: !!mine,
    membership_status: mine?.status ?? null,
    role: mine?.role ?? null,
  };
};

const author = db.prepare('SELECT id, firstname, lastname, profile_image, designation, company_name FROM users WHERE id = ?');
const countComments = db.prepare('SELECT COUNT(*) AS c FROM comments WHERE post_id = ?');
const countLikes = db.prepare("SELECT COUNT(*) AS c FROM like_things WHERE likeable_type = 'Post' AND likeable_id = ?");
const myLike = db.prepare("SELECT reaction FROM like_things WHERE likeable_type = 'Post' AND likeable_id = ? AND user_id = ?");
const communityName = db.prepare('SELECT name FROM communities WHERE id = ?');

export const postJson = (p, userId) => {
  const a = row(author, p.user_id);
  return {
    id: p.id,
    community_id: p.community_id,
    community_name: p.community_id ? row(communityName, p.community_id)?.name ?? null : null,
    body: p.body,
    image_url: p.image_url,
    created_at: p.created_at,
    author: a
      ? {
          id: a.id,
          full_name: [a.firstname, a.lastname].filter(Boolean).join(' '),
          profile_image: a.profile_image,
          designation: a.designation,
          company_name: a.company_name,
        }
      : null,
    comments_count: row(countComments, p.id)?.c ?? 0,
    likes_count: row(countLikes, p.id)?.c ?? 0,
    my_reaction: userId ? row(myLike, p.id, userId)?.reaction ?? null : null,
  };
};

export const commentJson = (c) => {
  const a = row(author, c.user_id);
  return {
    id: c.id,
    post_id: c.post_id,
    body: c.body,
    created_at: c.created_at,
    author: a
      ? {
          id: a.id,
          full_name: [a.firstname, a.lastname].filter(Boolean).join(' '),
          profile_image: a.profile_image,
        }
      : null,
  };
};

export { rows, row };
