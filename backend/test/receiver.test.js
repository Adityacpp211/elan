const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { start, stop, registerUser, registerHospitalStaff } = require('./helpers');

let baseUrl;

before(async () => {
    ({ baseUrl } = await start());
});

after(async () => {
    await stop();
});

/// The seeded hospitals, ordered by distance from the alert coordinates below
/// (12.8585, 76.4880 — which sits on top of H002).
const HOSPITALS = {
    nearest: 'H002',
    second: 'H003',
    third: 'H001',
    far: 'H004'
};

async function createSentAlert(tier = 2) {
    const { auth } = await registerUser();

    const orderRes = await fetch(`${baseUrl}/api/payments/create-order`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({
            tier,
            latitude: 12.8585,
            longitude: 76.4880,
            symptoms: 'Chest pain, breathlessness',
            message: 'Father collapsed at home'
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

    const sendRes = await fetch(`${baseUrl}/api/alerts/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({ alertId: order.alertId })
    });
    assert.strictEqual(sendRes.status, 200);

    return { auth, alertId: order.alertId };
}

test('receiver routes reject unauthenticated callers', async () => {
    for (const path of ['/api/receiver/inbox', '/api/receiver/profile']) {
        const res = await fetch(`${baseUrl}${path}`);
        assert.strictEqual(res.status, 401, path);
    }
});

test('receiver routes reject members', async () => {
    const { auth } = await registerUser();
    const res = await fetch(`${baseUrl}/api/receiver/inbox`, { headers: auth });
    assert.strictEqual(res.status, 403);
});

test('registering as hospital staff requires a known hospital', async () => {
    const missing = await registerHospitalStaff(undefined);
    assert.strictEqual(missing.status, 400);
    assert.match(missing.data.error, /hospitalId is required/);

    const unknown = await registerHospitalStaff('does-not-exist');
    assert.strictEqual(unknown.status, 400);
    assert.match(unknown.data.error, /Unknown or inactive hospital/);
});

test('registering as admin over self-service is rejected', async () => {
    const { status, data } = await registerUser({ role: 'admin' });
    assert.strictEqual(status, 400);
    assert.match(data.error, /Invalid role/);
});

test('hospital staff account carries its hospital on the token and profile', async () => {
    const staff = await registerHospitalStaff(HOSPITALS.nearest);
    assert.strictEqual(staff.status, 201);
    assert.strictEqual(staff.data.user.role, 'hospital');
    assert.strictEqual(staff.data.user.hospitalId, HOSPITALS.nearest);

    const me = await fetch(`${baseUrl}/api/auth/me`, { headers: staff.auth });
    assert.strictEqual(me.status, 200);
    const profile = await me.json();
    assert.strictEqual(profile.hospitalId, HOSPITALS.nearest);
    assert.strictEqual(profile.hospital.name, 'Shravanabelagola Government Hospital');
});

test('receiver inbox lists only the alerts addressed to that hospital', async () => {
    const { alertId } = await createSentAlert(2);

    const recipient = await registerHospitalStaff(HOSPITALS.nearest);
    const inbox = await fetch(`${baseUrl}/api/receiver/inbox`, { headers: recipient.auth });
    assert.strictEqual(inbox.status, 200);
    const body = await inbox.json();

    assert.strictEqual(body.hospital.id, HOSPITALS.nearest);
    assert.ok(body.alerts.some((a) => a.id === alertId), 'recipient sees the alert');

    const alert = body.alerts.find((a) => a.id === alertId);
    assert.strictEqual(alert.status, 'pending');
    assert.deepStrictEqual(alert.symptoms, ['Chest pain', 'breathlessness']);
    assert.strictEqual(alert.patientName, 'Test User');
    assert.ok(
        alert.location.mapsUrl.includes('12.8585'),
        'has a maps deep link'
    );

    // A hospital outside the notified set must not see it.
    const bystander = await registerHospitalStaff(HOSPITALS.far);
    const otherInbox = await fetch(`${baseUrl}/api/receiver/inbox`, { headers: bystander.auth });
    const otherBody = await otherInbox.json();
    assert.ok(!otherBody.alerts.some((a) => a.id === alertId), 'bystander does not see the alert');
});

test('receiver inbox rejects an unknown status filter', async () => {
    const staff = await registerHospitalStaff(HOSPITALS.nearest);
    const res = await fetch(`${baseUrl}/api/receiver/inbox?status=exploded`, {
        headers: staff.auth
    });
    assert.strictEqual(res.status, 400);
});

test('acknowledging an alert updates the hospital view and the alert status', async () => {
    const { alertId } = await createSentAlert(1);
    const staff = await registerHospitalStaff(HOSPITALS.nearest);

    const res = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ etaMinutes: 8 })
    });
    assert.strictEqual(res.status, 200);
    const body = await res.json();

    assert.strictEqual(body.success, true);
    assert.strictEqual(body.alert.status, 'acknowledged');
    assert.strictEqual(body.alert.etaMinutes, 8);
    assert.strictEqual(body.alertStatus, 'acknowledged');

    const detail = await fetch(`${baseUrl}/api/receiver/inbox/${alertId}`, {
        headers: staff.auth
    });
    const detailBody = await detail.json();
    assert.strictEqual(detailBody.alert.status, 'acknowledged');
    assert.ok(detailBody.alert.acknowledgedAt);
    assert.strictEqual(detailBody.alert.respondedBy, staff.data.user.email);

    const profile = await fetch(`${baseUrl}/api/receiver/profile`, { headers: staff.auth });
    const profileBody = await profile.json();
    assert.strictEqual(profileBody.hospital.id, HOSPITALS.nearest);
    assert.ok(profileBody.stats.acknowledged >= 1);
});

test('acknowledging validates the ETA and refuses alerts from other hospitals', async () => {
    const { alertId } = await createSentAlert(1);
    const staff = await registerHospitalStaff(HOSPITALS.nearest);

    const badEta = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ etaMinutes: 5000 })
    });
    assert.strictEqual(badEta.status, 400);

    const bystander = await registerHospitalStaff(HOSPITALS.far);
    const res = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...bystander.auth },
        body: JSON.stringify({})
    });
    assert.strictEqual(res.status, 404);
});

test('a decline is recorded and only escalates the alert when every hospital declines', async () => {
    const { alertId } = await createSentAlert(1);
    const staff = await registerHospitalStaff(HOSPITALS.nearest);

    const res = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/decline`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ reason: 'No cath lab available' })
    });
    assert.strictEqual(res.status, 200);
    const body = await res.json();

    assert.strictEqual(body.alert.status, 'declined');
    assert.strictEqual(body.alert.declineReason, 'No cath lab available');
    assert.strictEqual(body.alertStatus, 'unacknowledged');
});

