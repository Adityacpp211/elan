const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const config = require('../config/config');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// Register new user
router.post('/register', async (req, res) => {
    try {
        const { name, email, password } = req.body;

        // Validation
        if (!name || !email || !password) {
            return res.status(400).json({ error: 'Name, email, and password are required' });
        }

        if (password.length < 6) {
            return res.status(400).json({ error: 'Password must be at least 6 characters' });
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
        const user = User.create(name, email.toLowerCase(), passwordHash);

        // Generate token
        const token = jwt.sign(
            { userId: user.id, email: user.email, role: user.role || 'member' },
            config.jwtSecret,
            { expiresIn: '7d' }
        );

        res.status(201).json({
            message: 'Registration successful',
            token,
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone || '',
                role: user.role || 'member'
            },
            requiresLocation: true // Frontend should request location after login
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

        // Generate token
        const token = jwt.sign(
            { userId: user.id, email: user.email, role: user.role || 'member' },
            config.jwtSecret,
            { expiresIn: '7d' }
        );

        res.json({
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone || '',
                role: user.role || 'member'
            },
            requiresLocation: true // Frontend should request location after login
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

    res.json({
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        role: user.role || 'member',
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
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone || '',
                role: user.role || 'member'
            }
        });
    } catch (error) {
        console.error('Profile update error:', error);
        res.status(500).json({ error: 'Failed to update profile' });
    }
});

module.exports = router;
