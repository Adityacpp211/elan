const { all, get, run, getDb, saveDatabase } = require('./database');
const { v4: uuidv4 } = require('uuid');

class User {
    static create(name, email, passwordHash, options = {}) {
        const id = uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO users (id, name, email, password_hash, role, hospital_id, approved, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                id,
                name,
                email,
                passwordHash,
                options.role || 'member',
                options.hospitalId || null,
                options.approved === false ? 0 : 1,
                now
            ]
        );
        return this.findById(id);
    }

    static findByEmail(email) {
        return get('SELECT * FROM users WHERE email = ?', [email]);
    }

    static findById(id) {
        return get('SELECT * FROM users WHERE id = ?', [id]);
    }

    static findByHospitalId(hospitalId) {
        return all('SELECT * FROM users WHERE hospital_id = ?', [hospitalId]);
    }

    /// Permanently delete an account and the personal data attached to it:
    /// the user row, their patient/vital/report records, and their alerts
    /// (with each hospital's copy of them). Payment rows are kept for
    /// accounting but no longer link to anything personal once the alert is
    /// gone. A staff member's email is removed from the alerts they answered.
    static deleteWithData(id) {
        const user = this.findById(id);
        if (!user) return false;

        const db = getDb();
        db.run('BEGIN TRANSACTION');
        try {
            const alertIds = all('SELECT id FROM alerts WHERE user_id = ?', [id]).map((a) => a.id);
            for (const alertId of alertIds) {
                db.run('DELETE FROM alert_hospitals WHERE alert_id = ?', [alertId]);
            }
            db.run('DELETE FROM alerts WHERE user_id = ?', [id]);
            db.run('DELETE FROM vitals WHERE user_id = ?', [id]);
            db.run('DELETE FROM reports WHERE user_id = ?', [id]);
            db.run('DELETE FROM patients WHERE user_id = ?', [id]);
            db.run('DELETE FROM password_resets WHERE user_id = ?', [id]);
            db.run('UPDATE alert_hospitals SET responded_by = NULL WHERE responded_by = ?', [user.email]);
            db.run('DELETE FROM users WHERE id = ?', [id]);
            db.run('COMMIT');
        } catch (error) {
            db.run('ROLLBACK');
            throw error;
        }
        saveDatabase();
        return true;
    }

    /// Set a new password and record when, so sessions from before the
    /// change are rejected.
    static updatePassword(id, passwordHash) {
        run('UPDATE users SET password_hash = ?, password_changed_at = ? WHERE id = ?',
            [passwordHash, new Date().toISOString(), id]);
        run('DELETE FROM password_resets WHERE user_id = ? AND used_at IS NULL', [id]);
        return this.findById(id);
    }

    static findPendingStaff() {
        return all(
            `SELECT * FROM users WHERE role = 'hospital' AND approved = 0 ORDER BY created_at ASC`
        );
    }

    static setApproved(id, approved) {
        run('UPDATE users SET approved = ? WHERE id = ?', [approved ? 1 : 0, id]);
        return this.findById(id);
    }

    static updateLocation(id, latitude, longitude) {
        const now = new Date().toISOString();
        run(
            `UPDATE users SET last_latitude = ?, last_longitude = ?, last_location_update = ? WHERE id = ?`,
            [latitude, longitude, now, id]
        );
        return this.findById(id);
    }

    static updateFcmToken(id, fcmToken) {
        run('UPDATE users SET fcm_token = ? WHERE id = ?', [fcmToken, id]);
        return this.findById(id);
    }

    static updateProfile(id, data) {
        run(
            `UPDATE users SET name = ?, phone = ? WHERE id = ?`,
            [data.name, data.phone || null, id]
        );
        return this.findById(id);
    }
}

module.exports = User;
