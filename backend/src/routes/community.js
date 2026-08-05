import { Router } from 'express';

import { affected, many, one, query } from '../db.js';
import { authenticate, currentSiteId } from '../middleware/auth.js';
import { commentJson, communityJson, postJson } from '../serializers.js';

export const router = Router();

/** $1 is the viewer, so membership comes back on the same row. */
const COMMUNITY_SELECT = `
  SELECT c.*,
         (m.id IS NOT NULL) AS joined,
         m.status AS membership_status,
         m.role   AS role
    FROM communities c
    LEFT JOIN community_members m ON m.community_id = c.id AND m.user_id = $1
`;

router.get('/communities/my_communities.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `${COMMUNITY_SELECT} WHERE m.id IS NOT NULL AND m.status = 'approved' ORDER BY c.name`,
      [req.user.id]
    );
    res.json({ success: true, communities: rows.map(communityJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/communities/other_communities.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `${COMMUNITY_SELECT}
        WHERE c.site_id = $2 AND m.id IS NULL
        ORDER BY c.members_count DESC`,
      [req.user.id, currentSiteId(req)]
    );
    res.json({ success: true, communities: rows.map(communityJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/communities/trending_communities.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `${COMMUNITY_SELECT}
        WHERE c.site_id = $2 AND c.trending = TRUE
        ORDER BY c.members_count DESC`,
      [req.user.id, currentSiteId(req)]
    );
    res.json({ success: true, communities: rows.map(communityJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/communities/category_communities.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `${COMMUNITY_SELECT}
        WHERE c.site_id = $2 AND c.category = $3
        ORDER BY c.members_count DESC`,
      [req.user.id, currentSiteId(req), String(req.query.category ?? '')]
    );
    res.json({ success: true, communities: rows.map(communityJson) });
  } catch (err) {
    next(err);
  }
});

router.get('/communities/:id.json', authenticate, async (req, res, next) => {
  try {
    const community = await one(`${COMMUNITY_SELECT} WHERE c.id = $2`, [
      req.user.id,
      Number(req.params.id),
    ]);
    if (!community) {
      return res.status(404).json({ success: false, message: 'Community not found.' });
    }
    res.json({ success: true, community: communityJson(community) });
  } catch (err) {
    next(err);
  }
});

const recount = (communityId) =>
  query(
    `UPDATE communities SET members_count =
       (SELECT COUNT(*) FROM community_members WHERE community_id = $1)
     WHERE id = $1`,
    [communityId]
  );

router.post('/community_members.json', authenticate, async (req, res, next) => {
  try {
    const communityId = Number(req.body?.community_id);
    const exists = await one('SELECT id FROM communities WHERE id = $1', [communityId]);
    if (!exists) {
      return res.status(404).json({ success: false, message: 'Community not found.' });
    }

    await query(
      `INSERT INTO community_members (community_id, user_id, status)
       VALUES ($1, $2, 'approved')
       ON CONFLICT (community_id, user_id) DO NOTHING`,
      [communityId, req.user.id]
    );
    await recount(communityId);

    const community = await one(`${COMMUNITY_SELECT} WHERE c.id = $2`, [
      req.user.id,
      communityId,
    ]);
    res.status(201).json({ success: true, community: communityJson(community) });
  } catch (err) {
    next(err);
  }
});

router.delete('/community_members.json', authenticate, async (req, res, next) => {
  try {
    const communityId = Number(req.body?.community_id ?? req.query.community_id);
    await query('DELETE FROM community_members WHERE community_id = $1 AND user_id = $2', [
      communityId,
      req.user.id,
    ]);
    await recount(communityId);
    res.json({ success: true, message: 'You left the community.' });
  } catch (err) {
    next(err);
  }
});

router.get('/community_members.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(
      `SELECT u.id, u.firstname, u.lastname, u.profile_image, u.designation,
              u.company_name, m.role
         FROM community_members m
         JOIN users u ON u.id = m.user_id
        WHERE m.community_id = $1
        ORDER BY m.role DESC, u.firstname`,
      [Number(req.query.community_id)]
    );
    res.json({
      success: true,
      members: rows.map((m) => ({
        id: m.id,
        full_name: [m.firstname, m.lastname].filter(Boolean).join(' '),
        profile_image: m.profile_image,
        designation: m.designation,
        company_name: m.company_name,
        role: m.role,
      })),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * Counts and the viewer's own reaction arrive with the row, so a feed of twenty
 * posts is one query rather than sixty.
 */
const POST_SELECT = `
  SELECT p.*,
         com.name AS community_name,
         u.id            AS author_id,
         u.firstname     AS author_firstname,
         u.lastname      AS author_lastname,
         u.profile_image AS author_profile_image,
         u.designation   AS author_designation,
         u.company_name  AS author_company_name,
         COALESCE(cc.c, 0) AS comments_count,
         COALESCE(lc.c, 0) AS likes_count,
         ml.reaction AS my_reaction
    FROM posts p
    JOIN users u ON u.id = p.user_id
    LEFT JOIN communities com ON com.id = p.community_id
    LEFT JOIN (SELECT post_id, COUNT(*)::int AS c FROM comments GROUP BY post_id) cc
           ON cc.post_id = p.id
    LEFT JOIN (
      SELECT likeable_id, COUNT(*)::int AS c FROM like_things
       WHERE likeable_type = 'Post' GROUP BY likeable_id
    ) lc ON lc.likeable_id = p.id
    LEFT JOIN like_things ml
           ON ml.likeable_type = 'Post' AND ml.likeable_id = p.id AND ml.user_id = $1
`;

router.get('/posts.json', authenticate, async (req, res, next) => {
  try {
    const page = Math.max(1, Number(req.query.page ?? 1));
    const perPage = Math.min(50, Number(req.query.per_page ?? 20));

    const rows = req.query.community_id
      ? await many(`${POST_SELECT} WHERE p.community_id = $2 ORDER BY p.id DESC`, [
          req.user.id,
          Number(req.query.community_id),
        ])
      : await many(
          `${POST_SELECT}
            WHERE com.site_id = $2 OR p.community_id IS NULL
            ORDER BY p.id DESC LIMIT $3 OFFSET $4`,
          [req.user.id, currentSiteId(req), perPage, (page - 1) * perPage]
        );

    res.json({ success: true, page, posts: rows.map(postJson) });
  } catch (err) {
    next(err);
  }
});

router.post('/posts.json', authenticate, async (req, res, next) => {
  try {
    const body = String(req.body?.body ?? '').trim();
    if (!body) {
      return res.status(422).json({ success: false, message: 'Write something before posting.' });
    }

    const created = await one(
      'INSERT INTO posts (community_id, user_id, body, image_url) VALUES ($1, $2, $3, $4) RETURNING id',
      [req.body?.community_id ?? null, req.user.id, body, req.body?.image_url ?? null]
    );
    const post = await one(`${POST_SELECT} WHERE p.id = $2`, [req.user.id, created.id]);
    res.status(201).json({ success: true, post: postJson(post) });
  } catch (err) {
    next(err);
  }
});

router.get('/posts/:id.json', authenticate, async (req, res, next) => {
  try {
    const post = await one(`${POST_SELECT} WHERE p.id = $2`, [
      req.user.id,
      Number(req.params.id),
    ]);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });
    res.json({ success: true, post: postJson(post) });
  } catch (err) {
    next(err);
  }
});

const COMMENT_SELECT = `
  SELECT c.*,
         u.id            AS author_id,
         u.firstname     AS author_firstname,
         u.lastname      AS author_lastname,
         u.profile_image AS author_profile_image
    FROM comments c
    JOIN users u ON u.id = c.user_id
`;

router.get('/comments.json', authenticate, async (req, res, next) => {
  try {
    const rows = await many(`${COMMENT_SELECT} WHERE c.post_id = $1 ORDER BY c.id ASC`, [
      Number(req.query.post_id),
    ]);
    res.json({ success: true, comments: rows.map(commentJson) });
  } catch (err) {
    next(err);
  }
});

router.post('/comments.json', authenticate, async (req, res, next) => {
  try {
    const postId = Number(req.body?.post_id);
    const body = String(req.body?.body ?? '').trim();

    const post = await one('SELECT id FROM posts WHERE id = $1', [postId]);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });
    if (!body) return res.status(422).json({ success: false, message: 'Comment cannot be empty.' });

    const created = await one(
      'INSERT INTO comments (post_id, user_id, body) VALUES ($1, $2, $3) RETURNING id',
      [postId, req.user.id, body]
    );
    const comment = await one(`${COMMENT_SELECT} WHERE c.id = $1`, [created.id]);
    res.status(201).json({ success: true, comment: commentJson(comment) });
  } catch (err) {
    next(err);
  }
});

router.post('/like_things.json', authenticate, async (req, res, next) => {
  try {
    const type = req.body?.likeable_type ?? 'Post';
    const id = Number(req.body?.likeable_id);

    await query(
      `INSERT INTO like_things (likeable_type, likeable_id, user_id, reaction)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (likeable_type, likeable_id, user_id)
       DO UPDATE SET reaction = EXCLUDED.reaction`,
      [type, id, req.user.id, req.body?.reaction ?? 'heart']
    );

    const post =
      type === 'Post' ? await one(`${POST_SELECT} WHERE p.id = $2`, [req.user.id, id]) : null;
    res.json({ success: true, post: post ? postJson(post) : null });
  } catch (err) {
    next(err);
  }
});

router.delete('/like_things.json', authenticate, async (req, res, next) => {
  try {
    const type = req.body?.likeable_type ?? req.query.likeable_type ?? 'Post';
    const id = Number(req.body?.likeable_id ?? req.query.likeable_id);

    await affected(
      'DELETE FROM like_things WHERE likeable_type = $1 AND likeable_id = $2 AND user_id = $3',
      [type, id, req.user.id]
    );

    const post =
      type === 'Post' ? await one(`${POST_SELECT} WHERE p.id = $2`, [req.user.id, id]) : null;
    res.json({ success: true, post: post ? postJson(post) : null });
  } catch (err) {
    next(err);
  }
});
