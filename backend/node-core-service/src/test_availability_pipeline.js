const { scanSingleServiceAvailability, scanNearbyTechnicians, scanServiceAvailability } = require('./services/postgresSpatialScanner');
const { getSkillSynonymsForService, doesTechnicianMatchService } = require('./services/catalogSkillMapper');
const { inMemoryTechProfiles, inMemorySkills } = require('./config/inMemoryTechStore');

async function runTests() {
  console.log('🧪 ============================================================');
  console.log('🧪 RUNNING COMPREHENSIVE AVAILABILITY PIPELINE VERIFICATION');
  console.log('🧪 ============================================================\n');

  // Customer Coordinates (Kolkata City Center: 22.5726° N, 88.3639° E)
  const custLat = 22.5726;
  const custLng = 88.3639;

  // Test 1: Verify Skill Synonyms Mapper
  console.log('▶️ TEST 1: Service / Skill Synonyms Mapping');
  const fanSynonyms = getSkillSynonymsForService('fan_rep');
  console.log('   Fan Repair Synonyms:', fanSynonyms.slice(0, 8));
  if (!fanSynonyms.includes('fan_rep') || !fanSynonyms.includes('sk_fan_repair')) {
    throw new Error('Fan repair synonyms missing expected canonical keys!');
  }
  console.log('   ✅ TEST 1 PASSED: Fan repair synonyms mapped correctly.\n');

  // Test 2: Service Matcher Logic
  console.log('▶️ TEST 2: Service/Skill Matcher Disambiguation');
  const fanTech = { skills: ['fan_rep', 'sk_ceiling_fan_repair'], category: 'ELECTRICIAN' };
  const laptopTech = { skills: ['laptop_rep_gen', 'sk_laptop_repair'], category: 'COMPUTER' };
  const newElectrician = { skills: [], category: 'ELECTRICIAN' };

  console.log('   Fan tech matches fan_rep:', doesTechnicianMatchService(fanTech, 'fan_rep')); // true
  console.log('   Laptop tech matches fan_rep:', doesTechnicianMatchService(laptopTech, 'fan_rep')); // false
  console.log('   Laptop tech matches laptop_rep_gen:', doesTechnicianMatchService(laptopTech, 'laptop_rep_gen')); // true
  console.log('   New electrician matches fan_rep:', doesTechnicianMatchService(newElectrician, 'fan_rep')); // true

  if (!doesTechnicianMatchService(fanTech, 'fan_rep')) throw new Error('Fan tech should match fan_rep');
  if (doesTechnicianMatchService(laptopTech, 'fan_rep')) throw new Error('Laptop tech must NOT match fan_rep');
  if (!doesTechnicianMatchService(laptopTech, 'laptop_rep_gen')) throw new Error('Laptop tech should match laptop_rep_gen');
  console.log('   ✅ TEST 2 PASSED: Strict skill vs category disambiguation verified.\n');

  // Test 3: Set up 1 Real Technician within 15 km (2.1 km away in Kolkata: 22.5850, 88.3500)
  console.log('▶️ TEST 3: Real Technician Availability within 15km Radius');
  const techId = 'tech_real_001';
  inMemoryTechProfiles.set(techId, {
    id: techId,
    technicianId: techId,
    fullName: 'Arjun Das (Verified Electrician)',
    phone: '9876543210',
    category: 'ELECTRICIAN',
    skills: ['fan_rep', 'sk_ceiling_fan_repair'],
    isOnline: true,
    is_online: true,
    availabilityStatus: 'AVAILABLE',
    currentLatitude: 22.5850,
    currentLongitude: 88.3500,
    lastLocationUpdate: new Date(),
  });

  const res1 = await scanSingleServiceAvailability({
    serviceId: 'fan_rep',
    serviceName: 'Fan Repair',
    latitude: custLat,
    longitude: custLng,
    radiusKm: 15,
  });

  console.log('   Result for Fan Repair (Tech within 2.1 km, ONLINE):', res1);
  if (res1.availableTechnicianCount !== 1) {
    throw new Error(`Expected count 1, got ${res1.availableTechnicianCount}`);
  }
  console.log('   ✅ TEST 3 PASSED: Exactly 1 technician found within 15 km.\n');

  // Test 4: Move technician outside 15 km (e.g. Durgapur: 23.5204, 87.3119 ~ 150 km away)
  console.log('▶️ TEST 4: Technician Outside 15 km Radius');
  inMemoryTechProfiles.get(techId).currentLatitude = 23.5204;
  inMemoryTechProfiles.get(techId).currentLongitude = 87.3119;

  const res2 = await scanSingleServiceAvailability({
    serviceId: 'fan_rep',
    serviceName: 'Fan Repair',
    latitude: custLat,
    longitude: custLng,
    radiusKm: 15,
  });

  console.log('   Result for Fan Repair (Tech in Durgapur 150 km away):', res2);
  if (res2.availableTechnicianCount !== 0) {
    throw new Error(`Expected count 0 outside 15km, got ${res2.availableTechnicianCount}`);
  }
  console.log('   ✅ TEST 4 PASSED: 0 technicians found when outside 15 km.\n');

  // Test 5: Move technician back within 15 km, but switch OFFLINE
  console.log('▶️ TEST 5: Technician Moves Back within 15 km but goes OFFLINE');
  inMemoryTechProfiles.get(techId).currentLatitude = 22.5850;
  inMemoryTechProfiles.get(techId).currentLongitude = 88.3500;
  inMemoryTechProfiles.get(techId).isOnline = false;
  inMemoryTechProfiles.get(techId).is_online = false;
  inMemoryTechProfiles.get(techId).availabilityStatus = 'OFFLINE';

  const res3 = await scanSingleServiceAvailability({
    serviceId: 'fan_rep',
    serviceName: 'Fan Repair',
    latitude: custLat,
    longitude: custLng,
    radiusKm: 15,
  });

  console.log('   Result for Fan Repair (Tech OFFLINE):', res3);
  if (res3.availableTechnicianCount !== 0) {
    throw new Error(`Expected count 0 for OFFLINE technician, got ${res3.availableTechnicianCount}`);
  }
  console.log('   ✅ TEST 5 PASSED: 0 technicians found when OFFLINE.\n');

  // Test 6: Technician goes ONLINE again
  console.log('▶️ TEST 6: Technician Switches Back ONLINE');
  inMemoryTechProfiles.get(techId).isOnline = true;
  inMemoryTechProfiles.get(techId).is_online = true;
  inMemoryTechProfiles.get(techId).availabilityStatus = 'AVAILABLE';

  const res4 = await scanSingleServiceAvailability({
    serviceId: 'fan_rep',
    serviceName: 'Fan Repair',
    latitude: custLat,
    longitude: custLng,
    radiusKm: 15,
  });

  console.log('   Result for Fan Repair (Tech Back ONLINE):', res4);
  if (res4.availableTechnicianCount !== 1) {
    throw new Error(`Expected count 1 when back ONLINE, got ${res4.availableTechnicianCount}`);
  }
  console.log('   ✅ TEST 6 PASSED: Count immediately updates to 1 when ONLINE.\n');

  // Test 7: Technician becomes BUSY on active booking
  console.log('▶️ TEST 7: Technician Accepts Booking (Becomes BUSY)');
  inMemoryTechProfiles.get(techId).availabilityStatus = 'BUSY';

  const res5 = await scanSingleServiceAvailability({
    serviceId: 'fan_rep',
    serviceName: 'Fan Repair',
    latitude: custLat,
    longitude: custLng,
    radiusKm: 15,
  });

  console.log('   Result for Fan Repair (Tech BUSY on job):', res5);
  if (res5.availableTechnicianCount !== 0) {
    throw new Error(`Expected count 0 for BUSY technician, got ${res5.availableTechnicianCount}`);
  }
  console.log('   ✅ TEST 7 PASSED: BUSY technician excluded from available count.\n');

  // Clean up
  inMemoryTechProfiles.delete(techId);

  console.log('🎉 ============================================================');
  console.log('🎉 ALL 7 AVAILABILITY PIPELINE TESTS PASSED PERFECTLY!');
  console.log('🎉 ============================================================');
}

runTests().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
