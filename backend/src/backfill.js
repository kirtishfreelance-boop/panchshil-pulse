import { one, transaction } from './db.js';

const IMG = 'https://images.unsplash.com/';

/**
 * Populates a newly added module's tables the first time it appears on an
 * existing deployment.
 *
 * The full seed only runs against a brand-new database, so it never fires once
 * there are real members. Without this, shipping a new module would leave its
 * screens empty until somebody typed the content in by hand.
 *
 * Each block is guarded by a count, so this is safe to run on every boot and
 * will never overwrite anything an administrator has changed or deleted.
 */
export async function backfillModules() {
  const filled = [];

  const siteRow = await one('SELECT id FROM sites ORDER BY id LIMIT 1');
  if (!siteRow) return filled; // Nothing to attach to; the full seed will handle it.
  const siteId = siteRow.id;

  // --- Amenities -----------------------------------------------------------

  const facilityCount = await one('SELECT COUNT(*)::int AS c FROM facilities');
  if ((facilityCount?.c ?? 0) === 0) {
    await transaction(async (c) => {
      const categories = [
        ['Meeting Rooms', 'bookable', 1],
        ['Sports & Fitness', 'bookable', 2],
        ['Event Spaces', 'bookable', 3],
      ];
      const categoryIds = {};
      for (const [name, facType, position] of categories) {
        const { rows } = await c.query(
          `INSERT INTO facility_categories (site_id, name, fac_type, position)
           VALUES ($1, $2, $3, $4) RETURNING id`,
          [siteId, name, facType, position]
        );
        categoryIds[name] = rows[0].id;
      }

      const facilities = [
        ['Meeting Rooms', 'Boardroom — Tower A', 'Seats 12, video conferencing, whiteboard wall.', 'Tower A, Level 6', `${IMG}photo-1497366216548-37526070297c?w=1200`, 12, '08:00', '20:00', 60, 0, 2],
        ['Meeting Rooms', 'Huddle Room 2', 'Four-seater for quick calls and stand-ups.', 'Tower B, Level 3', `${IMG}photo-1517502884422-41eaead166d4?w=1200`, 4, '08:00', '20:00', 30, 0, 3],
        ['Sports & Fitness', 'Badminton Court', 'Wooden flooring, racquets available at the desk.', 'Sports Block, Ground', `${IMG}photo-1626224583764-f87db24ac4ea?w=1200`, 4, '06:00', '22:00', 60, 200, 2],
        ['Sports & Fitness', 'Gymnasium', 'Cardio and free weights. Instructor on duty mornings.', 'Sports Block, Level 1', `${IMG}photo-1534438327276-14e5300c3a48?w=1200`, 30, '05:00', '23:00', 60, 0, 1],
        ['Event Spaces', 'Amphitheatre', 'Open-air, seats 200. Sound system on request.', 'Central Plaza', `${IMG}photo-1478147427282-58a87a120781?w=1200`, 200, '07:00', '22:00', 120, 2500, 1],
      ];
      for (const [cat, name, description, location, image, capacity, opens, closes, slot, price, maxPer] of facilities) {
        await c.query(
          `INSERT INTO facilities (site_id, category_id, name, description, location, cover_image,
             capacity, opens_at, closes_at, slot_minutes, price_per_slot, max_per_user)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
          [siteId, categoryIds[cat], name, description, location, image, capacity, opens, closes, slot, price, maxPer]
        );
      }
    });
    filled.push('amenities');
  }

  // --- Documents -----------------------------------------------------------

  const documentCount = await one('SELECT COUNT(*)::int AS c FROM documents');
  if ((documentCount?.c ?? 0) === 0) {
    await transaction(async (c) => {
      const folders = [
        ['Estate Policies', 'House rules, fit-out guidelines and access policy.', 1],
        ['Safety & Compliance', 'Fire drills, evacuation plans, safety certificates.', 2],
        ['Forms', 'Gate passes, work permits, visitor requests.', 3],
      ];
      const folderIds = {};
      for (const [name, description, position] of folders) {
        const { rows } = await c.query(
          `INSERT INTO document_folders (site_id, name, description, position)
           VALUES ($1,$2,$3,$4) RETURNING id`,
          [siteId, name, description, position]
        );
        folderIds[name] = rows[0].id;
      }

      const sample = 'https://www.africau.edu/images/default/sample.pdf';
      const documents = [
        ['Estate Policies', 'Tenant Handbook 2026', 'Everything from access hours to fit-out rules.', 2400],
        ['Estate Policies', 'Fit-out Guidelines', 'Approved materials, contractor rules, timelines.', 1800],
        ['Safety & Compliance', 'Fire Evacuation Plan — Tower A', 'Floor-wise assembly points and marshal list.', 950],
        ['Safety & Compliance', 'Fire Safety Certificate', 'Valid through the current financial year.', 420],
        ['Forms', 'Visitor Gate Pass Form', 'Submit at least 24 hours in advance.', 180],
        ['Forms', 'After-hours Work Permit', 'Required for any work past 20:00.', 210],
      ];
      for (const [folder, title, description, sizeKb] of documents) {
        await c.query(
          `INSERT INTO documents (site_id, folder_id, title, description, file_url, file_type, size_kb)
           VALUES ($1,$2,$3,$4,$5,'PDF',$6)`,
          [siteId, folderIds[folder], title, description, sample, sizeKb]
        );
      }
    });
    filled.push('documents');
  }

  // --- SOS directory -------------------------------------------------------

  const sosCount = await one('SELECT COUNT(*)::int AS c FROM sos_contacts');
  if ((sosCount?.c ?? 0) === 0) {
    await transaction(async (c) => {
      const contacts = [
        ['Emergency Ambulance', 'National helpline', '108', 'Emergency', true, 1],
        ['Fire Brigade', 'National helpline', '101', 'Emergency', true, 2],
        ['Police', 'National helpline', '100', 'Emergency', true, 3],
        ['Estate Control Room', 'Open 24 hours', '+912066812345', 'Estate', false, 1],
        ['Estate Manager', 'Rohan Kulkarni', '+919822012345', 'Estate', false, 2],
        ['Security Desk — Main Gate', 'Gate 1', '+912066812346', 'Security', false, 1],
        ['Facilities Helpdesk', 'Weekdays 08:00–20:00', '+912066812347', 'Facilities', false, 1],
        ['Ruby Hall Clinic', 'Nearest hospital, 2.4 km', '+912026163391', 'Medical', false, 1],
      ];
      for (const [name, role, phone, category, urgent, position] of contacts) {
        await c.query(
          `INSERT INTO sos_contacts (site_id, name, role, phone, category, is_urgent, position)
           VALUES ($1,$2,$3,$4,$5,$6,$7)`,
          [siteId, name, role, phone, category, urgent, position]
        );
      }
    });
    filled.push('sos directory');
  }

  return filled;
}
