import { Router } from 'express';
import { db, row, rows } from '../db.js';
import { authenticate } from '../middleware/auth.js';
import { siteJson, userJson } from '../serializers.js';

export const router = Router();

const allSites = db.prepare('SELECT * FROM sites WHERE active = 1 ORDER BY name');
const sitesForUser = db.prepare(`SELECT s.* FROM sites s
  JOIN user_sites us ON us.site_id = s.id
  WHERE us.user_id = ? AND s.active = 1 ORDER BY s.name`);
const findSite = db.prepare('SELECT * FROM sites WHERE id = ?');
const findUser = db.prepare('SELECT * FROM users WHERE id = ?');
const setSite = db.prepare('UPDATE users SET site_id = ? WHERE id = ?');
const hasAccess = db.prepare('SELECT 1 AS x FROM user_sites WHERE user_id = ? AND site_id = ?');

/** Open list — the office-park picker is shown before the user has an account. */
router.get('/users/sites.json', (_req, res) => {
  res.json({ success: true, sites: rows(allSites).map(siteJson) });
});

router.get('/pms/sites/allowed_sites.json', authenticate, (req, res) => {
  res.json({
    success: true,
    current_site_id: req.user.site_id,
    sites: rows(sitesForUser, req.user.id).map(siteJson),
  });
});

router.get('/pms/sites/:id.json', authenticate, (req, res) => {
  const site = row(findSite, Number(req.params.id));
  if (!site) return res.status(404).json({ success: false, message: 'Site not found.' });
  res.json({ success: true, site: siteJson(site) });
});

router.get('/change_site.json', authenticate, (req, res) => {
  const siteId = Number(req.query.site_id);
  const site = row(findSite, siteId);
  if (!site) return res.status(404).json({ success: false, message: 'Site not found.' });
  if (!row(hasAccess, req.user.id, siteId)) {
    return res.status(403).json({ success: false, message: 'You do not have access to this site.' });
  }
  setSite.run(siteId, req.user.id);
  res.json({ success: true, site: siteJson(site), user: userJson(row(findUser, req.user.id)) });
});

const activeServices = db.prepare(
  'SELECT * FROM service_categories WHERE active = 1 ORDER BY position'
);

router.get('/service_categories.json', (_req, res) => {
  res.json({
    success: true,
    service_categories: rows(activeServices).map((s) => ({
      id: s.id,
      name: s.name,
      icon: s.icon,
      route: s.route,
      service_tag: s.service_tag,
      position: s.position,
    })),
  });
});
