import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { db, row } from './db.js';
import { ensureBootstrapAdmin } from './middleware/adminAuth.js';
import { smsProvider } from './sms.js';
import { router as adminRoutes } from './routes/admin.js';
import { router as authRoutes } from './routes/auth.js';
import { router as siteRoutes } from './routes/sites.js';
import { router as eventRoutes } from './routes/events.js';
import { router as noticeRoutes } from './routes/notices.js';
import { router as walletRoutes } from './routes/wallet.js';
import { router as communityRoutes } from './routes/community.js';

const app = express();
const PORT = Number(process.env.PORT ?? 4000);

app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'panchshil-pulse-api' }));

// Admin console — API first so /admin/api/* is never shadowed by the SPA.
const here = path.dirname(fileURLToPath(import.meta.url));
app.use(adminRoutes);
app.use('/admin', express.static(path.join(here, 'admin')));
app.get('/admin', (_req, res) => res.sendFile(path.join(here, 'admin', 'index.html')));

app.use(authRoutes);
app.use(siteRoutes);
app.use(eventRoutes);
app.use(noticeRoutes);
app.use(walletRoutes);
app.use(communityRoutes);

app.use((req, res) => {
  res.status(404).json({ success: false, message: `No route for ${req.method} ${req.path}` });
});

app.use((err, _req, res, _next) => {
  console.error(err);
  // Body-parser and friends attach a status; only unexpected throws are 500s.
  const status = err.status ?? err.statusCode ?? 500;
  res.status(status).json({
    success: false,
    message: status === 500 ? 'Something went wrong on our side.' : err.message,
  });
});

/**
 * Free hosting tiers hand out an ephemeral disk, so the SQLite file is empty
 * after every deploy. Seed on boot when there is nothing there, which keeps a
 * fresh deployment immediately usable.
 */
async function ensureSeeded() {
  const sites = row(db.prepare('SELECT COUNT(*) AS c FROM sites'));
  if ((sites?.c ?? 0) > 0) return;
  console.log('Empty database detected — seeding.');
  await import('./seed.js');
}

await ensureSeeded();
ensureBootstrapAdmin();

// 0.0.0.0 is required by most container hosts; localhost-only would be unreachable.
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Panchshil Pulse API listening on port ${PORT}`);
  console.log(`  Admin console: /admin`);
  console.log(`  SMS provider:  ${smsProvider}${smsProvider === 'console' ? ' (codes are logged, not sent)' : ''}`);
});
