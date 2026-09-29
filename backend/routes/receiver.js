const express = require('express');
const Alert = require('../models/Alert');
const Hospital = require('../models/Hospital');
const notificationService = require('../services/notificationService');
const { authMiddleware, requireRole } = require('../middleware/auth');
const { isValidCoordinates } = require('../utils/validation');

const router = express.Router();

// Every route below is scoped to the signed-in hospital staff member's facility.
router.use(authMiddleware, requireRole('hospital', 'admin'));

/// Resolve the hospital a request is acting on behalf of.
function resolveHospital(req, res) {
    if (req.user.role === 'admin' && req.query.hospitalId) {
        const hospital = Hospital.findById(req.query.hospitalId);
        if (!hospital) {
            res.status(404).json({ error: 'Hospital not found' });
            return null;
        }
        return hospital;
    }

    const hospitalId = req.user.hospitalId;
    if (!hospitalId) {
        res.status(403).json({ error: 'This account is not linked to a hospital' });
        return null;
    }

    const hospital = Hospital.findById(hospitalId);
    if (!hospital) {
        res.status(404).json({ error: 'Hospital not found' });
        return null;
    }
    return hospital;
}

function shapeAlert(row, hospital) {
    const distanceKm = isValidCoordinates(hospital.latitude, hospital.longitude)
        ? Math.round(
            Hospital.calculateDistance(
                hospital.latitude,
                hospital.longitude,
                row.user_latitude,
                row.user_longitude
            ) * 100
        ) / 100
        : null;

    const symptoms = (row.symptoms || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);

    const status = row.acknowledged === 1
        ? 'acknowledged'
        : row.declined === 1
            ? 'declined'
            : 'pending';

    return {
        id: row.id,
        status,
        symptoms,
        message: row.message || '',
        tier: row.charge_tier,
        patientName: row.patient_name || 'Anonymous',
        patientPhone: row.patient_phone || '',
        location: {
            latitude: row.user_latitude,
            longitude: row.user_longitude,
            mapsUrl: `https://www.google.com/maps/search/?api=1&query=${row.user_latitude},${row.user_longitude}`
        },
        distanceKm,
        etaMinutes: row.eta_minutes,
        declineReason: row.decline_reason,
        notified: row.notification_sent === 1,
        sentAt: row.sent_at,
        acknowledgedAt: row.acknowledged_at,
        declinedAt: row.declined_at,
        respondedBy: row.responded_by,
        createdAt: row.created_at
    };
}

function hospitalSummary(hospital) {
    return {
        id: hospital.id,
        name: hospital.name,
        address: hospital.address,
        phone: hospital.phone,
        latitude: hospital.latitude,
        longitude: hospital.longitude
    };
}

// ==================== RECEIVER INBOX ====================

// GET /api/receiver/inbox - Alerts addressed to this hospital, newest first
router.get('/inbox', (req, res) => {
    try {
        const hospital = resolveHospital(req, res);
        if (!hospital) return;

        const status = req.query.status;
        if (status && !['pending', 'acknowledged', 'declined', 'all'].includes(status)) {
            return res.status(400).json({ error: 'Invalid status filter' });
        }

        const limit = Math.min(parseInt(req.query.limit) || 50, 100);
        const rows = Alert.findByHospitalId(hospital.id, { limit });
        const alerts = rows.map((row) => shapeAlert(row, hospital));

        res.json({
            hospital: hospitalSummary(hospital),
            stats: Alert.statsForHospital(hospital.id),
            alerts: status && status !== 'all'
                ? alerts.filter((a) => a.status === status)
                : alerts
        });
    } catch (error) {
        console.error('Receiver inbox error:', error);
        res.status(500).json({ error: 'Failed to fetch receiver inbox' });
    }
});

