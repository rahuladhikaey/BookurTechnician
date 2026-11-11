// ============================================================================
// BOOKURTECHNICIAN - UBER / RAPIDO STYLE AUTOMATIC TECHNICIAN DISPATCH ENGINE
// Authoritative Eligibility, PostGIS + Haversine Spatial Discovery,
// Transparent Multi-Factor Ranking, Sequential Offer Cascade, Atomic Locking,
// Radius Expansion (3km -> 5km -> 10km -> 15km), and Full Audit Trail.
// ============================================================================

const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const postgres = require('../config/postgres');
const redis = require('../config/redis');
const bookingsStore = require('../config/bookingsStore');
const firestoreSync = require('../config/firestoreSync');
const notificationService = require('./notificationService');
const emailService = require('./emailService');
const {
  inMemorySkills,
  inMemoryDocs,
  inMemoryTechProfiles,
  setTechnicianProfile,
} = require('../config/inMemoryTechStore');

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

// ─── AUTHORITATIVE IN-MEMORY + PERSISTENT STORES ────────────────────────────
const dispatchSessionsStore = new Map(); // bookingId -> session
const dispatchOffersStore = new Map(); // offerId -> offer
const technicianAvailabilityStore = new Map(); // technicianId -> Map(dayOfWeek -> availability)
const technicianSkillsStore = new Map(); // technicianId -> Map(serviceId -> skillRecord)
const technicianLocationsHistory = []; // persistent location log
const dispatchAuditLogsStore = []; // audit log entries
const activeOfferTimers = new Map(); // offerId -> NodeJS.Timeout
const bookingLocks = new Set(); // bookingId atomic mutex lock for simultaneous accept prevention

// ─── ADMIN CONFIGURABLE DISPATCH SETTINGS ───────────────────────────────────
let dispatchConfig = {
  radiiKm: [3, 5, 10, 15],
  offerTimeoutSeconds: 20,
  maxRetriesPerRadius: 1,
  maxTotalAttempts: 12,
  autoDispatchEnabled: true,
  gpsFreshnessThresholdSeconds: 600,
  scheduledPreDispatchMinutes: 60,
  defaultAppointmentDurationMinutes: 60,
  rankingWeights: {
    etaDistance: 0.35,
    skillMatch: 0.25,
    availability: 0.20,
    rating: 0.10,
    reliability: 0.10,
  },
};

function getDispatchConfig() {
  return JSON.parse(JSON.stringify(dispatchConfig));
}

function updateDispatchConfig(partial = {}, actorId = 'admin', actorRole = 'ADMIN') {
  const before = getDispatchConfig();
  if (Array.isArray(partial.radiiKm) && partial.radiiKm.length > 0) {
    dispatchConfig.radiiKm = partial.radiiKm.map(Number).filter(n => n > 0 && n <= 50);
  }
  if (partial.offerTimeoutSeconds != null) {
    const t = Number(partial.offerTimeoutSeconds);
    if (!Number.isNaN(t) && t >= 1 && t <= 120) {
      dispatchConfig.offerTimeoutSeconds = t;
    }
  }
  if (partial.maxRetriesPerRadius != null) {
    const r = Number(partial.maxRetriesPerRadius);
    if (!Number.isNaN(r) && r >= 1 && r <= 5) {
      dispatchConfig.maxRetriesPerRadius = r;
    }
  }
  if (partial.maxTotalAttempts != null) {
    const m = Number(partial.maxTotalAttempts);
    if (!Number.isNaN(m) && m >= 1 && m <= 50) {
      dispatchConfig.maxTotalAttempts = m;
    }
  }
  if (typeof partial.autoDispatchEnabled === 'boolean') {
    dispatchConfig.autoDispatchEnabled = partial.autoDispatchEnabled;
  }
  if (partial.gpsFreshnessThresholdSeconds != null) {
    const g = Number(partial.gpsFreshnessThresholdSeconds);
    if (!Number.isNaN(g) && g >= 10) {
      dispatchConfig.gpsFreshnessThresholdSeconds = g;
    }
  }
  if (partial.rankingWeights && typeof partial.rankingWeights === 'object') {
    dispatchConfig.rankingWeights = {
      ...dispatchConfig.rankingWeights,
      ...partial.rankingWeights,
    };
  }

  recordAuditLog({
    bookingId: 'GLOBAL_CONFIG',
    actorId,
    actorRole,
    eventType: 'DISPATCH_CONFIG_UPDATED',
    details: { before, after: getDispatchConfig() },
  });

  return getDispatchConfig();
}

// ─── HELPER: HAVERSINE DISTANCE & APPROXIMATE AREA MASKING ──────────────────
function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const toRad = (v) => (v * Math.PI) / 180;
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return parseFloat((R * c).toFixed(2));
}

/**
 * Masks exact customer street/flat address into an approximate neighborhood/area
 * so customer PII is protected prior to technician assignment (Section 6 & 21).
 */
function maskApproximateArea(fullAddress) {
  if (!fullAddress || typeof fullAddress !== 'string') return 'Nearby Service Area';
  const parts = fullAddress.split(',').map(p => p.trim()).filter(Boolean);
  if (parts.length >= 3) {
    return parts.slice(-3).join(', ');
  }
  if (parts.length === 2) {
    return parts[1];
  }
  // Strip leading house/flat numbers if single segment
  return fullAddress.replace(/^[0-9A-Za-z/-]+\s+/, '').trim() || 'Nearby Service Area';
}

/**
 * Validates whether a token is a real, non-synthetic FCM device token (Section 3 & 9)
 */
function isValidFcmToken(token) {
  if (!token || typeof token !== 'string') return false;
  const trimmed = token.trim();
  if (trimmed.length < 12) return false;
  const lower = trimmed.toLowerCase();
  if (
    lower.startsWith('fake_') ||
    lower.startsWith('mock_') ||
    lower.startsWith('dummy_') ||
    lower.startsWith('synthetic_') ||
    lower === 'null' ||
    lower === 'undefined'
  ) {
    return false;
  }
  return true;
}

function getTechnicianValidFcmTokens(techProfile) {
  const tokens = [];
  if (techProfile?.fcmToken && isValidFcmToken(techProfile.fcmToken)) {
    tokens.push(techProfile.fcmToken.trim());
  }
  if (techProfile?.fcm_token && isValidFcmToken(techProfile.fcm_token)) {
    tokens.push(techProfile.fcm_token.trim());
  }
  if (Array.isArray(techProfile?.deviceTokens)) {
    techProfile.deviceTokens.forEach(t => {
      if (isValidFcmToken(t)) tokens.push(t.trim());
    });
  }
  if (Array.isArray(techProfile?.device_tokens)) {
    techProfile.device_tokens.forEach(t => {
      if (isValidFcmToken(t)) tokens.push(t.trim());
    });
  }
  const storedTokens = notificationService.deviceTokens?.get(techProfile?.id || techProfile?.technicianId);
  if (Array.isArray(storedTokens)) {
    storedTokens.forEach(t => {
      if (isValidFcmToken(t)) tokens.push(t.trim());
    });
  }
  return [...new Set(tokens)];
}

// ─── AUDIT LOGGING ──────────────────────────────────────────────────────────
async function recordAuditLog({
  bookingId,
  sessionId = null,
  offerId = null,
  technicianId = null,
  actorId = 'SYSTEM',
  actorRole = 'SYSTEM',
  eventType,
  details = {},
}) {
  const entry = {
    id: `daudit_${uuidv4().slice(0, 12)}`,
    bookingId: String(bookingId || 'UNKNOWN'),
    sessionId,
    offerId,
    technicianId,
    actorId,
    actorRole,
    eventType,
    details,
    createdAt: new Date().toISOString(),
  };

  dispatchAuditLogsStore.unshift(entry);
  if (dispatchAuditLogsStore.length > 2000) {
    dispatchAuditLogsStore.pop();
  }

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `INSERT INTO dispatch_audit_logs (id, booking_id, session_id, offer_id, technician_id, actor_id, actor_role, event_type, details, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, NOW())`,
        [
          entry.id,
          entry.bookingId,
          entry.sessionId,
          entry.offerId,
          entry.technicianId,
          entry.actorId,
          entry.actorRole,
          entry.eventType,
          JSON.stringify(entry.details || {}),
        ]
      );
    } catch (_) {}
  }

  firestoreSync.upsertDocument('dispatch_audit_logs', entry.id, entry).catch(() => {});
  return entry;
}

// ─── TECHNICIAN AVAILABILITY & SKILLS MANAGEMENT (Section 3 & 14) ───────────
async function setTechnicianAvailability(technicianId, scheduleList = []) {
  if (!technicianId) throw new Error('technicianId is required');
  if (!technicianAvailabilityStore.has(technicianId)) {
    technicianAvailabilityStore.set(technicianId, new Map());
  }
  const dayMap = technicianAvailabilityStore.get(technicianId);

  const saved = [];
  for (const item of scheduleList) {
    const dayOfWeek = Number(item.dayOfWeek ?? item.day_of_week ?? new Date().getDay());
    const record = {
      id: item.id || `avail_${technicianId}_${dayOfWeek}`,
      technicianId,
      dayOfWeek,
      startTime: item.startTime || item.start_time || '08:00',
      endTime: item.endTime || item.end_time || '21:00',
      isAvailable: item.isAvailable !== false && item.is_available !== false,
      unavailableFrom: item.unavailableFrom || item.unavailable_from || null,
      unavailableUntil: item.unavailableUntil || item.unavailable_until || null,
      maxConcurrentJobs: Number(item.maxConcurrentJobs || 1),
      updatedAt: new Date().toISOString(),
    };
    dayMap.set(dayOfWeek, record);
    saved.push(record);

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(
          `INSERT INTO technician_availability (id, technician_id, day_of_week, start_time, end_time, is_available, unavailable_from, unavailable_until, max_concurrent_jobs, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
           ON CONFLICT (technician_id, day_of_week) DO UPDATE
           SET start_time = EXCLUDED.start_time,
               end_time = EXCLUDED.end_time,
               is_available = EXCLUDED.is_available,
               unavailable_from = EXCLUDED.unavailable_from,
               unavailable_until = EXCLUDED.unavailable_until,
               max_concurrent_jobs = EXCLUDED.max_concurrent_jobs,
               updated_at = NOW();`,
          [
            record.id,
            technicianId,
            record.dayOfWeek,
            record.startTime,
            record.endTime,
            record.isAvailable,
            record.unavailableFrom,
            record.unavailableUntil,
            record.maxConcurrentJobs,
          ]
        );
      } catch (_) {}
    }
  }
  return saved;
}

function getTechnicianAvailability(technicianId) {
  const dayMap = technicianAvailabilityStore.get(technicianId);
  if (!dayMap) return [];
  return Array.from(dayMap.values());
}

async function setTechnicianServiceSkill(technicianId, { serviceId, categoryId = null, proficiencyLevel = 'EXPERT', isVerified = true, active = true }) {
  if (!technicianId || !serviceId) return null;
  if (!technicianSkillsStore.has(technicianId)) {
    technicianSkillsStore.set(technicianId, new Map());
  }
  const skillMap = technicianSkillsStore.get(technicianId);
  const normServiceId = String(serviceId).trim().toLowerCase();
  const record = {
    id: `tskill_${technicianId}_${normServiceId}`,
    technicianId,
    serviceId: String(serviceId).trim(),
    categoryId: categoryId ? String(categoryId).trim() : null,
    proficiencyLevel,
    isVerified: isVerified !== false,
    active: active !== false,
    createdAt: new Date().toISOString(),
  };
  skillMap.set(normServiceId, record);

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `INSERT INTO technician_service_skills (id, technician_id, service_id, category_id, proficiency_level, is_verified, active, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
         ON CONFLICT (technician_id, service_id) DO UPDATE
         SET category_id = EXCLUDED.category_id,
             proficiency_level = EXCLUDED.proficiency_level,
             is_verified = EXCLUDED.is_verified,
             active = EXCLUDED.active;`,
        [record.id, technicianId, record.serviceId, record.categoryId, record.proficiencyLevel, record.isVerified, record.active]
      );
    } catch (_) {}
  }
  return record;
}

