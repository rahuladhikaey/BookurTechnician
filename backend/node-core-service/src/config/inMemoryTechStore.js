// ============================================================================
// BOOKURTECHNICIAN PERMANENT TECHNICIAN PROFILE & PRIVATE KYC VAULT STORE
// Phase 5 Architecture:
// - Public/General Profile: technician_profiles/{uid}
// - Private KYC & Payout Vault: technician_private/{uid}
// - Permanent Identity: uid (document key), technicianCode (BT-XXXXXX), phoneNumber
// ============================================================================

const fs = require('fs');
const path = require('path');
const firestoreSync = require('./firestoreSync');

const DATA_DIR = path.join(__dirname, '../../data');
const PROFILES_FILE = path.join(DATA_DIR, 'technician_profiles.json');
const PRIVATE_FILE = path.join(DATA_DIR, 'technician_private.json');
const AUDIT_FILE = path.join(DATA_DIR, 'technician_audit_log.json');

const inMemorySkills = new Map();
const inMemoryDocs = new Map();
const inMemoryTechProfiles = new Map();
const inMemoryTechPrivate = new Map();
let technicianAuditLogs = [];

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function maskVoterId(raw) {
  if (!raw || typeof raw !== 'string') return '';
  const clean = raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (clean.length < 6) return clean;
  return `${clean.slice(0, 3)}****${clean.slice(-3)}`;
}

function maskAadhaar(raw) {
  if (!raw || typeof raw !== 'string') return '';
  const digits = raw.replace(/\D/g, '');
  if (digits.length < 4) return '';
  return `XXXX-XXXX-${digits.slice(-4)}`;
}

function maskUpiId(raw) {
  if (!raw || typeof raw !== 'string' || !raw.includes('@')) return '';
  const [handle, bank] = raw.trim().split('@');
  if (!handle || !bank) return '';
  const visible = handle.length <= 2 ? handle[0] : handle.slice(0, 2);
  return `${visible}***@${bank}`;
}

function resolveCanonicalTechUid(rawId, fallbackPhone = '') {
  const candidate = String(rawId || fallbackPhone || '').trim();
  if (!candidate) return 'uid_tech_partner';

  // If already canonical uid_tech_<digits>, keep as-is
  if (candidate.startsWith('uid_tech_')) {
    return candidate;
  }

  // Extract digits from phone or tech_<digits>
  const digits = candidate.replace(/\D/g, '');
  if (digits.length >= 10) {
    const last10 = digits.slice(-10);
    return `uid_tech_${last10}`;
  }

  // Check if an existing profile has this technicianCode or id
  for (const [k, prof] of inMemoryTechProfiles.entries()) {
    if (prof.technicianCode === candidate || prof.id === candidate || prof.phone === candidate || prof.phoneNumber === candidate) {
      return k;
    }
  }

  if (candidate.startsWith('tech_')) {
    return `uid_${candidate}`;
  }
  return candidate;
}

function resolveTechnicianCode(uid, phone = '', existingCode = '') {
  if (existingCode && /^BT-\d{6}$/.test(String(existingCode).trim())) {
    return String(existingCode).trim();
  }
  const digits = String(phone || uid || '').replace(/\D/g, '');
  if (digits.length >= 6) {
    return `BT-${digits.slice(-6)}`;
  }
  let hash = 0;
  const str = String(uid || 'partner');
  for (let i = 0; i < str.length; i++) {
    hash = (hash * 31 + str.charCodeAt(i)) % 900000;
  }
  return `BT-${String(100000 + Math.abs(hash)).slice(0, 6)}`;
}

function computeProfileCompletion(publicProf = {}, privateVault = {}) {
  let score = 0;
  if (publicProf.phoneNumber || publicProf.phone) score += 20;
  if (publicProf.fullName && publicProf.fullName !== 'Partner Technician') score += 20;
  const skills = publicProf.selectedSkills || publicProf.skills || [];
  if (Array.isArray(skills) && skills.length > 0) score += 25;
  if (
    privateVault.maskedVoterId ||
    privateVault.maskedAadhaar ||
    (Array.isArray(privateVault.secureDocumentRefs) && privateVault.secureDocumentRefs.length > 0) ||
    publicProf.kycSubmittedAt
  ) {
    score += 20;
  }
  if (privateVault.upiId || privateVault.maskedUpiId || publicProf.maskedUpiId) {
    score += 15;
  }
  return Math.min(100, score);
}

