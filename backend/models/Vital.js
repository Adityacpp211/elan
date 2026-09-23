const { all, get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

class Vital {
    static create(userId, data) {
        const id = data.id || uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO vitals (id, user_id, patient_id, patient_name, heart_rate, blood_pressure, temperature, oxygen_level, timestamp, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                id,
                userId,
                data.patientId,
                data.patientName,
                data.heartRate,
                data.bloodPressure,
                data.temperature,
                data.oxygenLevel,
                data.timestamp || now,
                now
            ]
        );
        return this.findById(id);
    }

    static findById(id) {
        return get('SELECT * FROM vitals WHERE id = ?', [id]);
    }

    static findAllByUser(userId) {
        return all('SELECT * FROM vitals WHERE user_id = ? ORDER BY timestamp DESC', [userId]);
    }

    static remove(id) {
        run('DELETE FROM vitals WHERE id = ?', [id]);
    }

    static count() {
        const result = get('SELECT COUNT(*) as count FROM vitals');
        return result ? result.count : 0;
    }
}

module.exports = Vital;