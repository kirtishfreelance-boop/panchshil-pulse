import { db } from './db.js';

const IMG = 'https://images.unsplash.com/';

const sites = [
  [1, 'Panchshil Business Park', 'Pune', 'Viman Nagar, Pune 411014'],
  [2, 'Eon Free Zone', 'Pune', 'Kharadi, Pune 411014'],
  [3, 'Panchshil Tech Park', 'Pune', 'Hinjewadi Phase 1, Pune 411057'],
  [4, 'The Trilium', 'Mumbai', 'Bandra Kurla Complex, Mumbai 400051'],
];

const eventCategories = [
  [1, 'Wellness'],
  [2, 'Sports'],
  [3, 'Cultural'],
  [4, 'Learning'],
  [5, 'Networking'],
];

const serviceCategories = [
  [1, 'Events', 'events', '/events', 'discover', 1],
  [2, 'Amenities', 'amenities', '/amenities', 'discover', 2],
  [3, 'Notices', 'notices', '/notices', 'discover', 3],
  [4, 'Documents', 'documents', '/documents', 'discover', 4],
  [5, 'Food Court', 'food_court', '/food-court', 'discover', 5],
  [6, 'Carpool', 'carpool', '/carpool', 'discover', 6],
  [7, 'Curated Services', 'curated_services', '/curated-services', 'discover', 7],
  [8, 'Panchshil Privilege', 'privilege', '/privilege', 'discover', 8],
  [9, 'SOS Directory', 'sos_directory', '/sos-directory', 'discover', 9],
];

const day = (offset, hour = 18) => {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  d.setHours(hour, 0, 0, 0);
  return d.toISOString();
};

const events = [
  [1, 1, 1, 'Sunrise Yoga at the Amphitheatre', 'Start the week grounded. A 60-minute Hatha flow led by certified instructors, followed by herbal tea at the deck. Mats provided.', 'Central Amphitheatre, Tower B', `${IMG}photo-1506126613408-eca07ce68773?w=1200`, day(2, 7), day(2, 8), 0, 0, 60],
  [2, 1, 2, 'Corporate Box Cricket League — Finals', 'The eight-week league comes down to two towers. Cheer squads welcome, refreshments on the house.', 'Sports Arena, North Lawn', `${IMG}photo-1531415074968-036ba1b575da?w=1200`, day(5, 17), day(5, 21), 1, 250, 200],
  [3, 1, 3, 'Diwali Bazaar & Lights Evening', 'Curated stalls from 30 local artisans, live rangoli, and the annual lamp-lighting at the fountain court.', 'Fountain Court, Central Plaza', `${IMG}photo-1604608672516-f1b9b1a0a3f9?w=1200`, day(9, 18), day(9, 22), 0, 0, 500],
  [4, 1, 4, 'Design Thinking Masterclass', 'A hands-on workshop on framing problems and prototyping fast. Limited to 40 seats, laptop required.', 'Innovation Lab, Tower A, Level 6', `${IMG}photo-1522071820081-009f0129c71c?w=1200`, day(12, 10), day(12, 16), 1, 1500, 40],
  [5, 1, 5, 'Founders & Funders Breakfast', 'An invite-style morning connecting park tenants with early-stage investors. Structured intros, then open table.', 'The Terrace, Tower C', `${IMG}photo-1511795409834-ef04bbd61622?w=1200`, day(16, 8), day(16, 11), 1, 750, 80],
  [6, 1, 1, 'Health Check-up Camp', 'Complimentary full-body screening in partnership with Ruby Hall Clinic. Walk-ins from 9am.', 'Community Hall, Ground Level', `${IMG}photo-1576091160399-112ba8d25d1d?w=1200`, day(-6, 9), day(-6, 17), 0, 0, 300],
  [7, 1, 3, 'Monsoon Live: Acoustic Sessions', 'An intimate unplugged set to open the season. Seating is first-come.', 'Rooftop Lounge, Tower D', `${IMG}photo-1470229722913-7ea0d582d0e2?w=1200`, day(-15, 19), day(-15, 22), 1, 500, 150],
  [8, 2, 2, 'Eon Runners — 10K Sunrise Run', 'Chip-timed run through the Kharadi loop with hydration stations every 2km.', 'Eon Free Zone, Gate 2', `${IMG}photo-1552674605-db6ffd4facb5?w=1200`, day(7, 6), day(7, 9), 1, 400, 250],
  [9, 2, 5, 'Tenant Town Hall — Q3', 'Facility roadmap, parking changes, and an open floor with the estate team.', 'Auditorium, Building 3', `${IMG}photo-1540575467063-178a50c2df87?w=1200`, day(4, 15), day(4, 17), 0, 0, 180],
];

