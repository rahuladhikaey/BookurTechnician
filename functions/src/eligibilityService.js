const { resolveCanonicalServiceId, doesTechnicianPossessVerifiedSkill } = require('./canonicalServices');

const DEFAULT_COVERAGE_RADIUS_KM = 15.0;
const DEFAULT_MAX_LOCATION_AGE_MS = 10 * 60 * 1000;
const ACTIVE_BOOKING_STATUSES = ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'TECHNICIAN_ARRIVED'];

function calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const c = Math.cos;
  const a = 0.5 - c((lat2 - lat1) * p) / 2 +
            c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * Math.asin(Math.sqrt(a));
}

function isValidCoordinates(lat, lng) {
  return (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat === 0 && lng === 0)
  );
}

/**
 * Authoritative single source of truth for Technician Eligibility (Phase 3).
 * Used identically by Availability queries, Dispatch offer generation, and Offer acceptance.
 */
function evaluateTechnicianEligibility(tech, options = {}) {
  const {
    techId: explicitTechId,
    serviceId = '',
    serviceName = '',
    customerCoordinates = null,
    busyTechSet = null,
    radiusKm = DEFAULT_COVERAGE_RADIUS_KM,
    maxLocationAgeMs = DEFAULT_MAX_LOCATION_AGE_MS,
    maxClockSkewMs = 2 * 60 * 1000,
    nowMs = Date.now(),
    requireCoverage = true,
  } = options;

  if (!tech || typeof tech !== 'object') {
    return { eligible: false, reason: 'TECHNICIAN_NOT_FOUND', distanceKm: null, skillMatch: false };
  }

  // 1. Authenticated technician exists
  const resolvedTechId = String(explicitTechId || tech.uid || tech.technicianId || tech.id || '').trim();
  if (!resolvedTechId) {
    return { eligible: false, reason: 'UNAUTHENTICATED_TECHNICIAN', distanceKm: null, skillMatch: false };
  }

  // 2. Account is ACTIVE (strictly requires explicit ACTIVE)
  const accStatus = String(tech.accountStatus || '').toUpperCase().trim();
  if (accStatus !== 'ACTIVE') {
    return { eligible: false, reason: 'ACCOUNT_NOT_ACTIVE', distanceKm: null, skillMatch: false };
  }

  // 3. KYC is VERIFIED or APPROVED (strictly requires explicit verification)
  const kycStatus = String(tech.kycStatus || '').toUpperCase().trim();
  if (kycStatus !== 'VERIFIED' && kycStatus !== 'APPROVED') {
    return { eligible: false, reason: 'KYC_NOT_VERIFIED', distanceKm: null, skillMatch: false };
  }

  // 4. Technician is online
  if (tech.isOnline !== true) {
    return { eligible: false, reason: 'TECHNICIAN_OFFLINE', distanceKm: null, skillMatch: false };
  }

  // 5. Availability is not OFFLINE or BUSY
  const availStatus = String(tech.availabilityStatus || 'AVAILABLE').toUpperCase().trim();
  if (availStatus === 'OFFLINE' || availStatus === 'BUSY') {
    return { eligible: false, reason: `AVAILABILITY_${availStatus}`, distanceKm: null, skillMatch: false };
  }

  // 6. No conflicting active booking exists
  if (tech.activeBookingId || (busyTechSet && busyTechSet.has(resolvedTechId))) {
    return { eligible: false, reason: 'ACTIVE_BOOKING_CONFLICT', distanceKm: null, skillMatch: false };
  }

  // 7 & 8. Location is valid and sufficiently recent
  const tLat = Number(tech.latitude ?? tech.currentLatitude);
  const tLng = Number(tech.longitude ?? tech.currentLongitude);
  if (!isValidCoordinates(tLat, tLng)) {
    return { eligible: false, reason: 'INVALID_LOCATION', distanceKm: null, skillMatch: false };
  }

  const lastUpdateRaw = tech.lastLocationUpdate;
  if (!lastUpdateRaw) {
    return { eligible: false, reason: 'MISSING_LOCATION_TIMESTAMP', distanceKm: null, skillMatch: false };
  }
  const lastUpdateMs = new Date(lastUpdateRaw).getTime();
  if (Number.isNaN(lastUpdateMs)) {
    return { eligible: false, reason: 'INVALID_LOCATION_TIMESTAMP', distanceKm: null, skillMatch: false };
  }
  const ageMs = nowMs - lastUpdateMs;
  if (ageMs > maxLocationAgeMs || ageMs < -maxClockSkewMs) {
    return { eligible: false, reason: 'STALE_LOCATION', distanceKm: null, skillMatch: false };
  }

  // 9. Technician is inside supported service coverage
  let distanceKm = null;
  if (customerCoordinates && isValidCoordinates(Number(customerCoordinates.latitude), Number(customerCoordinates.longitude))) {
    distanceKm = calculateHaversineDistanceKm(
      Number(customerCoordinates.latitude),
      Number(customerCoordinates.longitude),
      tLat,
      tLng
    );
    if (distanceKm > radiusKm) {
      return { eligible: false, reason: 'OUT_OF_COVERAGE', distanceKm, skillMatch: false };
    }
  } else if (requireCoverage) {
    return { eligible: false, reason: 'CUSTOMER_LOCATION_REQUIRED', distanceKm: null, skillMatch: false };
  }

  // 10. Requested canonical service skill exists, is verified, and enabled
  if (serviceId || serviceName) {
    const hasSkill = doesTechnicianPossessVerifiedSkill(tech, serviceId, serviceName);
    if (!hasSkill) {
      return { eligible: false, reason: 'SKILL_NOT_ELIGIBLE', distanceKm, skillMatch: false };
    }
  }

  return {
    eligible: true,
    reason: null,
    distanceKm: distanceKm !== null ? Math.round(distanceKm * 100) / 100 : null,
    skillMatch: true,
  };
}

