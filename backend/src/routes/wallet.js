import { Router } from 'express';
import { db, row, rows } from '../db.js';
import { authenticate } from '../middleware/auth.js';

export const router = Router();

const txns = db.prepare(
  "SELECT * FROM wallet_transactions WHERE user_id = ? AND kind != 'consent' ORDER BY id DESC LIMIT 50"
);
const findUser = db.prepare('SELECT * FROM users WHERE id = ?');
const credit = db.prepare('UPDATE users SET wallet_balance = wallet_balance + ? WHERE id = ?');
const logTxn = db.prepare(
  'INSERT INTO wallet_transactions (user_id, amount, kind, note, reference) VALUES (?, ?, ?, ?, ?)'
);

const txnJson = (t) => ({
  id: t.id,
  amount: t.amount,
  kind: t.kind,
  note: t.note,
  reference: t.reference,
  created_at: t.created_at,
});

router.get('/get_wallet_data.json', authenticate, (req, res) => {
  const user = row(findUser, req.user.id);
  res.json({
    success: true,
    wallet_balance: user.wallet_balance,
    loyalty_points: user.loyalty_points,
    transactions: rows(txns, req.user.id).map(txnJson),
  });
});

/**
 * Stands in for the Easebuzz hosted checkout. A real deployment redirects to the
 * gateway and credits the wallet from the callback below instead.
 */
router.post('/pms/easebuzz/initiate_payment', authenticate, (req, res) => {
  const amount = Number(req.body?.amount ?? 0);
  if (!(amount > 0)) {
    return res.status(422).json({ success: false, message: 'Enter an amount greater than zero.' });
  }
  const txnId = `EZ${Date.now()}${req.user.id}`;
  res.json({
    success: true,
    txn_id: txnId,
    amount,
    // The client treats this as the gateway's access key / payment URL.
    payment_url: `${req.protocol}://${req.get('host')}/pms/easebuzz/callback?txn_id=${txnId}&amount=${amount}&status=success`,
    productinfo: req.body?.productinfo ?? 'Pulse Wallet Top-up',
  });
});

router.all('/pms/easebuzz/callback', authenticate, (req, res) => {
  const p = { ...req.query, ...(req.body ?? {}) };
  const amount = Number(p.amount ?? 0);
  if (p.status !== 'success' || !(amount > 0)) {
    return res.status(422).json({ success: false, message: 'Payment was not completed.' });
  }
  credit.run(amount, req.user.id);
  logTxn.run(req.user.id, amount, 'credit', 'Wallet top-up', String(p.txn_id ?? 'EZ'));
  const user = row(findUser, req.user.id);
  res.json({ success: true, message: 'Wallet topped up.', wallet_balance: user.wallet_balance });
});
