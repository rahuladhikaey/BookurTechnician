const postgres = require('../config/postgres');
const redis = require('../config/redis');
const { inMemoryTechProfiles, inMemorySkills } = require('../config/inMemoryTechStore');
const { getFlattenedServices } = require('../config/masterCatalog');
const { resolveServiceIdsFromSkill, getSkillSynonymsForService, doesTechnicianMatchService } = require('./catalogSkillMapper');

/**
 * Pure Haversine distance calculator between two WGS84 GPS points
 * @returns {number} distance in kilometers
 */
const calculateHaversineKm = (lat1, lon1, lat2, lon2) => {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return 999.0;
  const R = 6371.0; // Earth radius in km
  const dLat = (lat2 - lat1) * (Math.PI / 180.0);
  const dLon = (lon2 - lon1) * (Math.PI / 180.0);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180.0)) *
      Math.cos(lat2 * (Math.PI / 180.0)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return parseFloat((R * c).toFixed(2));
};

/**
 * Standardize category keys across queries
 */
const normalizeCategoryKey = (cat) => {
  if (!cat) return '';
  const lower = String(cat).trim().toLowerCase();
  if (lower.includes('elect')) return 'electrician';
  if (lower.includes('plumb')) return 'plumber';
  if (lower.includes('carp')) return 'carpenter';
  if (lower.includes('paint')) return 'painter';
  if (lower.includes('clean')) return 'cleaning';
  if (lower.includes('appliance') || lower.includes('repair')) return 'appliance_repair';
  if (lower.includes('ac') || lower.includes('air')) return 'ac_repair';
  return lower;
};

/**
 * Diagnostic multi-stage availability scanner for a single service
 * Logs each step of the pipeline as specified in development logging requirements:
 * [AVAILABILITY] service=... customerLat=... customerLng=... radius=15km
 * [AVAILABILITY] candidate technicians before radius filter=...
 * [AVAILABILITY] technicians within 15km=...
 * [AVAILABILITY] matching skill technicians=...
 * [AVAILABILITY] online technicians=...
 * [AVAILABILITY] fresh-location technicians=...
 * [AVAILABILITY] final available count=...
 */
