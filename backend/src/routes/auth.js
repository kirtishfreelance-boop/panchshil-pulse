import { Router } from 'express';
import { db, row } from '../db.js';
import { authenticate, issueToken } from '../middleware/auth.js';
import { userJson } from '../serializers.js';

export const router = Router();

/// In dev the OTP is returned in the response so the app can be driven without an SMS gateway.
const DEV_OTP_ECHO = process.env.PULSE_ECHO_OTP !== 'false';
const OTP_TTL_MINUTES = 10;

const findByMobile = db.prepare('SELECT * FROM users WHERE mobile = ?');
const findById = db.prepare('SELECT * FROM users WHERE id = ?');
const insertOtp = db.prepare('INSERT INTO otps (mobile, code, expires_at) VALUES (?, ?, ?)');
const latestOtp = db.prepare(
  'SELECT * FROM otps WHERE mobile = ? AND consumed = 0 ORDER BY id DESC LIMIT 1'
);
const consumeOtp = db.prepare('UPDATE otps SET consumed = 1 WHERE id = ?');

const normalizeMobile = (raw) => String(raw ?? '').replace(/\D/g, '').slice(-10);

router.get('/get_otps/generate_otp.json', (req, res) => {
  const mobile = normalizeMobile(req.query.mobile);
  if (mobile.length !== 10) {
    return res.status(422).json({ success: false, message: 'Enter a valid 10-digit mobile number.' });
  }

  const code = String(Math.floor(100000 + Math.random() * 900000));
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60_000).toISOString();
  insertOtp.run(mobile, code, expiresAt);
  console.log(`[otp] ${mobile} -> ${code}`);

  res.json({
    success: true,
    message: `OTP sent to ${mobile}.`,
    mobile,
    user_exists: !!row(findByMobile, mobile),
    expires_in: OTP_TTL_MINUTES * 60,
    ...(DEV_OTP_ECHO ? { otp: code } : {}),
  });
});

router.get('/get_otps/verify_otp.json', (req, res) => {
  const mobile = normalizeMobile(req.query.mobile);
  const code = String(req.query.otp ?? '').trim();

  const record = row(latestOtp, mobile);
  if (!record) {
    return res.status(422).json({ success: false, message: 'Request an OTP first.' });
  }
  if (new Date(record.expires_at) < new Date()) {
    return res.status(422).json({ success: false, message: 'This OTP has expired. Request a new one.' });
  }
  if (record.code !== code) {
    return res.status(422).json({ success: false, message: 'The OTP you entered is incorrect.' });
  }
  consumeOtp.run(record.id);

  const user = row(findByMobile, mobile);
  if (!user) {
    // New number: the app moves on to the registration screen.
    return res.json({ success: true, registered: false, mobile, message: 'Verified. Complete your profile.' });
  }

  res.json({
    success: true,
    registered: true,
    token: issueToken(user),
    user: userJson(user),
  });
});

const insertUser = db.prepare(`INSERT INTO users
  (firstname, lastname, email, mobile, country_code, gender, company_name, designation, site_id, registered)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`);
const linkSite = db.prepare('INSERT OR IGNORE INTO user_sites (user_id, site_id) VALUES (?, ?)');

router.post('/users/create_user.json', (req, res) => {
  const b = req.body?.user ?? req.body ?? {};
  const mobile = normalizeMobile(b.mobile);

  if (mobile.length !== 10) {
    return res.status(422).json({ success: false, message: 'Enter a valid 10-digit mobile number.' });
  }
  if (!b.firstname?.trim()) {
    return res.status(422).json({ success: false, message: 'First name is required.' });
  }
  if (row(findByMobile, mobile)) {
    return res.status(409).json({ success: false, message: 'An account already exists for this number.' });
  }

  const siteId = Number(b.site_id ?? 1);
  const info = insertUser.run(
    b.firstname.trim(),
    b.lastname?.trim() ?? null,
    b.email?.trim() ?? null,
    mobile,
    b.country_code ?? '+91',
    b.gender ?? null,
    b.company_name?.trim() ?? null,
    b.designation?.trim() ?? null,
    siteId
  );

  const user = row(findById, Number(info.lastInsertRowid));
  linkSite.run(user.id, siteId);

  res.status(201).json({ success: true, token: issueToken(user), user: userJson(user) });
});

router.get('/api/users/account.json', authenticate, (req, res) => {
  res.json({ success: true, user: userJson(req.user) });
});

const updateUser = db.prepare(`UPDATE users SET
  firstname = COALESCE(?, firstname),
  lastname = COALESCE(?, lastname),
  email = COALESCE(?, email),
  gender = COALESCE(?, gender),
  company_name = COALESCE(?, company_name),
  designation = COALESCE(?, designation),
  profile_image = COALESCE(?, profile_image)
  WHERE id = ?`);

router.patch('/api/users/account.json', authenticate, (req, res) => {
  const b = req.body?.user ?? req.body ?? {};
  updateUser.run(
    b.firstname ?? null,
    b.lastname ?? null,
    b.email ?? null,
    b.gender ?? null,
    b.company_name ?? null,
    b.designation ?? null,
    b.profile_image ?? null,
    req.user.id
  );
  res.json({ success: true, user: userJson(row(findById, req.user.id)) });
});

const insertConsent = db.prepare(
  "INSERT INTO wallet_transactions (user_id, amount, kind, note, reference) VALUES (?, 0, 'consent', ?, ?)"
);

router.post('/pms/users/create_consent_logs.json', authenticate, (req, res) => {
  insertConsent.run(req.user.id, req.body?.consent_type ?? 'terms', 'CONSENT');
  res.json({ success: true, message: 'Consent recorded.' });
});
