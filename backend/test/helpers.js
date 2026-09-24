const path = require('path');
const fs = require('fs');
const os = require('os');
const jwt = require('jsonwebtoken');
const config = require('../config/config');

// Must be set before requiring the server so the DB module picks up the temp path
process.env.NODE_ENV = 'test';

// Silence app logging so it cannot interfere with the test-runner IPC stream
for (const method of ['log', 'info', 'warn', 'error']) {
    console[method] = () => {};
}

const DB_PATH = path.join(os.tmpdir(), `elan-test-${process.pid}-${Date.now()}.db`);
process.env.ELAN_DB_PATH = DB_PATH;

const { app, initialize } = require('../server');

let server = null;
let baseUrl = '';

async function start() {
    await initialize();
    server = app.listen(0);
    await new Promise(resolve => server.once('listening', resolve));
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    return { baseUrl, app, server };
}

async function stop() {
    if (server) {
        await new Promise(resolve => server.close(resolve));
        server = null;
    }
    try {
        fs.unlinkSync(DB_PATH);
    } catch (_) {
        // Ignore cleanup errors
    }
}

async function registerUser(overrides = {}) {
    const email = overrides.email || `user${Date.now()}_${Math.floor(Math.random() * 10000)}@test.com`;
    const res = await fetch(`${baseUrl}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Test User',
            email,
            password: 'secret123',
            ...overrides
        })
    });
    const data = await res.json();
    return {
        status: res.status,
        data,
        token: data.token,
        auth: { Authorization: `Bearer ${data.token}` }
    };
}

function adminToken() {
    return jwt.sign(
        { userId: 'admin-test-user', email: 'admin@test.com', role: 'admin' },
        config.jwtSecret,
        { expiresIn: '1h' }
    );
}

module.exports = { start, stop, registerUser, adminToken };