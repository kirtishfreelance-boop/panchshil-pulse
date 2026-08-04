# Admin console

A web console for running Pulse day to day — creating events, posting notices, managing members, and checking people in at the gate.

**Live:** https://panchshil-pulse-api.onrender.com/admin
**Local:** http://localhost:4000/admin

---

## First sign-in

**Easiest route — choose your own password.** On the Render service go to **Environment**, set:

```
ADMIN_PASSWORD = whatever-you-want
```

Save. Render redeploys, and the owner account's password becomes that value. Sign in at `/admin` as `admin@panchshil.com`.

This works whether or not the account already exists, so it doubles as password recovery: only somebody who can already reach the deployment's environment can trigger it.

**If you leave `ADMIN_PASSWORD` unset**, a random password is generated on first boot and printed once to the log. On Render, find it under **Logs**, near the start of the deploy:

```
  Created the first admin account for /admin
    email:    admin@panchshil.com
    password: wbCW1eIZaWCt
    This is shown once. Set ADMIN_PASSWORD to choose your own.
```

There is deliberately no fixed default. This repository is public, so a hard-coded password would be known to anyone who read it.

Once in, change it under **Setup → Administrators → Change my password**, and add colleagues from the same screen.

---

## What you can manage

| Section | What it does |
|---|---|
| **Dashboard** | Member, event and registration counts, money collected, and the latest sign-ups |
| **Events** | Create and edit events — title, description, venue, cover image, timing, price, capacity, category, published/draft/cancelled |
| **Registrations** | Per event: who registered, guests, amount paid, ticket code, and a check-in toggle |
| **Notices** | Announcements, with a category and an "important" pin that surfaces them at the top |
| **Communities** | Interest groups, cover image, and the trending flag |
| **Feed posts** | Moderate the community feed |
| **Members** | Everyone who signed up: contact details, employer, wallet balance, privilege points |
| **Sites** | Office parks. Everything else is scoped to one |
| **Event categories** | The filter chips shown above the events list in the app |
| **Administrators** | Add colleagues, change your own password |

Anything saved here appears in the app immediately — the console writes to the same database the app reads.

---

## Sending real OTPs

Out of the box the server logs the OTP and returns it in the API response, which is what lets you sign in without an SMS gateway. Configure a provider and that stops: codes are sent, and never echoed.

Set these on the Render service under **Environment**:

**MSG91** (built for India, cheaper for Indian numbers)

```
SMS_PROVIDER=msg91
MSG91_AUTH_KEY=...
MSG91_TEMPLATE_ID=...
MSG91_SENDER_ID=PULSE
```

**Twilio**

```
SMS_PROVIDER=twilio
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_FROM=+1...
```

> **Indian numbers need DLT registration.** TRAI requires the sender ID and the message template to be registered on a DLT platform before transactional SMS will be delivered to Indian numbers. Your provider walks you through it; approval takes a few days. Until it clears, messages to Indian numbers will be rejected by the carriers regardless of which gateway you use.

Requests are throttled to one code per 30 seconds and five per hour per number, since the endpoint is public and every send costs money.

### Anyone can sign up

The flow already works for any number: request a code → verify it → if the number is new, the app moves to the registration screen, the member fills in their name, company and site, and the account is created. Nothing needs to be pre-registered.

---

## Keeping data

Render's free plan gives each deploy a fresh filesystem, so the database is recreated — and re-seeded — every time you push. Demo content comes back; real accounts, registrations and posts do not.

To keep data, switch `plan: free` to `plan: starter` in [render.yaml](render.yaml). The `disk:` block is already there and mounts at `/var/data`, where `PULSE_DB` already points. That is $7/month and also removes the cold-start delay.

The code handles both: if the mount is missing it logs a warning and falls back to the container filesystem rather than refusing to start.

---

## Before real members use it

- [ ] Change the admin password
- [ ] Configure an SMS provider and complete DLT registration
- [ ] Set `PULSE_ECHO_OTP=false` (setting a provider does this implicitly)
- [ ] Move to a paid plan so data persists
- [ ] Replace the seeded demo events, notices and communities with real ones
- [ ] Delete the demo member (mobile `9999999999`)
- [ ] Point the Easebuzz payment routes at the real gateway before taking money