test('a single acknowledgement keeps the alert acknowledged even if others decline', async () => {
    const { alertId } = await createSentAlert(3);

    const first = await registerHospitalStaff(HOSPITALS.nearest);
    const second = await registerHospitalStaff(HOSPITALS.second);

    const decline = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/decline`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...first.auth },
        body: JSON.stringify({ reason: 'Team on another case' })
    });
    assert.strictEqual(decline.status, 200);

    const acknowledge = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...second.auth },
        body: JSON.stringify({ etaMinutes: 12 })
    });
    assert.strictEqual(acknowledge.status, 200);
    assert.strictEqual((await acknowledge.json()).alertStatus, 'acknowledged');
});

test('re-acknowledging after a decline clears the decline', async () => {
    const { alertId } = await createSentAlert(1);
    const staff = await registerHospitalStaff(HOSPITALS.nearest);

    await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/decline`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ reason: 'Wrong desk' })
    });

    const res = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ etaMinutes: 5 })
    });
    const alert = (await res.json()).alert;

    assert.strictEqual(alert.status, 'acknowledged');
    assert.strictEqual(alert.declineReason, null);
});

test('the member sees acknowledgement and ETA in their alert history', async () => {
    const { auth, alertId } = await createSentAlert(1);
    const staff = await registerHospitalStaff(HOSPITALS.nearest);

    await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ etaMinutes: 6 })
    });

    const res = await fetch(`${baseUrl}/api/alerts/${alertId}`, { headers: auth });
    assert.strictEqual(res.status, 200);
    const body = await res.json();

    assert.strictEqual(body.status, 'acknowledged');
    const hospital = body.hospitals.find((h) => h.acknowledged);
    assert.ok(hospital, 'the acknowledging hospital is flagged');
    assert.strictEqual(hospital.etaMinutes, 6);

    const history = await fetch(`${baseUrl}/api/alerts/history`, { headers: auth });
    const historyBody = await history.json();
    const listed = historyBody.alerts.find((a) => a.id === alertId);
    assert.ok(listed.hospitals.some((h) => h.acknowledged && h.etaMinutes === 6));
});

test('the inbox status filter narrows the list', async () => {
    const staff = await registerHospitalStaff(HOSPITALS.nearest);
    const { alertId } = await createSentAlert(1);

    await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ etaMinutes: 7 })
    });

    const acknowledged = await fetch(`${baseUrl}/api/receiver/inbox?status=acknowledged`, {
        headers: staff.auth
    });
    const acknowledgedBody = await acknowledged.json();
    assert.ok(acknowledgedBody.alerts.length >= 1);
    assert.ok(acknowledgedBody.alerts.every((a) => a.status === 'acknowledged'));
    assert.ok(acknowledgedBody.alerts.some((a) => a.id === alertId));

    const pending = await fetch(`${baseUrl}/api/receiver/inbox?status=pending`, {
        headers: staff.auth
    });
    const pendingBody = await pending.json();
    assert.ok(!pendingBody.alerts.some((a) => a.id === alertId));
});

test('an acknowledged alert cannot be broadcast a second time', async () => {
    const { auth, alertId } = await createSentAlert(1);
    const staff = await registerHospitalStaff(HOSPITALS.nearest);

    // A receiver response moves the alert off 'sent', which used to reopen the
    // duplicate-send guard.
    const ack = await fetch(`${baseUrl}/api/receiver/alerts/${alertId}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...staff.auth },
        body: JSON.stringify({ etaMinutes: 5 })
    });
    assert.strictEqual(ack.status, 200);

    const resend = await fetch(`${baseUrl}/api/alerts/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...auth },
        body: JSON.stringify({ alertId })
    });
    assert.strictEqual(resend.status, 400);
    assert.strictEqual((await resend.json()).error, 'Alert already sent');
});
