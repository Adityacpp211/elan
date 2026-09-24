const express = require('express');
const Hospital = require('../models/Hospital');
const { optionalAuth, authMiddleware, requireRole } = require('../middleware/auth');
const { isValidCoordinates } = require('../utils/validation');

const router = express.Router();

// GET /api/hospitals/nearby - Find nearby hospitals
router.get('/nearby', optionalAuth, (req, res) => {
    try {
        const { lat, lng, radius = 10, limit = 10 } = req.query;

        if (!lat || !lng) {
            return res.status(400).json({ error: 'Latitude (lat) and longitude (lng) are required' });
        }

        const latitude = parseFloat(lat);
        const longitude = parseFloat(lng);
        const radiusKm = parseFloat(radius);
        const maxLimit = Math.min(parseInt(limit), 50);

        if (!isFinite(latitude) || !isFinite(longitude) || !isValidCoordinates(latitude, longitude)) {
            return res.status(400).json({ error: 'Invalid coordinates' });
        }

        if (!isFinite(radiusKm) || radiusKm <= 0 || radiusKm > 100) {
            return res.status(400).json({ error: 'Radius must be between 0 and 100 km' });
        }

        const hospitals = Hospital.findNearby(latitude, longitude, radiusKm, maxLimit);

        res.json({
            count: hospitals.length,
            userLocation: { latitude, longitude },
            radiusKm,
            hospitals: hospitals.map(h => ({
                id: h.id,
                name: h.name,
                address: h.address,
                phone: h.phone,
                latitude: h.latitude,
                longitude: h.longitude,
                distanceKm: Math.round(h.distance_km * 100) / 100
            }))
        });
    } catch (error) {
        console.error('Nearby hospitals error:', error);
        res.status(500).json({ error: 'Failed to fetch nearby hospitals' });
    }
});

// Get all hospitals
router.get('/', (req, res) => {
    try {
        const hospitals = Hospital.findAll();

        res.json({
            count: hospitals.length,
            hospitals: hospitals.map(h => ({
                id: h.id,
                name: h.name,
                address: h.address,
                phone: h.phone,
                latitude: h.latitude,
                longitude: h.longitude
            }))
        });
    } catch (error) {
        console.error('Get hospitals error:', error);
        res.status(500).json({ error: 'Failed to fetch hospitals' });
    }
});

// Get single hospital
router.get('/:id', (req, res) => {
    try {
        const hospital = Hospital.findById(req.params.id);

        if (!hospital) {
            return res.status(404).json({ error: 'Hospital not found' });
        }

        res.json({
            id: hospital.id,
            name: hospital.name,
            address: hospital.address,
            phone: hospital.phone,
            emergencyEmail: hospital.emergency_email,
            latitude: hospital.latitude,
            longitude: hospital.longitude
        });
    } catch (error) {
        console.error('Get hospital error:', error);
        res.status(500).json({ error: 'Failed to fetch hospital' });
    }
});

// ==================== ADMIN MANAGEMENT (role: admin) ====================

// Create hospital
router.post('/', authMiddleware, requireRole('admin'), (req, res) => {
    try {
        const { name, address, phone, emergencyEmail, latitude, longitude } = req.body;

        if (!name || !address || !phone) {
            return res.status(400).json({ error: 'Name, address, and phone are required' });
        }

        if (!isValidCoordinates(latitude, longitude)) {
            return res.status(400).json({ error: 'Valid latitude and longitude are required' });
        }

        const hospital = Hospital.create({
            name,
            address,
            phone,
            emergencyEmail,
            latitude,
            longitude
        });

        res.status(201).json({ message: 'Hospital created', hospital });
    } catch (error) {
        console.error('Create hospital error:', error);
        res.status(500).json({ error: 'Failed to create hospital' });
    }
});

// Update hospital
router.put('/:id', authMiddleware, requireRole('admin'), (req, res) => {
    try {
        const existing = Hospital.findById(req.params.id);
        if (!existing) {
            return res.status(404).json({ error: 'Hospital not found' });
        }

        const { name, address, phone, emergencyEmail, latitude, longitude, isActive } = req.body;

        if (latitude !== undefined && longitude !== undefined && !isValidCoordinates(latitude, longitude)) {
            return res.status(400).json({ error: 'Valid latitude and longitude are required' });
        }

        const hospital = Hospital.update(req.params.id, {
            name: name ?? existing.name,
            address: address ?? existing.address,
            phone: phone ?? existing.phone,
            emergencyEmail: emergencyEmail !== undefined ? emergencyEmail : existing.emergency_email,
            latitude: latitude !== undefined ? latitude : existing.latitude,
            longitude: longitude !== undefined ? longitude : existing.longitude,
            isActive: isActive !== undefined ? (isActive ? 1 : 0) : existing.is_active
        });

        res.json({ message: 'Hospital updated', hospital });
    } catch (error) {
        console.error('Update hospital error:', error);
        res.status(500).json({ error: 'Failed to update hospital' });
    }
});

// Deactivate hospital (soft delete)
router.delete('/:id', authMiddleware, requireRole('admin'), (req, res) => {
    try {
        const existing = Hospital.findById(req.params.id);
        if (!existing) {
            return res.status(404).json({ error: 'Hospital not found' });
        }

        Hospital.remove(req.params.id);
        res.json({ success: true, message: 'Hospital deactivated' });
    } catch (error) {
        console.error('Delete hospital error:', error);
        res.status(500).json({ error: 'Failed to delete hospital' });
    }
});

module.exports = router;
