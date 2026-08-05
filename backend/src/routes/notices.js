import { Router } from 'express';

import { many, one } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';
import { noticeJson } from '../serializers.js';

export const router = Router();

router.get('/pms/noticeboards.json', authenticate, async (req, res, next) => {
  try {
    const siteId = currentSiteId(req);
    const page = Math.max(1, Number(req.query.page ?? 1));
    const perPage = Math.min(50, Number(req.query.per_page ?? 20));
    const category = req.query.category;

    const notices = category
      ? await many(
          'SELECT * FROM noticeboards WHERE site_id = $1 AND category = $2 ORDER BY created_at DESC',
          [siteId, String(category)]
        )
      : await many(
          `SELECT * FROM noticeboards
            WHERE site_id = $1 AND (expires_at IS NULL OR expires_at >= NOW())
            ORDER BY is_important DESC, created_at DESC
            LIMIT $2 OFFSET $3`,
          [siteId, perPage, (page - 1) * perPage]
        );

    const categories = await many(
      `SELECT DISTINCT category FROM noticeboards
        WHERE site_id = $1 AND category IS NOT NULL ORDER BY category`,
      [siteId]
    );

    res.json({
      success: true,
      page,
      categories: categories.map((r) => r.category),
      noticeboards: notices.map(noticeJson),
    });
  } catch (err) {
    next(err);
  }
});

router.get('/pms/noticeboards/:id.json', authenticate, async (req, res, next) => {
  try {
    const notice = await one('SELECT * FROM noticeboards WHERE id = $1', [
      Number(req.params.id),
    ]);
    if (!notice) return res.status(404).json({ success: false, message: 'Notice not found.' });
    res.json({ success: true, noticeboard: noticeJson(notice) });
  } catch (err) {
    next(err);
  }
});
