import { pathToFileURL } from 'node:url';

import { pool, transaction } from './db.js';
import { ensureSchema, resyncSequences } from './schema.js';

const IMG = 'https://images.unsplash.com/';

const sites = [
  [1, 'Panchshil Business Park', 'Pune', 'Viman Nagar, Pune 411014'],
  [2, 'Eon Free Zone', 'Pune', 'Kharadi, Pune 411014'],
  [3, 'Panchshil Tech Park', 'Pune', 'Hinjewadi Phase 1, Pune 411057'],
  [4, 'The Trilium', 'Mumbai', 'Bandra Kurla Complex, Mumbai 400051'],
];

const eventCategories = [
  [1, 'Wellness'], [2, 'Sports'], [3, 'Cultural'], [4, 'Learning'], [5, 'Networking'],
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
  [1, 1, 1, 'Sunrise Yoga at the Amphitheatre', 'Start the week grounded. A 60-minute Hatha flow led by certified instructors, followed by herbal tea at the deck. Mats provided.', 'Central Amphitheatre, Tower B', `${IMG}photo-1506126613408-eca07ce68773?w=1200`, day(2, 7), day(2, 8), false, 0, 60],
  [2, 1, 2, 'Corporate Box Cricket League — Finals', 'The eight-week league comes down to two towers. Cheer squads welcome, refreshments on the house.', 'Sports Arena, North Lawn', `${IMG}photo-1531415074968-036ba1b575da?w=1200`, day(5, 17), day(5, 21), true, 250, 200],
  [3, 1, 3, 'Diwali Bazaar & Lights Evening', 'Curated stalls from 30 local artisans, live rangoli, and the annual lamp-lighting at the fountain court.', 'Fountain Court, Central Plaza', `${IMG}photo-1604608672516-f1b9b1a0a3f9?w=1200`, day(9, 18), day(9, 22), false, 0, 500],
  [4, 1, 4, 'Design Thinking Masterclass', 'A hands-on workshop on framing problems and prototyping fast. Limited to 40 seats, laptop required.', 'Innovation Lab, Tower A, Level 6', `${IMG}photo-1522071820081-009f0129c71c?w=1200`, day(12, 10), day(12, 16), true, 1500, 40],
  [5, 1, 5, 'Founders & Funders Breakfast', 'An invite-style morning connecting park tenants with early-stage investors. Structured intros, then open table.', 'The Terrace, Tower C', `${IMG}photo-1511795409834-ef04bbd61622?w=1200`, day(16, 8), day(16, 11), true, 750, 80],
  [6, 1, 1, 'Health Check-up Camp', 'Complimentary full-body screening in partnership with Ruby Hall Clinic. Walk-ins from 9am.', 'Community Hall, Ground Level', `${IMG}photo-1576091160399-112ba8d25d1d?w=1200`, day(-6, 9), day(-6, 17), false, 0, 300],
  [7, 1, 3, 'Monsoon Live: Acoustic Sessions', 'An intimate unplugged set to open the season. Seating is first-come.', 'Rooftop Lounge, Tower D', `${IMG}photo-1470229722913-7ea0d582d0e2?w=1200`, day(-15, 19), day(-15, 22), true, 500, 150],
  [8, 2, 2, 'Eon Runners — 10K Sunrise Run', 'Chip-timed run through the Kharadi loop with hydration stations every 2km.', 'Eon Free Zone, Gate 2', `${IMG}photo-1552674605-db6ffd4facb5?w=1200`, day(7, 6), day(7, 9), true, 400, 250],
  [9, 2, 5, 'Tenant Town Hall — Q3', 'Facility roadmap, parking changes, and an open floor with the estate team.', 'Auditorium, Building 3', `${IMG}photo-1540575467063-178a50c2df87?w=1200`, day(4, 15), day(4, 17), false, 0, 180],
];

