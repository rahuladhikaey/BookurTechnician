const { resolveCanonicalServiceId } = require('./canonicalServices');

/**
 * Server-Authoritative Technician Skill Management Service
 * BookurTechnician (Pure Firebase Architecture)
 */

async function fetchTechnicianSkills(db, { callerUid, targetTechId, isAdmin } = {}) {
  const effectiveTechId = targetTechId || callerUid;
  if (!effectiveTechId) {
    const err = new Error('Authenticated technician UID or target technician ID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const techDoc = await db.collection('technician_profiles').doc(effectiveTechId).get();
  if (!techDoc.exists) {
    return {
      success: true,
      technicianId: effectiveTechId,
      skills: [],
      selectedSkills: [],
      categories: [],
      totalSkillsCount: 0,
      verifiedSkillsCount: 0,
    };
  }

  const data = techDoc.data();
  const rawSkills = Array.isArray(data.selectedSkills) && data.selectedSkills.length > 0
    ? data.selectedSkills
    : (Array.isArray(data.skills) ? data.skills : []);

  return {
    success: true,
    technicianId: effectiveTechId,
    fullName: data.fullName || data.name || 'Partner Technician',
    category: data.category || '',
    categories: data.categories || data.serviceCategories || [],
    skills: rawSkills,
    selectedSkills: rawSkills,
    totalSkillsCount: rawSkills.length,
    verifiedSkillsCount: rawSkills.filter((s) => (s.verificationStatus || '').toUpperCase() === 'VERIFIED').length,
    pendingSkillsCount: rawSkills.filter((s) => (s.verificationStatus || '').toUpperCase() === 'PENDING').length,
  };
}

async function saveTechnicianSkills(db, { callerUid, targetTechId, skills, isAdmin }) {
  if (!callerUid) {
    const err = new Error('Unauthorized: Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const effectiveTechId = targetTechId || callerUid;
  if (targetTechId && targetTechId !== callerUid && !isAdmin) {
    const err = new Error('Forbidden: Cannot modify another technician\'s skills');
    err.status = 403;
    err.code = 'FORBIDDEN';
    throw err;
  }

  if (!Array.isArray(skills) || skills.length === 0) {
    const err = new Error('At least one skill must be selected');
    err.status = 400;
    err.code = 'INVALID_SKILLS_PAYLOAD';
    throw err;
  }

  const nowIso = new Date().toISOString();
  const techRef = db.collection('technician_profiles').doc(effectiveTechId);
  const techSnap = await techRef.get();
  const existing = techSnap.exists ? techSnap.data() : {};

  // Build map of existing skills to preserve prior admin verification status
  const existingSkillMap = new Map();
  const priorSkills = Array.isArray(existing.skills) ? existing.skills : [];
  for (const s of priorSkills) {
    if (s && (s.id || s.skillId || s.canonicalServiceId)) {
      const key = s.canonicalServiceId || s.skillId || s.id;
      existingSkillMap.set(key, s);
    }
  }

  const enrichedSkills = [];
  const declaredCategories = new Set();
  const declaredCategoryIds = new Set();
  const seenCanonicalKeys = new Set();

  for (const s of skills) {
    const rawId = s.canonicalServiceId || s.skillId || s.id;
    const rawName = s.name || s.skillName || '';
    if (!rawId && !rawName) continue;

    const canonicalId = resolveCanonicalServiceId(rawId, rawName);
    if (!canonicalId || seenCanonicalKeys.has(canonicalId)) continue;
    seenCanonicalKeys.add(canonicalId);

    const prev = existingSkillMap.get(canonicalId);
    // If previously verified by admin, keep VERIFIED. Otherwise new declarations default to VERIFIED for standard services
    const verificationStatus = prev && prev.verificationStatus ? prev.verificationStatus : (s.verificationStatus || 'VERIFIED');

    const sName = rawName || canonicalId
      .replace(/^sk_/, '')
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());

    let cId = s.categoryId || (prev && prev.categoryId) || '';
    let cName = s.categoryName || (prev && prev.categoryName) || '';

    if (!cId) {
      if (canonicalId.startsWith('ac_')) {
        cId = 'cat_ac';
        cName = 'AC Services';
      } else if (canonicalId.startsWith('fan_') || canonicalId.startsWith('light_') || canonicalId.startsWith('mcb_') || canonicalId.startsWith('switch_') || canonicalId.startsWith('elec_') || canonicalId.startsWith('led_')) {
        cId = 'cat_electrical';
        cName = 'Electrical Services';
      } else if (canonicalId.startsWith('wm_') || canonicalId.startsWith('fridge_') || canonicalId.startsWith('ro_') || canonicalId.startsWith('geyser_')) {
        cId = 'cat_appliances';
        cName = 'Appliances Repair';
      } else {
        cId = 'cat_general';
        cName = 'Home Services';
      }
    }

    declaredCategories.add(cName);
    declaredCategoryIds.add(cId);

    enrichedSkills.push({
      id: canonicalId,
      skillId: canonicalId,
      canonicalServiceId: canonicalId,
      name: sName,
      skillName: sName,
      categoryId: cId,
      categoryName: cName,
      experienceYears: Number(s.experienceYears) || (prev && prev.experienceYears) || 2,
      verificationStatus: String(verificationStatus).toUpperCase(),
      enabled: s.enabled !== false,
    });
  }

  const primaryCategory = declaredCategories.size > 0
    ? Array.from(declaredCategories)[0]
    : (existing.category || 'Electrical Services');

  const updateData = {
    ...existing,
    id: effectiveTechId,
    uid: effectiveTechId,
    technicianId: effectiveTechId,
    skills: enrichedSkills,
    selectedSkills: enrichedSkills,
    categories: Array.from(declaredCategories),
    serviceCategories: Array.from(declaredCategoryIds),
    category: primaryCategory,
    totalSkillsCount: enrichedSkills.length,
    verifiedSkillsCount: enrichedSkills.filter((s) => s.verificationStatus === 'VERIFIED').length,
    pendingSkillsCount: enrichedSkills.filter((s) => s.verificationStatus === 'PENDING').length,
    updatedAt: nowIso,
  };

  // Strictly preserve non-modifiable fields: GPS, walletBalance, ratings, KYC
  if (existing.createdAt) updateData.createdAt = existing.createdAt;
  if (existing.latitude !== undefined) updateData.latitude = existing.latitude;
  if (existing.longitude !== undefined) updateData.longitude = existing.longitude;
  if (existing.lastLocationUpdate) updateData.lastLocationUpdate = existing.lastLocationUpdate;
  if (existing.rating !== undefined) updateData.rating = existing.rating;
  if (existing.walletBalance !== undefined) updateData.walletBalance = existing.walletBalance;
  if (existing.kycStatus) updateData.kycStatus = existing.kycStatus;
  if (existing.accountStatus) updateData.accountStatus = existing.accountStatus;
  if (existing.isOnline !== undefined) updateData.isOnline = existing.isOnline;
  if (existing.availabilityStatus) updateData.availabilityStatus = existing.availabilityStatus;

  await techRef.set(updateData);

  // Record audit log
  await db.collection('technician_audit_logs').doc().set({
    technicianId: effectiveTechId,
    modifiedByUid: callerUid,
    action: 'SKILLS_SAVED',
    skillsCount: enrichedSkills.length,
    timestamp: nowIso,
    createdAt: nowIso,
  });

  return {
    success: true,
    message: 'Skills saved successfully',
    technicianId: effectiveTechId,
    skills: enrichedSkills,
    selectedSkills: enrichedSkills,
    categories: Array.from(declaredCategories),
    totalSkillsCount: enrichedSkills.length,
    verifiedSkillsCount: updateData.verifiedSkillsCount,
    profile: updateData,
  };
}

async function toggleTechnicianSkill(db, { callerUid, targetTechId, skillId, enabled, isAdmin }) {
  if (!callerUid) {
    const err = new Error('Unauthorized: Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }
  const effectiveTechId = targetTechId || callerUid;
  if (targetTechId && targetTechId !== callerUid && !isAdmin) {
    const err = new Error('Forbidden: Cannot modify another technician\'s skills');
    err.status = 403;
    err.code = 'FORBIDDEN';
    throw err;
  }
  if (!skillId) {
    const err = new Error('Skill ID required');
    err.status = 400;
    err.code = 'MISSING_SKILL_ID';
    throw err;
  }

  const techRef = db.collection('technician_profiles').doc(effectiveTechId);
  const techSnap = await techRef.get();
  if (!techSnap.exists) {
    const err = new Error('Technician profile not found');
    err.status = 404;
    err.code = 'TECHNICIAN_NOT_FOUND';
    throw err;
  }

  const data = techSnap.data();
  const skills = Array.isArray(data.skills) ? [...data.skills] : [];
  const canonicalId = resolveCanonicalServiceId(skillId, skillId);
  let matched = false;

  for (const s of skills) {
    if (s.id === skillId || s.skillId === skillId || s.canonicalServiceId === skillId ||
        s.id === canonicalId || s.skillId === canonicalId || s.canonicalServiceId === canonicalId) {
      s.enabled = enabled !== undefined ? Boolean(enabled) : !s.enabled;
      matched = true;
      break;
    }
  }

  if (!matched) {
    const err = new Error(`Skill ${skillId} not found in technician profile`);
    err.status = 404;
    err.code = 'SKILL_NOT_FOUND';
    throw err;
  }

  const nowIso = new Date().toISOString();
  await techRef.update({
    skills,
    selectedSkills: skills,
    updatedAt: nowIso,
  });

  return {
    success: true,
    message: 'Skill toggled successfully',
    skillId,
    skills,
  };
}

module.exports = {
  fetchTechnicianSkills,
  saveTechnicianSkills,
  toggleTechnicianSkill,
};
