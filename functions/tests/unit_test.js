const assert = require('assert');
const { resolveCanonicalServiceId, doesTechnicianPossessVerifiedSkill } = require('../src/canonicalServices');
const { generateOtp, generateSalt, hashOtp } = require('../src/otpService');

console.log('================================================================');
console.log('🧪 RUNNING FUNCTIONS UNIT TESTS');
console.log('================================================================\n');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✅ PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ❌ FAIL: ${name}`);
    console.error(`     Error: ${err.message}`);
    failed++;
  }
}

// 1. Canonical Service Resolver
test('resolveCanonicalServiceId maps "AC installation" to "ac_install"', () => {
  assert.strictEqual(resolveCanonicalServiceId('sk_ac_installation', 'AC installation'), 'ac_install');
  assert.strictEqual(resolveCanonicalServiceId(null, 'AC installation'), 'ac_install');
  assert.strictEqual(resolveCanonicalServiceId('ac_install', null), 'ac_install');
});

test('resolveCanonicalServiceId maps Electrical skills accurately', () => {
  assert.strictEqual(resolveCanonicalServiceId('sk_light_repair', 'Light Repair'), 'light_rep');
  assert.strictEqual(resolveCanonicalServiceId('sk_ceiling_fan_installation', 'Ceiling Fan Installation'), 'fan_ceiling_install');
  assert.strictEqual(resolveCanonicalServiceId('sk_basic_electrician', 'Basic Electrician'), 'elec_fault_diag');
});

// 2. Skill Eligibility Matcher Guard
test('doesTechnicianPossessVerifiedSkill blocks technician with only Electrical skills from receiving AC jobs', () => {
  const electricianTech = {
    skills: [
      { skillId: 'sk_light_repair', canonicalServiceId: 'light_rep', name: 'Light Repair', verificationStatus: 'VERIFIED', enabled: true },
      { skillId: 'sk_basic_electrician', canonicalServiceId: 'elec_fault_diag', name: 'Basic Electrician', verificationStatus: 'VERIFIED', enabled: true },
      { skillId: 'sk_ceiling_fan_installation', canonicalServiceId: 'fan_ceiling_install', name: 'Ceiling Fan Installation', verificationStatus: 'VERIFIED', enabled: true },
    ],
  };

  const matchesAc = doesTechnicianPossessVerifiedSkill(electricianTech, 'sk_ac_installation', 'AC installation');
  assert.strictEqual(matchesAc, false, 'Electrician MUST NOT match AC Installation');

  const matchesFan = doesTechnicianPossessVerifiedSkill(electricianTech, 'sk_ceiling_fan_installation', 'Ceiling Fan Installation');
  assert.strictEqual(matchesFan, true, 'Electrician MUST match Ceiling Fan Installation');
});

test('doesTechnicianPossessVerifiedSkill rejects UNVERIFIED or DISABLED skills', () => {
  const pendingAcTech = {
    skills: [
      { skillId: 'sk_ac_installation', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'PENDING', enabled: true },
    ],
  };
  assert.strictEqual(doesTechnicianPossessVerifiedSkill(pendingAcTech, 'sk_ac_installation', 'AC installation'), false);

  const disabledAcTech = {
    skills: [
      { skillId: 'sk_ac_installation', canonicalServiceId: 'ac_install', name: 'AC installation', verificationStatus: 'VERIFIED', enabled: false },
    ],
  };
  assert.strictEqual(doesTechnicianPossessVerifiedSkill(disabledAcTech, 'sk_ac_installation', 'AC installation'), false);
});

// 3. Cryptographic OTP Generation & Salting
test('generateOtp produces 4-digit numeric string', () => {
  for (let i = 0; i < 20; i++) {
    const otp = generateOtp(4);
    assert.strictEqual(typeof otp, 'string');
    assert.strictEqual(otp.length, 4);
    const num = parseInt(otp, 10);
    assert(num >= 1000 && num <= 9999);
  }
});

test('hashOtp produces consistent HMAC-SHA256 hex string with salt', () => {
  const salt = generateSalt();
  const hash1 = hashOtp('1234', salt);
  const hash2 = hashOtp('1234', salt);
  const hashOther = hashOtp('1235', salt);

  assert.strictEqual(hash1, hash2, 'Identical OTP + salt must yield identical hash');
  assert.notStrictEqual(hash1, hashOther, 'Different OTP must yield different hash');
  assert.strictEqual(hash1.length, 64, 'SHA-256 hex must be 64 characters');
});

console.log('\n================================================================');
console.log(`📊 UNIT TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
console.log('================================================================\n');

if (failed > 0) process.exit(1);