const notices = [
  [1, 1, 'Scheduled Water Supply Interruption', 'Water supply to Towers A and B will be interrupted on Saturday between 10:00 and 14:00 for tank cleaning. Please store water in advance. Tankers will be stationed at the service bay for emergencies.', 'Maintenance', true],
  [2, 1, 'New Visitor Management Process', 'From the 1st, all visitors must be pre-registered through the Pulse app. Gate security will scan the QR issued to your guest. Walk-in visitors will need host approval at the kiosk.', 'Security', true],
  [3, 1, 'Basement Parking Re-striping', 'Levels B1 and B2 will be re-striped over two weekends. Allotted bays move temporarily to the surface lot. Your allotment number stays the same.', 'Facilities', false],
  [4, 1, 'Food Court Extended Hours', 'Starting this month the food court stays open until 22:00 on weekdays. Two additional counters — a South Indian station and a salad bar — open next week.', 'Amenities', false],
  [5, 1, 'Fire Drill — Full Building Evacuation', 'A mandatory evacuation drill is scheduled for Thursday 11:00. Please follow your floor marshal and assemble at the designated point in the north lawn.', 'Safety', true],
  [6, 2, 'EV Charging Bays Now Live', 'Twelve fast-charging bays are operational at Eon Free Zone P2. Billing runs through your Pulse wallet at ₹18/kWh.', 'Amenities', false],
];

const communities = [
  [1, 1, 'Pulse Runners', 'Weekend long runs, weekday tempo sessions, and a very active shoe-recommendation thread.', `${IMG}photo-1476480862126-209bfaa8edc8?w=800`, 'Sports', true],
  [2, 1, 'Book Club at the Park', 'One book a month, one long conversation over coffee. Currently reading contemporary Indian fiction.', `${IMG}photo-1524995997946-a1c2e315a42f?w=800`, 'Culture', true],
  [3, 1, 'Product & Design Guild', 'Practitioners across the park swapping critique, portfolios, and the occasional job lead.', `${IMG}photo-1531403009284-440f080d1e12?w=800`, 'Professional', true],
  [4, 1, 'Parents of Pune', 'School runs, paediatricians, weekend plans — the practical stuff, from people two floors away.', `${IMG}photo-1476703993599-0035a21b17a9?w=800`, 'Lifestyle', false],
  [5, 1, 'Photography Walk', 'Monthly walks around the city. All cameras welcome, phones very much included.', `${IMG}photo-1452587925148-ce544e77e70d?w=800`, 'Hobby', false],
  [6, 2, 'Eon Cyclists', 'Kharadi to Mulshi and back, most Sundays. Sweep rider always provided.', `${IMG}photo-1485965120184-e220f721d03e?w=800`, 'Sports', false],
];

const posts = [
  [1, 1, 2, 'Sunday long run is on — 6:00am at Gate 2. Doing an easy 12K, no one gets dropped. Bring a spare tee, it is humid.', null],
  [2, 1, 3, 'Ran my first sub-50 10K this morning at the park loop. Six months ago I could not finish 3K without walking. This group did that.', `${IMG}photo-1571008887538-b36bb32f4571?w=900`],
  [3, 2, 4, 'This month we are reading a short novel — under 200 pages, so no excuses. Discussion the last Friday at the rooftop lounge, 7pm.', null],
  [4, 3, 5, "Sharing the deck from yesterday's critique session. The recurring theme: we all over-design the empty state and under-design the error state.", null],
  [5, 3, 2, 'Anyone here worked with design tokens across Flutter and web? Trying to keep one source of truth and losing the argument internally.', null],
];

