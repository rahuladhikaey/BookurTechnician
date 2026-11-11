/**
 * BookurTechnician Firestore Security Rules Audit & Enforcement Test Suite
 * Validates permission isolation, zero client assignment, secrets protection, and KYC isolation.
 */

const assert = require('assert');

const FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
const BASE_URL = `http://${FIRESTORE_EMULATOR_HOST}/v1/projects/bookmytechnician-53d94/databases/(default)/documents`;

// Helper to make unauthenticated or authenticated Firestore REST calls
async function firestoreRequest(path, { method = 'GET', authUid = null, authRole = null, body = null } = {}) {
  const url = `${BASE_URL}/${path}`;
  const headers = { 'Content-Type': 'application/json' };

  if (authUid) {
    // Emulator Auth Token simulation: "Bearer owner" or mock token with claims
    // In Firebase Emulator, passing Authorization: Bearer {"sub": uid, "role": role} or custom token
    const tokenPayload = {
      sub: authUid,
      user_id: authUid,
      uid: authUid,
      role: authRole || 'USER',
      admin: authRole === 'ADMIN',
    };
    // The emulator recognizes JWTs with { sub, user_id, ... }
    const base64Token = Buffer.from(JSON.stringify(tokenPayload)).toString('base64');
    headers['Authorization'] = `Bearer dummy.${base64Token}.dummy`;
  }

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  let data = null;
  try {
    data = await res.json();
  } catch (e) {
    data = null;
  }
  return { status: res.status, data };
}