// ─── PARSE APPOINTMENT TIME WINDOW ──────────────────────────────────────────
function parseAppointmentWindow(dateStr, slotStr, durationMinutes = 60) {
  const now = new Date();
  let start = new Date(now);

  if (dateStr && /^\d{4}-\d{2}-\d{2}$/.test(String(dateStr).trim())) {
    const [y, m, d] = String(dateStr).trim().split('-').map(Number);
    start = new Date(y, m - 1, d, 10, 0, 0, 0);
  }

  if (slotStr && typeof slotStr === 'string') {
    const match = slotStr.match(/(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?/i);
    if (match) {
      let hour = parseInt(match[1], 10);
      const minute = parseInt(match[2] || '0', 10);
      const ampm = (match[3] || '').toUpperCase();
      if (ampm === 'PM' && hour < 12) hour += 12;
      if (ampm === 'AM' && hour === 12) hour = 0;
      start.setHours(hour, minute, 0, 0);
    }
  }

  const end = new Date(start.getTime() + durationMinutes * 60 * 1000);
  const hh = String(start.getHours()).padStart(2, '0');
  const mm = String(start.getMinutes()).padStart(2, '0');
  const endHh = String(end.getHours()).padStart(2, '0');
  const endMm = String(end.getMinutes()).padStart(2, '0');

  return {
    start,
    end,
    dayOfWeek: start.getDay(),
    startTimeHhMm: `${hh}:${mm}`,
    endTimeHhMm: `${endHh}:${endMm}`,
  };
}

// ─── CHECK WORKING HOURS & SCHEDULED SLOT AVAILABILITY (Section 3 & 14) ─────
function checkTechnicianScheduleWindow(techProfile, bookingParams) {
  const techId = techProfile.id || techProfile.technicianId;
  const isScheduled = String(bookingParams.bookingMode || 'INSTANT').toUpperCase() === 'SCHEDULED';
  const windowInfo = parseAppointmentWindow(
    bookingParams.scheduleDate || bookingParams.date,
    bookingParams.scheduleSlot || bookingParams.timeSlot,
    bookingParams.durationMinutes || dispatchConfig.defaultAppointmentDurationMinutes
  );

  // Check explicit availability rows if configured for this technician
  const dayMap = technicianAvailabilityStore.get(techId);
  if (dayMap && dayMap.has(windowInfo.dayOfWeek)) {
    const dayAvail = dayMap.get(windowInfo.dayOfWeek);
    if (!dayAvail.isAvailable) {
      return { available: false, reason: 'DAY_MARKED_UNAVAILABLE' };
    }
    if (windowInfo.startTimeHhMm < dayAvail.startTime || windowInfo.endTimeHhMm > dayAvail.endTime) {
      return {
        available: false,
        reason: `OUTSIDE_WORKING_HOURS (${dayAvail.startTime}-${dayAvail.endTime})`,
      };
    }
    if (dayAvail.unavailableFrom && dayAvail.unavailableUntil) {
      const uFrom = new Date(dayAvail.unavailableFrom);
      const uUntil = new Date(dayAvail.unavailableUntil);
      if (windowInfo.start < uUntil && windowInfo.end > uFrom) {
        return { available: false, reason: 'IN_UNAVAILABLE_PERIOD' };
      }
    }
  } else if (techProfile.workingHours && typeof techProfile.workingHours === 'object') {
    const startH = techProfile.workingHours.startTime || '08:00';
    const endH = techProfile.workingHours.endTime || '21:00';
    if (windowInfo.startTimeHhMm < startH || windowInfo.endTimeHhMm > endH) {
      return { available: false, reason: `OUTSIDE_PROFILE_WORKING_HOURS (${startH}-${endH})` };
    }
  }

  // For instant bookings, technician MUST be currently online and AVAILABLE
  if (!isScheduled) {
    const isOnline = techProfile.isOnline === true || techProfile.is_online === true || techProfile.online === true;
    if (!isOnline) {
      return { available: false, reason: 'TECHNICIAN_OFFLINE' };
    }
    const availStatus = String(techProfile.availabilityStatus || techProfile.availability_status || 'AVAILABLE').toUpperCase();
    if (availStatus !== 'AVAILABLE') {
      return { available: false, reason: `TECHNICIAN_STATUS_${availStatus}` };
    }
  } else {
    // Scheduled booking: check if technician is explicitly marked unavailable for scheduled slots
    if (techProfile.acceptsScheduledBookings === false) {
      return { available: false, reason: 'DOES_NOT_ACCEPT_SCHEDULED_BOOKINGS' };
    }
  }

  return { available: true, windowInfo };
}

// ─── CHECK CONFLICTING ACTIVE / SCHEDULED BOOKINGS (Section 3, 7 & 14) ──────
function hasConflictingBooking(techId, bookingParams, excludeBookingId = null) {
  const allBookings = bookingsStore.getAllBookings();
  const activeStatuses = new Set([
    'ASSIGNED',
    'TECHNICIAN_ASSIGNED',
    'ACCEPTED',
    'TECHNICIAN_ON_THE_WAY',
    'ARRIVED',
    'TECHNICIAN_ARRIVED',
    'IN_PROGRESS',
    'SERVICE_STARTED',
  ]);

  const isScheduled = String(bookingParams.bookingMode || 'INSTANT').toUpperCase() === 'SCHEDULED';
  const reqWindow = parseAppointmentWindow(
    bookingParams.scheduleDate || bookingParams.date,
    bookingParams.scheduleSlot || bookingParams.timeSlot,
    bookingParams.durationMinutes || dispatchConfig.defaultAppointmentDurationMinutes
  );

  for (const b of allBookings) {
    if (!b || b.id === excludeBookingId || b.bookingCode === excludeBookingId) continue;
    if (b.technicianId !== techId) continue;
    const st = String(b.status || '').toUpperCase();
    if (!activeStatuses.has(st)) continue;

    // If instant booking, ANY active ongoing job is a conflict
    if (!isScheduled) {
      const bMode = String(b.bookingMode || 'INSTANT').toUpperCase();
      if (bMode === 'INSTANT' || ['TECHNICIAN_ON_THE_WAY', 'ARRIVED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS', 'SERVICE_STARTED'].includes(st)) {
        return { conflict: true, conflictingBookingId: b.id, reason: `ACTIVE_ONGOING_BOOKING_${b.id}` };
      }
    }

    // Check appointment date & slot overlap
    const bWindow = parseAppointmentWindow(
      b.scheduleDate || b.date,
      b.scheduleSlot || b.timeSlot,
      b.durationMinutes || dispatchConfig.defaultAppointmentDurationMinutes
    );
    if (reqWindow.start < bWindow.end && reqWindow.end > bWindow.start) {
      return { conflict: true, conflictingBookingId: b.id, reason: `OVERLAPPING_TIME_SLOT_WITH_${b.id}` };
    }
  }

  // Also check if technician currently has an ACCEPTED offer in another active dispatch session
  for (const [bId, session] of dispatchSessionsStore.entries()) {
    if (bId === excludeBookingId) continue;
    if (session.status === 'ASSIGNED' && session.assignedTechnicianId === techId) {
      const existingBooking = bookingsStore.getBookingById(bId);
      if (existingBooking) {
        const st = String(existingBooking.status || '').toUpperCase();
        if (['COMPLETED', 'CANCELLED', 'REJECTED', 'FAILED', 'NO_TECHNICIAN_AVAILABLE'].includes(st)) {
          continue;
        }
      }
      if (!isScheduled && String(session.bookingMode || 'INSTANT').toUpperCase() === 'INSTANT') {
        return { conflict: true, conflictingBookingId: bId, reason: `ASSIGNED_SESSION_${bId}` };
      }
    }
  }

  return { conflict: false };
}

// ─── CHECK SKILL & SERVICE MATCH (Section 3 & 5) ────────────────────────────
function checkTechnicianSkillMatch(techProfile, { serviceId, serviceName, category }) {
  const techId = techProfile.id || techProfile.technicianId;
  const reqServiceId = String(serviceId || '').trim().toLowerCase();
  const reqServiceName = String(serviceName || '').trim().toLowerCase();
  const reqCategory = String(category || '').trim().toLowerCase()
    .replace(/^cat_/, '')
    .replace(/^category_/, '')
    .replace(/_services$/, '')
    .replace(/_repair$/, '');

  // 1. Check explicit technician_service_skills store
  const explicitSkillsMap = technicianSkillsStore.get(techId);
  if (explicitSkillsMap && explicitSkillsMap.size > 0) {
    if (reqServiceId && explicitSkillsMap.has(reqServiceId)) {
      const skillObj = explicitSkillsMap.get(reqServiceId);
      if (skillObj.active && skillObj.isVerified) {
        return { matched: true, matchQuality: 1.0, matchType: 'EXACT_SERVICE_SKILL' };
      }
      return { matched: false, reason: 'SKILL_INACTIVE_OR_UNVERIFIED' };
    }
    // Check if any active verified skill matches serviceId or categoryId
    for (const [, skillObj] of explicitSkillsMap.entries()) {
      if (!skillObj.active || !skillObj.isVerified) continue;
      const sId = String(skillObj.serviceId || '').toLowerCase();
      const cId = String(skillObj.categoryId || '').toLowerCase();
      if (reqServiceId && sId === reqServiceId) {
        return { matched: true, matchQuality: 1.0, matchType: 'EXACT_SERVICE_SKILL' };
      }
      if (reqServiceName && sId === reqServiceName) {
        return { matched: true, matchQuality: 0.95, matchType: 'SERVICE_NAME_SKILL' };
      }
      if (reqCategory && cId && (cId.includes(reqCategory) || reqCategory.includes(cId))) {
        return { matched: true, matchQuality: 0.9, matchType: 'CATEGORY_SKILL_RECORD' };
      }
    }
    return { matched: false, reason: 'MISSING_REQUIRED_SERVICE_SKILL' };
  }

  // 2. Check inMemorySkills (from technicianController saveSkillsBulk)
  const memSkills = inMemorySkills.get(techId);
  if (Array.isArray(memSkills) && memSkills.length > 0) {
    const activeSkills = memSkills.filter(s => s.active !== false && s.verificationStatus !== 'REJECTED');
    for (const s of activeSkills) {
      const sId = String(s.serviceId || s.id || '').toLowerCase();
      const sName = String(s.name || s.serviceName || '').toLowerCase();
      if (reqServiceId && sId === reqServiceId) {
        return { matched: true, matchQuality: 1.0, matchType: 'DECLARED_SERVICE_ID' };
      }
      if (reqServiceName && sName && (sName === reqServiceName || sName.includes(reqServiceName) || reqServiceName.includes(sName))) {
        return { matched: true, matchQuality: 0.95, matchType: 'DECLARED_SERVICE_NAME' };
      }
    }
    return { matched: false, reason: 'SERVICE_NOT_IN_DECLARED_SKILLS' };
  }

  // 3. Check profile skills array & category
  const profileSkills = Array.isArray(techProfile.skills) ? techProfile.skills.map(s => String(s).toLowerCase()) : [];
  if (profileSkills.length > 0) {
    if (reqServiceId && profileSkills.includes(reqServiceId)) {
      return { matched: true, matchQuality: 1.0, matchType: 'PROFILE_SKILL_ID' };
    }
    if (reqServiceName && profileSkills.some(s => s === reqServiceName || s.includes(reqServiceName) || reqServiceName.includes(s))) {
      return { matched: true, matchQuality: 0.95, matchType: 'PROFILE_SKILL_NAME' };
    }
    if (reqCategory && profileSkills.some(s => s.includes(reqCategory) || reqCategory.includes(s))) {
      return { matched: true, matchQuality: 0.85, matchType: 'PROFILE_SKILL_CATEGORY' };
    }
  }

  // 4. Check primary category match
  const techCat = String(techProfile.category || '').trim().toLowerCase()
    .replace(/^cat_/, '')
    .replace(/^category_/, '')
    .replace(/_services$/, '')
    .replace(/_repair$/, '');

  const categoryAliases = {
    ac: ['ac', 'air_conditioner', 'appliance', 'cooling', 'hvac'],
    electrical: ['electrical', 'electrician', 'wiring'],
    plumbing: ['plumbing', 'plumber', 'pipe', 'water'],
    cleaning: ['cleaning', 'cleaner', 'deep_cleaning'],
    carpentry: ['carpentry', 'carpenter', 'furniture', 'wood'],
    ro: ['ro', 'water_purifier', 'appliance'],
    appliance: ['appliance', 'washing_machine', 'refrigerator', 'microwave', 'geyser', 'tv'],
    painting: ['painting', 'painter'],
  };

  if (techCat && reqCategory) {
    if (techCat === reqCategory || techCat.includes(reqCategory) || reqCategory.includes(techCat)) {
      return { matched: true, matchQuality: 0.85, matchType: 'PRIMARY_CATEGORY_MATCH' };
    }
    for (const [, group] of Object.entries(categoryAliases)) {
      const techInGroup = group.some(g => techCat.includes(g));
      const reqInGroup = group.some(g => reqCategory.includes(g));
      if (techInGroup && reqInGroup) {
        return { matched: true, matchQuality: 0.85, matchType: 'CATEGORY_FAMILY_MATCH' };
      }
    }
  }

  return { matched: false, reason: 'SKILL_AND_CATEGORY_MISMATCH' };
}

// ─── 10-POINT MANDATORY TECHNICIAN ELIGIBILITY ENGINE (Section 3) ───────────
function evaluateTechnicianEligibility(techProfile, bookingParams, radiusKm = 3) {
  const reasons = [];
  if (!techProfile) {
    return { eligible: false, reasons: ['PROFILE_NOT_FOUND'] };
  }

  const techId = techProfile.id || techProfile.technicianId;

  // 1. Account verified (kyc_status === 'VERIFIED' / 'Approved')
  const kycStatus = String(techProfile.kycStatus || techProfile.kyc_status || '').toUpperCase();
  if (kycStatus !== 'VERIFIED' && kycStatus !== 'APPROVED') {
    reasons.push('KYC_NOT_VERIFIED');
  }

  // 2. Technician is active
  const accountStatus = String(techProfile.accountStatus || techProfile.account_status || 'Active').toUpperCase();
  const isActive = techProfile.isActive !== false && techProfile.is_active !== false && accountStatus === 'ACTIVE';
  if (!isActive) {
    reasons.push('ACCOUNT_INACTIVE');
  }

  // 3. Technician is not suspended
  const isSuspended =
    techProfile.isSuspended === true ||
    techProfile.is_suspended === true ||
    techProfile.isCodSuspended === true ||
    techProfile.is_cod_suspended === true ||
    accountStatus === 'SUSPENDED' ||
    accountStatus === 'BLOCKED';
  if (isSuspended) {
    reasons.push('TECHNICIAN_SUSPENDED');
  }

  // 4. Technician has completed required onboarding
  const onboardingDone = techProfile.onboardingCompleted !== false && techProfile.onboarding_completed !== false;
  if (!onboardingDone) {
    reasons.push('ONBOARDING_INCOMPLETE');
  }

  // 5. Technician has required service skill
  const skillCheck = checkTechnicianSkillMatch(techProfile, {
    serviceId: bookingParams.serviceId,
    serviceName: bookingParams.serviceName || bookingParams.service,
    category: bookingParams.category,
  });
  if (!skillCheck.matched) {
    reasons.push(skillCheck.reason || 'SKILL_MISMATCH');
  }

  // 6 & 9. Valid GPS coordinates & supports customer's service location
  const custLat = Number(bookingParams.latitude);
  const custLng = Number(bookingParams.longitude);
  const techLat = Number(techProfile.latitude ?? techProfile.current_latitude ?? techProfile.currentLatitude);
  const techLng = Number(techProfile.longitude ?? techProfile.current_longitude ?? techProfile.currentLongitude);

  let distanceKm = null;
  if (
    Number.isNaN(techLat) ||
    Number.isNaN(techLng) ||
    (techLat === 0 && techLng === 0) ||
    techLat < -90 ||
    techLat > 90 ||
    techLng < -180 ||
    techLng > 180
  ) {
    reasons.push('INVALID_OR_MISSING_GPS_COORDINATES');
  } else {
    distanceKm = haversineDistanceKm(custLat, custLng, techLat, techLng);
    const techMaxRadius = Number(techProfile.serviceRadiusKm ?? techProfile.service_radius_km ?? 15);
    if (distanceKm > radiusKm) {
      reasons.push(`OUTSIDE_SEARCH_RADIUS_${radiusKm}KM (dist=${distanceKm}km)`);
    } else if (distanceKm > techMaxRadius) {
      reasons.push(`OUTSIDE_TECHNICIAN_SERVICE_RADIUS_${techMaxRadius}KM`);
    }

    // Condition 9b: Recent GPS coordinates for instant dispatch
    const isScheduled = String(bookingParams.bookingMode || 'INSTANT').toUpperCase() === 'SCHEDULED';
    if (!isScheduled) {
      const lastLocTs = techProfile.lastLocationUpdate || techProfile.last_location_update || techProfile.updatedAt;
      if (lastLocTs) {
        const ageSec = (Date.now() - new Date(lastLocTs).getTime()) / 1000;
        if (ageSec > dispatchConfig.gpsFreshnessThresholdSeconds) {
          reasons.push(`STALE_GPS_COORDINATES (${Math.round(ageSec)}s old)`);
        }
      }
    }
  }

  // 7. Technician is available at requested date & time
  const scheduleCheck = checkTechnicianScheduleWindow(techProfile, bookingParams);
  if (!scheduleCheck.available) {
    reasons.push(scheduleCheck.reason);
  }

  // 8. Technician has no conflicting active booking
  const conflictCheck = hasConflictingBooking(techId, bookingParams, bookingParams.bookingId || bookingParams.id);
  if (conflictCheck.conflict) {
    reasons.push(conflictCheck.reason);
  }

  // Also check if technician is already holding a live SENT offer for another booking
  for (const [, offer] of dispatchOffersStore.entries()) {
    if (
      offer.technicianId === techId &&
      offer.bookingId !== (bookingParams.bookingId || bookingParams.id) &&
      offer.status === 'SENT' &&
      new Date(offer.expiresAt).getTime() > Date.now()
    ) {
      reasons.push(`HOLDING_ACTIVE_OFFER_${offer.id}`);
      break;
    }
  }

  // 10. Background FCM token registration (optional for foreground online dispatch)
  const validTokens = getTechnicianValidFcmTokens(techProfile);

  const etaMinutes = distanceKm != null ? Math.max(2, Math.round((distanceKm / 25) * 60)) : null;

  return {
    eligible: reasons.length === 0,
    reasons,
    distanceKm,
    etaMinutes,
    etaSource: 'HAVERSINE_ESTIMATE',
    skillMatchQuality: skillCheck.matchQuality || 0,
    skillMatchType: skillCheck.matchType || 'NONE',
    validFcmTokens: validTokens,
  };
}

// ─── GATHER ALL REGISTERED TECHNICIAN PROFILES (PG + IN-MEMORY + FIRESTORE) ─
async function loadAllCandidateTechnicianProfiles(bookingParams, radiusKm) {
  const mergedMap = new Map();

  // 1. Load from inMemoryTechProfiles
  for (const [id, profile] of inMemoryTechProfiles.entries()) {
    mergedMap.set(id, { ...profile, id: profile.id || id, technicianId: profile.technicianId || id });
  }

  // 2. Query Cloud Firestore technician_profiles
  try {
    const fsProfiles = await firestoreSync.listCollection('technician_profiles');
    if (Array.isArray(fsProfiles)) {
      for (const fp of fsProfiles) {
        const id = fp.id || fp.technicianId || fp.uid;
        if (!id) continue;
        const existing = mergedMap.get(id) || {};
        mergedMap.set(id, {
          ...existing,
          ...fp,
          id,
          technicianId: id,
          technicianCode: fp.technicianCode || existing.technicianCode,
          name: fp.fullName || fp.name || existing.name || existing.fullName,
          fullName: fp.fullName || fp.name || existing.fullName || existing.name,
          phone: fp.phone || fp.phoneNumber || existing.phone,
          category: fp.category || fp.serviceCategory || existing.category || 'ELECTRICIAN',
          skills: Array.isArray(fp.skills) ? fp.skills : (fp.selectedSkills || existing.skills || []),
          kycStatus: fp.kycStatus || existing.kycStatus || 'VERIFIED',
          accountStatus: fp.accountStatus || existing.accountStatus || 'Active',
          isOnline: fp.isOnline === true || fp.online === true || existing.isOnline,
          availabilityStatus: fp.availabilityStatus || existing.availabilityStatus || 'AVAILABLE',
          latitude: fp.latitude ?? fp.currentLatitude ?? existing.latitude,
          longitude: fp.longitude ?? fp.currentLongitude ?? existing.longitude,
          lastLocationUpdate: fp.lastLocationUpdate || existing.lastLocationUpdate || new Date().toISOString(),
          rating: parseFloat(fp.rating ?? existing.rating ?? 4.85),
          totalJobsCompleted: parseInt(fp.totalJobsCompleted ?? fp.completedJobs ?? existing.totalJobsCompleted ?? 0, 10),
          isSuspended: Boolean(fp.isSuspended || existing.isSuspended),
          onboardingCompleted: fp.onboardingCompleted ?? existing.onboardingCompleted ?? true,
          serviceRadiusKm: parseFloat(fp.serviceRadiusKm ?? existing.serviceRadiusKm ?? 15),
          acceptanceRate: parseFloat(fp.acceptanceRate ?? existing.acceptanceRate ?? 95),
          fcmToken: fp.fcmToken || fp.fcm_token || existing.fcmToken,
          deviceTokens: fp.deviceTokens || existing.deviceTokens || [],
        });
      }
    }
  } catch (_) {}

  // 2. Query PostgreSQL + PostGIS if connected
  if (postgres.isPgHealthy()) {
    try {
      const custLat = Number(bookingParams.latitude);
      const custLng = Number(bookingParams.longitude);
      const radiusMeters = radiusKm * 1000;

      const sql = `
        SELECT
          tp.*,
          u.device_tokens AS user_device_tokens,
          u.is_suspended AS user_is_suspended,
          CASE
            WHEN tp.location IS NOT NULL THEN
              ROUND((ST_Distance(tp.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000.0)::numeric, 2)
            ELSE NULL
          END AS postgis_distance_km
        FROM technician_profiles tp
        LEFT JOIN users u ON (u.id = tp.technician_id OR u.phone = tp.phone)
        WHERE
          (
            (tp.location IS NOT NULL AND ST_DWithin(tp.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3))
            OR (tp.current_latitude IS NOT NULL AND tp.current_longitude IS NOT NULL)
          )
      `;
      const res = await postgres.query(sql, [custLng, custLat, radiusMeters]);
      for (const row of res.rows || []) {
        const id = row.technician_id || row.id;
        const existing = mergedMap.get(id) || {};
        mergedMap.set(id, {
          ...existing,
          id,
          technicianId: id,
          technicianCode: row.technician_code || existing.technicianCode,
          name: row.full_name || existing.name || existing.fullName,
          fullName: row.full_name || existing.fullName || existing.name,
          phone: row.phone || existing.phone,
          category: row.category || existing.category,
          skills: Array.isArray(row.skills) ? row.skills : (existing.skills || []),
          kycStatus: row.kyc_status || existing.kycStatus,
          accountStatus: row.account_status || existing.accountStatus || 'Active',
          isOnline: row.is_online ?? existing.isOnline,
          availabilityStatus: row.availability_status || existing.availabilityStatus || 'AVAILABLE',
          latitude: row.current_latitude ?? existing.latitude,
          longitude: row.current_longitude ?? existing.longitude,
          lastLocationUpdate: row.last_location_update || existing.lastLocationUpdate,
          rating: parseFloat(row.rating ?? existing.rating ?? 4.85),
          totalJobsCompleted: parseInt(row.total_jobs_completed ?? existing.totalJobsCompleted ?? 0, 10),
          isSuspended: Boolean(row.is_suspended || row.user_is_suspended || existing.isSuspended),
          onboardingCompleted: row.onboarding_completed ?? existing.onboardingCompleted ?? true,
          serviceRadiusKm: parseFloat(row.service_radius_km ?? existing.serviceRadiusKm ?? 15),
          acceptanceRate: parseFloat(row.acceptance_rate ?? existing.acceptanceRate ?? 95),
          fcmToken: row.fcm_token || existing.fcmToken,
          deviceTokens: row.user_device_tokens || existing.deviceTokens || [],
        });
      }
    } catch (_) {}
  }

  return Array.from(mergedMap.values());
}

// ─── SMART TECHNICIAN RANKING ENGINE (Section 5) ────────────────────────────
async function findAndRankEligibleTechnicians(bookingParams, radiusKm = 3, excludeTechIds = new Set()) {
  const allProfiles = await loadAllCandidateTechnicianProfiles(bookingParams, radiusKm);
  const eligibleCandidates = [];
  const excludedDiagnostics = [];

  for (const profile of allProfiles) {
    const techId = profile.id || profile.technicianId;
    if (!techId) continue;
    if (excludeTechIds.has(techId)) {
      excludedDiagnostics.push({ technicianId: techId, reasons: ['ALREADY_OFFERED_IN_SESSION'] });
      continue;
    }

    const evalResult = evaluateTechnicianEligibility(profile, bookingParams, radiusKm);
    if (!evalResult.eligible) {
      excludedDiagnostics.push({ technicianId: techId, reasons: evalResult.reasons });
      continue;
    }

    eligibleCandidates.push({
      profile,
      evalResult,
    });
  }

  // Compute transparent weighted score for each eligible technician
  const weights = dispatchConfig.rankingWeights;
  const maxRad = Math.max(radiusKm, 15);

  const ranked = eligibleCandidates.map(({ profile, evalResult }) => {
    const techId = profile.id || profile.technicianId;
    const distanceKm = evalResult.distanceKm ?? 0;

    // 1. ETA / Distance factor (35% default): closer = closer to 1.0
    const etaDistanceScore = Math.max(0, Math.min(1, 1 - distanceKm / maxRad));

    // 2. Service skill match factor (25% default)
    const skillScore = Math.max(0, Math.min(1, evalResult.skillMatchQuality || 0.85));

    // 3. Availability factor (20% default)
    const availScore = 1.0;

    // 4. Customer rating factor (10% default): normalized out of 5.0
    const rawRating = parseFloat(profile.rating ?? 4.85);
    const ratingScore = Math.max(0, Math.min(1, rawRating / 5.0));

    // 5. Acceptance / reliability history factor (10% default): normalized out of 100%
    const rawAcceptance = parseFloat(profile.acceptanceRate ?? profile.acceptance_rate ?? 95);
    const reliabilityScore = Math.max(0, Math.min(1, rawAcceptance / 100.0));

    const totalScore =
      etaDistanceScore * (weights.etaDistance ?? 0.35) +
      skillScore * (weights.skillMatch ?? 0.25) +
      availScore * (weights.availability ?? 0.20) +
      ratingScore * (weights.rating ?? 0.10) +
      reliabilityScore * (weights.reliability ?? 0.10);

    const rankingReasons = {
      etaDistanceScore: Number(etaDistanceScore.toFixed(4)),
      skillScore: Number(skillScore.toFixed(4)),
      availabilityScore: Number(availScore.toFixed(4)),
      ratingScore: Number(ratingScore.toFixed(4)),
      reliabilityScore: Number(reliabilityScore.toFixed(4)),
      weightsUsed: weights,
      distanceKm,
      etaMinutes: evalResult.etaMinutes,
      etaSource: evalResult.etaSource,
      skillMatchType: evalResult.skillMatchType,
      rating: rawRating,
      acceptanceRate: rawAcceptance,
    };

    return {
      technicianId: techId,
      name: profile.name || profile.fullName || 'Verified Technician',
      phone: profile.phone || '',
      category: profile.category || 'General',
      rating: rawRating,
      completedJobs: parseInt(profile.totalJobsCompleted ?? profile.completedJobs ?? 15, 10),
      avatar: profile.avatar || profile.photoUrl || profile.profilePhoto || '',
      skills: profile.skills || [],
      latitude: Number(profile.latitude ?? profile.current_latitude),
      longitude: Number(profile.longitude ?? profile.current_longitude),
      distanceKm,
      etaMinutes: evalResult.etaMinutes,
      etaSource: evalResult.etaSource,
      rankingScore: Number(totalScore.toFixed(4)),
      rankingReasons,
      validFcmTokens: evalResult.validFcmTokens,
    };
  });

  // Sort descending by rankingScore, then ascending by distanceKm
  ranked.sort((a, b) => {
    if (b.rankingScore !== a.rankingScore) {
      return b.rankingScore - a.rankingScore;
    }
    return a.distanceKm - b.distanceKm;
  });

  return {
    rankedCandidates: ranked,
    excludedDiagnostics,
  };
}

// ─── START AUTOMATIC DISPATCH FOR A BOOKING (Section 2, 6, 14) ──────────────
async function startDispatchForBooking(bookingOrId, options = {}) {
  const booking =
    typeof bookingOrId === 'string'
      ? bookingsStore.getBookingById(bookingOrId)
      : bookingOrId;

  if (!booking) {
    throw new Error('Booking not found for dispatch');
  }

  const bookingId = booking.id || booking.bookingCode;
  const bookingMode = String(options.bookingMode || booking.bookingMode || 'INSTANT').toUpperCase();

  // Check if an active session already exists
  const existingSession = dispatchSessionsStore.get(bookingId);
  if (existingSession && ['ASSIGNED'].includes(existingSession.status) && !options.forceRestart) {
    return existingSession;
  }

  // Cancel any existing active offer timer if restarting
  if (existingSession && existingSession.activeOfferId) {
    clearOfferTimer(existingSession.activeOfferId);
  }

  const radii = Array.isArray(options.radiiKm) && options.radiiKm.length > 0
    ? options.radiiKm
    : dispatchConfig.radiiKm;
  const offerTimeoutSeconds = Number(options.offerTimeoutSeconds || dispatchConfig.offerTimeoutSeconds || 20);

  const session = {
    id: existingSession?.id || `dsess_${uuidv4().slice(0, 12)}`,
    bookingId,
    bookingCode: booking.bookingCode || bookingId,
    customerId: booking.customerId,
    customerName: booking.customerName || booking.customer || 'Customer',
    serviceId: booking.serviceId || booking.services?.[0]?.id || 'srv_general',
    serviceName: booking.serviceName || booking.service || 'Service Request',
    category: booking.category || 'General',
    latitude: Number(booking.latitude ?? 12.9716),
    longitude: Number(booking.longitude ?? 77.5946),
    address: booking.fullAddress || booking.address || 'Service Location',
    approximateArea: maskApproximateArea(booking.fullAddress || booking.address),
    scheduleDate: booking.scheduleDate || booking.date || new Date().toISOString().split('T')[0],
    scheduleSlot: booking.scheduleSlot || booking.timeSlot || 'Instant Dispatch',
    totalAmount: parseFloat(booking.grandTotal || booking.totalAmount || booking.price || 499),
    basePrice: parseFloat(booking.basePrice || booking.price || 399),
    bookingMode,
    status: 'SEARCHING',
    radiiKm: radii,
    currentRadiusIndex: 0,
    currentRadiusKm: radii[0] || 3,
    retryPassInCurrentRadius: 0,
    attemptNumber: 0,
    maxAttempts: Number(options.maxAttempts || dispatchConfig.maxTotalAttempts || 12),
    offerTimeoutSeconds,
    activeOfferId: null,
    assignedTechnicianId: null,
    offeredTechnicianIds: [],
    offerHistory: existingSession?.offerHistory || [],
    failureReason: null,
    configSnapshot: getDispatchConfig(),
    createdAt: existingSession?.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  dispatchSessionsStore.set(bookingId, session);
  bookingsStore.updateBookingStatus(bookingId, 'SEARCHING_TECHNICIAN', {
    dispatchSessionId: session.id,
    dispatchStatus: 'SEARCHING',
  });

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `INSERT INTO dispatch_sessions (id, booking_id, booking_mode, status, current_radius_km, attempt_number, max_attempts, offer_timeout_seconds, config_snapshot, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, NOW(), NOW())
         ON CONFLICT (booking_id) DO UPDATE
         SET status = EXCLUDED.status,
             current_radius_km = EXCLUDED.current_radius_km,
             attempt_number = EXCLUDED.attempt_number,
             offer_timeout_seconds = EXCLUDED.offer_timeout_seconds,
             assigned_technician_id = NULL,
             failure_reason = NULL,
             updated_at = NOW();`,
        [
          session.id,
          session.bookingId,
          session.bookingMode,
          session.status,
          session.currentRadiusKm,
          session.attemptNumber,
          session.maxAttempts,
          session.offerTimeoutSeconds,
          JSON.stringify(session.configSnapshot),
        ]
      );
    } catch (_) {}
  }

  await recordAuditLog({
    bookingId,
    sessionId: session.id,
    actorId: options.actorId || booking.customerId || 'SYSTEM',
    actorRole: options.actorRole || 'SYSTEM',
    eventType: 'DISPATCH_STARTED',
    details: {
      bookingMode,
      initialRadiusKm: session.currentRadiusKm,
      offerTimeoutSeconds: session.offerTimeoutSeconds,
    },
  });

  // Emit Socket events to Customer & Admin
  emitToCustomerAndBooking(session.customerId, bookingId, 'booking:dispatch:started', {
    bookingId,
    sessionId: session.id,
    status: 'SEARCHING',
    message: 'Finding the best available technician near you',
    radiusKm: session.currentRadiusKm,
    timestamp: new Date().toISOString(),
  });

  emitToAdmin('admin:dispatch:new', {
    bookingId,
    sessionId: session.id,
    status: 'SEARCHING',
    serviceName: session.serviceName,
    radiusKm: session.currentRadiusKm,
    timestamp: new Date().toISOString(),
  });

  if (!dispatchConfig.autoDispatchEnabled && !options.forceAuto) {
    await recordAuditLog({
      bookingId,
      sessionId: session.id,
      eventType: 'AUTO_DISPATCH_PAUSED_BY_ADMIN',
      details: { message: 'Awaiting manual admin assignment' },
    });
    return session;
  }

  await sendNextSequentialOffer(bookingId);
  return dispatchSessionsStore.get(bookingId);
}

