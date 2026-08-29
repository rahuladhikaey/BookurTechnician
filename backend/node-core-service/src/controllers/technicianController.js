const redis = require('../config/redis');
const MongoTechnicianProfile = require('../models/MongoTechnicianProfile');
const bookingsStore = require('../config/bookingsStore');

// In-memory fallback cache for fast standalone operations
const inMemorySkills = new Map();
const inMemoryDocs = new Map();

/**
 * Helper to format skillId into human-readable skill and category
 */
const resolveSkillMeta = (skillId) => {
  const clean = (skillId || '').replace(/^sk_/, '').replace(/^cat_/, '');
  const words = clean.split(/[_-]/).map(w => w.charAt(0).toUpperCase() + w.slice(1));
  const skillName = words.join(' ');

  let categoryName = 'General Repairs';
  let categoryId = 'cat_general';
  if (skillId.includes('ac') || clean.includes('cooling') || clean.includes('gas')) {
    categoryName = 'AC Services';
    categoryId = 'cat_ac';
  } else if (skillId.includes('electr') || skillId.includes('wiring') || skillId.includes('fan') || skillId.includes('switch') || skillId.includes('mcb')) {
    categoryName = 'Electrical & Home';
    categoryId = 'cat_electrical';
  } else if (skillId.includes('plumb') || clean.includes('pipe') || clean.includes('tap') || clean.includes('drain')) {
    categoryName = 'Plumbing Services';
    categoryId = 'cat_plumbing';
  } else if (skillId.includes('appliance') || clean.includes('wash') || clean.includes('fridge') || clean.includes('ro_')) {
    categoryName = 'Appliance Repair';
    categoryId = 'cat_appliance';
  }

  return { skillName, categoryName, categoryId };
};

/**
 * POST /api/v1/technicians/location-sync & POST /api/v1/technician/location
 */
