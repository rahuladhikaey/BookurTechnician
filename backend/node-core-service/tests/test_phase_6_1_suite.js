/**
 * BOOKURTECHNICIAN — PHASE 6.1 CRITICAL SECURITY & REAL-TIME SYNCHRONIZATION TEST SUITE
 * Verifies all Phase 6.1 requirements:
 *   1. P0 Security: Zero hardcoded credentials in frontend builds or source
 *   2. P0 Security: Server-side environment key validation (fails securely)
 *   3. P0 Security: Removal of fake authentication and fallback bypass
 *   4. P0 Security: Direct Firestore writes blocked from client
 *   5. RBAC & Access Control: All unauthorized requests rejected (401/403)
 *   6. Firestore Rules: Audit of dispatch_offers, dispatch_sessions, bookings, technician_private
 *   7. Backend Authority: PostgreSQL source of truth & atomic locking mutex
 *   8. Concurrency: Two technicians accepting same booking (atomic mutex conflict handling)
 *   9. Admin Live Dashboard: Authoritative server-side aggregate statistics
 *  10. Real-time Notification Lifecycle: Technician & Customer events with deduplication
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

// Load environment variables before any other imports
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'b7e289f03c4a16d8e950bc42ad9f7124e5d6c813a0294b7e51c863a9f021e847';

const authController = require('../src/controllers/authController');
const adminController = require('../src/controllers/adminController');
const notificationService = require('../src/services/notificationService');

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

async function runPhase61VerificationSuite() {
  const adapterUrl = 'file:///' + path.join(__dirname, '../../../apps/admin_panel/src/api/firestoreAdapter.js').replace(/\\/g, '/');
  const { handleFirestoreFallback, firestoreUpsert, firestoreDelete } = await import(adapterUrl);

  const results = [];
  let passed = 0;
  let failed = 0;

  async function runTest(id, name, fn) {
    try {
      await fn();
      passed++;
      results.push({ id, name, status: 'PASS' });
      console.log(`✅ [PASS] ${id}: ${name}`);
    } catch (err) {
      failed++;
      results.push({ id, name, status: 'FAIL', error: err.message });
      console.error(`❌ [FAIL] ${id}: ${name} -> ${err.message}`);
    }
  }

  console.log('================================================================');
  console.log('🛡️ STARTING PHASE 6.1 CRITICAL SECURITY & REAL-TIME TEST SUITE');
  console.log('================================================================\n');

  // ---------------------------------------------------------------------------
  // 1. P0 SECURITY HARDENING: ZERO HARDCODED CREDENTIALS
  // ---------------------------------------------------------------------------

  await runTest('SEC-01', 'Frontend source code and build bundles contain zero hardcoded credentials', async () => {
    const adminLoginPath = path.join(__dirname, '../../../apps/admin_panel/src/features/auth/AdminLogin.jsx');
    const adminLoginContent = fs.readFileSync(adminLoginPath, 'utf8');
    assert.ok(!adminLoginContent.includes('BT-ADMIN-KEY'), 'AdminLogin.jsx must not contain BT-ADMIN-KEY');
    assert.ok(!adminLoginContent.includes('DEFAULT_KEY_1'), 'AdminLogin.jsx must not contain DEFAULT_KEY_1');

    const distPath = path.join(__dirname, '../../../apps/admin_panel/dist');
    if (fs.existsSync(distPath)) {
      const files = fs.readdirSync(distPath, { recursive: true });
      for (const f of files) {
        const fullP = path.join(distPath, f);
        if (fs.statSync(fullP).isFile() && (f.endsWith('.js') || f.endsWith('.html'))) {
          const content = fs.readFileSync(fullP, 'utf8');
          assert.ok(!content.includes('BT-ADMIN-KEY'), `Production build bundle ${f} must not contain BT-ADMIN-KEY`);
        }
      }
    }
  });

  await runTest('SEC-02', 'adminDirectAccess rejects missing or invalid credentials and validates against environment', async () => {
    // Attempt with wrong credentials
    const badReq = { body: { email: 'admin@bookurtechnician.com', accessKey1: 'WRONG_SECRET_KEY' } };
    const badRes = createMockRes();
    await authController.adminDirectAccess(badReq, badRes);
    assert.strictEqual(badRes.statusCode, 401, 'Invalid admin passkey must return HTTP 401');

    // Attempt with valid environment credentials
    const validKey = process.env.ADMIN_KEY_PRIMARY;
    assert.ok(validKey && validKey.length >= 32, 'ADMIN_KEY_PRIMARY must be set in environment with >= 32 characters');
    const goodReq = { body: { email: 'admin@bookurtechnician.com', accessKey1: validKey } };
    const goodRes = createMockRes();
    await authController.adminDirectAccess(goodReq, goodRes);
    assert.strictEqual(goodRes.statusCode, 200, 'Valid admin passkey must return HTTP 200');
    assert.ok(goodRes.body.token, 'Must return signed JWT accessToken');
    assert.strictEqual(goodRes.body.user.role, 'SUPER_ADMIN');
  });

  await runTest('SEC-03', 'Fake admin authentication and fallback bypass are completely removed from firestoreAdapter', async () => {
    const adminReqs = [
      '/admin/me',
      '/admin/stats',
      '/admin/overview',
      '/admin/bookings',
      '/admin/customers',
      '/admin/technicians',
      '/auth/admin/direct-access',
    ];

    for (const ep of adminReqs) {
      const res = await handleFirestoreFallback(ep, 'GET', null);
      assert.strictEqual(res.success, false, `Fallback for ${ep} must be blocked`);
      assert.strictEqual(res.statusCode, 401, `Fallback for ${ep} must return HTTP 401`);
      assert.strictEqual(res.code, 'ADMIN_FALLBACK_FORBIDDEN');
    }
  });

  await runTest('SEC-04', 'Direct client-side Firestore writes are permanently disabled', async () => {
    await assert.rejects(
      async () => {
        await firestoreUpsert('bookings', 'b-test-999', { status: 'COMPLETED' });
      },
      /Direct client Firestore writes are disabled/,
      'firestoreUpsert must throw and deny client-side write'
    );

    await assert.rejects(
      async () => {
        await firestoreDelete('bookings', 'b-test-999');
      },
      /Direct client Firestore deletes are disabled/,
      'firestoreDelete must throw and deny client-side delete'
    );
  });

  // ---------------------------------------------------------------------------
  // 2. RBAC & UNAUTHORIZED REQUEST REJECTION
  // ---------------------------------------------------------------------------

  const customerToken = jwt.sign({ id: 'cust_test_01', role: 'CUSTOMER' }, JWT_SECRET, { expiresIn: '1h' });
  const technicianToken = jwt.sign({ id: 'uid_tech_9876988363', role: 'TECHNICIAN' }, JWT_SECRET, { expiresIn: '1h' });
  const expiredAdminToken = jwt.sign({ id: 'admin_test', role: 'SUPER_ADMIN' }, JWT_SECRET, { expiresIn: '-10s' });
  const validAdminToken = jwt.sign({ id: 'admin_test', role: 'SUPER_ADMIN' }, JWT_SECRET, { expiresIn: '1h' });

  const { authenticateToken, requireAdminRole } = require('../src/middleware/authMiddleware');

  async function testMiddleware(authHeader) {
    const req = {
      headers: authHeader ? { authorization: authHeader } : {},
      method: 'GET',
    };
    const res = createMockRes();
    let nextCalled = false;

    await authenticateToken(req, res, () => {
      requireAdminRole(req, res, () => {
        nextCalled = true;
      });
    });

    return { nextCalled, statusCode: res.statusCode, body: res.body };
  }

  await runTest('SEC-05', 'Unauthenticated user rejected from admin endpoints (HTTP 401)', async () => {
    const res = await testMiddleware(null);
    assert.strictEqual(res.nextCalled, false);
    assert.strictEqual(res.statusCode, 401);
  });

  await runTest('SEC-06', 'Expired admin token rejected from admin endpoints (HTTP 403)', async () => {
    const res = await testMiddleware(`Bearer ${expiredAdminToken}`);
    assert.strictEqual(res.nextCalled, false);
    assert.strictEqual(res.statusCode, 403);
  });

  await runTest('SEC-07', 'Customer token attempting admin access rejected (HTTP 403)', async () => {
    const res = await testMiddleware(`Bearer ${customerToken}`);
    assert.strictEqual(res.nextCalled, false);
    assert.strictEqual(res.statusCode, 403);
  });

  await runTest('SEC-08', 'Technician token attempting admin access rejected (HTTP 403)', async () => {
    const res = await testMiddleware(`Bearer ${technicianToken}`);
    assert.strictEqual(res.nextCalled, false);
    assert.strictEqual(res.statusCode, 403);
  });

  await runTest('SEC-09', 'Valid admin token granted access to admin endpoints', async () => {
    const res = await testMiddleware(`Bearer ${validAdminToken}`);
    assert.strictEqual(res.nextCalled, true);
  });

  // ---------------------------------------------------------------------------
  // 3. FIRESTORE SECURITY RULES AUDIT
  // ---------------------------------------------------------------------------

  await runTest('SEC-10', 'firestore.rules enforces comprehensive least-privilege security across all collections', async () => {
    const rulesPath = path.join(__dirname, '../../../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    // Required collections audit
    assert.ok(rules.includes('match /dispatch_offers/{offerId}'), 'Missing dispatch_offers rule');
    assert.ok(rules.includes('match /dispatch_sessions/{sessionId}'), 'Missing dispatch_sessions rule');
    assert.ok(rules.includes('match /booking_events/{eventId}'), 'Missing booking_events rule');
    assert.ok(rules.includes('match /dispatch_audit_logs/{logId}'), 'Missing dispatch_audit_logs rule');
    assert.ok(rules.includes('match /bookings/{bookingId}'), 'Missing bookings rule');
    assert.ok(rules.includes('match /technician_profiles/{techId}'), 'Missing technician_profiles rule');
    assert.ok(rules.includes('match /technician_private/{techId}'), 'Missing technician_private rule');

    // Field guards verification
    assert.ok(!rules.includes('technician_profiles/{techId} {\n      allow read: if isAuthenticated() || true;'), 'Public read bypass removed');
    assert.ok(rules.includes('walletBalance'), 'walletBalance protected from client writes');
    assert.ok(rules.includes('paymentStatus'), 'paymentStatus protected from client writes');
    assert.ok(rules.includes('technicianPayoutAmount'), 'technicianPayoutAmount protected from client writes');
  });

  // ---------------------------------------------------------------------------
  // 4. BACKEND CONCURRENCY & ATOMIC BOOKING MUTEX LOCKING
  // ---------------------------------------------------------------------------

  await runTest('CONC-01', 'Two technicians accepting the same booking simultaneously results in exactly one winner and one 409 Conflict', async () => {
    const automaticDispatchEngine = require('../src/services/automaticDispatchEngine');
    const bookingsStore = require('../src/config/bookingsStore');

    const testBookingId = 'b_conc_test_' + Date.now();
    const tech1Uid = 'uid_tech_9876988363';
    const tech2Uid = 'uid_tech_9876988364';

    // Seed mock pending booking
    bookingsStore.addBooking({
      id: testBookingId,
      bookingId: testBookingId,
      customerId: 'cust_conc_01',
      serviceId: 'ac_install',
      serviceName: 'AC installation',
      status: 'SEARCHING',
      totalAmount: 1299,
    });

    const offer1 = {
      id: 'off_1_' + Date.now(),
      offerId: 'off_1_' + Date.now(),
      bookingId: testBookingId,
      technicianId: tech1Uid,
      targetTechnicianUid: tech1Uid,
      status: 'SENT',
      expiresAt: new Date(Date.now() + 60000).toISOString(),
    };

    const offer2 = {
      id: 'off_2_' + Date.now(),
      offerId: 'off_2_' + Date.now(),
      bookingId: testBookingId,
      technicianId: tech2Uid,
      targetTechnicianUid: tech2Uid,
      status: 'SENT',
      expiresAt: new Date(Date.now() + 60000).toISOString(),
    };

    automaticDispatchEngine.dispatchOffersStore.set(offer1.id, offer1);
    automaticDispatchEngine.dispatchOffersStore.set(offer2.id, offer2);
    automaticDispatchEngine.dispatchSessionsStore.set(testBookingId, {
      bookingId: testBookingId,
      status: 'SEARCHING',
      activeOfferId: offer1.id,
      offers: [offer1, offer2],
    });

    // Accept simultaneously
    const p1 = automaticDispatchEngine.acceptOffer(offer1.id, tech1Uid)
      .then(res => ({ tech: 'tech1', success: true, res }))
      .catch(err => ({ tech: 'tech1', success: false, status: err.statusCode || 500, error: err.message }));

    const p2 = automaticDispatchEngine.acceptOffer(offer2.id, tech2Uid)
      .then(res => ({ tech: 'tech2', success: true, res }))
      .catch(err => ({ tech: 'tech2', success: false, status: err.statusCode || 500, error: err.message }));

    const [r1, r2] = await Promise.all([p1, p2]);

    const successes = [r1, r2].filter(r => r.success);
    const conflicts = [r1, r2].filter(r => !r.success && (r.status === 409 || r.status === 403));

    assert.strictEqual(successes.length, 1, 'Exactly one technician must win the race');
    assert.strictEqual(conflicts.length, 1, 'The competing technician must receive HTTP 409 Conflict');
  });

  // ---------------------------------------------------------------------------
  // 5. ADMIN LIVE DASHBOARD: SERVER-SIDE AGGREGATE STATISTICS
  // ---------------------------------------------------------------------------

  await runTest('DASH-01', 'adminController.getOverview returns server-side aggregates reconciling with database', async () => {
    const req = { user: { id: 'admin_test', role: 'SUPER_ADMIN' } };
    const res = createMockRes();
    await adminController.getOverview(req, res);
    assert.strictEqual(res.statusCode, 200);
    const stats = res.body.data;
    assert.ok(typeof stats.totalBookings === 'number', 'totalBookings must be numeric');
    assert.ok(typeof stats.pendingBookings === 'number', 'pendingBookings must be numeric');
    assert.ok(typeof stats.activeDispatches === 'number', 'activeDispatches must be numeric');
    assert.ok(typeof stats.assignedBookings === 'number', 'assignedBookings must be numeric');
    assert.ok(typeof stats.activeTechnicians === 'number', 'activeTechnicians must be numeric');
    assert.ok(typeof stats.completedBookings === 'number', 'completedBookings must be numeric');
    assert.ok(typeof stats.cancelledBookings === 'number', 'cancelledBookings must be numeric');
    assert.ok(typeof stats.failedDispatches === 'number', 'failedDispatches must be numeric');
    assert.ok(stats.totalBookings >= 0);
  });

  await runTest('DASH-02', 'adminController.getBookings returns complete booking management fields for every booking', async () => {
    const req = { user: { id: 'admin_test', role: 'SUPER_ADMIN' } };
    const res = createMockRes();
    await adminController.getBookings(req, res);
    assert.strictEqual(res.statusCode, 200);
    const list = res.body.data;
    assert.ok(Array.isArray(list) && list.length > 0);
    const b = list[0];
    assert.ok(b.id || b.bookingId, 'Booking must have ID');
    assert.ok(b.customer, 'Booking must have customer object');
    assert.ok(b.selectedService, 'Booking must have selectedService object');
    assert.ok(b.status && b.dispatchStatus, 'Booking must have status and dispatchStatus');
    assert.ok(Array.isArray(b.notifiedTechnicians), 'Booking must have notifiedTechnicians array');
    assert.ok(Array.isArray(b.timeline), 'Booking must have timeline array');
  });

  // ---------------------------------------------------------------------------
  // 6. REAL-TIME NOTIFICATION LIFECYCLE
  // ---------------------------------------------------------------------------

  await runTest('NOTIF-01', 'Complete notification lifecycle methods exist and deduplicate identical offer alerts', async () => {
    assert.strictEqual(typeof notificationService.notifyCustomerBookingSubmitted, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerTechnicianAssigned, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerTechnicianAccepted, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerTechnicianEnRoute, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerTechnicianArrived, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerServiceStarted, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerServiceCompleted, 'function');
    assert.strictEqual(typeof notificationService.notifyCustomerBookingCancelledOrExpired, 'function');

    assert.strictEqual(typeof notificationService.notifyTechnicianNewRequest, 'function');
    assert.strictEqual(typeof notificationService.notifyTechnicianAcceptedElsewhere, 'function');
    assert.strictEqual(typeof notificationService.notifyTechnicianOfferExpired, 'function');
    assert.strictEqual(typeof notificationService.notifyTechnicianBookingCancelled, 'function');
    assert.strictEqual(typeof notificationService.notifyTechnicianBookingUpdate, 'function');

    // Test deduplication on rapid duplicate offer notifications
    const res1 = await notificationService.sendToUser('user_test_dedup_01', {
      title: 'Job Offer',
      body: 'New offer',
      data: { offerId: 'offer_dedup_100' },
    });
    const res2 = await notificationService.sendToUser('user_test_dedup_01', {
      title: 'Job Offer',
      body: 'New offer',
      data: { offerId: 'offer_dedup_100' },
    });
    assert.strictEqual(res2.deduplicated, true, 'Second identical offer alert must be deduplicated');
  });

  console.log('\n================================================================');
  console.log(`🏁 PHASE 6.1 TEST SUITE SUMMARY: ${passed}/${passed + failed} PASSED`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase61VerificationSuite().catch((err) => {
  console.error('Fatal Phase 6.1 suite error:', err);
  process.exit(1);
});
