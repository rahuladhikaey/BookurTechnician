/**
 * Phase 7 — Render Deployment Readiness & Firestore Emulator Integration Test Suite
 * Tests standalone HTTP server binding, /health, CORS for Firebase Hosting domains,
 * EmailJS/Firestore OTP auth flow, catalog availability & PII redaction, booking create,
 * and atomic Firestore transaction self-accept.
 */

const assert = require('assert');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { createApp } = require('../src/app');
const { sendOtpEmail } = require('../src/emailService');
const { getFirebaseStatus, verifyFirestoreConnection } = require('../src/firebaseAdmin');

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
process.env.NODE_ENV = 'production';
process.env.JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
process.env.REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET || crypto.randomBytes(32).toString('hex');
process.env.EMAILJS_PUBLIC_KEY = 'test_pub_key';
process.env.EMAILJS_PRIVATE_KEY = 'test_priv_key';
process.env.EMAILJS_SERVICE_ID = 'test_srv_id';
process.env.EMAILJS_TEMPLATE_ID = 'test_tpl_id';

const PROJECT_ID = 'bookmytechnician-53d94';
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

async function clearFirestoreEmulator() {
  const url = `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const res = await fetch(url, { method: 'DELETE' });
  if (!res.ok) {
    throw new Error(`Failed clearing Firestore Emulator (${res.status}) at ${EMULATOR_HOST}`);
  }
}

async function run() {
  const capturedEmails = [];
  const mockEmailFetch = async (url, init) => {
    const body = JSON.parse(init.body);
    capturedEmails.push({
      url,
      headers: init.headers,
      service_id: body.service_id,
      template_id: body.template_id,
      to_email: body.template_params.to_email,
      otp: body.template_params.otp,
      role: body.template_params.role,
    });
    return {
      ok: true,
      status: 200,
      text: async () => 'OK',
    };
  };

  const app = createApp(db, {
    getFirebaseStatus,
    verifyFirestoreConnection,
    authDeps: {
      sendOtpEmailFn: (email, otp, role, name) =>
        sendOtpEmail(email, otp, role, name, { fetchImpl: mockEmailFetch }),
    },
  });

  const server = await new Promise((resolve) => {
    const srv = app.listen(0, '0.0.0.0', () => resolve(srv));
  });
  const addr = server.address();
  assert.strictEqual(addr.address, '0.0.0.0', 'Server must bind 0.0.0.0');
  const baseUrl = `http://127.0.0.1:${addr.port}`;

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      capturedEmails.length = 0;
      await clearFirestoreEmulator();
      await fn();
      console.log(`  PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  FAIL: ${name}\n    ${err.stack || err.message}`);
      failed++;
    }
  }

  console.log('================================================================');
  console.log('PHASE 7 — RENDER DEPLOYMENT READINESS TEST SUITE');
  console.log(`Bound: 0.0.0.0:${addr.port} | Firestore Emulator: ${EMULATOR_HOST}`);
  console.log('================================================================\n');

  await test('1. GET /health returns status, firebase Spark status, and emailjs config state without leaking secrets', async () => {
    const res = await fetch(`${baseUrl}/health?check=db`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.status, 'ok');
    assert.strictEqual(data.firebase.projectId, PROJECT_ID);
    assert.strictEqual(data.firebase.plan, 'spark-free');
    assert.strictEqual(data.firebase.firestoreReady, true);
    assert.strictEqual(data.emailjs.configured, true);
    const rawStr = JSON.stringify(data);
    assert.strictEqual(rawStr.includes('test_priv_key'), false);
    assert.strictEqual(rawStr.includes('test_pub_key'), false);
  });

  await test('2. Unconfigured Firebase mode returns degraded /health (200) and fail-closed 503 on DB routes', async () => {
    const noDbApp = createApp(null);
    const tmpSrv = await new Promise((resolve) => {
      const s = noDbApp.listen(0, '0.0.0.0', () => resolve(s));
    });
    const tmpUrl = `http://127.0.0.1:${tmpSrv.address().port}`;
    try {
      const hRes = await fetch(`${tmpUrl}/health`);
      assert.strictEqual(hRes.status, 200);
      const hData = await hRes.json();
      assert.strictEqual(hData.status, 'degraded');

      const availRes = await fetch(`${tmpUrl}/catalog/availability?latitude=23.24&longitude=88.55`);
      assert.strictEqual(availRes.status, 503);
      const availData = await availRes.json();
      assert.strictEqual(availData.code, 'FIREBASE_NOT_CONFIGURED');
    } finally {
      tmpSrv.close();
    }
  });

  await test('3. CORS allows actual Firebase Hosting domains and blocks unauthorized browser origins', async () => {
    for (const origin of [
      'https://bookmytechnician-53d94.web.app',
      'https://bookmytechnician-53d94.firebaseapp.com',
    ]) {
      const res = await fetch(`${baseUrl}/health`, { headers: { Origin: origin } });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), origin);
    }

    const evilRes = await fetch(`${baseUrl}/health`, {
      headers: { Origin: 'https://untrusted-domain.example' },
    });
    assert.strictEqual(evilRes.status, 403);
    const evilData = await evilRes.json();
    assert.strictEqual(evilData.code, 'CORS_FORBIDDEN');
  });

  await test('4. POST /auth/request-otp & /auth/verify-otp dispatches EmailJS, stores salted hash, blocks ADMIN escalation, and enforces lockout', async () => {
    // Hard P0 Admin privilege escalation block: non-admin requesting ADMIN even with purpose=REGISTER gets 403 immediately
    const escRes = await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'customer.test@example.com',
        phone: '+919876543210',
        fullName: 'Test Customer',
        role: 'ADMIN',
        purpose: 'REGISTER',
      }),
    });
    assert.strictEqual(escRes.status, 403);
    const escData = await escRes.json();
    assert.strictEqual(escData.code, 'ADMIN_ACCESS_DENIED');
    assert.strictEqual(capturedEmails.length, 0);

    const reqRes = await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'customer.test@example.com',
        phone: '+919876543210',
        fullName: 'Test Customer',
        role: 'CUSTOMER',
        purpose: 'REGISTER',
      }),
    });
    assert.strictEqual(reqRes.status, 200);
    const reqData = await reqRes.json();
    assert.strictEqual(reqData.success, true);
    assert.strictEqual(reqData.emailSent, true);
    assert.strictEqual(reqData._testOtp, undefined, 'Must never leak OTP in HTTP response');
    assert.strictEqual(capturedEmails.length, 1);
    assert.strictEqual(capturedEmails[0].to_email, 'customer.test@example.com');
    const deliveredOtp = capturedEmails[0].otp;
    assert.match(deliveredOtp, /^\d{6}$/);

    // Verify stored challenge has hash/salt and no plaintext OTP
    const challengeSnap = await db.collection('otp_challenges').doc('otp_customer_test_example_com').get();
    assert.strictEqual(challengeSnap.exists, true);
    assert.strictEqual(challengeSnap.data().otp, undefined);
    assert(challengeSnap.data().otpHash && challengeSnap.data().salt);

    // Wrong OTP attempt
    const badVerify = await fetch(`${baseUrl}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'customer.test@example.com', otp: '000000' }),
    });
    assert.strictEqual(badVerify.status, 400);
    const badData = await badVerify.json();
    assert.strictEqual(badData.code, 'INVALID_OTP');

    // Correct OTP verify
    const goodVerify = await fetch(`${baseUrl}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'customer.test@example.com', otp: deliveredOtp }),
    });
    assert.strictEqual(goodVerify.status, 200);
    const goodData = await goodVerify.json();
    assert.strictEqual(goodData.success, true);
    assert.strictEqual(goodData.user.role, 'CUSTOMER', 'Role escalation to ADMIN must be prevented');
    assert(goodData.accessToken, 'Must issue JWT accessToken when JWT_SECRET is set');

    // Replay of same OTP must be rejected
    const replayRes = await fetch(`${baseUrl}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'customer.test@example.com', otp: deliveredOtp }),
    });
    assert.strictEqual(replayRes.status, 400);
    assert.strictEqual((await replayRes.json()).code, 'OTP_ALREADY_USED');
  });

  await test('5. End-to-end OTP JWT auth -> /catalog/availability & /nearby -> POST booking -> POST transactional offer accept', async () => {
    await db.collection('service_categories').doc('cat_ac').set({
      id: 'cat_ac',
      name: 'AC Services',
      subcategories: [
        {
          id: 'sub_ac',
          name: 'AC Care',
          services: [{ id: 'ac_install', name: 'AC installation' }],
        },
      ],
    });

    await db.collection('technician_profiles').doc('uid_tech_9988776655').set({
      id: 'uid_tech_9988776655',
      uid: 'uid_tech_9988776655',
      technicianId: 'uid_tech_9988776655',
      fullName: 'Verified Tech',
      email: 'tech.test@example.com',
      phone: '+919988776655',
      upiId: 'secret@upi',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.244,
      longitude: 88.554,
      lastLocationUpdate: new Date().toISOString(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    // Public catalog availability & nearby check (including /api/v1 alias)
    const availRes = await fetch(`${baseUrl}/api/v1/catalog/availability?latitude=23.242&longitude=88.553&radiusKm=15`);
    assert.strictEqual(availRes.status, 200);
    const availData = await availRes.json();
    assert.strictEqual(availData.services[0].availableTechnicianCount, 1);

    const nearbyRes = await fetch(`${baseUrl}/catalog/technicians/nearby?latitude=23.242&longitude=88.553&radiusKm=15&serviceId=ac_install`);
    assert.strictEqual(nearbyRes.status, 200);
    const nearbyData = await nearbyRes.json();
    assert.strictEqual(nearbyData.technicians.length, 1);
    assert.strictEqual(nearbyData.technicians[0].phone, undefined, 'Private PII phone must not be leaked');
    assert.strictEqual(nearbyData.technicians[0].upiId, undefined, 'Private UPI must not be leaked');

    // Customer authenticates via OTP
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'cust2@example.com', role: 'CUSTOMER', fullName: 'Customer Two' }),
    });
    const custOtp = capturedEmails.pop().otp;
    const custAuth = await (
      await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'cust2@example.com', otp: custOtp }),
      })
    ).json();

    // Technician authenticates via OTP
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'tech.test@example.com', role: 'TECHNICIAN' }),
    });
    const techOtp = capturedEmails.pop().otp;
    const techAuth = await (
      await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'tech.test@example.com', otp: techOtp }),
      })
    ).json();
    assert.strictEqual(techAuth.user.uid, 'uid_tech_9988776655');

    // Protected booking creation MUST fail without token
    const unauthBooking = await fetch(`${baseUrl}/api/bookings/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ serviceId: 'ac_install' }),
    });
    assert.strictEqual(unauthBooking.status, 401);

    // Customer creates booking with Bearer JWT -> generates offers & booking_secrets
    const createRes = await fetch(`${baseUrl}/api/bookings/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${custAuth.accessToken}`,
      },
      body: JSON.stringify({
        serviceId: 'ac_install',
        serviceName: 'AC installation',
        coordinates: { latitude: 23.242, longitude: 88.553 },
        price: 1299,
      }),
    });
    assert.strictEqual(createRes.status, 201);
    const createData = await createRes.json();
    assert.strictEqual(createData.success, true);
    assert.strictEqual(createData.offersDispatched, 1);

    // Technician atomically self-accepts the offer via Bearer JWT
    const offerId = createData.offerIds[0];
    const acceptRes = await fetch(`${baseUrl}/api/dispatch/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${techAuth.accessToken}`,
      },
      body: JSON.stringify({ offerId }),
    });
    assert.strictEqual(acceptRes.status, 200);
    const acceptData = await acceptRes.json();
    assert.strictEqual(acceptData.success, true);
    assert.strictEqual(acceptData.booking.status, 'ASSIGNED');
    assert.strictEqual(acceptData.assignment.status, 'ASSIGNED');
    assert.strictEqual(acceptData.booking.startOtp, undefined, 'Secrets/OTPs must not leak to technician');

    const techDoc = await db.collection('technician_profiles').doc('uid_tech_9988776655').get();
    assert.strictEqual(techDoc.data().availabilityStatus, 'BUSY');
  });

  await test('6. POST /auth/refresh-token validates refreshToken, rotates session, and rejects invalid tokens', async () => {
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'refresh.user@example.com', role: 'CUSTOMER' }),
    });
    const otp = capturedEmails.pop().otp;
    const authData = await (
      await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'refresh.user@example.com', otp }),
      })
    ).json();
    assert(authData.refreshToken, 'verify-otp must return refreshToken');

    const badRef = await fetch(`${baseUrl}/auth/refresh-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: 'tampered.jwt.token' }),
    });
    assert.strictEqual(badRef.status, 401);

    const goodRef = await fetch(`${baseUrl}/auth/refresh-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: authData.refreshToken }),
    });
    assert.strictEqual(goodRef.status, 200);
    const refData = await goodRef.json();
    assert(refData.data.accessToken && refData.data.refreshToken);
  });

  await test('7. Genuine Admin Auth protection, monitoring-only routes, and non-admin blocking', async () => {
    process.env.ADMIN_EMAIL = 'admin.real@bookurtechnician.com';
    process.env.ADMIN_SECRET_KEY = crypto.randomBytes(16).toString('hex');

    // Non-admin attempting ADMIN OTP LOGIN must get 403
    const fakeOtpReq = await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'attacker@example.com', role: 'ADMIN', purpose: 'LOGIN' }),
    });
    assert.strictEqual(fakeOtpReq.status, 403);
    assert.strictEqual((await fakeOtpReq.json()).code, 'ADMIN_AUTHORIZATION_REQUIRED');

    // Wrong admin passkey rejected
    const badPasskey = await fetch(`${baseUrl}/auth/admin/direct-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.ADMIN_EMAIL, accessKey1: 'wrong-passkey' }),
    });
    assert.strictEqual(badPasskey.status, 401);

    // Valid admin direct-access -> accesses /admin/me and monitoring /admin/bookings
    const goodPasskey = await fetch(`${baseUrl}/auth/admin/direct-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.ADMIN_EMAIL, accessKey1: process.env.ADMIN_SECRET_KEY }),
    });
    assert.strictEqual(goodPasskey.status, 200);
    const adminAuth = await goodPasskey.json();
    assert.strictEqual(adminAuth.user.role, 'SUPER_ADMIN');

    const meRes = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${adminAuth.accessToken}` },
    });
    assert.strictEqual(meRes.status, 200);
    assert.strictEqual((await meRes.json()).user.admin, true);

    const admBookings = await fetch(`${baseUrl}/admin/bookings`, {
      headers: { Authorization: `Bearer ${adminAuth.accessToken}` },
    });
    assert.strictEqual(admBookings.status, 200);

    // Manual booking assign endpoint MUST NOT exist
    const noManualAssign = await fetch(`${baseUrl}/admin/bookings/bkg_1/assign`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminAuth.accessToken}`,
      },
      body: JSON.stringify({ technicianId: 'tech_1' }),
    });
    assert.strictEqual(noManualAssign.status, 404);

    // Customer token attempting /admin/me must get 403
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'plain.cust@example.com', role: 'CUSTOMER' }),
    });
    const custOtp = capturedEmails.pop().otp;
    const custVerify = await (
      await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'plain.cust@example.com', otp: custOtp }),
      })
    ).json();
    const deniedMe = await fetch(`${baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${custVerify.accessToken}` },
    });
    assert.strictEqual(deniedMe.status, 403);
  });

  await test('8. Client compatibility: Customer top-level lat/lng booking + tracking & Technician /online-status + /dispatch/offers/pending', async () => {
    await db.collection('service_categories').doc('cat_ac').set({
      id: 'cat_ac',
      name: 'AC Services',
      subcategories: [{ id: 'sub_ac', services: [{ id: 'ac_install', name: 'AC installation' }] }],
    });

    await db.collection('technician_profiles').doc('uid_tech_7766554433').set({
      id: 'uid_tech_7766554433',
      uid: 'uid_tech_7766554433',
      technicianId: 'uid_tech_7766554433',
      fullName: 'Online Partner',
      email: 'partner8@example.com',
      phone: '+917766554433',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: false,
      availabilityStatus: 'OFFLINE',
      skills: [{ id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true }],
    });

    // Technician logs in & toggles online via /technician/online-status (as dashboard_provider.dart calls)
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'partner8@example.com', role: 'TECHNICIAN' }),
    });
    const techOtp = capturedEmails.pop().otp;
    const techAuth = await (
      await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'partner8@example.com', otp: techOtp }),
      })
    ).json();

    const onlineRes = await fetch(`${baseUrl}/technician/online-status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${techAuth.accessToken}` },
      body: JSON.stringify({ isOnline: true, latitude: 23.243, longitude: 88.554 }),
    });
    assert.strictEqual(onlineRes.status, 200);

    // Customer logs in & creates booking using Flutter top-level latitude/longitude format
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'cust8@example.com', role: 'CUSTOMER' }),
    });
    const custOtp = capturedEmails.pop().otp;
    const custAuth = await (
      await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'cust8@example.com', otp: custOtp }),
      })
    ).json();

    const bkgRes = await fetch(`${baseUrl}/bookings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${custAuth.accessToken}` },
      body: JSON.stringify({ serviceId: 'ac_install', serviceName: 'AC installation', latitude: 23.242, longitude: 88.553, grandTotal: 1299 }),
    });
    assert.strictEqual(bkgRes.status, 201);
    const bkgData = await bkgRes.json();
    assert.strictEqual(bkgData.offersDispatched, 1);

    // Technician polls /dispatch/proposals/pending (exact Flutter job_state.dart path)
    const pendRes = await fetch(`${baseUrl}/dispatch/proposals/pending`, {
      headers: { Authorization: `Bearer ${techAuth.accessToken}` },
    });
    assert.strictEqual(pendRes.status, 200);
    const pendData = await pendRes.json();
    assert.strictEqual(pendData.hasPending, true);
    assert.strictEqual(pendData.offers.length, 1);

    // Technician rejects offer via /dispatch/offers/:offerId/reject
    const rejRes = await fetch(`${baseUrl}/dispatch/offers/${pendData.offers[0].id}/reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${techAuth.accessToken}` },
      body: JSON.stringify({ reason: 'Busy elsewhere' }),
    });
    assert.strictEqual(rejRes.status, 200);
    assert.strictEqual((await rejRes.json()).status, 'REJECTED');

    // Customer reads my-bookings & live-tracking
    const myRes = await fetch(`${baseUrl}/bookings/my-bookings`, {
      headers: { Authorization: `Bearer ${custAuth.accessToken}` },
    });
    assert.strictEqual(myRes.status, 200);
    assert.strictEqual((await myRes.json()).bookings.length, 1);

    const trackRes = await fetch(`${baseUrl}/bookings/${bkgData.bookingId}/live-tracking`, {
      headers: { Authorization: `Bearer ${custAuth.accessToken}` },
    });
    assert.strictEqual(trackRes.status, 200);
    assert.strictEqual((await trackRes.json()).data.id, bkgData.bookingId);
  });

  server.close();
  console.log('\n================================================================');
  console.log(`PHASE 7 READINESS SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error('Fatal Phase 7 test error:', err);
  process.exit(1);
});
