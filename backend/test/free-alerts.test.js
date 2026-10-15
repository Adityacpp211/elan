// Free-alert mode (the default for the Play Store build): no payment step.
process.env.ALERTS_FREE = 'true';

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

function post(path, body, headers = {}) {
    return fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...headers },
        body: JSON.stringify(body)
    });
}

test('a free alert needs no tier or payment and sends straight away', async () => {
    const { auth } = await registerUser();

    const create = await post('/api/payments/create-order', {
        latitude: 12.8585, longitude: 76.4880, symptoms: 'Chest pain'
    }, auth);
    assert.strictEqual(create.status, 200);
    const order = await create.json();
    assert.strictEqual(order.paymentRequired, false);
    assert.strictEqual(order.order, undefined);
    assert.strictEqual(order.tier.hospitalCount, 3);

    // No /verify call: the alert can be sent immediately
    const send = await post('/api/alerts/send', { alertId: order.alertId }, auth);
    assert.strictEqual(send.status, 200);
    assert.strictEqual((await send.json()).hospitalsNotified, 3);
});

test('a client-supplied tier cannot change the free reach', async () => {
    const { auth } = await registerUser();
    const order = await (await post('/api/payments/create-order', {
        tier: 3, latitude: 12.8585, longitude: 76.4880
    }, auth)).json();
    assert.strictEqual(order.tier.level, 2);
});

test('free alerts are recorded as ₹0, not as unpaid', async () => {
    const { auth } = await registerUser();
    const order = await (await post('/api/payments/create-order', {
        latitude: 12.8585, longitude: 76.4880
    }, auth)).json();

    const history = await (await fetch(`${baseUrl}/api/payments/history`, { headers: auth })).json();
    const entry = history.payments.find((p) => p.alertId === order.alertId);
    assert.strictEqual(entry.amount, '₹0');
    assert.strictEqual(entry.status, 'completed');
});

test('free alerts still refuse to create anything with no hospital in range', async () => {
    const { auth } = await registerUser();
    const res = await post('/api/payments/create-order', { latitude: 0, longitude: 0 }, auth);
    assert.strictEqual(res.status, 404);
});
