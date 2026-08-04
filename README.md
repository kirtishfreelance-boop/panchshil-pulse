# Panchshil Pulse

A cross-platform (iOS + Android) rebuild of the Panchshil Pulse community app, with its own backend.

```
panchshil-pulse/
├── backend/     Node 22+ / Express / SQLite API
└── app/         Flutter client (one codebase, both platforms)
```

---

## Quick start

### 1. Backend

```bash
cd backend && npm install && npm run seed && npm start
```

Serves on `http://localhost:4000`. `npm run reset` wipes and re-seeds the database.

In dev the API **returns the OTP in the response** (and logs it) so you can sign in without an SMS gateway. Set `PULSE_ECHO_OTP=false` to turn that off.

Demo account: mobile `9999999999` — ₹3,000 wallet, 1,250 privilege points, 4 event registrations.

### 2. App

The toolchain is already installed on this machine:

| Tool | Version | Location |
|---|---|---|
| Flutter | 3.44.8 (Dart 3.12.2) | `D:\dev\flutter` |
| Android SDK | platform 36, build-tools 36.0.0 | `D:\dev\android-sdk` |
| JDK | Microsoft OpenJDK 17.0.20 | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |

`JAVA_HOME`, `ANDROID_HOME` and `PATH` are set at user scope, so a new terminal picks them up. Verify with `flutter doctor`.

```bash
cd app && flutter pub get && flutter run
```

Android permissions, `minSdk 24`, applicationId `com.panchshil.pulse` and release signing are already configured in `android/`.

### 3. Point the app at the backend

`app/lib/core/config/app_config.dart` defaults to `http://10.0.2.2:4000` — the host machine as seen from the **Android emulator**.

| Target | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:4000` (default) |
| iOS simulator | `http://localhost:4000` |
| Physical device on this Wi-Fi | `http://192.168.1.4:4000` |

Override without editing source:

```bash
flutter run --dart-define=PULSE_API_BASE=http://192.168.1.4:4000
```

For a phone to reach the backend, Windows Firewall needs to allow inbound TCP 4000. Run this in an **Administrator** PowerShell:

```bash
New-NetFirewallRule -DisplayName "Panchshil Pulse API" -Direction Inbound -Protocol TCP -LocalPort 4000 -Action Allow -Profile Private
```

---

## Building

```bash
cd app && flutter build apk --release --dart-define=PULSE_API_BASE=http://192.168.1.4:4000
```

Output lands at `app/build/app/outputs/flutter-apk/app-release.apk`. Copy it to an Android phone and open it — Android will ask you to allow installs from that source.

Split per-ABI APKs (smaller downloads) or an App Bundle for Play:

```bash
flutter build apk --release --split-per-abi
```

```bash
flutter build appbundle --release
```

### Signing

`android/key.properties` points at `android/pulse-release.jks`, generated locally for development. Both are gitignored. **Generate a fresh keystore for anything that ships** and keep the passwords in a secret manager — losing the Play signing key means you cannot update the app.

---

## iOS

iOS cannot be built from Windows — Apple's toolchain is macOS-only. The Dart code is already cross-platform and `ios/` is generated; what's missing is a build host. Options:

1. **A Mac.** `flutter build ios` and run on the simulator or a connected device. A free Apple ID signs builds valid for 7 days; a paid Apple Developer account ($99/yr) is needed for TestFlight and the App Store.
2. **Cloud CI** — Codemagic, Bitrise or GitHub Actions `macos-latest` runners build Flutter iOS without owning a Mac. Distributing to a device still needs a paid Apple Developer account for the signing certificate and provisioning profile.

Before the first iOS build, add these to `ios/Runner/Info.plist` inside the root `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Pulse uses the camera to scan event passes at the venue gate.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pulse needs photo access so you can set a profile picture.</string>
<key>NSCalendarsUsageDescription</key>
<string>Pulse adds events you save to your device calendar.</string>
```

Minimum deployment targets: **Android SDK 24**, **iOS 12**.

---

## What is built

### Working end to end

| Area | Screens |
|---|---|
| **Onboarding** | Video splash, mobile login, 6-digit OTP, office-park picker, registration |
| **Home** | Greeting header, banner carousel, wallet strip, event rail, notice list |
| **Events** | List (Upcoming / Past / Mine), category filters, detail, registration with guests + payment, QR ticket, month calendar |
| **Pulse** | Play / Pursuit / Panache strands, your passes, gate-side QR scanner |
| **Community** | Feed with optimistic likes, comments sheet, composer, group join/leave |
| **Wallet** | Balance card, transaction history, top-up with gateway handoff |
| **Profile** | Account summary, site switching, light/dark toggle, support links, sign out |
| **Notices** | Category filters, list, detail |

### Backend endpoints

Auth (`generate_otp`, `verify_otp`, `create_user`, `account`), sites (`allowed_sites`, `change_site`, `service_categories`), events (list, detail, categories, calendar, register, cancel, my events, `mark_attended`, `add_to_calendar`), notices, communities, posts, comments, likes, wallet and the Easebuzz-shaped payment pair.

### Deferred to the next phase

Amenities booking, documents, food court, carpool, curated services, privilege tiers, SOS directory. Their endpoint paths are already declared in `app/lib/core/network/api_endpoints.dart`, and Discover shows them with a "Soon" label rather than dead-ending.

---

## Architecture

**Backend** — Express with route modules per domain, `node:sqlite` (no native build step), JWT bearer tokens that are also accepted as `?token=`, and serializers that keep response shapes consistent.

**App** — `provider` for state, `dio` for networking with a token interceptor, `shared_preferences` for the session. Every list screen goes through one `AsyncValue<T>` container so loading, error and empty states look the same everywhere.

```
lib/
├── core/        config, theme, network, storage, widgets, utils
├── models/      plain Dart models with fromJson
├── providers/   ChangeNotifier state per domain
└── features/    one folder per screen group
```

---

## Design tokens

Sampled from the original artwork:

| Token | Value |
|---|---|
| Primary blue | `#2674DA` |
| Accent orange | `#F58220` |
| Ink | `#231F20` |
| Light background | `#F6F7FB` |
| Dark background | `#121212` |
| UI type | Futura (5 weights) |
| Display type | Trajan Pro |

Full palette in `app/lib/core/theme/app_colors.dart`.

---

## Notes

- **Fonts.** Futura and Trajan Pro are commercially licensed typefaces. Confirm the existing licence covers this build, or swap the `fonts:` block in `pubspec.yaml` for an alternative.
- **Payments.** The wallet top-up flow is shaped like Easebuzz but settles locally. Drop in `easebuzz_flutter` and point `initiate_payment` at the real gateway before handling live money.
- **Push, analytics.** Firebase is not wired up yet. Add `google-services.json` / `GoogleService-Info.plist` and `firebase_core` when you need them.
- **Production hardening.** Rotate `JWT_SECRET` (currently a dev default in `backend/src/middleware/auth.js`), move to Postgres, and put the API behind HTTPS.
