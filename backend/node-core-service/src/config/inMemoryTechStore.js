// ============================================================================
// BOOKURTECHNICIAN IN-MEMORY TECHNICIAN & KYC DOCUMENT STORE (PRODUCTION READY)
// Stores live authenticated technician profiles, uploaded documents, and declared skills.
// ============================================================================

const inMemorySkills = new Map();
const inMemoryDocs = new Map();
const inMemoryTechProfiles = new Map();

/**
 * Register or update a real technician partner in-memory
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
  return merged;
}

/**
 * Delete a technician partner permanently
 */
function deleteTechnicianProfile(id) {
  inMemoryTechProfiles.delete(id);
  inMemoryDocs.delete(id);
  inMemorySkills.delete(id);
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
};
