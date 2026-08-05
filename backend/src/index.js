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
const isProduction = process.env.NODE_ENV === 'production';

// Render terminates TLS at its proxy. Without this, req.protocol reports "http"
// and the payment callback URL we hand the gateway would be insecure.
app.set('trust proxy', 1);
app.disable('x-powered-by');

// The clients are a mobile app and an admin page served from this same origin.
// Auth travels in the Authorization header, not cookies, so there is no
// credentialed cross-origin surface to protect here.
app.use(
  cors({
    origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : true,
    credentials: false,
  })
);

app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(isProduction ? 'combined' : 'dev'));

/**
 * Render polls this to decide whether an instance is healthy. It touches the
 * database on purpose — a process that is listening but cannot read its own
 * tables is not actually serving, and should fail the check.
 */
app.get('/health', (_req, res) => {
  try {
    row(db.prepare('SELECT 1 AS ok'));
    res.json({
      status: 'ok',
      service: 'panchshil-pulse-api',
      database: 'reachable',
      persistent: Boolean(process.env.PULSE_DB),
      uptime_seconds: Math.round(process.uptime()),
    });
  } catch (err) {
    res.status(503).json({
      status: 'degraded',
      service: 'panchshil-pulse-api',
      database: 'unreachable',
      message: err.message,
    });
  }
});

// Admin console — API first so /admin/api/* is never shadowed by the SPA.
const here = path.dirname(fileURLToPath(import.meta.url));
app.use(adminRoutes);
app.use('/admin', express.static(path.join(here, 'admin')));
app.get('/admin', (_req, res) => res.sendFile(path.join(here, 'admin', 'index.html')));

// Public install page. Serving the build from the API keeps the download link
// stable regardless of who can see the repository.
const publicDir = path.join(here, 'public');
app.get('/download', (_req, res) => res.sendFile(path.join(publicDir, 'download.html')));
app.use(
  '/download',
  express.static(publicDir, {
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('.apk')) {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', `attachment; filename="${path.basename(filePath)}"`);
      }
    },
  })
);

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

// Boot work must never prevent the server from listening: a process that exits
// before binding fails Render's health check and lands in a restart loop, which
// is far harder to diagnose than a running service with an empty table.
try {
  await ensureSeeded();
  ensureBootstrapAdmin();
} catch (err) {
  console.error('Start-up task failed; continuing so the service stays up:', err);
}

// 0.0.0.0 is required by container hosts; binding localhost would be unreachable.
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Panchshil Pulse API listening on port ${PORT}`);
  console.log(`  Environment:   ${process.env.NODE_ENV ?? 'development'}`);
  console.log(`  Admin console: /admin`);
  console.log(`  Install page:  /download`);
  console.log(
    `  SMS provider:  ${smsProvider}${smsProvider === 'console' ? ' (codes are logged, not sent)' : ''}`
  );
});

// Render sends SIGTERM before replacing an instance. Draining connections and
// closing the database avoids a truncated write to the SQLite file.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(`${signal} received, shutting down.`);
    server.close(() => {
      try {
        db.close();
      } catch {
        // Already closed, or never opened — nothing useful to do here.
      }
      process.exit(0);
    });
    // Do not hang forever on a stuck connection.
    setTimeout(() => process.exit(0), 10_000).unref();
  });
}

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled promise rejection:', reason);
});
