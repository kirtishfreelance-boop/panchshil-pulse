import { Router } from 'express';

import { many, one } from '../db.js';
import { authenticate } from '../middleware/auth.js';
import { siteJson, userJson } from '../serializers.js';

export const router = Router();

/** Open list — the office-park picker is shown before the user has an account. */
router.get('/users/sites.json', async (_req, res, next) => {
  try {
    const sites = await many('SELECT * FROM sites WHERE active = TRUE ORDER BY name');
    res.json({ success: true, sites: sites.map(siteJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/sites/allowed_sites.json', authenticate, async (req, res, next) => {
  try {
    const sites = await many(
      `SELECT s.* FROM sites s
         JOIN user_sites us ON us.site_id = s.id
        WHERE us.user_id = $1 AND s.active = TRUE
        ORDER BY s.name`,
      [req.user.id]
    );
    res.json({
      success: true,
      current_site_id: req.user.site_id,
      sites: sites.map(siteJson),
    });
  } catch (err) {
    next(err);
  }
});

router.get('/change_site.json', authenticate, async (req, res, next) => {
  try {
    const siteId = Number(req.query.site_id);
    const site = await one('SELECT * FROM sites WHERE id = $1', [siteId]);
    if (!site) return res.status(404).json({ success: false, message: 'Site not found.' });

    const access = await one(
      'SELECT 1 FROM user_sites WHERE user_id = $1 AND site_id = $2',
      [req.user.id, siteId]
    );
    if (!access) {
      return res
        .status(403)
        .json({ success: false, message: 'You do not have access to this site.' });
    }

    const user = await one('UPDATE users SET site_id = $1 WHERE id = $2 RETURNING *', [
      siteId,
      req.user.id,
    ]);
    res.json({ success: true, site: siteJson(site), user: userJson(user) });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/sites/:id.json', authenticate, async (req, res, next) => {
  try {
    const site = await one('SELECT * FROM sites WHERE id = $1', [Number(req.params.id)]);
    if (!site) return res.status(404).json({ success: false, message: 'Site not found.' });
    res.json({ success: true, site: siteJson(site) });
  } catch (err) {
    next(err);
  }
});

router.get('/service_categories.json', async (_req, res, next) => {
  try {
    const rows = await many(
      'SELECT * FROM service_categories WHERE active = TRUE ORDER BY position'
    );
    res.json({
      success: true,
      service_categories: rows.map((s) => ({
        id: s.id,
        name: s.name,
        icon: s.icon,
        route: s.route,
        service_tag: s.service_tag,
        position: s.position,
      })),
    });
  } catch (err) {
    next(err);
  }
});