const scanSingleServiceAvailability = async ({
  serviceId,
  serviceName,
  latitude,
  longitude,
  radiusKm = 15,
  staleSeconds = 1800,
}) => {
  const custLat = parseFloat(latitude);
  const custLng = parseFloat(longitude);
  const srvId = String(serviceId || '').trim();
  const srvName = serviceName || srvId;

  console.log(`[AVAILABILITY] service=${srvName} (${srvId}) customerLat=${custLat} customerLng=${custLng} radius=${radiusKm}km`);

  if (isNaN(custLat) || isNaN(custLng) || !srvId) {
    console.warn(`⚠️ [AVAILABILITY] Invalid parameters: lat=${latitude}, lng=${longitude}, serviceId=${serviceId}`);
    return {
      serviceId: srvId,
      serviceName: srvName,
      radiusKm,
      availableTechnicianCount: 0,
      updatedAt: new Date().toISOString(),
    };
  }

  const radiusMeters = radiusKm * 1000.0;
  const skillSynonyms = getSkillSynonymsForService(srvId);
  const allServices = getFlattenedServices();
  const matchedSrv = allServices.find(s => s.id === srvId || s.slug === srvId);
  const srvCatId = matchedSrv?.categoryId || '';
  const srvCatName = matchedSrv?.categoryName || '';

  let candidateTechniciansBeforeRadius = 0;
  let techniciansWithin15km = 0;
  let matchingSkillTechnicians = 0;
  let onlineTechnicians = 0;
  let freshLocationTechnicians = 0;
  let finalAvailableCount = 0;

  const eligibleTechIds = new Set();

  if (postgres.isPgHealthy()) {
    try {
      // 1. Candidate Technicians total in system
      const totalRes = await postgres.query(`SELECT COUNT(*) as count FROM technician_profiles;`);
      candidateTechniciansBeforeRadius = parseInt(totalRes.rows[0]?.count || 0, 10);

      // 2. Technicians within radius (pure spatial)
      const spatialRes = await postgres.query(`
        SELECT technician_id, current_latitude, current_longitude, is_online, availability_status, kyc_status, last_location_update, skills, category
        FROM technician_profiles
        WHERE current_latitude IS NOT NULL AND current_longitude IS NOT NULL
          AND ST_DWithin(
            COALESCE(location, ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)::geography),
            ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
            $3
          );
      `, [custLat, custLng, radiusMeters]);

      techniciansWithin15km = spatialRes.rows.length;

      // 3. PostGIS Query with all verified business filters
      const queryText = `
        SELECT DISTINCT tp.technician_id, tp.full_name, tp.current_latitude, tp.current_longitude, tp.last_location_update
        FROM technician_profiles tp
        LEFT JOIN technician_services ts ON ts.technician_id = tp.technician_id AND ts.active = true
        WHERE tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - ($4 * INTERVAL '1 second')))
          AND (tp.current_latitude IS NOT NULL AND tp.current_longitude IS NOT NULL)
          AND ST_DWithin(
            COALESCE(tp.location, ST_SetSRID(ST_MakePoint(tp.current_longitude, tp.current_latitude), 4326)::geography),
            ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
            $3
          )
          AND (
            ts.service_id = $5
            OR ts.service_id = ANY($6::text[])
            OR ts.service_id ILIKE ('%' || $5 || '%')
            OR tp.skills::text ILIKE ('%' || $5 || '%')
            OR tp.skills::text ILIKE ('%' || replace($5, '_', ' ') || '%')
            OR tp.skills::text ILIKE ('%' || replace($5, '_', '') || '%')
            OR tp.skills::text ILIKE ('%' || split_part($5, '_', 1) || '%')
            OR (
              (tp.skills IS NULL OR tp.skills = '[]'::jsonb OR tp.skills = 'null'::jsonb)
              AND (
                LOWER(tp.category) = LOWER($7)
                OR LOWER(tp.category) ILIKE ('%' || split_part($5, '_', 1) || '%')
                OR ($8 != '' AND LOWER(tp.category) = LOWER($8))
                OR ($9 != '' AND LOWER(tp.category) = LOWER($9))
              )
            )
          )
          AND NOT EXISTS (
            SELECT 1 FROM bookings b 
            WHERE (b.technician_id = tp.technician_id OR b.technician_id = tp.id)
              AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
          );
      `;

      const pgRes = await postgres.query(queryText, [
        custLat,
        custLng,
        radiusMeters,
        staleSeconds,
        srvId,
        skillSynonyms,
        srvName,
        srvCatId,
        srvCatName,
      ]);

      for (const row of pgRes.rows) {
        eligibleTechIds.add(row.technician_id);
      }

      // Compute pipeline diagnostics from spatial results
      for (const row of spatialRes.rows) {
        const isOnline = row.is_online === true && (row.availability_status === 'AVAILABLE' || !row.availability_status);
        if (isOnline) onlineTechnicians++;

        const matchesSkill = doesTechnicianMatchService(
          { skills: row.skills, category: row.category },
          srvId
        );
        if (matchesSkill) matchingSkillTechnicians++;

        const isFresh = !row.last_location_update || (Date.now() - new Date(row.last_location_update).getTime()) <= (staleSeconds * 1000);
        if (isFresh && isOnline) freshLocationTechnicians++;
      }
    } catch (pgErr) {
      console.warn(`⚠️ [AVAILABILITY] PostGIS diagnostic query notice: ${pgErr.message}`);
    }
  }

  // Cross-check with In-Memory store for instantaneous zero-latency local state
  for (const [tId, p] of inMemoryTechProfiles.entries()) {
    candidateTechniciansBeforeRadius++;
    if (p && p.currentLatitude && p.currentLongitude) {
      const dist = calculateHaversineKm(custLat, custLng, p.currentLatitude, p.currentLongitude);
      if (dist <= radiusKm) {
        techniciansWithin15km++;
        const isOnline = (p.isOnline === true || p.is_online === true) && (p.availabilityStatus !== 'BUSY' && p.availabilityStatus !== 'OFFLINE');
        if (isOnline) onlineTechnicians++;

        const matchesSkill = doesTechnicianMatchService(p, srvId);
        if (matchesSkill) matchingSkillTechnicians++;

        const isFresh = true; // In-memory active profiles are live
        if (isOnline && matchesSkill && isFresh) {
          eligibleTechIds.add(tId);
        }
      }
    }
  }

  finalAvailableCount = eligibleTechIds.size;

  console.log(`[AVAILABILITY] candidate technicians before radius filter=${candidateTechniciansBeforeRadius}`);
  console.log(`[AVAILABILITY] technicians within 15km=${techniciansWithin15km}`);
  console.log(`[AVAILABILITY] matching skill technicians=${matchingSkillTechnicians}`);
  console.log(`[AVAILABILITY] online technicians=${onlineTechnicians}`);
  console.log(`[AVAILABILITY] fresh-location technicians=${freshLocationTechnicians}`);
  console.log(`[AVAILABILITY] final available count=${finalAvailableCount}`);

  return {
    serviceId: srvId,
    serviceName: srvName,
    radiusKm,
    availableTechnicianCount: finalAvailableCount,
    updatedAt: new Date().toISOString(),
  };
};