function determineOnboardingStep(publicProf = {}, privateVault = {}) {
  const acct = String(publicProf.accountStatus || '').toUpperCase();
  const kyc = String(publicProf.kycStatus || privateVault.voterIdVerificationStatus || '').toUpperCase();
  if (acct === 'ACTIVE' && kyc === 'VERIFIED') return 'ACTIVE';
  if (kyc === 'VERIFIED') return 'ADMIN_VERIFIED';
  if (privateVault.upiId || privateVault.maskedUpiId || publicProf.maskedUpiId) return 'UPI_SAVED';
  if (
    privateVault.kycSubmittedAt ||
    privateVault.maskedVoterId ||
    privateVault.maskedAadhaar ||
    (Array.isArray(privateVault.secureDocumentRefs) && privateVault.secureDocumentRefs.length > 0)
  ) {
    return 'KYC_SUBMITTED';
  }
  if (publicProf.fullName && publicProf.fullName !== 'Partner Technician' && publicProf.addressSummary) {
    return 'PERSONAL_DETAILS_SAVED';
  }
  const skills = publicProf.selectedSkills || publicProf.skills || [];
  if (Array.isArray(skills) && skills.length > 0) {
    return 'SKILLS_SAVED';
  }
  return 'PROFILE_CREATED';
}

function saveLocalDiskStores() {
  try {
    ensureDataDir();
    const pubObj = {};
    for (const [k, v] of inMemoryTechProfiles.entries()) {
      pubObj[k] = v;
    }
    fs.writeFileSync(PROFILES_FILE, JSON.stringify(pubObj, null, 2), 'utf8');

    const privObj = {};
    for (const [k, v] of inMemoryTechPrivate.entries()) {
      privObj[k] = v;
    }
    fs.writeFileSync(PRIVATE_FILE, JSON.stringify(privObj, null, 2), 'utf8');
  } catch (err) {
    console.warn('[TechStore] Failed to write local disk stores:', err.message);
  }
}

function loadLocalDiskStores() {
  try {
    ensureDataDir();
    if (fs.existsSync(AUDIT_FILE)) {
      const parsedAudit = JSON.parse(fs.readFileSync(AUDIT_FILE, 'utf8'));
      if (Array.isArray(parsedAudit)) technicianAuditLogs = parsedAudit;
    }
    if (fs.existsSync(PRIVATE_FILE)) {
      const parsedPriv = JSON.parse(fs.readFileSync(PRIVATE_FILE, 'utf8'));
      for (const [k, v] of Object.entries(parsedPriv || {})) {
        inMemoryTechPrivate.set(k, v);
      }
    }
    if (fs.existsSync(PROFILES_FILE)) {
      const parsedPub = JSON.parse(fs.readFileSync(PROFILES_FILE, 'utf8'));
      for (const [k, v] of Object.entries(parsedPub || {})) {
        inMemoryTechProfiles.set(k, v);
        if (Array.isArray(v.selectedSkills || v.skills)) {
          inMemorySkills.set(k, v.selectedSkills || v.skills);
        }
      }
    }
  } catch (err) {
    console.warn('[TechStore] Load disk store notice:', err.message);
  }
}

loadLocalDiskStores();

