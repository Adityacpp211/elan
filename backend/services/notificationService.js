const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const config = require('../config/config');
const fs = require('fs');
const path = require('path');

let isInitialized = false;
let transporter = null;

// Initialize Firebase Admin SDK
function initializeFirebase() {
    if (isInitialized) return true;

    try {
        const serviceAccountPath = path.resolve(__dirname, '..', config.firebase.serviceAccountPath);

        if (!fs.existsSync(serviceAccountPath)) {
            console.warn('⚠️ Firebase service account not found. FCM notifications disabled.');
            console.warn(`  Expected path: ${serviceAccountPath}`);
            console.warn('  Download from: Firebase Console > Project Settings > Service Accounts');
            return false;
        }

        const serviceAccount = require(serviceAccountPath);

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        isInitialized = true;
        console.log('✅ Firebase Admin SDK initialized');
        return true;
    } catch (error) {
        console.error('❌ Firebase initialization error:', error.message);
        return false;
    }
}

// Initialize SMTP transporter for email alerts
function initializeTransporter() {
    if (transporter) return true;

    if (!config.smtp.host || !config.smtp.user || !config.smtp.pass) {
        console.warn('⚠️ SMTP not configured. Email alerts disabled (mock mode).');
        console.warn('  Set SMTP_HOST, SMTP_USER, and SMTP_PASS in .env to enable.');
        return false;
    }

    try {
        transporter = nodemailer.createTransport({
            host: config.smtp.host,
            port: config.smtp.port,
            secure: config.smtp.secure,
            auth: {
                user: config.smtp.user,
                pass: config.smtp.pass
            }
        });
        console.log('✅ SMTP transporter initialized');
        return true;
    } catch (error) {
        console.error('❌ SMTP initialization error:', error.message);
        return false;
    }
}

// Send an email alert
async function sendEmail(to, subject, html) {
    if (!transporter && !initializeTransporter()) {
        console.log('📧 [Mock Email] Would send to:', to, { subject });
        return { success: true, mock: true };
    }

    try {
        const info = await transporter.sendMail({
            from: config.smtp.from,
            to,
            subject,
            html
        });
        console.log('✅ Email sent:', info.messageId, '->', to);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error('❌ Email send error:', error.message);
        return { success: false, error: error.message };
    }
}