/**
 * Robust 15 KM Geospatial Scanner for PostgreSQL (PostGIS primary + Pure SQL Haversine fallback)
 * Scans active, verified, non-busy technicians within radius and ranks by proximity.
 */
const scanNearbyTechnicians = async ({
  latitude,
  longitude,
  radiusKm = 15,
  category = null,
  serviceId = null,
  staleSeconds = 1800,
  limit = 50,
}) => {
  const custLat = parseFloat(latitude);
  const custLng = parseFloat(longitude);

  if (isNaN(custLat) || isNaN(custLng) || custLat < -90 || custLat > 90 || custLng < -180 || custLng > 180) {
    console.warn(`⚠️ [Spatial Scanner] Invalid search coordinates: lat=${latitude}, lng=${longitude}`);
    return [];
  }

  const radiusMeters = parseFloat(radiusKm) * 1000.0;
  const normCat = normalizeCategoryKey(category);
  const matchedMap = new Map(); // technicianId -> object
  const synonyms = serviceId ? getSkillSynonymsForService(serviceId) : [];

  // ─── 1. TIER 1: AUTHORITATIVE POSTGIS GEODESIC SCAN ───────────────────────
  if (postgres.isPgHealthy()) {
    try {
      let queryText = `
        SELECT 
          tp.id,
          tp.technician_id,
          tp.technician_code,
          tp.full_name,
          tp.phone,
          tp.category,
          tp.skills,
          tp.rating,
          tp.total_ratings_count,
          tp.total_jobs_completed,
          tp.current_latitude,
          tp.current_longitude,
          tp.is_online,
          ST_Distance(
            COALESCE(tp.location, ST_SetSRID(ST_MakePoint(tp.current_longitude, tp.current_latitude), 4326)::geography),
            ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
          ) / 1000.0 AS distance_km
        FROM technician_profiles tp
        LEFT JOIN technician_services ts ON ts.technician_id = tp.technician_id AND ts.active = true
        WHERE tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - ($4 * INTERVAL '1 second')))
          AND (tp.current_latitude IS NOT NULL AND tp.current_longitude IS NOT NULL)
          AND ST_DWithin(
            COALESCE(tp.location, ST_SetSRID(ST_MakePoint(tp.current_longitude, tp.current_latitude), 4326)::geography),
            ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
            $3
          )
          AND NOT EXISTS (
            SELECT 1 FROM bookings b 
            WHERE b.technician_id = tp.technician_id 
              AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
          )
      `;

      const params = [custLat, custLng, radiusMeters, staleSeconds];

      // Smart category and service matching
      if (serviceId || normCat) {
        let catConds = [];
        if (serviceId) {
          params.push(serviceId);
          const pIdx1 = params.length;
          params.push(synonyms);
          const pIdx2 = params.length;

          catConds.push(`ts.service_id = $${pIdx1}`);
          catConds.push(`ts.service_id = ANY($${pIdx2}::text[])`);
          catConds.push(`ts.service_id ILIKE ('%' || $${pIdx1} || '%')`);
          catConds.push(`tp.skills::text ILIKE ('%' || $${pIdx1} || '%')`);
          catConds.push(`tp.skills::text ILIKE ('%' || replace($${pIdx1}, '_', ' ') || '%')`);
          catConds.push(`tp.skills::text ILIKE ('%' || replace($${pIdx1}, '_', '') || '%')`);
          catConds.push(`tp.category ILIKE ('%' || split_part($${pIdx1}, '_', 1) || '%')`);
        }
        if (normCat && normCat !== 'all') {
          params.push(`%${normCat}%`);
          catConds.push(`tp.category ILIKE $${params.length}`);
          catConds.push(`tp.skills::text ILIKE $${params.length}`);
        }
        if (catConds.length > 0) {
          queryText += ` AND (${catConds.join(' OR ')})`;
        }
      }

      params.push(limit);
      queryText += ` GROUP BY tp.id, tp.technician_id, tp.technician_code, tp.full_name, tp.phone, tp.category, tp.skills, tp.rating, tp.total_ratings_count, tp.total_jobs_completed, tp.current_latitude, tp.current_longitude, tp.is_online, tp.location ORDER BY distance_km ASC LIMIT $${params.length};`;

      const pgRes = await postgres.query(queryText, params);
      for (const row of pgRes.rows) {
        const techId = row.technician_id || row.id;
        const dist = parseFloat(parseFloat(row.distance_km).toFixed(2));
        matchedMap.set(techId, {
          technicianId: techId,
          technicianCode: row.technician_code || `BT-TECH-${techId.slice(-4).toUpperCase()}`,
          name: row.full_name || 'Verified Partner',
          phone: row.phone || '',
          category: row.category || normCat || 'General',
          rating: parseFloat(row.rating) || 4.9,
          totalRatingsCount: parseInt(row.total_ratings_count, 10) || 0,
          totalJobsCompleted: parseInt(row.total_jobs_completed, 10) || 0,
          distanceKm: dist,
          etaMinutes: Math.max(10, Math.round(dist * 3.5 + 5)),
          latitude: parseFloat(row.current_latitude),
          longitude: parseFloat(row.current_longitude),
          isOnline: true,
          source: 'POSTGIS_SPATIAL',
        });
      }

      if (matchedMap.size > 0) {
        console.log(`🌐 [PostGIS Spatial Scan] Found ${matchedMap.size} domain technicians within ${radiusKm}km`);
      }
    } catch (postgisErr) {
      console.warn('⚠️ [PostGIS Spatial Scan] Notice:', postgisErr.message, 'Falling back to Pure SQL Haversine.');
    }
  }

  // ─── 2. TIER 2: STANDARD SQL HAVERSINE FALLBACK ───────────────────────────
  if (matchedMap.size === 0 && postgres.isPgHealthy()) {
    try {
      const latDelta = radiusKm / 110.0;
      const cosLat = Math.cos(custLat * (Math.PI / 180.0));
      const lonDelta = radiusKm / (110.0 * Math.max(0.2, cosLat));

      let queryText = `
        SELECT 
          tp.id,
          tp.technician_id,
          tp.technician_code,
          tp.full_name,
          tp.phone,
          tp.category,
          tp.skills,
          tp.rating,
          tp.total_ratings_count,
          tp.total_jobs_completed,
          tp.current_latitude,
          tp.current_longitude,
          tp.is_online,
          (6371.0 * acos(
            LEAST(1.0, GREATEST(-1.0,
              cos(radians($1)) * cos(radians(tp.current_latitude)) *
              cos(radians(tp.current_longitude) - radians($2)) +
              sin(radians($1)) * sin(radians(tp.current_latitude))
            ))
          )) AS distance_km
        FROM technician_profiles tp
        LEFT JOIN technician_services ts ON ts.technician_id = tp.technician_id AND ts.active = true
        WHERE tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - ($4 * INTERVAL '1 second')))
          AND tp.current_latitude IS NOT NULL 
          AND tp.current_longitude IS NOT NULL
          AND tp.current_latitude BETWEEN ($1 - $5) AND ($1 + $5)
          AND tp.current_longitude BETWEEN ($2 - $6) AND ($2 + $6)
          AND NOT EXISTS (
            SELECT 1 FROM bookings b 
            WHERE b.technician_id = tp.technician_id 
              AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
          )
      `;

      const params = [custLat, custLng, radiusKm, staleSeconds, latDelta, lonDelta];

      if (serviceId || normCat) {
        let catConds = [];
        if (serviceId) {
          params.push(serviceId);
          catConds.push(`ts.service_id = $${params.length}`);
          catConds.push(`tp.skills::text ILIKE ('%' || $${params.length} || '%')`);
        }
        if (normCat && normCat !== 'all') {
          params.push(`%${normCat}%`);
          catConds.push(`tp.category ILIKE $${params.length}`);
          catConds.push(`tp.skills::text ILIKE $${params.length}`);
        }
        if (catConds.length > 0) {
          queryText += ` AND (${catConds.join(' OR ')})`;
        }
      }

      params.push(limit);
      queryText += ` GROUP BY tp.id, tp.technician_id, tp.technician_code, tp.full_name, tp.phone, tp.category, tp.skills, tp.rating, tp.total_ratings_count, tp.total_jobs_completed, tp.current_latitude, tp.current_longitude, tp.is_online HAVING (6371.0 * acos(LEAST(1.0, GREATEST(-1.0, cos(radians($1)) * cos(radians(tp.current_latitude)) * cos(radians(tp.current_longitude) - radians($2)) + sin(radians($1)) * sin(radians(tp.current_latitude)))))) <= $3 ORDER BY distance_km ASC LIMIT $${params.length};`;

      const pgRes = await postgres.query(queryText, params);
      for (const row of pgRes.rows) {
        const techId = row.technician_id || row.id;
        const dist = parseFloat(parseFloat(row.distance_km).toFixed(2));
        matchedMap.set(techId, {
          technicianId: techId,
          technicianCode: row.technician_code || `BT-TECH-${techId.slice(-4).toUpperCase()}`,
          name: row.full_name || 'Verified Partner',
          phone: row.phone || '',
          category: row.category || normCat || 'General',
          rating: parseFloat(row.rating) || 4.9,
          totalRatingsCount: parseInt(row.total_ratings_count, 10) || 0,
          totalJobsCompleted: parseInt(row.total_jobs_completed, 10) || 0,
          distanceKm: dist,
          etaMinutes: Math.max(10, Math.round(dist * 3.5 + 5)),
          latitude: parseFloat(row.current_latitude),
          longitude: parseFloat(row.current_longitude),
          isOnline: true,
          source: 'POSTGRES_HAVERSINE',
        });
      }

      if (matchedMap.size > 0) {
        console.log(`📐 [SQL Haversine Scan] Matched ${matchedMap.size} domain technicians within ${radiusKm}km`);
      }
    } catch (sqlErr) {
      console.warn('⚠️ [SQL Haversine Scan] Warning:', sqlErr.message);
    }
  }

  // ─── 3. TIER 3: REDIS GEO FALLBACK ────────────────────────────────────────
  try {
    const redisTechs = await redis.geoRadius('technician:locations', custLng, custLat, radiusKm);
    for (const t of redisTechs) {
      const isFresh = await redis.isTechnicianFresh(t.member);
      if (!isFresh) continue;

      if (!matchedMap.has(t.member)) {
        const dist = t.distanceKm !== undefined ? t.distanceKm : calculateHaversineKm(custLat, custLng, t.latitude, t.longitude);
        if (dist <= radiusKm) {
          matchedMap.set(t.member, {
            technicianId: t.member,
            technicianCode: `BT-TECH-${t.member.slice(-4).toUpperCase()}`,
            name: 'Verified Partner',
            phone: '',
            category: normCat || 'General',
            rating: 4.9,
            distanceKm: parseFloat(dist.toFixed(2)),
            etaMinutes: Math.max(10, Math.round(dist * 3.5 + 5)),
            latitude: t.latitude,
            longitude: t.longitude,
            isOnline: true,
            source: 'REDIS_LIVE',
          });
        }
      }
    }
  } catch (_) {}

  // ─── 4. TIER 4: IN-MEMORY ACTIVE PROFILES ─────────────────────────────────
  for (const [tId, p] of inMemoryTechProfiles.entries()) {
    if (p && (p.isOnline === true || p.is_online === true) && p.currentLatitude && p.currentLongitude) {
      const dist = calculateHaversineKm(custLat, custLng, p.currentLatitude, p.currentLongitude);
      if (dist <= radiusKm && !matchedMap.has(tId)) {
        if (!serviceId || doesTechnicianMatchService(p, serviceId)) {
          matchedMap.set(tId, {
            technicianId: tId,
            technicianCode: p.technicianCode || `BT-TECH-${tId.slice(-4).toUpperCase()}`,
            name: p.fullName || 'Verified Partner',
            phone: p.phone || '',
            category: p.category || normCat || 'General',
            rating: 4.9,
            distanceKm: parseFloat(dist.toFixed(2)),
            etaMinutes: Math.max(10, Math.round(dist * 3.5 + 5)),
            latitude: p.currentLatitude,
            longitude: p.currentLongitude,
            isOnline: true,
            source: 'IN_MEMORY',
          });
        }
      }
    }
  }

  const results = Array.from(matchedMap.values()).sort((a, b) => a.distanceKm - b.distanceKm);
  return results;
};