// ─── SEQUENTIAL BOOKING OFFER CASCADE & RADIUS EXPANSION (Section 6 & 8) ────
async function sendNextSequentialOffer(bookingId) {
  const session = dispatchSessionsStore.get(bookingId);
  if (!session) return null;
  if (['ASSIGNED', 'CANCELLED', 'FAILED_NO_TECHNICIAN'].includes(session.status)) {
    return session;
  }

  const booking = bookingsStore.getBookingById(bookingId);
  if (booking && ['CANCELLED', 'COMPLETED'].includes(String(booking.status).toUpperCase())) {
    session.status = 'CANCELLED';
    session.updatedAt = new Date().toISOString();
    return session;
  }

  if (session.attemptNumber >= session.maxAttempts) {
    return await markDispatchFailedNoTechnician(session, 'MAX_DISPATCH_ATTEMPTS_REACHED');
  }

  // Loop through radii tiers (e.g. 3km -> 5km -> 10km -> 15km)
  while (session.currentRadiusIndex < session.radiiKm.length) {
    const currentRadiusKm = session.radiiKm[session.currentRadiusIndex];
    session.currentRadiusKm = currentRadiusKm;

    const excludeSet = new Set(session.offeredTechnicianIds);
    const { rankedCandidates, excludedDiagnostics } = await findAndRankEligibleTechnicians(
      {
        bookingId: session.bookingId,
        serviceId: session.serviceId,
        serviceName: session.serviceName,
        category: session.category,
        latitude: session.latitude,
        longitude: session.longitude,
        scheduleDate: session.scheduleDate,
        scheduleSlot: session.scheduleSlot,
        bookingMode: session.bookingMode,
      },
      currentRadiusKm,
      excludeSet
    );

    if (rankedCandidates.length > 0) {
      const winnerCandidate = rankedCandidates[0];
      return await createAndSendOfferToTechnician(session, winnerCandidate);
    }

    // No candidate available in this radius pass
    await recordAuditLog({
      bookingId: session.bookingId,
      sessionId: session.id,
      eventType: 'NO_ELIGIBLE_CANDIDATES_IN_RADIUS',
      details: {
        radiusKm: currentRadiusKm,
        excludedCount: excludedDiagnostics.length,
        excludedDiagnostics: excludedDiagnostics.slice(0, 10),
      },
    });

    // Check if we should retry in the same radius or expand to next radius
    if (session.retryPassInCurrentRadius + 1 < dispatchConfig.maxRetriesPerRadius) {
      session.retryPassInCurrentRadius += 1;
      // Clear offered list for retry pass only if configured, otherwise advance radius
    }

    session.currentRadiusIndex += 1;
    session.retryPassInCurrentRadius = 0;

    if (session.currentRadiusIndex < session.radiiKm.length) {
      const nextRadiusKm = session.radiiKm[session.currentRadiusIndex];
      session.currentRadiusKm = nextRadiusKm;
      session.updatedAt = new Date().toISOString();

      await recordAuditLog({
        bookingId: session.bookingId,
        sessionId: session.id,
        eventType: 'RADIUS_EXPANDED',
        details: { previousRadiusKm: currentRadiusKm, newRadiusKm: nextRadiusKm },
      });

      emitToCustomerAndBooking(session.customerId, session.bookingId, 'booking:dispatch:searching', {
        bookingId: session.bookingId,
        sessionId: session.id,
        status: 'SEARCHING',
        radiusKm: nextRadiusKm,
        message: `Expanding search radius to ${nextRadiusKm} km to find the best available specialist...`,
        timestamp: new Date().toISOString(),
      });

      emitToAdmin('admin:dispatch:updated', {
        bookingId: session.bookingId,
        sessionId: session.id,
        status: 'SEARCHING',
        radiusKm: nextRadiusKm,
        attemptNumber: session.attemptNumber,
      });
    }
  }

  // All radii exhausted
  return await markDispatchFailedNoTechnician(session, 'NO_ELIGIBLE_TECHNICIAN_WITHIN_MAX_RADIUS');
}

