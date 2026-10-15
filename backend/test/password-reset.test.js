const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const { start, stop, registerUser } = require('./helpers');
const notificationService = require('../services/notificationService');

let baseUrl;
let sent = [];

before(async () => {
    ({ baseUrl } = await start());
    // Capture outgoing email instead of sending it
    notificationService.sendEmail = async (to, subject, html) => {
        sent.push({ to, subject, html });
        return { success: true, mock: true };
    };
});

after(async () => {
    await stop();
});

beforeEach(() => {
    sent = [];
});

function post(path, body, headers = {}) {
    return fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...headers },
        body: JSON.stringify(body)
    });
}

function lastCode() {
    const match = sent.at(-1).html.match(/>(\d{6})</);
    return match[1];
}

async function login(email, password) {
    return post('/api/auth/login', { email, password });
}

test('unknown emails get the same answer and no email is sent', async () => {
    const known = await registerUser();
    const knownRes = await (await post('/api/auth/forgot-password', { email: known.data.user.email })).json();
    const unknownRes = await (await post('/api/auth/forgot-password', { email: 'nobody@nowhere.test' })).json();

    assert.strictEqual(knownRes.message, unknownRes.message);
    assert.strictEqual(sent.length, 1);
    assert.strictEqual(sent[0].to, known.data.user.email);
});

test('a valid code sets a new password and signs out old sessions', async () => {
    const member = await registerUser();
    const email = member.data.user.email;

    await post('/api/auth/forgot-password', { email: email.toUpperCase() });
    const code = lastCode();

    const res = await post('/api/auth/reset-password', { email, code, password: 'brand-new-pass' });
    assert.strictEqual(res.status, 200);

    // Old password no longer works; the new one does
    assert.strictEqual((await login(email, 'secret123')).status, 401);
    const fresh = await login(email, 'brand-new-pass');
    assert.strictEqual(fresh.status, 200);

    // The session from before the reset is rejected...
    const old = await fetch(`${baseUrl}/api/auth/me`, { headers: member.auth });
    assert.strictEqual(old.status, 401);
    assert.match((await old.json()).error, /Password changed/);

    // ...while the new one works
    const token = (await fresh.json()).token;
    const me = await fetch(`${baseUrl}/api/auth/me`, { headers: { Authorization: `Bearer ${token}` } });
    assert.strictEqual(me.status, 200);
});

test('a code works only once', async () => {
    const member = await registerUser();
    const email = member.data.user.email;
    await post('/api/auth/forgot-password', { email });
    const code = lastCode();

    assert.strictEqual((await post('/api/auth/reset-password', { email, code, password: 'first-new' })).status, 200);
    assert.strictEqual((await post('/api/auth/reset-password', { email, code, password: 'second-new' })).status, 400);
});

test('wrong guesses lock the code after five attempts', async () => {
    const member = await registerUser();
    const email = member.data.user.email;
    await post('/api/auth/forgot-password', { email });
    const code = lastCode();
    const wrong = code === '000000' ? '111111' : '000000';

    for (let i = 0; i < 5; i++) {
        assert.strictEqual((await post('/api/auth/reset-password', { email, code: wrong, password: 'whatever1' })).status, 400);
    }
    // Even the right code is refused now
    assert.strictEqual((await post('/api/auth/reset-password', { email, code, password: 'whatever1' })).status, 400);
    assert.strictEqual((await login(email, 'secret123')).status, 200);
});

test('requesting a new code cancels the previous one', async () => {
    const member = await registerUser();
    const email = member.data.user.email;
    await post('/api/auth/forgot-password', { email });
    const first = lastCode();
    await post('/api/auth/forgot-password', { email });
    const second = lastCode();

    if (first !== second) {
        assert.strictEqual((await post('/api/auth/reset-password', { email, code: first, password: 'new-pass-1' })).status, 400);
    }
    assert.strictEqual((await post('/api/auth/reset-password', { email, code: second, password: 'new-pass-1' })).status, 200);
});

test('reset rejects short passwords and malformed requests', async () => {
    const member = await registerUser();
    const email = member.data.user.email;
    await post('/api/auth/forgot-password', { email });
    const code = lastCode();

    assert.strictEqual((await post('/api/auth/reset-password', { email, code, password: '123' })).status, 400);
    assert.strictEqual((await post('/api/auth/reset-password', { email, password: 'longenough' })).status, 400);
    assert.strictEqual((await post('/api/auth/forgot-password', { email: 'not-an-email' })).status, 400);
});
