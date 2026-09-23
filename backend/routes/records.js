const express = require('express');
const Patient = require('../models/Patient');
const Vital = require('../models/Vital');
const Report = require('../models/Report');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// All endpoints below require an authenticated user.
router.use(authMiddleware);

// ==================== PATIENTS ====================

// List patients
router.get('/patients', (req, res) => {
    try {
        const patients = Patient.findAllByUser(req.user.userId);
        res.json({ count: patients.length, patients });
    } catch (error) {
        console.error('List patients error:', error);
        res.status(500).json({ error: 'Failed to fetch patients' });
    }
});

// Get single patient
router.get('/patients/:id', (req, res) => {
    try {
        const patient = Patient.findById(req.params.id);
        if (!patient || patient.user_id !== req.user.userId) {
            return res.status(404).json({ error: 'Patient not found' });
        }
        res.json({ patient });
    } catch (error) {
        console.error('Get patient error:', error);
        res.status(500).json({ error: 'Failed to fetch patient' });
    }
});

// Create patient
router.post('/patients', (req, res) => {
    try {
        const { name, age, bloodType, condition, admissionDate, roomNumber } = req.body;
        if (!name || !age || !bloodType || !condition || !admissionDate || !roomNumber) {
            return res.status(400).json({ error: 'All patient fields are required' });
        }
        const patient = Patient.create(req.user.userId, {
            name, age: parseInt(age), bloodType, condition, admissionDate, roomNumber
        });
        res.status(201).json({ patient });
    } catch (error) {
        console.error('Create patient error:', error);
        res.status(500).json({ error: 'Failed to create patient' });
    }
});

// Update patient
router.put('/patients/:id', (req, res) => {
    try {
        const existing = Patient.findById(req.params.id);
        if (!existing || existing.user_id !== req.user.userId) {
            return res.status(404).json({ error: 'Patient not found' });
        }
        const { name, age, bloodType, condition, admissionDate, roomNumber } = req.body;
        if (!name || !age || !bloodType || !condition || !admissionDate || !roomNumber) {
            return res.status(400).json({ error: 'All patient fields are required' });
        }
        const patient = Patient.update(req.params.id, {
            name, age: parseInt(age), bloodType, condition, admissionDate, roomNumber
        });
        res.json({ patient });
    } catch (error) {
        console.error('Update patient error:', error);
        res.status(500).json({ error: 'Failed to update patient' });
    }
});

// Delete patient
router.delete('/patients/:id', (req, res) => {
    try {
        const existing = Patient.findById(req.params.id);
        if (!existing || existing.user_id !== req.user.userId) {
            return res.status(404).json({ error: 'Patient not found' });
        }
        Patient.remove(req.params.id);
        res.json({ success: true, message: 'Patient deleted' });
    } catch (error) {
        console.error('Delete patient error:', error);
        res.status(500).json({ error: 'Failed to delete patient' });
    }
});

// ==================== VITALS ====================

// List vital readings
router.get('/vitals', (req, res) => {
    try {
        const vitals = Vital.findAllByUser(req.user.userId);
        res.json({ count: vitals.length, vitals });
    } catch (error) {
        console.error('List vitals error:', error);
        res.status(500).json({ error: 'Failed to fetch vitals' });
    }
});

// Create vital reading
router.post('/vitals', (req, res) => {
    try {
        const { patientId, patientName, heartRate, bloodPressure, temperature, oxygenLevel, timestamp } = req.body;
        if (!patientId || !patientName || !heartRate || !bloodPressure || !temperature || !oxygenLevel) {
            return res.status(400).json({ error: 'All vital fields are required' });
        }
        const vital = Vital.create(req.user.userId, {
            patientId,
            patientName,
            heartRate: parseInt(heartRate),
            bloodPressure,
            temperature: parseFloat(temperature),
            oxygenLevel: parseInt(oxygenLevel),
            timestamp
        });
        res.status(201).json({ vital });
    } catch (error) {
        console.error('Create vital error:', error);
        res.status(500).json({ error: 'Failed to create vital reading' });
    }
});

// Delete vital reading
router.delete('/vitals/:id', (req, res) => {
    try {
        const existing = Vital.findById(req.params.id);
        if (!existing || existing.user_id !== req.user.userId) {
            return res.status(404).json({ error: 'Vital not found' });
        }
        Vital.remove(req.params.id);
        res.json({ success: true, message: 'Vital deleted' });
    } catch (error) {
        console.error('Delete vital error:', error);
        res.status(500).json({ error: 'Failed to delete vital' });
    }
});

// ==================== REPORTS ====================

// List reports
router.get('/reports', (req, res) => {
    try {
        const reports = Report.findAllByUser(req.user.userId);
        res.json({ count: reports.length, reports });
    } catch (error) {
        console.error('List reports error:', error);
        res.status(500).json({ error: 'Failed to fetch reports' });
    }
});

// Get single report
router.get('/reports/:id', (req, res) => {
    try {
        const report = Report.findById(req.params.id);
        if (!report || report.user_id !== req.user.userId) {
            return res.status(404).json({ error: 'Report not found' });
        }
        res.json({ report });
    } catch (error) {
        console.error('Get report error:', error);
        res.status(500).json({ error: 'Failed to fetch report' });
    }
});

// Create report
router.post('/reports', (req, res) => {
    try {
        const { patientName, reportType, date, summary, doctor } = req.body;
        if (!patientName || !reportType || !date || !summary || !doctor) {
            return res.status(400).json({ error: 'All report fields are required' });
        }
        const report = Report.create(req.user.userId, { patientName, reportType, date, summary, doctor });
        res.status(201).json({ report });
    } catch (error) {
        console.error('Create report error:', error);
        res.status(500).json({ error: 'Failed to create report' });
    }
});

// Delete report
router.delete('/reports/:id', (req, res) => {
    try {
        const existing = Report.findById(req.params.id);
        if (!existing || existing.user_id !== req.user.userId) {
            return res.status(404).json({ error: 'Report not found' });
        }
        Report.remove(req.params.id);
        res.json({ success: true, message: 'Report deleted' });
    } catch (error) {
        console.error('Delete report error:', error);
        res.status(500).json({ error: 'Failed to delete report' });
    }
});

module.exports = router;