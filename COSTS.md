# What this costs

Short answer: **everything currently running is free, and can stay free.**

Two things need attention — one is a 30-day expiry with a free fix, the other is the only genuinely paid item, and it is optional.

---

## Running today — ₹0

| Component | Service | Free tier | Catch |
|---|---|---|---|
| Backend API | Render Web Service | Free forever | Sleeps after 15 min idle; first request then takes ~60s |
| Database | Render Postgres | Free | **Deleted 30 days after creation** — see below |
| Admin console | Served by the API | Free | — |
| App download page | Served by the API | Free | — |
| Source code | GitHub | Free | — |
| Android build tools | Flutter + Android SDK | Free | — |
| OTP codes | Console mode | Free | Codes appear in the API response, not by SMS |

---

## The 30-day database expiry, and the free fix

Render's free Postgres is removed 30 days after it is created. That is Render's policy, not a limitation of this project.

**Neon** (neon.tech) has a free tier with **no expiry** and no card required — 0.5 GB, which is far more than this app needs. Members, events and registrations are text and numbers; images are URLs pointing elsewhere. Realistically that is years of data.

Moving takes about three minutes and **needs no code change**, because the server only reads `DATABASE_URL`:

1. Sign up at [neon.tech](https://neon.tech) and create a project
2. Copy the connection string it shows you (`postgresql://…?sslmode=require`)
3. In [render.yaml](render.yaml), delete the `databases:` block and the `fromDatabase` entry, replacing that entry with:
   ```yaml
   - key: DATABASE_URL
     sync: false
   ```
4. In Render → your service → **Environment**, paste the Neon string as `DATABASE_URL`

Do this before the 30 days are up and nothing is ever interrupted.

**Alternatives, all free and all a one-line swap:** Supabase (500 MB; pauses after a week of no traffic, resumes on the next request), Aiven, or Postgres on Fly.io.

---

## The cold start

A free Render service sleeps after 15 minutes with no traffic, and the next request waits roughly a minute while it wakes. The app handles this — the splash screen says "Waking the server…" and the client timeouts are set to cover it.

If that becomes annoying during a demo, a free uptime pinger (UptimeRobot, cron-job.org) hitting `/health` every 10 minutes keeps it awake at no cost. Note this consumes Render's monthly free instance hours faster, so use it around demos rather than permanently.

---

## The one genuinely paid thing

**Real SMS delivery.** Sending an actual text message costs money — roughly ₹0.15–0.25 per SMS through MSG91, more through Twilio. There is no free tier for transactional SMS to Indian numbers, and TRAI additionally requires DLT registration of your sender ID and template.

**You do not need this to test.** In console mode the OTP comes back in the API response and the app fills it in automatically, so anyone can sign in. That is how it works right now and it costs nothing.

You only need paid SMS when real members outside your team start signing up on their own phones.

---

## iOS

The Apple Developer Program is **$99/year** and there is no way around it for installing on an iPhone. A free Apple ID only signs builds that stop working after 7 days, and it still requires a Mac.

Android has no equivalent charge — the APK installs directly, which is why it is the sensible place to test first.

---

## Summary

| | Cost |
|---|---|
| Everything running today | **₹0** |
| Keeping it free past 30 days | **₹0** — move the database to Neon |
| Real SMS to members' phones | ~₹0.20 per message, when you are ready |
| iOS | $99/year, optional |
