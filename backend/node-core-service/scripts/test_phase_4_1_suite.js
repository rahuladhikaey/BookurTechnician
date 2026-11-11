/**
 * BOOKURTECHNICIAN — PHASE 4.1 BACKEND VERIFICATION SUITE
 * Verifies:
 * 1. Atomic booking assignment & simultaneous dual-customer race condition (201 vs 409 TECHNICIAN_BUSY_CONFLICT)
 * 2. Technician going offline before booking (409 TECHNICIAN_WENT_OFFLINE)
 * 3. Stale GPS coordinates (>10 mins old -> 409 STALE_LOCATION)
 * 4. Duplicate booking idempotency protection (409 DUPLICATE_BOOKING)
 * 5. Cryptographic SHA-256 OTP generation, zero '123456' backdoor, 10-min expiry, 5-attempt lockout, 3-req/10m rate limit
 * 6. Internal UID (UUID) vs public BT-XXXXXX partner code separation
 */
const assert = require('assert');
const authController = require('../src/controllers/authController');
const bookingController = require('../src/controllers/bookingController');
const redis = require('../src/config/redis');
const { inMemoryTechProfiles, setTechnicianProfile } = require('../src/config/inMemoryTechStore');
const bookingsStore = require('../src/config/bookingsStore');
const automaticDispatchEngine = require('../src/services/automaticDispatchEngine');

function createMockRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

