const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { start, stop, registerUser, registerHospitalStaff, adminToken } = require('./helpers');
const { escapeHtml } = require('../services/notificationService');

let baseUrl;

before(async () => {
    ({ baseUrl } = await start());
});

after(async () => {
    await stop();
});

function post(path, body, headers = {}) {
    return fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...headers },
        body: typeof body === 'string' ? body : JSON.stringify(body)
    });
}

// ==================== HOSPITAL STAFF APPROVAL ====================

test('self-registered hospital staff cannot read the inbox until approved', async () => {
    const staff = await registerHospitalStaff('H002', { approve: false });
    assert.strictEqual(staff.status, 201);
    assert.strictEqual(staff.data.pendingApproval, true);
    assert.strictEqual(staff.data.user.approved, false);

    const blocked = await fetch(`${baseUrl}/api/receiver/inbox`, { headers: staff.auth });
    assert.strictEqual(blocked.status, 403);
    assert.strictEqual((await blocked.json()).code, 'pending_approval');

    const admin = { Authorization: `Bearer ${adminToken()}` };
    const pending = await (await fetch(`${baseUrl}/api/auth/staff/pending`, { headers: admin })).json();
    assert.ok(pending.staff.some((s) => s.id === staff.data.user.id));

    const approve = await post(`/api/auth/staff/${staff.data.user.id}/approve`, {}, admin);
    assert.strictEqual(approve.status, 200);

    // The same token works once approved — no re-login needed
    const allowed = await fetch(`${baseUrl}/api/receiver/inbox`, { headers: staff.auth });
    assert.strictEqual(allowed.status, 200);

    // ...and revoking takes effect immediately too
    await post(`/api/auth/staff/${staff.data.user.id}/approve`, { approved: false }, admin);
    const revoked = await fetch(`${baseUrl}/api/receiver/inbox`, { headers: staff.auth });
    assert.strictEqual(revoked.status, 403);
});

test('members cannot approve staff accounts', async () => {
    const staff = await registerHospitalStaff('H002', { approve: false });
    const member = await registerUser();

    const res = await post(`/api/auth/staff/${staff.data.user.id}/approve`, {}, member.auth);
    assert.strictEqual(res.status, 403);

    const own = await post(`/api/auth/staff/${staff.data.user.id}/approve`, {}, staff.auth);
    assert.strictEqual(own.status, 403);
});

test('member signups are approved immediately', async () => {
    const member = await registerUser();
    assert.strictEqual(member.data.user.approved, true);
    assert.strictEqual(member.data.pendingApproval, false);
});

// ==================== EMERGENCY PAYMENT FLOW ====================

test('no order or alert is created when no hospital is in range', async () => {
    const { auth } = await registerUser();

    // 0,0 is valid (and must not be rejected as "missing") but nowhere near a hospital
    const res = await post('/api/payments/create-order', { tier: 1, latitude: 0, longitude: 0 }, auth);
    assert.strictEqual(res.status, 404);
    assert.match((await res.json()).error, /No hospitals found/);

    const history = await (await fetch(`${baseUrl}/api/alerts/history`, { headers: auth })).json();
    assert.strictEqual(history.alerts.length, 0);
});

test('verifying an already-completed payment is idempotent', async () => {
    const { auth } = await registerUser();
    const order = await (await post('/api/payments/create-order', {
        tier: 1, latitude: 12.8585, longitude: 76.4880
    }, auth)).json();
    assert.strictEqual(order.mockGateway, true);

    const body = { orderId: order.order.id, paymentId: 'pay_1', signature: 'sig', alertId: order.alertId };
    assert.strictEqual((await post('/api/payments/verify', body, auth)).status, 200);

    const again = await post('/api/payments/verify', { ...body, paymentId: 'pay_2' }, auth);
    assert.strictEqual(again.status, 200);
    assert.strictEqual((await again.json()).paymentId, 'pay_1');
});

// ==================== INPUT VALIDATION ====================

test('malformed JSON is a 400, not a server error', async () => {
    const res = await post('/api/auth/login', '{"email": ');
    assert.strictEqual(res.status, 400);
});

test('register and login reject non-string credentials', async () => {
    const register = await post('/api/auth/register', { name: 'X', email: 42, password: 123456 });
    assert.strictEqual(register.status, 400);

    const badEmail = await post('/api/auth/register', { name: 'X', email: 'not-an-email', password: 'secret123' });
    assert.strictEqual(badEmail.status, 400);

    const login = await post('/api/auth/login', { email: ['a'], password: { $ne: '' } });
    assert.strictEqual(login.status, 400);
});

test('location updates reject out-of-range coordinates', async () => {
    const { auth } = await registerUser();
    const res = await post('/api/auth/location', { latitude: 500, longitude: 10 }, auth);
    assert.strictEqual(res.status, 400);
});

test('vital readings must be numeric and plausible', async () => {
    const { auth } = await registerUser();
    const reading = {
        patientId: 'P1',
        patientName: 'Asha',
        heartRate: 72,
        bloodPressure: '120/80',
        temperature: 36.8,
        oxygenLevel: 98,
        timestamp: new Date().toISOString()
    };

    assert.strictEqual((await post('/api/records/vitals', reading, auth)).status, 201);
    assert.strictEqual((await post('/api/records/vitals', { ...reading, heartRate: 'fast' }, auth)).status, 400);
    assert.strictEqual((await post('/api/records/vitals', { ...reading, oxygenLevel: 140 }, auth)).status, 400);
    assert.strictEqual((await post('/api/records/vitals', { ...reading, bloodPressure: 'high' }, auth)).status, 400);
});

test('patient age must be a plausible whole number', async () => {
    const { auth } = await registerUser();
    const patient = {
        name: 'Asha', age: 'old', bloodType: 'O+', condition: 'Stable',
        admissionDate: '2026-01-01', roomNumber: '1'
    };
    assert.strictEqual((await post('/api/records/patients', patient, auth)).status, 400);
    assert.strictEqual((await post('/api/records/patients', { ...patient, age: 0 }, auth)).status, 201);
});

test('admin hospital update validates a single changed coordinate', async () => {
    const admin = { Authorization: `Bearer ${adminToken()}`, 'Content-Type': 'application/json' };
    const res = await fetch(`${baseUrl}/api/hospitals/H004`, {
        method: 'PUT',
        headers: admin,
        body: JSON.stringify({ latitude: 'north' })
    });
    assert.strictEqual(res.status, 400);
});

test('nearby search tolerates a non-numeric limit', async () => {
    const res = await fetch(`${baseUrl}/api/hospitals/nearby?lat=12.8585&lng=76.4880&limit=abc`);
    assert.strictEqual(res.status, 200);
    assert.ok((await res.json()).hospitals.length > 0);
});

// ==================== EMAIL ====================

test('patient text is HTML-escaped before it goes into the hospital email', () => {
    assert.strictEqual(
        escapeHtml('<a href="x">Click</a> & \'go\''),
        '&lt;a href=&quot;x&quot;&gt;Click&lt;/a&gt; &amp; &#39;go&#39;'
    );
    assert.strictEqual(escapeHtml(null), '');
});