async function runRulesTests() {
  console.log('================================================================');
  console.log('🔒 RUNNING FIRESTORE SECURITY RULES ISOLATION TESTS (EMULATOR)');
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

  // Helper to format Firestore document fields
  function toFirestoreFields(obj) {
    const fields = {};
    for (const [k, v] of Object.entries(obj)) {
      if (typeof v === 'boolean') fields[k] = { booleanValue: v };
      else if (typeof v === 'number') fields[k] = { integerValue: String(v) };
      else fields[k] = { stringValue: String(v) };
    }
    return { fields };
  }

  // 1. Booking Secrets: Denied to ALL clients
  await test('1. Clients CANNOT read or write booking_secrets collection (Zero Access)', async () => {
    // Attempt read
    const readRes = await firestoreRequest('booking_secrets/test_secret_01', {
      method: 'GET',
      authUid: 'any_client_uid',
    });
    assert([403, 404].includes(readRes.status), `Read should be denied (403), got ${readRes.status}`);

    // Attempt write
    const writeRes = await firestoreRequest('booking_secrets/test_secret_01', {
      method: 'PATCH',
      authUid: 'any_client_uid',
      body: toFirestoreFields({ startOtpHash: 'hack' }),
    });
    assert.strictEqual(writeRes.status, 403, `Direct write to booking_secrets must be 403, got ${writeRes.status}`);
  });

  // 2. Customer OTPs: Readable ONLY by the owning customer
  await test('2. customer_otps collection rejects unauthenticated or foreign access', async () => {
    const foreignRes = await firestoreRequest('customer_otps/bkg_001', {
      method: 'GET',
      authUid: 'foreign_tech_uid',
    });
    assert([403, 404].includes(foreignRes.status));

    // Direct write to customer_otps must be 403 for everyone except Admin SDK
    const writeRes = await firestoreRequest('customer_otps/bkg_001', {
      method: 'PATCH',
      authUid: 'customer_owner',
      body: toFirestoreFields({ startOtp: '1234' }),
    });
    assert.strictEqual(writeRes.status, 403, 'Clients cannot write customer_otps');
  });

  // 3. Technician Private KYC Vault: Accessible ONLY by owner or admin
  await test('3. technician_private is denied to unauthorized technicians', async () => {
    const foreignRes = await firestoreRequest('technician_private/tech_alice', {
      method: 'GET',
      authUid: 'tech_bob',
    });
    assert([403, 404].includes(foreignRes.status));
  });

  // 4. Technician cannot alter their own walletBalance or kycStatus
  await test('4. Technician CANNOT alter walletBalance, kycStatus, or verification in technician_profiles', async () => {
    // First seed a profile
    const admin = require('firebase-admin');
    if (!admin.apps.length) admin.initializeApp({ projectId: 'bookmytechnician-53d94' });
    const db = admin.firestore();

    await db.collection('technician_profiles').doc('tech_wallet_test').set({
      id: 'tech_wallet_test',
      walletBalance: 0,
      kycStatus: 'VERIFIED',
      isOnline: true,
    });

    // Technician attempts to set walletBalance to 100,000
    const tamperRes = await firestoreRequest('technician_profiles/tech_wallet_test', {
      method: 'PATCH',
      authUid: 'tech_wallet_test',
      body: toFirestoreFields({ walletBalance: 100000 }),
    });
    assert.strictEqual(tamperRes.status, 403, `Direct wallet tampering must be blocked (403), got ${tamperRes.status}`);
  });

  // 5. Direct Assignment Lockdown: Technician CANNOT assign themselves to a booking
  await test('5. Technician CANNOT modify technicianId or status on a booking (No Client Self-Assignment)', async () => {
    const admin = require('firebase-admin');
    const db = admin.firestore();

    await db.collection('bookings').doc('bkg_assign_guard_test').set({
      id: 'bkg_assign_guard_test',
      customerId: 'customer_123',
      status: 'SEARCHING',
      totalAmount: 1039,
      technicianId: null,
    });

    // Rogue technician attempts to directly set technicianId to themselves
    const assignTamperRes = await firestoreRequest('bookings/bkg_assign_guard_test', {
      method: 'PATCH',
      authUid: 'rogue_tech_999',
      body: toFirestoreFields({
        technicianId: 'rogue_tech_999',
        status: 'ASSIGNED',
      }),
    });
    assert.strictEqual(assignTamperRes.status, 403, `Direct assignment write must be blocked (403), got ${assignTamperRes.status}`);
  });

  // 6. Direct Client Acceptance of dispatch_offers is BLOCKED
  await test('6. Technician CANNOT directly update dispatch_offers status to ACCEPTED (Reserved for Cloud Functions)', async () => {
    const admin = require('firebase-admin');
    const db = admin.firestore();

    await db.collection('dispatch_offers').doc('offer_client_guard_test').set({
      id: 'offer_client_guard_test',
      technicianId: 'tech_offer_test',
      status: 'SENT',
    });

    const directAcceptRes = await firestoreRequest('dispatch_offers/offer_client_guard_test', {
      method: 'PATCH',
      authUid: 'tech_offer_test',
      body: toFirestoreFields({ status: 'ACCEPTED' }),
    });
    assert.strictEqual(directAcceptRes.status, 403, `Direct offer acceptance must be blocked (403), got ${directAcceptRes.status}`);

    // But directly REJECTING an offer is permitted
    const directRejectRes = await firestoreRequest('dispatch_offers/offer_client_guard_test', {
      method: 'PATCH',
      authUid: 'tech_offer_test',
      body: toFirestoreFields({ status: 'REJECTED' }),
    });
    assert([200, 204].includes(directRejectRes.status), `Direct offer reject should succeed, got ${directRejectRes.status}`);
  });

  // 7. Audit Logs: Write denied to all clients
  await test('7. audit_logs and dispatch_audit_logs write is denied to all clients (403)', async () => {
    const auditRes = await firestoreRequest('audit_logs/log_001', {
      method: 'PATCH',
      authUid: 'any_user',
      body: toFirestoreFields({ event: 'FAKE_LOG' }),
    });
    assert.strictEqual(auditRes.status, 403, 'Clients cannot write audit_logs');
  });

  console.log('\n================================================================');
  console.log(`📊 SECURITY RULES SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');

  if (failed > 0) process.exit(1);
}

runRulesTests().catch((err) => {
  console.error('Fatal rules test error:', err);
  process.exit(1);
});