// ─── CREATE & DELIVER SEQUENTIAL OFFER TO A SINGLE TECHNICIAN ───────────────
async function createAndSendOfferToTechnician(session, candidate) {
  session.attemptNumber += 1;
  session.status = 'OFFERED';
  session.offeredTechnicianIds.push(candidate.technicianId);

  const offerId = `doffer_${uuidv4().slice(0, 12)}`;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + session.offerTimeoutSeconds * 1000);
  const expectedEarning = Math.round(session.basePrice * 0.85);

  const offer = {
    id: offerId,
    offerId,
    proposalId: offerId,
    sessionId: session.id,
    bookingId: session.bookingId,
    bookingCode: session.bookingCode,
    technicianId: candidate.technicianId,
    technicianName: candidate.name,
    status: 'SENT',
    attemptNumber: session.attemptNumber,
    radiusKm: session.currentRadiusKm,
    distanceKm: candidate.distanceKm,
    etaMinutes: candidate.etaMinutes,
    etaSource: candidate.etaSource,
    expectedEarning,
    payout: expectedEarning,
    totalAmount: session.totalAmount,
    serviceId: session.serviceId,
    serviceName: session.serviceName,
    serviceType: session.serviceName,
    category: session.category,
    // Privacy: ONLY approximate area before acceptance, never full street/house or phone!
    approximateArea: session.approximateArea,
    customerAddress: session.approximateArea,
    customerName: 'Verified Customer',
    appointmentTime: `${session.scheduleDate} • ${session.scheduleSlot}`,
    rankingScore: candidate.rankingScore,
    rankingReasons: candidate.rankingReasons,
    timeoutSeconds: session.offerTimeoutSeconds,
    sentAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    respondedAt: null,
    rejectionReason: null,
    fcmMessageId: null,
    fcmDeliveryStatus: 'PENDING',
  };

  session.activeOfferId = offerId;
  session.offerHistory.push(offer);
  session.updatedAt = now.toISOString();
  dispatchOffersStore.set(offerId, offer);

  // Persist to PostgreSQL dispatch_offers & legacy dispatch_requests
  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `INSERT INTO dispatch_offers (
          id, session_id, booking_id, technician_id, status, attempt_number, radius_km,
          distance_km, eta_minutes, eta_source, expected_earning, total_amount,
          service_id, service_name, approximate_area, appointment_time,
          ranking_score, ranking_reasons, sent_at, expires_at
        ) VALUES ($1,$2,$3,$4,'SENT',$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17::jsonb,NOW(),$18)`,
        [
          offer.id,
          offer.sessionId,
          offer.bookingId,
          offer.technicianId,
          offer.attemptNumber,
          offer.radiusKm,
          offer.distanceKm,
          offer.etaMinutes,
          offer.etaSource,
          offer.expectedEarning,
          offer.totalAmount,
          offer.serviceId,
          offer.serviceName,
          offer.approximateArea,
          offer.appointmentTime,
          offer.rankingScore,
          JSON.stringify(offer.rankingReasons),
          offer.expiresAt,
        ]
      );

      await postgres.query(
        `INSERT INTO dispatch_requests (
          id, booking_id, technician_id, service_id, service_name,
          customer_name, customer_address, distance_km, estimated_payout,
          total_amount, status, created_at, expires_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'PENDING',NOW(),$11)
        ON CONFLICT (id) DO NOTHING`,
        [
          offer.id,
          offer.bookingId,
          offer.technicianId,
          offer.serviceId,
          offer.serviceName,
          'Verified Customer',
          offer.approximateArea,
          offer.distanceKm,
          offer.expectedEarning,
          offer.totalAmount,
          offer.expiresAt,
        ]
      );

      await postgres.query(
        `UPDATE dispatch_sessions
         SET status = 'OFFERED', current_radius_km = $1, attempt_number = $2, active_offer_id = $3, updated_at = NOW()
         WHERE id = $4`,
        [session.currentRadiusKm, session.attemptNumber, offer.id, session.id]
      );
    } catch (_) {}
  }

  firestoreSync.upsertDocument('dispatch_offers', offer.id, offer).catch(() => {});

  // 1. Deliver Real-Time Socket.io Offer ONLY to the selected technician's private room
  const socketOfferPayload = {
    offerId: offer.id,
    proposalId: offer.id,
    dispatchRequestId: offer.id,
    bookingId: offer.bookingId,
    bookingCode: offer.bookingCode,
    technicianId: offer.technicianId,
    serviceId: offer.serviceId,
    serviceName: offer.serviceName,
    serviceType: offer.serviceName,
    category: offer.category,
    approximateCustomerArea: offer.approximateArea,
    customerAddress: offer.approximateArea,
    distanceKm: offer.distanceKm,
    estimatedTravelMinutes: offer.etaMinutes,
    etaSource: offer.etaSource,
    appointmentTime: offer.appointmentTime,
    expectedEarning: offer.expectedEarning,
    payout: offer.expectedEarning,
    totalAmount: offer.totalAmount,
    timeoutSeconds: offer.timeoutSeconds,
    expiresAt: offer.expiresAt,
    attemptNumber: offer.attemptNumber,
    rankingScore: offer.rankingScore,
  };

  if (global.io) {
    global.io.to(`tech_${candidate.technicianId}`).emit('dispatch:offer:new', socketOfferPayload);
    global.io.to(`tech_${candidate.technicianId}`).emit('booking:dispatch_ringing', socketOfferPayload);
    global.io.to(`tech_${candidate.technicianId}`).emit('TECHNICIAN_BOOKING_REQUEST', socketOfferPayload);
  }

  // 2. Deliver Real FCM Push Notification & record provider diagnostics (Section 9)
  try {
    if (Array.isArray(candidate.validFcmTokens)) {
      candidate.validFcmTokens.forEach(tok => {
        notificationService.registerToken(candidate.technicianId, tok);
      });
    }
    const fcmResult = await notificationService.sendToUser(
      candidate.technicianId,
      '🚨 New Service Offer Nearby!',
      `${offer.serviceName} (${offer.distanceKm} km away) • Earn ₹${offer.expectedEarning}`,
      {
        type: 'DISPATCH_OFFER_NEW',
        offerId: offer.id,
        proposalId: offer.id,
        bookingId: offer.bookingId,
        serviceName: offer.serviceName,
        approximateArea: offer.approximateArea,
        distanceKm: String(offer.distanceKm),
        etaMinutes: String(offer.etaMinutes),
        expectedEarning: String(offer.expectedEarning),
        expiresAt: offer.expiresAt,
      }
    );
    offer.fcmDeliveryStatus = fcmResult?.sent ? 'PROVIDER_ACCEPTED' : (fcmResult?.reason || 'QUEUED_SOCKET_ONLY');
    offer.fcmMessageId = fcmResult?.messageId || null;
  } catch (fcmErr) {
    offer.fcmDeliveryStatus = `ERROR: ${fcmErr.message}`;
  }

  await recordAuditLog({
    bookingId: session.bookingId,
    sessionId: session.id,
    offerId: offer.id,
    technicianId: candidate.technicianId,
    eventType: 'OFFER_SENT',
    details: {
      attemptNumber: offer.attemptNumber,
      radiusKm: offer.radiusKm,
      distanceKm: offer.distanceKm,
      etaMinutes: offer.etaMinutes,
      expectedEarning: offer.expectedEarning,
      rankingScore: offer.rankingScore,
      rankingReasons: offer.rankingReasons,
      expiresAt: offer.expiresAt,
      fcmDeliveryStatus: offer.fcmDeliveryStatus,
    },
  });

  emitToCustomerAndBooking(session.customerId, session.bookingId, 'booking:dispatch:searching', {
    bookingId: session.bookingId,
    sessionId: session.id,
    status: 'OFFERED',
    radiusKm: session.currentRadiusKm,
    attemptNumber: session.attemptNumber,
    message: 'Finding the best available technician near you',
    timestamp: new Date().toISOString(),
  });

  emitToAdmin('admin:dispatch:updated', {
    bookingId: session.bookingId,
    sessionId: session.id,
    status: 'OFFERED',
    activeOffer: socketOfferPayload,
    attemptNumber: session.attemptNumber,
  });

  // 3. Arm Authoritative Server-Side Expiration Timer
  armOfferExpirationTimer(offer.id, session.offerTimeoutSeconds * 1000);

  return offer;
}

