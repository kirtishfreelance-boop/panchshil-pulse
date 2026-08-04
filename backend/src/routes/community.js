import { Router } from 'express';
import { db, row, rows } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';
import { commentJson, communityJson, postJson } from '../serializers.js';

export const router = Router();

const mine = db.prepare(`SELECT c.* FROM communities c
  JOIN community_members m ON m.community_id = c.id
  WHERE m.user_id = ? AND m.status = 'approved' ORDER BY c.name`);
const others = db.prepare(`SELECT * FROM communities
  WHERE site_id = ? AND id NOT IN (SELECT community_id FROM community_members WHERE user_id = ?)
  ORDER BY members_count DESC`);
const trending = db.prepare(
  'SELECT * FROM communities WHERE site_id = ? AND trending = 1 ORDER BY members_count DESC'
);
const byCategory = db.prepare(
  'SELECT * FROM communities WHERE site_id = ? AND category = ? ORDER BY members_count DESC'
);
const find = db.prepare('SELECT * FROM communities WHERE id = ?');

router.get('/communities/my_communities.json', authenticate, (req, res) => {
  res.json({ success: true, communities: rows(mine, req.user.id).map((c) => communityJson(c, req.user.id)) });
});

router.get('/communities/other_communities.json', authenticate, (req, res) => {
  res.json({
    success: true,
    communities: rows(others, currentSiteId(req), req.user.id).map((c) => communityJson(c, req.user.id)),
  });
});

router.get('/communities/trending_communities.json', authenticate, (req, res) => {
  res.json({
    success: true,
    communities: rows(trending, currentSiteId(req)).map((c) => communityJson(c, req.user.id)),
  });
});

router.get('/communities/category_communities.json', authenticate, (req, res) => {
  res.json({
    success: true,
    communities: rows(byCategory, currentSiteId(req), String(req.query.category ?? '')).map((c) =>
      communityJson(c, req.user.id)
    ),
  });
});

router.get('/communities/:id.json', authenticate, (req, res) => {
  const community = row(find, Number(req.params.id));
  if (!community) return res.status(404).json({ success: false, message: 'Community not found.' });
  res.json({ success: true, community: communityJson(community, req.user.id) });
});

const join = db.prepare(
  "INSERT OR IGNORE INTO community_members (community_id, user_id, status) VALUES (?, ?, 'approved')"
);
const leave = db.prepare('DELETE FROM community_members WHERE community_id = ? AND user_id = ?');
const recount = db.prepare(
  'UPDATE communities SET members_count = (SELECT COUNT(*) FROM community_members WHERE community_id = ?) WHERE id = ?'
);
const members = db.prepare(`SELECT u.id, u.firstname, u.lastname, u.profile_image, u.designation, u.company_name, m.role
  FROM community_members m JOIN users u ON u.id = m.user_id
  WHERE m.community_id = ? ORDER BY m.role DESC, u.firstname`);

router.post('/community_members.json', authenticate, (req, res) => {
  const communityId = Number(req.body?.community_id);
  if (!row(find, communityId)) {
    return res.status(404).json({ success: false, message: 'Community not found.' });
  }
  join.run(communityId, req.user.id);
  recount.run(communityId, communityId);
  res.status(201).json({ success: true, community: communityJson(row(find, communityId), req.user.id) });
});

router.delete('/community_members.json', authenticate, (req, res) => {
  const communityId = Number(req.body?.community_id ?? req.query.community_id);
  leave.run(communityId, req.user.id);
  recount.run(communityId, communityId);
  res.json({ success: true, message: 'You left the community.' });
});

router.get('/community_members.json', authenticate, (req, res) => {
  const communityId = Number(req.query.community_id);
  res.json({
    success: true,
    members: rows(members, communityId).map((m) => ({
      id: m.id,
      full_name: [m.firstname, m.lastname].filter(Boolean).join(' '),
      profile_image: m.profile_image,
      designation: m.designation,
      company_name: m.company_name,
      role: m.role,
    })),
  });
});

