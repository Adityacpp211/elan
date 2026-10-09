const { all, get, run } = require('./database');
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