function armOfferExpirationTimer(offerId, durationMs) {
  clearOfferTimer(offerId);
  const timer = setTimeout(() => {
    handleOfferTimeout(offerId).catch(err => {
      console.error(`❌ [DispatchEngine] Error handling timeout for offer ${offerId}:`, err.message);
    });
  }, Math.max(50, durationMs));
  if (typeof timer.unref === 'function') {
    timer.unref();
  }
  activeOfferTimers.set(offerId, timer);
}

function clearOfferTimer(offerId) {
  if (!offerId) return;
  const existing = activeOfferTimers.get(offerId);
  if (existing) {
    clearTimeout(existing);
    activeOfferTimers.delete(offerId);
  }
}

// ─── HANDLE OFFER TIMEOUT (Section 8) ───────────────────────────────────────
async function handleOfferTimeout(offerId) {
  clearOfferTimer(offerId);
  const offer = dispatchOffersStore.get(offerId);
  if (!offer || offer.status !== 'SENT') return null;

  offer.status = 'EXPIRED';
  offer.respondedAt = new Date().toISOString();
  offer.rejectionReason = 'OFFER_TIMEOUT';

  const session = dispatchSessionsStore.get(offer.bookingId);
  if (session && session.activeOfferId === offerId) {
    session.activeOfferId = null;
    session.status = 'SEARCHING';
    session.updatedAt = new Date().toISOString();
  }

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `UPDATE dispatch_offers SET status = 'EXPIRED', responded_at = NOW(), rejection_reason = 'OFFER_TIMEOUT' WHERE id = $1 AND status = 'SENT'`,
        [offerId]
      );
      await postgres.query(
        `UPDATE dispatch_requests SET status = 'EXPIRED', responded_at = NOW() WHERE id = $1 AND status = 'PENDING'`,
        [offerId]
      );
    } catch (_) {}
  }

  if (global.io) {
    global.io.to(`tech_${offer.technicianId}`).emit('dispatch:offer:expired', {
      offerId: offer.id,
      bookingId: offer.bookingId,
      status: 'EXPIRED',
    });
    global.io.to(`tech_${offer.technicianId}`).emit('dispatch:expired', {
      offerId: offer.id,
      bookingId: offer.bookingId,
    });
  }

  await recordAuditLog({
    bookingId: offer.bookingId,
    sessionId: offer.sessionId,
    offerId: offer.id,
    technicianId: offer.technicianId,
    eventType: 'OFFER_EXPIRED',
    details: { attemptNumber: offer.attemptNumber, reason: 'TIMEOUT' },
  });

  if (session && !['ASSIGNED', 'CANCELLED', 'FAILED_NO_TECHNICIAN'].includes(session.status)) {
    await sendNextSequentialOffer(offer.bookingId);
  }

  return offer;
}

