# Play Console guide for Élan

What to enter in the Google Play Console, matching what the app and backend
actually do (checked against the code in October 2026). If the app changes —
for example push notifications, analytics, or paid alerts are switched on —
update these answers and the privacy policy (`backend/public/privacy.html`)
together.

> These answers describe the app's behaviour; they are not legal advice.
> Have someone qualified review the privacy policy and declarations before
> publishing a medical app.

## Links (App content → Privacy policy / Data safety)

Replace `https://YOUR-SERVER` with the HTTPS address the backend is deployed at.

| Field | Value |
|---|---|
| Privacy policy URL | `https://YOUR-SERVER/privacy` |
| Account deletion URL | `https://YOUR-SERVER/delete-account` |

The backend must run with `SUPPORT_EMAIL` (and ideally `ORGANIZATION_NAME`)
set; both pages show them, and production refuses to start without
`SUPPORT_EMAIL`.

## Data safety form

**Does your app collect or share any of the required user data types?** Yes.
**Is all of the user data collected by your app encrypted in transit?** Yes
(only true once the backend is served over HTTPS — do not publish before).
**Do you provide a way for users to request that their data is deleted?** Yes —
in-app (Profile → Delete account) and at the account deletion URL above.

### Data types

| Category → type | Collected | Shared | Optional? | Purposes |
|---|---|---|---|---|
| Location → **Precise location** | Yes | **Yes** — with the hospitals the user alerts | Required to send an alert | App functionality |
| Personal info → **Name** | Yes | **Yes** — with alerted hospitals | Required | App functionality, Account management |
| Personal info → **Email address** | Yes | No (hospital staff see their own) | Required | Account management, App functionality (password reset) |
| Personal info → **Phone number** | Yes | **Yes** — with alerted hospitals | Optional | App functionality |
| Health and fitness → **Health info** (symptoms, alert message, patient/vital/report records) | Yes | **Yes** — symptoms & message with alerted hospitals | Required for alerts; records optional | App functionality |
| App activity → **Other user-generated content** (alert history, hospital responses) | Yes | No | — | App functionality |

Not collected: financial info (while alerts are free; Razorpay would handle
card data if paid alerts are switched on), contacts, photos, messages, web
history, device IDs for tracking, analytics, crash logs (none integrated yet —
update this if you add crash reporting).

**Sharing note:** Google counts sending data to another party as "sharing".
Alerted hospitals are third parties, so location, name, phone and health info
are *shared*. Transfers to your own service providers (hosting, email
delivery) are not "sharing" for this form.

**Is data processed ephemerally?** No.

## Health apps declaration (App content → Health apps)

Select the features that apply:

- **Medical**: *Emergency / safety alerts* — the app notifies hospitals of a
  user's cardiac emergency with location and symptoms.
- **Health & fitness / Medical records**: the optional patient, vital-sign and
  report records.

Élan does **not** diagnose, treat or prescribe, and is not a regulated medical
device. The in-app safety notice (first launch) and the Emergency screen both
say that it does not replace calling 112.

## Store listing text (draft)

**App name:** Élan — Emergency Cardiac Alerts

**Short description (≤ 80 chars):**
Alert nearby hospitals in a cardiac emergency, with your location and symptoms.

**Full description:**

> Élan helps you get help faster in a cardiac emergency.
>
> Hold the SOS button to alert the nearest hospitals with your live location,
> your symptoms and a short message. Follow your alert as it happens: see when
> it is delivered, which hospital accepts it, and their estimated arrival time
> — with one tap to call the hospital or 112.
>
> For hospitals, Élan's duty desk shows incoming alerts in order of urgency,
> with one-tap acceptance and an arrival estimate the patient sees instantly.
>
> **Important: Élan does not replace emergency services.** If someone's life
> is in danger, call 112 (or 108 for an ambulance) first. Élan alerts nearby
> hospitals but cannot guarantee that a hospital responds or how quickly help
> arrives. Élan does not provide medical advice or diagnosis.
>
> • Hold-to-send SOS that guards against accidental alerts
> • Live alert tracker with hospital responses and ETA
> • One-tap calls to hospitals and 112
> • Your location is used only when you open the Emergency screen or send an alert
> • Delete your account and data at any time

**Category:** Medical. **Contact email:** the same address as `SUPPORT_EMAIL`.

## Other App content items

- **Target audience:** 18+ (the privacy policy says accounts are for adults).
- **Ads:** No ads.
- **Content rating questionnaire:** answer honestly; the app has no violence,
  user-to-user chat or gambling.
- **Government apps / Financial features:** No.
