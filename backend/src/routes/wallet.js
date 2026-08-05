import { Router } from 'express';

import { many, one, transaction } from '../db.js';
import { authenticate } from '../middleware/auth.js';
import { txnJson } from '../serializers.js';

export const router = Router();

router.get('/get_wallet_data.json', authenticate, async (req, res, next) => {
  try {
    const user = await one(
      'SELECT wallet_balance, loyalty_points FROM users WHERE id = $1',
      [req.user.id]
    );
    const txns = await many(
      `SELECT * FROM wallet_transactions
        WHERE user_id = $1 AND kind <> 'consent'
        ORDER BY id DESC LIMIT 50`,
      [req.user.id]
    );

    res.json({
      success: true,
      wallet_balance: Number(user?.wallet_balance ?? 0),
      loyalty_points: Number(user?.loyalty_points ?? 0),
      transactions: txns.map(txnJson),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * Stands in for the Easebuzz hosted checkout. A real deployment redirects to the
 * gateway and credits the wallet from the callback below instead.
 */
router.post('/pms/easebuzz/initiate_payment', authenticate, (req, res) => {
  const amount = Number(req.body?.amount ?? 0);
  if (!(amount > 0)) {
    return res
      .status(422)
      .json({ success: false, message: 'Enter an amount greater than zero.' });
  }

  const txnId = `EZ${Date.now()}${req.user.id}`;
  res.json({
    success: true,
    txn_id: txnId,
    amount,
    // `trust proxy` is on, so this is https behind Render's TLS terminator.
    payment_url: `${req.protocol}://${req.get('host')}/pms/easebuzz/callback?txn_id=${txnId}&amount=${amount}&status=success`,
    productinfo: req.body?.productinfo ?? 'Pulse Wallet Top-up',
  });
});

router.all('/pms/easebuzz/callback', authenticate, async (req, res, next) => {
  try {
    const p = { ...req.query, ...(req.body ?? {}) };
    const amount = Number(p.amount ?? 0);
    if (p.status !== 'success' || !(amount > 0)) {
      return res.status(422).json({ success: false, message: 'Payment was not completed.' });
    }

    const balance = await transaction(async (client) => {
      const { rows } = await client.query(
        'UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2 RETURNING wallet_balance',
        [amount, req.user.id]
      );
      await client.query(
        `INSERT INTO wallet_transactions (user_id, amount, kind, note, reference)
         VALUES ($1, $2, 'credit', 'Wallet top-up', $3)`,
        [req.user.id, amount, String(p.txn_id ?? 'EZ')]
      );
      return Number(rows[0]?.wallet_balance ?? 0);
    });

    res.json({ success: true, message: 'Wallet topped up.', wallet_balance: balance });
  } catch (err) {
    next(err);
  }
});
