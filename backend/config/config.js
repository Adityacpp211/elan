require('dotenv').config();

const isProduction = process.env.NODE_ENV === 'production';

// Settings that are safe to default in development but must never silently
// fall back in production: a guessable JWT secret lets anyone mint tokens, and
// without Razorpay keys the payment service would accept every payment.
if (isProduction) {
  const missing = ['JWT_SECRET', 'RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET']
    .filter((name) => !process.env[name]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables for production: ${missing.join(', ')}`);
  }
}

module.exports = {
  isProduction,
  port: process.env.PORT || 3000,
  jwtSecret: process.env.JWT_SECRET || 'elan-dev-secret-key',
  
  firebase: {
    serviceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './config/firebase-service-account.json'
  },
  
  razorpay: {
    keyId: process.env.RAZORPAY_KEY_ID,
    keySecret: process.env.RAZORPAY_KEY_SECRET
  },

  smtp: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || 'Élan <no-reply@elan.app>'
  },
  
  alertPricing: {
    tier1: parseInt(process.env.ALERT_TIER_1_PRICE) || 100,  // ₹1 in paise
    tier2: parseInt(process.env.ALERT_TIER_2_PRICE) || 200,  // ₹2 in paise
    tier3: parseInt(process.env.ALERT_TIER_3_PRICE) || 300   // ₹3 in paise
  },
  
  // Number of hospitals to notify per tier
  hospitalCountPerTier: {
    tier1: 1,
    tier2: 3,
    tier3: 10  // All nearby hospitals
  },

  // Radius (km) searched when picking which hospitals an alert goes to
  alertRadiusKm: 15,

  // Demo hospital-staff account (dev/test only, never in production)
  seedReceiverStaff: process.env.SEED_RECEIVER_STAFF !== 'false',
  seedReceiverEmail: process.env.SEED_RECEIVER_EMAIL || '',
  seedReceiverPassword: process.env.SEED_RECEIVER_PASSWORD || '',
  seedReceiverHospitalId: process.env.SEED_RECEIVER_HOSPITAL_ID || ''
};
