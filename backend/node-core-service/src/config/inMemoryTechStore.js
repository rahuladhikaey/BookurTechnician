// ============================================================================
// BOOKURTECHNICIAN IN-MEMORY TECHNICIAN & KYC DOCUMENT STORE (PRODUCTION READY)
// Stores live authenticated technician profiles, uploaded documents, and declared skills.
// ============================================================================

const firestoreSync = require('./firestoreSync');

const inMemorySkills = new Map();
const inMemoryDocs = new Map();
const inMemoryTechProfiles = new Map();

/**
 * Hydrate Technicians from Cloud Firestore on server startup
 */
async function hydrateTechniciansFromFirestore() {
  try {
    const remoteTechs = await firestoreSync.listDocuments('technician_profiles', 300);
    if (Array.isArray(remoteTechs) && remoteTechs.length > 0) {
      remoteTechs.forEach(tech => {
        const id = tech.id || tech.technicianId;
        if (id) {
          inMemoryTechProfiles.set(id, tech);
        }
      });
      console.log(`🔥 [Firestore Hydration] Restored ${remoteTechs.length} technician profiles from Cloud Firestore`);
    }
  } catch (err) {
    console.warn('⚠️ [Firestore Tech Hydration] Notice:', err.message);
  }
}

/**
 * Register or update a real technician partner in-memory & Cloud Firestore
 */
function setTechnicianProfile(id, profileData) {
  const existing = inMemoryTechProfiles.get(id) || {};
  const merged = {
    ...existing,
    ...profileData,
    id: id || profileData.id || profileData.technicianId,
    technicianId: id || profileData.id || profileData.technicianId,
    updatedAt: new Date().toISOString(),
  };
  inMemoryTechProfiles.set(merged.id, merged);
  firestoreSync.upsertDocument('technician_profiles', merged.id, merged).catch(() => {});
  return merged;
}

/**
 * Delete a technician partner permanently
 */
function deleteTechnicianProfile(id) {
  inMemoryTechProfiles.delete(id);
  inMemoryDocs.delete(id);
  inMemorySkills.delete(id);
  firestoreSync.removeDocument('technician_profiles', id).catch(() => {});
  return true;
}

/**
 * Clear all technicians permanently
 */
function clearAllTechniciansStore() {
  inMemoryTechProfiles.clear();
  inMemoryDocs.clear();
  inMemorySkills.clear();
  return true;
}

module.exports = {
  inMemorySkills,
  inMemoryDocs,
  inMemoryTechProfiles,
  setTechnicianProfile,
  deleteTechnicianProfile,
  clearAllTechniciansStore,
  hydrateTechniciansFromFirestore,
};
