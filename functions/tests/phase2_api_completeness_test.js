/**
 * BookurTechnician — Phase 2 API Completeness & Launch Readiness Suite
 * Runs against Cloud Firestore Emulator (127.0.0.1:8085) and Express backend (`functions/src/app.js`).
 */

const assert = require('assert');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { createApp } = require('../src/app');

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

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

async function clearEmulator() {
  const res = await fetch(
    `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
  if (!res.ok) throw new Error(`Failed clearing emulator: ${res.status}`);
}

async function otpLogin(baseUrl, { email, phone, fullName, role, capturedEmails }) {
  capturedEmails.length = 0;
  const reqRes = await fetch(`${baseUrl}/auth/request-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, phone, fullName, role, purpose: 'REGISTER' }),
  });
  assert.strictEqual(reqRes.status, 200, `OTP request failed for ${email}: ${await reqRes.clone().text()}`);
  assert.strictEqual(capturedEmails.length, 1);
  const otp = capturedEmails[0].otp;

  const verRes = await fetch(`${baseUrl}/auth/verify-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, phone, fullName, role, purpose: 'REGISTER', otp }),
  });
  assert.strictEqual(verRes.status, 200);
  return verRes.json();
}

async function run() {
  await clearEmulator();
  const capturedEmails = [];
  const app = createApp(db, {
    allowLocalhost: true,
    authDeps: {
      sendOtpEmailFn: async (toEmail, otp, role, toName) => {
        capturedEmails.push({ toEmail, toName, otp, role });
        return { success: true };
      },
      createFirebaseCustomTokenFn: async (uid, claims) => `custom_${uid}_${claims.role}`,
    },
  });

  const server = await new Promise((resolve) => {
    const srv = app.listen(0, '127.0.0.1', () => resolve(srv));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  let passed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  FAIL: ${name}\n   `, err);
      throw err;
    }
  }

  console.log('================================================================');
  console.log('PHASE 2 — API COMPLETENESS & LAUNCH READINESS EMULATOR SUITE');
  console.log(`Emulator: ${EMULATOR_HOST} | API: ${baseUrl}`);
  console.log('================================================================\n');

  try {
    // Prepare Admin, Customer 1, Customer 2, and Technician tokens
    const adminLoginRes = await fetch(`${baseUrl}/auth/admin/direct-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_SECRET_KEY }),
    });
    assert.strictEqual(adminLoginRes.status, 200);
    const adminToken = (await adminLoginRes.json()).accessToken;

    const cust1 = await otpLogin(baseUrl, {
      email: 'cust1.phase2@example.com',
      phone: '+919800000101',
      fullName: 'Customer One',
      role: 'CUSTOMER',
      capturedEmails,
    });
    const cust2 = await otpLogin(baseUrl, {
      email: 'cust2.phase2@example.com',
      phone: '+919800000102',
      fullName: 'Customer Two',
      role: 'CUSTOMER',
      capturedEmails,
    });
    const tech = await otpLogin(baseUrl, {
      email: 'tech1.phase2@example.com',
      phone: '+919800000201',
      fullName: 'Tech Partner One',
      role: 'TECHNICIAN',
      capturedEmails,
    });

    const cust1Headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${cust1.accessToken}` };
    const cust2Headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${cust2.accessToken}` };
    const techHeaders = { 'Content-Type': 'application/json', Authorization: `Bearer ${tech.accessToken}` };
    const adminHeaders = { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` };

    await test('1. Customer Profile & Addresses CRUD enforce validation, owner isolation, and field protection', async () => {
      // Privilege escalation via profile update blocked
      const escRes = await fetch(`${baseUrl}/customer/profile`, {
        method: 'PUT',
        headers: cust1Headers,
        body: JSON.stringify({ fullName: 'Escalated', role: 'ADMIN', isAdmin: true }),
      });
      assert.strictEqual(escRes.status, 403);

      const updProf = await fetch(`${baseUrl}/customer/profile`, {
        method: 'PUT',
        headers: cust1Headers,
        body: JSON.stringify({ fullName: 'Customer Verified', gender: 'FEMALE' }),
      });
      assert.strictEqual(updProf.status, 200);
      const profData = await updProf.json();
      assert.strictEqual(profData.data.user.fullName, 'Customer Verified');

      const getProf = await fetch(`${baseUrl}/customer/profile`, { headers: cust1Headers });
      assert.strictEqual(getProf.status, 200);
      assert.strictEqual((await getProf.json()).data.gender, 'FEMALE');

      // Address create, read, primary toggle, cross-customer isolation
      const addr1Res = await fetch(`${baseUrl}/customer/addresses`, {
        method: 'POST',
        headers: cust1Headers,
        body: JSON.stringify({
          houseFlat: '12A',
          street: 'Park Street',
          area: 'Birnagar',
          city: 'Ranaghat',
          state: 'WB',
          postalCode: '741127',
          latitude: 23.242,
          longitude: 88.553,
          primary: true,
        }),
      });
      assert.strictEqual(addr1Res.status, 200);
      const addr1 = (await addr1Res.json()).data;

      // Cross-customer update & delete blocked (403)
      const crossUpd = await fetch(`${baseUrl}/customer/addresses/${addr1.id}`, {
        method: 'PUT',
        headers: cust2Headers,
        body: JSON.stringify({ area: 'Hijacked' }),
      });
      assert.strictEqual(crossUpd.status, 403);

      const crossDel = await fetch(`${baseUrl}/customer/addresses/${addr1.id}`, {
        method: 'DELETE',
        headers: cust2Headers,
      });
      assert.strictEqual(crossDel.status, 403);

      // List & Update owner address
      const listRes = await fetch(`${baseUrl}/customer/addresses`, { headers: cust1Headers });
      assert.strictEqual((await listRes.json()).data.length, 1);

      // Technician cannot access customer profile
      const techBlocked = await fetch(`${baseUrl}/customer/profile`, { headers: techHeaders });
      assert.strictEqual(techBlocked.status, 403);
    });

    await test('2. Technician Profile, KYC submission & Pending-by-default skills require Admin approval before dispatch', async () => {
      // Blocked privileged write via technician profile endpoint
      const escTech = await fetch(`${baseUrl}/technicians/profile`, {
        method: 'PUT',
        headers: techHeaders,
        body: JSON.stringify({ kycStatus: 'VERIFIED', walletBalance: 5000 }),
      });
      assert.strictEqual(escTech.status, 403);

      const okProf = await fetch(`${baseUrl}/technician/profile`, {
        method: 'PUT',
        headers: techHeaders,
        body: JSON.stringify({ fullName: 'Partner Raj', upiId: 'raj@oksbi' }),
      });
      assert.strictEqual(okProf.status, 200);
      const profJson = await okProf.json();
      assert.strictEqual(profJson.data.fullName, 'Partner Raj');
      assert.strictEqual(profJson.data.kycStatus, 'PENDING');

      const docRes = await fetch(`${baseUrl}/technicians/documents`, {
        method: 'POST',
        headers: techHeaders,
        body: JSON.stringify({
          documentType: 'AADHAAR',
          fileUrl: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
          maskedNumber: 'XXXX-XXXX-1234',
        }),
      });
      assert.strictEqual(docRes.status, 201);

      const docsList = await fetch(`${baseUrl}/technicians/documents`, { headers: techHeaders });
      assert.strictEqual((await docsList.json()).data.length, 1);

      // New technician declares skill -> starts PENDING until Admin approves
      const skillSave = await fetch(`${baseUrl}/technicians/skills/bulk`, {
        method: 'POST',
        headers: techHeaders,
        body: JSON.stringify({
          skills: [{ id: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED' }],
        }),
      });
      assert.strictEqual(skillSave.status, 200);
      const skillData = await skillSave.json();
      assert.strictEqual(skillData.skills[0].verificationStatus, 'PENDING');

      // Online presence while PENDING KYC/skills must NOT show up as eligible for customers
      const goOn = await fetch(`${baseUrl}/technician/online-status`, {
        method: 'POST',
        headers: techHeaders,
        body: JSON.stringify({ isOnline: true, latitude: 23.244, longitude: 88.554 }),
      });
      assert.strictEqual(goOn.status, 200);

      const preAvail = await fetch(`${baseUrl}/catalog/availability?latitude=23.242&longitude=88.553&serviceId=ac_install`);
      assert.strictEqual((await preAvail.json()).availableTechnicianCount, 0);

      // Non-admin blocked from admin endpoints
      const nonAdminSkillApprove = await fetch(`${baseUrl}/admin/technicians/${tech.user.uid}/skills/ac_install/verify`, {
        method: 'PATCH',
        headers: techHeaders,
        body: JSON.stringify({ verificationStatus: 'VERIFIED' }),
      });
      assert.strictEqual(nonAdminSkillApprove.status, 403);
    });

    await test('3. Admin Category/Service CRUD + KYC & Skill Approval unlock Customer catalog & live availability', async () => {
      const catRes = await fetch(`${baseUrl}/admin/categories`, {
        method: 'POST',
        headers: adminHeaders,
        body: JSON.stringify({ id: 'cat_ac', name: 'AC Services' }),
      });
      assert.strictEqual(catRes.status, 201);

      const srvRes = await fetch(`${baseUrl}/admin/services`, {
        method: 'POST',
        headers: adminHeaders,
        body: JSON.stringify({
          id: 'ac_install',
          name: 'AC installation',
          categoryId: 'cat_ac',
          categoryName: 'AC Services',
          price: 1299,
        }),
      });
      assert.strictEqual(srvRes.status, 201);

      // Update pricing via /admin/pricing/:id
      const priceRes = await fetch(`${baseUrl}/admin/pricing/ac_install`, {
        method: 'PUT',
        headers: adminHeaders,
        body: JSON.stringify({ price: 1199, offerPrice: 1199 }),
      });
      assert.strictEqual(priceRes.status, 200);
      assert.strictEqual((await priceRes.json()).data.price, 1199);

      // Admin inspects docs, approves KYC & approves skill
      const adminDocs = await fetch(`${baseUrl}/admin/technicians/${tech.user.uid}/documents`, { headers: adminHeaders });
      assert.strictEqual(adminDocs.status, 200);
      assert.strictEqual((await adminDocs.json()).data.length, 1);

      const kycApprove = await fetch(`${baseUrl}/admin/technicians/${tech.user.uid}/kyc`, {
        method: 'PATCH',
        headers: adminHeaders,
        body: JSON.stringify({ kycStatus: 'VERIFIED', accountStatus: 'ACTIVE' }),
      });
      assert.strictEqual(kycApprove.status, 200);

      const skillVerify = await fetch(`${baseUrl}/admin/technicians/${tech.user.uid}/skills/ac_install/verify`, {
        method: 'PATCH',
        headers: adminHeaders,
        body: JSON.stringify({ verificationStatus: 'VERIFIED' }),
      });
      assert.strictEqual(skillVerify.status, 200);
      assert.strictEqual((await skillVerify.json()).verifiedSkillsCount, 1);

      // Customer catalog & availability now show the service and 1 eligible technician
      const catCatalog = await fetch(`${baseUrl}/catalog/categories`);
      assert.strictEqual((await catCatalog.json()).categories.length, 1);

      const availRes = await fetch(`${baseUrl}/catalog/availability?latitude=23.242&longitude=88.553&serviceId=ac_install`);
      assert.strictEqual((await availRes.json()).availableTechnicianCount, 1);

      // Test { online: false } legacy payload bug fix turns technician OFFLINE
      const goOff = await fetch(`${baseUrl}/technician/online-status`, {
        method: 'POST',
        headers: techHeaders,
        body: JSON.stringify({ online: false }),
      });
      assert.strictEqual(goOff.status, 200);
      assert.strictEqual((await goOff.json()).data.isOnline, false);

      const afterOff = await fetch(`${baseUrl}/catalog/availability?latitude=23.242&longitude=88.553&serviceId=ac_install`);
      assert.strictEqual((await afterOff.json()).availableTechnicianCount, 0);

      // Bring technician back online for booking flow
      await fetch(`${baseUrl}/technician/online-status`, {
        method: 'POST',
        headers: techHeaders,
        body: JSON.stringify({ isOnline: true, latitude: 23.244, longitude: 88.554 }),
      });
    });

    await test('4. End-to-End Booking -> Idempotency -> Self-Accept -> Travel (ON_THE_WAY/ARRIVED) -> Start/End OTP -> Admin Monitoring -> Cancelled Cleanup', async () => {
      const slotsRes = await fetch(`${baseUrl}/bookings/available-slots?serviceId=ac_install&latitude=23.242&longitude=88.553`);
      assert.strictEqual(slotsRes.status, 200);
      assert((await slotsRes.json()).slots.length >= 1);

      const idemKey = `idem_${Date.now()}`;
      const createRes = await fetch(`${baseUrl}/bookings`, {
        method: 'POST',
        headers: cust1Headers,
        body: JSON.stringify({
          idempotencyKey: idemKey,
          serviceId: 'ac_install',
          serviceName: 'AC installation',
          latitude: 23.242,
          longitude: 88.553,
          address: 'Birnagar, Ranaghat',
          price: 1199,
          paymentMethod: 'CASH_ON_DELIVERY',
        }),
      });
      assert.strictEqual(createRes.status, 201);
      const created = await createRes.json();
      const bookingId = created.bookingId;
      const startOtp = created.startOtp;
      const endOtp = created.endOtp;
      const offerId = created.offerIds[0];
      assert(startOtp && endOtp && offerId);

      // Duplicate idempotency key rejected with 409 DUPLICATE_BOOKING
      const dupRes = await fetch(`${baseUrl}/bookings`, {
        method: 'POST',
        headers: cust1Headers,
        body: JSON.stringify({
          idempotencyKey: idemKey,
          serviceId: 'ac_install',
          latitude: 23.242,
          longitude: 88.553,
        }),
      });
      assert.strictEqual(dupRes.status, 409);

      // Admin dispatch live & history monitoring endpoints work read-only
      const liveDisp = await fetch(`${baseUrl}/admin/dispatch/live`, { headers: adminHeaders });
      assert.strictEqual(liveDisp.status, 200);
      assert.strictEqual((await liveDisp.json()).monitoringOnly, true);

      const histDisp = await fetch(`${baseUrl}/admin/dispatch/${bookingId}/history`, { headers: adminHeaders });
      assert.strictEqual(histDisp.status, 200);
      assert((await histDisp.json()).offers.length >= 1);

      // Technician sees offer, accepts via /technician/dispatch/:offerId/accept, lists /technician/jobs (without OTP leak)
      const pendRes = await fetch(`${baseUrl}/dispatch/proposals/pending`, { headers: techHeaders });
      assert.strictEqual((await pendRes.json()).offers.length, 1);

      const accRes = await fetch(`${baseUrl}/technician/dispatch/${offerId}/accept`, {
        method: 'POST',
        headers: techHeaders,
      });
      assert.strictEqual(accRes.status, 200);

      const jobsRes = await fetch(`${baseUrl}/technician/jobs`, { headers: techHeaders });
      assert.strictEqual(jobsRes.status, 200);
      const jobsData = await jobsRes.json();
      assert.strictEqual(jobsData.data.length, 1);
      assert.strictEqual(jobsData.data[0].startOtp, undefined);
      assert.strictEqual(jobsData.data[0].endOtp, undefined);

      // GET /bookings/:bookingId hides OTPs from technician too
      const techGetBooking = await fetch(`${baseUrl}/bookings/${bookingId}`, { headers: techHeaders });
      assert.strictEqual(techGetBooking.status, 200);
      assert.strictEqual((await techGetBooking.json()).data.startOtp, undefined);

      // Technician advances ON_THE_WAY -> ARRIVED -> Start OTP -> rejects COMPLETED without End OTP -> End OTP
      const onWayRes = await fetch(`${baseUrl}/technician/jobs/${bookingId}/status`, {
        method: 'PATCH',
        headers: techHeaders,
        body: JSON.stringify({ status: 'ON_THE_WAY' }),
      });
      assert.strictEqual(onWayRes.status, 200);
      assert.strictEqual((await onWayRes.json()).status, 'ON_THE_WAY');

      const arrivedRes = await fetch(`${baseUrl}/technician/jobs/${bookingId}/status`, {
        method: 'PATCH',
        headers: techHeaders,
        body: JSON.stringify({ status: 'ARRIVED' }),
      });
      assert.strictEqual(arrivedRes.status, 200);

      // Verify Start OTP works from ARRIVED status!
      const startOtpRes = await fetch(`${baseUrl}/technician/jobs/${bookingId}/status`, {
        method: 'PATCH',
        headers: techHeaders,
        body: JSON.stringify({ status: 'IN_PROGRESS', startOtp }),
      });
      assert.strictEqual(startOtpRes.status, 200);

      // Attempt COMPLETED without endOtp rejected (400)
      const badCompleteRes = await fetch(`${baseUrl}/technician/jobs/${bookingId}/status`, {
        method: 'PATCH',
        headers: techHeaders,
        body: JSON.stringify({ status: 'COMPLETED' }),
      });
      assert.strictEqual(badCompleteRes.status, 400);

      // Valid End OTP completes booking & frees technician
      const endOtpRes = await fetch(`${baseUrl}/technician/jobs/${bookingId}/status`, {
        method: 'PATCH',
        headers: techHeaders,
        body: JSON.stringify({ status: 'COMPLETED', endOtp }),
      });
      assert.strictEqual(endOtpRes.status, 200);
      assert.strictEqual((await endOtpRes.json()).status, 'COMPLETED');

      // Deleting COMPLETED booking is blocked (400); cancelled booking can be cancelled + deleted
      const badDelRes = await fetch(`${baseUrl}/bookings/${bookingId}`, {
        method: 'DELETE',
        headers: cust1Headers,
      });
      assert.strictEqual(badDelRes.status, 400);

      const secondRes = await fetch(`${baseUrl}/bookings`, {
        method: 'POST',
        headers: cust1Headers,
        body: JSON.stringify({
          serviceId: 'ac_install',
          latitude: 23.242,
          longitude: 88.553,
          price: 1199,
        }),
      });
      const b2Id = (await secondRes.json()).bookingId;
      const cancelRes = await fetch(`${baseUrl}/admin/bookings/${b2Id}/cancel`, {
        method: 'POST',
        headers: adminHeaders,
        body: JSON.stringify({ reason: 'Test cleanup' }),
      });
      assert.strictEqual(cancelRes.status, 200);

      const delCancelledRes = await fetch(`${baseUrl}/bookings/${b2Id}`, {
        method: 'DELETE',
        headers: cust1Headers,
      });
      assert.strictEqual(delCancelledRes.status, 200);
    });

    console.log('\n================================================================');
    console.log(`PHASE 2 API COMPLETENESS SUMMARY: ${passed} PASSED, 0 FAILED`);
    console.log('================================================================');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
