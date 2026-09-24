const { rateLimit } = require('express-rate-limit');

function isTest() {
    return process.env.NODE_ENV === 'test';
}

// General API throttle
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    limit: 300,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skip: isTest,
    message: { error: 'Too many requests. Please try again later.' }
});

// Stricter throttle for credential-based endpoints (brute-force protection)
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    limit: 20,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skip: isTest,
    message: { error: 'Too many attempts. Please try again later.' }
});

// Emergency endpoints should stay available even under heavy load
const emergencyLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    limit: 15,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skip: isTest,
    message: { error: 'Too many emergency requests. Please wait a moment.' }
});

module.exports = { apiLimiter, authLimiter, emergencyLimiter };