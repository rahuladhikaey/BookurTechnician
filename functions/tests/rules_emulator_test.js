/**
 * BookurTechnician Dedicated Firestore Security Rules Unit & Boundary Tests
 * Evaluates local firestore.rules against the Firestore Emulator (Port 8085).
 */

const assert = require('assert');
const admin = require('firebase-admin');

const FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
const PROJECT_ID = 'bookmytechnician-53d94';
const BASE_REST = `http://${FIRESTORE_EMULATOR_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// Helper to make simulated client requests with custom auth claims
async function clientRequest(path, method = 'GET', body = null, authHeader = null) {
  const url = `${BASE_REST}/${path}`;
  const headers = { 'Content-Type': 'application/json' };
  if (authHeader) {
    headers['Authorization'] = authHeader;
  }
  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (e) {}
  if (res.status === 400) {
    console.log(`[DEBUG 400 on ${path}] ${JSON.stringify(data)}`);
  }
  return { status: res.status, data };
}

// Helper to format Firestore REST fields
function toFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === null || v === undefined) {
      fields[k] = { nullValue: null };
    } else if (typeof v === 'boolean') {
      fields[k] = { booleanValue: v };
    } else if (typeof v === 'number') {
      if (Number.isInteger(v)) {
        fields[k] = { integerValue: String(v) };
      } else {
        fields[k] = { doubleValue: v };
      }
    } else if (typeof v === 'string') {
      fields[k] = { stringValue: v };
    } else if (Array.isArray(v)) {
      fields[k] = { arrayValue: { values: v.map((item) => ({ stringValue: String(item) })) } };
    } else if (typeof v === 'object') {
      fields[k] = { mapValue: { fields: toFields(v) } };
    }
  }
  return { fields };
}

function createTestToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify({
    iss: 'https://securetoken.google.com/bookmytechnician-53d94',
    aud: 'bookmytechnician-53d94',
    auth_time: Math.floor(Date.now() / 1000),
    user_id: payload.sub,
    sub: payload.sub,
    ...payload,
  })).toString('base64url');
  return `Bearer ${header}.${body}.`;
}

async function runRulesTests() {
  console.log('================================================================');
  console.log('🛡️ RUNNING FIRESTORE SECURITY RULES VERIFICATION TEST SUITE');
  console.log(`Firestore Emulator: ${FIRESTORE_EMULATOR_HOST}`);
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
      failed++;
    }
  }

  // 0. Seed test fixtures using Admin SDK (bypasses rules)
  await db.collection('bookings').doc('bkg_rules_test_01').set({
    id: 'bkg_rules_test_01',
    customerId: 'cust_alice',
    technicianId: 'tech_bob',
    status: 'SEARCHING',
    price: 1039,
    totalAmount: 1039,
    startOtp: '1234',
    endOtp: '5678',
  });

  await db.collection('booking_secrets').doc('bkg_rules_test_01').set({
    bookingId: 'bkg_rules_test_01',
    startOtpHash: 'secret_hash_value',
    failedStartAttempts: 0,
  });

  await db.collection('technician_profiles').doc('tech_bob').set({
    id: 'tech_bob',
    name: 'Bob Technician',
    walletBalance: 500,
    isOnline: true,
    kycStatus: 'VERIFIED',
  });

  await db.collection('technician_private').doc('tech_bob').set({
    id: 'tech_bob',
    aadhaarNumber: '1234-5678-9012',
    upiId: 'bob@upi',
  });

  await db.collection('wallet_withdrawals').doc('wth_test_01').set({
    id: 'wth_test_01',
    technicianId: 'tech_bob',
    amount: 500,
    status: 'PENDING',
    destinationUpi: 'bob@upi',
  });

  await db.collection('audit_logs').doc('log_system_01').set({
    id: 'log_system_01',
    event: 'SYSTEM_STARTUP',
  });

  // Simulated Auth Headers using valid 3-part test JWTs
  const NO_AUTH = null;
  const AUTH_ALICE_CUSTOMER = createTestToken({ sub: 'cust_alice' });
  const AUTH_CHARLIE_STRANGER = createTestToken({ sub: 'user_charlie' });
  const AUTH_BOB_TECH = createTestToken({ sub: 'tech_bob' });
  const AUTH_FAKE_ADMIN = createTestToken({ sub: 'hacker_01', role: 'USER', admin: false });
  const AUTH_REAL_ADMIN = createTestToken({ sub: 'admin_master', admin: true, role: 'ADMIN' });

  // Test 1: Unauthenticated access denied to protected collections
  await test('1. Unauthenticated read to bookings is DENIED (403/401)', async () => {
    const res = await clientRequest('bookings/bkg_rules_test_01', 'GET', null, NO_AUTH);
    assert.strictEqual(res.status, 403, 'Unauthenticated read to bookings must be forbidden');
  });

  await test('2. Unauthenticated read to technician_private is DENIED (403/401)', async () => {
    const res = await clientRequest('technician_private/tech_bob', 'GET', null, NO_AUTH);
    assert.strictEqual(res.status, 403, 'Unauthenticated read to technician_private must be forbidden');
  });

  // Test 2: Customer cannot self-assign technician
  await test('3. Customer cannot set technicianId during booking creation (403)', async () => {
    const body = toFields({
      customerId: 'cust_alice',
      technicianId: 'tech_bob', // FORBIDDEN!
      status: 'SEARCHING',
    });
    const res = await clientRequest('bookings?documentId=bkg_illegal_assign', 'POST', body, AUTH_ALICE_CUSTOMER);
    assert.strictEqual(res.status, 403, 'Customer cannot self-assign a technicianId on creation');
  });

  // Test 3: Technician cannot self-assign existing booking
  await test('4. Technician cannot modify technicianId or assign themselves to booking (403)', async () => {
    const body = toFields({
      technicianId: 'tech_bob',
      status: 'ASSIGNED',
    });
    const res = await clientRequest('bookings/bkg_rules_test_01', 'PATCH', body, AUTH_BOB_TECH);
    assert.strictEqual(res.status, 403, 'Technician cannot overwrite technicianId');
  });

  // Test 4: Technician cannot modify their own wallet balance
  await test('5. Technician cannot directly modify their wallet balance (403)', async () => {
    const body = toFields({
      walletBalance: 50000, // Attempted illegal credit
    });
    const res = await clientRequest('technician_profiles/tech_bob', 'PATCH', body, AUTH_BOB_TECH);
    assert.strictEqual(res.status, 403, 'Technician cannot modify wallet balance directly');
  });

  // Test 5: Technician cannot approve their own withdrawal
  await test('6. Technician cannot change withdrawal status to PAID or APPROVED (403)', async () => {
    const body = toFields({
      status: 'PAID',
      utrReference: 'UTR123456',
    });
    const res = await clientRequest('wallet_withdrawals/wth_test_01', 'PATCH', body, AUTH_BOB_TECH);
    assert.strictEqual(res.status, 403, 'Technician cannot approve their own withdrawal');
  });

  // Test 6: Customer cannot read booking secrets
  await test('7. Customer cannot read booking_secrets (403)', async () => {
    const res = await clientRequest('booking_secrets/bkg_rules_test_01', 'GET', null, AUTH_ALICE_CUSTOMER);
    assert.strictEqual(res.status, 403, 'booking_secrets must be forbidden to customers');
  });

  await test('8. Technician cannot read booking_secrets (403)', async () => {
    const res = await clientRequest('booking_secrets/bkg_rules_test_01', 'GET', null, AUTH_BOB_TECH);
    assert.strictEqual(res.status, 403, 'booking_secrets must be forbidden to technicians');
  });

  // Test 7: Unauthorized user cannot read technician_private
  await test('9. Unauthorized user cannot read technician_private KYC/UPI documents (403)', async () => {
    const res = await clientRequest('technician_private/tech_bob', 'GET', null, AUTH_CHARLIE_STRANGER);
    assert.strictEqual(res.status, 403, 'technician_private must be forbidden to third parties');
  });

  // Test 8: Non-admin cannot modify audit logs
  await test('10. Non-admin cannot write or tamper with audit logs (403)', async () => {
    const body = toFields({
      event: 'ILLEGAL_LOG_ENTRY',
    });
    const res = await clientRequest('audit_logs/log_system_01', 'PATCH', body, AUTH_CHARLIE_STRANGER);
    assert.strictEqual(res.status, 403, 'Non-admin cannot modify audit logs');
  });

  // Test 9: Fake Admin without JWT custom claims is blocked
  await test('11. Fake Admin without verified JWT claims cannot perform privileged actions (403)', async () => {
    const body = toFields({
      status: 'PAID',
      utrReference: 'UTR999999',
    });
    const res = await clientRequest('wallet_withdrawals/wth_test_01', 'PATCH', body, AUTH_FAKE_ADMIN);
    assert.strictEqual(res.status, 403, 'Fake admin must be denied');
  });

  // Test 10: Real Admin with verified JWT claims can approve withdrawal with UTR
  await test('12. Real Admin with verified JWT claim can update withdrawal to PAID with UTR (200)', async () => {
    const body = toFields({
      status: 'PAID',
      utrReference: 'UTR_BANK_REAL_12345',
    });
    const res = await clientRequest('wallet_withdrawals/wth_test_01?updateMask.fieldPaths=status&updateMask.fieldPaths=utrReference', 'PATCH', body, AUTH_REAL_ADMIN);
    assert.strictEqual(res.status, 200, 'Real admin with verified claim should succeed');
  });

  console.log('\n================================================================');
  console.log(`📊 FIRESTORE RULES TESTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================\n');

  if (failed > 0) process.exit(1);
}

runRulesTests().catch((err) => {
  console.error('Fatal rules test error:', err);
  process.exit(1);
});