async function getBusyTechnicianIds(db) {
  const activeBookingsQuery = await db.collection('bookings')
    .where('status', 'in', ACTIVE_BOOKING_STATUSES)
    .get();
  const busyTechSet = new Set();
  activeBookingsQuery.forEach((doc) => {
    const data = doc.data();
    const tId = data && data.technicianId;
    if (tId) busyTechSet.add(tId);
  });
  return busyTechSet;
}

async function getAvailableTechniciansForService(db, {
  serviceId = '',
  serviceName = '',
  latitude,
  longitude,
  radiusKm = DEFAULT_COVERAGE_RADIUS_KM,
  maxLocationAgeMs = DEFAULT_MAX_LOCATION_AGE_MS,
  nowMs = Date.now(),
}) {
  const custLat = Number(latitude);
  const custLng = Number(longitude);
  if (!isValidCoordinates(custLat, custLng)) {
    const err = new Error('Customer GPS coordinates required for coverage verification.');
    err.status = 400;
    err.code = 'LOCATION_UNAVAILABLE';
    throw err;
  }

  const [techSnap, busyTechSet] = await Promise.all([
    db.collection('technician_profiles').get(),
    getBusyTechnicianIds(db),
  ]);

  const results = [];
  for (const doc of techSnap.docs) {
    const tech = doc.data();
    const evalRes = evaluateTechnicianEligibility(tech, {
      techId: doc.id,
      serviceId,
      serviceName,
      customerCoordinates: { latitude: custLat, longitude: custLng },
      busyTechSet,
      radiusKm,
      maxLocationAgeMs,
      nowMs,
      requireCoverage: true,
    });
    if (!evalRes.eligible) continue;

    const digits = doc.id.replace(/\D/g, '');
    const techCode = tech.technicianCode || `BT-${digits.slice(-6).padStart(6, '0')}`;
    const distKm = evalRes.distanceKm ?? 0;

    // Redact PII: never return phone, email, UPI, KYC docs, or exact GPS coords
    results.push({
      technicianId: doc.id,
      technicianCode: techCode,
      fullName: tech.fullName || tech.name || 'Verified Partner',
      category: tech.category || '',
      profileImageUrl: tech.profileImageUrl || '',
      experienceYears: Number(tech.experienceYears) || 0,
      rating: Number(tech.rating) || 0,
      totalRatingsCount: Number(tech.totalRatingsCount) || 0,
      totalJobsCompleted: Number(tech.totalJobsCompleted) || 0,
      distanceKm: distKm,
      distanceMeters: Math.round(distKm * 1000),
      estimatedArrivalMinutes: Math.max(8, Math.round(distKm * 3.5)),
      isOnline: true,
      locationFresh: true,
      availabilityStatus: 'AVAILABLE',
    });
  }

  results.sort((a, b) => a.distanceKm - b.distanceKm);
  return results;
}

