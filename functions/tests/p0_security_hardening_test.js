/**
 * BookurTechnician — P0 Security & Authentication Hardening Test Suite
 * Runs against Cloud Firestore Emulator (127.0.0.1:8085) enforcing local firestore.rules
 * and standalone Express app (`functions/src/app.js`).
 */

const assert = require('assert');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { createApp } = require('../src/app');
const { sendOtpEmail } = require('../src/emailService');
const { getFirebaseStatus, verifyFirestoreConnection } = require('../src/firebaseAdmin');
const { signJwt } = require('../src/jwtHelper');

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
process.env.NODE_ENV = 'production';
process.env.JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
process.env.REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET || crypto.randomBytes(32).toString('hex');
process.env.ADMIN_EMAIL = 'admin.verified@bookurtechnician.com';
process.env.ADMIN_SECRET_KEY = 'Adm!nSuperKey#2026';
process.env.EMAILJS_PUBLIC_KEY = 'pub_key_test';
process.env.EMAILJS_PRIVATE_KEY = 'priv_key_test';
process.env.EMAILJS_SERVICE_ID = 'srv_test';
process.env.EMAILJS_TEMPLATE_ID = 'tpl_test';

const PROJECT_ID = 'bookmytechnician-53d94';
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const FIRESTORE_REST_BASE = `http://${EMULATOR_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

function makeEmulatorJwt(uid, claims = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      iss: `https://securetoken.google.com/${PROJECT_ID}`,
      aud: PROJECT_ID,
      auth_time: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      sub: uid,
      user_id: uid,
      ...claims,
    })
  ).toString('base64url');
  return `Bearer ${header}.${payload}.`;
}

function toFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined) continue;
    if (v === null) fields[k] = { nullValue: null };
    else if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    else if (typeof v === 'number') {
      fields[k] = Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
    } else if (typeof v === 'string') fields[k] = { stringValue: v };
    else if (Array.isArray(v)) {
      fields[k] = {
        arrayValue: {
          values: v.map((item) =>
            typeof item === 'object' && item !== null ? { mapValue: toFields(item) } : { stringValue: String(item) }
          ),
        },
      };
    } else if (typeof v === 'object') {
      fields[k] = { mapValue: toFields(v) };
    }
  }
  return { fields };
}

async function clearFirestoreEmulator() {
  const url = `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const res = await fetch(url, { method: 'DELETE' });
  if (!res.ok) {
    throw new Error(`Failed clearing Firestore Emulator (${res.status}) at ${EMULATOR_HOST}`);
  }
}

async function firestoreRest(docPath, method = 'GET', body = null, authHeader = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (authHeader) headers.Authorization = authHeader;
  const res = await fetch(`${FIRESTORE_REST_BASE}/${docPath}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (_) {}
  return { status: res.status, data };
}