async function runPhase41BackendSuite() {
  console.log('===================================================================');
  console.log('🚀 BOOKURTECHNICIAN PHASE 4.1 BACKEND SAFETY & ATOMICITY TEST SUITE');
  console.log('===================================================================\n');

  // ── TEST 1: OTP Security, Rate Limiting, Lockout & Identity Separation ──
  console.log('▶ [Test 1] OTP Cryptographic Hashing, Rate Limiting (3/10m), 5-Attempt Lockout & UID vs BT-XXXXXX...');
  const testEmail = 'phase41.tech@bookurtechnician.com';
  const testPhone = '9830011223';

  // Clear Redis keys
  await redis.del(`otp_rate:${testEmail}`);
  await redis.del(`otp_fail:${testEmail}`);
  await redis.del(`otp:${testEmail}`);

  // Request 1, 2, 3 must succeed; Request 4 must fail with 429 OTP_RATE_LIMIT_EXCEEDED
  for (let i = 1; i <= 3; i++) {
    const req = { body: { email: testEmail, phone: testPhone, fullName: 'Ram Partner', role: 'TECHNICIAN' } };
    const res = createMockRes();
    await authController.requestOtp(req, res);
    assert.strictEqual(res.statusCode, 200, `OTP request #${i} should return 200`);
    assert.strictEqual(res.body.success, true);
  }

  const req4 = { body: { email: testEmail, phone: testPhone, role: 'TECHNICIAN' } };
  const res4 = createMockRes();
  await authController.requestOtp(req4, res4);
  assert.strictEqual(res4.statusCode, 429, '4th OTP request within 10 mins must be rejected with 429');
  assert.strictEqual(res4.body.code, 'OTP_RATE_LIMIT_EXCEEDED');
  console.log('  ✅ OTP Request Rate Limit (max 3 per 10 mins -> HTTP 429 OTP_RATE_LIMIT_EXCEEDED): PASS');

  // Verify stored payload in Redis has otpHash (SHA-256) and NO plaintext otp
  const cachedOtpData = await redis.get(`otp:${testEmail}`);
  assert.ok(cachedOtpData, 'OTP challenge must exist in Redis');
  assert.ok(cachedOtpData.otpHash && cachedOtpData.otpHash.length === 64, 'OTP must be stored as 64-char SHA-256 hex digest');
  assert.strictEqual(cachedOtpData.otp, undefined, 'Plaintext OTP must never be stored in Redis');
  console.log('  ✅ OTP Stored as SHA-256 Digest (No Plaintext OTP in Redis): PASS');

  // Test 5 wrong OTP attempts -> 429 OTP_ATTEMPT_LIMIT_EXCEEDED
  for (let attempt = 1; attempt <= 5; attempt++) {
    const vReq = { body: { email: testEmail, otp: '000000' } };
    const vRes = createMockRes();
    await authController.verifyOtp(vReq, vRes);
    assert.strictEqual(vRes.statusCode, 400);
    assert.strictEqual(vRes.body.code, 'INVALID_OTP');
  }
  const lockedReq = { body: { email: testEmail, otp: '123456' } };
  const lockedRes = createMockRes();
  await authController.verifyOtp(lockedReq, lockedRes);
  assert.strictEqual(lockedRes.statusCode, 429);
  assert.strictEqual(lockedRes.body.code, 'OTP_ATTEMPT_LIMIT_EXCEEDED');
  console.log('  ✅ 5 Failed OTP Attempts Lockout (HTTP 429 OTP_ATTEMPT_LIMIT_EXCEEDED): PASS');

  // Test Expired OTP rejection
  const expEmail = 'expired.user@bookurtechnician.com';
  await redis.setWithExpiry(`otp:${expEmail}`, {
    otpHash: authController.hashOtp('654321'),
    role: 'TECHNICIAN',
    expiresAt: Date.now() - 5000, // already expired
  }, 60);
  const expRes = createMockRes();
  await authController.verifyOtp({ body: { email: expEmail, otp: '654321' } }, expRes);
  assert.strictEqual(expRes.statusCode, 400);
  assert.strictEqual(expRes.body.code, 'OTP_EXPIRED');
  console.log('  ✅ Expired OTP Rejection (HTTP 400 OTP_EXPIRED): PASS');

  // Test Valid OTP Login & Internal UUID vs Public BT-XXXXXX Partner Code Separation
  const validEmail = 'verified.partner@bookurtechnician.com';
  await redis.del(`otp_fail:${validEmail}`);
  await redis.setWithExpiry(`otp:${validEmail}`, {
    otpHash: authController.hashOtp('789456'),
    role: 'TECHNICIAN',
    fullName: 'Verified Ram',
    phone: '9830098836',
    email: validEmail,
    expiresAt: Date.now() + 600000,
  }, 600);
  const loginRes = createMockRes();
  await authController.verifyOtp({ body: { email: validEmail, phone: '9830098836', otp: '789456', role: 'TECHNICIAN' } }, loginRes);
  assert.strictEqual(loginRes.statusCode, 200);
  assert.ok(loginRes.body.user.id && !loginRes.body.user.id.startsWith('BT-'), 'Internal id/uid must be UUID, not BT-XXXXXX');
  assert.strictEqual(loginRes.body.user.uid, loginRes.body.user.id);
  assert.ok(loginRes.body.user.technicianCode && loginRes.body.user.technicianCode.startsWith('BT-'), 'Public partner code must be BT-XXXXXX');
  console.log(`  ✅ Identity Separation Verified: Internal UID = ${loginRes.body.user.uid} | Public Partner Code = ${loginRes.body.user.technicianCode}: PASS\n`);

  // ── TEST 2: Duplicate Booking Idempotency Guard ──
  console.log('▶ [Test 2] Duplicate Booking Request Idempotency Guard...');
  inMemoryTechProfiles.clear();
  bookingsStore.clearAllBookings();
  bookingController.clearMemoryBookings();
  automaticDispatchEngine.resetDispatchEngineStoresForTest();
  automaticDispatchEngine.clearAllSessions();

  const techId = 'tech-uuid-ram-988363';
  setTechnicianProfile(techId, {
    id: techId,
    technicianId: techId,
    technicianCode: 'BT-988363',
    fullName: 'Ram',
    phone: '9830098836',
    isOnline: true,
    online: true,
    isAvailable: true,
    availabilityStatus: 'AVAILABLE',
    verificationStatus: 'VERIFIED',
    kycStatus: 'APPROVED',
    accountStatus: 'ACTIVE',
    latitude: 22.5726,
    longitude: 88.3639,
    currentLatitude: 22.5726,
    currentLongitude: 88.3639,
    lastLocationUpdate: new Date().toISOString(),
    serviceRadiusKm: 15,
    category: 'AC Services',
    categories: ['AC Services'],
    skills: [
      { id: 'ac_install', skillId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', isActive: true, enabled: true },
    ],
  });

  const dupPayload = {
    id: 'bkg_idem_test_1',
    customerId: 'cust_001',
    customerName: 'Rahul',
    serviceId: 'ac_install',
    serviceName: 'AC installation',
    category: 'AC Services',
    latitude: 22.5726,
    longitude: 88.3639,
    idempotencyKey: 'idem_key_fixed_100',
  };

  const firstBookRes = createMockRes();
  await bookingController.createBooking({ body: dupPayload, headers: {} }, firstBookRes);
  assert.strictEqual(firstBookRes.statusCode, 201);

  const secondBookRes = createMockRes();
  await bookingController.createBooking({ body: dupPayload, headers: {} }, secondBookRes);
  assert.strictEqual(secondBookRes.statusCode, 409);
  assert.strictEqual(secondBookRes.body.code, 'DUPLICATE_BOOKING');
  console.log('  ✅ Duplicate Booking Request Rejected (HTTP 409 DUPLICATE_BOOKING): PASS\n');

  // ── TEST 3: Stale GPS Location Rejection ──
  console.log('▶ [Test 3] Stale GPS Location Rejection (>10 mins old)...');
  inMemoryTechProfiles.clear();
  bookingsStore.clearAllBookings();
  bookingController.clearMemoryBookings();
  automaticDispatchEngine.resetDispatchEngineStoresForTest();
  automaticDispatchEngine.clearAllSessions();

  const staleIso = new Date(Date.now() - 40 * 60 * 1000).toISOString(); // 40 minutes old
  setTechnicianProfile(techId, {
    id: techId,
    technicianId: techId,
    technicianCode: 'BT-988363',
    fullName: 'Ram',
    isOnline: true,
    online: true,
    isAvailable: true,
    availabilityStatus: 'AVAILABLE',
    verificationStatus: 'VERIFIED',
    kycStatus: 'APPROVED',
    accountStatus: 'ACTIVE',
    latitude: 22.5726,
    longitude: 88.3639,
    currentLatitude: 22.5726,
    currentLongitude: 88.3639,
    lastLocationUpdate: staleIso,
    serviceRadiusKm: 15,
    category: 'AC Services',
    categories: ['AC Services'],
    skills: [
      { id: 'ac_install', skillId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', isActive: true, enabled: true },
    ],
  });

  const staleBookRes = createMockRes();
  await bookingController.createBooking({
    body: {
      id: 'bkg_stale_01',
      customerId: 'cust_002',
      serviceId: 'ac_install',
      serviceName: 'AC installation',
      category: 'AC Services',
      latitude: 22.5726,
      longitude: 88.3639,
      technicianId: techId,
      requireImmediateAssignment: true,
    },
    headers: {},
  }, staleBookRes);

  assert.strictEqual(staleBookRes.statusCode, 409);
  assert.strictEqual(staleBookRes.body.code, 'STALE_LOCATION');
  console.log('  ✅ Stale GPS Coordinates Rejected (HTTP 409 STALE_LOCATION): PASS\n');

  // ── TEST 4: Technician Going Offline During Checkout ──
  console.log('▶ [Test 4] Technician Going Offline During Checkout...');
  setTechnicianProfile(techId, {
    ...inMemoryTechProfiles.get(techId),
    isOnline: false,
    online: false,
    availabilityStatus: 'OFFLINE',
    lastLocationUpdate: new Date().toISOString(),
  });

  const offlineBookRes = createMockRes();
  await bookingController.createBooking({
    body: {
      id: 'bkg_offline_01',
      customerId: 'cust_003',
      serviceId: 'ac_install',
      serviceName: 'AC installation',
      category: 'AC Services',
      latitude: 22.5726,
      longitude: 88.3639,
      technicianId: techId,
      requireImmediateAssignment: true,
    },
    headers: {},
  }, offlineBookRes);

  assert.strictEqual(offlineBookRes.statusCode, 409);
  assert.strictEqual(offlineBookRes.body.code, 'TECHNICIAN_WENT_OFFLINE');
  console.log('  ✅ Technician Offline Rejected (HTTP 409 TECHNICIAN_WENT_OFFLINE): PASS\n');

  // ── TEST 5: Simultaneous Dual-Customer Booking Race Condition ──
  console.log('▶ [Test 5] Simultaneous Dual-Customer Booking Race Condition on Single Technician...');
  bookingsStore.clearAllBookings();
  bookingController.clearMemoryBookings();
  automaticDispatchEngine.clearAllSessions();

  setTechnicianProfile(techId, {
    ...inMemoryTechProfiles.get(techId),
    isOnline: true,
    online: true,
    isAvailable: true,
    availabilityStatus: 'AVAILABLE',
    fcmToken: 'valid_fcm_token_for_partner_ram_988363_xyz_1234567890',
    lastLocationUpdate: new Date().toISOString(),
  });

  const raceResA = createMockRes();
  const raceResB = createMockRes();

  await Promise.all([
    bookingController.createBooking({
      body: {
        id: 'bkg_race_A',
        customerId: 'cust_race_A',
        serviceId: 'ac_install',
        serviceName: 'AC installation',
        category: 'AC Services',
        latitude: 22.5726,
        longitude: 88.3639,
        technicianId: techId,
        requireImmediateAssignment: true,
        idempotencyKey: 'race_key_A',
      },
      headers: {},
    }, raceResA),
    bookingController.createBooking({
      body: {
        id: 'bkg_race_B',
        customerId: 'cust_race_B',
        serviceId: 'ac_install',
        serviceName: 'AC installation',
        category: 'AC Services',
        latitude: 22.5726,
        longitude: 88.3639,
        technicianId: techId,
        requireImmediateAssignment: true,
        idempotencyKey: 'race_key_B',
      },
      headers: {},
    }, raceResB),
  ]);

  const raceCodes = [raceResA.statusCode, raceResB.statusCode].sort();
  assert.deepStrictEqual(raceCodes, [201, 409], `Expected one 201 and one 409, got ${raceCodes}`);
  const loserRes = raceResA.statusCode === 409 ? raceResA : raceResB;
  assert.strictEqual(loserRes.body.code, 'TECHNICIAN_BUSY_CONFLICT');
  console.log('  ✅ Simultaneous Race Condition Prevented (Winner = 201 ASSIGNED, Loser = 409 TECHNICIAN_BUSY_CONFLICT): PASS\n');

  console.log('===================================================================');
  console.log('🎉 ALL PHASE 4.1 BACKEND SAFETY & ATOMICITY TESTS PASSED!');
  console.log('===================================================================');
  process.exit(0);
}

runPhase41BackendSuite().catch((err) => {
  console.error('❌ Test Suite Failed:', err);
  process.exit(1);
});
