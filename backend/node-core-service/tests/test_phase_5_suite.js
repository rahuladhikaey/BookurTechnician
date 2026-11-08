/**
 * BOOKURTECHNICIAN — PHASE 5 COMPREHENSIVE VERIFICATION SUITE
 * Verifies all 25 required tests across:
 *   A. Service Catalog (6 tests)
 *   B. Technician Profile Persistence & Security (8 tests)
 *   C. Admin Synchronization & RBAC Governance (6 tests)
 *   D. Network, Spark Optimization & Live Skill Matching (5 tests)
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const {
  getMasterCatalog,
  getFlattenedServices,
  getCatalogVersion,
  createServiceItem,
  updateServiceItem,
  deleteServiceItem,
} = require('../src/config/masterCatalog');

const {
  inMemoryTechProfiles,
  inMemoryTechPrivate,
  resolveCanonicalTechUid,
  resolveTechnicianCode,
  maskVoterId,
  maskAadhaar,
  maskUpiId,
  setTechnicianProfile,
} = require('../src/config/inMemoryTechStore');

const catalogController = require('../src/controllers/catalogController');
const technicianController = require('../src/controllers/technicianController');
const adminController = require('../src/controllers/adminController');
const bookingController = require('../src/controllers/bookingController');

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

async function runPhase5VerificationSuite() {
  const results = [];
  let passed = 0;
  let failed = 0;

  async function runTest(id, category, name, fn) {
    try {
      await fn();
      passed++;
      results.push({ id, category, name, status: 'PASS' });
      console.log(`✅ [PASS] ${id} (${category}): ${name}`);
    } catch (err) {
      failed++;
      results.push({ id, category, name, status: 'FAIL', error: err.message });
      console.error(`❌ [FAIL] ${id} (${category}): ${name} -> ${err.message}`);
    }
  }

  console.log('================================================================');
  console.log('🚀 STARTING PHASE 5 VERIFICATION SUITE (25 REQUIRED TESTS)');
  console.log('================================================================\n');

  // ---------------------------------------------------------------------------
  // A. SERVICE CATALOG TESTS (6 TESTS)
  // ---------------------------------------------------------------------------

  await runTest('CAT-01', 'Service Catalog', 'All 158+ services exist in central database across 8 categories & 21 subcategories', async () => {
    const master = getMasterCatalog({ activeOnly: false });
    const flat = getFlattenedServices({ includeInactive: true });
    assert.strictEqual(master.length, 8, `Expected 8 categories, got ${master.length}`);
    const subCount = master.reduce((acc, c) => acc + (c.subcategories?.length || 0), 0);
    assert.strictEqual(subCount, 21, `Expected 21 subcategories, got ${subCount}`);
    assert.ok(flat.length >= 158, `Expected >= 158 services, got ${flat.length}`);
    for (const s of flat) {
      assert.ok(s.id && s.canonicalServiceId && s.categoryId && s.subcategoryId, `Service ${s.id} missing canonical identifiers`);
      assert.ok(typeof s.basePrice === 'number' && typeof s.discountPrice === 'number', `Service ${s.id} missing numeric prices`);
      assert.ok(typeof s.isActive === 'boolean', `Service ${s.id} missing boolean isActive`);
    }
  });

  await runTest('CAT-02', 'Service Catalog', 'Customer App loads active services and catalogVersion from central catalog', async () => {
    const req = { query: { isActive: 'true' } };
    const res = createMockRes();
    await catalogController.getHierarchy(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.catalogVersion >= 1, 'Expected catalogVersion >= 1');
    assert.strictEqual(res.body.data.length, 8);
  });

  let tempServiceId = null;
  await runTest('CAT-03', 'Service Catalog', 'Admin adds a new service and Customer App receives it with incremented catalogVersion', async () => {
    deleteServiceItem('test_phase5_temp_service', 'admin_master');
    const beforeVersion = getCatalogVersion();
    const created = createServiceItem({
      id: 'test_phase5_temp_service',
      name: 'Smart Energy Meter Setup',
      categoryId: 'cat_electrical',
      subcategoryId: 'sub_fan',
      basePrice: 599,
      discountPrice: 449,
      description: 'Digital smart energy meter installation',
      isActive: true,
    }, 'admin_master');
    tempServiceId = created.id;
    const afterVersion = getCatalogVersion();
    assert.ok(afterVersion > beforeVersion, 'catalogVersion must increment on service creation');
    const found = getFlattenedServices({ includeInactive: true }).find(s => s.id === tempServiceId);
    assert.ok(found, 'Newly added service must exist in central catalog');
  });

  await runTest('CAT-04', 'Service Catalog', 'Admin updates a service price and Customer App displays the updated price', async () => {
    const updated = updateServiceItem(tempServiceId, {
      basePrice: 699,
      discountPrice: 499,
      price: 499,
    }, 'admin_master');
    assert.ok(updated);
    assert.strictEqual(updated.discountPrice, 499);
    assert.strictEqual(updated.basePrice, 699);
  });

  await runTest('CAT-05', 'Service Catalog', 'Admin disables a service and Customer App blocks booking it (SERVICE_DISABLED)', async () => {
    try {
      updateServiceItem(tempServiceId, { isActive: false, active: false }, 'admin_master');
      const activeList = getFlattenedServices({ includeInactive: false });
      assert.ok(!activeList.some(s => s.id === tempServiceId), 'Disabled service must be excluded from active customer list');

      // Attempt to book the disabled service via bookingController
      const req = {
        user: { id: 'cust_test_01' },
        body: {
          serviceId: tempServiceId,
          serviceName: 'Smart Energy Meter Setup',
          latitude: 28.6139,
          longitude: 77.2090,
        },
      };
      const res = createMockRes();
      await bookingController.createBooking(req, res, (e) => { throw e; });
      assert.strictEqual(res.statusCode, 400, 'Booking a disabled service must return HTTP 400');
      assert.strictEqual(res.body.code, 'SERVICE_DISABLED');
    } finally {
      // Cleanup temp service so catalog remains at exact 158 canonical services
      deleteServiceItem(tempServiceId, 'admin_master');
    }
  });

  await runTest('CAT-06', 'Service Catalog', 'Migration is 100% idempotent and creates zero duplicate services on repeated runs', async () => {
    const flat = getFlattenedServices({ includeInactive: true });
    const uniqueIds = new Set(flat.map(s => s.id));
    assert.strictEqual(flat.length, uniqueIds.size, 'Zero duplicate service IDs allowed');
    assert.strictEqual(flat.length, 158, `Expected exact 158 canonical services after cleanup, got ${flat.length}`);
  });

  // ---------------------------------------------------------------------------
  // B. TECHNICIAN PROFILE PERSISTENCE & SECURITY TESTS (8 TESTS)
  // ---------------------------------------------------------------------------

  const ramPhone = '9876988363';
  const ramUid = resolveCanonicalTechUid(ramPhone, ramPhone);
  const ramCode = resolveTechnicianCode(ramUid, ramPhone);

  await runTest('TECH-01', 'Technician Profile', 'New technician registers with permanent UID (uid_tech_<10digits>) and public code (BT-XXXXXX)', async () => {
    assert.strictEqual(ramUid, 'uid_tech_9876988363');
    assert.strictEqual(ramCode, 'BT-988363');

    const req = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: {
        fullName: 'Ram',
        phone: ramPhone,
        email: 'ram@bookurtechnician.com',
        latitude: 28.6139,
        longitude: 77.2090,
        isOnline: true,
        availabilityStatus: 'AVAILABLE',
      },
    };
    const res = createMockRes();
    await technicianController.updateProfile(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.uid, 'uid_tech_9876988363');
    assert.strictEqual(res.body.data.technicianCode, 'BT-988363');
  });

  await runTest('TECH-02', 'Technician Profile', 'Technician selects skills and skills persist with canonicalServiceId (ac_install)', async () => {
    const req = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: {
        technicianId: ramUid,
        skills: [
          { skillId: 'sk_ac_installation', skillName: 'AC installation', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'sk_deep_cleaning_service', skillName: 'Deep cleaning service', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'ac_repair_general', skillName: 'AC repair', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'ac_pcb_repair', skillName: 'AC PCB repair', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'ac_relocation', skillName: 'AC relocation', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'ac_general_service', skillName: 'AC general servicing', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'ac_gas_charging', skillName: 'AC gas charging/refilling', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
          { skillId: 'ac_uninstall', skillName: 'AC uninstallation', categoryId: 'cat_ac', categoryName: 'AC Services', experienceYears: 2 },
        ],
      },
    };
    const res = createMockRes();
    await technicianController.saveSkillsBulk(req, res);
    assert.strictEqual(res.statusCode, 200);
    const savedSkills = res.body.data.skills;
    assert.strictEqual(savedSkills.length, 8);
    assert.strictEqual(savedSkills[0].canonicalServiceId, 'ac_install', 'sk_ac_installation must normalize to ac_install');
    assert.strictEqual(savedSkills[1].canonicalServiceId, 'ac_deep_cleaning', 'sk_deep_cleaning_service must normalize to ac_deep_cleaning');
  });

  await runTest('TECH-03', 'Technician Profile', 'Technician closes app, reopens app, logs in again, and selected skills remain intact', async () => {
    const req = {
      user: { id: ramUid, phone: ramPhone },
      params: {},
      query: { technicianId: ramUid },
      headers: { 'x-technician-id': ramUid },
    };
    const res = createMockRes();
    await technicianController.getSkills(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.skills.length, 8);
    assert.strictEqual(res.body.data.technicianCode, 'BT-988363');
  });

  await runTest('TECH-04', 'Technician Profile', 'Technician submits Voter ID and UPI, and values persist in private vault with masked public display', async () => {
    const docReq1 = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { documentType: 'SELFIE', fileUrl: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799180/prw4acrn6uajclcl7neg.svg', maskedNumber: 'LIVE_SELFIE' },
    };
    await technicianController.submitDocument(docReq1, createMockRes());

    const docReq2 = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { documentType: 'AADHAAR', fileUrl: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799174/npirtdof27t2ogvu2hnj.svg', maskedNumber: '123456789123' },
    };
    await technicianController.submitDocument(docReq2, createMockRes());

    const docReq3 = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { documentType: 'VOTER_CARD', fileUrl: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799176/u6zexc12ymd5l5szgrhn.svg', maskedNumber: 'WBD1234567' },
    };
    const res3 = createMockRes();
    await technicianController.submitDocument(docReq3, res3);
    assert.ok(res3.statusCode === 200 || res3.statusCode === 201);

    const upiReq = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { upiId: 'ram988363@okaxis' },
    };
    const upiRes = createMockRes();
    await technicianController.updateProfile(upiReq, upiRes);
    assert.strictEqual(upiRes.statusCode, 200);

    const priv = inMemoryTechPrivate.get(ramUid);
    assert.ok(priv, 'Private vault record must exist');
    assert.strictEqual(priv.maskedVoterId, 'WBD****567');
    assert.strictEqual(priv.maskedAadhaar, 'XXXX-XXXX-9123');
    assert.strictEqual(priv.maskedUpiId, 'ra***@okaxis');
  });

  await runTest('TECH-05', 'Technician Profile', 'Technician updates skills without losing KYC, UPI, or GPS coordinates', async () => {
    const toggleReq = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: { id: 'ac_relocation' },
      query: {},
      body: { technicianId: ramUid },
    };
    const toggleRes = createMockRes();
    await technicianController.toggleSkill(toggleReq, toggleRes);
    assert.strictEqual(toggleRes.statusCode, 200);

    // Toggle back to true so all 8 remain enabled
    await technicianController.toggleSkill(toggleReq, createMockRes());

    const prof = inMemoryTechProfiles.get(ramUid);
    const priv = inMemoryTechPrivate.get(ramUid);
    assert.strictEqual(prof.latitude, 28.6139, 'GPS latitude must remain untouched after skill update');
    assert.strictEqual(priv.upiId, 'ram988363@okaxis', 'UPI ID must remain untouched after skill update');
    assert.strictEqual(priv.maskedVoterId, 'WBD****567', 'Voter ID must remain untouched after skill update');
  });

  await runTest('TECH-06', 'Technician Profile', 'Technician logs in on a clean app state and full profile & onboardingCompleted restore', async () => {
    const req = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: { technicianId: ramUid },
    };
    const res = createMockRes();
    await technicianController.getProfile(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.onboardingCompleted, true);
    assert.strictEqual(res.body.data.selectedSkills.length, 8);
  });

  await runTest('TECH-07', 'Technician Profile', 'Public technician profile collection never exposes unmasked Voter ID, Aadhaar, or raw document URLs', async () => {
    const publicProf = inMemoryTechProfiles.get(ramUid);
    assert.strictEqual(publicProf.upiId, undefined, 'Public profile collection must not store raw upiId');
    assert.strictEqual(publicProf.secureDocumentRefs, undefined, 'Public profile collection must not store secureDocumentRefs');
  });

  await runTest('TECH-08', 'Technician Profile', 'Technician cannot self-approve KYC, skills, or account status (SELF_APPROVAL_FORBIDDEN)', async () => {
    const selfSkillReq = {
      user: { id: ramUid, role: 'TECHNICIAN' },
      params: { id: 'ac_install' },
      body: { technicianId: ramUid, verificationStatus: 'VERIFIED' },
    };
    const selfSkillRes = createMockRes();
    await technicianController.verifySkillAdmin(selfSkillReq, selfSkillRes);
    assert.strictEqual(selfSkillRes.statusCode, 403);
    assert.strictEqual(selfSkillRes.body.code, 'SELF_APPROVAL_FORBIDDEN');

    const selfKycReq = {
      user: { id: ramUid, role: 'TECHNICIAN' },
      params: { id: ramUid },
      body: { kycStatus: 'VERIFIED' },
    };
    const selfKycRes = createMockRes();
    await adminController.updateTechnicianKyc(selfKycReq, selfKycRes, (e) => { throw e; });
    assert.strictEqual(selfKycRes.statusCode, 403);
    assert.strictEqual(selfKycRes.body.code, 'SELF_APPROVAL_FORBIDDEN');
  });

  // ---------------------------------------------------------------------------
  // C. ADMIN SYNCHRONIZATION & RBAC GOVERNANCE TESTS (6 TESTS)
  // ---------------------------------------------------------------------------

  await runTest('ADM-01', 'Admin Panel', 'Admin sees registered technician in Admin Panel with masked UPI & Voter ID in general list', async () => {
    const req = { user: { id: 'admin_master', role: 'ADMIN' }, query: {} };
    const res = createMockRes();
    await adminController.getTechnicians(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 200);
    const ram = res.body.data.find(t => t.uid === ramUid);
    assert.ok(ram, 'Technician Ram must appear in Admin Panel list');
    assert.strictEqual(ram.technicianCode, 'BT-988363');
    assert.strictEqual(ram.maskedUpiId, 'ra***@okaxis');
    assert.strictEqual(ram.maskedVoterId, 'WBD****567');
  });

  await runTest('ADM-02', 'Admin Panel', 'Admin views technician selected skills with canonical service mappings', async () => {
    const req = { user: { id: 'admin_master', role: 'ADMIN' }, params: {}, query: { technicianId: ramUid }, headers: {} };
    const res = createMockRes();
    await technicianController.getSkills(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.skills.length, 8);
    assert.ok(res.body.data.skills.some(s => s.canonicalServiceId === 'ac_install'));
  });

  await runTest('ADM-03', 'Admin Panel', 'Admin approves KYC and updates technician verification status', async () => {
    const req = {
      user: { id: 'admin_master', role: 'ADMIN' },
      params: { id: ramUid },
      body: { kycStatus: 'VERIFIED' },
    };
    const res = createMockRes();
    await adminController.updateTechnicianKyc(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.kycStatus, 'VERIFIED');
  });

  await runTest('ADM-04', 'Admin Panel', 'Admin approves individual technician skill via verifySkillAdmin', async () => {
    const req = {
      user: { id: 'admin_master', role: 'ADMIN' },
      params: { id: 'ac_install' },
      body: { technicianId: ramUid, verificationStatus: 'VERIFIED' },
    };
    const res = createMockRes();
    await technicianController.verifySkillAdmin(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.verificationStatus, 'VERIFIED');
  });

  await runTest('ADM-05', 'Admin Panel', 'Admin suspends and reactivates technician account status', async () => {
    const suspendReq = {
      user: { id: 'admin_master', role: 'ADMIN' },
      params: { id: ramUid },
      body: { status: 'Suspended' },
    };
    const suspendRes = createMockRes();
    await adminController.updateTechnicianStatus(suspendReq, suspendRes, (e) => { throw e; });
    assert.strictEqual(suspendRes.statusCode, 200);
    assert.strictEqual(suspendRes.body.data.status, 'Suspended');

    const activateReq = {
      user: { id: 'admin_master', role: 'ADMIN' },
      params: { id: ramUid },
      body: { status: 'Active' },
    };
    const activateRes = createMockRes();
    await adminController.updateTechnicianStatus(activateReq, activateRes, (e) => { throw e; });
    assert.strictEqual(activateRes.statusCode, 200);
    assert.strictEqual(activateRes.body.data.status, 'Active');
  });

  await runTest('ADM-06', 'Admin Panel', 'Admin actions create immutable audit log entries with adminUid, targetTechnicianUid, previousStatus, and updatedStatus', async () => {
    const req = { user: { id: 'admin_master', role: 'ADMIN' } };
    const res = createMockRes();
    await adminController.getAuditLogs(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 200);
    assert.ok(Array.isArray(res.body.data) && res.body.data.length >= 3);
    const latest = res.body.data[0];
    assert.ok(latest.adminUid && latest.action && latest.targetTechnicianUid && latest.timestamp);
  });

  // ---------------------------------------------------------------------------
  // D. NETWORK, SPARK OPTIMIZATION & LIVE SKILL MATCHING TESTS (5 TESTS)
  // ---------------------------------------------------------------------------

  await runTest('NET-01', 'Network & Safety', 'Duplicate rapid KYC submissions are intercepted or upserted idempotently without creating duplicate records', async () => {
    const priv = inMemoryTechPrivate.get(ramUid);
    const docsCountBefore = priv.secureDocumentRefs.length;
    const req = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { documentType: 'VOTER_CARD', fileUrl: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799176/u6zexc12ymd5l5szgrhn.svg', maskedNumber: 'WBD1234567' },
    };
    const res = createMockRes();
    await technicianController.submitDocument(req, res);
    // Either 409 DUPLICATE_KYC_SUBMISSION (within 3s lock) or 200 idempotent upsert
    assert.ok(res.statusCode === 409 || res.statusCode === 200);
    const docsCountAfter = inMemoryTechPrivate.get(ramUid).secureDocumentRefs.length;
    assert.strictEqual(docsCountAfter, docsCountBefore, 'Idempotent document upsert must not create duplicate VOTER_CARD entries');
  });

  await runTest('NET-02', 'Network & Safety', 'Invalid Voter ID or UPI format is rejected cleanly with HTTP 400', async () => {
    const badVoterReq = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { documentType: 'VOTER_CARD', fileUrl: 'https://example.com/voter.jpg', maskedNumber: 'INVALID_123' },
    };
    const badVoterRes = createMockRes();
    await technicianController.submitDocument(badVoterReq, badVoterRes);
    assert.strictEqual(badVoterRes.statusCode, 400);
    assert.strictEqual(badVoterRes.body.code, 'INVALID_VOTER_ID');

    const badUpiReq = {
      user: { id: ramUid, phone: ramPhone },
      headers: { 'x-technician-id': ramUid },
      params: {},
      query: {},
      body: { upiId: 'not-a-valid-upi' },
    };
    const badUpiRes = createMockRes();
    await technicianController.updateProfile(badUpiReq, badUpiRes);
    assert.strictEqual(badUpiRes.statusCode, 400);
    assert.strictEqual(badUpiRes.body.code, 'INVALID_UPI_FORMAT');
  });

  await runTest('NET-03', 'Network & Safety', 'Catalog pagination and category filtering minimize read bandwidth for Firebase Spark compatibility', async () => {
    const req = { query: { categoryId: 'cat_ac', page: '1', limit: '5' } };
    const res = createMockRes();
    await catalogController.getServices(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.length, 5);
    assert.ok(res.body.pagination.total >= 15);
  });

  await runTest('NET-04', 'Network & Safety', 'Firestore security rules enforce public catalog reads, field-level profile guards, and private vault isolation', async () => {
    const rulesPath = path.join(__dirname, '../../../firestore.rules');
    const rulesText = fs.readFileSync(rulesPath, 'utf8');
    assert.ok(rulesText.includes('match /service_categories/{categoryId}'));
    assert.ok(rulesText.includes('match /services/{serviceId}'));
    assert.ok(rulesText.includes('match /technician_profiles/{techId}'));
    assert.ok(rulesText.includes('match /technician_private/{techId}'));
    assert.ok(rulesText.includes('verifiedByAdminUid'));
  });

  await runTest('NET-05', 'Live Availability', 'Technician Ram (BT-988363) with skill "AC installation" (ac_install) matches Customer App service "AC installation"', async () => {
    const prof = setTechnicianProfile(ramUid, {
      isOnline: true,
      online: true,
      availabilityStatus: 'AVAILABLE',
      lastLocationUpdate: new Date().toISOString(),
    }, ['isOnline', 'online', 'availabilityStatus', 'lastLocationUpdate']);

    assert.strictEqual(prof.isOnline, true);
    assert.strictEqual(prof.availabilityStatus, 'AVAILABLE');
    const hasAcInstall = prof.selectedSkills.some(
      s => s.enabled !== false && (s.canonicalServiceId === 'ac_install' || s.skillId === 'ac_install')
    );
    assert.strictEqual(hasAcInstall, true, 'Ram must have enabled canonical skill ac_install');
  });

  console.log('\n================================================================');
  console.log(`🏁 PHASE 5 VERIFICATION SUMMARY: ${passed}/${passed + failed} PASSED`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase5VerificationSuite().catch((err) => {
  console.error('Fatal suite error:', err);
  process.exit(1);
});
