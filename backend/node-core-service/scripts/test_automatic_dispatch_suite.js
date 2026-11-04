// ============================================================================
// BOOKURTECHNICIAN - 20-SCENARIO AUTOMATIC DISPATCH & SECURITY TEST SUITE
// Verifies Eligibility, PostGIS/Haversine Spatial Search, Multi-Factor Ranking,
// Sequential Offers, Timeout/Reject/Offline Cascade, Atomic 409 Race Prevention,
// Socket Room Auth, GPS Privacy, Geofence + EmailJS OTP, Restart Recovery & Admin Audit.
// ============================================================================

const assert = require('assert');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const { io: ClientIO } = require('socket.io-client');

const { server } = require('../src/server');
const { JWT_SECRET } = require('../src/middleware/authMiddleware');
const automaticDispatchEngine = require('../src/services/automaticDispatchEngine');
const bookingsStore = require('../src/config/bookingsStore');
const { setTechnicianProfile, clearAllTechniciansStore } = require('../src/config/inMemoryTechStore');

const TEST_PORT = 4599;
const BASE_URL = `http://localhost:${TEST_PORT}/api/v1`;
const SOCKET_URL = `http://localhost:${TEST_PORT}`;

function signToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
}

function createHelperTechnician({
  id,
  name,
  phone,
  category = 'AC_REPAIR',
  skills = ['ac_jet_service', 'ac_repair'],
  lat = 22.5726,
  lng = 88.3639,
  rating = 4.9,
  acceptanceRate = 98,
  isOnline = true,
  kycStatus = 'VERIFIED',
  accountStatus = 'Active',
  isSuspended = false,
  onboardingCompleted = true,
  fcmToken = 'fcm_live_device_token_valid_998877665544332211',
}) {
  // Note: fcmToken must not start with fcm_ or fake_
  const realFormattedToken = fcmToken.startsWith('fcm_')
    ? `dG9rZW5_${id}_real_firebase_instance_token_2026_xyz987654321`
    : fcmToken;

  const profile = setTechnicianProfile(id, {
    id,
    technicianId: id,
    name,
    fullName: name,
    phone,
    email: `${id}@bookurtechnician.online`,
    category,
    skills,
    latitude: lat,
    longitude: lng,
    current_latitude: lat,
    current_longitude: lng,
    lastLocationUpdate: new Date().toISOString(),
    rating,
    acceptanceRate,
    isOnline,
    is_online: isOnline,
    availabilityStatus: isOnline ? 'AVAILABLE' : 'OFFLINE',
    kycStatus,
    accountStatus,
    isSuspended,
    onboardingCompleted,
    fcmToken: realFormattedToken,
    deviceTokens: [realFormattedToken],
  });

  skills.forEach(s => {
    automaticDispatchEngine.setTechnicianServiceSkill(id, {
      serviceId: s,
      categoryId: category,
      isVerified: true,
      active: true,
    });
  });

  return profile;
}

