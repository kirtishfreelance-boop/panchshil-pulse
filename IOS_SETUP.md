# Getting Panchshil Pulse onto an iPhone

Everything on the code side is done. The bundle ID, permission strings, deployment target and CI pipelines are configured and committed. What remains is the part that needs Apple's involvement.

**The one hard constraint:** an iOS app binary can only be produced on macOS. This is enforced by Apple's toolchain, so it cannot be worked around from Windows. The route below rents a Mac in the cloud for the length of each build — you never buy or touch one.

---

## Step 0 — Free sanity check (do this first, costs nothing)

Before spending anything, confirm the iOS code compiles on a real Mac.

1. Create a repo on GitHub and push this project:

```bash
git remote add origin https://github.com/<you>/panchshil-pulse.git && git push -u origin main
```

2. Go to [codemagic.io](https://codemagic.io), sign in with GitHub, and add the repository.
3. Run the **`ios-verify`** workflow.

It runs `flutter analyze`, `flutter test` and an unsigned iOS build. No Apple account needed. Green means the iOS build is sound and only signing stands between you and an install.

Codemagic's free tier includes 500 macOS build-minutes a month, which is plenty for this.

---

## Step 1 — Apple Developer Program — $99/year

There is no way around this for installing on a real iPhone.

Enrol at **[developer.apple.com/programs](https://developer.apple.com/programs/)**.

- Enrol as an **Organization** if this ships under Panchshil Realty's name — you'll need the company's D-U-N-S number, and approval takes a few days.
- Enrol as an **Individual** for testing — approval is usually same-day.

> A free Apple ID can install a build that stops working after **7 days** and only via a Mac with Xcode. It is not a workable path for real testing.

---

## Step 2 — Register the app in App Store Connect

At [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Panchshil Pulse |
| Primary language | English (India) |
| Bundle ID | `com.panchshil.pulse` |
| SKU | `panchshil-pulse` |

If `com.panchshil.pulse` isn't in the Bundle ID dropdown, create it first under [Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list).

---

## Step 3 — Create an App Store Connect API key

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **+**

- Access: **App Manager**
- Download the `.p8` file — **Apple lets you download it once.** Store it in a password manager.
- Note the **Key ID** and **Issuer ID**.

---

## Step 4 — Connect Codemagic to Apple

In Codemagic → **Teams** → **Integrations** → **Apple Developer Portal** → **Connect**, upload the `.p8` and enter the Key ID and Issuer ID. **Name the integration `pulse_api_key`** — `codemagic.yaml` refers to it by that name.

Then create an environment variable group named **`appstore`** containing:

| Variable | Value |
|---|---|
| `APP_STORE_APPLE_ID` | the numeric Apple ID of the app, from its App Store Connect URL |

Codemagic generates and manages the signing certificate and provisioning profile itself, so there is nothing to create by hand.

---

## Step 5 — Build and ship

Run the **`ios-testflight`** workflow. It will:

1. Fetch dependencies, analyze, run the 17 unit tests
2. `pod install`
3. Fetch signing profiles
4. Build a signed `.ipa`
5. Upload it to TestFlight
6. Email you the result

First upload takes 10–20 minutes, then Apple processes it for another 5–15.

---

## Step 6 — Install on the iPhone

1. Install **TestFlight** from the App Store (free).
2. In App Store Connect → your app → **TestFlight**, add your Apple ID email under **Internal Testing**.
3. Accept the invite email on the iPhone; the build appears in TestFlight.
4. Tap **Install**.

Internal testing allows up to 100 testers with no Apple review. External testing (up to 10,000) requires a short Beta App Review, usually a day or two.

---

## Before it faces real users

The current build is wired for local development. Two things must change:

**1. Point it at a hosted backend.** The app defaults to a LAN address, which a phone off your Wi-Fi cannot reach. Deploy `backend/` somewhere public and build with:

```bash
flutter build ipa --release --dart-define=PULSE_API_BASE=https://api.yourdomain.com
```

**2. Remove the HTTP escape hatch.** `ios/Runner/Info.plist` currently sets `NSAllowsArbitraryLoads` so the app can talk to a plain-HTTP local server. Delete that `NSAppTransportSecurity` block once the backend is on HTTPS — App Review scrutinises it, and it weakens transport security.

Also worth settling before submission: the Futura and Trajan Pro font licences, and a privacy policy URL (App Store requires one, and this app collects a name, email, mobile number and employer).

---

## Cost summary

| Item | Cost |
|---|---|
| Compile check on a cloud Mac | Free (Codemagic 500 min/month) |
| Apple Developer Program | **$99/year — unavoidable** |
| TestFlight distribution | Free |
| Codemagic beyond the free tier | ~$0.095/min, or bring your own Mac |

Total to get Pulse onto your iPhone: **$99/year.**
