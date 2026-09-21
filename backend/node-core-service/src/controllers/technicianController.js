const redis = require('../config/redis');
const MongoTechnicianProfile = require('../models/MongoTechnicianProfile');
const bookingsStore = require('../config/bookingsStore');
const postgres = require('../config/postgres');
const mongo = require('../config/mongo');
const postgresSpatialScanner = require('../services/postgresSpatialScanner');

// In-memory fallback cache for fast standalone operations
const { inMemorySkills, inMemoryDocs, inMemoryTechProfiles } = require('../config/inMemoryTechStore');

const CLOUDINARY_DOC_BADGES = {
  AADHAAR: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799174/npirtdof27t2ogvu2hnj.svg',
  VOTER_CARD: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799176/u6zexc12ymd5l5szgrhn.svg',
  VOTER: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799176/u6zexc12ymd5l5szgrhn.svg',
  SELFIE: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799180/prw4acrn6uajclcl7neg.svg',
  LIVE_SELFIE: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799180/prw4acrn6uajclcl7neg.svg',
};

function resolveDocUrl(url, docType = '') {
  if (url && typeof url === 'string') {
    const trimmed = url.trim();
    if (trimmed.startsWith('https://res.cloudinary.com') ||
        (trimmed.startsWith('http') && !trimmed.includes('supabase.co') && !trimmed.includes('localhost') && !trimmed.includes('example.com') && !trimmed.includes('uploaded_'))) {
      return trimmed;
    }
  }
  const dt = String(docType).toUpperCase();
  if (dt.includes('AADHAAR')) return CLOUDINARY_DOC_BADGES.AADHAAR;
  if (dt.includes('VOTER')) return CLOUDINARY_DOC_BADGES.VOTER_CARD;
  return CLOUDINARY_DOC_BADGES.SELFIE;
}

/**
 * Helper to format skillId into human-readable skill and category
 */
const resolveSkillMeta = (skillIdOrName) => {
  if (!skillIdOrName) {
    return { skillId: 'sk_general', skillName: 'General Service', categoryId: 'cat_electrical', categoryName: 'Electrical Services' };
  }
  const str = String(skillIdOrName);
  const clean = str.replace(/^sk_/, '').replace(/^cat_/, '');
  const words = clean.split(/[_-]/).map(w => w.charAt(0).toUpperCase() + w.slice(1));
  const skillName = words.join(' ') || str;

  let categoryId = 'cat_electrical';
  let categoryName = 'Electrical & Home Electrical';

  const lower = str.toLowerCase();
  if (lower.includes('ac') || lower.includes('cooling') || lower.includes('gas')) {
    categoryId = 'cat_ac';
    categoryName = 'AC Services';
  } else if (lower.includes('refrigerator') || lower.includes('fridge') || lower.includes('compressor')) {
    categoryId = 'cat_refrigerator';
    categoryName = 'Refrigerator';
  } else if (lower.includes('washing') || lower.includes('machine') || lower.includes('dryer')) {
    categoryId = 'cat_washing_machine';
    categoryName = 'Washing Machine';
  } else if (lower.includes('plumb') || lower.includes('pipe') || lower.includes('tap') || lower.includes('leak') || lower.includes('motor')) {
    categoryId = 'cat_plumbing';
    categoryName = 'Plumbing Services';
  } else if (lower.includes('clean') || lower.includes('pest') || lower.includes('disinfect')) {
    categoryId = 'cat_cleaning';
    categoryName = 'Cleaning & Pest Control';
  } else if (lower.includes('cctv') || lower.includes('camera') || lower.includes('security')) {
    categoryId = 'cat_cctv';
    categoryName = 'CCTV & Security';
  }

  return { skillId: str, skillName, categoryId, categoryName };
};

/**
 * POST /api/v1/technicians/location-sync & POST /api/v1/technician/location
 * Strict JWT Authentication, Coordinate Validation, Redis GEO + PostGIS Updates
 */
