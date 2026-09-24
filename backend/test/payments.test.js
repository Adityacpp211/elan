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

async function createOrder(auth, body = {}) {
    const res = await fetch(`${baseUrl}/api/payments/create-order`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({
            tier: 2,
            latitude: 12.8585,
            longitude: 76.4880,
            symptoms: 'Chest pain',
            ...body
        })
    });
    return { status: res.status, data: await res.json() };
}

test('POST /api/payments/create-order requires auth', async () => {
    const { status } = await createOrder({});
    assert.strictEqual(status, 401);
});

test('POST /api/payments/create-order validates tier and coordinates', async () => {
    const { auth } = await registerUser();

    const badTier = await createOrder(auth, { tier: 9 });
    assert.strictEqual(badTier.status, 400);

    const badCoords = await createOrder(auth, { latitude: 9999 });
    assert.strictEqual(badCoords.status, 400);
});

test('POST /api/payments/create-order creates a mock order', async () => {
    const { auth } = await registerUser();
    const { status, data } = await createOrder(auth);

    assert.strictEqual(status, 200);
    assert.ok(data.success);
    assert.ok(data.alertId);
    assert.ok(data.order.id);
    assert.strictEqual(data.order.amount, 200); // tier 2 = ₹2 = 200 paise
    assert.strictEqual(data.tier.level, 2);
    assert.strictEqual(data.tier.hospitalCount, 3);
});

test('POST /api/payments/verify binds payment to its alert', async () => {
    const alice = await registerUser({ email: `alice_${Date.now()}@test.com` });

    const order = await createOrder(alice.auth);
    const alertId = order.data.alertId;

    // Verify with the wrong alertId -> rejected
    const mismatch = await fetch(`${baseUrl}/api/payments/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...alice.auth },
        body: JSON.stringify({
            orderId: order.data.order.id,
            paymentId: 'pay_123',
            signature: 'sig',
            alertId: 'some-other-alert'
        })
    });
    assert.strictEqual(mismatch.status, 400);

    // Verify with an unknown order -> 404
    const unknown = await fetch(`${baseUrl}/api/payments/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...alice.auth },
        body: JSON.stringify({
            orderId: 'order_unknown',
            paymentId: 'pay_123',
            signature: 'sig',
            alertId
        })
    });
    assert.strictEqual(unknown.status, 404);

    // Correct verification succeeds
    const ok = await fetch(`${baseUrl}/api/payments/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...alice.auth },
        body: JSON.stringify({
            orderId: order.data.order.id,
            paymentId: 'pay_123',
            signature: 'sig',
            alertId
        })
    });
    assert.strictEqual(ok.status, 200);
    const okBody = await ok.json();
    assert.strictEqual(okBody.success, true);
});

test('POST /api/payments/verify blocks cross-user alert verification', async () => {
    const alice = await registerUser({ email: `alice2_${Date.now()}@test.com` });
    const mallory = await registerUser({ email: `mallory_${Date.now()}@test.com` });

    const order = await createOrder(alice.auth);

    // Mallory tries to verify Alice's pending alert -> forbidden
    const res = await fetch(`${baseUrl}/api/payments/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...mallory.auth },
        body: JSON.stringify({
            orderId: order.data.order.id,
            paymentId: 'pay_123',
            signature: 'sig',
            alertId: order.data.alertId
        })
    });
    assert.strictEqual(res.status, 403);
});

test('GET /api/payments/history returns payment records', async () => {
    const { auth } = await registerUser();
    await createOrder(auth, { tier: 1 });

    const res = await fetch(`${baseUrl}/api/payments/history`, { headers: auth });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.payments.length, 1);
    assert.strictEqual(body.payments[0].status, 'pending');
});