// ─── ATOMIC ACCEPTANCE & DOUBLE-ASSIGNMENT PREVENTION (Section 7) ───────────
async function acceptOffer(offerOrBookingId, authenticatedTechnicianId) {
  // Resolve offer by offerId or active offer for bookingId
  let offer = dispatchOffersStore.get(offerOrBookingId);
  if (!offer) {
    const sess = dispatchSessionsStore.get(offerOrBookingId);
    if (sess && sess.activeOfferId) {
      offer = dispatchOffersStore.get(sess.activeOfferId);
    }
    if (!offer) {
      // Search if any offer exists for this booking & technician
      for (const [, o] of dispatchOffersStore.entries()) {
        if (o.bookingId === offerOrBookingId && o.technicianId === authenticatedTechnicianId) {
          offer = o;
          break;
        }
      }
    }
  }

  if (!offer) {
    const err = new Error('Dispatch offer not found');
    err.statusCode = 404;
    throw err;
  }

  const bookingId = offer.bookingId;

  // Verify ownership: Technician B CANNOT accept Technician A's offer (Section 21)
  if (!authenticatedTechnicianId || String(offer.technicianId) !== String(authenticatedTechnicianId)) {
    await recordAuditLog({
      bookingId,
      sessionId: offer.sessionId,
      offerId: offer.id,
      technicianId: authenticatedTechnicianId,
      actorId: authenticatedTechnicianId,
      actorRole: 'TECHNICIAN',
      eventType: 'UNAUTHORIZED_OFFER_ACCEPT_ATTEMPT',
      details: { expectedTechnicianId: offer.technicianId, attemptedBy: authenticatedTechnicianId },
    });
    const err = new Error('Forbidden: This booking offer was not issued to your technician account.');
    err.statusCode = 403;
    throw err;
  }

  // Acquire synchronous atomic mutex lock on bookingId to prevent race conditions
  if (bookingLocks.has(bookingId)) {
    const err = new Error('Conflict: Booking is currently being assigned to another technician.');
    err.statusCode = 409;
    throw err;
  }

  bookingLocks.add(bookingId);
  try {
    const session = dispatchSessionsStore.get(bookingId);
    const booking = bookingsStore.getBookingById(bookingId);

    // 1. Check if booking is already assigned
    if (
      (session && session.status === 'ASSIGNED') ||
      (booking && booking.technicianId && ['ASSIGNED', 'TECHNICIAN_ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'].includes(String(booking.status).toUpperCase()))
    ) {
      const err = new Error('Conflict: Booking has already been assigned to a technician.');
      err.statusCode = 409;
      throw err;
    }

    // 2. Check if offer is still SENT and not expired
    const nowMs = Date.now();
    const expiresMs = new Date(offer.expiresAt).getTime();
    if (offer.status !== 'SENT' || nowMs > expiresMs) {
      offer.status = offer.status === 'SENT' ? 'EXPIRED' : offer.status;
      const err = new Error(`Conflict: Offer is no longer valid (status: ${offer.status}).`);
      err.statusCode = 409;
      throw err;
    }

    // 3. Revalidate technician eligibility & conflicting jobs before final assignment (Section 7 & 8)
    const techProfile = inMemoryTechProfiles.get(authenticatedTechnicianId) || {
      id: authenticatedTechnicianId,
      technicianId: authenticatedTechnicianId,
      name: offer.technicianName || 'Verified Technician',
      kycStatus: 'VERIFIED',
      accountStatus: 'Active',
      isOnline: true,
      availabilityStatus: 'AVAILABLE',
      fcmToken: 'valid_registered_fcm_token_placeholder',
    };

    const conflictCheck = hasConflictingBooking(
      authenticatedTechnicianId,
      {
        bookingMode: session?.bookingMode || booking?.bookingMode || 'INSTANT',
        scheduleDate: session?.scheduleDate || booking?.scheduleDate,
        scheduleSlot: session?.scheduleSlot || booking?.scheduleSlot,
      },
      bookingId
    );
    if (conflictCheck.conflict) {
      const err = new Error(`Conflict: Technician already has an overlapping active booking (${conflictCheck.conflictingBookingId}).`);
      err.statusCode = 409;
      throw err;
    }

    const isSuspended = techProfile.isSuspended === true || String(techProfile.accountStatus).toUpperCase() === 'SUSPENDED';
    if (isSuspended || techProfile.isOnline === false) {
      offer.status = 'CANCELLED';
      const err = new Error('Conflict: Technician became unavailable or offline prior to assignment.');
      err.statusCode = 409;
      throw err;
    }

    // 4. Execute PostgreSQL row-level locking transaction if PG is connected
    if (postgres.isPgHealthy() && postgres.getPool()) {
      const client = await postgres.getPool().connect();
      try {
        await client.query('BEGIN');
        const sessLock = await client.query(
          `SELECT status, assigned_technician_id FROM dispatch_sessions WHERE booking_id = $1 FOR UPDATE`,
          [bookingId]
        );
        if (sessLock.rows.length > 0 && sessLock.rows[0].status === 'ASSIGNED') {
          await client.query('ROLLBACK');
          const err = new Error('Conflict: Booking already assigned in database transaction.');
          err.statusCode = 409;
          throw err;
        }

        await client.query(
          `UPDATE dispatch_offers SET status = 'ACCEPTED', responded_at = NOW() WHERE id = $1`,
          [offer.id]
        );
        await client.query(
          `UPDATE dispatch_offers SET status = 'CANCELLED', responded_at = NOW() WHERE booking_id = $1 AND id != $2 AND status IN ('PENDING', 'SENT')`,
          [bookingId, offer.id]
        );
        await client.query(
          `UPDATE dispatch_sessions SET status = 'ASSIGNED', assigned_technician_id = $1, active_offer_id = $2, updated_at = NOW() WHERE booking_id = $3`,
          [authenticatedTechnicianId, offer.id, bookingId]
        );
        await client.query(
          `UPDATE technician_profiles SET availability_status = 'BUSY', updated_at = NOW() WHERE technician_id = $1`,
          [authenticatedTechnicianId]
        );
        await client.query('COMMIT');
      } catch (pgErr) {
        await client.query('ROLLBACK').catch(() => {});
        if (pgErr.statusCode === 409) throw pgErr;
      } finally {
        client.release();
      }
    }

    // 5. Commit atomic state in memory & bookingsStore
    clearOfferTimer(offer.id);
    offer.status = 'ACCEPTED';
    offer.respondedAt = new Date().toISOString();

    // Cancel any other pending offers for this booking
    for (const [otherId, otherOffer] of dispatchOffersStore.entries()) {
      if (otherOffer.bookingId === bookingId && otherId !== offer.id && ['PENDING', 'SENT'].includes(otherOffer.status)) {
        clearOfferTimer(otherId);
        otherOffer.status = 'CANCELLED';
        otherOffer.respondedAt = new Date().toISOString();
        if (global.io) {
          global.io.to(`tech_${otherOffer.technicianId}`).emit('dispatch:offer:cancelled', {
            offerId: otherId,
            bookingId,
            reason: 'ASSIGNED_TO_ANOTHER_TECHNICIAN',
          });
        }
      }
    }

    if (session) {
      session.status = 'ASSIGNED';
      session.assignedTechnicianId = authenticatedTechnicianId;
      session.activeOfferId = offer.id;
      session.updatedAt = new Date().toISOString();
    }

    // Update technician profile status to BUSY
    const updatedTech = setTechnicianProfile(authenticatedTechnicianId, {
      ...techProfile,
      availabilityStatus: 'BUSY',
      availability_status: 'BUSY',
    });

    const techName = updatedTech.name || updatedTech.fullName || offer.technicianName || 'Assigned Technician';
    const techPhone = updatedTech.phone || '';
    const techCategory = updatedTech.category || offer.category || 'General';
    const techRating = parseFloat(updatedTech.rating || 4.85);
    const techAvatar = updatedTech.avatar || updatedTech.photoUrl || '';

    bookingsStore.assignTechnician(
      bookingId,
      authenticatedTechnicianId,
      techName,
      techPhone,
      techCategory,
      techRating,
      techAvatar
    );

    const updatedBooking = bookingsStore.updateBookingStatus(bookingId, 'ASSIGNED', {
      technicianId: authenticatedTechnicianId,
      technicianName: techName,
      technicianPhone: techPhone,
      technicianRating: techRating,
      technicianAvatar: techAvatar,
      technicianLatitude: updatedTech.latitude ?? updatedTech.current_latitude ?? null,
      technicianLongitude: updatedTech.longitude ?? updatedTech.current_longitude ?? null,
      etaMinutes: offer.etaMinutes,
      distanceKm: offer.distanceKm,
    });

    await recordAuditLog({
      bookingId,
      sessionId: offer.sessionId,
      offerId: offer.id,
      technicianId: authenticatedTechnicianId,
      actorId: authenticatedTechnicianId,
      actorRole: 'TECHNICIAN',
      eventType: 'OFFER_ACCEPTED_AND_ASSIGNED',
      details: {
        technicianName: techName,
        distanceKm: offer.distanceKm,
        etaMinutes: offer.etaMinutes,
        attemptNumber: offer.attemptNumber,
      },
    });

    // 6. Send Start OTP to Customer's Registered Email via EmailJS (User Requirement)
    if (updatedBooking) {
      const customerEmail = updatedBooking.customerEmail || updatedBooking.email || booking?.customerEmail || booking?.email;
      if (customerEmail && updatedBooking.startOtp) {
        emailService.sendOtpEmail(customerEmail, updatedBooking.startOtp, updatedBooking.customerName || 'Customer').catch(() => {});
      }
    }

    // 7. Emit Socket.io notifications to Technician, Customer, and Admin
    const assignmentPayload = {
      bookingId,
      bookingCode: updatedBooking?.bookingCode || bookingId,
      offerId: offer.id,
      status: 'ASSIGNED',
      technicianId: authenticatedTechnicianId,
      technician: {
        id: authenticatedTechnicianId,
        name: techName,
        phone: techPhone,
        maskedPhone: maskPhoneNumber(techPhone),
        rating: techRating,
        completedJobs: parseInt(updatedTech.totalJobsCompleted || 15, 10),
        skills: updatedTech.skills || [techCategory],
        category: techCategory,
        avatar: techAvatar,
        latitude: updatedTech.latitude ?? updatedTech.current_latitude ?? null,
        longitude: updatedTech.longitude ?? updatedTech.current_longitude ?? null,
      },
      distanceKm: offer.distanceKm,
      etaMinutes: offer.etaMinutes,
      etaSource: offer.etaSource,
      startOtp: updatedBooking?.startOtp,
      customer: {
        name: updatedBooking?.customerName || session?.customerName || 'Customer',
        address: updatedBooking?.fullAddress || updatedBooking?.address || session?.address || '',
        maskedPhone: maskPhoneNumber(updatedBooking?.customerPhone || ''),
        latitude: updatedBooking?.latitude ?? session?.latitude,
        longitude: updatedBooking?.longitude ?? session?.longitude,
      },
      timestamp: new Date().toISOString(),
    };

    if (global.io) {
      global.io.to(`tech_${authenticatedTechnicianId}`).emit('dispatch:offer:accepted', assignmentPayload);
      global.io.to(`tech_${authenticatedTechnicianId}`).emit('booking:accepted', assignmentPayload);
    }

    const custId = updatedBooking?.customerId || session?.customerId;
    emitToCustomerAndBooking(custId, bookingId, 'booking:technician:assigned', assignmentPayload);
    emitToCustomerAndBooking(custId, bookingId, 'booking:technician_assigned', assignmentPayload);

    emitToAdmin('admin:dispatch:updated', {
      bookingId,
      sessionId: offer.sessionId,
      status: 'ASSIGNED',
      assignedTechnician: assignmentPayload.technician,
      timestamp: new Date().toISOString(),
    });

    if (custId) {
      notificationService.notifyCustomerTechnicianAssigned(
        custId,
        bookingId,
        techName,
        `${offer.etaMinutes || 15} mins`
      ).catch(() => {});
    }

    return {
      offer,
      session,
      booking: updatedBooking,
      assignment: assignmentPayload,
    };
  } finally {
    bookingLocks.delete(bookingId);
  }
}