const feed = db.prepare(`SELECT p.* FROM posts p
  LEFT JOIN communities c ON c.id = p.community_id
  WHERE c.site_id = ? OR p.community_id IS NULL
  ORDER BY p.created_at DESC, p.id DESC LIMIT ? OFFSET ?`);
const byCommunity = db.prepare(
  'SELECT * FROM posts WHERE community_id = ? ORDER BY created_at DESC, id DESC'
);
const findPost = db.prepare('SELECT * FROM posts WHERE id = ?');
const nextPostId = db.prepare('SELECT COALESCE(MAX(id), 0) + 1 AS id FROM posts');
const insertPost = db.prepare(
  'INSERT INTO posts (id, community_id, user_id, body, image_url) VALUES (?, ?, ?, ?, ?)'
);

router.get('/posts.json', authenticate, (req, res) => {
  const page = Math.max(1, Number(req.query.page ?? 1));
  const perPage = Math.min(50, Number(req.query.per_page ?? 20));
  const list = req.query.community_id
    ? rows(byCommunity, Number(req.query.community_id))
    : rows(feed, currentSiteId(req), perPage, (page - 1) * perPage);
  res.json({ success: true, page, posts: list.map((p) => postJson(p, req.user.id)) });
});

router.post('/posts.json', authenticate, (req, res) => {
  const body = String(req.body?.body ?? '').trim();
  if (!body) return res.status(422).json({ success: false, message: 'Write something before posting.' });
  const id = row(nextPostId).id;
  insertPost.run(id, req.body?.community_id ?? null, req.user.id, body, req.body?.image_url ?? null);
  res.status(201).json({ success: true, post: postJson(row(findPost, id), req.user.id) });
});

router.get('/posts/:id.json', authenticate, (req, res) => {
  const post = row(findPost, Number(req.params.id));
  if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });
  res.json({ success: true, post: postJson(post, req.user.id) });
});

const commentsFor = db.prepare('SELECT * FROM comments WHERE post_id = ? ORDER BY id ASC');
const insertComment = db.prepare('INSERT INTO comments (post_id, user_id, body) VALUES (?, ?, ?)');
const findComment = db.prepare('SELECT * FROM comments WHERE id = ?');

router.get('/comments.json', authenticate, (req, res) => {
  res.json({
    success: true,
    comments: rows(commentsFor, Number(req.query.post_id)).map(commentJson),
  });
});

router.post('/comments.json', authenticate, (req, res) => {
  const postId = Number(req.body?.post_id);
  const body = String(req.body?.body ?? '').trim();
  if (!row(findPost, postId)) return res.status(404).json({ success: false, message: 'Post not found.' });
  if (!body) return res.status(422).json({ success: false, message: 'Comment cannot be empty.' });
  const info = insertComment.run(postId, req.user.id, body);
  res.status(201).json({ success: true, comment: commentJson(row(findComment, Number(info.lastInsertRowid))) });
});

const likeUpsert = db.prepare(`INSERT INTO like_things (likeable_type, likeable_id, user_id, reaction)
  VALUES (?, ?, ?, ?)
  ON CONFLICT (likeable_type, likeable_id, user_id) DO UPDATE SET reaction = excluded.reaction`);
const likeDelete = db.prepare(
  'DELETE FROM like_things WHERE likeable_type = ? AND likeable_id = ? AND user_id = ?'
);

router.post('/like_things.json', authenticate, (req, res) => {
  const type = req.body?.likeable_type ?? 'Post';
  const id = Number(req.body?.likeable_id);
  const reaction = req.body?.reaction ?? 'heart';
  likeUpsert.run(type, id, req.user.id, reaction);
  const post = type === 'Post' ? row(findPost, id) : null;
  res.json({ success: true, post: post ? postJson(post, req.user.id) : null });
});

router.delete('/like_things.json', authenticate, (req, res) => {
  const type = req.body?.likeable_type ?? req.query.likeable_type ?? 'Post';
  const id = Number(req.body?.likeable_id ?? req.query.likeable_id);
  likeDelete.run(type, id, req.user.id);
  const post = type === 'Post' ? row(findPost, id) : null;
  res.json({ success: true, post: post ? postJson(post, req.user.id) : null });
});