async function getCatalogAvailabilitySummary(db, {
  latitude,
  longitude,
  serviceId = '',
  serviceName = '',
  radiusKm = DEFAULT_COVERAGE_RADIUS_KM,
  maxLocationAgeMs = DEFAULT_MAX_LOCATION_AGE_MS,
  nowMs = Date.now(),
}) {
  const custLat = Number(latitude);
  const custLng = Number(longitude);
  if (!isValidCoordinates(custLat, custLng)) {
    const err = new Error('Customer GPS coordinates required for coverage verification.');
    err.status = 400;
    err.code = 'LOCATION_UNAVAILABLE';
    throw err;
  }

  const [techSnap, busyTechSet, catSnap] = await Promise.all([
    db.collection('technician_profiles').get(),
    getBusyTechnicianIds(db),
    db.collection('service_categories').get(),
  ]);

  // First filter technicians eligible across non-skill gates + coverage
  const pool = [];
  for (const doc of techSnap.docs) {
    const tech = doc.data();
    const baseEval = evaluateTechnicianEligibility(tech, {
      techId: doc.id,
      serviceId: '',
      serviceName: '',
      customerCoordinates: { latitude: custLat, longitude: custLng },
      busyTechSet,
      radiusKm,
      maxLocationAgeMs,
      nowMs,
      requireCoverage: true,
    });
    if (baseEval.eligible) {
      pool.push({ techId: doc.id, tech });
    }
  }

  const servicesList = [];
  const serviceCounts = {};

  for (const catDoc of catSnap.docs) {
    const cat = catDoc.data();
    const subcategories = Array.isArray(cat.subcategories) ? cat.subcategories : [];
    for (const sub of subcategories) {
      const srvs = Array.isArray(sub?.services) ? sub.services : [];
      for (const s of srvs) {
        const sId = s?.id ? String(s.id) : '';
        const sName = s?.name ? String(s.name) : '';
        if (!sId) continue;

        let count = 0;
        for (const item of pool) {
          if (doesTechnicianPossessVerifiedSkill(item.tech, sId, sName)) {
            count++;
          }
        }
        serviceCounts[sId] = count;
        const canonicalKey = resolveCanonicalServiceId(sId, sName);
        if (canonicalKey) serviceCounts[canonicalKey] = count;
        servicesList.push({ serviceId: sId, availableTechnicianCount: count });
      }
    }
  }

  let targetCount = 0;
  if (serviceId) {
    const canonicalTarget = resolveCanonicalServiceId(serviceId, serviceName);
    if (Object.prototype.hasOwnProperty.call(serviceCounts, serviceId)) {
      targetCount = serviceCounts[serviceId];
    } else if (canonicalTarget && Object.prototype.hasOwnProperty.call(serviceCounts, canonicalTarget)) {
      targetCount = serviceCounts[canonicalTarget];
    } else {
      for (const item of pool) {
        if (doesTechnicianPossessVerifiedSkill(item.tech, serviceId, serviceName)) {
          targetCount++;
        }
      }
    }
    if (!servicesList.some((e) => e.serviceId === serviceId)) {
      servicesList.push({ serviceId, availableTechnicianCount: targetCount });
    }
  }

  return {
    success: true,
    services: servicesList,
    data: servicesList,
    availableTechnicianCount: serviceId ? targetCount : pool.length,
    totalOnlineEligibleTechnicians: pool.length,
    count: serviceId ? targetCount : pool.length,
    isAuthoritative: true,
    isCached: false,
    verifiedAt: new Date(nowMs).toISOString(),
  };
}

module.exports = {
  DEFAULT_COVERAGE_RADIUS_KM,
  DEFAULT_MAX_LOCATION_AGE_MS,
  ACTIVE_BOOKING_STATUSES,
  calculateHaversineDistanceKm,
  isValidCoordinates,
  evaluateTechnicianEligibility,
  getBusyTechnicianIds,
  getAvailableTechniciansForService,
  getCatalogAvailabilitySummary,
};