// Send notification to a specific device token
async function sendToDevice(fcmToken, title, body, data = {}) {
    if (!initializeFirebase()) {
        console.log('📱 [Mock FCM] Would send to device:', { title, body, data });
        return { success: true, mock: true };
    }

    try {
        const message = {
            notification: {
                title,
                body
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            token: fcmToken
        };

        const response = await admin.messaging().send(message);
        console.log('✅ FCM notification sent:', response);
        return { success: true, messageId: response };
    } catch (error) {
        console.error('❌ FCM send error:', error.message);
        return { success: false, error: error.message };
    }
}

// Send notification to a topic (for hospital groups)
async function sendToTopic(topic, title, body, data = {}) {
    if (!initializeFirebase()) {
        console.log('📱 [Mock FCM] Would send to topic:', topic, { title, body, data });
        return { success: true, mock: true };
    }

    try {
        const message = {
            notification: {
                title,
                body
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            topic: topic
        };

        const response = await admin.messaging().send(message);
        console.log(`✅ FCM topic notification sent to ${topic}:`, response);
        return { success: true, messageId: response };
    } catch (error) {
        console.error('❌ FCM topic send error:', error.message);
        return { success: false, error: error.message };
    }
}

// Subscribe device to a topic
async function subscribeToTopic(fcmToken, topic) {
    if (!initializeFirebase()) {
        console.log('📱 [Mock FCM] Would subscribe to topic:', topic);
        return { success: true, mock: true };
    }

    try {
        const response = await admin.messaging().subscribeToTopic(fcmToken, topic);
        console.log(`✅ Subscribed to topic ${topic}:`, response);
        return { success: true };
    } catch (error) {
        console.error('❌ Topic subscription error:', error.message);
        return { success: false, error: error.message };
    }
}

// Send emergency alert to multiple hospitals
async function sendEmergencyAlert(hospitals, alertData) {
    const results = [];

    for (const hospital of hospitals) {
        const title = '🚨 CARDIAC EMERGENCY ALERT';
        const body = `Patient needs help! Location: ${alertData.userLatitude.toFixed(4)}, ${alertData.userLongitude.toFixed(4)}. Distance: ${hospital.distance_km?.toFixed(2) || 'N/A'} km`;

        const data = {
            alertId: alertData.id,
            type: 'emergency_cardiac',
            symptoms: alertData.symptoms || '',
            userLatitude: String(alertData.userLatitude),
            userLongitude: String(alertData.userLongitude),
            timestamp: new Date().toISOString()
        };

        // Try to send via FCM topic for this hospital
        const result = await sendToTopic(`hospital_${hospital.id}`, title, body, data);

        // Also send an email alert to the hospital emergency inbox
        let emailResult = { sent: false, mock: false };
        if (hospital.emergency_email) {
            emailResult = await sendEmergencyEmail(hospital, alertData);
        }

        results.push({
            hospitalId: hospital.id,
            hospitalName: hospital.name,
            ...result,
            email: {
                sent: emailResult.success === true,
                mock: emailResult.mock || false,
                to: hospital.emergency_email || '',
                ...(emailResult.error ? { error: emailResult.error } : {})
            }
        });
    }

    return results;
}

// Build and send the emergency alert email to a hospital
async function sendEmergencyEmail(hospital, alertData) {
    const googleMapsUrl = `https://www.google.com/maps?q=${alertData.userLatitude},${alertData.userLongitude}`;
    const subject = `🚨 CARDIAC EMERGENCY ALERT${alertData.userName ? ` - ${alertData.userName}` : ''}`;

    const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; max-width: 640px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
      <div style="background-color: #c62828; color: #ffffff; padding: 16px 24px;">
        <h1 style="margin: 0; font-size: 20px;">🚨 CARDIAC EMERGENCY ALERT</h1>
      </div>
      <div style="padding: 24px;">
        <p>Hi <strong>${hospital.name}</strong>,</p>
        <p>A cardiac emergency has been reported near you. The following details have been shared by the patient:</p>
        <table style="border-collapse: collapse; width: 100%; margin: 16px 0;">
          ${alertData.userName ? `<tr><td style="padding: 8px; border: 1px solid #e0e0e0; background:#fafafa;"><strong>Patient</strong></td><td style="padding: 8px; border: 1px solid #e0e0e0;">${alertData.userName}</td></tr>` : ''}
          ${alertData.symptoms ? `<tr><td style="padding: 8px; border: 1px solid #e0e0e0; background:#fafafa;"><strong>Symptoms</strong></td><td style="padding: 8px; border: 1px solid #e0e0e0;">${alertData.symptoms}</td></tr>` : ''}
          ${alertData.message ? `<tr><td style="padding: 8px; border: 1px solid #e0e0e0; background:#fafafa;"><strong>Message</strong></td><td style="padding: 8px; border: 1px solid #e0e0e0;">${alertData.message}</td></tr>` : ''}
          <tr><td style="padding: 8px; border: 1px solid #e0e0e0; background:#fafafa;"><strong>Location</strong></td><td style="padding: 8px; border: 1px solid #e0e0e0;">${alertData.userLatitude.toFixed(6)}, ${alertData.userLongitude.toFixed(6)}</td></tr>
        </table>
        <p style="margin-bottom: 24px;">
          <a href="${googleMapsUrl}" style="background-color: #c62828; color: #ffffff; text-decoration: none; padding: 10px 20px; border-radius: 4px; display: inline-block;">Open in Google Maps</a>
        </p>
        <p style="color: #757575; font-size: 12px;">This is an automated message from the CardioAid Emergency Cardiac Care System. Please prepare your emergency response team.</p>
      </div>
    </div>
    `;

    return sendEmail(hospital.emergency_email, subject, html);
}

module.exports = {
    initializeFirebase,
    initializeTransporter,
    sendToDevice,
    sendToTopic,
    subscribeToTopic,
    sendEmail,
    sendEmergencyAlert,
    sendEmergencyEmail
};
