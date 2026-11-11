/**
 * BookurTechnician — Technician Self-Accept Dispatch Architecture Test Suite
 * Validates all 9 critical scenarios mandated by Section 7:
 * 1. Eligible technician receives offer.
 * 2. Wrong-skill technician receives no offer.
 * 3. Offline technician receives no offer.
 * 4. Busy technician receives no offer.
 * 5. First eligible technician successfully accepts.
 * 6. Competing technician receives ALREADY_ASSIGNED.
 * 7. Expired offer is rejected.
 * 8. Duplicate acceptance is idempotent.
 * 9. Client cannot directly assign technicianId.
 */

const assert = require('assert');
const { createBooking } = require('../src/bookingService');
const { acceptBookingOffer, dispatchBookingOffers } = require('../src/dispatchService');
const { resolveCanonicalServiceId, doesTechnicianPossessVerifiedSkill } = require('../src/canonicalServices');

// In-Memory High-Fidelity Firestore Mock for deterministic local execution
class MockFirestore {
  constructor() {
    this.store = new Map(); // "col/docId" -> data
  }

  collection(name) {
    const self = this;
    return {
      doc(id) {
        const docId = id || `doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const fullPath = `${name}/${docId}`;
        return {
          id: docId,
          async get() {
            const data = self.store.get(fullPath);
            return {
              id: docId,
              exists: !!data,
              data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
            };
          },
          async set(data) {
            self.store.set(fullPath, JSON.parse(JSON.stringify(data)));
          },
          async update(updates) {
            const existing = self.store.get(fullPath) || {};
            self.store.set(fullPath, { ...existing, ...JSON.parse(JSON.stringify(updates)) });
          },
          async delete() {
            self.store.delete(fullPath);
          },
        };
      },
      where(field, op, val) {
        return {
          where(f2, op2, v2) {
            return this;
          },
          async get() {
            const docs = [];
            for (const [key, valData] of self.store.entries()) {
              if (key.startsWith(`${name}/`)) {
                let match = false;
                const docVal = valData[field];
                if (op === '==') match = docVal === val;
                else if (op === 'in' && Array.isArray(val)) match = val.includes(docVal);
                if (match) {
                  docs.push({
                    id: key.split('/')[1],
                    data: () => JSON.parse(JSON.stringify(valData)),
                    ref: self.collection(name).doc(key.split('/')[1]),
                  });
                }
              }
            }
            return {
              docs,
              forEach(fn) {
                docs.forEach(fn);
              },
            };
          },
        };
      },
      async get() {
        const docs = [];
        for (const [key, valData] of self.store.entries()) {
          if (key.startsWith(`${name}/`)) {
            docs.push({
              id: key.split('/')[1],
              data: () => JSON.parse(JSON.stringify(valData)),
              ref: self.collection(name).doc(key.split('/')[1]),
            });
          }
        }
        return {
          docs,
          forEach(fn) {
            docs.forEach(fn);
          },
        };
      },
    };
  }

  batch() {
    const ops = [];
    return {
      update(ref, data) {
        ops.push(async () => ref.update(data));
      },
      async commit() {
        for (const op of ops) await op();
      },
    };
  }

  async runTransaction(updateFunction) {
    const transaction = {
      get: async (ref) => ref.get(),
      set: (ref, data) => ref.set(data),
      update: (ref, data) => ref.update(data),
      delete: (ref) => ref.delete(),
    };
    return await updateFunction(transaction);
  }
}

async function runSelfAcceptTests() {
  console.log('================================================================');
  console.log('⚡ RUNNING TECHNICIAN SELF-ACCEPT DISPATCH ARCHITECTURE TESTS');
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
      if (err.stack) console.error(err.stack.split('\n').slice(1, 3).join('\n'));
      failed++;
    }
  }

  const db = new MockFirestore();
  const nowIso = new Date().toISOString();

  // Seed Technician Profiles
  // 1. Eligible AC Technician (Kakali AC)
  await db.collection('technician_profiles').doc('tech_ac_kakali').set({
    id: 'tech_ac_kakali',
    name: 'Kakali Goswami (AC Pro)',
    phone: '+91 9883637055',
    kycStatus: 'VERIFIED',
    accountStatus: 'ACTIVE',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    latitude: 23.2219,
    longitude: 88.5672,
    lastLocationUpdate: nowIso,
    skills: [
      { id: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // 2. Competing Eligible AC Technician (Ram AC)
  await db.collection('technician_profiles').doc('tech_ac_ram').set({
    id: 'tech_ac_ram',
    name: 'Ram Sharma (AC Pro)',
    phone: '+91 9883637056',
    kycStatus: 'VERIFIED',
    accountStatus: 'ACTIVE',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    latitude: 23.2250,
    longitude: 88.5700,
    lastLocationUpdate: nowIso,
    skills: [
      { id: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // 3. Wrong-Skill Technician (Electrical-Only: Light Repair)
  await db.collection('technician_profiles').doc('tech_electrical_only').set({
    id: 'tech_electrical_only',
    name: 'Babu Electrician',
    phone: '+91 9883637057',
    kycStatus: 'VERIFIED',
    accountStatus: 'ACTIVE',
    isOnline: true,
    availabilityStatus: 'AVAILABLE',
    latitude: 23.2219,
    longitude: 88.5672,
    lastLocationUpdate: nowIso,
    skills: [
      { id: 'light_repair', name: 'Light Repair', verificationStatus: 'VERIFIED', enabled: true },
      { id: 'basic_electrician', name: 'Basic Electrician', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // 4. Offline AC Technician
  await db.collection('technician_profiles').doc('tech_ac_offline').set({
    id: 'tech_ac_offline',
    name: 'Suresh Offline',
    phone: '+91 9883637058',
    kycStatus: 'VERIFIED',
    accountStatus: 'ACTIVE',
    isOnline: false,
    availabilityStatus: 'OFFLINE',
    latitude: 23.2219,
    longitude: 88.5672,
    lastLocationUpdate: nowIso,
    skills: [
      { id: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // 5. Busy AC Technician
  await db.collection('technician_profiles').doc('tech_ac_busy').set({
    id: 'tech_ac_busy',
    name: 'Mahesh Busy',
    phone: '+91 9883637059',
    kycStatus: 'VERIFIED',
    accountStatus: 'ACTIVE',
    isOnline: true,
    availabilityStatus: 'BUSY',
    activeBookingId: 'bkg_other_busy_999',
    latitude: 23.2219,
    longitude: 88.5672,
    lastLocationUpdate: nowIso,
    skills: [
      { id: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  });

  // Customer creates AC Booking
  let createdBookingId = '';
  let acBookingResult = null;

  await test('1. Customer booking creation initializes with SEARCHING status and null technicianId', async () => {
    acBookingResult = await createBooking(db, {
      customerId: 'cust_rahul_101',
      customerName: 'Rahul Adhikary',
      customerPhone: '+91 9883637055',
      serviceId: 'ac_install',
      serviceName: 'AC installation',
      categoryId: 'ac_appliances',
      address: { area: 'Birnagar' },
      coordinates: { latitude: 23.2219, longitude: 88.5672 },
      price: 1299,
    });

    createdBookingId = acBookingResult.bookingId;
    assert.strictEqual(acBookingResult.success, true);
    assert.strictEqual(acBookingResult.booking.status, 'SEARCHING');
    assert.strictEqual(acBookingResult.booking.technicianId, null);
    assert.strictEqual(acBookingResult.booking.serviceId, 'ac_install');
  });

  await test('2. Eligible AC technicians receive dispatch offers in dispatch_offers collection', async () => {
    const offerKakali = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_ac_kakali`).get();
    const offerRam = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_ac_ram`).get();

    assert.strictEqual(offerKakali.exists, true, 'Kakali AC must receive offer');
    assert.strictEqual(offerRam.exists, true, 'Ram AC must receive offer');
    assert.strictEqual(offerKakali.data().status, 'SENT');
    assert.strictEqual(offerKakali.data().serviceId, 'ac_install');
  });

  await test('3. Wrong-skill technician (Electrical-only) receives NO offer for AC Installation', async () => {
    const offerElectrical = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_electrical_only`).get();
    assert.strictEqual(offerElectrical.exists, false, 'Electrical technician must NOT receive AC offer');
  });

  await test('4. Offline technician receives NO offer', async () => {
    const offerOffline = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_ac_offline`).get();
    assert.strictEqual(offerOffline.exists, false, 'Offline technician must NOT receive offer');
  });

  await test('5. Busy technician receives NO offer', async () => {
    const offerBusy = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_ac_busy`).get();
    assert.strictEqual(offerBusy.exists, false, 'Busy technician must NOT receive offer');
  });

  await test('6. First eligible technician (Kakali) successfully accepts offer atomically', async () => {
    const acceptRes = await acceptBookingOffer(db, {
      offerId: `offer_${createdBookingId}_tech_ac_kakali`,
      callerUid: 'tech_ac_kakali',
      callerName: 'Kakali Goswami (AC Pro)',
      callerPhone: '+91 9883637055',
    });

    assert.strictEqual(acceptRes.success, true);
    assert.strictEqual(acceptRes.assignment.status, 'ASSIGNED');
    assert.strictEqual(acceptRes.assignment.technicianId, 'tech_ac_kakali');

    // Verify booking in DB is updated
    const bookingDoc = await db.collection('bookings').doc(createdBookingId).get();
    assert.strictEqual(bookingDoc.data().status, 'ASSIGNED');
    assert.strictEqual(bookingDoc.data().technicianId, 'tech_ac_kakali');

    // Verify winning offer is ACCEPTED
    const winningOffer = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_ac_kakali`).get();
    assert.strictEqual(winningOffer.data().status, 'ACCEPTED');

    // Verify winning technician availability is set to BUSY
    const techDoc = await db.collection('technician_profiles').doc('tech_ac_kakali').get();
    assert.strictEqual(techDoc.data().availabilityStatus, 'BUSY');
    assert.strictEqual(techDoc.data().activeBookingId, createdBookingId);
  });

  await test('7. Competing technician (Ram) receives 409 ALREADY_ASSIGNED on race condition', async () => {
    let thrownError = null;
    try {
      await acceptBookingOffer(db, {
        offerId: `offer_${createdBookingId}_tech_ac_ram`,
        callerUid: 'tech_ac_ram',
        callerName: 'Ram Sharma (AC Pro)',
        callerPhone: '+91 9883637056',
      });
    } catch (err) {
      thrownError = err;
    }

    assert.ok(thrownError, 'Competing acceptance must throw an error');
    assert.strictEqual(thrownError.status, 409);
    assert.strictEqual(thrownError.code, 'ALREADY_ASSIGNED');

    // Verify competing offer is marked CANCELLED_CLAIMED_BY_ANOTHER
    const compOffer = await db.collection('dispatch_offers').doc(`offer_${createdBookingId}_tech_ac_ram`).get();
    assert.strictEqual(compOffer.data().status, 'CANCELLED_CLAIMED_BY_ANOTHER');
  });

  await test('8. Duplicate acceptance by winning technician (Kakali) is idempotent (200 OK)', async () => {
    const retryRes = await acceptBookingOffer(db, {
      offerId: `offer_${createdBookingId}_tech_ac_kakali`,
      callerUid: 'tech_ac_kakali',
      callerName: 'Kakali Goswami (AC Pro)',
    });

    assert.strictEqual(retryRes.success, true);
    assert.strictEqual(retryRes.assignment.technicianId, 'tech_ac_kakali');
    assert.strictEqual(retryRes.assignment.status, 'ASSIGNED');
  });

  await test('9. Expired offer is rejected with 410 OFFER_EXPIRED', async () => {
    // Seed an expired offer
    const expiredBookingId = 'bkg_expired_test_01';
    await db.collection('bookings').doc(expiredBookingId).set({
      id: expiredBookingId,
      status: 'SEARCHING',
      serviceId: 'ac_install',
      price: 1299,
    });
    const expOfferId = `offer_${expiredBookingId}_tech_ac_kakali`;
    await db.collection('dispatch_offers').doc(expOfferId).set({
      id: expOfferId,
      offerId: expOfferId,
      bookingId: expiredBookingId,
      technicianId: 'tech_ac_kakali',
      targetTechnicianUid: 'tech_ac_kakali',
      serviceId: 'ac_install',
      status: 'SENT',
      expiresAt: new Date(Date.now() - 60000).toISOString(), // 1 minute in the past
    });

    let expiredErr = null;
    try {
      await acceptBookingOffer(db, {
        offerId: expOfferId,
        callerUid: 'tech_ac_kakali',
      });
    } catch (err) {
      expiredErr = err;
    }

    assert.ok(expiredErr, 'Expired offer must throw 410');
    assert.strictEqual(expiredErr.status, 410);
    assert.strictEqual(expiredErr.code, 'OFFER_EXPIRED');

    // Verify offer status was updated to EXPIRED in Firestore
    const expDoc = await db.collection('dispatch_offers').doc(expOfferId).get();
    assert.strictEqual(expDoc.data().status, 'EXPIRED');
  });

  await test('10. Client cannot directly assign technicianId (Validation & Rules Boundary)', async () => {
    // Attempting to pass technicianId directly to createBooking is stripped by server-authoritative logic
    const rogueBooking = await createBooking(db, {
      customerId: 'cust_attacker_99',
      serviceId: 'ac_install',
      technicianId: 'tech_attacker_chosen', // client attempts to self-assign
      status: 'CONFIRMED',                  // client attempts to bypass SEARCHING
      price: 999,
    });

    // Server-Authoritative invariant: technicianId is ignored and forced to null, status forced to SEARCHING
    assert.strictEqual(rogueBooking.booking.technicianId, null, 'Client-supplied technicianId must be ignored');
    assert.strictEqual(rogueBooking.booking.status, 'SEARCHING', 'Client-supplied status must be forced to SEARCHING');
  });

  console.log('\n================================================================');
  console.log(`📊 ARCHITECTURE TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');

  if (failed > 0) process.exit(1);
}

runSelfAcceptTests().catch((err) => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});

