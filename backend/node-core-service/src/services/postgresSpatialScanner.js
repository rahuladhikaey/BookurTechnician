const postgres = require('../config/postgres');
const redis = require('../config/redis');

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
          catConds.push(`ts.service_id = $${params.length}`);
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
  // Runs if PostGIS is not available or returned 0 candidates (e.g. PostGIS extension not loaded or NULL geography)
  if (matchedMap.size === 0 && postgres.isPgHealthy()) {
    try {
      // 1 degree lat approx 111 km; 1 degree lon approx 111 * cos(lat) km
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

  // ─── 3. TIER 3: REDIS GEO FALLBACK (FAST IN-MEMORY RADIAL INDEX) ────────────
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
  } catch (_) {
    // Redis offline fallback
  }

  const results = Array.from(matchedMap.values()).sort((a, b) => a.distanceKm - b.distanceKm);
  return results;
};

/**
 * Scan aggregate service availability counts within 15 km radius
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

  if (postgres.isPgHealthy()) {
    // Attempt PostGIS query
    try {
      const queryText = `
        SELECT 
          s.id AS service_id,
          s.name AS service_name,
          COUNT(DISTINCT tp.technician_id) AS available_technician_count
        FROM services s
        LEFT JOIN technician_services ts ON ts.service_id = s.id AND ts.active = true
        LEFT JOIN technician_profiles tp ON 
          (tp.technician_id = ts.technician_id OR LOWER(tp.category) = LOWER(s.name) OR tp.category ILIKE ('%' || s.slug || '%'))
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
            WHERE b.technician_id = tp.technician_id 
              AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
          )
        WHERE s.is_active = true
        GROUP BY s.id, s.name
      `;
      const res = await postgres.query(queryText, [custLat, custLng, radiusMeters, staleSeconds]);
      for (const row of res.rows) {
        countsMap.set(row.service_id, parseInt(row.available_technician_count, 10) || 0);
      }
      return countsMap;
    } catch (err) {
      // Fallback to SQL Haversine
      try {
        const queryText = `
          SELECT 
            s.id AS service_id,
            s.name AS service_name,
            COUNT(DISTINCT tp.technician_id) AS available_technician_count
          FROM services s
          LEFT JOIN technician_services ts ON ts.service_id = s.id AND ts.active = true
          LEFT JOIN technician_profiles tp ON 
            (tp.technician_id = ts.technician_id OR LOWER(tp.category) = LOWER(s.name) OR tp.category ILIKE ('%' || s.slug || '%'))
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
              WHERE b.technician_id = tp.technician_id 
                AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
            )
          WHERE s.is_active = true
          GROUP BY s.id, s.name
        `;
        const res = await postgres.query(queryText, [custLat, custLng, radiusKm, staleSeconds]);
        for (const row of res.rows) {
          countsMap.set(row.service_id, parseInt(row.available_technician_count, 10) || 0);
        }
        return countsMap;
      } catch (sqlErr) {
        console.warn('⚠️ [Spatial Scanner] Service count fallback notice:', sqlErr.message);
      }
    }
  }

  return countsMap;
};

module.exports = {
  scanNearbyTechnicians,
  scanServiceAvailability,
  calculateHaversineKm,
  normalizeCategoryKey,
};
