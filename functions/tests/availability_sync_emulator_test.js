/**
 * BookurTechnician — Phase 6 End-to-End Availability Sync Emulator Test Suite
 *
 * Exercises ALL 11 Phase 6 scenarios against:
 *   1. Real Cloud Firestore Emulator (127.0.0.1:8085) enforcing local firestore.rules
 *   2. Real Trusted Backend Express App (functions/src/app.js) using Firebase Admin SDK
 *   3. Unified Eligibility Engine (functions/src/eligibilityService.js)
 */

const assert = require('assert');
const http = require('http');
const admin = require('firebase-admin');
const { createApp } = require('../src/app');

process.env.FUNCTIONS_EMULATOR = 'true';
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';

const PROJECT_ID = 'bookmytechnician-53d94';
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const FIRESTORE_REST_BASE = `http://${EMULATOR_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

function makeEmulatorJwt(uid, extra = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      iss: `https://securetoken.google.com/${PROJECT_ID}`,
      aud: PROJECT_ID,
      auth_time: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      sub: uid,
      user_id: uid,
      ...extra,
    })
  ).toString('base64url');
  return `Bearer ${header}.${payload}.`;
}

function toFirestoreFields(obj) {
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
          values: v.map((item) => {
            if (typeof item === 'object' && item !== null) {
              return { mapValue: toFirestoreFields(item) };
            }
            return { stringValue: String(item) };
          }),
        },
      };
    } else if (typeof v === 'object') {
      fields[k] = { mapValue: toFirestoreFields(v) };
    }
  }
  return { fields };
}

