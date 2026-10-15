const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { start, stop, registerUser, registerHospitalStaff } = require('./helpers');
const { all } = require('../models/database');

let baseUrl;

before(async () => {
    ({ baseUrl } = await start());
});

after(async () => {
    await stop();
});

function request(method, path, body, headers = {}) {
    return fetch(`${baseUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', ...headers },
        body: body === undefined ? undefined : JSON.stringify(body)
    });
}

/// A member with one dispatched alert, one patient record and one vital.
async function memberWithData() {
    const email = `del_${Date.now()}_${Math.floor(Math.random() * 1e4)}@test.com`;
    const member = await registerUser({ email });

    const order = await (await request('POST', '/api/payments/create-order', {
        tier: 1, latitude: 12.8585, longitude: 76.4880, symptoms: 'Chest pain', message: 'Help'
    }, member.auth)).json();
    await request('POST', '/api/payments/verify', {
        orderId: order.order.id, paymentId: 'pay_x', signature: 's', alertId: order.alertId
    }, member.auth);
    await request('POST', '/api/alerts/send', { alertId: order.alertId }, member.auth);

    await request('POST', '/api/records/patients', {
        name: 'Asha', age: 60, bloodType: 'O+', condition: 'Stable',
        admissionDate: '2026-01-01', roomNumber: '1'
    }, member.auth);
    await request('POST', '/api/records/vitals', {
        patientId: 'P1', patientName: 'Asha', heartRate: 70, bloodPressure: '120/80',
        temperature: 36.8, oxygenLevel: 98
    }, member.auth);

    return { ...member, email, alertId: order.alertId };
}

test('in-app deletion requires the correct password', async () => {
    const member = await registerUser();

    const missing = await request('DELETE', '/api/auth/me', {}, member.auth);
    assert.strictEqual(missing.status, 400);

    const wrong = await request('DELETE', '/api/auth/me', { password: 'nope' }, member.auth);
    // 403 so the app doesn't mistake it for an expired session
    assert.strictEqual(wrong.status, 403);

    // Still there
    const me = await fetch(`${baseUrl}/api/auth/me`, { headers: member.auth });
    assert.strictEqual(me.status, 200);
});

test('in-app deletion removes the account and its personal data', async () => {
    const member = await memberWithData();
    const userId = member.data.user.id;

    const res = await request('DELETE', '/api/auth/me', { password: 'secret123' }, member.auth);
    assert.strictEqual(res.status, 200);

    assert.strictEqual(all('SELECT id FROM users WHERE id = ?', [userId]).length, 0);
    assert.strictEqual(all('SELECT id FROM alerts WHERE user_id = ?', [userId]).length, 0);
    assert.strictEqual(all('SELECT id FROM alert_hospitals WHERE alert_id = ?', [member.alertId]).length, 0);
    assert.strictEqual(all('SELECT id FROM patients WHERE user_id = ?', [userId]).length, 0);
    assert.strictEqual(all('SELECT id FROM vitals WHERE user_id = ?', [userId]).length, 0);

    // Payment kept for accounting, with no personal fields of its own
    const payments = all('SELECT * FROM payments WHERE alert_id = ?', [member.alertId]);
    assert.strictEqual(payments.length, 1);
});

test('a deleted account cannot sign in and its old token stops working', async () => {
    const member = await memberWithData();
    await request('DELETE', '/api/auth/me', { password: 'secret123' }, member.auth);

    const reuse = await fetch(`${baseUrl}/api/alerts/history`, { headers: member.auth });
    assert.strictEqual(reuse.status, 401);
    assert.match((await reuse.json()).error, /no longer exists/);

    const login = await request('POST', '/api/auth/login', { email: member.email, password: 'secret123' });
    assert.strictEqual(login.status, 401);

    // The email can be registered again from scratch
    const again = await registerUser({ email: member.email });
    assert.strictEqual(again.status, 201);
});

test('web deletion works with email and password and rejects bad credentials', async () => {
    const member = await memberWithData();

    const wrong = await request('POST', '/api/auth/delete-account', { email: member.email, password: 'bad' });
    assert.strictEqual(wrong.status, 401);

    const unknown = await request('POST', '/api/auth/delete-account', { email: 'nobody@test.com', password: 'x' });
    assert.strictEqual(unknown.status, 401);

    const ok = await request('POST', '/api/auth/delete-account', {
        email: member.email.toUpperCase(), password: 'secret123'
    });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(all('SELECT id FROM users WHERE id = ?', [member.data.user.id]).length, 0);
});

test('deleting a staff account removes their email from alerts they answered', async () => {
    const member = await memberWithData();
    const staffEmail = `staff_${Date.now()}@test.com`;
    const staff = await registerHospitalStaff('H002', { email: staffEmail });

    const ack = await request('POST', `/api/receiver/alerts/${member.alertId}/acknowledge`, { etaMinutes: 5 }, staff.auth);
    assert.strictEqual(ack.status, 200);
    assert.strictEqual(all('SELECT id FROM alert_hospitals WHERE responded_by = ?', [staffEmail]).length, 1);

    const res = await request('DELETE', '/api/auth/me', { password: 'secret123' }, staff.auth);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(all('SELECT id FROM alert_hospitals WHERE responded_by = ?', [staffEmail]).length, 0);

    // The patient's alert itself is untouched and still shows the response
    const history = await (await fetch(`${baseUrl}/api/alerts/history`, { headers: member.auth })).json();
    assert.strictEqual(history.alerts[0].hospitals[0].acknowledged, true);
});

test('the public deletion page is served', async () => {
    const res = await fetch(`${baseUrl}/delete-account`);
    assert.strictEqual(res.status, 200);
    assert.match(res.headers.get('content-type'), /text\/html/);
    assert.match(await res.text(), /Delete your Élan account/);
});
