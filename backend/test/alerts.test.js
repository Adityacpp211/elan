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

async function createPaidAlert(auth, tier = 2) {
    const orderRes = await fetch(`${baseUrl}/api/payments/create-order`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({
            tier,
            latitude: 12.8585,
            longitude: 76.4880,
            symptoms: 'Chest pain',
            message: 'Help please'
        })
    });
    const order = await orderRes.json();

    const verifyRes = await fetch(`${baseUrl}/api/payments/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({
            orderId: order.order.id,
            paymentId: 'pay_123',
            signature: 'sig',
            alertId: order.alertId
        })
    });
    assert.strictEqual(verifyRes.status, 200);

    return order.alertId;
}

test('GET /api/alerts/history requires auth', async () => {
    const res = await fetch(`${baseUrl}/api/alerts/history`);
    assert.strictEqual(res.status, 401);
});

test('POST /api/alerts/send rejects alerts without completed payment', async () => {
    const { auth } = await registerUser();

    // Create an order but do NOT verify payment
    const orderRes = await fetch(`${baseUrl}/api/payments/create-order`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({
            tier: 1,
            latitude: 12.8585,
            longitude: 76.4880
        })
    });
    const { alertId } = await orderRes.json();

    const res = await fetch(`${baseUrl}/api/alerts/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({ alertId })
    });
    assert.strictEqual(res.status, 400);
});

test('POST /api/alerts/send delivers to the tier hospital count', async () => {
    const { auth } = await registerUser();
    const alertId = await createPaidAlert(auth, 2);

    const res = await fetch(`${baseUrl}/api/alerts/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({ alertId })
    });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.hospitalsNotified, 3);
    for (const hospital of body.hospitals) {
        assert.strictEqual(hospital.notificationSent, true);
        assert.strictEqual(hospital.emailSent, true); // mock email fallback
    }
});

test('POST /api/alerts/send cannot send the same alert twice', async () => {
    const { auth } = await registerUser();
    const alertId = await createPaidAlert(auth, 1);

    const first = await fetch(`${baseUrl}/api/alerts/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({ alertId })
    });
    assert.strictEqual(first.status, 200);

    const second = await fetch(`${baseUrl}/api/alerts/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({ alertId })
    });
    assert.strictEqual(second.status, 400);
});

test('GET /api/alerts/history shows sent alerts with hospital details', async () => {
    const { auth } = await registerUser();
    await createPaidAlert(auth, 2);
    const alertId = await createPaidAlert(auth, 1);

    const res = await fetch(`${baseUrl}/api/alerts/history`, { headers: auth });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.alerts.length, 2);

    const sent = body.alerts.find(a => a.id === alertId);
    assert.ok(sent);
    assert.strictEqual(sent.status, 'payment_verified'); // not yet 'sent' in this test
});