const notices = [
  [1, 1, 'Scheduled Water Supply Interruption', 'Water supply to Towers A and B will be interrupted on Saturday between 10:00 and 14:00 for tank cleaning. Please store water in advance. Tankers will be stationed at the service bay for emergencies.', 'Maintenance', 1],
  [2, 1, 'New Visitor Management Process', 'From the 1st, all visitors must be pre-registered through the Pulse app. Gate security will scan the QR issued to your guest. Walk-in visitors will need host approval at the kiosk.', 'Security', 1],
  [3, 1, 'Basement Parking Re-striping', 'Levels B1 and B2 will be re-striped over two weekends. Allotted bays move temporarily to the surface lot. Your allotment number stays the same.', 'Facilities', 0],
  [4, 1, 'Food Court Extended Hours', 'Starting this month the food court stays open until 22:00 on weekdays. Two additional counters — a South Indian station and a salad bar — open next week.', 'Amenities', 0],
  [5, 1, 'Fire Drill — Full Building Evacuation', 'A mandatory evacuation drill is scheduled for Thursday 11:00. Please follow your floor marshal and assemble at the designated point in the north lawn.', 'Safety', 1],
  [6, 2, 'EV Charging Bays Now Live', 'Twelve fast-charging bays are operational at Eon Free Zone P2. Billing runs through your Pulse wallet at ₹18/kWh.', 'Amenities', 0],
];

const communities = [
  [1, 1, 'Pulse Runners', 'Weekend long runs, weekday tempo sessions, and a very active shoe-recommendation thread.', `${IMG}photo-1476480862126-209bfaa8edc8?w=800`, 'Sports', 1],
  [2, 1, 'Book Club at the Park', 'One book a month, one long conversation over coffee. Currently reading contemporary Indian fiction.', `${IMG}photo-1524995997946-a1c2e315a42f?w=800`, 'Culture', 1],
  [3, 1, 'Product & Design Guild', 'Practitioners across the park swapping critique, portfolios, and the occasional job lead.', `${IMG}photo-1531403009284-440f080d1e12?w=800`, 'Professional', 1],
  [4, 1, 'Parents of Pune', 'School runs, paediatricians, weekend plans — the practical stuff, from people two floors away.', `${IMG}photo-1476703993599-0035a21b17a9?w=800`, 'Lifestyle', 0],
  [5, 1, 'Photography Walk', 'Monthly walks around the city. All cameras welcome, phones very much included.', `${IMG}photo-1452587925148-ce544e77e70d?w=800`, 'Hobby', 0],
  [6, 2, 'Eon Cyclists', 'Kharadi to Mulshi and back, most Sundays. Sweep rider always provided.', `${IMG}photo-1485965120184-e220f721d03e?w=800`, 'Sports', 0],
];

const posts = [
  [1, 1, 2, 'Sunday long run is on — 6:00am at Gate 2. Doing an easy 12K, no one gets dropped. Bring a spare tee, it is humid.', null],
  [2, 1, 3, 'Ran my first sub-50 10K this morning at the park loop. Six months ago I could not finish 3K without walking. This group did that.', `${IMG}photo-1571008887538-b36bb32f4571?w=900`],
  [3, 2, 4, 'This month we are reading a short novel — under 200 pages, so no excuses. Discussion the last Friday at the rooftop lounge, 7pm.', null],
  [4, 3, 5, 'Sharing the deck from yesterday\'s critique session. The recurring theme: we all over-design the empty state and under-design the error state.', null],
  [5, 3, 2, 'Anyone here worked with design tokens across Flutter and web? Trying to keep one source of truth and losing the argument internally.', null],
];

const now = () => new Date().toISOString();

