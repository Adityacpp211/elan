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

- **One-tap SOS** — Send an emergency alert with pre-selected symptoms and your live GPS location in a single tap.
- **Tiered response** — Choose how wide the net goes: 1, 3, or up to 10 nearby hospitals notified per alert.
- **Location-aware hospitals** — GPS-driven search surfaces verified hospitals ranked by distance, backed by a live hospital database on the backend.
- **Secure payments** — Tiered alert pricing with a **wallet** system and the **Razorpay** gateway for real transactions.
- **Hospital alert feed** — Track every alert you've sent, its status, and which hospitals acknowledged it.
- **Patient records** — Manage patient profiles with admission details, blood type, room, and condition.
- **Vitals monitoring** — Log and view heart rate, blood pressure, temperature, and oxygen saturation over time.
- **Medical reports** — Store and review report documents per patient.
- **Offline-first** — Local data store keeps the core experience working even when the server is unreachable; syncs when back online.
- **Live server status** — On-device connectivity indicator that pings the backend and shows online/synced or offline/local.
- **Dark-first design system** — A crafted dark UI with a custom design language (Space Grotesk + Manrope, material-you inspired tokens).

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
│  Local SQLite    │                      │   SQLite (sql.js)         │
│  (offline cache) │                      │   persistent data store   │
└──────────────────┘                      └───────────────────────────┘
```

**Flow of an emergency:**

1. User taps **Send Alert** and picks a response tier.
2. The app resolves the user's GPS location and the nearest hospitals.
3. The backend creates a payment order (wallet or Razorpay) and verifies it.
4. Notified hospitals receive an **FCM push** and an **email** with symptoms, exact coordinates, and a Google Maps deep link.
5. The alert is logged to history with live status and acknowledgement tracking.

---

## Tech Stack

| Layer      | Technology |
|------------|------------|
| Mobile     | Flutter / Dart — custom dark theme, geolocation, offline cache |
| Backend    | Node.js / Express — JWT auth, role-based access, rate limiting |
| Database   | SQLite (`sql.js`) — persistent, file-based, test-isolated |
| Payments   | Razorpay — real gateway + in-app wallet |
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
> (Android emulator → host loopback). Point [`lib/services/api_service.dart`](lib/services/api_service.dart)
> at your backend URL for a physical device.

---

## Project Structure

```
├── android/               # Android platform config (bundle: com.elan.elan)
├── ios/                   # iOS platform config
├── assets/fonts/          # Space Grotesk + Manrope (brand typography)
├── backend/
│   ├── config/            # App config & env parsing
│   ├── models/            # SQLite schema + data access
│   ├── services/          # FCM, email (SMTP), Razorpay integration
│   ├── routes/            # Auth, hospitals, alerts, payments, records
│   └── server.js          # Express entry point
├── lib/
│   ├── main.dart          # Entry point + animated splash
│   ├── theme.dart         # Design system, brand mark, shared widgets
│   ├── models.dart        # Data models + local service layer
│   ├── screens.dart       # All screens & flows
│   └── services/          # API client + connectivity monitoring
└── test/                  # Widget tests
```

Full API reference and deployment notes: [`backend/README.md`](backend/README.md).

---

## About the Name

**Élan** (pronounced *ay-LAHN*) is French for **spirit, momentum, and drive** — qualities that define both a beating heart and the split-second action Élan's emergency network delivers.

---

## Roadmap

- [x] Core SOS alert network with tiered hospital dispatch
- [x] Payments (wallet + Razorpay) and alert history
- [x] Patient records, vitals monitoring, and medical reports
- [ ] Hospital-side receiver app with live acknowledgement feed
- [ ] Real-time ambulance ETA & route tracking
- [ ] Multilingual support (ES / FR / HI)

---

## License

[MIT](https://opensource.org/licenses/MIT) © Élan