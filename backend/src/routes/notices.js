import { Router } from 'express';
import { db, row, rows } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';
import { noticeJson } from '../serializers.js';

export const router = Router();

const list = db.prepare(`SELECT * FROM noticeboards
  WHERE site_id = ? AND (expires_at IS NULL OR datetime(expires_at) >= datetime('now'))
  ORDER BY is_important DESC, created_at DESC LIMIT ? OFFSET ?`);
const byCategory = db.prepare(`SELECT * FROM noticeboards
  WHERE site_id = ? AND category = ? ORDER BY created_at DESC`);
const find = db.prepare('SELECT * FROM noticeboards WHERE id = ?');
const distinctCategories = db.prepare(
  'SELECT DISTINCT category FROM noticeboards WHERE site_id = ? AND category IS NOT NULL ORDER BY category'
);

router.get('/pms/noticeboards.json', authenticate, (req, res) => {
  const siteId = currentSiteId(req);
  const page = Math.max(1, Number(req.query.page ?? 1));
  const perPage = Math.min(50, Number(req.query.per_page ?? 20));
  const category = req.query.category;

  const found = category
    ? rows(byCategory, siteId, String(category))
    : rows(list, siteId, perPage, (page - 1) * perPage);

  res.json({
    success: true,
    page,
    categories: rows(distinctCategories, siteId).map((r) => r.category),
    noticeboards: found.map(noticeJson),
  });
});

router.get('/pms/noticeboards/:id.json', authenticate, (req, res) => {
  const notice = row(find, Number(req.params.id));
  if (!notice) return res.status(404).json({ success: false, message: 'Notice not found.' });
  res.json({ success: true, noticeboard: noticeJson(notice) });
});