/**
 * Scan aggregate service availability counts across ALL catalog services within 15 km radius
 * @returns {Promise<Map<string, number>>} serviceId -> availableTechnicianCount
 */
const scanServiceAvailability = async ({
  latitude,
  longitude,
  radiusKm = 15,
  staleSeconds = 1800,
}) => {
  const custLat = parseFloat(latitude);
  const custLng = parseFloat(longitude);
  const countsMap = new Map();

  if (isNaN(custLat) || isNaN(custLng)) return countsMap;
  const radiusMeters = radiusKm * 1000.0;

  // Initialize all catalog services with 0
  const allServices = getFlattenedServices ? getFlattenedServices() : [];
  for (const s of allServices) {
    countsMap.set(s.id, 0);
  }

  if (postgres.isPgHealthy()) {
    try {
      const queryText = `
        SELECT 
          s.id AS service_id,
          s.name AS service_name,
          COUNT(DISTINCT tp.technician_id) AS available_technician_count
        FROM services s
        LEFT JOIN technician_services ts ON (
          ts.service_id = s.id 
          OR ts.service_id ILIKE ('%' || s.id || '%') 
          OR ts.service_id ILIKE ('%' || replace(s.id, '_', '') || '%')
          OR ts.service_id ILIKE ('%' || split_part(s.id, '_', 1) || '%')
        ) AND ts.active = true
        LEFT JOIN technician_profiles tp ON 
          (
            tp.technician_id = ts.technician_id 
            OR tp.skills::text ILIKE ('%' || s.id || '%')
            OR tp.skills::text ILIKE ('%' || replace(s.id, '_', ' ') || '%')
            OR tp.skills::text ILIKE ('%' || replace(s.id, '_', '') || '%')
            OR tp.skills::text ILIKE ('%' || s.name || '%')
            OR tp.skills::text ILIKE ('%' || s.slug || '%')
            OR tp.skills::text ILIKE ('%' || split_part(s.id, '_', 1) || '%')
            OR (
              (tp.skills IS NULL OR tp.skills = '[]'::jsonb OR tp.skills = 'null'::jsonb)
              AND (
                LOWER(tp.category) = LOWER(s.name) 
                OR tp.category ILIKE ('%' || s.slug || '%')
                OR tp.category ILIKE ('%' || split_part(s.slug, '-', 1) || '%')
                OR tp.category ILIKE ('%' || split_part(s.id, '_', 1) || '%')
              )
            )
          )
          AND tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - ($4 * INTERVAL '1 second')))
          AND tp.current_latitude IS NOT NULL AND tp.current_longitude IS NOT NULL
          AND ST_DWithin(
            COALESCE(tp.location, ST_SetSRID(ST_MakePoint(tp.current_longitude, tp.current_latitude), 4326)::geography),
            ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
            $3
          )
          AND NOT EXISTS (
            SELECT 1 FROM bookings b 
            WHERE (b.technician_id = tp.technician_id OR b.technician_id = tp.id)
              AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
          )
        WHERE s.is_active = true
        GROUP BY s.id, s.name
      `;
      const res = await postgres.query(queryText, [custLat, custLng, radiusMeters, staleSeconds]);
      for (const row of res.rows) {
        countsMap.set(row.service_id, parseInt(row.available_technician_count, 10) || 0);
      }
    } catch (err) {
      // Fallback SQL Haversine query
      try {
        const queryText = `
          SELECT 
            s.id AS service_id,
            s.name AS service_name,
            COUNT(DISTINCT tp.technician_id) AS available_technician_count
          FROM services s
          LEFT JOIN technician_services ts ON (
            ts.service_id = s.id 
            OR ts.service_id ILIKE ('%' || s.id || '%') 
            OR ts.service_id ILIKE ('%' || replace(s.id, '_', '') || '%')
            OR ts.service_id ILIKE ('%' || split_part(s.id, '_', 1) || '%')
          ) AND ts.active = true
          LEFT JOIN technician_profiles tp ON 
            (
              tp.technician_id = ts.technician_id 
              OR tp.skills::text ILIKE ('%' || s.id || '%')
              OR tp.skills::text ILIKE ('%' || replace(s.id, '_', ' ') || '%')
              OR tp.skills::text ILIKE ('%' || replace(s.id, '_', '') || '%')
              OR tp.skills::text ILIKE ('%' || s.name || '%')
              OR tp.skills::text ILIKE ('%' || s.slug || '%')
              OR tp.skills::text ILIKE ('%' || split_part(s.id, '_', 1) || '%')
              OR (
                (tp.skills IS NULL OR tp.skills = '[]'::jsonb OR tp.skills = 'null'::jsonb)
                AND (
                  LOWER(tp.category) = LOWER(s.name) 
                  OR tp.category ILIKE ('%' || s.slug || '%')
                  OR tp.category ILIKE ('%' || split_part(s.slug, '-', 1) || '%')
                  OR tp.category ILIKE ('%' || split_part(s.id, '_', 1) || '%')
                )
              )
            )
            AND tp.is_online = true
            AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
            AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
            AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - ($4 * INTERVAL '1 second')))
            AND tp.current_latitude IS NOT NULL AND tp.current_longitude IS NOT NULL
            AND (6371.0 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(tp.current_latitude)) *
                cos(radians(tp.current_longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(tp.current_latitude))
              ))
            )) <= $3
            AND NOT EXISTS (
              SELECT 1 FROM bookings b 
              WHERE (b.technician_id = tp.technician_id OR b.technician_id = tp.id)
                AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
            )
          WHERE s.is_active = true
          GROUP BY s.id, s.name
        `;
        const res = await postgres.query(queryText, [custLat, custLng, radiusKm, staleSeconds]);
        for (const row of res.rows) {
          countsMap.set(row.service_id, parseInt(row.available_technician_count, 10) || 0);
        }
      } catch (sqlErr) {
        console.warn('⚠️ [Spatial Scanner] Service count fallback notice:', sqlErr.message);
      }
    }
  }

  // Cross-match in-memory technicians for instantaneous local updates
  for (const [tId, p] of inMemoryTechProfiles.entries()) {
    if (p && (p.isOnline === true || p.is_online === true) && p.currentLatitude && p.currentLongitude) {
      const dist = calculateHaversineKm(custLat, custLng, p.currentLatitude, p.currentLongitude);
      if (dist <= radiusKm) {
        for (const s of allServices) {
          if (doesTechnicianMatchService(p, s.id)) {
            const curr = countsMap.get(s.id) || 0;
            countsMap.set(s.id, curr + 1);
          }
        }
      }
    }
  }

  return countsMap;
};

module.exports = {
  scanNearbyTechnicians,
  scanServiceAvailability,
  scanSingleServiceAvailability,
  calculateHaversineKm,
  normalizeCategoryKey,
};
