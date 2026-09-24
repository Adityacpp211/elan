const express = require('express');
const Alert = require('../models/Alert');
const Payment = require('../models/Payment');
const Hospital = require('../models/Hospital');
const User = require('../models/User');
const notificationService = require('../services/notificationService');
const paymentService = require('../services/paymentService');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// Send emergency alert (after payment verification)
router.post('/send', authMiddleware, async (req, res) => {
    try {
        const { alertId } = req.body;

        if (!alertId) {
            return res.status(400).json({ error: 'alertId is required' });
        }

        // Get alert
        const alert = Alert.findById(alertId);
        if (!alert) {
            return res.status(404).json({ error: 'Alert not found' });
        }

        // Verify alert belongs to user
        if (alert.user_id !== req.user.userId) {
            return res.status(403).json({ error: 'Unauthorized' });
        }

        // Check payment status
        const payment = Payment.findByAlertId(alertId);
        if (!payment || payment.status !== 'completed') {
            return res.status(400).json({
                error: 'Payment not completed. Complete payment first.',
                paymentStatus: payment?.status || 'not found'
            });
        }

        // Check if alert already sent
        if (alert.status === 'sent') {
            return res.status(400).json({ error: 'Alert already sent' });
        }

        // Get hospitals to notify based on tier
        const hospitalCount = paymentService.getHospitalCountForTier(alert.charge_tier);
        const hospitals = Hospital.findNearby(
            alert.user_latitude,
            alert.user_longitude,
            15, // 15km radius
            hospitalCount
        );

        if (hospitals.length === 0) {
            return res.status(404).json({ error: 'No hospitals found nearby' });
        }

        // Get user info
        const user = User.findById(req.user.userId);

        // Prepare alert data for notifications
        const alertData = {
            id: alert.id,
            symptoms: alert.symptoms,
            message: alert.message,
            userLatitude: alert.user_latitude,
            userLongitude: alert.user_longitude,
            userName: user?.name || 'Anonymous',
            tier: alert.charge_tier
        };

        // Link hospitals to alert
        for (const hospital of hospitals) {
            Alert.addHospital(alert.id, hospital.id);
        }

        // Send notifications via FCM
        const results = await notificationService.sendEmergencyAlert(hospitals, alertData);

        // Mark notifications as sent
        for (const result of results) {
            if (result.success) {
                Alert.markNotificationSent(alert.id, result.hospitalId);
            }
        }

        // Update alert status
        Alert.updateStatus(alertId, 'sent');

        res.json({
            success: true,
            message: 'Emergency alert sent successfully',
            alertId,
            hospitalsNotified: results.length,
            hospitals: results.map(r => ({
                id: r.hospitalId,
                name: r.hospitalName,
                notificationSent: r.success,
                mock: r.mock || false,
                emailSent: r.email?.sent || false,
                emailMock: r.email?.mock || false
            }))
        });
    } catch (error) {
        console.error('Send alert error:', error);
        res.status(500).json({ error: 'Failed to send alert' });
    }
});

// Get user's alert history
router.get('/history', authMiddleware, (req, res) => {
    try {
        const alerts = Alert.findByUserId(req.user.userId);

        const history = alerts.map(alert => {
            const hospitals = Alert.getAlertHospitals(alert.id);
            const payment = Payment.findByAlertId(alert.id);

            return {
                id: alert.id,
                symptoms: alert.symptoms,
                message: alert.message,
                tier: alert.charge_tier,
                location: {
                    latitude: alert.user_latitude,
                    longitude: alert.user_longitude
                },
                status: alert.status,
                paymentStatus: payment?.status || 'N/A',
                hospitalsNotified: hospitals.length,
                hospitals: hospitals.map(h => ({
                    name: h.hospital_name,
                    phone: h.hospital_phone,
                    notificationSent: h.notification_sent === 1,
                    acknowledged: h.acknowledged === 1
                })),
                createdAt: alert.created_at
            };
        });

        res.json({ alerts: history });
    } catch (error) {
        console.error('Alert history error:', error);
        res.status(500).json({ error: 'Failed to fetch alert history' });
    }
});

// Get single alert details
router.get('/:id', authMiddleware, (req, res) => {
    try {
        const alert = Alert.findById(req.params.id);

        if (!alert) {
            return res.status(404).json({ error: 'Alert not found' });
        }

        if (alert.user_id !== req.user.userId) {
            return res.status(403).json({ error: 'Unauthorized' });
        }

        const hospitals = Alert.getAlertHospitals(alert.id);
        const payment = Payment.findByAlertId(alert.id);

        res.json({
            id: alert.id,
            symptoms: alert.symptoms,
            message: alert.message,
            tier: alert.charge_tier,
            location: {
                latitude: alert.user_latitude,
                longitude: alert.user_longitude
            },
            status: alert.status,
            payment: payment ? {
                status: payment.status,
                amount: `₹${payment.amount_paise / 100}`
            } : null,
            hospitals: hospitals.map(h => ({
                name: h.hospital_name,
                phone: h.hospital_phone,
                notificationSent: h.notification_sent === 1,
                sentAt: h.sent_at,
                acknowledged: h.acknowledged === 1,
                acknowledgedAt: h.acknowledged_at
            })),
            createdAt: alert.created_at
        });
    } catch (error) {
        console.error('Get alert error:', error);
        res.status(500).json({ error: 'Failed to fetch alert' });
    }
});

module.exports = router;
