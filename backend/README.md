# Élan Backend

Backend server for the Élan Emergency Cardiac Care System.

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Start server
npm start

# Or with auto-reload (development)
npm run dev

# Run the test suite
npm test
```

> Without `.env`, the server runs in **mock mode**: Razorpay orders/payments and
> FCM/email notifications are simulated and logged to the console.

## API Endpoints

### Authentication
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| `POST` | `/api/auth/register` | Register new user | ❌ |
| `POST` | `/api/auth/login` | Login user | ❌ |
| `POST` | `/api/auth/location` | Update user location | ✅ |
| `POST` | `/api/auth/fcm-token` | Update FCM token | ✅ |
| `GET` | `/api/auth/me` | Get profile | ✅ |
| `PUT` | `/api/auth/me` | Update profile | ✅ |

### Hospitals
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| `GET` | `/api/hospitals/nearby?lat=X&lng=Y` | Find nearby hospitals | ❌ |
| `GET` | `/api/hospitals` | List active hospitals | ❌ |
| `GET` | `/api/hospitals/:id` | Get hospital by id | ❌ |
| `POST` | `/api/hospitals` | Create hospital | ✅ Admin |
| `PUT` | `/api/hospitals/:id` | Update hospital | ✅ Admin |
| `DELETE` | `/api/hospitals/:id` | Deactivate hospital (soft delete) | ✅ Admin |

### Payments
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| `POST` | `/api/payments/create-order` | Create payment order | ✅ |
| `POST` | `/api/payments/verify` | Verify payment | ✅ |
| `GET` | `/api/payments/history` | Payment history | ✅ |

### Alerts
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| `POST` | `/api/alerts/send` | Send emergency alert | ✅ |
| `GET` | `/api/alerts/history` | Get alert history | ✅ |
| `GET` | `/api/alerts/:id` | Get alert details | ✅ |

### Patient Records (medical data)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET/POST` | `/api/records/patients` | List / create patients |
| `PUT/DELETE` | `/api/records/patients/:id` | Update / delete patient |
| `GET/POST` | `/api/records/vitals` | List / create vital readings |
| `DELETE` | `/api/records/vitals/:id` | Delete vital reading |
| `GET/POST` | `/api/records/reports` | List / create medical reports |
| `DELETE` | `/api/records/reports/:id` | Delete report |

## Configuration

Edit `.env` file:

```bash
# Server
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-change-this

# Firebase (for FCM notifications)
# Download service account JSON from Firebase Console
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json

# Razorpay
RAZORPAY_KEY_ID=rzp_test_xxxxx
RAZORPAY_KEY_SECRET=your_secret

# SMTP (for hospital email alerts) - leave blank for mock mode
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=Élan <no-reply@elan.app>

# Alert pricing (in paise - 100 paise = 1 INR)
ALERT_TIER_1_PRICE=100
ALERT_TIER_2_PRICE=200
ALERT_TIER_3_PRICE=300
```

## Alert Tiers

| Tier | Price | Hospitals Notified |
|------|-------|--------------------|
| 1 | ₹1 | 1 hospital |
| 2 | ₹2 | 3 hospitals |
| 3 | ₹3 | All nearby (up to 10) |

## Test Database

Tests run against an isolated SQLite file in the OS temp directory (set via
`ELAN_DB_PATH`) — the production `data/elan.db` is left untouched.

## Security

- JWT auth with role claims (`member` / `admin`); admin routes are protected via `requireRole('admin')`
- Rate limiting on auth (20/15min), emergency (15/min), and general API (300/15min) routes
- Input validation for coordinates and tiers
- Payment verification binds the payment order to its alert and checks alert ownership
- bcrypt password hashing (10 rounds)