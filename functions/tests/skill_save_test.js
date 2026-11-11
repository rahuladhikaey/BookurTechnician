/**
 * BookurTechnician — Technician Skill Save & Verification Test Suite
 * Validates all 7 critical scenarios:
 * 1. Single skill selection & save -> reload -> skill persists
 * 2. Multiple skills across categories -> save -> reload -> all persist
 * 3. Skill removal/deselection -> save -> reload -> removed skill is gone
 * 4. Sign out / sign in simulation -> skills load from Firestore (not local cache)
 * 5. Unauthorized write attempt -> cannot edit another technician's skills
 * 6. Unverified skill state -> does not qualify for dispatch
 * 7. Canonical mapping match -> customer booking service matches technician skill
 */

const assert = require('assert');
const { fetchTechnicianSkills, saveTechnicianSkills, toggleTechnicianSkill } = require('../src/skillService');
const { resolveCanonicalServiceId, doesTechnicianPossessVerifiedSkill } = require('../src/canonicalServices');
const { createBooking } = require('../src/bookingService');
const { dispatchBookingOffers } = require('../src/dispatchService');

// In-Memory High-Fidelity Firestore Mock
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
      set(ref, data) {
        ops.push(async () => ref.set(data));
      },
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
    };
    return await updateFunction(transaction);
  }
}

