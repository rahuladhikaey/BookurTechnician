/**
 * BookurTechnician Trusted Firebase Backend Integration & Concurrency Test Suite
 * Runs against Firebase Local Emulators
 */

const assert = require('assert');

const BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:5001/bookmytechnician-53d94/asia-south1/api';

async function request(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (e) {
    data = null;
  }
  return { status: res.status, data };
}

async function runTests() {
  console.log('================================================================');
  console.log('🚀 RUNNING TRUSTED BACKEND INTEGRATION & CONCURRENCY TESTS');
  console.log(`Target URL: ${BASE_URL}`);
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  ✅ PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  ❌ FAIL: ${name}`);
      console.error(`     Error: ${err.message}`);
      if (err.actual !== undefined && err.expected !== undefined) {
        console.error(`     Actual: ${JSON.stringify(err.actual)}`);
        console.error(`     Expected: ${JSON.stringify(err.expected)}`);
      }
      failed++;
    }
  }

  // 1. Health Check
  await test('1. GET /health responds with 200 OK', async () => {
    const res = await request('/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.status, 'ok');
  });

  // 2. Presence Coordinates Bounds Validation
  await test('2. POST /updateTechnicianPresence rejects out-of-bounds coordinates (lat > 90)', async () => {
    const res = await request('/updateTechnicianPresence', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_test_01' },
      body: { latitude: 95.0, longitude: 88.0 },
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.data.code, 'INVALID_COORDINATES');
  });

  await test('3. POST /updateTechnicianPresence records valid GPS and presence heartbeat', async () => {
    const res = await request('/updateTechnicianPresence', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_test_01' },
      body: { latitude: 23.242, longitude: 88.553, heading: 45, speed: 12.5, isOnline: true },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.success, true);
    assert.strictEqual(res.data.data.isOnline, true);
  });

  // 3. Create Booking & OTP Separation
  let testBookingId = null;
  let testStartOtp = null;
  let testEndOtp = null;

  await test('4. POST /createBooking creates booking and isolates OTP secrets', async () => {
    const res = await request('/createBooking', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'customer_test_01' },
      body: {
        customerName: 'Rahul Customer',
        customerPhone: '+919876543210',
        serviceId: 'sk_ac_installation',
        serviceName: 'AC installation',
        price: 1039,
        address: { fullAddress: 'Birnagar, Ranaghat, West Bengal' },
      },
    });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.data.success, true);
    assert(res.data.bookingId, 'Should return bookingId');
    assert(res.data.startOtp, 'Should return customer startOtp');
    assert(res.data.endOtp, 'Should return customer endOtp');
    assert.strictEqual(res.data.booking.startOtp, undefined, 'Plaintext startOtp must NOT be on public booking doc');
    assert.strictEqual(res.data.booking.endOtp, undefined, 'Plaintext endOtp must NOT be on public booking doc');

    testBookingId = res.data.bookingId;
    testStartOtp = res.data.startOtp;
    testEndOtp = res.data.endOtp;
  });

  // Setup technician profiles and offers in Firestore for dispatch testing
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'bookmytechnician-53d94' });
  }
  const db = admin.firestore();

  // Tech A: Has ONLY Electrical skills (No AC skill)
  await db.collection('technician_profiles').doc('tech_electrician_only').set({
    id: 'tech_electrician_only',
    name: 'Kakali Goswami',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    kycStatus: 'VERIFIED',
    walletBalance: 0,
    skills: [
      { skillId: 'sk_light_repair', canonicalServiceId: 'light_rep', name: 'Light Repair', verificationStatus: 'VERIFIED', enabled: true },
      { skillId: 'sk_ceiling_fan_installation', canonicalServiceId: 'fan_ceiling_install', name: 'Ceiling Fan Installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // Tech B: Has VERIFIED AC Installation skill
  await db.collection('technician_profiles').doc('tech_ac_specialist').set({
    id: 'tech_ac_specialist',
    name: 'Subhashish AC Pro',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    kycStatus: 'VERIFIED',
    walletBalance: 0,
    skills: [
      { skillId: 'sk_ac_installation', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // Tech C: Has AC skill but DISABLED (toggle off)
  await db.collection('technician_profiles').doc('tech_ac_disabled').set({
    id: 'tech_ac_disabled',
    name: 'Sunil Disabled AC',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    kycStatus: 'VERIFIED',
    walletBalance: 0,
    skills: [
      { skillId: 'sk_ac_installation', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: false },
    ],
  });

  // Tech D: Second eligible AC technician for concurrency test
  await db.collection('technician_profiles').doc('tech_ac_competitor').set({
    id: 'tech_ac_competitor',
    name: 'Ramesh Competitor',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    kycStatus: 'VERIFIED',
    walletBalance: 0,
    skills: [
      { skillId: 'sk_ac_installation', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // 4. Dispatch Offers Setup
  const now = Date.now();
  const futureExp = new Date(now + 120000).toISOString();
  const pastExp = new Date(now - 10000).toISOString();

  // Offer 1: Dispatched to Tech A (Electrician only)
  await db.collection('dispatch_offers').doc('offer_tech_electrician').set({
    id: 'offer_tech_electrician',
    bookingId: testBookingId,
    technicianId: 'tech_electrician_only',
    serviceId: 'sk_ac_installation',
    serviceName: 'AC installation',
    status: 'SENT',
    expiresAt: futureExp,
  });

  // Offer 2: Dispatched to Tech B (AC specialist)
  await db.collection('dispatch_offers').doc('offer_tech_ac').set({
    id: 'offer_tech_ac',
    bookingId: testBookingId,
    technicianId: 'tech_ac_specialist',
    serviceId: 'sk_ac_installation',
    serviceName: 'AC installation',
    status: 'SENT',
    expiresAt: futureExp,
  });

  // Offer 3: Dispatched to Tech C (Disabled AC)
  await db.collection('dispatch_offers').doc('offer_tech_disabled').set({
    id: 'offer_tech_disabled',
    bookingId: testBookingId,
    technicianId: 'tech_ac_disabled',
    serviceId: 'sk_ac_installation',
    serviceName: 'AC installation',
    status: 'SENT',
    expiresAt: futureExp,
  });

  // Offer 4: Expired Offer for Tech B
  await db.collection('dispatch_offers').doc('offer_tech_expired').set({
    id: 'offer_tech_expired',
    bookingId: testBookingId,
    technicianId: 'tech_ac_specialist',
    serviceId: 'sk_ac_installation',
    serviceName: 'AC installation',
    status: 'SENT',
    expiresAt: pastExp,
  });

  // Offer 5: Dispatched to Tech D (Competitor)
  await db.collection('dispatch_offers').doc('offer_tech_competitor').set({
    id: 'offer_tech_competitor',
    bookingId: testBookingId,
    technicianId: 'tech_ac_competitor',
    serviceId: 'sk_ac_installation',
    serviceName: 'AC installation',
    status: 'SENT',
    expiresAt: futureExp,
  });

  // 5. Test Offer Ownership Unauthorized
  await test('5. POST /acceptBookingOffer denies acceptance when technician does not own the offer (403)', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { offerId: 'offer_tech_electrician' }, // Owned by tech_electrician_only
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.data.code, 'OFFER_UNAUTHORIZED');
  });

  // 6. Test Expired Offer
  await test('6. POST /acceptBookingOffer rejects expired offer with 410 OFFER_EXPIRED', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { offerId: 'offer_tech_expired' },
    });
    assert.strictEqual(res.status, 410);
    assert.strictEqual(res.data.code, 'OFFER_EXPIRED');
  });

  // 7. Test Skill Eligibility Guard (Electrician trying to accept AC installation)
  await test('7. POST /acceptBookingOffer strictly blocks technician lacking verified AC skill (403 SKILL_NOT_AUTHORIZED)', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_electrician_only' },
      body: { offerId: 'offer_tech_electrician' },
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.data.code, 'SKILL_NOT_AUTHORIZED');
  });

  // 8. Test Disabled Skill Guard
  await test('8. POST /acceptBookingOffer blocks technician whose required skill is toggled off (403)', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_disabled' },
      body: { offerId: 'offer_tech_disabled' },
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.data.code, 'SKILL_NOT_AUTHORIZED');
  });

  // 9. Atomic Acceptance Success
  await test('9. POST /acceptBookingOffer successfully claims booking for eligible technician Tech B', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { offerId: 'offer_tech_ac', technicianName: 'Subhashish AC Pro' },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.success, true);
    assert.strictEqual(res.data.assignment.status, 'ASSIGNED');
    assert.strictEqual(res.data.assignment.technicianId, 'tech_ac_specialist');
    assert.strictEqual(res.data.booking.startOtp, undefined, 'Plaintext startOtp must not be leaked to technician');
  });

  // 10. Concurrency & Single-Winner Protection
  await test('10. POST /acceptBookingOffer rejects competing Tech D with 409 ALREADY_ASSIGNED', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_competitor' },
      body: { offerId: 'offer_tech_competitor' },
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.data.code, 'ALREADY_ASSIGNED');

    // Verify competitor offer is cancelled
    const compOfferSnap = await db.collection('dispatch_offers').doc('offer_tech_competitor').get();
    assert.strictEqual(compOfferSnap.data().status, 'CANCELLED_CLAIMED_BY_ANOTHER');
  });

  // 11. Idempotency Check
  await test('11. POST /acceptBookingOffer handles duplicate call idempotently with 200 OK', async () => {
    const res = await request('/acceptBookingOffer', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { offerId: 'offer_tech_ac' },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.success, true);
    assert.strictEqual(res.data.booking.technicianId, 'tech_ac_specialist');
  });

  // 12. Verify Start OTP by Unauthorized Technician
  await test('12. POST /verifyStartOtp blocks unassigned technician (403)', async () => {
    const res = await request(`/api/bookings/${testBookingId}/verify-start-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_competitor' },
      body: { startOtp: testStartOtp },
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.data.code, 'TECHNICIAN_NOT_ASSIGNED');
  });

  // 13. Verify Start OTP with Invalid Code & Decrement Attempts
  await test('13. POST /verifyStartOtp decrements remaining attempts on wrong OTP (400)', async () => {
    const res = await request(`/api/bookings/${testBookingId}/verify-start-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { startOtp: '0000' }, // Incorrect OTP
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.data.code, 'INVALID_OTP');
    assert.strictEqual(res.data.remainingAttempts, 2);
  });

  // 14. Verify Start OTP Success with Valid Code
  await test('14. POST /verifyStartOtp advances job to IN_PROGRESS on valid code', async () => {
    const res = await request(`/api/bookings/${testBookingId}/verify-start-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { startOtp: testStartOtp },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.status, 'IN_PROGRESS');

    const bkgSnap = await db.collection('bookings').doc(testBookingId).get();
    assert.strictEqual(bkgSnap.data().status, 'IN_PROGRESS');
  });

  // 15. Verify End OTP Lockout Test (Simulate 3 Failed Attempts on a new test booking)
  await test('15. POST /verifyEndOtp enforces 3-attempt lockout (403 OTP_LOCKED_OUT)', async () => {
    // Create quick secondary booking for lockout test
    const bkgRes = await request('/createBooking', {
      method: 'POST',
      headers: { 'x-mock-user-id': 'customer_test_01' },
      body: {
        serviceId: 'sk_ac_installation',
        serviceName: 'AC installation',
        price: 1039,
      },
    });
    const lId = bkgRes.data.bookingId;
    const lStart = bkgRes.data.startOtp;

    // Direct assign for test
    await db.collection('bookings').doc(lId).update({
      status: 'ASSIGNED',
      technicianId: 'tech_ac_specialist',
    });

    // Start work
    await request(`/api/bookings/${lId}/verify-start-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { startOtp: lStart },
    });

    // Fail 1
    const r1 = await request(`/api/bookings/${lId}/verify-end-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { endOtp: '1111' },
    });
    assert.strictEqual(r1.status, 400);
    assert.strictEqual(r1.data.remainingAttempts, 2);

    // Fail 2
    const r2 = await request(`/api/bookings/${lId}/verify-end-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { endOtp: '2222' },
    });
    assert.strictEqual(r2.status, 400);
    assert.strictEqual(r2.data.remainingAttempts, 1);

    // Fail 3 -> Lockout
    const r3 = await request(`/api/bookings/${lId}/verify-end-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { endOtp: '3333' },
    });
    assert.strictEqual(r3.status, 403);
    assert.strictEqual(r3.data.code, 'OTP_LOCKED_OUT');

    // Attempt 4 -> Still Locked Out
    const r4 = await request(`/api/bookings/${lId}/verify-end-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { endOtp: '4444' },
    });
    assert.strictEqual(r4.status, 403);
    assert.strictEqual(r4.data.code, 'OTP_LOCKED_OUT');
  });

  // 16. Verify End OTP Success on Primary Booking
  await test('16. POST /verifyEndOtp completes service, credits wallet, and sets technician AVAILABLE', async () => {
    const res = await request(`/api/bookings/${testBookingId}/verify-end-otp`, {
      method: 'POST',
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
      body: { endOtp: testEndOtp },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.data.status, 'COMPLETED');
    assert(res.data.payoutAmount > 0, 'Should credit technician payout');

    const bkgSnap = await db.collection('bookings').doc(testBookingId).get();
    assert.strictEqual(bkgSnap.data().status, 'COMPLETED');

    const techSnap = await db.collection('technician_profiles').doc('tech_ac_specialist').get();
    assert.strictEqual(techSnap.data().availabilityStatus, 'AVAILABLE');
    assert.strictEqual(techSnap.data().activeBookingId, null);
    assert(techSnap.data().walletBalance > 0, 'Wallet balance should increase');
  });

  // 17. Customer-Only OTP Access Guard
  await test('17. Customer OTP retrieval allows customer but blocks technician', async () => {
    // Customer retrieval
    const cRes = await request(`/bookings/${testBookingId}/customer-otps`, {
      headers: { 'x-mock-user-id': 'customer_test_01' },
    });
    assert.strictEqual(cRes.status, 200);
    assert.strictEqual(cRes.data.startOtp, testStartOtp);
    assert.strictEqual(cRes.data.endOtp, testEndOtp);

    // Technician retrieval forbidden
    const tRes = await request(`/bookings/${testBookingId}/customer-otps`, {
      headers: { 'x-mock-user-id': 'tech_ac_specialist' },
    });
    assert.strictEqual(tRes.status, 403);
    assert.strictEqual(tRes.data.code, 'FORBIDDEN');
  });

  console.log('\n================================================================');
  console.log(`📊 TEST SUITE SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});