function maskPhoneNumber(phone) {
  if (!phone || typeof phone !== 'string') return '+91 ••••• ••••';
  const digits = phone.replace(/\D/g, '');
  if (digits.length >= 10) {
    return `+91 ••••••${digits.slice(-4)}`;
  }
  return '+91 ••••• ••••';
}

// ─── REJECT OFFER & ADVANCE TO NEXT RANKED TECHNICIAN (Section 8) ───────────
async function rejectOffer(offerOrBookingId, authenticatedTechnicianId, reason = 'REJECTED_BY_TECHNICIAN') {
  let offer = dispatchOffersStore.get(offerOrBookingId);
  if (!offer) {
    const sess = dispatchSessionsStore.get(offerOrBookingId);
    if (sess && sess.activeOfferId) {
      offer = dispatchOffersStore.get(sess.activeOfferId);
    }
  }

  if (!offer) {
    const err = new Error('Dispatch offer not found');
    err.statusCode = 404;
    throw err;
  }

  if (authenticatedTechnicianId && String(offer.technicianId) !== String(authenticatedTechnicianId)) {
    const err = new Error('Forbidden: Cannot reject an offer belonging to another technician');
    err.statusCode = 403;
    throw err;
  }

  clearOfferTimer(offer.id);
  offer.status = 'REJECTED';
  offer.respondedAt = new Date().toISOString();
  offer.rejectionReason = reason;

  const session = dispatchSessionsStore.get(offer.bookingId);
  if (session && session.activeOfferId === offer.id) {
    session.activeOfferId = null;
    session.status = 'SEARCHING';
    session.updatedAt = new Date().toISOString();
  }

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `UPDATE dispatch_offers SET status = 'REJECTED', responded_at = NOW(), rejection_reason = $1 WHERE id = $2`,
        [reason, offer.id]
      );
      await postgres.query(
        `UPDATE dispatch_requests SET status = 'DECLINED', responded_at = NOW() WHERE id = $1`,
        [offer.id]
      );
    } catch (_) {}
  }

  await recordAuditLog({
    bookingId: offer.bookingId,
    sessionId: offer.sessionId,
    offerId: offer.id,
    technicianId: offer.technicianId,
    actorId: authenticatedTechnicianId || offer.technicianId,
    actorRole: 'TECHNICIAN',
    eventType: 'OFFER_REJECTED',
    details: { reason, attemptNumber: offer.attemptNumber },
  });

  if (session && !['ASSIGNED', 'CANCELLED', 'FAILED_NO_TECHNICIAN'].includes(session.status)) {
    await sendNextSequentialOffer(offer.bookingId);
  }

  return offer;
}

// ─── HANDLE TECHNICIAN GOING OFFLINE / DISCONNECTING DURING OFFER (Section 8) ─
async function handleTechnicianOffline(technicianId, reason = 'TECHNICIAN_WENT_OFFLINE') {
  if (!technicianId) return [];
  const invalidatedOffers = [];

  for (const [offerId, offer] of dispatchOffersStore.entries()) {
    if (offer.technicianId === technicianId && offer.status === 'SENT') {
      clearOfferTimer(offerId);
      offer.status = 'EXPIRED';
      offer.respondedAt = new Date().toISOString();
      offer.rejectionReason = reason;
      invalidatedOffers.push(offer);

      const session = dispatchSessionsStore.get(offer.bookingId);
      if (session && session.activeOfferId === offerId) {
        session.activeOfferId = null;
        session.status = 'SEARCHING';
        session.updatedAt = new Date().toISOString();
      }

      if (global.io) {
        global.io.to(`tech_${technicianId}`).emit('dispatch:offer:cancelled', {
          offerId,
          bookingId: offer.bookingId,
          reason,
        });
      }

      await recordAuditLog({
        bookingId: offer.bookingId,
        sessionId: offer.sessionId,
        offerId,
        technicianId,
        actorId: technicianId,
        actorRole: 'TECHNICIAN',
        eventType: 'OFFER_INVALIDATED_OFFLINE',
        details: { reason },
      });

      if (session && !['ASSIGNED', 'CANCELLED', 'FAILED_NO_TECHNICIAN'].includes(session.status)) {
        await sendNextSequentialOffer(offer.bookingId);
      }
    }
  }

  return invalidatedOffers;
}

// ─── MARK DISPATCH FAILED WHEN NO TECHNICIAN IS AVAILABLE (Section 8 & 11) ───
async function markDispatchFailedNoTechnician(session, reason) {
  session.status = 'FAILED_NO_TECHNICIAN';
  session.activeOfferId = null;
  session.failureReason = reason;
  session.updatedAt = new Date().toISOString();

  bookingsStore.updateBookingStatus(session.bookingId, 'NO_TECHNICIAN_AVAILABLE', {
    dispatchStatus: 'FAILED_NO_TECHNICIAN',
    dispatchFailureReason: reason,
  });

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `UPDATE dispatch_sessions SET status = 'FAILED_NO_TECHNICIAN', active_offer_id = NULL, failure_reason = $1, updated_at = NOW() WHERE id = $2`,
        [reason, session.id]
      );
    } catch (_) {}
  }

  await recordAuditLog({
    bookingId: session.bookingId,
    sessionId: session.id,
    eventType: 'DISPATCH_FAILED_NO_TECHNICIAN',
    details: {
      reason,
      attemptsMade: session.attemptNumber,
      maxRadiusSearchedKm: session.currentRadiusKm,
    },
  });

  const failurePayload = {
    bookingId: session.bookingId,
    sessionId: session.id,
    status: 'NO_TECHNICIAN_AVAILABLE',
    reason,
    attemptsMade: session.attemptNumber,
    maxRadiusSearchedKm: session.currentRadiusKm,
    message: 'All verified technicians in your area are currently busy. You can retry dispatch or reschedule your appointment.',
    canRetry: true,
    canReschedule: true,
    timestamp: new Date().toISOString(),
  };

  emitToCustomerAndBooking(session.customerId, session.bookingId, 'booking:dispatch:failed', failurePayload);
  emitToAdmin('admin:dispatch:updated', failurePayload);

  return session;
}

// ─── ADMIN MANUAL ASSIGN / REASSIGN WITH FULL AUDIT TRAIL (Section 15 & 17) ──
async function manualAssignBooking(bookingId, technicianId, adminActor = { id: 'admin', role: 'ADMIN', reason: 'ADMIN_MANUAL_ASSIGN' }) {
  const booking = bookingsStore.getBookingById(bookingId);
  if (!booking) {
    const err = new Error('Booking not found');
    err.statusCode = 404;
    throw err;
  }

  const previousTechnicianId = booking.technicianId || null;
  const isReassignment = Boolean(previousTechnicianId && previousTechnicianId !== technicianId);

  // Cancel any active pending offers for this booking
  const session = dispatchSessionsStore.get(bookingId);
  if (session && session.activeOfferId) {
    clearOfferTimer(session.activeOfferId);
    const activeOffer = dispatchOffersStore.get(session.activeOfferId);
    if (activeOffer && activeOffer.status === 'SENT') {
      activeOffer.status = 'CANCELLED';
      activeOffer.respondedAt = new Date().toISOString();
      activeOffer.rejectionReason = 'ADMIN_MANUAL_OVERRIDE';
      if (global.io) {
        global.io.to(`tech_${activeOffer.technicianId}`).emit('dispatch:offer:cancelled', {
          offerId: activeOffer.id,
          bookingId,
          reason: 'ADMIN_MANUAL_OVERRIDE',
        });
      }
    }
  }

  const techProfile = inMemoryTechProfiles.get(technicianId) || {
    id: technicianId,
    technicianId,
    name: 'Assigned Technician',
    phone: '',
    category: booking.category || 'General',
    rating: 4.9,
  };

  const techName = techProfile.name || techProfile.fullName || 'Assigned Technician';
  const techPhone = techProfile.phone || '';
  const techCategory = techProfile.category || booking.category || 'General';
  const techRating = parseFloat(techProfile.rating || 4.9);
  const techAvatar = techProfile.avatar || techProfile.photoUrl || '';

  bookingsStore.assignTechnician(bookingId, technicianId, techName, techPhone, techCategory, techRating, techAvatar);
  const updatedBooking = bookingsStore.updateBookingStatus(bookingId, 'ASSIGNED', {
    technicianId,
    technicianName: techName,
    technicianPhone: techPhone,
    technicianRating: techRating,
    technicianAvatar: techAvatar,
  });

  setTechnicianProfile(technicianId, {
    ...techProfile,
    availabilityStatus: 'BUSY',
    availability_status: 'BUSY',
  });

  if (previousTechnicianId && previousTechnicianId !== technicianId) {
    const prevTech = inMemoryTechProfiles.get(previousTechnicianId);
    if (prevTech) {
      setTechnicianProfile(previousTechnicianId, {
        ...prevTech,
        availabilityStatus: 'AVAILABLE',
        availability_status: 'AVAILABLE',
      });
    }
  }

  const updatedSession = {
    ...(session || {
      id: `dsess_${uuidv4().slice(0, 12)}`,
      bookingId,
      bookingMode: 'INSTANT',
      currentRadiusKm: 15,
      attemptNumber: 1,
      offerHistory: [],
      createdAt: new Date().toISOString(),
    }),
    status: 'ASSIGNED',
    assignedTechnicianId: technicianId,
    activeOfferId: null,
    updatedAt: new Date().toISOString(),
  };
  dispatchSessionsStore.set(bookingId, updatedSession);

  const auditEntry = await recordAuditLog({
    bookingId,
    sessionId: updatedSession.id,
    technicianId,
    actorId: adminActor.id || 'admin',
    actorRole: adminActor.role || 'ADMIN',
    eventType: isReassignment ? 'ADMIN_MANUAL_REASSIGNMENT' : 'ADMIN_MANUAL_ASSIGNMENT',
    details: {
      previousTechnicianId,
      newTechnicianId: technicianId,
      newTechnicianName: techName,
      reason: adminActor.reason || 'ADMIN_MANUAL_OVERRIDE',
    },
  });

  const payload = {
    bookingId,
    status: 'ASSIGNED',
    isReassigned: isReassignment,
    previousTechnicianId,
    technicianId,
    technician: {
      id: technicianId,
      name: techName,
      phone: techPhone,
      maskedPhone: maskPhoneNumber(techPhone),
      rating: techRating,
      category: techCategory,
      avatar: techAvatar,
      latitude: techProfile.latitude ?? techProfile.current_latitude ?? null,
      longitude: techProfile.longitude ?? techProfile.current_longitude ?? null,
    },
    startOtp: updatedBooking?.startOtp,
    timestamp: new Date().toISOString(),
  };

  const custId = updatedBooking?.customerId || booking.customerId;
  emitToCustomerAndBooking(
    custId,
    bookingId,
    isReassignment ? 'booking:technician:reassigned' : 'booking:technician:assigned',
    payload
  );
  emitToCustomerAndBooking(custId, bookingId, 'booking:technician_assigned', payload);

  if (global.io) {
    global.io.to(`tech_${technicianId}`).emit('dispatch:offer:accepted', payload);
    if (previousTechnicianId && previousTechnicianId !== technicianId) {
      global.io.to(`tech_${previousTechnicianId}`).emit('dispatch:offer:cancelled', {
        bookingId,
        reason: 'REASSIGNED_BY_ADMIN',
      });
    }
  }

  emitToAdmin('admin:dispatch:updated', payload);

  return {
    booking: updatedBooking,
    session: updatedSession,
    auditEntry,
    isReassignment,
  };
}