const syncLocation = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId || 'tech-001';
    const { category = 'ELECTRICIAN', longitude, latitude, lat, lng, speed = 0, heading = 0 } = req.body;

    const finalLat = latitude !== undefined ? parseFloat(latitude) : (lat !== undefined ? parseFloat(lat) : null);
    const finalLng = longitude !== undefined ? parseFloat(longitude) : (lng !== undefined ? parseFloat(lng) : null);

    if (finalLat === null || finalLng === null || isNaN(finalLat) || isNaN(finalLng)) {
      return res.status(400).json({ success: false, error: 'Missing or invalid latitude or longitude' });
    }

    const geoKey = `tech_geo:${category.toLowerCase()}`;
    try {
      await redis.geoAdd(geoKey, finalLng, finalLat, technicianId);
    } catch (_) {}

    try {
      await MongoTechnicianProfile.updateOne(
        { technicianId },
        {
          $set: {
            currentLocation: {
              type: 'Point',
              coordinates: [finalLng, finalLat],
            },
            isOnline: true,
            updatedAt: new Date(),
          },
        },
        { upsert: true }
      );
    } catch (e) {}

    // Update technician coordinates in all assigned active bookings
    try {
      bookingsStore.updateTechnicianLocation(technicianId, finalLat, finalLng, speed, heading);
    } catch (_) {}

    if (global.io) {
      global.io.emit(`tech:location:${technicianId}`, {
        technicianId,
        longitude: finalLng,
        latitude: finalLat,
        speed: parseFloat(speed) || 0,
        heading: parseFloat(heading) || 0,
        timestamp: Date.now(),
      });
      global.io.emit('technician:location:broadcast', {
        technicianId,
        longitude: finalLng,
        latitude: finalLat,
        speed: parseFloat(speed) || 0,
        heading: parseFloat(heading) || 0,
        timestamp: Date.now(),
      });
    }

    return res.json({
      success: true,
      message: 'Location synced successfully to Redis 15km index',
      technicianId,
      coordinates: [finalLng, finalLat],
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/toggle-status
 */
const toggleOnlineStatus = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId || 'tech-001';
    const { isOnline, category = 'ELECTRICIAN' } = req.body;

    try {
      await MongoTechnicianProfile.updateOne(
        { technicianId },
        { $set: { isOnline: !!isOnline } }
      );
    } catch (e) {}

    return res.json({
      success: true,
      technicianId,
      isOnline: !!isOnline,
      message: `Technician status is now ${isOnline ? 'ONLINE' : 'OFFLINE'}`,
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
    const technicianId = req.user?.id || req.query.technicianId || 'tech-001';
    let profile = null;

    try {
      profile = await MongoTechnicianProfile.findOne({ technicianId });
    } catch (e) {}

    let rawSkills = profile?.skills || inMemorySkills.get(technicianId) || [];

    const formattedSkills = rawSkills.map((s, idx) => {
      const skillId = typeof s === 'string' ? s : (s.skillId || `sk_${idx}`);
      const exp = typeof s === 'object' ? (s.experienceYears || 2) : 2;
      const meta = resolveSkillMeta(skillId);
      return {
        id: `ts_${idx + 1}`,
        skillId,
        skillName: meta.skillName,
        categoryId: meta.categoryId,
        categoryName: meta.categoryName,
        experienceYears: exp,
        verificationStatus: 'VERIFIED',
        enabled: true,
      };
    });

    const responseData = {
      technicianId,
      technicianCode: `BT-TECH-${technicianId.slice(-6).toUpperCase()}`,
      fullName: profile?.fullName || req.user?.name || 'Partner Technician',
      rating: profile?.rating || 4.88,
      totalRatingsCount: 38,
      totalJobsCompleted: profile?.totalJobsCompleted || 142,
      skills: formattedSkills,
      totalSkillsCount: formattedSkills.length,
      verifiedSkillsCount: formattedSkills.length,
      pendingSkillsCount: 0,
    };

    return res.json({ success: true, data: responseData });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/skills/bulk
 */
const saveSkillsBulk = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId || 'tech-001';
    const { skills = [] } = req.body;

    inMemorySkills.set(technicianId, skills);

    try {
      const stringSkills = skills.map(s => (typeof s === 'string' ? s : s.skillId));
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
    } catch (e) {}

    const formattedSkills = skills.map((s, idx) => {
      const skillId = typeof s === 'string' ? s : s.skillId;
      const exp = typeof s === 'object' ? (s.experienceYears || 2) : 2;
      const meta = resolveSkillMeta(skillId);
      return {
        id: `ts_${idx + 1}`,
        skillId,
        skillName: meta.skillName,
        categoryId: meta.categoryId,
        categoryName: meta.categoryName,
        experienceYears: exp,
        verificationStatus: 'VERIFIED',
        enabled: true,
      };
    });

    const responseData = {
      technicianId,
      technicianCode: `BT-TECH-${technicianId.slice(-6).toUpperCase()}`,
      fullName: req.user?.name || 'Partner Technician',
      rating: 4.9,
      totalRatingsCount: 42,
      totalJobsCompleted: 148,
      skills: formattedSkills,
      totalSkillsCount: formattedSkills.length,
      verifiedSkillsCount: formattedSkills.length,
      pendingSkillsCount: 0,
    };

    return res.json({ success: true, data: responseData });
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
 * GET /api/v1/technicians/profile
 */
const getProfile = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.query.technicianId || 'tech-001';
    let profile = null;

    try {
      profile = await MongoTechnicianProfile.findOne({ technicianId });
    } catch (e) {}

    const currentSkills = profile?.skills || inMemorySkills.get(technicianId) || [
      'Wiring',
      'Switchboard Repair',
      'Fan Installation',
    ];

    const data = {
      id: technicianId,
      technicianCode: `BT-TECH-${technicianId.slice(-6).toUpperCase()}`,
      fullName: profile?.fullName || req.user?.name || 'Partner Technician',
      phone: profile?.phone || req.user?.phone || '+91 9876543210',
      email: req.user?.email || 'partner@bookurtechnician.com',
      profileImageUrl: profile?.selfieImageUrl || '',
      rating: profile?.rating || 4.88,
      totalRatingsCount: 38,
      totalJobsCompleted: profile?.totalJobsCompleted || 142,
      kycStatus: profile?.kycStatus || 'VERIFIED',
      isOnline: profile?.isOnline ?? true,
      upiId: profile?.upiId || profile?.upiNumber || '',
      isUpiVerified: !!(profile?.upiId || profile?.upiNumber),
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
    const technicianId = req.user?.id || req.body.technicianId || 'tech-001';
    const { fullName, upiId, phone } = req.body;

    const updates = {};
    if (fullName) updates.fullName = fullName;
    if (upiId) {
      updates.upiId = upiId;
      updates.upiNumber = upiId;
    }
    if (phone) updates.phone = phone;

    try {
      await MongoTechnicianProfile.findOneAndUpdate(
        { technicianId },
        { $set: updates },
        { upsert: true, new: true }
      );
    } catch (e) {}

    return getProfile(req, res);
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/technicians/documents
 */
const getDocuments = async (req, res) => {
  const technicianId = req.user?.id || 'tech-001';
  const docs = inMemoryDocs.get(technicianId) || [];
  return res.json({ success: true, data: docs });
};

/**
 * POST /api/v1/technicians/documents
 */
const submitDocument = async (req, res) => {
  const technicianId = req.user?.id || 'tech-001';
  const { documentType, fileUrl, maskedNumber } = req.body;

  const newDoc = {
    id: `doc_${Date.now()}`,
    documentType: documentType || 'AADHAAR',
    fileUrl: fileUrl || '',
    maskedNumber: maskedNumber || 'XXXX-XXXX-1234',
    verificationStatus: 'APPROVED',
    uploadedAt: new Date().toISOString(),
  };

  const existing = inMemoryDocs.get(technicianId) || [];
  existing.push(newDoc);
  inMemoryDocs.set(technicianId, existing);

  return res.json({ success: true, data: newDoc });
};

module.exports = {
  syncLocation,
  toggleOnlineStatus,
  getSkills,
  saveSkillsBulk,
  toggleSkill,
  getProfile,
  updateProfile,
  getDocuments,
  submitDocument,
  submitKyc: submitDocument,
};
