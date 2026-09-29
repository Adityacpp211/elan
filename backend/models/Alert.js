const { all, get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

class Alert {
    static create(data) {
        const id = uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO alerts (id, user_id, symptoms, message, charge_tier, user_latitude, user_longitude, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                id,
                data.userId,
                data.symptoms || '',
                data.message || '',
                data.chargeTier,
                data.userLatitude,
                data.userLongitude,
                'pending',
                now
            ]
        );
        return this.findById(id);
    }

    static findById(id) {
        return get('SELECT * FROM alerts WHERE id = ?', [id]);
    }

    static findByUserId(userId) {
        return all('SELECT * FROM alerts WHERE user_id = ? ORDER BY created_at DESC', [userId]);
    }

    static updateStatus(id, status) {
        run('UPDATE alerts SET status = ? WHERE id = ?', [status, id]);
        return this.findById(id);
    }

    static addHospital(alertId, hospitalId) {
        // A hospital is only ever linked to an alert once.
        const existing = get(
            'SELECT id FROM alert_hospitals WHERE alert_id = ? AND hospital_id = ?',
            [alertId, hospitalId]
        );
        if (existing) return existing.id;

        const id = uuidv4();
        run(
            `INSERT INTO alert_hospitals (id, alert_id, hospital_id) VALUES (?, ?, ?)`,
            [id, alertId, hospitalId]
        );
        return id;
    }

    static markNotificationSent(alertId, hospitalId) {
        const now = new Date().toISOString();
        run(
            `UPDATE alert_hospitals SET notification_sent = 1, sent_at = ? WHERE alert_id = ? AND hospital_id = ?`,
            [now, alertId, hospitalId]
        );
    }

    static getAlertHospitals(alertId) {
        return all(
            `SELECT ah.*, h.name as hospital_name, h.phone as hospital_phone
       FROM alert_hospitals ah
       JOIN hospitals h ON ah.hospital_id = h.id
       WHERE ah.alert_id = ?`,
            [alertId]
        );
    }

    static acknowledgeAlert(alertId, hospitalId) {
        const now = new Date().toISOString();
        run(
            `UPDATE alert_hospitals SET acknowledged = 1, acknowledged_at = ? WHERE alert_id = ? AND hospital_id = ?`,
            [now, alertId, hospitalId]
        );
    }

    // ==================== HOSPITAL RECEIVER ====================

    /// The receiver's view of one alert, joined with the patient who raised it.
    static findForReceiver(alertId, hospitalId) {
        return get(
            `SELECT a.*, ah.acknowledged, ah.acknowledged_at, ah.declined,
                    ah.declined_at, ah.decline_reason, ah.eta_minutes,
                    ah.notification_sent, ah.sent_at, ah.responded_by, ah.responded_at,
                    u.name AS patient_name, u.phone AS patient_phone
       FROM alert_hospitals ah
       JOIN alerts a ON a.id = ah.alert_id
       LEFT JOIN users u ON u.id = a.user_id
       WHERE ah.alert_id = ? AND ah.hospital_id = ?`,
            [alertId, hospitalId]
        );
    }

    /// Every alert addressed to a hospital, newest first.
    static findByHospitalId(hospitalId, { limit = 50 } = {}) {
        return all(
            `SELECT a.*, ah.acknowledged, ah.acknowledged_at, ah.declined,
                    ah.declined_at, ah.decline_reason, ah.eta_minutes,
                    ah.notification_sent, ah.sent_at, ah.responded_by, ah.responded_at,
                    u.name AS patient_name, u.phone AS patient_phone
       FROM alert_hospitals ah
       JOIN alerts a ON a.id = ah.alert_id
       LEFT JOIN users u ON u.id = a.user_id
       WHERE ah.hospital_id = ?
       ORDER BY a.created_at DESC
       LIMIT ?`,
            [hospitalId, limit]
        );
    }

    static respondToAlert(alertId, hospitalId, response) {
        const now = new Date().toISOString();
        if (response.action === 'decline') {
            run(
                `UPDATE alert_hospitals
         SET declined = 1, declined_at = ?, decline_reason = ?, acknowledged = 0,
             acknowledged_at = NULL, responded_by = ?, responded_at = ?
         WHERE alert_id = ? AND hospital_id = ?`,
                [now, response.reason || null, response.respondedBy || null, now, alertId, hospitalId]
            );
        } else {
            run(
                `UPDATE alert_hospitals
         SET acknowledged = 1, acknowledged_at = ?, eta_minutes = ?, declined = 0,
             declined_at = NULL, decline_reason = NULL, responded_by = ?, responded_at = ?
         WHERE alert_id = ? AND hospital_id = ?`,
                [now, response.etaMinutes ?? null, response.respondedBy || null, now, alertId, hospitalId]
            );
        }
        return this.findForReceiver(alertId, hospitalId);
    }

    /// Roll the parent alert up from its hospital responses so the member app
    /// can show whether anyone picked the emergency up.
    static syncStatusFromResponses(alertId) {
        const responses = all(
            `SELECT acknowledged, declined FROM alert_hospitals WHERE alert_id = ?`,
            [alertId]
        );
        if (responses.length === 0) return this.findById(alertId);

        const alert = this.findById(alertId);
        if (!alert) return null;
        if (alert.status !== 'sent') return alert;

        const acknowledged = responses.some((r) => r.acknowledged === 1);
        if (acknowledged) {
            return this.updateStatus(alertId, 'acknowledged');
        }

        const allDeclined = responses.every((r) => r.declined === 1);
        if (allDeclined) {
            return this.updateStatus(alertId, 'unacknowledged');
        }

        return alert;
    }

    /// Aggregate counters for the receiver dashboard.
    static statsForHospital(hospitalId) {
        const rows = all(
            `SELECT acknowledged, declined FROM alert_hospitals WHERE hospital_id = ?`,
            [hospitalId]
        );

        const counts = { total: rows.length, pending: 0, acknowledged: 0, declined: 0 };
        for (const row of rows) {
            if (row.acknowledged === 1) counts.acknowledged += 1;
            else if (row.declined === 1) counts.declined += 1;
            else counts.pending += 1;
        }
        return counts;
    }
}

module.exports = Alert;
