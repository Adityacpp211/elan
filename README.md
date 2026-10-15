<div align="center">

# Élan

### Emergency Cardiac Care System

**Élan** *(Fr. — "spirit, momentum")* is an end-to-end emergency cardiac care platform. In the seconds that decide a life, it connects people in distress with nearby hospitals through an intelligent, location-aware alert network.

[![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-4.x-000000?logo=express)](https://expressjs.com)
[![License](https://img.shields.io/badge/License-MIT-yellow)](#license)

A **Flutter** mobile app paired with a **Node.js + Express** backend — engineered to bridge the critical gap between a cardiac emergency and the medical response it demands.

</div>

---

## Why Élan

Heart attacks move fast. Emergency response usually doesn't. Traditional flows rely on phone calls, uncertain dispatches, and hospitals learning about a patient *after* they arrive. Élan inverts that — **the moment a user presses the emergency button, nearby hospitals are notified instantly with live location, symptoms, and a route they can act on.**

> "Every second counts in a cardiac emergency. Élan makes sure those seconds are never wasted."

---

## Key Features

- **Hold-to-send SOS** — Press and hold for 1.5 s to send symptoms and your live GPS location. Holding guards against accidental alerts without a confirm dialog slowing you down.
- **Live dispatch tracker** — After sending, follow the alert from "sent" to "help is on the way": a running timer, a timeline, the accepting hospital's ETA countdown, and one-tap calls to hospitals or 112.
- **Location-aware hospitals** — GPS-driven search surfaces verified hospitals ranked by distance, backed by a live hospital database on the backend.
- **Free alerts** — Every alert goes to the 3 nearest hospitals at no cost, with no payment step (`ALERTS_FREE`, on by default). Paid tiers through Razorpay remain available behind `ALERTS_FREE=false`; check Google Play's billing policy before enabling them in a Play build.
- **Account recovery and control** — Forgot-password reset by emailed 6-digit code (signs out every other session), and account deletion in the app or on the web.
- **Safety and privacy** — A first-launch notice that Élan does not replace 112, a standing 112 button on the Emergency screen, and a privacy policy served at `/privacy`.
- **Hospital triage desk** — A console for hospital staff: unanswered alerts first, a live "waiting" timer that turns red after 2 minutes, the patient's own message, and one-tap accept with an arrival estimate (5/10/15/20 min) the patient sees immediately.
- **Hospital alert feed** — Track every alert you've sent, its status, and which hospitals acknowledged it.
- **Patient records** — Manage patient profiles with admission details, blood type, room, and condition.
- **Vitals monitoring** — Log and view heart rate, blood pressure, temperature, and oxygen saturation over time.
- **Medical reports** — Store and review report documents per patient.
- **Honest offline behaviour** — A previous session still opens offline, and the receiver console shows its last cached inbox. Alerts and records always need the server, and the app says clearly when an alert was **not** sent instead of pretending.
- **Live server status** — On-device connectivity indicator that pings the backend and shows online/synced or offline/local.
- **Clinical light design** — A calm light theme built from the Élan logo's blues and greens, set in Manrope, with red reserved for SOS and critical states.

---

## Architecture

```
┌──────────────────┐         REST         ┌───────────────────────────┐
│   Flutter App    │ ◄──────────────────► │      Express Backend      │
│  (Android / iOS) │   JSON over HTTPS    │  Auth · Alerts · Hospitals │
└──────────────────┘                      │  Payments · Records · FCM │
        │                                 └────────────┬──────────────┘
        │ GPS, alerts,                              Firebase FCM ───► Hospital
        │ patient data                              Razorpay          push / email
        ▼                                          SMTP (Nodemailer)
┌──────────────────┐                      ┌───────────────────────────┐
│ SharedPreferences│                      │   SQLite (sql.js)         │
│ (session + cache)│                      │   persistent data store   │
└──────────────────┘                      └───────────────────────────┘
```

**Flow of an emergency:**

1. User opens the **Emergency** screen, picks symptoms and holds the SOS button for 1.5 s.
2. The app resolves the user's real GPS location. If no fix is available it stops and says so; it never substitutes a default location.
3. The backend confirms at least one hospital is in range and records the alert for the 3 nearest (free; no payment step).
4. Notified hospitals receive an **FCM push** and an **email** with symptoms, exact coordinates, and a Google Maps deep link.
5. Duty staff open the **receiver console** and accept the alert, optionally giving an arrival estimate.
6. The patient is notified of the acceptance and the ETA, and can watch the alert move to `acknowledged` in their history.

---

## Tech Stack

| Layer      | Technology |
|------------|------------|
| Mobile     | Flutter / Dart — custom light theme, geolocation, offline cache |
| Backend    | Node.js / Express — JWT auth, role-based access, rate limiting |
| Database   | SQLite (`sql.js`) — persistent, file-based, test-isolated |
| Payments   | None in v1 (alerts are free); Razorpay support kept behind `ALERTS_FREE=false` |
| Notifications | Firebase Cloud Messaging (push) + Nodemailer (email) |
| Security   | bcrypt password hashing, JWT, helmet-style hardening, input validation |

---

## Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) `>= 3.38`
- [Node.js](https://nodejs.org) `>= 18`

### 1. Run the backend

```bash
cd backend
npm install
cp .env.example .env       # optional — server runs in mock mode without it
npm run dev                # or: npm start
```

> Without `.env`, the server runs in **mock mode**: Razorpay orders and FCM/email
> notifications are simulated and logged to the console — perfect for local development.

Run the API test suite:

```bash
npm test
```

### 2. Run the Flutter app

```bash
flutter pub get
flutter run
```

### 3. Run the widget tests

```bash
flutter test
```

> **Configuration:** the app talks to `http://10.0.2.2:3000` by default
> (Android emulator → host loopback). Point it elsewhere at build time, with no
> code change:
>
> ```bash
> flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
> ```
>
> Use an `https://` backend for anything beyond local testing: patient
> locations must not travel unencrypted. (Flutter's HTTP client does not apply
> Android's cleartext setting, so the app does not enforce this for you.)
>
> **"Server offline" in the app** means nothing answered at that address: start
> the backend (`cd backend && npm start`) and check `API_BASE_URL`. In debug
> builds, tap the status pill to see the exact URL the app is trying.

### Production checklist

- The backend **refuses to start** with `NODE_ENV=production` unless
  `JWT_SECRET` and `SUPPORT_EMAIL` are set (plus `RAZORPAY_KEY_ID` /
  `RAZORPAY_KEY_SECRET` if paid alerts are switched on). Mock payments are a
  development-only feature.
- Configure SMTP (`SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`): password-reset codes
  are emailed. Without SMTP, development servers print the code to the console.
- Public pages for the Play Console: `/privacy` (privacy policy) and
  `/delete-account` (web account deletion). See
  [docs/play-store/PLAY_CONSOLE_GUIDE.md](docs/play-store/PLAY_CONSOLE_GUIDE.md)
  for the Data safety answers and store listing text.
- Android release signing reads `android/key.properties` (git-ignored). Copy
  [`android/key.properties.example`](android/key.properties.example) and fill
  it in. Without it, release builds fall back to debug signing.

### Trying the hospital receiver desk

Sign out of a member session and sign back in on the **Hospital staff** tab. A
dev/test server seeds a duty desk for the first hospital:

```
duty@bahubali-hospital.com  /  elan-demo-2026
```

Sign-up also accepts new hospital staff, who pick their facility from the
hospital list. Hospital staff land in the receiver console; members land on the
dashboard. Seeding is skipped in production and can be disabled with
`SEED_RECEIVER_STAFF=false`.

**Staff accounts need approval.** Hospital staff can read patients' alerts,
phone numbers and live locations, so a self-registered staff account stays
locked until an admin approves it:

```
GET  /api/auth/staff/pending            # admin: list waiting accounts
POST /api/auth/staff/:id/approve        # admin: approve ({"approved": false} revokes)
```

Approval and revocation take effect immediately, with no re-login needed. The
seeded demo desk is pre-approved.

---

## Project Structure

```
├── android/               # Android platform config (bundle: com.elan.elan)
├── ios/                   # iOS platform config
├── assets/brand/          # Élan logo mark
├── assets/fonts/          # Manrope (brand typography)
├── backend/
│   ├── config/            # App config & env parsing
│   ├── models/            # SQLite schema + data access
│   ├── services/          # FCM, email (SMTP), Razorpay integration
│   ├── routes/            # Auth, hospitals, alerts, payments, records, receiver
│   └── server.js          # Express entry point
├── lib/
│   ├── main.dart          # Entry point + animated splash
│   ├── theme.dart         # Design system, brand mark, shared widgets
│   ├── models.dart        # Data models + local service layer
│   ├── screens.dart       # All screens & flows
│   └── services/          # API client, receiver sync, connectivity monitoring
├── docs/                  # Play Console guide, project report (PDF)
└── test/                  # Widget tests
```

Full API reference and deployment notes: [`backend/README.md`](backend/README.md).

---

## About the Name

**Élan** (pronounced *ay-LAHN*) is French for **spirit, momentum, and drive** — qualities that define both a beating heart and the split-second action Élan's emergency network delivers.

---

## Roadmap

- [x] Core SOS alert network dispatching to the nearest hospitals
- [x] Free alerts and alert history (Razorpay kept behind a flag)
- [x] Privacy policy, account deletion, password reset, safety notice
- [x] Patient records, vitals monitoring, and medical reports
- [x] Hospital-side receiver app with live acknowledgement feed
- [ ] Real-time ambulance ETA & route tracking
- [ ] Multilingual support (ES / FR / HI)

---

## License

[MIT](https://opensource.org/licenses/MIT) © Élan