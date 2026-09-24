# Free Firebase Cloud Messaging (FCM) Setup Guide

Firebase Cloud Messaging is **completely FREE** with no message limits. Here's how to set it up:

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"** (or "Add project")
3. Enter project name: `Élan` (any name works)
4. **Disable** Google Analytics (not needed, keeps it simpler)
5. Click **Create project**
6. Wait for project creation → Click **Continue**

---

## Step 2: Add Android App

1. On project dashboard, click **Android icon** (🤖)
2. Enter Android package name: `com.elan.elan`
   - Find this in `android/app/build.gradle` under `applicationId`
3. App nickname: `Élan` (optional)
4. Debug signing certificate: Skip for now (optional)
5. Click **Register app**
6. Download `google-services.json`
7. Place it in: `c:\cardio_aid\android\app\google-services.json`

---

## Step 3: Configure Android Project

### 3.1 Update `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        // Add this line:
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### 3.2 Update `android/app/build.gradle`:
```gradle
// Add at the bottom of the file:
apply plugin: 'com.google.gms.google-services'
```

---

## Step 4: Get Service Account for Backend

1. In Firebase Console → Click ⚙️ (Settings gear) → **Project settings**
2. Go to **Service accounts** tab
3. Click **Generate new private key**
4. Download the JSON file
5. Rename to `firebase-service-account.json`
6. Place in: `c:\cardio_aid\backend\config\firebase-service-account.json`

---

## Step 5: Update Backend .env

Create `c:\cardio_aid\backend\.env`:
```
PORT=3000
JWT_SECRET=your-secret-key-here-make-it-long

# Firebase
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json

# Razorpay (optional - wallet system bypasses this)
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
```

---

## Step 6: Test the Setup

1. Start backend:
```bash
cd c:\cardio_aid\backend
npm start
```

You should see:
```
✅ Firebase Admin SDK initialized
```

If you see this instead, Firebase is running in mock mode (notifications logged but not sent):
```
⚠️ Firebase service account not found. FCM notifications disabled.
```

---

## How It Works

1. **User sends alert** → Backend receives request
2. Backend → **Firebase Cloud Messaging** → Hospital devices
3. Hospitals receive push notification with patient location

---

## Cost: **₹0 (FREE)**

| Feature | Limit | Cost |
|---------|-------|------|
| FCM Messages | **Unlimited** | FREE |
| Firebase Projects | Up to 25 | FREE |
| Cloud Functions | 2M calls/month | FREE |

---

## Alternative: Without Firebase (Local Only)

If you don't want to set up Firebase, the app still works:
- Wallet payments ✅
- Local alert storage ✅
- Hospital list display ✅

Just notifications won't be sent to hospitals (they would need a receiver app with FCM).

---

## Need Help?

Firebase documentation: https://firebase.google.com/docs/cloud-messaging
