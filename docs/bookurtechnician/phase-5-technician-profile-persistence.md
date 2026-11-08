# Phase 5 — Permanent Technician Profile & Skills Persistence Architecture

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Firebase Plan:** Spark (Free)  

---

## 1. Permanent Identity Architecture

Every technician in **BookurTechnician** is assigned two permanent, deterministic identifiers upon registration and OTP verification:

1. **Permanent Internal UID (`uid`):**
   - Format: `uid_tech_<10-digit-phone>` (e.g., `uid_tech_9876988363`).
   - Used as the primary document key across `technician_profiles/{uid}`, `technician_private/{uid}`, and `technician_audit_logs`.
   - Resolved consistently via `resolveCanonicalTechUid()` in both Node.js (`backend/node-core-service/src/config/inMemoryTechStore.js`) and Flutter (`apps/technician_app/lib/core/network/firestore_rest_client.dart`).
   - Eliminates the legacy fragmentation where login created `uid_tech_<phone>`, skill onboarding saved under `tech_<phone>`, and the profile card displayed `substring(0, 6)`.

2. **Public Partner Code (`technicianCode`):**
   - Format: `BT-<last-6-digits>` (e.g., `BT-988363` for technician `Ram`).
   - Displayed in the Technician App (`My Skills & Expertise` header) and React Admin Panel (`TechniciansManager.jsx`), while never replacing `uid` as the database primary key.

---

## 2. Public vs. Private Collection Split

To protect sensitive identity and payout data while keeping customer discovery fast and Spark-compliant, technician records are partitioned into two collections:

### 2.1 Public Profile (`technician_profiles/{uid}`)
Contains only fields safe for authenticated app discovery and status tracking:
- `uid`, `technicianId`, `technicianCode` (`BT-988363`)
- `fullName`, `phoneNumber`, `email`, `profilePhotoUrl`, `city`, `serviceRadiusKm`
- `primaryCategory`, `serviceCategories`, `selectedSkills` (with `canonicalServiceId`, `skillName`, `categoryId`, `experienceYears`, `verificationStatus`, `enabled`)
- `onboardingStep` (`OTP_VERIFIED` → `PROFILE_CREATED` → `SKILLS_SAVED` → `KYC_SUBMITTED` → `ADMIN_REVIEW` → `ACTIVE`)
- `onboardingCompleted` (`boolean`), `profileCompletionPercentage` (`0..100`)
- `kycStatus`, `skillVerificationStatus`, `accountStatus`, `isAdminApproved`
- `isOnline`, `availabilityStatus`, `latitude`, `longitude`, `lastLocationUpdate`
- `rating`, `totalJobsCompleted`, `createdAt`, `updatedAt`

### 2.2 Private Vault (`technician_private/{uid}`)
Restricted strictly to the owning technician (`request.auth.uid == uid`) and verified admins (`isAdmin()`):
- `voterIdNumber` (unmasked EPIC for authorized admin verification) & `maskedVoterId` (`WBD****567`)
- `maskedAadhaar` (`XXXX-XXXX-9123`)
- `upiId` (unmasked payout VPA for settlement) & `maskedUpiId` (`ra***@okaxis`)
- `upiHolderName`, `upiVerifiedStatus`
- `secureDocumentRefs` (list of uploaded KYC metadata records with `documentType`, `fileUrl`, `maskedNumber`, `status`, `updatedAt`)
- `kycSubmittedAt`, `verifiedByAdminUid`, `verifiedAt`, `rejectionReason`

---

## 3. Partial Field-Mask Updates (`updateMask`)

Every profile mutation in both the Node.js backend (`setTechnicianProfile` / `firestoreSync.upsertDocument`) and the Technician Flutter App (`FirestoreRestClient.upsertDocument`) uses explicit field masks (`updateMask.fieldPaths` on Cloud Firestore REST PATCH):
- **Skill Updates (`POST /api/v1/technicians/skills/bulk` & `PATCH /skills/:id/toggle`):** Updates only `selectedSkills`, `skills`, `serviceCategories`, `onboardingStep`, `onboardingCompleted`, `profileCompletionPercentage`, and `updatedAt`. Personal details, KYC documents, UPI ID, and GPS coordinates remain 100% untouched (verified in `TECH-05`).
- **KYC & UPI Updates:** Writes sensitive fields to `technician_private/{uid}` and updates only `kycStatus`, `onboardingStep`, `profileCompletionPercentage`, and `updatedAt` in `technician_profiles/{uid}`.
- **Presence & Location Updates:** Updates only `isOnline`, `availabilityStatus`, `latitude`, `longitude`, and `lastLocationUpdate`.

---

## 4. Resolution of the `Ram` (`BT-988363`) "0 Online" Availability Issue

Forensic inspection of the user-provided screenshots revealed why technician **Ram (`ID: BT-988363`)** had `AC installation` verified and toggled on in the Technician App while the Customer App displayed `Unavailable (0 Online)`:
1. **Skill ID Mismatch:** The Technician App stored `sk_ac_installation` while the Customer App searched for `ac_install`. Both apps and the backend now normalize `sk_ac_installation` → `ac_install` (`canonicalServiceId`).
2. **Field Name Mismatch:** Customer App `_doesTechnicianMatchService` previously inspected only `tech['skills']`, ignoring `tech['selectedSkills']`. It now inspects both `selectedSkills` and `skills` plus canonical aliases (`_canonicalSkillAliases`).
3. **Presence Heartbeat & Coordinates on Login:** Technician App `verify-otp` fallback now initializes `lastLocationUpdate`, `latitude`, `longitude`, `isOnline: true`, and `availabilityStatus: 'AVAILABLE'`.

