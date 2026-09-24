const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { start, stop, registerUser, adminToken } = require('./helpers');

let baseUrl;

before(async () => {
    ({ baseUrl } = await start());
});

after(async () => {
    await stop();
});

test('GET /api/hospitals requires lat and lng', async () => {
    const res = await fetch(`${baseUrl}/api/hospitals/nearby`);
    assert.strictEqual(res.status, 400);
});

test('GET /api/hospitals/nearby rejects out-of-range coordinates', async () => {
    const res = await fetch(`${baseUrl}/api/hospitals/nearby?lat=999&lng=76.48`);
    assert.strictEqual(res.status, 400);
});

test('GET /api/hospitals/nearby returns hospitals sorted by distance', async () => {
    const res = await fetch(`${baseUrl}/api/hospitals/nearby?lat=12.8585&lng=76.4880&radius=50`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.ok(body.count >= 1);
    const first = body.hospitals[0];
    assert.strictEqual(first.id, 'H002'); // Government hospital is at seeder coords
    assert.strictEqual(first.distanceKm, 0);
});

test('GET /api/hospitals lists seeded hospitals', async () => {
    const res = await fetch(`${baseUrl}/api/hospitals`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.count, 4);
});

test('GET /api/hospitals/:id returns a hospital and 404 for unknown ids', async () => {
    const ok = await fetch(`${baseUrl}/api/hospitals/H001`);
    assert.strictEqual(ok.status, 200);
    const found = await ok.json();
    assert.strictEqual(found.name, 'Bahubali Children Hospital');

    const missing = await fetch(`${baseUrl}/api/hospitals/NOPE`);
    assert.strictEqual(missing.status, 404);
});

test('POST /api/hospitals requires admin role', async () => {
    const { auth } = await registerUser();
    const res = await fetch(`${baseUrl}/api/hospitals`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({
            name: 'New Hospital',
            address: 'Somewhere',
            phone: '+91-0000000000',
            latitude: 12.86,
            longitude: 76.49
        })
    });
    assert.strictEqual(res.status, 403);
});

test('admin can create, update, and deactivate hospitals', async () => {
    const adminAuth = { Authorization: `Bearer ${adminToken()}` };

    const created = await fetch(`${baseUrl}/api/hospitals`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...adminAuth },
        body: JSON.stringify({
            name: 'New Hospital',
            address: 'Somewhere',
            phone: '+91-0000000000',
            emergencyEmail: 'new@hospital.com',
            latitude: 12.86,
            longitude: 76.49
        })
    });
    assert.strictEqual(created.status, 201);
    const createdBody = await created.json();
    const id = createdBody.hospital.id;
    assert.ok(id);

    const updated = await fetch(`${baseUrl}/api/hospitals/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', ...adminAuth },
        body: JSON.stringify({ name: 'Renamed Hospital' })
    });
    assert.strictEqual(updated.status, 200);
    assert.strictEqual((await updated.json()).hospital.name, 'Renamed Hospital');

    const deleted = await fetch(`${baseUrl}/api/hospitals/${id}`, {
        method: 'DELETE',
        headers: adminAuth
    });
    assert.strictEqual(deleted.status, 200);

    const list = await fetch(`${baseUrl}/api/hospitals`);
    const listBody = await list.json();
    assert.strictEqual(listBody.count, 4); // soft delete removes it from the active list
});

test('admin hospital create rejects invalid coordinates', async () => {
    const adminAuth = { Authorization: `Bearer ${adminToken()}` };
    const res = await fetch(`${baseUrl}/api/hospitals`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...adminAuth },
        body: JSON.stringify({
            name: 'Bad',
            address: 'Nowhere',
            phone: '+91-0000000000',
            latitude: 9999,
            longitude: 76.49
        })
    });
    assert.strictEqual(res.status, 400);
});