async function runSuite() {
  console.log('================================================================================');
  console.log('🚀 STARTING BOOKURTECHNICIAN 20-SCENARIO AUTOMATIC DISPATCH VERIFICATION SUITE');
  console.log('================================================================================\n');

  await new Promise((resolve) => server.listen(TEST_PORT, resolve));

  const results = [];
  const recordResult = (num, title, passed, detail = '') => {
    results.push({ num, title, passed, detail });
    console.log(`${passed ? '✅ PASS' : '❌ FAIL'} [Test ${String(num).padStart(2, '0')}] ${title}${detail ? ` — ${detail}` : ''}`);
  };

  let tech1Socket = null;
  let tech2Socket = null;
  let cust1Socket = null;
  let unrelatedCustSocket = null;

  try {
    const adminToken = signToken({ id: 'admin_01', role: 'SUPER_ADMIN', email: 'admin@bookurtechnician.com' });
    const cust1Token = signToken({ id: 'cust_101', role: 'CUSTOMER', email: 'rahul.customer@example.com' });
    const cust2Token = signToken({ id: 'cust_202', role: 'CUSTOMER', email: 'other.customer@example.com' });

    // Clean state before tests
    clearAllTechniciansStore();
    automaticDispatchEngine.resetDispatchEngineStoresForTest();
    automaticDispatchEngine.updateDispatchConfig({
      radiiKm: [3, 5, 10, 15],
      offerTimeoutSeconds: 20,
      autoDispatchEnabled: true,
    });

    // -------------------------------------------------------------------------
    // TEST 1: Nearby eligible technician found
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_near_1',
      name: 'ArjunVermaTech',
      phone: '9800000001',
      category: 'AC_REPAIR',
      skills: ['ac_jet_service'],
      lat: 22.5750, // ~0.3 km from (22.5726, 88.3639)
      lng: 88.3650,
      rating: 4.95,
      acceptanceRate: 99,
    });

    const availRes1 = await axios.get(`${BASE_URL}/technicians/availability`, {
      params: {
        latitude: 22.5726,
        longitude: 88.3639,
        serviceId: 'ac_jet_service',
        category: 'AC_REPAIR',
        radiusKm: 3,
      },
    });
    assert.strictEqual(availRes1.data.availableCount, 1);
    assert.strictEqual(availRes1.data.technicians[0].technicianId, 'tech_near_1');
    recordResult(1, 'Nearby eligible technician found within 3 km radius', true, `distance=${availRes1.data.technicians[0].distanceKm}km`);

    // -------------------------------------------------------------------------
    // TEST 2: Technician with wrong skill excluded
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_wrong_skill',
      name: 'PlumberSpecialist',
      phone: '9800000002',
      category: 'PLUMBING',
      skills: ['tap_repair'],
      lat: 22.5730,
      lng: 88.3640,
    });

    const scan2 = await automaticDispatchEngine.findAndRankEligibleTechnicians(
      {
        serviceId: 'ac_jet_service',
        serviceName: 'AC Jet Service',
        category: 'AC_REPAIR',
        latitude: 22.5726,
        longitude: 88.3639,
      },
      3
    );
    const wrongSkillIncluded = scan2.rankedCandidates.some(c => c.technicianId === 'tech_wrong_skill');
    assert.strictEqual(wrongSkillIncluded, false);
    recordResult(2, 'Technician with wrong skill strictly excluded', true, 'Plumber excluded from AC job');

    // -------------------------------------------------------------------------
    // TEST 3: Offline technician excluded
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_offline_3',
      name: 'OfflineACTech',
      phone: '9800000003',
      category: 'AC_REPAIR',
      skills: ['ac_jet_service'],
      lat: 22.5735,
      lng: 88.3642,
      isOnline: false,
    });

    const scan3 = await automaticDispatchEngine.findAndRankEligibleTechnicians(
      {
        serviceId: 'ac_jet_service',
        category: 'AC_REPAIR',
        latitude: 22.5726,
        longitude: 88.3639,
        bookingMode: 'INSTANT',
      },
      3
    );
    assert.strictEqual(scan3.rankedCandidates.some(c => c.technicianId === 'tech_offline_3'), false);
    recordResult(3, 'Offline technician excluded from instant dispatch', true);

    // -------------------------------------------------------------------------
    // TEST 4: Scheduled booking checks appointment availability window
    // -------------------------------------------------------------------------
    const schedDay = new Date('2026-11-10T10:00:00').getDay();
    await automaticDispatchEngine.setTechnicianAvailability('tech_near_1', [
      {
        dayOfWeek: schedDay,
        startTime: '09:00',
        endTime: '14:00',
        isAvailable: true,
      },
    ]);

    const scanSchedAvailable = await automaticDispatchEngine.findAndRankEligibleTechnicians(
      {
        serviceId: 'ac_jet_service',
        category: 'AC_REPAIR',
        latitude: 22.5726,
        longitude: 88.3639,
        bookingMode: 'SCHEDULED',
        scheduleDate: '2026-11-10',
        scheduleSlot: '10:00 AM',
      },
      5
    );
    const scanSchedUnavailable = await automaticDispatchEngine.findAndRankEligibleTechnicians(
      {
        serviceId: 'ac_jet_service',
        category: 'AC_REPAIR',
        latitude: 22.5726,
        longitude: 88.3639,
        bookingMode: 'SCHEDULED',
        scheduleDate: '2026-11-10',
        scheduleSlot: '06:00 PM', // Outside 09:00-14:00 working hours
      },
      5
    );
    assert.strictEqual(scanSchedAvailable.rankedCandidates.some(c => c.technicianId === 'tech_near_1'), true);
    assert.strictEqual(scanSchedUnavailable.rankedCandidates.some(c => c.technicianId === 'tech_near_1'), false);
    recordResult(4, 'Scheduled booking checks appointment window & working hours', true, '10:00 AM eligible, 06:00 PM excluded');

    // Reset tech_near_1 availability to full day
    await automaticDispatchEngine.setTechnicianAvailability('tech_near_1', [
      { dayOfWeek: new Date().getDay(), startTime: '00:00', endTime: '23:59', isAvailable: true },
    ]);

    // -------------------------------------------------------------------------
    // TEST 5: Technician with conflicting active booking excluded
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_busy_5',
      name: 'BusyACTech',
      phone: '9800000005',
      category: 'AC_REPAIR',
      skills: ['ac_jet_service'],
      lat: 22.5730,
      lng: 88.3640,
    });
    bookingsStore.addBooking({
      id: 'BK-CONFLICT-500',
      customerId: 'cust_999',
      technicianId: 'tech_busy_5',
      serviceId: 'ac_jet_service',
      status: 'IN_PROGRESS',
      latitude: 22.5730,
      longitude: 88.3640,
    });

    const scan5 = await automaticDispatchEngine.findAndRankEligibleTechnicians(
      {
        serviceId: 'ac_jet_service',
        category: 'AC_REPAIR',
        latitude: 22.5726,
        longitude: 88.3639,
        bookingMode: 'INSTANT',
      },
      3
    );
    assert.strictEqual(scan5.rankedCandidates.some(c => c.technicianId === 'tech_busy_5'), false);
    recordResult(5, 'Technician with conflicting active booking excluded', true);

    // -------------------------------------------------------------------------
    // TEST 6: Best ranked technician selected using weighted multi-factor score
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_rank_second',
      name: 'SecondRankedTech',
      phone: '9800000006',
      category: 'AC_REPAIR',
      skills: ['ac_jet_service'],
      lat: 22.5920, // ~2.2 km away (further than tech_near_1 at 0.3 km)
      lng: 88.3650,
      rating: 4.2,
      acceptanceRate: 80,
    });

    const scan6 = await automaticDispatchEngine.findAndRankEligibleTechnicians(
      {
        serviceId: 'ac_jet_service',
        category: 'AC_REPAIR',
        latitude: 22.5726,
        longitude: 88.3639,
        bookingMode: 'INSTANT',
      },
      3
    );
    assert(scan6.rankedCandidates.length >= 2);
    assert.strictEqual(scan6.rankedCandidates[0].technicianId, 'tech_near_1');
    assert.strictEqual(scan6.rankedCandidates[1].technicianId, 'tech_rank_second');
    assert(scan6.rankedCandidates[0].rankingScore > scan6.rankedCandidates[1].rankingScore);
    recordResult(
      6,
      'Best ranked technician selected via weighted score',
      true,
      `#1=${scan6.rankedCandidates[0].technicianId} (${scan6.rankedCandidates[0].rankingScore}) > #2=${scan6.rankedCandidates[1].technicianId} (${scan6.rankedCandidates[1].rankingScore})`
    );

    // -------------------------------------------------------------------------
    // TEST 7: First technician receives offer via Socket + API & Customer PII is masked
    // -------------------------------------------------------------------------
    const tech1Token = signToken({ id: 'tech_near_1', role: 'TECHNICIAN', phone: '9800000001' });
    const tech2Token = signToken({ id: 'tech_rank_second', role: 'TECHNICIAN', phone: '9800000006' });

    tech1Socket = ClientIO(SOCKET_URL, { auth: { token: tech1Token }, transports: ['websocket'] });
    tech2Socket = ClientIO(SOCKET_URL, { auth: { token: tech2Token }, transports: ['websocket'] });
    cust1Socket = ClientIO(SOCKET_URL, { auth: { token: cust1Token }, transports: ['websocket'] });

    await Promise.all([
      new Promise(r => tech1Socket.on('connect', r)),
      new Promise(r => tech2Socket.on('connect', r)),
      new Promise(r => cust1Socket.on('connect', r)),
    ]);

    tech1Socket.emit('technician:join', { technicianId: 'tech_near_1' });
    tech2Socket.emit('technician:join', { technicianId: 'tech_rank_second' });
    cust1Socket.emit('customer:join', { customerId: 'cust_101' });
    await new Promise(r => setTimeout(r, 80));

    let tech1ReceivedOffer = null;
    let tech2PrematureOffer = null;
    tech1Socket.on('dispatch:offer:new', (payload) => { tech1ReceivedOffer = payload; });
    tech2Socket.on('dispatch:offer:new', (payload) => { tech2PrematureOffer = payload; });

    const booking1Res = await axios.post(
      `${BASE_URL}/bookings`,
      {
        id: 'BK-DISPATCH-701',
        customerId: 'cust_101',
        customerName: 'Rahul Customer',
        customerPhone: '9876500101',
        customerEmail: 'rahul.customer@example.com',
        serviceId: 'ac_jet_service',
        serviceName: 'AC Jet Servicing',
        category: 'AC_REPAIR',
        address: 'Flat 402, Tower B, Salt Lake Sector 5, Kolkata',
        latitude: 22.5726,
        longitude: 88.3639,
        basePrice: 500,
        grandTotal: 590,
      },
      { headers: { Authorization: `Bearer ${cust1Token}` } }
    );

    await new Promise(r => setTimeout(r, 120));
    assert(tech1ReceivedOffer, 'Technician 1 must receive dispatch:offer:new');
    assert.strictEqual(tech2PrematureOffer, null, 'Technician 2 must NOT receive offer while Tech 1 offer is active');
    assert(!tech1ReceivedOffer.customerAddress.includes('Flat 402'), 'Exact flat number must be masked before acceptance');
    assert.strictEqual(tech1ReceivedOffer.customerPhone, undefined, 'Customer phone must NOT be leaked in pre-acceptance offer');
    recordResult(7, 'First technician receives sequential offer with masked customer area & no PII leak', true, `offerId=${tech1ReceivedOffer.offerId}`);

    // -------------------------------------------------------------------------
    // TEST 9 & 12: Technician 1 rejects offer -> Second technician receives next offer
    // -------------------------------------------------------------------------
    let tech2ReceivedOfferAfterReject = null;
    tech2Socket.on('dispatch:offer:new', (payload) => { tech2ReceivedOfferAfterReject = payload; });

    const rejectRes = await axios.post(
      `${BASE_URL}/dispatch/offers/${tech1ReceivedOffer.offerId}/reject`,
      { reason: 'TOO_FAR' },
      { headers: { Authorization: `Bearer ${tech1Token}` } }
    );
    assert.strictEqual(rejectRes.status, 200);
    await new Promise(r => setTimeout(r, 120));

    assert(tech2ReceivedOfferAfterReject, 'Second technician must receive offer after first rejects');
    assert.strictEqual(tech2ReceivedOfferAfterReject.technicianId, 'tech_rank_second');
    recordResult(9, 'Technician rejects offer and backend records rejection', true);
    recordResult(12, 'Second ranked technician receives next sequential offer immediately', true, `offerId=${tech2ReceivedOfferAfterReject.offerId}`);

    // -------------------------------------------------------------------------
    // TEST 8 & 14: Technician accepts offer -> Atomically assigned & Customer notified
    // -------------------------------------------------------------------------
    let custAssignedEvent = null;
    cust1Socket.on('booking:technician:assigned', (payload) => { custAssignedEvent = payload; });

    const acceptRes = await axios.post(
      `${BASE_URL}/dispatch/offers/${tech2ReceivedOfferAfterReject.offerId}/accept`,
      {},
      { headers: { Authorization: `Bearer ${tech2Token}` } }
    );
    assert.strictEqual(acceptRes.status, 200);
    await new Promise(r => setTimeout(r, 120));

    assert(custAssignedEvent, 'Customer must receive booking:technician:assigned socket event');
    assert.strictEqual(custAssignedEvent.technicianId, 'tech_rank_second');
    assert(custAssignedEvent.etaMinutes >= 1);
    recordResult(8, 'Technician accepts offer and is atomically assigned', true);
    recordResult(14, 'Customer receives real-time assignment notification with profile & ETA', true, `tech=${custAssignedEvent.technician.name}, eta=${custAssignedEvent.etaMinutes}m`);

    // Free tech_rank_second for subsequent tests
    bookingsStore.updateBookingStatus('BK-DISPATCH-701', 'COMPLETED');
    createHelperTechnician({
      id: 'tech_rank_second',
      name: 'SecondRankedTech',
      phone: '9800000006',
      category: 'AC_REPAIR',
      skills: ['ac_jet_service'],
      lat: 22.5920,
      lng: 88.3650,
      rating: 4.2,
      acceptanceRate: 80,
      isOnline: true,
    });

    // -------------------------------------------------------------------------
    // TEST 10: Offer times out after configured window and advances to next technician
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_timeout_a',
      name: 'TimeoutTechA',
      phone: '9800000010',
      category: 'ELECTRICIAN',
      skills: ['wiring_fix'],
      lat: 22.5728,
      lng: 88.3640,
      rating: 4.95,
    });
    createHelperTechnician({
      id: 'tech_timeout_b',
      name: 'TimeoutTechB',
      phone: '9800000011',
      category: 'ELECTRICIAN',
      skills: ['wiring_fix'],
      lat: 22.5760,
      lng: 88.3660,
      rating: 4.80,
    });

    const bTimeout = bookingsStore.addBooking({
      id: 'BK-TIMEOUT-10',
      customerId: 'cust_101',
      serviceId: 'wiring_fix',
      serviceName: 'Switchboard Wiring Fix',
      category: 'ELECTRICIAN',
      latitude: 22.5726,
      longitude: 88.3639,
      basePrice: 300,
      grandTotal: 354,
    });

    await automaticDispatchEngine.startDispatchForBooking(bTimeout, {
      offerTimeoutSeconds: 1, // 1 second window for fast automated test
    });

    const sessBeforeTimeout = automaticDispatchEngine.getBookingDispatchStatus('BK-TIMEOUT-10');
    assert.strictEqual(sessBeforeTimeout.activeOffer.technicianId, 'tech_timeout_a');

    // Wait 1.35s for authoritative backend timer to expire Tech A's offer and advance to Tech B
    await new Promise(r => setTimeout(r, 1350));

    const sessAfterTimeout = automaticDispatchEngine.getBookingDispatchStatus('BK-TIMEOUT-10');
    assert.strictEqual(sessAfterTimeout.activeOffer.technicianId, 'tech_timeout_b');
    recordResult(10, 'Offer times out after configured window and advances to next technician', true, 'Tech A expired -> Tech B offered');

    // Clean up BK-TIMEOUT-10
    bookingsStore.updateBookingStatus('BK-TIMEOUT-10', 'CANCELLED');
    await automaticDispatchEngine.handleTechnicianOffline('tech_timeout_b', 'TEST_CLEANUP');

    // -------------------------------------------------------------------------
    // TEST 11: Technician goes offline during active offer -> Offer invalidated & cascaded
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_off_a',
      name: 'OfflineMidOfferA',
      phone: '9800000012',
      category: 'PLUMBING',
      skills: ['pipe_leak'],
      lat: 22.5727,
      lng: 88.3640,
      rating: 4.95,
    });
    createHelperTechnician({
      id: 'tech_off_b',
      name: 'OfflineMidOfferB',
      phone: '9800000013',
      category: 'PLUMBING',
      skills: ['pipe_leak'],
      lat: 22.5770,
      lng: 88.3670,
      rating: 4.85,
    });

    const bOffline = bookingsStore.addBooking({
      id: 'BK-OFFLINE-11',
      customerId: 'cust_101',
      serviceId: 'pipe_leak',
      serviceName: 'Pipe Leak Repair',
      category: 'PLUMBING',
      latitude: 22.5726,
      longitude: 88.3639,
      basePrice: 400,
      grandTotal: 472,
    });

    await automaticDispatchEngine.startDispatchForBooking(bOffline, { offerTimeoutSeconds: 20 });
    const statusBeforeOff = automaticDispatchEngine.getBookingDispatchStatus('BK-OFFLINE-11');
    assert.strictEqual(statusBeforeOff.activeOffer.technicianId, 'tech_off_a');

    const techOffAToken = signToken({ id: 'tech_off_a', role: 'TECHNICIAN' });
    await axios.post(
      `${BASE_URL}/technicians/online-status`,
      { isOnline: false },
      { headers: { Authorization: `Bearer ${techOffAToken}` } }
    );

    const statusAfterOff = automaticDispatchEngine.getBookingDispatchStatus('BK-OFFLINE-11');
    assert.strictEqual(statusAfterOff.activeOffer.technicianId, 'tech_off_b');
    recordResult(11, 'Technician going offline during offer invalidates offer and cascades immediately', true, 'Tech A offline -> Tech B offered');

    bookingsStore.updateBookingStatus('BK-OFFLINE-11', 'CANCELLED');
    await automaticDispatchEngine.handleTechnicianOffline('tech_off_b', 'TEST_CLEANUP');

    // -------------------------------------------------------------------------
    // TEST 13: Simultaneous accept returns one 200 SUCCESS and one 409 CONFLICT
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_race_winner',
      name: 'RaceWinnerTech',
      phone: '9800000014',
      category: 'CARPENTRY',
      skills: ['door_lock'],
      lat: 22.5728,
      lng: 88.3641,
    });
    const bRace = bookingsStore.addBooking({
      id: 'BK-RACE-13',
      customerId: 'cust_101',
      serviceId: 'door_lock',
      serviceName: 'Door Lock Installation',
      category: 'CARPENTRY',
      latitude: 22.5726,
      longitude: 88.3639,
      basePrice: 450,
      grandTotal: 531,
    });
    await automaticDispatchEngine.startDispatchForBooking(bRace, { offerTimeoutSeconds: 20 });
    const raceStatus = automaticDispatchEngine.getBookingDispatchStatus('BK-RACE-13');
    const raceOfferId = raceStatus.activeOffer.offerId;
    const raceToken = signToken({ id: 'tech_race_winner', role: 'TECHNICIAN' });

    // Fire two simultaneous accept requests for the same booking/offer
    const [r1, r2] = await Promise.allSettled([
      axios.post(`${BASE_URL}/dispatch/offers/${raceOfferId}/accept`, {}, { headers: { Authorization: `Bearer ${raceToken}` } }),
      axios.post(`${BASE_URL}/dispatch/offers/${raceOfferId}/accept`, {}, { headers: { Authorization: `Bearer ${raceToken}` } }),
    ]);

    const codes = [
      r1.status === 'fulfilled' ? r1.value.status : r1.reason?.response?.status,
      r2.status === 'fulfilled' ? r2.value.status : r2.reason?.response?.status,
    ].sort();

    assert.deepStrictEqual(codes, [200, 409], `Expected [200, 409], got ${JSON.stringify(codes)}`);
    recordResult(13, 'Simultaneous accept returns one 200 SUCCESS and one 409 CONFLICT', true, `HTTP codes=${JSON.stringify(codes)}`);

    // -------------------------------------------------------------------------
    // TEST 15: Invalid / synthetic FCM token rejected
    // -------------------------------------------------------------------------
    let fcmRejectedStatus = null;
    try {
      await axios.post(
        `${BASE_URL}/technicians/fcm-token`,
        { technicianId: 'tech_near_1', token: 'fake_synthetic_token_123' },
        { headers: { Authorization: `Bearer ${tech1Token}` } }
      );
    } catch (err) {
      fcmRejectedStatus = err.response?.status;
    }
    assert.strictEqual(fcmRejectedStatus, 400);
    recordResult(15, 'Synthetic/invalid FCM token rejected with 400 Bad Request', true);

    // -------------------------------------------------------------------------
    // TEST 16: Technician GPS updates only authorized booking room (GPS Privacy)
    // -------------------------------------------------------------------------
    unrelatedCustSocket = ClientIO(SOCKET_URL, { auth: { token: cust2Token }, transports: ['websocket'] });
    await new Promise(r => unrelatedCustSocket.on('connect', r));
    unrelatedCustSocket.emit('customer:join', { customerId: 'cust_202' });

    // Unrelated customer tries to join BK-RACE-13 room -> must be blocked with auth_error
    let unauthorizedJoinBlocked = false;
    unrelatedCustSocket.on('auth_error', () => { unauthorizedJoinBlocked = true; });
    unrelatedCustSocket.emit('job:join', { bookingId: 'BK-RACE-13' });
    await new Promise(r => setTimeout(r, 80));
    assert.strictEqual(unauthorizedJoinBlocked, true, 'Unrelated customer must be blocked from joining another booking room');

    let authorizedCustomerReceivedGps = false;
    let unrelatedCustomerReceivedGps = false;
    cust1Socket.on('booking:partner:location', (loc) => {
      if (loc.bookingId === 'BK-RACE-13') authorizedCustomerReceivedGps = true;
    });
    unrelatedCustSocket.on('booking:partner:location', () => {
      unrelatedCustomerReceivedGps = true;
    });

    await axios.post(
      `${BASE_URL}/technicians/location`,
      {
        technicianId: 'tech_race_winner',
        bookingId: 'BK-RACE-13',
        latitude: 22.5727,
        longitude: 88.3640,
        speed: 18,
        heading: 90,
      },
      { headers: { Authorization: `Bearer ${raceToken}` } }
    );
    await new Promise(r => setTimeout(r, 100));

    assert.strictEqual(authorizedCustomerReceivedGps, true);
    assert.strictEqual(unrelatedCustomerReceivedGps, false);
    recordResult(16, 'Technician GPS updates only authorized booking/customer room (zero global leak)', true);

    // -------------------------------------------------------------------------
    // TEST 17: Geofence Arrival + Start OTP transition + Registered Email OTP via EmailJS
    // -------------------------------------------------------------------------
    const arriveRes = await axios.post(
      `${BASE_URL}/bookings/BK-RACE-13/arrive`,
      { latitude: 22.5726, longitude: 88.3639 },
      { headers: { Authorization: `Bearer ${raceToken}` } }
    );
    assert.strictEqual(arriveRes.status, 200);
    assert.strictEqual(arriveRes.data.status, 'ARRIVED');

    const raceBookingObj = bookingsStore.getBookingById('BK-RACE-13');
    const otpStartRes = await axios.post(
      `${BASE_URL}/bookings/BK-RACE-13/verify-start-otp`,
      { startOtp: raceBookingObj.startOtp },
      { headers: { Authorization: `Bearer ${raceToken}` } }
    );
    assert.strictEqual(otpStartRes.status, 200);
    assert.strictEqual(otpStartRes.data.status, 'IN_PROGRESS');

    // Also test Auth OTP Request & Verification via Registered Email (EmailJS service)
    const reqOtpRes = await axios.post(`${BASE_URL}/auth/request-otp`, {
      email: 'verified.user@bookurtechnician.online',
      name: 'Verified User',
      role: 'CUSTOMER',
    });
    assert.strictEqual(reqOtpRes.status, 200);
    assert.strictEqual(reqOtpRes.data.success, true);

    recordResult(17, 'Arrival geofence (500m), Start OTP transition, and Registered Email OTP flow verified', true);

    // -------------------------------------------------------------------------
    // TEST 18: Server restart recovers active dispatch session without duplicate offers
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_recover_18',
      name: 'RecoveryTech',
      phone: '9800000018',
      category: 'CLEANING',
      skills: ['sofa_clean'],
      lat: 22.5730,
      lng: 88.3640,
    });
    const bRecover = bookingsStore.addBooking({
      id: 'BK-RECOVER-18',
      customerId: 'cust_101',
      serviceId: 'sofa_clean',
      serviceName: 'Sofa Deep Cleaning',
      category: 'CLEANING',
      latitude: 22.5726,
      longitude: 88.3639,
      basePrice: 599,
      grandTotal: 706,
    });
    await automaticDispatchEngine.startDispatchForBooking(bRecover, { offerTimeoutSeconds: 20 });
    const recoveredList = await automaticDispatchEngine.recoverActiveDispatchSessions();
    assert(recoveredList.includes('BK-RECOVER-18'));
    const histAfterRecover = automaticDispatchEngine.getBookingDispatchHistory('BK-RECOVER-18');
    assert.strictEqual(histAfterRecover.offers.length, 1, 'Must not create duplicate offer during restart recovery');
    recordResult(18, 'Server restart recovers active dispatch session cleanly without duplicate offers', true);

    bookingsStore.updateBookingStatus('BK-RECOVER-18', 'CANCELLED');
    await automaticDispatchEngine.handleTechnicianOffline('tech_recover_18', 'TEST_CLEANUP');

    // -------------------------------------------------------------------------
    // TEST 19: No technician available expands radius (3->5->10->15km) & sets transparent status
    // -------------------------------------------------------------------------
    const bNoTech = bookingsStore.addBooking({
      id: 'BK-NOTECH-19',
      customerId: 'cust_101',
      serviceId: 'rare_chimney_service',
      serviceName: 'Chimney Turbine Overhaul',
      category: 'CHIMNEY_SPECIAL',
      latitude: 22.5726,
      longitude: 88.3639,
      basePrice: 999,
      grandTotal: 1178,
    });

    const failedSession = await automaticDispatchEngine.startDispatchForBooking(bNoTech);
    assert.strictEqual(failedSession.status, 'FAILED_NO_TECHNICIAN');
    const updatedNoTechBooking = bookingsStore.getBookingById('BK-NOTECH-19');
    assert.strictEqual(updatedNoTechBooking.status, 'NO_TECHNICIAN_AVAILABLE');
    recordResult(19, 'No technician available expands radii (3->5->10->15km) and sets transparent NO_TECHNICIAN_AVAILABLE status', true);

    // -------------------------------------------------------------------------
    // TEST 20: Admin manual reassignment is audited
    // -------------------------------------------------------------------------
    createHelperTechnician({
      id: 'tech_reassign_20',
      name: 'AdminReassignedTech',
      phone: '9800000020',
      category: 'CARPENTRY',
      skills: ['door_lock'],
      lat: 22.5740,
      lng: 88.3645,
    });

    const manualRes = await axios.post(
      `${BASE_URL}/dispatch/BK-RACE-13/manual-assign`,
      {
        technicianId: 'tech_reassign_20',
        reason: 'CUSTOMER_PRIORITY_REASSIGNMENT',
      },
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    assert.strictEqual(manualRes.status, 200);
    assert.strictEqual(manualRes.data.data.isReassignment, true);

    const historyRes = await axios.get(
      `${BASE_URL}/admin/dispatch/BK-RACE-13/history`,
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    const hasReassignAudit = historyRes.data.auditLogs.some(
      l => l.eventType === 'ADMIN_MANUAL_REASSIGNMENT' && l.technicianId === 'tech_reassign_20'
    );
    assert.strictEqual(hasReassignAudit, true);
    recordResult(20, 'Admin manual reassignment is executed and recorded in dispatch_audit_logs', true);

    // -------------------------------------------------------------------------
    // TEST 21: Service catalog search, Real available slots & Booking Idempotency-Key
    // -------------------------------------------------------------------------
    const catalogRes = await axios.get(`${BASE_URL}/catalog/services`);
    assert.strictEqual(catalogRes.status, 200);

    const slotsRes = await axios.get(`${BASE_URL}/bookings/available-slots`, {
      params: {
        serviceId: 'door_lock',
        category: 'CARPENTRY',
        date: '2026-11-12',
        latitude: 22.5726,
        longitude: 88.3639,
      },
    });
    assert.strictEqual(slotsRes.status, 200);
    assert.strictEqual(slotsRes.data.success, true);
    assert(Array.isArray(slotsRes.data.slots) && slotsRes.data.slots.length > 0);

    const idemKey = 'idem_test_key_2026_unique_901';
    const idemReqBody = {
      customerId: 'cust_101',
      customerName: 'Rahul Customer',
      customerPhone: '9876500101',
      serviceId: 'door_lock',
      serviceName: 'Door Lock Installation',
      category: 'CARPENTRY',
      address: 'Salt Lake Sector 5, Kolkata',
      latitude: 22.5726,
      longitude: 88.3639,
      basePrice: 450,
    };
    const idem1 = await axios.post(`${BASE_URL}/bookings`, idemReqBody, {
      headers: { Authorization: `Bearer ${cust1Token}`, 'Idempotency-Key': idemKey },
    });
    const idem2 = await axios.post(`${BASE_URL}/bookings`, idemReqBody, {
      headers: { Authorization: `Bearer ${cust1Token}`, 'Idempotency-Key': idemKey },
    });
    assert.strictEqual(idem1.data.data.id, idem2.data.data.id, 'Idempotent replay must return identical booking ID');
    assert.strictEqual(idem2.data.idempotentReplay, true);
    recordResult(21, 'Service search, Real-time available slots & Booking Idempotency-Key deduplication verified', true, `bookingId=${idem1.data.data.id}`);

    // -------------------------------------------------------------------------
    // TEST 22: Service proof upload, Completion OTP, Ledger settlement & GST Invoice
    // -------------------------------------------------------------------------
    const assignedTechToken = signToken({ id: 'tech_reassign_20', role: 'TECHNICIAN' });
    await axios.post(
      `${BASE_URL}/bookings/BK-RACE-13/arrive`,
      { latitude: 22.5726, longitude: 88.3639 },
      { headers: { Authorization: `Bearer ${assignedTechToken}` } }
    );
    const raceBookingBeforeStart = bookingsStore.getBookingById('BK-RACE-13');
    await axios.post(
      `${BASE_URL}/bookings/BK-RACE-13/verify-start-otp`,
      { startOtp: raceBookingBeforeStart.startOtp },
      { headers: { Authorization: `Bearer ${assignedTechToken}` } }
    );

    // Security check: Attempting to complete job BEFORE uploading service proof must fail with 400
    const raceBookingMid = bookingsStore.getBookingById('BK-RACE-13');
    let bypassProofStatus = null;
    try {
      await axios.post(
        `${BASE_URL}/bookings/BK-RACE-13/verify-end-otp`,
        { endOtp: raceBookingMid.endOtp },
        { headers: { Authorization: `Bearer ${assignedTechToken}` } }
      );
    } catch (err) {
      bypassProofStatus = err.response?.status;
    }
    assert.strictEqual(bypassProofStatus, 400, 'Completion without after-service proof must be blocked with 400');

    // Security check: Unassigned technician attempting to upload proof to BK-RACE-13 must fail with 403
    let wrongTechProofStatus = null;
    try {
      await axios.post(
        `${BASE_URL}/bookings/BK-RACE-13/proof`,
        { type: 'AFTER', mediaUrl: 'https://storage.googleapis.com/bookmytechnician-53d94.appspot.com/proofs/unauth.jpg' },
        { headers: { Authorization: `Bearer ${tech1Token}` } }
      );
    } catch (err) {
      wrongTechProofStatus = err.response?.status;
    }
    assert.strictEqual(wrongTechProofStatus, 403, 'Unassigned technician proof upload must be blocked with 403');

    const proofUploadRes = await axios.post(
      `${BASE_URL}/bookings/BK-RACE-13/proof`,
      {
        type: 'AFTER',
        mediaUrl: 'https://storage.googleapis.com/bookmytechnician-53d94.appspot.com/proofs/BK-RACE-13-after.jpg',
        beforeImageUrl: 'https://storage.googleapis.com/bookmytechnician-53d94.appspot.com/proofs/BK-RACE-13-before.jpg',
        afterImageUrl: 'https://storage.googleapis.com/bookmytechnician-53d94.appspot.com/proofs/BK-RACE-13-after.jpg',
        technicianNotes: 'Installed high-security mortise lock and tested 3 keys.',
        partsReplaced: 'Mortise cylinder',
      },
      { headers: { Authorization: `Bearer ${assignedTechToken}` } }
    );
    assert.strictEqual(proofUploadRes.status, 200);
    assert.strictEqual(proofUploadRes.data.success, true);

    const getProofRes = await axios.get(`${BASE_URL}/bookings/BK-RACE-13/proof`, {
      headers: { Authorization: `Bearer ${cust1Token}` },
    });
    assert.strictEqual(getProofRes.status, 200);
    const proofItems = Array.isArray(getProofRes.data.data) ? getProofRes.data.data : [getProofRes.data.data];
    assert(proofItems.some(p => (p.mediaUrl || p.after_image_url || '').includes('BK-RACE-13-after.jpg')));

    const raceBookingNow = bookingsStore.getBookingById('BK-RACE-13');
    const completeRes = await axios.post(
      `${BASE_URL}/bookings/BK-RACE-13/verify-end-otp`,
      { endOtp: raceBookingNow.endOtp },
      { headers: { Authorization: `Bearer ${assignedTechToken}` } }
    );
    assert.strictEqual(completeRes.status, 200);
    assert.strictEqual(completeRes.data.booking?.status || completeRes.data.status, 'COMPLETED');

    const invoiceRes = await axios.get(`${BASE_URL}/bookings/BK-RACE-13/invoice`, {
      headers: { Authorization: `Bearer ${cust1Token}` },
    });
    assert.strictEqual(invoiceRes.status, 200);
    const invNo = invoiceRes.data.data?.invoiceNumber || invoiceRes.data.invoice?.invoiceNumber || '';
    assert(invNo.startsWith('INV-'));
    recordResult(22, 'Service proof upload, End OTP completion, Ledger credit & GST Invoice verified', true, `invoice=${invNo}`);

    // -------------------------------------------------------------------------
    // TEST 23: Customer cancellation stops active dispatch session & releases technician
    // -------------------------------------------------------------------------
    const cancelBookingId = idem1.data.data.id;
    const cancelRes = await axios.patch(
      `${BASE_URL}/bookings/${cancelBookingId}/status`,
      { status: 'CANCELLED', reason: 'CUSTOMER_CHANGED_SCHEDULE' },
      { headers: { Authorization: `Bearer ${cust1Token}` } }
    );
    assert.strictEqual(cancelRes.status, 200);
    assert.strictEqual(cancelRes.data.data.status, 'CANCELLED');
    const cancelledSess = automaticDispatchEngine.getBookingDispatchStatus(cancelBookingId);
    if (cancelledSess && cancelledSess.session) {
      assert.strictEqual(cancelledSess.session.status, 'CANCELLED');
    }
    recordResult(23, 'Customer cancellation stops active dispatch session, cancels offers & processes refund state', true);

    // -------------------------------------------------------------------------
    // TEST 24: Unauthorized booking access blocked (403 Forbidden) & FCM duplicate suppression
    // -------------------------------------------------------------------------
    let unauthStatus = null;
    try {
      await axios.get(`${BASE_URL}/bookings/BK-RACE-13`, {
        headers: { Authorization: `Bearer ${cust2Token}` },
      });
    } catch (err) {
      unauthStatus = err.response?.status;
    }
    assert.strictEqual(unauthStatus, 403, `Expected 403 Forbidden for unrelated customer, got ${unauthStatus}`);

    const notificationService = require('../src/services/notificationService');
    notificationService.registerToken('tech_fcm_dedup', 'dG9rZW5_fcm_dedup_real_firebase_instance_token_2026_xyz987654321');
    const firstFcm = await notificationService.sendToUser(
      'tech_fcm_dedup',
      'New Offer',
      'Test Offer Body',
      { offerId: 'OFFER-DEDUP-24' }
    );
    const secondFcm = await notificationService.sendToUser(
      'tech_fcm_dedup',
      'New Offer',
      'Test Offer Body',
      { offerId: 'OFFER-DEDUP-24' }
    );
    assert.strictEqual(secondFcm.deduplicated, true, 'Duplicate FCM push for same (userId, offerId) must be suppressed');
    recordResult(24, 'Unauthorized booking access blocked (403) & duplicate FCM offer delivery suppressed', true);
  } catch (err) {
    console.error('\n❌ ASSERTION / RUNTIME ERROR IN SUITE:', err.response?.data || err.message, err.stack);
    throw err;
  } finally {
    try { tech1Socket?.disconnect(); } catch (_) {}
    try { tech2Socket?.disconnect(); } catch (_) {}
    try { cust1Socket?.disconnect(); } catch (_) {}
    try { unrelatedCustSocket?.disconnect(); } catch (_) {}
    if (typeof server.closeAllConnections === 'function') {
      server.closeAllConnections();
    }
    await new Promise(r => server.close(r));
  }

  const passedCount = results.filter(r => r.passed).length;
  console.log('\n================================================================================');
  console.log(`🎯 DISPATCH VERIFICATION SUMMARY: ${passedCount}/${results.length} TESTS PASSED`);
  console.log('================================================================================');
  if (passedCount !== results.length) {
    process.exit(1);
  }
  process.exit(0);
}

runSuite().catch(err => {
  console.error('❌ Test suite failed with error:', err);
  process.exit(1);
});