async function clearFirestoreEmulator() {
  const url = `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const res = await fetch(url, { method: 'DELETE' });
  if (!res.ok) {
    throw new Error(`Failed clearing Firestore Emulator (${res.status}). Is it running on ${EMULATOR_HOST}?`);
  }
}

async function seedCatalog() {
  await db.collection('service_categories').doc('cat_ac').set({
    id: 'cat_ac',
    name: 'AC Services',
    subcategories: [
      {
        id: 'sub_ac',
        name: 'AC Care',
        services: [
          { id: 'ac_install', name: 'AC installation' },
          { id: 'ac_repair_general', name: 'AC repair' },
        ],
      },
    ],
  });
  await db.collection('service_categories').doc('cat_elec').set({
    id: 'cat_elec',
    name: 'Electrical Services',
    subcategories: [
      {
        id: 'sub_elec',
        name: 'Electrical',
        services: [
          { id: 'light_rep', name: 'Light Repair' },
          { id: 'ro_filter_replacement', name: 'Water purifier filter replacement' },
        ],
      },
    ],
  });
}

async function runTests() {
  const app = createApp(db);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;

  async function apiRequest(path, { method = 'GET', uid = 'cust_emu_01', body = null } = {}) {
    const res = await fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'x-mock-user-id': uid,
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await res.json();
    return { status: res.status, data };
  }

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await clearFirestoreEmulator();
      await seedCatalog();
      await fn();
      console.log(`  PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  FAIL: ${name}`);
      console.error(`    ${err.stack || err.message}`);
      failed++;
    }
  }

  const nowIso = () => new Date().toISOString();
  const custLat = 23.2420;
  const custLng = 88.5530;

  console.log('================================================================');
  console.log('PHASE 6 — FIREBASE EMULATOR AVAILABILITY SYNC TEST SUITE (11 SCENARIOS)');
  console.log(`Firestore Emulator: ${EMULATOR_HOST} | API Server: ${baseUrl}`);
  console.log('================================================================\n');

  await test('Scenario 1: Online technician + matching verified skill = eligible (+ rules auth check)', async () => {
    await db.collection('technician_profiles').doc('tech_ac_1').set({
      id: 'tech_ac_1',
      uid: 'tech_ac_1',
      technicianId: 'tech_ac_1',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.status, 200);
    assert.strictEqual(avail.data.availableTechnicianCount, 1);

    // Unauthenticated REST client must be blocked by firestore.rules (403)
    const unauthRes = await fetch(`${FIRESTORE_REST_BASE}/technician_profiles/tech_ac_1`);
    assert.strictEqual(unauthRes.status, 403);

    // Authenticated customer JWT succeeds reading technician_profiles (200)
    const authRes = await fetch(`${FIRESTORE_REST_BASE}/technician_profiles/tech_ac_1`, {
      headers: { Authorization: makeEmulatorJwt('cust_emu_01') },
    });
    assert.strictEqual(authRes.status, 200);
  });

  await test('Scenario 2: Online technician + wrong skill = not eligible', async () => {
    await db.collection('technician_profiles').doc('tech_elec_1').set({
      id: 'tech_elec_1',
      uid: 'tech_elec_1',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      category: 'AC Services', // Category bait must never qualify
      skills: [
        { id: 'light_rep', canonicalServiceId: 'light_rep', name: 'Light Repair', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.status, 200);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);
  });

  await test('Scenario 3: Online technician + unverified skill (or unverified KYC/account) = not eligible', async () => {
    await db.collection('technician_profiles').doc('tech_pending_skill').set({
      id: 'tech_pending_skill',
      uid: 'tech_pending_skill',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'PENDING', enabled: true },
      ],
    });
    await db.collection('technician_profiles').doc('tech_pending_kyc').set({
      id: 'tech_pending_kyc',
      uid: 'tech_pending_kyc',
      accountStatus: 'PENDING_VERIFICATION',
      kycStatus: 'PENDING',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.status, 200);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);
  });

  await test('Scenario 4: Offline technician = not eligible', async () => {
    await db.collection('technician_profiles').doc('tech_off_1').set({
      id: 'tech_off_1',
      uid: 'tech_off_1',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: false,
      availabilityStatus: 'OFFLINE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);
  });

  await test('Scenario 5: Busy technician = not eligible (availabilityStatus=BUSY or active booking)', async () => {
    await db.collection('technician_profiles').doc('tech_busy_1').set({
      id: 'tech_busy_1',
      uid: 'tech_busy_1',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'BUSY',
      activeBookingId: 'bkg_active_1',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });
    await db.collection('technician_profiles').doc('tech_busy_booking_2').set({
      id: 'tech_busy_booking_2',
      uid: 'tech_busy_booking_2',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });
    await db.collection('bookings').doc('bkg_inprog_2').set({
      id: 'bkg_inprog_2',
      technicianId: 'tech_busy_booking_2',
      status: 'IN_PROGRESS',
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);
  });

  await test('Scenario 6: Online technician with stale location (>10m) = not eligible', async () => {
    const staleIso = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    await db.collection('technician_profiles').doc('tech_stale_1').set({
      id: 'tech_stale_1',
      uid: 'tech_stale_1',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: staleIso,
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);
  });

  await test('Scenario 7: Online technician within coverage = eligible; outside coverage = not eligible', async () => {
    await db.collection('technician_profiles').doc('tech_near').set({
      id: 'tech_near',
      uid: 'tech_near',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2600, // ~2.1 km away
      longitude: 88.5600,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });
    await db.collection('technician_profiles').doc('tech_far').set({
      id: 'tech_far',
      uid: 'tech_far',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 22.5726, // ~77 km away (Kolkata vs Birnagar)
      longitude: 88.3639,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 1);

    const nearby = await apiRequest(`/catalog/technicians/nearby?latitude=${custLat}&longitude=${custLng}&radiusKm=15&serviceId=ac_install`);
    assert.strictEqual(nearby.data.technicians.length, 1);
    assert.strictEqual(nearby.data.technicians[0].technicianId, 'tech_near');
  });

  await test('Scenario 8: Technician goes offline = customer availability updates to 0', async () => {
    await db.collection('technician_profiles').doc('tech_toggle').set({
      id: 'tech_toggle',
      uid: 'tech_toggle',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    let avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 1);

    const goOff = await apiRequest('/updateTechnicianPresence', {
      method: 'POST',
      uid: 'tech_toggle',
      body: { isOnline: false },
    });
    assert.strictEqual(goOff.status, 200);
    assert.strictEqual(goOff.data.data.availabilityStatus, 'OFFLINE');

    avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);
  });

  await test('Scenario 9: Technician comes online = customer availability updates to 1', async () => {
    await db.collection('technician_profiles').doc('tech_toggle_on').set({
      id: 'tech_toggle_on',
      uid: 'tech_toggle_on',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: false,
      availabilityStatus: 'OFFLINE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    let avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);

    const goOn = await apiRequest('/updateTechnicianPresence', {
      method: 'POST',
      uid: 'tech_toggle_on',
      body: { isOnline: true, latitude: 23.2440, longitude: 88.5550 },
    });
    assert.strictEqual(goOn.status, 200);
    assert.strictEqual(goOn.data.data.availabilityStatus, 'AVAILABLE');

    avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 1);
  });

  await test('Scenario 10: Two technicians with different skills = accurate service-specific counts', async () => {
    await db.collection('technician_profiles').doc('tech_only_ac').set({
      id: 'tech_only_ac',
      uid: 'tech_only_ac',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });
    await db.collection('technician_profiles').doc('tech_only_light').set({
      id: 'tech_only_light',
      uid: 'tech_only_light',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'light_rep', canonicalServiceId: 'light_rep', name: 'Light Repair', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    const catAvail = await apiRequest(`/catalog/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(catAvail.status, 200);
    const byId = Object.fromEntries(catAvail.data.services.map((s) => [s.serviceId, s.availableTechnicianCount]));
    assert.strictEqual(byId.ac_install, 1);
    assert.strictEqual(byId.light_rep, 1);
    assert.strictEqual(byId.ac_repair_general, 0);
    assert.strictEqual(byId.ro_filter_replacement, 0);

    const nearbyLight = await apiRequest(`/catalog/technicians/nearby?latitude=${custLat}&longitude=${custLng}&radiusKm=15&serviceId=light_rep`);
    assert.strictEqual(nearbyLight.data.technicians.length, 1);
    assert.strictEqual(nearbyLight.data.technicians[0].technicianId, 'tech_only_light');
  });

  await test('Scenario 11: Technician signs out and reconnects (firestore.rules owner update + presence recovery)', async () => {
    await db.collection('technician_profiles').doc('tech_reconn').set({
      id: 'tech_reconn',
      uid: 'tech_reconn',
      technicianId: 'tech_reconn',
      accountStatus: 'ACTIVE',
      kycStatus: 'VERIFIED',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      latitude: 23.2440,
      longitude: 88.5550,
      lastLocationUpdate: nowIso(),
      skills: [
        { id: 'ac_install', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
      ],
    });

    // Simulate Technician signing out -> owner PATCH sets isOnline=false, availabilityStatus=OFFLINE under firestore.rules
    const signOutRes = await fetch(
      `${FIRESTORE_REST_BASE}/technician_profiles/tech_reconn?updateMask.fieldPaths=isOnline&updateMask.fieldPaths=availabilityStatus&updateMask.fieldPaths=updatedAt`,
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: makeEmulatorJwt('tech_reconn'),
        },
        body: JSON.stringify(
          toFirestoreFields({
            isOnline: false,
            availabilityStatus: 'OFFLINE',
            updatedAt: nowIso(),
          })
        ),
      }
    );
    assert.strictEqual(signOutRes.status, 200);

    // Non-owner technician cannot tamper with tech_reconn's presence (403 under firestore.rules)
    const attackerRes = await fetch(
      `${FIRESTORE_REST_BASE}/technician_profiles/tech_reconn?updateMask.fieldPaths=isOnline`,
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: makeEmulatorJwt('attacker_uid'),
        },
        body: JSON.stringify(toFirestoreFields({ isOnline: true })),
      }
    );
    assert.strictEqual(attackerRes.status, 403);

    // Customer sees 0 while signed out
    let avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 0);

    // Technician reconnects & restores online presence
    const reconnectRes = await fetch(
      `${FIRESTORE_REST_BASE}/technician_profiles/tech_reconn?updateMask.fieldPaths=isOnline&updateMask.fieldPaths=availabilityStatus&updateMask.fieldPaths=latitude&updateMask.fieldPaths=longitude&updateMask.fieldPaths=lastLocationUpdate&updateMask.fieldPaths=updatedAt`,
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: makeEmulatorJwt('tech_reconn'),
        },
        body: JSON.stringify(
          toFirestoreFields({
            isOnline: true,
            availabilityStatus: 'AVAILABLE',
            latitude: 23.2440,
            longitude: 88.5550,
            lastLocationUpdate: nowIso(),
            updatedAt: nowIso(),
          })
        ),
      }
    );
    assert.strictEqual(reconnectRes.status, 200);

    avail = await apiRequest(`/services/ac_install/availability?latitude=${custLat}&longitude=${custLng}&radiusKm=15`);
    assert.strictEqual(avail.data.availableTechnicianCount, 1);
  });

  server.close();
  console.log('\n================================================================');
  console.log(`EMULATOR AVAILABILITY SYNC SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch((err) => {
  console.error('Fatal emulator suite error:', err);
  process.exit(1);
});