export async function seed() {
  await ensureSchema();

  await transaction(async (c) => {
    // Order matters: children before parents.
    await c.query(`TRUNCATE like_things, comments, posts, community_members, communities,
      noticeboards, user_calendars, event_registrations, events, event_categories,
      wallet_transactions, user_sites, users, sites, service_categories, otps,
      facility_bookings, facilities, facility_categories,
      documents, document_folders, sos_contacts
      RESTART IDENTITY CASCADE`);

    for (const s of sites) {
      await c.query('INSERT INTO sites (id, name, city, address) VALUES ($1,$2,$3,$4)', s);
    }
    for (const cat of eventCategories) {
      await c.query('INSERT INTO event_categories (id, name, site_id) VALUES ($1,$2,1)', cat);
    }
    for (const s of serviceCategories) {
      await c.query(
        'INSERT INTO service_categories (id, name, icon, route, service_tag, position) VALUES ($1,$2,$3,$4,$5,$6)',
        s
      );
    }
    for (const e of events) {
      await c.query(
        `INSERT INTO events (id, site_id, category_id, title, description, venue, cover_image,
           starts_at, ends_at, is_paid, amount, capacity)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
        e
      );
    }
    for (const n of notices) {
      await c.query(
        'INSERT INTO noticeboards (id, site_id, title, body, category, is_important) VALUES ($1,$2,$3,$4,$5,$6)',
        n
      );
    }
    for (const com of communities) {
      await c.query(
        'INSERT INTO communities (id, site_id, name, description, cover_image, category, trending) VALUES ($1,$2,$3,$4,$5,$6,$7)',
        com
      );
    }

    const users = [
      [1, 'Demo', 'User', 'demo@panchshil.com', '9999999999', 'Panchshil Realty', 'Community Manager', 2500, 1250],
      [2, 'Aarav', 'Mehta', 'aarav@example.com', '9820011223', 'Nexus Labs', 'Engineering Lead', 800, 340],
      [3, 'Ishita', 'Rao', 'ishita@example.com', '9820011224', 'Brightline', 'Data Scientist', 0, 90],
      [4, 'Kabir', 'Shah', 'kabir@example.com', '9820011225', 'Meridian Capital', 'Analyst', 150, 60],
      [5, 'Nikhil', 'Fernandes', 'nikhil@example.com', '9820011226', 'Studio Fern', 'Product Designer', 0, 15],
    ];
    for (const u of users) {
      await c.query(
        `INSERT INTO users (id, firstname, lastname, email, mobile, company_name, designation,
           site_id, registered, wallet_balance, loyalty_points)
         VALUES ($1,$2,$3,$4,$5,$6,$7,1,TRUE,$8,$9)`,
        u
      );
    }

    for (const uid of [1, 2, 3, 4, 5]) {
      await c.query('INSERT INTO user_sites (user_id, site_id) VALUES ($1,1),($1,2)', [uid]);
    }
    await c.query('INSERT INTO user_sites (user_id, site_id) VALUES (1,3),(1,4)');

    const members = [[1, 1, 'member'], [1, 2, 'admin'], [1, 3, 'member'], [2, 1, 'member'],
      [2, 4, 'admin'], [3, 5, 'admin'], [3, 2, 'member']];
    for (const m of members) {
      await c.query(
        'INSERT INTO community_members (community_id, user_id, role) VALUES ($1,$2,$3)',
        m
      );
    }
    await c.query(`UPDATE communities SET members_count =
      (SELECT COUNT(*) FROM community_members WHERE community_id = communities.id)`);

    for (const p of posts) {
      await c.query(
        'INSERT INTO posts (id, community_id, user_id, body, image_url) VALUES ($1,$2,$3,$4,$5)',
        p
      );
    }

    const comments = [
      [1, 3, 'In. I will bring the spare hydration belt for whoever forgets theirs again.'],
      [2, 1, 'This is the best thing on the feed all week. Congratulations.'],
      [4, 2, 'The error-state point landed. We are guilty of exactly that.'],
    ];
    for (const cm of comments) {
      await c.query('INSERT INTO comments (post_id, user_id, body) VALUES ($1,$2,$3)', cm);
    }

    const likes = [['Post', 2, 1, 'clap'], ['Post', 2, 4, 'heart'], ['Post', 1, 3, 'thumb']];
    for (const l of likes) {
      await c.query(
        'INSERT INTO like_things (likeable_type, likeable_id, user_id, reaction) VALUES ($1,$2,$3,$4)',
        l
      );
    }

    const regs = [
      [1, 1, 1, 0, 'free', 'PLS-1-1-DEMO01'],
      [2, 1, 2, 750, 'paid', 'PLS-2-1-DEMO02'],
      [6, 1, 0, 0, 'free', 'PLS-6-1-DEMO03'],
    ];
    for (const r of regs) {
      await c.query(
        `INSERT INTO event_registrations (event_id, user_id, guests, amount_paid, payment_status, ticket_code)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        r
      );
    }
    await c.query(
      "UPDATE event_registrations SET attended = TRUE, attended_at = NOW() WHERE ticket_code = 'PLS-6-1-DEMO03'"
    );

    await c.query('INSERT INTO user_calendars (user_id, event_id) VALUES (1,1),(1,3)');

    const txns = [
      [1, 3000, 'credit', 'Wallet top-up via UPI', 'TXN-88121'],
      [1, -750, 'debit', 'Corporate Box Cricket League — Finals', 'EVT-2'],
      [1, 500, 'credit', 'Loyalty cashback', 'LOY-2201'],
      [1, -250, 'debit', 'Food court order #4471', 'FNB-4471'],
    ];
    for (const t of txns) {
      await c.query(
        'INSERT INTO wallet_transactions (user_id, amount, kind, note, reference) VALUES ($1,$2,$3,$4,$5)',
        t
      );
    }

    // --- Amenities ---------------------------------------------------------

    const facilityCategories = [
      [1, 1, 'Meeting Rooms', 'bookable', 1],
      [2, 1, 'Sports & Fitness', 'bookable', 2],
      [3, 1, 'Event Spaces', 'bookable', 3],
      [4, 1, 'Estate Services', 'requestable', 4],
    ];
    for (const fc of facilityCategories) {
      await c.query(
        'INSERT INTO facility_categories (id, site_id, name, fac_type, position) VALUES ($1,$2,$3,$4,$5)',
        fc
      );
    }

    const facilities = [
      [1, 1, 1, 'Boardroom — Tower A', 'Seats 12, video conferencing, whiteboard wall.', 'Tower A, Level 6', `${IMG}photo-1497366216548-37526070297c?w=1200`, 12, '08:00', '20:00', 60, 0, 2],
      [2, 1, 1, 'Huddle Room 2', 'Four-seater for quick calls and stand-ups.', 'Tower B, Level 3', `${IMG}photo-1517502884422-41eaead166d4?w=1200`, 4, '08:00', '20:00', 30, 0, 3],
      [3, 1, 2, 'Badminton Court', 'Wooden flooring, racquets available at the desk.', 'Sports Block, Ground', `${IMG}photo-1626224583764-f87db24ac4ea?w=1200`, 4, '06:00', '22:00', 60, 200, 2],
      [4, 1, 2, 'Gymnasium', 'Cardio and free weights. Instructor on duty mornings.', 'Sports Block, Level 1', `${IMG}photo-1534438327276-14e5300c3a48?w=1200`, 30, '05:00', '23:00', 60, 0, 1],
      [5, 1, 3, 'Amphitheatre', 'Open-air, seats 200. Sound system on request.', 'Central Plaza', `${IMG}photo-1478147427282-58a87a120781?w=1200`, 200, '07:00', '22:00', 120, 2500, 1],
      [6, 2, 1, 'Conference Hall — Eon', 'Seats 40, projector and podium.', 'Building 3, Level 2', `${IMG}photo-1505373877841-8d25f7d46678?w=1200`, 40, '09:00', '19:00', 60, 1000, 1],
    ];
    for (const f of facilities) {
      await c.query(
        `INSERT INTO facilities (id, site_id, category_id, name, description, location, cover_image,
           capacity, opens_at, closes_at, slot_minutes, price_per_slot, max_per_user)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
        f
      );
    }

    // One upcoming booking so "My bookings" is not empty on first run.
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    const tomorrowEnd = new Date(tomorrow.getTime() + 60 * 60_000);
    await c.query(
      `INSERT INTO facility_bookings (facility_id, user_id, starts_at, ends_at, amount_paid)
       VALUES (1, 1, $1, $2, 0)`,
      [tomorrow.toISOString(), tomorrowEnd.toISOString()]
    );

    // --- Documents ---------------------------------------------------------

    const folders = [
      [1, 1, 'Estate Policies', 'House rules, fit-out guidelines and access policy.', 1],
      [2, 1, 'Safety & Compliance', 'Fire drills, evacuation plans, safety certificates.', 2],
      [3, 1, 'Forms', 'Gate passes, work permits, visitor requests.', 3],
      [4, 1, 'Notices Archive', 'Circulars issued over the past year.', 4],
    ];
    for (const f of folders) {
      await c.query(
        'INSERT INTO document_folders (id, site_id, name, description, position) VALUES ($1,$2,$3,$4,$5)',
        f
      );
    }

    const documents = [
      [1, 1, 1, 'Tenant Handbook 2026', 'Everything from access hours to fit-out rules.', 'https://www.africau.edu/images/default/sample.pdf', 'PDF', 2400],
      [2, 1, 1, 'Fit-out Guidelines', 'Approved materials, contractor rules, timelines.', 'https://www.africau.edu/images/default/sample.pdf', 'PDF', 1800],
      [3, 1, 2, 'Fire Evacuation Plan — Tower A', 'Floor-wise assembly points and marshal list.', 'https://www.africau.edu/images/default/sample.pdf', 'PDF', 950],
      [4, 1, 2, 'Fire Safety Certificate', 'Valid through the current financial year.', 'https://www.africau.edu/images/default/sample.pdf', 'PDF', 420],
      [5, 1, 3, 'Visitor Gate Pass Form', 'Submit at least 24 hours in advance.', 'https://www.africau.edu/images/default/sample.pdf', 'PDF', 180],
      [6, 1, 3, 'After-hours Work Permit', 'Required for any work past 20:00.', 'https://www.africau.edu/images/default/sample.pdf', 'PDF', 210],
    ];
    for (const d of documents) {
      await c.query(
        `INSERT INTO documents (id, site_id, folder_id, title, description, file_url, file_type, size_kb)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        d
      );
    }

    // --- SOS directory -----------------------------------------------------

    const sos = [
      [1, 1, 'Emergency Ambulance', 'National helpline', '108', 'Emergency', true, 1],
      [2, 1, 'Fire Brigade', 'National helpline', '101', 'Emergency', true, 2],
      [3, 1, 'Police', 'National helpline', '100', 'Emergency', true, 3],
      [4, 1, 'Estate Control Room', 'Open 24 hours', '+912066812345', 'Estate', false, 1],
      [5, 1, 'Security Desk — Main Gate', 'Gate 1', '+912066812346', 'Security', false, 1],
      [6, 1, 'Facilities Helpdesk', 'Weekdays 08:00–20:00', '+912066812347', 'Facilities', false, 1],
      [7, 1, 'Ruby Hall Clinic', 'Nearest hospital, 2.4 km', '+912026163391', 'Medical', false, 1],
      [8, 1, 'Estate Manager', 'Rohan Kulkarni', '+919822012345', 'Estate', false, 2],
    ];
    for (const s of sos) {
      await c.query(
        `INSERT INTO sos_contacts (id, site_id, name, role, phone, category, is_urgent, position)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        s
      );
    }
  });

  await resyncSequences();
}

// Allow `npm run seed` as well as being imported by the server on first boot.
// pathToFileURL handles Windows drive letters, which a manual file:// prefix does not.
const runDirectly =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (runDirectly) {
  await seed();
  console.log('Seeded Panchshil Pulse database.');
  console.log('Demo login: mobile 9999999999.');
  await pool.end();
}