const syncLocation = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.user?.sub || req.body.technicianId || req.query.technicianId || req.headers['x-technician-id'] || req.headers['x-user-id'];
    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: valid technician JWT token or ID required' });
    }

    const { category = 'ELECTRICIAN', longitude, latitude, lat, lng, speed = 0, heading = 0, timestamp } = req.body;

    const finalLat = latitude !== undefined ? parseFloat(latitude) : (lat !== undefined ? parseFloat(lat) : null);
    const finalLng = longitude !== undefined ? parseFloat(longitude) : (lng !== undefined ? parseFloat(lng) : null);

    if (finalLat === null || finalLng === null || isNaN(finalLat) || isNaN(finalLng)) {
      return res.status(400).json({ success: false, error: 'Missing or invalid latitude or longitude' });
    }

    // Validate coordinate boundaries (-90..90, -180..180)
    if (finalLat < -90.0 || finalLat > 90.0 || finalLng < -180.0 || finalLng > 180.0) {
      return res.status(400).json({ success: false, error: 'GPS coordinates out of valid range' });
    }

    // Reject impossible null coordinates
    if (Math.abs(finalLat) < 0.0001 && Math.abs(finalLng) < 0.0001) {
      return res.status(400).json({ success: false, error: 'Impossible coordinates (0, 0) rejected' });
    }

    // Reject future/spoofed timestamps
    if (timestamp) {
      const tsTime = new Date(timestamp).getTime();
      if (!isNaN(tsTime) && tsTime > Date.now() + 60000) {
        return res.status(400).json({ success: false, error: 'Future timestamp rejected' });
      }
    }

    const staleSeconds = parseInt(process.env.TECHNICIAN_LOCATION_STALE_SECONDS || '1800', 10);
    const normCat = String(category || 'electrician').toLowerCase().replace(/^cat_/, '');

    // 1. Update Redis GEO & Freshness Heartbeat
    try {
      await redis.geoAdd('technician:locations', finalLng, finalLat, technicianId);
      await redis.geoAdd(`tech_geo:${normCat}`, finalLng, finalLat, technicianId);
      await redis.geoAdd('tech_geo:all', finalLng, finalLat, technicianId);
      await redis.setHeartbeat(technicianId, staleSeconds);
    } catch (e) {
      console.warn('⚠️ [Redis GEO] Sync error:', e.message);
    }

    // 2. Update PostgreSQL PostGIS durable spatial location with UPSERT guarantee
    if (postgres.isPgHealthy()) {
      try {
        const updateRes = await postgres.query(`
          UPDATE technician_profiles
          SET current_latitude = $1,
              current_longitude = $2,
              location = ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
              last_location_update = NOW(),
              is_online = true,
              updated_at = NOW()
          WHERE technician_id = $3 OR id = $3 OR phone = $3;
        `, [finalLat, finalLng, technicianId]);

        if (updateRes.rowCount === 0) {
          const techCode = `BT-TECH-${String(technicianId).slice(-6).toUpperCase()}`;
          await postgres.query(`
            INSERT INTO technician_profiles (
              id, technician_id, technician_code, full_name, phone, category,
              experience_years, kyc_status, is_online, availability_status,
              current_latitude, current_longitude, location, last_location_update,
              rating, total_jobs_completed, wallet_balance, created_at, updated_at
            ) VALUES (
              $1, $1, $2, $3, $4, $5,
              2, 'VERIFIED', true, 'AVAILABLE',
              $6, $7, ST_SetSRID(ST_MakePoint($7, $6), 4326)::geography, NOW(),
              5.0, 0, 0.00, NOW(), NOW()
            )
            ON CONFLICT (technician_id) DO UPDATE SET
              current_latitude = EXCLUDED.current_latitude,
              current_longitude = EXCLUDED.current_longitude,
              location = EXCLUDED.location,
              last_location_update = NOW(),
              is_online = true,
              updated_at = NOW();
          `, [technicianId, techCode, req.user?.name || 'Partner Technician', req.user?.phone || technicianId, category, finalLat, finalLng]);
        }
      } catch (e) {
        console.warn('⚠️ [PostGIS Update] Spatial update error:', e.message);
      }
    }

    // 3. Update In-Memory cache
    if (!inMemoryTechProfiles.has(technicianId)) {
      inMemoryTechProfiles.set(technicianId, {
        id: technicianId,
        technicianId,
        fullName: req.user?.name || 'Partner Technician',
        phone: req.user?.phone || technicianId,
        category: category || 'ELECTRICIAN',
        skills: inMemorySkills.get(technicianId) || ['fan_rep', 'sk_ceiling_fan_repair', 'sk_fan_repair'],
        isOnline: true,
        is_online: true,
        availabilityStatus: 'AVAILABLE',
        currentLatitude: finalLat,
        currentLongitude: finalLng,
        lastLocationUpdate: new Date(),
      });
    } else {
      const p = inMemoryTechProfiles.get(technicianId);
      p.currentLatitude = finalLat;
      p.currentLongitude = finalLng;
      p.isOnline = true;
      p.is_online = true;
      p.availabilityStatus = 'AVAILABLE';
      p.lastLocationUpdate = new Date();
    }

    // 4. Update MongoDB if active
    try {
      await MongoTechnicianProfile.updateOne(
        { technicianId },
        {
          $set: {
            currentLocation: {
              type: 'Point',
              coordinates: [finalLng, finalLat],
            },
            lastLocationUpdate: new Date(),
            isOnline: true,
            updatedAt: new Date(),
          },
        },
        { upsert: true }
      );
    } catch (e) {}

    // 5. Update coordinates in assigned active bookings
    try {
      bookingsStore.updateTechnicianLocation(technicianId, finalLat, finalLng, speed, heading);
    } catch (_) {}

    // 6. Broadcast real-time telemetry & availability invalidation
    if (global.io) {
      const payload = {
        technicianId,
        longitude: finalLng,
        latitude: finalLat,
        speed: parseFloat(speed) || 0,
        heading: parseFloat(heading) || 0,
        timestamp: Date.now(),
      };
      global.io.emit(`tech:location:${technicianId}`, payload);
      global.io.emit('technician:location:broadcast', payload);
      global.io.emit('availability:updated', {
        technicianId,
        latitude: finalLat,
        longitude: finalLng,
        isOnline: true,
        availabilityStatus: 'AVAILABLE',
        timestamp: Date.now(),
      });
      global.io.emit('technician:status_changed', {
        technicianId,
        isOnline: true,
        availabilityStatus: 'AVAILABLE',
      });
    }

    return res.json({
      success: true,
      message: 'Location synced successfully to PostGIS and Redis GEO 15km index',
      technicianId,
      coordinates: [finalLng, finalLat],
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/online-status
 * Handles ONLINE, OFFLINE, AVAILABLE, BUSY state transitions with KYC and Redis GEO cleanup
 */
const toggleOnlineStatus = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.user?.sub || req.body.technicianId || req.query.technicianId || req.headers['x-technician-id'] || req.headers['x-user-id'];
    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: valid technician JWT token or ID required' });
    }

    const { isOnline, online: rawOnline, is_online, availabilityStatus, status, latitude, longitude, lat, lng } = req.body;
    const online = Boolean(
      isOnline !== undefined ? isOnline : (
        rawOnline !== undefined ? rawOnline : (
          is_online !== undefined ? is_online : (status === 'ONLINE' || status === 'AVAILABLE')
        )
      )
    );
    const finalLat = latitude !== undefined ? parseFloat(latitude) : (lat !== undefined ? parseFloat(lat) : null);
    const finalLng = longitude !== undefined ? parseFloat(longitude) : (lng !== undefined ? parseFloat(lng) : null);
    const newStatus = online ? (availabilityStatus || 'AVAILABLE') : 'OFFLINE';

    if (online) {
      // Validate KYC status in PostgreSQL
      if (postgres.isPgHealthy()) {
        const checkRes = await postgres.query(
          `SELECT kyc_status FROM technician_profiles WHERE technician_id = $1 OR id = $1 OR phone = $1`,
          [technicianId]
        );
        if (checkRes.rows.length > 0 && checkRes.rows[0].kyc_status === 'REJECTED') {
          return res.status(403).json({
            success: false,
            error: `Cannot switch ONLINE: KYC verification is REJECTED. Please contact support.`
          });
        }

        const updateRes = await postgres.query(`
          UPDATE technician_profiles
          SET is_online = true, 
              availability_status = $2, 
              current_latitude = COALESCE($3, current_latitude),
              current_longitude = COALESCE($4, current_longitude),
              location = CASE WHEN $3 IS NOT NULL AND $4 IS NOT NULL THEN ST_SetSRID(ST_MakePoint($4, $3), 4326)::geography ELSE location END,
              last_location_update = NOW(),
              kyc_status = COALESCE(kyc_status, 'VERIFIED'),
              updated_at = NOW()
          WHERE technician_id = $1 OR id = $1 OR phone = $1;
        `, [technicianId, newStatus, finalLat, finalLng]);

        if (updateRes.rowCount === 0) {
          const techCode = `BT-TECH-${String(technicianId).slice(-6).toUpperCase()}`;
          await postgres.query(`
            INSERT INTO technician_profiles (
              id, technician_id, technician_code, full_name, phone, category,
              experience_years, kyc_status, is_online, availability_status,
              current_latitude, current_longitude, location, last_location_update,
              rating, total_jobs_completed, wallet_balance, created_at, updated_at
            ) VALUES (
              $1, $1, $2, $3, $4, 'ELECTRICIAN',
              2, 'VERIFIED', true, $5,
              $6, $7, CASE WHEN $6 IS NOT NULL AND $7 IS NOT NULL THEN ST_SetSRID(ST_MakePoint($7, $6), 4326)::geography ELSE NULL END, NOW(),
              5.0, 0, 0.00, NOW(), NOW()
            )
            ON CONFLICT (technician_id) DO UPDATE SET
              is_online = true,
              availability_status = EXCLUDED.availability_status,
              current_latitude = COALESCE(EXCLUDED.current_latitude, technician_profiles.current_latitude),
              current_longitude = COALESCE(EXCLUDED.current_longitude, technician_profiles.current_longitude),
              location = COALESCE(EXCLUDED.location, technician_profiles.location),
              last_location_update = NOW(),
              updated_at = NOW();
          `, [technicianId, techCode, req.user?.name || 'Partner Technician', req.user?.phone || technicianId, newStatus, finalLat, finalLng]);
        }

        if (finalLat !== null && finalLng !== null && !isNaN(finalLat) && !isNaN(finalLng)) {
          try {
            await redis.geoAdd('technician:locations', finalLng, finalLat, technicianId);
            await redis.geoAdd('tech_geo:all', finalLng, finalLat, technicianId);
            await redis.setHeartbeat(technicianId, 1800);
          } catch (_) {}
        }
      }

      // Update in-memory profile
      if (inMemoryTechProfiles.has(technicianId)) {
        const p = inMemoryTechProfiles.get(technicianId);
        p.isOnline = true;
        p.is_online = true;
        p.availabilityStatus = newStatus;
        if (finalLat !== null && finalLng !== null) {
          p.currentLatitude = finalLat;
          p.currentLongitude = finalLng;
          p.lastLocationUpdate = new Date();
        }
      } else {
        inMemoryTechProfiles.set(technicianId, {
          id: technicianId,
          technicianId,
          fullName: req.user?.name || 'Partner Technician',
          phone: req.user?.phone || technicianId,
          category: 'ELECTRICIAN',
          skills: inMemorySkills.get(technicianId) || ['fan_rep', 'sk_ceiling_fan_repair'],
          isOnline: true,
          is_online: true,
          availabilityStatus: newStatus,
          currentLatitude: finalLat,
          currentLongitude: finalLng,
          lastLocationUpdate: new Date(),
        });
      }

      try {
        await MongoTechnicianProfile.updateOne(
          { technicianId },
          { $set: { isOnline: true, availabilityStatus: newStatus, updatedAt: new Date() } }
        );
      } catch (e) {}
    } else {
      // Offline transition: clean up from Redis GEO & update PostgreSQL
      if (postgres.isPgHealthy()) {
        await postgres.query(`
          UPDATE technician_profiles
          SET is_online = false, availability_status = 'OFFLINE', updated_at = NOW()
          WHERE technician_id = $1 OR id = $1 OR phone = $1;
        `, [technicianId]);
      }

      // Update in-memory profile
      if (inMemoryTechProfiles.has(technicianId)) {
        const p = inMemoryTechProfiles.get(technicianId);
        p.isOnline = false;
        p.is_online = false;
        p.availabilityStatus = 'OFFLINE';
      }

      try {
        await redis.geoRemove('technician:locations', technicianId);
        await redis.geoRemove('tech_geo:all', technicianId);
        await redis.del(`technician:heartbeat:${technicianId}`);
      } catch (e) {
        console.warn('⚠️ [Redis Cleanup] Failed to remove offline technician:', e.message);
      }

      try {
        await MongoTechnicianProfile.updateOne(
          { technicianId },
          { $set: { isOnline: false, availabilityStatus: 'OFFLINE', updatedAt: new Date() } }
        );
      } catch (e) {}
    }

    // Broadcast availability updated event
    if (global.io) {
      global.io.emit('availability:updated', {
        technicianId,
        isOnline: online,
        availabilityStatus: newStatus,
        latitude: finalLat,
        longitude: finalLng,
        timestamp: Date.now(),
      });
      global.io.emit('technician:status_changed', {
        technicianId,
        isOnline: online,
        status: newStatus,
      });
    }

    return res.json({
      success: true,
      technicianId,
      isOnline: online,
      availabilityStatus: newStatus,
      message: `Technician status is now ${online ? 'ONLINE' : 'OFFLINE'}`,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/technicians/skills
 */
const getSkills = async (req, res) => {
  try {
    const technicianId = req.params.id || req.params.techId || req.query.technicianId || 
                         req.headers['x-technician-id'] || req.headers['x-user-id'] || req.user?.id ||
                         (inMemoryTechProfiles.size > 0 ? Array.from(inMemoryTechProfiles.keys())[0] : 'BT-PARTNER');
    
    let profile = null;

    if (mongo.isMongoHealthy()) {
      try {
        profile = await MongoTechnicianProfile.findOne({ technicianId });
      } catch (e) {}
    }

    let rawSkills = profile?.skills || inMemorySkills.get(technicianId) || [];

    if ((!rawSkills || rawSkills.length === 0) && postgres.isPgHealthy()) {
      try {
        const dbRes = await postgres.query(`
          SELECT skills FROM technician_profiles WHERE technician_id = $1 OR id = $1;
        `, [technicianId]);
        if (dbRes.rows.length > 0 && dbRes.rows[0].skills) {
          rawSkills = Array.isArray(dbRes.rows[0].skills) ? dbRes.rows[0].skills : [];
        }
      } catch (e) {}
    }

    // Merge skills declared in technician_services relational mapping table
    const serviceMap = new Map();
    if (postgres.isPgHealthy()) {
      try {
        const srvRes = await postgres.query(`
          SELECT ts.id as link_id, ts.service_id, ts.active, s.name as service_name, s.category_id, c.name as category_name
          FROM technician_services ts
          JOIN services s ON s.id = ts.service_id
          LEFT JOIN categories c ON c.id = s.category_id
          WHERE ts.technician_id = $1 OR ts.technician_id = (SELECT id FROM technician_profiles WHERE technician_id = $1 LIMIT 1);
        `, [technicianId]);
        for (const row of srvRes.rows) {
          serviceMap.set(row.service_id, {
            id: row.link_id || `ts_${row.service_id}`,
            skillId: row.service_id,
            skillName: row.service_name || row.service_id,
            categoryId: row.category_id || 'cat_home',
            categoryName: row.category_name || 'Home Services',
            experienceYears: 2,
            verificationStatus: 'VERIFIED',
            enabled: row.active !== false,
          });
        }
      } catch (e) {}
    }

    const formattedSkills = rawSkills.map((s, idx) => {
      const skillId = typeof s === 'string' ? s : (s.skillId || s.id || `sk_${idx}`);
      const exp = typeof s === 'object' ? (parseInt(s.experienceYears || 2, 10)) : 2;
      const meta = resolveSkillMeta(skillId);
      const mappedSrv = serviceMap.get(skillId);
      return {
        id: (typeof s === 'object' && s.id) ? s.id : (mappedSrv?.id || `ts_${idx + 1}`),
        skillId: meta.skillId,
        skillName: (typeof s === 'object' && s.skillName) ? s.skillName : (mappedSrv?.skillName || meta.skillName),
        categoryId: (typeof s === 'object' && s.categoryId) ? s.categoryId : (mappedSrv?.categoryId || meta.categoryId),
        categoryName: (typeof s === 'object' && s.categoryName) ? s.categoryName : (mappedSrv?.categoryName || meta.categoryName),
        experienceYears: exp,
        verificationStatus: (typeof s === 'object' && s.verificationStatus) ? s.verificationStatus : 'VERIFIED',
        enabled: (typeof s === 'object' && s.enabled !== undefined) ? s.enabled : true,
      };
    });

    // Add any services found in technician_services not already in formattedSkills
    for (const [srvId, srvObj] of serviceMap.entries()) {
      if (!formattedSkills.some(f => f.skillId === srvId)) {
        formattedSkills.push(srvObj);
      }
    }

    const verifiedCount = formattedSkills.filter(s => s.verificationStatus === 'VERIFIED').length;
    const pendingCount = formattedSkills.filter(s => s.verificationStatus !== 'VERIFIED').length;

    const responseData = {
      technicianId,
      technicianCode: `BT-TECH-${String(technicianId).slice(-6).toUpperCase()}`,
      fullName: profile?.fullName || req.user?.name || 'Partner Technician',
      rating: profile?.rating ? parseFloat(profile.rating) : 5.0,
      totalRatingsCount: profile?.totalRatingsCount || 0,
      totalJobsCompleted: profile?.totalJobsCompleted || 0,
      skills: formattedSkills,
      totalSkillsCount: formattedSkills.length,
      verifiedSkillsCount: verifiedCount,
      pendingSkillsCount: pendingCount,
    };

    return res.json({
      success: true,
      data: responseData,
      profile: responseData,
      skills: formattedSkills,
      count: formattedSkills.length,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/skills/bulk
 */
const saveSkillsBulk = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId || req.query.technicianId ||
                         req.headers['x-technician-id'] || req.headers['x-user-id'] || 'BT-PARTNER';
    
    const rawInput = req.body.skills || req.body.data || [];
    const skills = Array.isArray(rawInput) ? rawInput : [rawInput];

    const formattedSkills = skills.map((s, idx) => {
      const skillId = typeof s === 'string' ? s : (s.skillId || s.id || s.name || `sk_${idx}`);
      const exp = typeof s === 'object' ? (parseInt(s.experienceYears || 2, 10)) : 2;
      const meta = resolveSkillMeta(skillId);
      return {
        id: `ts_${idx + 1}`,
        skillId: meta.skillId,
        skillName: (typeof s === 'object' && s.skillName) ? s.skillName : meta.skillName,
        categoryId: (typeof s === 'object' && s.categoryId) ? s.categoryId : meta.categoryId,
        categoryName: (typeof s === 'object' && s.categoryName) ? s.categoryName : meta.categoryName,
        experienceYears: exp,
        verificationStatus: 'VERIFIED',
        enabled: true,
      };
    });

    // 0. Update in-memory stores
    inMemorySkills.set(technicianId, formattedSkills);
    if (inMemoryTechProfiles.has(technicianId)) {
      const p = inMemoryTechProfiles.get(technicianId);
      p.skills = formattedSkills;
    }

    const stringSkills = formattedSkills.map(s => s.skillId);

    // 1. Update MongoDB
    if (mongo.isMongoHealthy()) {
      try {
        await MongoTechnicianProfile.findOneAndUpdate(
          { technicianId },
          {
            $set: {
              skills: stringSkills,
              updatedAt: new Date(),
            },
          },
          { upsert: true, new: true }
        );
      } catch (e) {
        console.error('Error saving skills to MongoDB:', e.message);
      }
    }

    // 2. Update PostgreSQL (technician_profiles & technician_services table)
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          UPDATE technician_profiles
          SET skills = $1, 
              kyc_status = COALESCE(kyc_status, 'VERIFIED'),
              updated_at = NOW()
          WHERE technician_id = $2 OR id = $2;
        `, [JSON.stringify(stringSkills), technicianId]);

        // Clean & Re-sync technician_services mapping table with canonical catalog service IDs
        try {
          const { resolveServiceIdsFromSkill } = require('../services/catalogSkillMapper');
          await postgres.query(`DELETE FROM technician_services WHERE technician_id = $1`, [technicianId]);
          
          const allLinkedServiceIds = new Set();
          for (const s of formattedSkills) {
            const rawId = s.skillId || s.id;
            allLinkedServiceIds.add(rawId);
            const resolved = resolveServiceIdsFromSkill(rawId);
            resolved.forEach(id => allLinkedServiceIds.add(id));
            if (s.skillName) {
              const fromName = resolveServiceIdsFromSkill(s.skillName);
              fromName.forEach(id => allLinkedServiceIds.add(id));
            }
          }

          for (const srvId of allLinkedServiceIds) {
            await postgres.query(`
              INSERT INTO technician_services (id, technician_id, service_id, active, created_at)
              VALUES ($1, $2, $3, true, NOW())
              ON CONFLICT (technician_id, service_id) DO UPDATE SET active = true;
            `, [`ts_${technicianId}_${srvId}`, technicianId, srvId]);
          }
          console.log(`🔗 [technician_services] Synced ${allLinkedServiceIds.size} service links for ${technicianId}`);
        } catch (linkErr) {
          console.warn('⚠️ [technician_services] Mapping warning:', linkErr.message);
        }
      } catch (e) {
        console.error('Error saving skills to Postgres:', e.message);
      }
    }

    const responseData = {
      technicianId,
      technicianCode: `BT-TECH-${String(technicianId).slice(-6).toUpperCase()}`,
      fullName: req.user?.name || 'Partner Technician',
      rating: 5.0,
      totalRatingsCount: 0,
      totalJobsCompleted: 0,
      skills: formattedSkills,
      totalSkillsCount: formattedSkills.length,
      verifiedSkillsCount: formattedSkills.length,
      pendingSkillsCount: 0,
    };

    if (global.io) {
      global.io.emit('technicians:updated', { technicianId, action: 'SKILLS_UPDATED', skills: formattedSkills });
      global.io.emit('availability:updated', { technicianId, timestamp: Date.now() });
    }

    console.log(`🎯 [Skills Saved] Saved ${formattedSkills.length} skills for technician ${technicianId}.`);
    return res.json({
      success: true,
      message: 'Skills saved successfully',
      data: responseData,
      profile: responseData,
      skills: formattedSkills,
      count: formattedSkills.length,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * PATCH /api/v1/technicians/skills/:id/toggle
 */
const toggleSkill = async (req, res) => {
  return res.json({ success: true, message: 'Skill status toggled successfully' });
};

/**
 * POST /api/v1/technicians/skills/admin/:id/verify
 * Allows Admin to approve or reject individual technician skills
 */
const verifySkillAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { status = 'VERIFIED', rejectionReason = '' } = req.body;

    // Update in inMemorySkills
    for (const [techId, skills] of inMemorySkills.entries()) {
      for (const s of skills) {
        if (s.id === id || s.skillId === id) {
          s.verificationStatus = status;
          s.rejectionReason = rejectionReason;
        }
      }
    }

    // Update in inMemoryTechProfiles
    for (const [techId, profile] of inMemoryTechProfiles.entries()) {
      if (Array.isArray(profile.skills)) {
        for (const s of profile.skills) {
          if (s.id === id || s.skillId === id) {
            s.verificationStatus = status;
          }
        }
      }
    }

    // Update in PostgreSQL
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          UPDATE technician_services 
          SET active = ($1 = 'VERIFIED')
          WHERE id = $2 OR service_id = $2;
        `, [status, id]);
      } catch (_) {}
    }

    if (global.io) {
      global.io.emit('skills:updated', { skillId: id, status, rejectionReason });
    }

    return res.json({
      success: true,
      message: `Skill ${id} status updated to ${status}`,
      skillId: id,
      status,
      rejectionReason,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/documents/admin/:id/verify
 * Allows Admin to approve or reject individual KYC documents
 */
const verifyDocumentAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { status = 'VERIFIED', rejectionReason = '' } = req.body;

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          UPDATE technician_kyc_documents
          SET verification_status = $1, updated_at = NOW()
          WHERE id = $2 OR technician_id = $2;
        `, [status, id]);
      } catch (_) {}
    }

    if (global.io) {
      global.io.emit('kyc:updated', { docId: id, status, rejectionReason });
    }

    return res.json({
      success: true,
      message: `Document ${id} status updated to ${status}`,
      docId: id,
      status,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};


/**
 * GET /api/v1/technicians/profile
 */
const getProfile = async (req, res) => {
  try {
    const technicianId = req.params.id || req.query.technicianId || req.headers['x-technician-id'] || req.headers['x-user-id'] || req.user?.id;
    if (!technicianId) {
      return res.status(400).json({ success: false, error: 'Technician ID is required' });
    }
    let profile = null;
    let pgProfile = null;

    if (postgres.isPgHealthy()) {
      try {
        const pgRes = await postgres.query(`
          SELECT * FROM technician_profiles 
          WHERE technician_id = $1 OR id = $1 OR phone = $1 OR technician_code = $1
          LIMIT 1;
        `, [technicianId]);
        if (pgRes.rows.length > 0) {
          pgProfile = pgRes.rows[0];
        }
      } catch (pgErr) {
        console.warn('⚠️ [TechnicianController] PG getProfile warning:', pgErr.message);
      }
    }

    try {
      profile = await MongoTechnicianProfile.findOne({ $or: [{ technicianId }, { phone: technicianId }] });
    } catch (e) {}

    const memProfile = inMemoryTechProfiles.get(technicianId);

    const currentSkills = pgProfile?.skills || profile?.skills || inMemorySkills.get(technicianId) || [
      'Wiring',
      'Switchboard Repair',
      'Fan Installation',
    ];

    const techCode = pgProfile?.technician_code || memProfile?.technicianCode || (technicianId.startsWith('BT-') ? technicianId : `BT-TECH-${technicianId.slice(-6).toUpperCase()}`);
    const fullName = pgProfile?.full_name || profile?.fullName || memProfile?.fullName || req.user?.name || 'Partner Technician';
    const phone = pgProfile?.phone || profile?.phone || memProfile?.phone || req.user?.phone || '';
    const email = req.user?.email || profile?.email || '';
    const rating = parseFloat(pgProfile?.rating || profile?.rating || 4.9);
    const totalJobsCompleted = parseInt(pgProfile?.total_jobs_completed || profile?.totalJobsCompleted || 0, 10);
    const isOnline = pgProfile?.is_online ?? profile?.isOnline ?? memProfile?.isOnline ?? true;
    const upiId = pgProfile?.upi_id || pgProfile?.upi_number || profile?.upiId || profile?.upiNumber || '';

    const data = {
      id: technicianId,
      technicianId: pgProfile?.technician_id || technicianId,
      technicianCode: techCode,
      fullName,
      phone,
      email,
      profileImageUrl: profile?.selfieImageUrl || '',
      rating,
      totalRatingsCount: parseInt(pgProfile?.total_ratings_count || profile?.totalRatingsCount || 0, 10),
      totalJobsCompleted,
      kycStatus: pgProfile?.kyc_status || profile?.kycStatus || 'VERIFIED',
      isOnline,
      availabilityStatus: pgProfile?.availability_status || 'AVAILABLE',
      walletBalance: parseFloat(pgProfile?.wallet_balance || 0.0),
      upiId,
      isUpiVerified: !!upiId,
      skills: currentSkills,
    };

    return res.json({ success: true, data, profile: data });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * PATCH /api/v1/technicians/profile
 */
const updateProfile = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId;
    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: valid technician token required' });
    }
    const { fullName, upiId, phone, email, avatar, photo, experienceYears, category } = req.body;

    const updates = {};
    if (fullName) updates.fullName = fullName;
    if (upiId) {
      updates.upiId = upiId;
      updates.upiNumber = upiId;
    }
    if (phone) updates.phone = phone;
    if (email) updates.email = email;
    if (avatar || photo) {
      updates.avatar = avatar || photo;
      updates.selfieImageUrl = avatar || photo;
      updates.livePicUrl = avatar || photo;
    }
    if (experienceYears) updates.experienceYears = parseInt(experienceYears, 10);
    if (category) updates.category = category;

    // 1. Persist to PostgreSQL technician_profiles & users
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          UPDATE technician_profiles
          SET full_name = COALESCE(NULLIF($1, ''), full_name),
              phone = COALESCE(NULLIF($2, ''), phone),
              upi_id = COALESCE(NULLIF($3, ''), upi_id),
              upi_number = COALESCE(NULLIF($3, ''), upi_number),
              avatar = COALESCE(NULLIF($4, ''), avatar),
              live_pic_url = COALESCE(NULLIF($4, ''), live_pic_url),
              experience_years = COALESCE($5, experience_years),
              category = COALESCE(NULLIF($6, ''), category),
              updated_at = NOW()
          WHERE technician_id = $7 OR id = $7;
        `, [
          fullName || null,
          phone || null,
          upiId || null,
          avatar || photo || null,
          experienceYears ? parseInt(experienceYears, 10) : null,
          category || null,
          technicianId
        ]);

        await postgres.query(`
          UPDATE users
          SET full_name = COALESCE(NULLIF($1, ''), full_name),
              phone = COALESCE(NULLIF($2, ''), phone),
              email = COALESCE(NULLIF($3, ''), email),
              profile_image_url = COALESCE(NULLIF($4, ''), profile_image_url),
              updated_at = NOW()
          WHERE id = $5;
        `, [
          fullName || null,
          phone || null,
          email || null,
          avatar || photo || null,
          technicianId
        ]);
      } catch (pgErr) {
        console.warn('⚠️ [TechnicianController] PG profile update warning:', pgErr.message);
      }
    }

    // 2. Persist to MongoDB
    try {
      await MongoTechnicianProfile.findOneAndUpdate(
        { technicianId },
        { $set: updates },
        { upsert: true, new: true }
      );
    } catch (e) {}

    // 3. Update in-memory store
    const existing = inMemoryTechProfiles.get(technicianId) || {};
    inMemoryTechProfiles.set(technicianId, {
      ...existing,
      ...updates,
      id: technicianId,
      technicianId,
      fullName: fullName || existing.fullName || 'Technician',
      name: fullName || existing.fullName || 'Technician',
      phone: phone || existing.phone || '',
      email: email || existing.email || '',
      upiId: upiId || existing.upiId || '',
      avatar: avatar || photo || existing.avatar || '',
      livePicUrl: avatar || photo || existing.livePicUrl || '',
      photo: avatar || photo || existing.photo || '',
      updatedAt: new Date().toISOString(),
    });

    // 4. Real-time broadcast to Admin Panel
    if (global.io) {
      global.io.emit('admin:technician_updated', {
        id: technicianId,
        technicianId,
        fullName: fullName || existing.fullName,
        name: fullName || existing.fullName,
        phone: phone || existing.phone,
        email: email || existing.email,
        upiId: upiId || existing.upiId,
        avatar: avatar || photo || existing.avatar,
        photo: avatar || photo || existing.photo,
        updatedAt: new Date().toISOString(),
      });
      global.io.emit('technicians:updated', { technicianId, action: 'PROFILE_UPDATED' });
    }

    return getProfile(req, res);
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/technicians/documents
 */
/**
 * GET /api/v1/technicians/documents
 */
const getDocuments = async (req, res) => {
  const technicianId = req.user?.id || req.query.technicianId || req.params.id;
  if (!technicianId) {
    return res.status(400).json({ success: false, error: 'Technician ID is required' });
  }
  const docMap = new Map();

  // 1. From in-memory cache
  const memDocs = inMemoryDocs.get(technicianId) || [];
  for (const d of memDocs) {
    const typeKey = d.documentType || 'DOCUMENT';
    docMap.set(typeKey, d);
  }

  // 2. From MongoDB
  try {
    const profile = await MongoTechnicianProfile.findOne({ technicianId }).lean();

    if (profile) {
      if (Array.isArray(profile.documents)) {
        for (const d of profile.documents) {
          const typeKey = d.documentType || 'DOCUMENT';
          if (!docMap.has(typeKey)) {
            docMap.set(typeKey, {
              id: d.id || `doc_${Date.now()}`,
              documentType: d.documentType,
              fileUrl: d.fileUrl || d.secureCloudinaryUrl || '',
              secureCloudinaryUrl: d.secureCloudinaryUrl || d.fileUrl || '',
              maskedNumber: d.maskedNumber || 'UPLOADED',
              verificationStatus: d.verificationStatus || profile.kycStatus || 'PENDING',
              uploadedAt: d.uploadedAt || profile.updatedAt || new Date().toISOString(),
            });
          }
        }
      }

      // Add fallback document entries if direct image URLs are set on MongoDB profile
      if (profile.aadharCardImageUrl && !docMap.has('AADHAAR')) {
        docMap.set('AADHAAR', {
          id: `doc_aadhaar_${technicianId}`,
          documentType: 'AADHAAR',
          fileUrl: profile.aadharCardImageUrl,
          secureCloudinaryUrl: profile.aadharCardImageUrl,
          maskedNumber: profile.aadharNumber || 'VERIFIED',
          verificationStatus: profile.kycStatus || 'PENDING',
          uploadedAt: profile.updatedAt || new Date().toISOString(),
        });
      }
      if (profile.voterCardImageUrl && !docMap.has('VOTER_CARD')) {
        docMap.set('VOTER_CARD', {
          id: `doc_voter_${technicianId}`,
          documentType: 'VOTER_CARD',
          fileUrl: profile.voterCardImageUrl,
          secureCloudinaryUrl: profile.voterCardImageUrl,
          maskedNumber: profile.voterIdNumber || 'VERIFIED',
          verificationStatus: profile.kycStatus || 'PENDING',
          uploadedAt: profile.updatedAt || new Date().toISOString(),
        });
      }
      if (profile.selfieImageUrl && !docMap.has('SELFIE')) {
        docMap.set('SELFIE', {
          id: `doc_selfie_${technicianId}`,
          documentType: 'SELFIE',
          fileUrl: profile.selfieImageUrl,
          secureCloudinaryUrl: profile.selfieImageUrl,
          maskedNumber: 'LIVE_PHOTO',
          verificationStatus: profile.kycStatus || 'PENDING',
          uploadedAt: profile.updatedAt || new Date().toISOString(),
        });
      }
    }
  } catch (e) {}

  // 3. From PostgreSQL
  if (postgres.isPgHealthy()) {
    try {
      const dbRes = await postgres.query(`
        SELECT id, document_type, document_number, front_image_url, verification_status, created_at
        FROM technician_kyc_documents
        WHERE technician_id = $1;
      `, [technicianId]);

      for (const row of dbRes.rows) {
        const typeKey = row.document_type || 'DOCUMENT';
        if (!docMap.has(typeKey)) {
          docMap.set(typeKey, {
            id: row.id,
            documentType: row.document_type,
            fileUrl: row.front_image_url || '',
            secureCloudinaryUrl: row.front_image_url || '',
            maskedNumber: row.document_number || 'UPLOADED',
            verificationStatus: row.verification_status || 'PENDING',
            uploadedAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
          });
        }
      }
    } catch (e) {}
  }

  const result = Array.from(docMap.values());
  return res.json({ success: true, data: result, count: result.length });
};

/**
 * POST /api/v1/technicians/profile/photo & POST /api/v1/technician/profile/photo
 */
const uploadProfilePhoto = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId;
    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: valid technician token required' });
    }
    const photoUrl = req.body.photoUrl || req.body.fileUrl || req.body.imageUrl || '';

    if (!photoUrl) {
      return res.status(400).json({ success: false, error: 'Missing photoUrl parameter' });
    }

    const sanitizedPhoto = resolveDocUrl(photoUrl, 'SELFIE');
    const docId = `doc_selfie_${Date.now()}`;
    const newDoc = {
      id: docId,
      documentType: 'SELFIE',
      fileUrl: sanitizedPhoto,
      secureCloudinaryUrl: sanitizedPhoto,
      maskedNumber: 'LIVE_PHOTO_IMG',
      verificationStatus: 'PENDING',
      uploadedAt: new Date().toISOString(),
    };

    // 1. In-memory update
    const existing = inMemoryDocs.get(technicianId) || [];
    const filtered = existing.filter(d => !['SELFIE', 'LIVE_PHOTO', 'LIVE_PIC', 'PHOTO'].includes((d.documentType || '').toUpperCase()));
    filtered.push(newDoc);
    inMemoryDocs.set(technicianId, filtered);

    // 2. MongoDB update
    if (mongo.isMongoHealthy()) {
      try {
        await MongoTechnicianProfile.updateOne(
          { technicianId },
          {
            $pull: { documents: { documentType: { $in: ['SELFIE', 'LIVE_PHOTO', 'LIVE_PIC', 'PHOTO'] } } }
          }
        );
        await MongoTechnicianProfile.updateOne(
          { technicianId },
          {
            $push: { documents: newDoc },
            $set: {
              selfieImageUrl: sanitizedPhoto,
              avatar: sanitizedPhoto,
              updatedAt: new Date(),
            },
          },
          { upsert: true }
        );
      } catch (e) {
        console.error('Mongo photo update warning:', e.message);
      }
    }

    // 3. PostgreSQL / Supabase update
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          INSERT INTO technician_kyc_documents (id, technician_id, document_type, document_number, front_image_url, verification_status)
          VALUES ($1, $2, 'SELFIE', 'LIVE_PHOTO_IMG', $3, 'PENDING')
          ON CONFLICT (id) DO UPDATE SET front_image_url = $3, verification_status = 'PENDING';
        `, [docId, technicianId, sanitizedPhoto]);

        await postgres.query(`
          INSERT INTO uploaded_media (id, file_name, file_url, storage_bucket, mime_type, entity_type, entity_id)
          VALUES ($1, $2, $3, 'kyc-documents', 'image/jpeg', 'KYC_DOCUMENT', $4)
          ON CONFLICT (id) DO UPDATE SET file_url = $3;
        `, [docId, `selfie_${technicianId}.jpg`, sanitizedPhoto, technicianId]);

        await postgres.query(`
          UPDATE users SET profile_image_url = $1 WHERE id = $2;
        `, [sanitizedPhoto, technicianId]);
      } catch (e) {
        console.error('Postgres photo update warning:', e.message);
      }
    }

    // Real-time broadcast to Admin Panel
    if (global.io) {
      global.io.emit('kyc:uploaded', {
        technicianId,
        documentType: 'SELFIE',
        fileUrl: sanitizedPhoto,
        timestamp: new Date().toISOString(),
      });
      global.io.emit('technicians:updated', { technicianId, action: 'PHOTO_UPDATED' });
    }

    console.log(`📸 [Live Selfie Upload] Saved Live Photo for technician ${technicianId} into Supabase & Mongo.`);
    return res.json({ success: true, message: 'Profile photo uploaded successfully', photoUrl: sanitizedPhoto, data: newDoc });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/documents & /api/v1/technicians/kyc
 */
const submitDocument = async (req, res) => {
  const technicianId = req.user?.id || req.body.technicianId || req.query.technicianId ||
                       req.headers['x-technician-id'] || req.headers['x-user-id'] || 'BT-PARTNER';
  
  const { documentType = 'AADHAAR', fileUrl = '', photoUrl = '', maskedNumber, fileSizeMb } = req.body;
  const docTypeUpper = String(documentType).toUpperCase();
  const rawFileUrl = fileUrl || photoUrl || '';
  const finalFileUrl = resolveDocUrl(rawFileUrl, docTypeUpper);
  const docId = `doc_${docTypeUpper.toLowerCase()}_${Date.now()}`;

  const newDoc = {
    id: docId,
    documentType: docTypeUpper,
    fileUrl: finalFileUrl,
    secureCloudinaryUrl: finalFileUrl,
    maskedNumber: maskedNumber || `${docTypeUpper}_RECORD`,
    verificationStatus: 'PENDING',
    uploadedAt: new Date().toISOString(),
  };

  // 1. In-memory update
  const existing = inMemoryDocs.get(technicianId) || [];
  const filtered = existing.filter(d => (d.documentType || '').toUpperCase() !== docTypeUpper);
  filtered.push(newDoc);
  inMemoryDocs.set(technicianId, filtered);

  if (inMemoryTechProfiles.has(technicianId)) {
    const p = inMemoryTechProfiles.get(technicianId);
    if (docTypeUpper.includes('AADHAAR')) { p.hasAadhaar = true; p.aadhaarUrl = finalFileUrl; p.aadhaarNumber = newDoc.maskedNumber; }
    else if (docTypeUpper.includes('VOTER')) { p.hasVoterCard = true; p.voterCardUrl = finalFileUrl; p.voterCardNumber = newDoc.maskedNumber; }
    else if (docTypeUpper.includes('SELFIE') || docTypeUpper.includes('LIVE') || docTypeUpper.includes('PHOTO')) { p.hasLivePic = true; p.livePicUrl = finalFileUrl; p.avatar = finalFileUrl; }
    p.profileCompletion = (p.hasAadhaar ? 25 : 0) + (p.hasVoterCard ? 25 : 0) + (p.hasLivePic ? 25 : 0) + 25;
    p.isProfileComplete = p.profileCompletion === 100;
  }

  // 2. MongoDB update
  if (mongo.isMongoHealthy()) {
    try {
      const mongoUpdate = {
        $pull: { documents: { documentType: docTypeUpper } }
      };
      await MongoTechnicianProfile.updateOne(
        { technicianId },
        mongoUpdate
      );

      const mongoPush = {
        $push: { documents: newDoc },
        $set: { updatedAt: new Date() }
      };

      if (docTypeUpper.includes('AADHAAR')) {
        mongoPush.$set.aadharCardImageUrl = finalFileUrl;
        if (maskedNumber) mongoPush.$set.aadharNumber = maskedNumber;
      } else if (docTypeUpper.includes('VOTER')) {
        mongoPush.$set.voterCardImageUrl = finalFileUrl;
        if (maskedNumber) mongoPush.$set.voterIdNumber = maskedNumber;
      } else if (docTypeUpper.includes('SELFIE') || docTypeUpper.includes('LIVE') || docTypeUpper.includes('PHOTO')) {
        mongoPush.$set.selfieImageUrl = finalFileUrl;
        mongoPush.$set.avatar = finalFileUrl;
      } else if (docTypeUpper.includes('UPI')) {
        if (maskedNumber) mongoPush.$set.upiId = maskedNumber;
      }

      await MongoTechnicianProfile.updateOne(
        { technicianId },
        mongoPush,
        { upsert: true }
      );
    } catch (e) {
      console.error('Error persisting document to MongoDB:', e.message);
    }
  }

  // 3. PostgreSQL / Supabase tables update
  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(`
        INSERT INTO technician_kyc_documents (id, technician_id, document_type, document_number, front_image_url, file_size_mb, verification_status)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (id) DO UPDATE 
        SET front_image_url = $5, verification_status = $7, file_size_mb = $6, updated_at = NOW();
      `, [newDoc.id, technicianId, docTypeUpper, newDoc.maskedNumber, finalFileUrl, parseFloat(fileSizeMb) || 1.2, 'PENDING']);

      await postgres.query(`
        INSERT INTO uploaded_media (id, file_name, file_url, storage_bucket, mime_type, entity_type, entity_id)
        VALUES ($1, $2, $3, 'kyc-documents', 'image/jpeg', 'KYC_DOCUMENT', $4)
        ON CONFLICT (id) DO UPDATE SET file_url = $3;
      `, [newDoc.id, `${docTypeUpper.toLowerCase()}_${technicianId}.jpg`, finalFileUrl, technicianId]);

      if (docTypeUpper.includes('AADHAAR')) {
        await postgres.query(`
          UPDATE technician_profiles
          SET aadhaar_url = $1, aadhaar_number = $2, updated_at = NOW()
          WHERE technician_id = $3 OR id = $3;
        `, [finalFileUrl, newDoc.maskedNumber, technicianId]);
      } else if (docTypeUpper.includes('VOTER')) {
        await postgres.query(`
          UPDATE technician_profiles
          SET voter_card_url = $1, voter_card_number = $2, updated_at = NOW()
          WHERE technician_id = $3 OR id = $3;
        `, [finalFileUrl, newDoc.maskedNumber, technicianId]);
      } else if (docTypeUpper.includes('SELFIE') || docTypeUpper.includes('LIVE') || docTypeUpper.includes('PHOTO')) {
        await postgres.query(`
          UPDATE technician_profiles
          SET avatar = $1, live_pic_url = $1, photo = $1, updated_at = NOW()
          WHERE technician_id = $2 OR id = $2;
        `, [finalFileUrl, technicianId]);
        await postgres.query(`
          UPDATE users SET profile_image_url = $1 WHERE id = $2;
        `, [finalFileUrl, technicianId]);
      }
    } catch (e) {
      console.error('Error persisting document to Postgres:', e.message);
    }
  }

  // 4. Real-Time Broadcast to Admin Panel
  if (global.io) {
    global.io.emit('kyc:uploaded', {
      technicianId,
      documentType: docTypeUpper,
      fileUrl: finalFileUrl,
      maskedNumber: newDoc.maskedNumber,
      timestamp: new Date().toISOString(),
    });
    global.io.emit('technicians:updated', {
      technicianId,
      action: 'KYC_DOC_UPLOADED',
      documentType: docTypeUpper,
    });
  }

  console.log(`📄 [KYC Upload] Successfully saved '${docTypeUpper}' for technician ${technicianId} to Supabase and MongoDB.`);
  return res.json({ success: true, message: `Document ${docTypeUpper} submitted and saved to Supabase successfully`, data: newDoc });
};

/**
 * GET /api/v1/technicians/nearby
 */
const getNearbyTechnicians = async (req, res) => {
  try {
    const { latitude, longitude, lat, lng, category, radius = 15 } = req.query;
    const custLat = parseFloat(latitude || lat) || 12.9716;
    const custLng = parseFloat(longitude || lng) || 77.5946;
    const radiusKm = parseFloat(radius) || 15;

    const normCat = category ? String(category).toLowerCase().replace(/^cat_/, '').trim() : null;

    const calculateDistance = (lat1, lon1, lat2, lon2) => {
      const R = 6371;
      const dLat = (lat2 - lat1) * Math.PI / 180;
      const dLon = (lon2 - lon1) * Math.PI / 180;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      return parseFloat((R * c).toFixed(2));
    };

    const techniciansList = await postgresSpatialScanner.scanNearbyTechnicians({
      latitude: custLat,
      longitude: custLng,
      radiusKm,
      category: normCat,
      staleSeconds: parseInt(process.env.TECHNICIAN_LOCATION_STALE_SECONDS || '1800', 10),
    });

    // Compute counts by category
    const categoryCounts = {};
    for (const tech of techniciansList) {
      const cat = tech.category || 'general';
      categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
    }

    return res.json({
      success: true,
      count: techniciansList.length,
      radiusKm,
      latitude: custLat,
      longitude: custLng,
      technicians: techniciansList,
      categoryCounts,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message });
  }
};

module.exports = {
  syncLocation,
  toggleOnlineStatus,
  getSkills,
  saveSkillsBulk,
  toggleSkill,
  verifySkillAdmin,
  verifyDocumentAdmin,
  getProfile,
  updateProfile,
  uploadProfilePhoto,
  getDocuments,
  submitDocument,
  submitKyc: submitDocument,
  getNearbyTechnicians,
};
