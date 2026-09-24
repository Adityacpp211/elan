const { all, get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

class Hospital {
    static create(data) {
        const id = data.id || uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO hospitals (id, name, address, phone, emergency_email, latitude, longitude, fcm_topic, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                id,
                data.name,
                data.address,
                data.phone,
                data.emergencyEmail || null,
                data.latitude,
                data.longitude,
                data.fcmTopic || `hospital_${id}`,
                now
            ]
        );
        return this.findById(id);
    }

    static findById(id) {
        return get('SELECT * FROM hospitals WHERE id = ?', [id]);
    }

    static update(id, data) {
        run(
            `UPDATE hospitals SET
              name = ?, address = ?, phone = ?, emergency_email = ?, latitude = ?, longitude = ?, is_active = ?
             WHERE id = ?`,
            [
                data.name,
                data.address,
                data.phone,
                data.emergencyEmail || null,
                data.latitude,
                data.longitude,
                data.isActive === undefined ? 1 : data.isActive,
                id
            ]
        );
        return this.findById(id);
    }

    static remove(id) {
        run('UPDATE hospitals SET is_active = 0 WHERE id = ?', [id]);
    }

    static findAll() {
        return all('SELECT * FROM hospitals WHERE is_active = 1');
    }

    static findNearby(latitude, longitude, radiusKm = 10, limit = 10) {
        const allHospitals = this.findAll();

        const hospitalsWithDistance = allHospitals.map(hospital => {
            const distance = this.calculateDistance(
                latitude, longitude,
                hospital.latitude, hospital.longitude
            );
            return { ...hospital, distance_km: distance };
        });

        return hospitalsWithDistance
            .filter(h => h.distance_km <= radiusKm)
            .sort((a, b) => a.distance_km - b.distance_km)
            .slice(0, limit);
    }

    static calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371; // Earth's radius in km
        const dLat = this.toRadians(lat2 - lat1);
        const dLon = this.toRadians(lon2 - lon1);
        const a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    static toRadians(degrees) {
        return degrees * (Math.PI / 180);
    }

    static count() {
        const result = get('SELECT COUNT(*) as count FROM hospitals');
        return result ? result.count : 0;
    }
}

module.exports = Hospital;