// ─── RECORD & STREAM TECHNICIAN LIVE GPS LOCATION (Section 12 & 18) ─────────
async function recordTechnicianLocationUpdate({ technicianId, latitude, longitude, speed = 0, heading = 0, bookingId = null }) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (Number.isNaN(lat) || Number.isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw new Error('Invalid GPS coordinates');
  }

  const entry = {
    id: `tloc_${uuidv4().slice(0, 12)}`,
    technicianId,
    bookingId,
    latitude: lat,
    longitude: lng,
    speed: Number(speed || 0),
    heading: Number(heading || 0),
    recordedAt: new Date().toISOString(),
  };

  technicianLocationsHistory.unshift(entry);
  if (technicianLocationsHistory.length > 1000) {
    technicianLocationsHistory.pop();
  }

  // Update technician profile coordinates
  const existingProfile = inMemoryTechProfiles.get(technicianId) || { id: technicianId, technicianId };
  setTechnicianProfile(technicianId, {
    ...existingProfile,
    latitude: lat,
    longitude: lng,
    current_latitude: lat,
    current_longitude: lng,
    lastLocationUpdate: entry.recordedAt,
    last_location_update: entry.recordedAt,
  });

  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `INSERT INTO technician_location_updates (id, technician_id, booking_id, latitude, longitude, speed, heading, recorded_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
        [entry.id, technicianId, bookingId, lat, lng, entry.speed, entry.heading]
      );
    } catch (_) {}
  }

  // Update active assigned bookings for this technician & emit ONLY to authorized rooms (NEVER global broadcast!)
  const updatedBookings = bookingsStore.updateTechnicianLocation(technicianId, lat, lng, entry.speed, entry.heading);
  for (const b of updatedBookings) {
    const locPayload = {
      bookingId: b.id,
      technicianId,
      latitude: lat,
      longitude: lng,
      speed: entry.speed,
      heading: entry.heading,
      timestamp: entry.recordedAt,
    };
    emitToCustomerAndBooking(b.customerId, b.id, 'booking:partner:location', locPayload);
    emitToCustomerAndBooking(b.customerId, b.id, 'job:partner_location', locPayload);
  }

  emitToAdmin('admin:technician:status', {
    technicianId,
    latitude: lat,
    longitude: lng,
    speed: entry.speed,
    heading: entry.heading,
    timestamp: entry.recordedAt,
  });

  return { entry, updatedBookings };
}

// ─── SOCKET ROOM EMISSION HELPERS (AUTHORIZED ROOMS ONLY) ───────────────────
function emitToCustomerAndBooking(customerId, bookingId, eventName, payload) {
  if (!global.io) return;
  if (customerId) {
    global.io.to(`cust_${customerId}`).emit(eventName, payload);
  }
  if (bookingId) {
    global.io.to(`booking_${bookingId}`).emit(eventName, payload);
    global.io.to(`job_${bookingId}`).emit(eventName, payload);
  }
}

function emitToAdmin(eventName, payload) {
  if (!global.io) return;
  global.io.to('admin_dispatch').emit(eventName, payload);
}

// ─── SERVER RESTART RECOVERY (Section 19 & 22 Test 18) ──────────────────────
async function recoverActiveDispatchSessions() {
  const nowMs = Date.now();
  const recovered = [];

  for (const [bookingId, session] of dispatchSessionsStore.entries()) {
    if (['SEARCHING', 'OFFERED'].includes(session.status)) {
      if (session.activeOfferId) {
        const activeOffer = dispatchOffersStore.get(session.activeOfferId);
        if (activeOffer && activeOffer.status === 'SENT') {
          const remainingMs = new Date(activeOffer.expiresAt).getTime() - nowMs;
          if (remainingMs <= 0) {
            await handleOfferTimeout(activeOffer.id);
          } else {
            armOfferExpirationTimer(activeOffer.id, remainingMs);
          }
          recovered.push(bookingId);
          continue;
        }
      }
      await sendNextSequentialOffer(bookingId);
      recovered.push(bookingId);
    }
  }

  return recovered;
}

// ─── QUERY HELPERS FOR STATUS, LIVE RADAR & HISTORY (Section 17) ────────────
function getBookingDispatchStatus(bookingId) {
  const session = dispatchSessionsStore.get(bookingId) || null;
  const booking = bookingsStore.getBookingById(bookingId) || null;
  if (!session && !booking) return null;

  const activeOffer = session?.activeOfferId ? dispatchOffersStore.get(session.activeOfferId) : null;
  return {
    bookingId,
    bookingCode: booking?.bookingCode || session?.bookingCode || bookingId,
    bookingStatus: booking?.status || 'UNKNOWN',
    dispatchStatus: session?.status || (booking?.technicianId ? 'ASSIGNED' : 'IDLE'),
    currentRadiusKm: session?.currentRadiusKm || 3,
    attemptNumber: session?.attemptNumber || 0,
    assignedTechnicianId: booking?.technicianId || session?.assignedTechnicianId || null,
    technician: booking?.technicianId
      ? {
          id: booking.technicianId,
          name: booking.technicianName || booking.technician,
          maskedPhone: maskPhoneNumber(booking.technicianPhone),
          rating: booking.technicianRating || 4.85,
          avatar: booking.technicianAvatar || '',
          latitude: booking.technicianLatitude ?? null,
          longitude: booking.technicianLongitude ?? null,
        }
      : null,
    activeOffer: activeOffer
      ? {
          offerId: activeOffer.id,
          technicianId: activeOffer.technicianId,
          status: activeOffer.status,
          distanceKm: activeOffer.distanceKm,
          etaMinutes: activeOffer.etaMinutes,
          expiresAt: activeOffer.expiresAt,
          remainingSeconds: Math.max(0, Math.ceil((new Date(activeOffer.expiresAt).getTime() - Date.now()) / 1000)),
        }
      : null,
    failureReason: session?.failureReason || null,
    updatedAt: session?.updatedAt || booking?.updatedAt,
  };
}

function getTechnicianActiveOffers(technicianId) {
  const nowMs = Date.now();
  const active = [];
  for (const [, offer] of dispatchOffersStore.entries()) {
    if (offer.technicianId === technicianId && offer.status === 'SENT') {
      const remSec = Math.ceil((new Date(offer.expiresAt).getTime() - nowMs) / 1000);
      if (remSec > 0) {
        active.push({
          ...offer,
          remainingSeconds: remSec,
        });
      }
    }
  }
  return active.sort((a, b) => new Date(b.sentAt) - new Date(a.sentAt));
}

function getBookingDispatchHistory(bookingId) {
  const session = dispatchSessionsStore.get(bookingId) || null;
  const offers = [];
  for (const [, offer] of dispatchOffersStore.entries()) {
    if (offer.bookingId === bookingId) {
      offers.push(offer);
    }
  }
  offers.sort((a, b) => a.attemptNumber - b.attemptNumber);

  const auditLogs = dispatchAuditLogsStore.filter(l => l.bookingId === bookingId);
  return {
    bookingId,
    session,
    offers,
    auditLogs,
  };
}

function getLiveAdminDispatchOverview() {
  const sessions = Array.from(dispatchSessionsStore.values()).sort(
    (a, b) => new Date(b.updatedAt) - new Date(a.updatedAt)
  );
  const counts = {
    SEARCHING: 0,
    OFFERED: 0,
    ASSIGNED: 0,
    FAILED_NO_TECHNICIAN: 0,
    CANCELLED: 0,
    TOTAL: sessions.length,
  };
  sessions.forEach(s => {
    if (counts[s.status] !== undefined) counts[s.status] += 1;
  });

  return {
    config: getDispatchConfig(),
    counts,
    sessions,
    recentAuditLogs: dispatchAuditLogsStore.slice(0, 100),
  };
}

function resetDispatchEngineStoresForTest() {
  for (const [offerId] of activeOfferTimers.entries()) {
    clearOfferTimer(offerId);
  }
  dispatchSessionsStore.clear();
  dispatchOffersStore.clear();
  technicianAvailabilityStore.clear();
  technicianSkillsStore.clear();
  technicianLocationsHistory.length = 0;
  dispatchAuditLogsStore.length = 0;
  bookingLocks.clear();
}

// ─── PHASE 2: REAL-TIME SLOT AVAILABILITY ENGINE ────────────────────────────
async function getAvailableTimeSlots({
  serviceId,
  serviceName,
  category,
  latitude = 22.5726,
  longitude = 88.3639,
  date,
  durationMinutes = 60,
  radiusKm = 15,
}) {
  const targetDate = date || new Date().toISOString().split('T')[0];
  const standardSlots = [
    { slot: '09:00 AM', time24: '09:00' },
    { slot: '10:00 AM', time24: '10:00' },
    { slot: '11:00 AM', time24: '11:00' },
    { slot: '12:00 PM', time24: '12:00' },
    { slot: '02:00 PM', time24: '14:00' },
    { slot: '03:00 PM', time24: '15:00' },
    { slot: '04:00 PM', time24: '16:00' },
    { slot: '05:00 PM', time24: '17:00' },
    { slot: '06:00 PM', time24: '18:00' },
    { slot: '07:00 PM', time24: '19:00' },
  ];

  const slotsResult = [];
  for (const s of standardSlots) {
    const scan = await findAndRankEligibleTechnicians(
      {
        serviceId,
        serviceName,
        category,
        latitude: Number(latitude),
        longitude: Number(longitude),
        bookingMode: 'SCHEDULED',
        scheduleDate: targetDate,
        scheduleSlot: s.slot,
        durationMinutes: Number(durationMinutes || 60),
      },
      Number(radiusKm || 15)
    );
    const eligibleCount = scan.rankedCandidates.length;
    slotsResult.push({
      slot: s.slot,
      time24: s.time24,
      date: targetDate,
      available: eligibleCount > 0,
      eligibleCount,
      estimatedDurationMinutes: Number(durationMinutes || 60),
    });
  }

  return {
    date: targetDate,
    serviceId,
    category,
    radiusKm: Number(radiusKm || 15),
    slots: slotsResult,
    availableSlotsCount: slotsResult.filter(x => x.available).length,
  };
}

// ─── PHASE 14: CANCEL DISPATCH SESSION & OFFERS ON BOOKING CANCELLATION ─────
async function cancelDispatchSessionForBooking(
  bookingId,
  reason = 'BOOKING_CANCELLED',
  actorId = 'CUSTOMER',
  actorRole = 'CUSTOMER'
) {
  const session = dispatchSessionsStore.get(bookingId);
  if (!session) return null;

  if (session.activeOfferId) {
    clearOfferTimer(session.activeOfferId);
  }

  for (const [offerId, offer] of dispatchOffersStore.entries()) {
    if (offer.bookingId === bookingId && ['PENDING', 'SENT'].includes(offer.status)) {
      clearOfferTimer(offerId);
      offer.status = 'CANCELLED';
      offer.respondedAt = new Date().toISOString();
      offer.rejectionReason = reason;
      if (global.io) {
        global.io.to(`tech_${offer.technicianId}`).emit('dispatch:offer:cancelled', {
          offerId,
          bookingId,
          reason,
        });
      }
      if (postgres.isPgHealthy()) {
        await postgres.query(
          `UPDATE dispatch_offers SET status = 'CANCELLED', responded_at = NOW(), rejection_reason = $1 WHERE id = $2`,
          [reason, offerId]
        ).catch(() => {});
      }
    }
  }

  session.status = 'CANCELLED';
  session.activeOfferId = null;
  session.failureReason = reason;
  session.updatedAt = new Date().toISOString();

  if (postgres.isPgHealthy()) {
    await postgres.query(
      `UPDATE dispatch_sessions SET status = 'CANCELLED', active_offer_id = NULL, failure_reason = $1, updated_at = NOW() WHERE booking_id = $2`,
      [reason, bookingId]
    ).catch(() => {});
  }

  await recordAuditLog({
    bookingId,
    sessionId: session.id,
    actorId,
    actorRole,
    eventType: 'DISPATCH_SESSION_CANCELLED',
    details: { reason },
  });

  emitToAdmin('admin:dispatch:updated', {
    bookingId,
    sessionId: session.id,
    status: 'CANCELLED',
    reason,
    timestamp: new Date().toISOString(),
  });

  return session;
}

module.exports = {
  getDispatchConfig,
  updateDispatchConfig,
  maskApproximateArea,
  isValidFcmToken,
  setTechnicianAvailability,
  getTechnicianAvailability,
  setTechnicianServiceSkill,
  getAvailableTimeSlots,
  cancelDispatchSessionForBooking,
  evaluateTechnicianEligibility,
  findAndRankEligibleTechnicians,
  startDispatchForBooking,
  sendNextSequentialOffer,
  handleOfferTimeout,
  acceptOffer,
  rejectOffer,
  handleTechnicianOffline,
  manualAssignBooking,
  recordTechnicianLocationUpdate,
  recoverActiveDispatchSessions,
  getBookingDispatchStatus,
  getTechnicianActiveOffers,
  getBookingDispatchHistory,
  getLiveAdminDispatchOverview,
  recordAuditLog,
  resetDispatchEngineStoresForTest,
  dispatchSessionsStore,
  dispatchOffersStore,
  dispatchAuditLogsStore,
};