async function run() {
  const capturedEmails = [];
  const mockEmailFetch = async (url, init) => {
    const payload = JSON.parse(init.body);
    capturedEmails.push(payload.template_params);
    return { ok: true, status: 200, text: async () => 'OK' };
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
    const srv = app.listen(0, '127.0.0.1', () => resolve(srv));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

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
  console.log('P0 SECURITY & AUTH HARDENING TEST SUITE (FIRESTORE EMULATOR)');
  console.log(`Emulator: ${EMULATOR_HOST} | API: ${baseUrl}`);
  console.log('================================================================\n');

  await test('1. Customer cannot assign or escalate role/admin in Firestore users/{uid} or via Admin OTP', async () => {
    const custUid = 'uid_cust_attacker';
    const custFbToken = makeEmulatorJwt(custUid, { role: 'CUSTOMER' });

    // Customer cannot create users/{uid} with role/admin fields
    const badCreate = await firestoreRest(
      `users?documentId=${custUid}`,
      'POST',
      toFields({ email: 'attacker@example.com', fullName: 'Attacker', role: 'ADMIN', admin: true }),
      custFbToken
    );
    assert.strictEqual(badCreate.status, 403, `Self-creating ADMIN in users must be 403, got ${badCreate.status}`);

    // Seed normal customer users/{uid} doc via Admin SDK
    await db.collection('users').doc(custUid).set({
      id: custUid,
      uid: custUid,
      email: 'attacker@example.com',
      fullName: 'Legit Customer',
      role: 'CUSTOMER',
    });

    // Customer CANNOT modify role/isAdmin on update
    const badUpdateRole = await firestoreRest(
      `users/${custUid}?updateMask.fieldPaths=role`,
      'PATCH',
      toFields({ role: 'SUPER_ADMIN' }),
      custFbToken
    );
    assert.strictEqual(badUpdateRole.status, 403, 'Modifying users.role must be denied (403)');

    const badUpdateAdminFlag = await firestoreRest(
      `users/${custUid}?updateMask.fieldPaths=isAdmin`,
      'PATCH',
      toFields({ isAdmin: true }),
      custFbToken
    );
    assert.strictEqual(badUpdateAdminFlag.status, 403, 'Adding users.isAdmin must be denied (403)');

    // Legitimate customer profile fields still update cleanly
    const goodUpdate = await firestoreRest(
      `users/${custUid}?updateMask.fieldPaths=fullName&updateMask.fieldPaths=fcmToken`,
      'PATCH',
      toFields({ fullName: 'Updated Name', fcmToken: 'fcm_tok_123' }),
      custFbToken
    );
    assert.strictEqual(goodUpdate.status, 200, 'Legitimate user profile update must succeed');

    // Even if DB `users` doc somehow has role=ADMIN, backend isGenuineAdminEmail MUST ignore users collection
    await db.collection('users').doc(custUid).set({ role: 'ADMIN' }, { merge: true });
    for (const purpose of ['LOGIN', 'REGISTER', '']) {
      const otpAdminTry = await fetch(`${baseUrl}/auth/request-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'attacker@example.com', role: 'ADMIN', ...(purpose ? { purpose } : {}) }),
      });
      assert.strictEqual(otpAdminTry.status, 403, `Admin OTP must reject non-allowlisted user (purpose=${purpose})`);
    }

    // Refresh token issued to CUSTOMER cannot be refreshed into ADMIN even if users/{uid}.role was tampered
    const custRefreshToken = signJwt(
      { uid: custUid, id: custUid, email: 'attacker@example.com', role: 'CUSTOMER', tokenType: 'refresh' },
      process.env.REFRESH_TOKEN_SECRET,
      3600
    );
    const refRes = await fetch(`${baseUrl}/auth/refresh-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: custRefreshToken }),
    });
    assert.strictEqual(refRes.status, 403, 'Tampered users.role upgrade on refresh must be rejected with 403');
  });

  await test('2. Technician cannot verify own skills, selectedSkills, KYC, or approval fields in Firestore (create & update)', async () => {
    const techUid = 'uid_tech_selfverify';
    const techFbToken = makeEmulatorJwt(techUid, { role: 'TECHNICIAN' });

    // Create with skills/kycStatus/accountStatus/isAdminApproved must fail
    const badCreate1 = await firestoreRest(
      `technician_profiles?documentId=${techUid}`,
      'POST',
      toFields({
        id: techUid,
        skills: [{ id: 'ac_install', verificationStatus: 'VERIFIED', enabled: true }],
      }),
      techFbToken
    );
    assert.strictEqual(badCreate1.status, 403, 'Client create with skills must be 403');

    const badCreate2 = await firestoreRest(
      `technician_profiles?documentId=${techUid}`,
      'POST',
      toFields({ id: techUid, accountStatus: 'ACTIVE', kycStatus: 'VERIFIED', isAdminApproved: true }),
      techFbToken
    );
    assert.strictEqual(badCreate2.status, 403, 'Client create with accountStatus/kycStatus/isAdminApproved must be 403');

    // Seed unapproved technician profile via Admin SDK (verify technician cannot escalate PENDING -> VERIFIED/ACTIVE)
    await db.collection('technician_profiles').doc(techUid).set({
      id: techUid,
      uid: techUid,
      accountStatus: 'PENDING_VERIFICATION',
      kycStatus: 'PENDING',
      isAdminApproved: false,
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      skills: [{ id: 'ac_install', verificationStatus: 'PENDING', enabled: true }],
      selectedSkills: [{ id: 'ac_install', verificationStatus: 'PENDING', enabled: true }],
      walletBalance: 100,
    });

    // Technician cannot tamper with skills, selectedSkills, kycStatus, accountStatus, isAdminApproved, walletBalance
    for (const [field, val] of [
      ['skills', [{ id: 'ac_install', verificationStatus: 'VERIFIED', enabled: true }]],
      ['selectedSkills', [{ id: 'ac_install', verificationStatus: 'VERIFIED', enabled: true }]],
      ['skillVerificationStatus', 'VERIFIED'],
      ['kycStatus', 'VERIFIED'],
      ['accountStatus', 'ACTIVE'],
      ['isAdminApproved', true],
      ['walletBalance', 99999],
      ['activeBookingId', null],
    ]) {
      const patchRes = await firestoreRest(
        `technician_profiles/${techUid}?updateMask.fieldPaths=${field}`,
        'PATCH',
        toFields({ [field]: val }),
        techFbToken
      );
      assert.strictEqual(patchRes.status, 403, `Direct client update to ${field} must be blocked (403), got ${patchRes.status}`);
    }

    // Legitimate GPS/online presence update succeeds
    const okPatch = await firestoreRest(
      `technician_profiles/${techUid}?updateMask.fieldPaths=isOnline&updateMask.fieldPaths=latitude&updateMask.fieldPaths=longitude&updateMask.fieldPaths=lastLocationUpdate`,
      'PATCH',
      toFields({ isOnline: false, latitude: 22.57, longitude: 88.36, lastLocationUpdate: new Date().toISOString() }),
      techFbToken
    );
    assert.strictEqual(okPatch.status, 200, 'Legitimate technician online/GPS update must succeed');
  });

  await test('3. Role isolation: Customer cannot call Technician APIs and Technician cannot create Customer bookings', async () => {
    const custJwt = signJwt(
      { uid: 'uid_cust_role_1', id: 'uid_cust_role_1', email: 'c@example.com', role: 'CUSTOMER', tokenType: 'access' },
      process.env.JWT_SECRET,
      3600
    );
    const techJwt = signJwt(
      { uid: 'uid_tech_role_1', id: 'uid_tech_role_1', email: 't@example.com', role: 'TECHNICIAN', tokenType: 'access' },
      process.env.JWT_SECRET,
      3600
    );
    const refreshJwt = signJwt(
      { uid: 'uid_cust_role_1', id: 'uid_cust_role_1', email: 'c@example.com', role: 'CUSTOMER', tokenType: 'refresh' },
      process.env.JWT_SECRET,
      3600
    );

    // Refresh token must NOT work as bearer access token
    const refreshAsBearer = await fetch(`${baseUrl}/bookings/my-bookings`, {
      headers: { Authorization: `Bearer ${refreshJwt}` },
    });
    assert.strictEqual(refreshAsBearer.status, 401);

    // Customer calling Technician APIs -> ALL 403
    for (const [method, path, body] of [
      ['POST', '/technician/online-status', { isOnline: true, latitude: 22.57, longitude: 88.36 }],
      ['POST', '/presence/heartbeat', { isOnline: true, latitude: 22.57, longitude: 88.36 }],
      ['POST', '/technicians/skills/bulk', { skills: [{ id: 'ac_install', name: 'AC installation' }] }],
      ['GET', '/technicians/skills', null],
      ['PATCH', '/technicians/skills/ac_install/toggle', { enabled: true }],
      ['GET', '/dispatch/offers/pending', null],
      ['POST', '/dispatch/offers/offer_1/accept', {}],
      ['POST', '/dispatch/offers/offer_1/reject', {}],
      ['POST', '/api/bookings/bkg_1/verify-start-otp', { otp: '1234' }],
      ['POST', '/api/bookings/bkg_1/verify-end-otp', { otp: '1234' }],
      ['PATCH', '/bookings/bkg_1/status', { status: 'IN_PROGRESS', startOtp: '1234' }],
    ]) {
      const res = await fetch(`${baseUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${custJwt}` },
        body: body ? JSON.stringify(body) : undefined,
      });
      assert.strictEqual(res.status, 403, `Customer ${method} ${path} must return 403, got ${res.status}`);
    }

    // Ensure customer never created a technician_profiles doc via presence
    const fakeTechSnap = await db.collection('technician_profiles').doc('uid_cust_role_1').get();
    assert.strictEqual(fakeTechSnap.exists, false);

    // Technician calling Customer-only APIs -> 403
    for (const [method, path, body] of [
      ['POST', '/bookings', { serviceId: 'ac_install', latitude: 22.57, longitude: 88.36 }],
      ['POST', '/api/bookings/create', { serviceId: 'ac_install', latitude: 22.57, longitude: 88.36 }],
      ['GET', '/bookings/my-bookings', null],
      ['GET', '/bookings/bkg_1/customer-otps', null],
    ]) {
      const res = await fetch(`${baseUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${techJwt}` },
        body: body ? JSON.stringify(body) : undefined,
      });
      assert.strictEqual(res.status, 403, `Technician ${method} ${path} must return 403, got ${res.status}`);
    }
  });

  await test('4. Unauthorized user cannot read or write booking_chats or legacy dispatch_requests', async () => {
    await db.collection('bookings').doc('bkg_chat_sec').set({
      id: 'bkg_chat_sec',
      customerId: 'cust_alice',
      technicianId: 'tech_bob',
      status: 'ASSIGNED',
    });
    await db.collection('booking_chats').doc('bkg_chat_sec').set({ bookingId: 'bkg_chat_sec' });
    await db.collection('booking_chats').doc('bkg_chat_sec').collection('messages').doc('m1').set({
      senderId: 'cust_alice',
      message: 'Hello Bob',
    });

    const aliceToken = makeEmulatorJwt('cust_alice', { role: 'CUSTOMER' });
    const bobToken = makeEmulatorJwt('tech_bob', { role: 'TECHNICIAN' });
    const strangerToken = makeEmulatorJwt('user_stranger', { role: 'CUSTOMER' });
    const otherTechToken = makeEmulatorJwt('tech_other', { role: 'TECHNICIAN' });
    const adminToken = makeEmulatorJwt('admin_1', { role: 'ADMIN', admin: true });

    // Stranger & unassigned technician blocked from reading & writing chat messages
    for (const badTok of [null, strangerToken, otherTechToken]) {
      const rRead = await firestoreRest('booking_chats/bkg_chat_sec/messages/m1', 'GET', null, badTok);
      assert.strictEqual(rRead.status, 403, 'Non-participant chat read must be 403');
      const rWrite = await firestoreRest(
        'booking_chats/bkg_chat_sec/messages?documentId=m_evil',
        'POST',
        toFields({ senderId: 'user_stranger', message: 'Intrusion' }),
        badTok
      );
      assert.strictEqual(rWrite.status, 403, 'Non-participant chat write must be 403');
    }

    // Bob spoofing senderId as Alice must be rejected
    const spoofSender = await firestoreRest(
      'booking_chats/bkg_chat_sec/messages?documentId=m_spoof',
      'POST',
      toFields({ senderId: 'cust_alice', message: 'Spoofed' }),
      bobToken
    );
    assert.strictEqual(spoofSender.status, 403, 'Participant cannot spoof another senderId');

    // Actual customer, assigned technician, and verified Admin succeed
    assert.strictEqual((await firestoreRest('booking_chats/bkg_chat_sec/messages/m1', 'GET', null, aliceToken)).status, 200);
    assert.strictEqual((await firestoreRest('booking_chats/bkg_chat_sec/messages/m1', 'GET', null, bobToken)).status, 200);
    assert.strictEqual((await firestoreRest('booking_chats/bkg_chat_sec/messages/m1', 'GET', null, adminToken)).status, 200);
    const bobWrite = await firestoreRest(
      'booking_chats/bkg_chat_sec/messages?documentId=m2',
      'POST',
      toFields({ senderId: 'tech_bob', message: 'On my way' }),
      bobToken
    );
    assert.strictEqual(bobWrite.status, 200, 'Assigned technician chat send must succeed');

    // Legacy dispatch_requests locked down completely
    assert.strictEqual(
      (await firestoreRest('dispatch_requests?documentId=dr1', 'POST', toFields({ technicianId: 'tech_bob' }), bobToken)).status,
      403
    );
    assert.strictEqual((await firestoreRest('dispatch_requests/dr1', 'GET', null, bobToken)).status, 403);
  });

  await test('5. Valid Customer/Technician/Admin flows & HTTP concurrent self-accept yields strictly one winner', async () => {
    const nowIso = new Date().toISOString();
    for (const [idx, uid] of ['uid_tech_win_1', 'uid_tech_win_2', 'uid_tech_win_3'].entries()) {
      await db.collection('technician_profiles').doc(uid).set({
        id: uid,
        uid,
        technicianId: uid,
        email: `tech${idx + 1}@example.com`,
        fullName: `Tech ${idx + 1}`,
        accountStatus: 'ACTIVE',
        kycStatus: 'VERIFIED',
        isOnline: true,
        availabilityStatus: 'AVAILABLE',
        latitude: 22.5726,
        longitude: 88.3639,
        lastLocationUpdate: nowIso,
        skills: [{ id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true }],
      });
    }

    // Valid Admin direct-access + OTP Admin access both work
    const admRes = await fetch(`${baseUrl}/auth/admin/direct-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.ADMIN_EMAIL, accessKey1: process.env.ADMIN_SECRET_KEY }),
    });
    assert.strictEqual(admRes.status, 200);
    const admData = await admRes.json();
    assert.strictEqual(admData.user.role, 'SUPER_ADMIN');
    assert.strictEqual((await fetch(`${baseUrl}/admin/stats`, { headers: { Authorization: `Bearer ${admData.accessToken}` } })).status, 200);

    // Valid Admin OTP LOGIN succeeds for verified admin
    const admOtpReq = await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.ADMIN_EMAIL, role: 'ADMIN', purpose: 'LOGIN' }),
    });
    assert.strictEqual(admOtpReq.status, 200);
    const admOtp = capturedEmails.pop().otp;
    const admOtpVerify = await fetch(`${baseUrl}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.ADMIN_EMAIL, otp: admOtp, role: 'ADMIN' }),
    });
    assert.strictEqual(admOtpVerify.status, 200);

    // Valid Customer OTP login & booking creation
    await fetch(`${baseUrl}/auth/request-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'legit.cust@example.com', role: 'CUSTOMER' }),
    });
    const cOtp = capturedEmails.pop().otp;
    const cAuth = await (await fetch(`${baseUrl}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'legit.cust@example.com', otp: cOtp, role: 'CUSTOMER' }),
    })).json();
    assert.strictEqual(cAuth.user.role, 'CUSTOMER');

    const bkgRes = await (await fetch(`${baseUrl}/bookings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cAuth.accessToken}` },
      body: JSON.stringify({ serviceId: 'ac_install', latitude: 22.5726, longitude: 88.3639, price: 1299 }),
    })).json();
    assert.strictEqual(bkgRes.success, true);
    assert.strictEqual(bkgRes.offersDispatched, 3);

    // Login all 3 technicians & race POST /dispatch/offers/:offerId/accept simultaneously
    const techTokens = {};
    for (let i = 1; i <= 3; i++) {
      await fetch(`${baseUrl}/auth/request-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: `tech${i}@example.com`, role: 'TECHNICIAN' }),
      });
      const tOtp = capturedEmails.pop().otp;
      const tAuth = await (await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: `tech${i}@example.com`, otp: tOtp, role: 'TECHNICIAN' }),
      })).json();
      assert.strictEqual(tAuth.user.role, 'TECHNICIAN');
      techTokens[`uid_tech_win_${i}`] = tAuth.accessToken;
    }

    const raceResponses = await Promise.all(
      ['uid_tech_win_1', 'uid_tech_win_2', 'uid_tech_win_3'].map(async (uid) => {
        const res = await fetch(`${baseUrl}/dispatch/offers/offer_${bkgRes.bookingId}_${uid}/accept`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${techTokens[uid]}` },
        });
        return { uid, status: res.status, data: await res.json() };
      })
    );

    const winners = raceResponses.filter((r) => r.status === 200);
    const losers = raceResponses.filter((r) => r.status === 409 && r.data.code === 'ALREADY_ASSIGNED');
    assert.strictEqual(winners.length, 1, `Expected 1 concurrent winner, got ${JSON.stringify(raceResponses)}`);
    assert.strictEqual(losers.length, 2, `Expected 2 409 ALREADY_ASSIGNED losers, got ${JSON.stringify(raceResponses)}`);
  });

  server.close();
  console.log('\n================================================================');
  console.log(`P0 SECURITY SUITE SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error('Fatal P0 suite error:', err);
  process.exit(1);
});
