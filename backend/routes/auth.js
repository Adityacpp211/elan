const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Hospital = require('../models/Hospital');
const config = require('../config/config');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// Roles a user may claim for themselves at signup. 'admin' is deliberately
// excluded — admin accounts are provisioned out of band.
const SELF_SERVICE_ROLES = ['member', 'hospital'];

function resolveRole(role, hospitalId) {
    if (!role) return { role: 'member', hospitalId: null };

    if (!SELF_SERVICE_ROLES.includes(role)) {
        return { error: 'Invalid role' };
    }

    if (role === 'hospital') {
        if (!hospitalId) {
            return { error: 'hospitalId is required for hospital staff accounts' };
        }
        const hospital = Hospital.findById(hospitalId);
        if (!hospital || !hospital.is_active) {
            return { error: 'Unknown or inactive hospital' };
        }
        return { role, hospitalId: hospital.id };
    }

    return { role, hospitalId: null };
}

function publicUser(user) {
    return {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        role: user.role || 'member',
        hospitalId: user.hospital_id || null
    };
}

function signToken(user) {
    return jwt.sign(
        {
            userId: user.id,
            email: user.email,
            role: user.role || 'member',
            hospitalId: user.hospital_id || null
        },
        config.jwtSecret,
        { expiresIn: '7d' }
    );
}

// Register new user
router.post('/register', async (req, res) => {
    try {
        const { name, email, password, role, hospitalId } = req.body;

        // Validation
        if (!name || !email || !password) {
            return res.status(400).json({ error: 'Name, email, and password are required' });
        }

        if (password.length < 6) {
            return res.status(400).json({ error: 'Password must be at least 6 characters' });
        }

        const resolved = resolveRole(role, hospitalId);
        if (resolved.error) {
            return res.status(400).json({ error: resolved.error });
        }

        // Check if email exists
        const existingUser = User.findByEmail(email.toLowerCase());
        if (existingUser) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        // Hash password
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Create user
        const user = User.create(name, email.toLowerCase(), passwordHash, {
            role: resolved.role,
            hospitalId: resolved.hospitalId
        });

        res.status(201).json({
            message: 'Registration successful',
            token: signToken(user),
            user: publicUser(user),
            requiresLocation: resolved.role === 'member' // Members broadcast their location
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// Login user
router.post('/login', async (req, res) => {
    try {
        const { email, password, fcmToken } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        // Find user
        const user = User.findByEmail(email.toLowerCase());
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Verify password
        const isValid = await bcrypt.compare(password, user.password_hash);
        if (!isValid) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Update FCM token if provided
        if (fcmToken) {
            User.updateFcmToken(user.id, fcmToken);
        }

        res.json({
            message: 'Login successful',
            token: signToken(user),
            user: publicUser(user),
            requiresLocation: (user.role || 'member') === 'member'
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

// Update user location
router.post('/location', authMiddleware, async (req, res) => {
    try {
        const { latitude, longitude } = req.body;

        if (typeof latitude !== 'number' || typeof longitude !== 'number') {
            return res.status(400).json({ error: 'Valid latitude and longitude are required' });
        }

        const user = User.updateLocation(req.user.userId, latitude, longitude);

        res.json({
            message: 'Location updated',
            location: {
                latitude: user.last_latitude,
                longitude: user.last_longitude,
                updatedAt: user.last_location_update
            }
        });
    } catch (error) {
        console.error('Location update error:', error);
        res.status(500).json({ error: 'Failed to update location' });
    }
});

// Update FCM token
router.post('/fcm-token', authMiddleware, async (req, res) => {
    try {
        const { fcmToken } = req.body;

        if (!fcmToken) {
            return res.status(400).json({ error: 'FCM token is required' });
        }

        User.updateFcmToken(req.user.userId, fcmToken);

        res.json({ message: 'FCM token updated' });
    } catch (error) {
        console.error('FCM token update error:', error);
        res.status(500).json({ error: 'Failed to update FCM token' });
    }
});

// Get current user profile
router.get('/me', authMiddleware, (req, res) => {
    const user = User.findById(req.user.userId);

    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }

    const hospital = user.hospital_id ? Hospital.findById(user.hospital_id) : null;

    res.json({
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        role: user.role || 'member',
        hospitalId: user.hospital_id || null,
        hospital: hospital
            ? {
                id: hospital.id,
                name: hospital.name,
                address: hospital.address,
                phone: hospital.phone,
                latitude: hospital.latitude,
                longitude: hospital.longitude
            }
            : null,
        location: user.last_latitude ? {
            latitude: user.last_latitude,
            longitude: user.last_longitude,
            updatedAt: user.last_location_update
        } : null
    });
});

// Update current user profile
router.put('/me', authMiddleware, (req, res) => {
    try {
        const { name, phone } = req.body;

        if (!name || name.trim().length === 0) {
            return res.status(400).json({ error: 'Name is required' });
        }

        const user = User.updateProfile(req.user.userId, {
            name: name.trim(),
            phone: phone ? String(phone).trim() : ''
        });

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json({
            message: 'Profile updated',
            user: publicUser(user)
        });
    } catch (error) {
        console.error('Profile update error:', error);
        res.status(500).json({ error: 'Failed to update profile' });
    }
});

module.exports = router;
