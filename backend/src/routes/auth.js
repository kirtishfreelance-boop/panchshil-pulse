import { Router } from 'express';

import { one, query } from '../db.js';
import { authenticate, issueToken } from '../middleware/auth.js';
import { userJson } from '../serializers.js';
import { isDevOtpMode, sendOtp } from '../sms.js';

export const router = Router();

const OTP_TTL_MINUTES = 10;

/// Only ever echo the code when no real gateway is configured.
const DEV_OTP_ECHO = isDevOtpMode && process.env.PULSE_ECHO_OTP !== 'false';

/// This endpoint is unauthenticated and costs money per call, so cap it.
const MAX_SENDS_PER_HOUR = 5;
const RESEND_COOLDOWN_SECONDS = 30;

const normalizeMobile = (raw) => String(raw ?? '').replace(/\D/g, '').slice(-10);

router.get('/get_otps/generate_otp.json', async (req, res, next) => {
  try {
    const mobile = normalizeMobile(req.query.mobile);
    const countryCode = String(req.query.country_code ?? '+91');

    if (mobile.length !== 10) {
      return res
        .status(422)
        .json({ success: false, message: 'Enter a valid 10-digit mobile number.' });
    }

    // Throttle: one code per 30s, and no more than five an hour per number.
    const previous = await one(
      'SELECT created_at FROM otps WHERE mobile = $1 ORDER BY id DESC LIMIT 1',
      [mobile]
    );
    if (previous) {
      const secondsSince = (Date.now() - new Date(previous.created_at).getTime()) / 1000;
      if (secondsSince < RESEND_COOLDOWN_SECONDS) {
        const wait = Math.ceil(RESEND_COOLDOWN_SECONDS - secondsSince);
        return res.status(429).json({
          success: false,
          message: `Please wait ${wait}s before requesting another code.`,
          retry_after: wait,
        });
      }
    }

    const recent = await one(
      "SELECT COUNT(*)::int AS c FROM otps WHERE mobile = $1 AND created_at > NOW() - INTERVAL '1 hour'",
      [mobile]
    );
    if ((recent?.c ?? 0) >= MAX_SENDS_PER_HOUR) {
      return res.status(429).json({
        success: false,
        message: 'Too many codes requested for this number. Try again in an hour.',
      });
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));
    await query(
      `INSERT INTO otps (mobile, code, expires_at)
       VALUES ($1, $2, NOW() + ($3 || ' minutes')::interval)`,
      [mobile, code, String(OTP_TTL_MINUTES)]
    );

    const existing = await one('SELECT id FROM users WHERE mobile = $1', [mobile]);

    try {
      const result = await sendOtp({ mobile, countryCode, otp: code });
      res.json({
        success: true,
        message: result.delivered
          ? `OTP sent to ${countryCode} ${mobile}.`
          : `OTP generated for ${mobile} (no SMS gateway configured).`,
        mobile,
        user_exists: !!existing,
        expires_in: OTP_TTL_MINUTES * 60,
        ...(DEV_OTP_ECHO && result.echo ? { otp: result.echo } : {}),
      });
    } catch (err) {
      console.error('[otp] delivery failed:', err.message);
      res.status(502).json({
        success: false,
        message: 'We could not send the code right now. Please try again shortly.',
      });
    }
  } catch (err) {
    next(err);
  }
});

router.get('/get_otps/verify_otp.json', async (req, res, next) => {
  try {
    const mobile = normalizeMobile(req.query.mobile);
    const code = String(req.query.otp ?? '').trim();

    const record = await one(
      'SELECT * FROM otps WHERE mobile = $1 AND consumed = FALSE ORDER BY id DESC LIMIT 1',
      [mobile]
    );
    if (!record) {
      return res.status(422).json({ success: false, message: 'Request an OTP first.' });
    }
    if (new Date(record.expires_at) < new Date()) {
      return res
        .status(422)
        .json({ success: false, message: 'This OTP has expired. Request a new one.' });
    }
    if (record.code !== code) {
      return res.status(422).json({ success: false, message: 'The OTP you entered is incorrect.' });
    }

    await query('UPDATE otps SET consumed = TRUE WHERE id = $1', [record.id]);

    const user = await one('SELECT * FROM users WHERE mobile = $1', [mobile]);
    if (!user) {
      // New number: the app moves on to the registration screen.
      return res.json({
        success: true,
        registered: false,
        mobile,
        message: 'Verified. Complete your profile.',
      });
    }

    res.json({ success: true, registered: true, token: issueToken(user), user: userJson(user) });
  } catch (err) {
    next(err);
  }
});

router.post('/users/create_user.json', async (req, res, next) => {
  try {
    const b = req.body?.user ?? req.body ?? {};
    const mobile = normalizeMobile(b.mobile);

    if (mobile.length !== 10) {
      return res
        .status(422)
        .json({ success: false, message: 'Enter a valid 10-digit mobile number.' });
    }
    if (!b.firstname?.trim()) {
      return res.status(422).json({ success: false, message: 'First name is required.' });
    }

    const existing = await one('SELECT id FROM users WHERE mobile = $1', [mobile]);
    if (existing) {
      return res
        .status(409)
        .json({ success: false, message: 'An account already exists for this number.' });
    }

    const siteId = Number(b.site_id ?? 1);
    const user = await one(
      `INSERT INTO users
         (firstname, lastname, email, mobile, country_code, gender,
          company_name, designation, site_id, registered)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE)
       RETURNING *`,
      [
        b.firstname.trim(),
        b.lastname?.trim() || null,
        b.email?.trim() || null,
        mobile,
        b.country_code ?? '+91',
        b.gender ?? null,
        b.company_name?.trim() || null,
        b.designation?.trim() || null,
        siteId,
      ]
    );

    await query(
      'INSERT INTO user_sites (user_id, site_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [user.id, siteId]
    );

    res.status(201).json({ success: true, token: issueToken(user), user: userJson(user) });
  } catch (err) {
    next(err);
  }
});

router.get('/api/users/account.json', authenticate, (req, res) => {
  res.json({ success: true, user: userJson(req.user) });
});

router.patch('/api/users/account.json', authenticate, async (req, res, next) => {
  try {
    const b = req.body?.user ?? req.body ?? {};
    const user = await one(
      `UPDATE users SET
         firstname     = COALESCE($1, firstname),
         lastname      = COALESCE($2, lastname),
         email         = COALESCE($3, email),
         gender        = COALESCE($4, gender),
         company_name  = COALESCE($5, company_name),
         designation   = COALESCE($6, designation),
         profile_image = COALESCE($7, profile_image)
       WHERE id = $8
       RETURNING *`,
      [
        b.firstname ?? null,
        b.lastname ?? null,
        b.email ?? null,
        b.gender ?? null,
        b.company_name ?? null,
        b.designation ?? null,
        b.profile_image ?? null,
        req.user.id,
      ]
    );
    res.json({ success: true, user: userJson(user) });
  } catch (err) {
    next(err);
  }
});

router.post('/pms/users/create_consent_logs.json', authenticate, async (req, res, next) => {
  try {
    await query(
      `INSERT INTO wallet_transactions (user_id, amount, kind, note, reference)
       VALUES ($1, 0, 'consent', $2, 'CONSENT')`,
      [req.user.id, req.body?.consent_type ?? 'terms']
    );
    res.json({ success: true, message: 'Consent recorded.' });
  } catch (err) {
    next(err);
  }
});
