const jwt = require('jsonwebtoken');
const config = require('../config/config');
const User = require('../models/User');

function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
        return res.status(401).json({ error: 'No authorization header' });
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
        return res.status(401).json({ error: 'Invalid authorization format' });
    }

    const token = parts[1];

    try {
        const decoded = jwt.verify(token, config.jwtSecret);
        // Tokens outlive accounts: once an account is deleted its token must
        // stop working immediately, not when it expires days later.
        if (!User.findById(decoded.userId)) {
            return res.status(401).json({ error: 'Account no longer exists' });
        }
        req.user = decoded;
        next();
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ error: 'Token expired' });
        }
        return res.status(401).json({ error: 'Invalid token' });
    }
}

// Optional auth - doesn't fail if no token
function optionalAuth(req, res, next) {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
        return next();
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
        return next();
    }

    try {
        const decoded = jwt.verify(parts[1], config.jwtSecret);
        if (User.findById(decoded.userId)) req.user = decoded;
    } catch (error) {
        // Ignore errors for optional auth
    }

    next();
}

// Require one of the given roles (must be used after authMiddleware)
function requireRole(...roles) {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Authentication required' });
        }
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ error: 'Insufficient permissions' });
        }
        next();
    };
}

module.exports = { authMiddleware, optionalAuth, requireRole };