function recordTechnicianAuditLog({
  adminUid = 'admin_system',
  action,
  targetTechnicianUid,
  previousStatus = null,
  updatedStatus = null,
  notes = '',
}) {
  try {
    ensureDataDir();
    const entry = {
      id: `aud_tech_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      adminUid,
      action,
      targetTechnicianUid,
      previousStatus,
      updatedStatus,
      notes,
      timestamp: new Date().toISOString(),
    };
    technicianAuditLogs.unshift(entry);
    if (technicianAuditLogs.length > 500) {
      technicianAuditLogs = technicianAuditLogs.slice(0, 500);
    }
    fs.writeFileSync(AUDIT_FILE, JSON.stringify(technicianAuditLogs, null, 2), 'utf8');
    firestoreSync.upsertDocument('admin_audit_logs', entry.id, entry).catch(() => { });
    return entry;
  } catch (err) {
    return null;
  }
}

function getTechnicianAuditLogs(targetTechnicianUid = null) {
  if (!targetTechnicianUid) return technicianAuditLogs;
  return technicianAuditLogs.filter(e => e.targetTechnicianUid === targetTechnicianUid);
}

/**
 * Hydrate Technicians from Cloud Firestore on server startup
 */
async function hydrateTechniciansFromFirestore() {
  try {
    const remoteTechs = await firestoreSync.listDocuments('technician_profiles', 300);
    if (Array.isArray(remoteTechs) && remoteTechs.length > 0) {
      remoteTechs.forEach(tech => {
        const rawId = tech.uid || tech.id || tech.technicianId;
        const uid = resolveCanonicalTechUid(rawId, tech.phoneNumber || tech.phone);
        if (uid) {
          const existing = inMemoryTechProfiles.get(uid) || {};
          const merged = {
            ...existing,
            ...tech,
            uid,
            id: uid,
            technicianId: uid,
            technicianCode: resolveTechnicianCode(uid, tech.phoneNumber || tech.phone, tech.technicianCode || existing.technicianCode),
          };
          inMemoryTechProfiles.set(uid, merged);
          if (Array.isArray(merged.selectedSkills || merged.skills) && (merged.selectedSkills || merged.skills).length > 0) {
            inMemorySkills.set(uid, merged.selectedSkills || merged.skills);
          }
        }
      });
      saveLocalDiskStores();
      console.log(`🔥 [Firestore Hydration] Restored ${remoteTechs.length} technician profiles from Cloud Firestore`);
    }

    const remotePrivate = await firestoreSync.listDocuments('technician_private', 300);
    if (Array.isArray(remotePrivate) && remotePrivate.length > 0) {
      remotePrivate.forEach(priv => {
        const rawId = priv.uid || priv.id || priv.technicianId;
        const uid = resolveCanonicalTechUid(rawId);
        if (uid) {
          inMemoryTechPrivate.set(uid, { ...priv, uid, id: uid });
        }
      });
      saveLocalDiskStores();
    }
  } catch (err) {
    console.warn('⚠️ [Firestore Tech Hydration] Notice:', err.message);
  }
}

/**
 * Update or create private KYC & Payout vault record (technician_private/{uid})
 */
function setTechnicianPrivateProfile(rawId, privateData = {}, updateMask = null) {
  const uid = resolveCanonicalTechUid(rawId, privateData.phoneNumber || privateData.phone);
  const existing = inMemoryTechPrivate.get(uid) || {
    uid,
    id: uid,
    voterIdVerificationStatus: 'NOT_SUBMITTED',
    maskedVoterId: '',
    aadhaarVerificationStatus: 'NOT_SUBMITTED',
    maskedAadhaar: '',
    secureDocumentRefs: [],
    upiVerificationStatus: 'NOT_SUBMITTED',
    upiId: '',
    maskedUpiId: '',
    kycSubmittedAt: null,
    verifiedAt: null,
    verifiedByAdminUid: null,
  };

  const nowIso = new Date().toISOString();
  const nextVoterId = privateData.voterIdNumber !== undefined ? privateData.voterIdNumber : existing.voterIdNumber;
  const nextMaskedVoter = privateData.maskedVoterId || (nextVoterId ? maskVoterId(nextVoterId) : existing.maskedVoterId);
  const nextAadhaar = privateData.aadhaarNumber !== undefined ? privateData.aadhaarNumber : existing.aadhaarNumber;
  const nextMaskedAadhaar = privateData.maskedAadhaar || (nextAadhaar ? maskAadhaar(nextAadhaar) : existing.maskedAadhaar);
  const nextUpi = privateData.upiId !== undefined ? privateData.upiId : existing.upiId;
  const nextMaskedUpi = privateData.maskedUpiId || (nextUpi ? maskUpiId(nextUpi) : existing.maskedUpiId);

  const merged = {
    ...existing,
    ...privateData,
    uid,
    id: uid,
    maskedVoterId: nextMaskedVoter || '',
    maskedAadhaar: nextMaskedAadhaar || '',
    upiId: nextUpi || '',
    maskedUpiId: nextMaskedUpi || '',
    updatedAt: nowIso,
  };

  inMemoryTechPrivate.set(uid, merged);
  saveLocalDiskStores();
  firestoreSync.upsertDocument('technician_private', uid, merged, updateMask).catch(() => { });
  return merged;
}

function getTechnicianPrivateProfile(rawId) {
  const uid = resolveCanonicalTechUid(rawId);
  return inMemoryTechPrivate.get(uid) || null;
}

/**
 * Register or update a technician partner in-memory & Cloud Firestore (technician_profiles/{uid}).
 * Strips sensitive raw KYC numbers and raw UPI ID from the public collection automatically.
 */
function setTechnicianProfile(rawId, profileData = {}, updateMask = null) {
  const uid = resolveCanonicalTechUid(rawId, profileData.phoneNumber || profileData.phone);
  const existing = inMemoryTechProfiles.get(uid) || {};
  const existingPriv = inMemoryTechPrivate.get(uid) || {};
  const nowIso = new Date().toISOString();

  // If sensitive KYC or UPI fields were passed into setTechnicianProfile, route them to technician_private/{uid}
  if (
    profileData.voterIdNumber ||
    profileData.aadhaarNumber ||
    profileData.upiId ||
    profileData.secureDocumentRefs ||
    profileData.voterIdVerificationStatus ||
    profileData.upiVerificationStatus
  ) {
    setTechnicianPrivateProfile(uid, {
      ...(profileData.voterIdNumber ? { voterIdNumber: profileData.voterIdNumber, maskedVoterId: maskVoterId(profileData.voterIdNumber) } : {}),
      ...(profileData.aadhaarNumber ? { aadhaarNumber: profileData.aadhaarNumber, maskedAadhaar: maskAadhaar(profileData.aadhaarNumber) } : {}),
      ...(profileData.upiId ? { upiId: profileData.upiId, maskedUpiId: maskUpiId(profileData.upiId) } : {}),
      ...(profileData.secureDocumentRefs ? { secureDocumentRefs: profileData.secureDocumentRefs } : {}),
      ...(profileData.voterIdVerificationStatus ? { voterIdVerificationStatus: profileData.voterIdVerificationStatus } : {}),
      ...(profileData.upiVerificationStatus ? { upiVerificationStatus: profileData.upiVerificationStatus } : {}),
      ...(profileData.kycSubmittedAt ? { kycSubmittedAt: profileData.kycSubmittedAt } : {}),
      ...(profileData.verifiedAt ? { verifiedAt: profileData.verifiedAt } : {}),
      ...(profileData.verifiedByAdminUid ? { verifiedByAdminUid: profileData.verifiedByAdminUid } : {}),
    });
  }

  const latestPriv = inMemoryTechPrivate.get(uid) || existingPriv;
  const phone = profileData.phoneNumber || profileData.phone || existing.phoneNumber || existing.phone || '';
  const technicianCode = resolveTechnicianCode(uid, phone, profileData.technicianCode || existing.technicianCode);

  const selectedSkills = profileData.selectedSkills || profileData.skills || existing.selectedSkills || existing.skills || [];
  if (Array.isArray(selectedSkills) && selectedSkills.length > 0) {
    inMemorySkills.set(uid, selectedSkills);
  }

  // Strip raw unmasked secrets from the public profile object
  const sanitizedInput = { ...profileData };
  delete sanitizedInput.voterIdNumber;
  delete sanitizedInput.aadhaarNumber;
  delete sanitizedInput.upiId;
  delete sanitizedInput.secureDocumentRefs;

  const merged = {
    ...existing,
    ...sanitizedInput,
    uid,
    id: uid,
    technicianId: uid,
    technicianCode,
    fullName: sanitizedInput.fullName || sanitizedInput.name || existing.fullName || existing.name || 'Partner Technician',
    name: sanitizedInput.fullName || sanitizedInput.name || existing.fullName || existing.name || 'Partner Technician',
    phoneNumber: phone,
    phone,
    email: sanitizedInput.email ?? existing.email ?? '',
    profilePhotoUrl: sanitizedInput.profilePhotoUrl ?? existing.profilePhotoUrl ?? '',
    experienceYears: Number(sanitizedInput.experienceYears ?? existing.experienceYears ?? 2),
    selectedSkills,
    skills: selectedSkills,
    skillVerificationStatus: sanitizedInput.skillVerificationStatus || existing.skillVerificationStatus || 'VERIFIED',
    serviceCategories: sanitizedInput.serviceCategories || sanitizedInput.categories || existing.serviceCategories || existing.categories || [],
    serviceArea: sanitizedInput.serviceArea || existing.serviceArea || '15 km radius',
    addressSummary: sanitizedInput.addressSummary || sanitizedInput.address || existing.addressSummary || existing.address || '',
    accountStatus: sanitizedInput.accountStatus || existing.accountStatus || 'ACTIVE',
    kycStatus: sanitizedInput.kycStatus || existing.kycStatus || 'VERIFIED',
    voterIdVerificationStatus: latestPriv.voterIdVerificationStatus || existing.voterIdVerificationStatus || 'NOT_SUBMITTED',
    maskedVoterId: latestPriv.maskedVoterId || existing.maskedVoterId || '',
    upiVerificationStatus: latestPriv.upiVerificationStatus || existing.upiVerificationStatus || 'NOT_SUBMITTED',
    maskedUpiId: latestPriv.maskedUpiId || existing.maskedUpiId || '',
    createdAt: existing.createdAt || sanitizedInput.createdAt || nowIso,
    updatedAt: nowIso,
  };

  merged.profileCompletionPercentage = computeProfileCompletion(merged, latestPriv);
  merged.onboardingStep = sanitizedInput.onboardingStep || determineOnboardingStep(merged, latestPriv);
  merged.onboardingCompleted =
    sanitizedInput.onboardingCompleted !== undefined
      ? Boolean(sanitizedInput.onboardingCompleted)
      : (merged.onboardingStep === 'ACTIVE' ||
        merged.onboardingStep === 'ADMIN_VERIFIED' ||
        merged.onboardingStep === 'UPI_SAVED' ||
        merged.onboardingStep === 'KYC_SUBMITTED' ||
        (Array.isArray(selectedSkills) && selectedSkills.length > 0));

  inMemoryTechProfiles.set(uid, merged);
  saveLocalDiskStores();
  firestoreSync.upsertDocument('technician_profiles', uid, merged, updateMask).catch(() => { });
  return merged;
}

/**
 * Delete a technician partner permanently
 */
function deleteTechnicianProfile(rawId) {
  const uid = resolveCanonicalTechUid(rawId);
  inMemoryTechProfiles.delete(uid);
  inMemoryTechProfiles.delete(rawId);
  inMemoryTechPrivate.delete(uid);
  inMemoryDocs.delete(uid);
  inMemorySkills.delete(uid);
  saveLocalDiskStores();
  firestoreSync.removeDocument('technician_profiles', uid).catch(() => { });
  firestoreSync.removeDocument('technician_private', uid).catch(() => { });
  return true;
}

/**
 * Clear all technicians permanently
 */
function clearAllTechniciansStore() {
  inMemoryTechProfiles.clear();
  inMemoryTechPrivate.clear();
  inMemoryDocs.clear();
  inMemorySkills.clear();
  saveLocalDiskStores();
  firestoreSync.clearCollection('technician_profiles').catch(() => { });
  firestoreSync.clearCollection('technician_private').catch(() => { });
  return true;
}

module.exports = {
  inMemorySkills,
  inMemoryDocs,
  inMemoryTechProfiles,
  inMemoryTechPrivate,
  maskVoterId,
  maskAadhaar,
  maskUpiId,
  resolveCanonicalTechUid,
  resolveTechnicianCode,
  computeProfileCompletion,
  determineOnboardingStep,
  setTechnicianProfile,
  setTechnicianPrivateProfile,
  getTechnicianPrivateProfile,
  recordTechnicianAuditLog,
  getTechnicianAuditLogs,
  deleteTechnicianProfile,
  clearAllTechniciansStore,
  hydrateTechniciansFromFirestore,
};
