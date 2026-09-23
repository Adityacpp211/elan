const { all, get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

class Patient {
    static create(userId, data) {
        const id = data.id || uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO patients (id, user_id, name, age, blood_type, condition, admission_date, room_number, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                id,
                userId,
                data.name,
                data.age,
                data.bloodType,
                data.condition,
                data.admissionDate,
                data.roomNumber,
                now
            ]
        );
        return this.findById(id);
    }

    static findById(id) {
        return get('SELECT * FROM patients WHERE id = ?', [id]);
    }

    static findAllByUser(userId) {
        return all('SELECT * FROM patients WHERE user_id = ? ORDER BY admission_date DESC', [userId]);
    }

    static update(id, data) {
        run(
            `UPDATE patients SET
        name = ?, age = ?, blood_type = ?, condition = ?,
        admission_date = ?, room_number = ?
        WHERE id = ?`,
            [
                data.name,
                data.age,
                data.bloodType,
                data.condition,
                data.admissionDate,
                data.roomNumber,
                id
            ]
        );
        return this.findById(id);
    }

    static remove(id) {
        run('DELETE FROM patients WHERE id = ?', [id]);
    }

    static count() {
        const result = get('SELECT COUNT(*) as count FROM patients');
        return result ? result.count : 0;
    }
}

module.exports = Patient;