async function runTests() {
  console.log('🧪 Starting Technician Skill Save & Verification Test Suite...\n');
  const db = new MockFirestore();
  let passed = 0;
  let total = 0;

  async function test(name, fn) {
    total++;
    process.stdout.write(`  [Test ${total}] ${name}... `);
    try {
      await fn();
      console.log('✅ PASSED');
      passed++;
    } catch (err) {
      console.log('❌ FAILED');
      console.error('    Error:', err.message);
      if (err.stack) console.error(err.stack);
    }
  }

  // TEST 1: Single skill selection & save -> reload -> skill persists
  await test('Single skill selection & save -> reload -> skill persists', async () => {
    const techId = 'uid_tech_single_01';
    await db.collection('technician_profiles').doc(techId).set({
      id: techId,
      fullName: 'Rahul Sharma',
      phone: '+919876543210',
      walletBalance: 500,
      rating: 4.8,
      kycStatus: 'VERIFIED',
    });

    const saveRes = await saveTechnicianSkills(db, {
      callerUid: techId,
      skills: [
        {
          id: 'sk_ac_installation',
          name: 'AC Installation',
          experienceYears: 3,
        },
      ],
    });

    assert.strictEqual(saveRes.success, true);
    assert.strictEqual(saveRes.totalSkillsCount, 1);
    assert.strictEqual(saveRes.skills[0].id, 'ac_install');
    assert.strictEqual(saveRes.skills[0].verificationStatus, 'VERIFIED');
    assert.strictEqual(saveRes.skills[0].enabled, true);

    // Reload from Firestore
    const reloaded = await fetchTechnicianSkills(db, { callerUid: techId });
    assert.strictEqual(reloaded.success, true);
    assert.strictEqual(reloaded.totalSkillsCount, 1);
    assert.strictEqual(reloaded.skills[0].id, 'ac_install');
    assert.strictEqual(reloaded.skills[0].canonicalServiceId, 'ac_install');
    assert.strictEqual(reloaded.skills[0].experienceYears, 3);
  });

  // TEST 2: Multiple skills across categories -> save -> reload -> all persist
  await test('Multiple skills across categories -> save -> reload -> all persist', async () => {
    const techId = 'uid_tech_multi_02';
    await db.collection('technician_profiles').doc(techId).set({
      id: techId,
      fullName: 'Amit Roy',
      phone: '+919876543211',
      kycStatus: 'VERIFIED',
    });

    const multiSkills = [
      { id: 'sk_ac_installation', name: 'AC Installation', experienceYears: 4 },
      { id: 'sk_ceiling_fan_installation', name: 'Ceiling Fan Installation', experienceYears: 5 },
      { id: 'sk_led_installation_repair', name: 'LED Light Installation', experienceYears: 2 },
    ];

    const saveRes = await saveTechnicianSkills(db, {
      callerUid: techId,
      skills: multiSkills,
    });

    assert.strictEqual(saveRes.success, true);
    assert.strictEqual(saveRes.totalSkillsCount, 3);
    assert.strictEqual(saveRes.verifiedSkillsCount, 3);

    // Verify categories
    assert(saveRes.categories.includes('AC Services'));
    assert(saveRes.categories.includes('Electrical Services'));

    // Reload
    const reloaded = await fetchTechnicianSkills(db, { callerUid: techId });
    assert.strictEqual(reloaded.skills.length, 3);
    const skillIds = reloaded.skills.map((s) => s.id);
    assert(skillIds.includes('ac_install'));
    assert(skillIds.includes('fan_ceiling_install'));
    assert(skillIds.includes('led_install'));
  });

  // TEST 3: Skill removal/deselection -> save -> reload -> removed skill is gone
  await test('Skill removal/deselection -> save -> reload -> removed skill is gone', async () => {
    const techId = 'uid_tech_multi_02';

    // Deselect ceiling fan, keep AC installation and LED
    const updatedSelection = [
      { id: 'sk_ac_installation', name: 'AC Installation', experienceYears: 4 },
      { id: 'sk_led_installation_repair', name: 'LED Light Installation', experienceYears: 2 },
    ];

    const saveRes = await saveTechnicianSkills(db, {
      callerUid: techId,
      skills: updatedSelection,
    });

    assert.strictEqual(saveRes.totalSkillsCount, 2);

    // Reload and assert ceiling fan installation is gone
    const reloaded = await fetchTechnicianSkills(db, { callerUid: techId });
    assert.strictEqual(reloaded.skills.length, 2);
    const skillIds = reloaded.skills.map((s) => s.id);
    assert(skillIds.includes('ac_install'));
    assert(skillIds.includes('led_install'));
    assert(!skillIds.includes('fan_ceiling_install'), 'Removed skill must NOT be present in reloaded profile');
  });

  // TEST 4: Sign out / sign in simulation -> skills load from Firestore (not local cache)
  await test('Sign out / sign in simulation -> skills load from Firestore (not local cache)', async () => {
    const techId = 'uid_tech_multi_02';

    // Simulate brand new clean session reading purely from Cloud Firestore
    const freshSessionFetch = await fetchTechnicianSkills(db, {
      callerUid: techId,
      targetTechId: techId,
      isAdmin: false,
    });

    assert.strictEqual(freshSessionFetch.success, true);
    assert.strictEqual(freshSessionFetch.technicianId, techId);
    assert.strictEqual(freshSessionFetch.skills.length, 2);
    assert.strictEqual(freshSessionFetch.verifiedSkillsCount, 2);

    // Verify Firestore doc directly
    const directDoc = await db.collection('technician_profiles').doc(techId).get();
    assert.strictEqual(directDoc.exists, true);
    const data = directDoc.data();
    assert.strictEqual(data.skills.length, 2);
    assert.strictEqual(data.selectedSkills.length, 2);
    assert(data.updatedAt, 'updatedAt timestamp must exist');
  });

  // TEST 5: Unauthorized write attempt -> cannot edit another technician\'s skills
  await test('Unauthorized write attempt -> cannot edit another technician\'s skills', async () => {
    const victimTechId = 'uid_tech_victim';
    const attackerTechId = 'uid_tech_attacker';

    await db.collection('technician_profiles').doc(victimTechId).set({
      id: victimTechId,
      fullName: 'Victim Technician',
      skills: [{ id: 'ac_install', name: 'AC Installation', verificationStatus: 'VERIFIED', enabled: true }],
    });

    let forbiddenCaught = false;
    try {
      await saveTechnicianSkills(db, {
        callerUid: attackerTechId,
        targetTechId: victimTechId,
        skills: [{ id: 'fan_ceiling_install', name: 'Fan Install' }],
        isAdmin: false,
      });
    } catch (err) {
      if (err.status === 403 && err.code === 'FORBIDDEN') {
        forbiddenCaught = true;
      }
    }

    assert.strictEqual(forbiddenCaught, true, 'Unauthorized edit of another technician profile must be rejected with 403 FORBIDDEN');

    // Verify victim skills remain untouched
    const victimDoc = await db.collection('technician_profiles').doc(victimTechId).get();
    assert.strictEqual(victimDoc.data().skills[0].id, 'ac_install');
  });

  // TEST 6: Unverified skill state -> does not qualify for dispatch
  await test('Unverified skill state -> does not qualify for dispatch', async () => {
    const unverifiedTech = {
      id: 'uid_tech_unverified',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      kycStatus: 'VERIFIED',
      skills: [
        {
          id: 'ac_install',
          canonicalServiceId: 'ac_install',
          name: 'AC Installation',
          verificationStatus: 'PENDING', // NOT verified!
          enabled: true,
        },
      ],
    };

    // Verification check directly
    const hasSkill = doesTechnicianPossessVerifiedSkill(unverifiedTech, 'ac_install', 'AC Installation');
    assert.strictEqual(hasSkill, false, 'PENDING unverified skill must NOT qualify for dispatch');

    // Disabled skill check
    const disabledTech = {
      id: 'uid_tech_disabled',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      kycStatus: 'VERIFIED',
      skills: [
        {
          id: 'ac_install',
          canonicalServiceId: 'ac_install',
          name: 'AC Installation',
          verificationStatus: 'VERIFIED',
          enabled: false, // Disabled!
        },
      ],
    };
    const hasDisabledSkill = doesTechnicianPossessVerifiedSkill(disabledTech, 'ac_install', 'AC Installation');
    assert.strictEqual(hasDisabledSkill, false, 'Disabled skill must NOT qualify for dispatch');
  });

  // TEST 7: Canonical mapping match -> customer booking service matches technician skill
  await test('Canonical mapping match -> customer booking service matches technician skill', async () => {
    const verifiedTechId = 'uid_tech_verified_match';
    await db.collection('technician_profiles').doc(verifiedTechId).set({
      id: verifiedTechId,
      name: 'Expert AC Tech',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      kycStatus: 'VERIFIED',
      latitude: 22.5726,
      longitude: 88.3639,
      lastLocationUpdate: new Date().toISOString(),
      skills: [
        {
          id: 'ac_install',
          canonicalServiceId: 'ac_install',
          name: 'AC Installation',
          verificationStatus: 'VERIFIED',
          enabled: true,
        },
      ],
    });

    // Customer creates booking using alias/catalog name "sk_ac_installation"
    const bookingResult = await createBooking(db, {
      customerId: 'cust_99',
      customerName: 'Priya Mukherjee',
      customerPhone: '+919876543299',
      serviceId: 'sk_ac_installation', // Catalog ID
      serviceName: 'AC Installation',
      coordinates: { latitude: 22.5730, longitude: 88.3645 },
      price: 899,
    });

    assert.strictEqual(bookingResult.success, true);
    assert.strictEqual(bookingResult.booking.serviceId, 'ac_install', 'Customer booking service must resolve to canonical ID ac_install');

    // Verify offer created for verifiedTechId
    const offerDoc = await db.collection('dispatch_offers').doc(`offer_${bookingResult.bookingId}_${verifiedTechId}`).get();
    assert.strictEqual(offerDoc.exists, true, 'Eligible technician with canonical skill must receive dispatch offer');
    assert.strictEqual(offerDoc.data().technicianId, verifiedTechId);
    assert.strictEqual(offerDoc.data().serviceId, 'ac_install');
    assert.strictEqual(offerDoc.data().status, 'SENT');
  });

  console.log(`\n📊 Results: ${passed}/${total} tests passed.\n`);
  if (passed !== total) {
    process.exit(1);
  }
}

runTests().catch((e) => {
  console.error('Test Suite Fatal Error:', e);
  process.exit(1);
});
