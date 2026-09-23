const { all, get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

class User {
    static create(name, email, passwordHash) {
        const id = uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO users (id, name, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)`,
            [id, name, email, passwordHash, now]
        );
        return this.findById(id);
    }

    static findByEmail(email) {
        return get('SELECT * FROM users WHERE email = ?', [email]);
    }

    static findById(id) {
        return get('SELECT * FROM users WHERE id = ?', [id]);
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