// GET /api/receiver/inbox/:alertId - Single alert detail
router.get('/inbox/:alertId', (req, res) => {
    try {
        const hospital = resolveHospital(req, res);
        if (!hospital) return;

        const row = Alert.findForReceiver(req.params.alertId, hospital.id);
        if (!row) {
            return res.status(404).json({ error: 'Alert not found for this hospital' });
        }

        res.json({
            alert: shapeAlert(row, hospital),
            hospital: hospitalSummary(hospital)
        });
    } catch (error) {
        console.error('Receiver alert detail error:', error);
        res.status(500).json({ error: 'Failed to fetch alert' });
    }
});

// ==================== RESPONSES ====================

// POST /api/receiver/alerts/:alertId/acknowledge - Take the alert
router.post('/alerts/:alertId/acknowledge', async (req, res) => {
    try {
        const hospital = resolveHospital(req, res);
        if (!hospital) return;

        const { etaMinutes } = req.body || {};

        if (etaMinutes !== undefined && etaMinutes !== null) {
            const eta = Number(etaMinutes);
            if (!Number.isInteger(eta) || eta < 0 || eta > 240) {
                return res.status(400).json({ error: 'etaMinutes must be a whole number between 0 and 240' });
            }
        }

        const row = Alert.findForReceiver(req.params.alertId, hospital.id);
        if (!row) {
            return res.status(404).json({ error: 'Alert not found for this hospital' });
        }

        const updated = Alert.respondToAlert(req.params.alertId, hospital.id, {
            action: 'acknowledge',
            etaMinutes: etaMinutes === undefined || etaMinutes === null ? null : Number(etaMinutes),
            respondedBy: req.user.email
        });

        const alert = Alert.syncStatusFromResponses(req.params.alertId);

        // Let the member know someone is on the way.
        const notification = await notificationService.sendResponseUpdate({
            userId: row.user_id,
            alertId: row.id,
            hospital,
            acknowledged: true,
            etaMinutes: updated?.eta_minutes ?? null
        });

        res.json({
            success: true,
            message: 'Alert acknowledged',
            alert: shapeAlert(updated, hospital),
            alertStatus: alert?.status || 'sent',
            notifiedPatient: notification
        });
    } catch (error) {
        console.error('Acknowledge alert error:', error);
        res.status(500).json({ error: 'Failed to acknowledge alert' });
    }
});

// POST /api/receiver/alerts/:alertId/decline - Pass the alert on
router.post('/alerts/:alertId/decline', async (req, res) => {
    try {
        const hospital = resolveHospital(req, res);
        if (!hospital) return;

        const { reason } = req.body || {};
        if (reason !== undefined && reason !== null && String(reason).trim().length === 0) {
            return res.status(400).json({ error: 'reason cannot be empty' });
        }

        const row = Alert.findForReceiver(req.params.alertId, hospital.id);
        if (!row) {
            return res.status(404).json({ error: 'Alert not found for this hospital' });
        }

        const updated = Alert.respondToAlert(req.params.alertId, hospital.id, {
            action: 'decline',
            reason: reason ? String(reason).trim() : null,
            respondedBy: req.user.email
        });

        const alert = Alert.syncStatusFromResponses(req.params.alertId);

        const notification = await notificationService.sendResponseUpdate({
            userId: row.user_id,
            alertId: row.id,
            hospital,
            acknowledged: false,
            reason: updated?.decline_reason ?? null
        });

        res.json({
            success: true,
            message: 'Alert declined',
            alert: shapeAlert(updated, hospital),
            alertStatus: alert?.status || 'sent',
            notifiedPatient: notification
        });
    } catch (error) {
        console.error('Decline alert error:', error);
        res.status(500).json({ error: 'Failed to decline alert' });
    }
});

// GET /api/receiver/profile - The facility this staff member works for
router.get('/profile', (req, res) => {
    try {
        const hospital = resolveHospital(req, res);
        if (!hospital) return;

        res.json({
            hospital: hospitalSummary(hospital),
            staff: {
                email: req.user.email,
                role: req.user.role
            },
            stats: Alert.statsForHospital(hospital.id)
        });
    } catch (error) {
        console.error('Receiver profile error:', error);
        res.status(500).json({ error: 'Failed to fetch receiver profile' });
    }
});

module.exports = router;