const seed = () => {
  db.exec('DELETE FROM like_things; DELETE FROM comments; DELETE FROM posts; DELETE FROM community_members; DELETE FROM communities; DELETE FROM noticeboards; DELETE FROM user_calendars; DELETE FROM event_registrations; DELETE FROM events; DELETE FROM event_categories; DELETE FROM wallet_transactions; DELETE FROM user_sites; DELETE FROM users; DELETE FROM sites; DELETE FROM service_categories; DELETE FROM otps;');

  const insSite = db.prepare('INSERT INTO sites (id, name, city, address) VALUES (?, ?, ?, ?)');
  for (const s of sites) insSite.run(...s);

  const insCat = db.prepare('INSERT INTO event_categories (id, name, site_id) VALUES (?, ?, 1)');
  for (const c of eventCategories) insCat.run(...c);

  const insSvc = db.prepare('INSERT INTO service_categories (id, name, icon, route, service_tag, position) VALUES (?, ?, ?, ?, ?, ?)');
  for (const s of serviceCategories) insSvc.run(...s);

  const insEvent = db.prepare(`INSERT INTO events
    (id, site_id, category_id, title, description, venue, cover_image, starts_at, ends_at, is_paid, amount, capacity)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  for (const e of events) insEvent.run(...e);

  const insNotice = db.prepare('INSERT INTO noticeboards (id, site_id, title, body, category, is_important) VALUES (?, ?, ?, ?, ?, ?)');
  for (const n of notices) insNotice.run(...n);

  const insCommunity = db.prepare('INSERT INTO communities (id, site_id, name, description, cover_image, category, trending) VALUES (?, ?, ?, ?, ?, ?, ?)');
  for (const c of communities) insCommunity.run(...c);

  const insUser = db.prepare(`INSERT INTO users
    (id, firstname, lastname, email, mobile, country_code, company_name, designation, site_id, registered, wallet_balance, loyalty_points)
    VALUES (?, ?, ?, ?, ?, '+91', ?, ?, 1, 1, ?, ?)`);
  insUser.run(1, 'Demo', 'User', 'demo@panchshil.com', '9999999999', 'Panchshil Realty', 'Community Manager', 2500, 1250);
  insUser.run(2, 'Aarav', 'Mehta', 'aarav@example.com', '9820011223', 'Nexus Labs', 'Engineering Lead', 800, 340);
  insUser.run(3, 'Ishita', 'Rao', 'ishita@example.com', '9820011224', 'Brightline', 'Data Scientist', 0, 90);
  insUser.run(4, 'Kabir', 'Shah', 'kabir@example.com', '9820011225', 'Meridian Capital', 'Analyst', 150, 60);
  insUser.run(5, 'Nikhil', 'Fernandes', 'nikhil@example.com', '9820011226', 'Studio Fern', 'Product Designer', 0, 15);

  const insUserSite = db.prepare('INSERT INTO user_sites (user_id, site_id) VALUES (?, ?)');
  for (const uid of [1, 2, 3, 4, 5]) {
    insUserSite.run(uid, 1);
    insUserSite.run(uid, 2);
  }
  insUserSite.run(1, 3);
  insUserSite.run(1, 4);

  const insMember = db.prepare('INSERT INTO community_members (community_id, user_id, role) VALUES (?, ?, ?)');
  insMember.run(1, 1, 'member');
  insMember.run(1, 2, 'admin');
  insMember.run(1, 3, 'member');
  insMember.run(2, 1, 'member');
  insMember.run(2, 4, 'admin');
  insMember.run(3, 5, 'admin');
  insMember.run(3, 2, 'member');

  db.exec(`UPDATE communities SET members_count = (
    SELECT COUNT(*) FROM community_members WHERE community_members.community_id = communities.id
  )`);

  const insPost = db.prepare('INSERT INTO posts (id, community_id, user_id, body, image_url) VALUES (?, ?, ?, ?, ?)');
  for (const p of posts) insPost.run(...p);

  const insComment = db.prepare('INSERT INTO comments (post_id, user_id, body) VALUES (?, ?, ?)');
  insComment.run(1, 3, 'In. I will bring the spare hydration belt for whoever forgets theirs again.');
  insComment.run(2, 1, 'This is the best thing on the feed all week. Congratulations.');
  insComment.run(4, 2, 'The error-state point landed. We are guilty of exactly that.');

  const insLike = db.prepare('INSERT INTO like_things (likeable_type, likeable_id, user_id, reaction) VALUES (?, ?, ?, ?)');
  insLike.run('Post', 2, 1, 'clap');
  insLike.run('Post', 2, 4, 'heart');
  insLike.run('Post', 1, 3, 'thumb');

  const insReg = db.prepare('INSERT INTO event_registrations (event_id, user_id, guests, amount_paid, payment_status, ticket_code) VALUES (?, ?, ?, ?, ?, ?)');
  insReg.run(1, 1, 1, 0, 'free', 'PLS-1-1-DEMO01');
  insReg.run(2, 1, 2, 750, 'paid', 'PLS-2-1-DEMO02');
  insReg.run(6, 1, 0, 0, 'free', 'PLS-6-1-DEMO03');
  db.prepare("UPDATE event_registrations SET attended = 1, attended_at = ? WHERE ticket_code = 'PLS-6-1-DEMO03'").run(now());

  const insCal = db.prepare('INSERT INTO user_calendars (user_id, event_id) VALUES (?, ?)');
  insCal.run(1, 1);
  insCal.run(1, 3);

  const insTxn = db.prepare('INSERT INTO wallet_transactions (user_id, amount, kind, note, reference) VALUES (?, ?, ?, ?, ?)');
  insTxn.run(1, 3000, 'credit', 'Wallet top-up via UPI', 'TXN-88121');
  insTxn.run(1, -750, 'debit', 'Corporate Box Cricket League — Finals', 'EVT-2');
  insTxn.run(1, 500, 'credit', 'Loyalty cashback', 'LOY-2201');
  insTxn.run(1, -250, 'debit', 'Food court order #4471', 'FNB-4471');
};

db.exec('BEGIN');
try {
  seed();
  db.exec('COMMIT');
} catch (err) {
  db.exec('ROLLBACK');
  throw err;
}

console.log('Seeded Panchshil Pulse database.');
console.log('Demo login: mobile 9999999999 — OTP is printed by the API on request (dev mode returns it in the response).');
