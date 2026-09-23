const { all, get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

class Report {
    static create(userId, data) {
        const id = data.id || uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO reports (id, user_id, patient_name, report_type, date, summary, doctor, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                id,
                userId,
                data.patientName,
                data.reportType,
                data.date,
                data.summary,
                data.doctor,
                now
            ]
        );
        return this.findById(id);
    }

    static findById(id) {
        return get('SELECT * FROM reports WHERE id = ?', [id]);
    }

    static findAllByUser(userId) {
        return all('SELECT * FROM reports WHERE user_id = ? ORDER BY date DESC', [userId]);
    }

    static remove(id) {
        run('DELETE FROM reports WHERE id = ?', [id]);
    }

    static count() {
        const result = get('SELECT COUNT(*) as count FROM reports');
        return result ? result.count : 0;
    }
}

module.exports = Report;