const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { start, stop, registerUser } = require('./helpers');

let baseUrl;

before(async () => {
    ({ baseUrl } = await start());
});

after(async () => {
    await stop();
});

test('GET /health returns ok', async () => {
    const res = await fetch(`${baseUrl}/health`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.status, 'ok');
});

test('POST /api/auth/register validates required fields', async () => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@a.com', password: 'secret123' })
    });
    assert.strictEqual(res.status, 400);
});

test('POST /api/auth/register rejects short passwords', async () => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'A', email: 'a@a.com', password: '123' })
    });
    assert.strictEqual(res.status, 400);
});

test('POST /api/auth/register creates a user and returns a token', async () => {
    const { status, data, token, auth } = await registerUser();
    assert.strictEqual(status, 201);
    assert.strictEqual(data.user.role, 'member');
    assert.ok(token);

    const me = await fetch(`${baseUrl}/api/auth/me`, { headers: auth });
    assert.strictEqual(me.status, 200);
    const meBody = await me.json();
    assert.strictEqual(meBody.email, data.user.email);
});

test('POST /api/auth/register rejects duplicate emails (case-insensitive)', async () => {
    const email = `dup_${Date.now()}@test.com`;
    await registerUser({ email });
    const res = await fetch(`${baseUrl}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'B', email: email.toUpperCase(), password: 'secret123' })
    });
    assert.strictEqual(res.status, 400);
});

test('POST /api/auth/login succeeds with valid credentials and fails with invalid', async () => {
    const { data } = await registerUser();

    const ok = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: data.user.email, password: 'secret123' })
    });
    assert.strictEqual(ok.status, 200);
    const okBody = await ok.json();
    assert.ok(okBody.token);

    const bad = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: data.user.email, password: 'wrongpass' })
    });
    assert.strictEqual(bad.status, 401);
});

test('protected routes require an auth token', async () => {
    const res = await fetch(`${baseUrl}/api/auth/me`);
    assert.strictEqual(res.status, 401);
});