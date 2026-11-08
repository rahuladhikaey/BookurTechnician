# Phase 5 — KYC, Voter ID & UPI Security Audit

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Firebase Plan:** Spark (Free)  

---

## 1. KYC & Payout Data Isolation (`technician_private/{uid}`)

All sensitive technician identity and payout fields have been isolated from the public `technician_profiles/{uid}` collection and moved to the protected `technician_private/{uid}` vault:

| Field | Stored in `technician_profiles/{uid}`? | Stored in `technician_private/{uid}`? | General Admin Table View | Authorized 360° KYC Review |
|---|---|---|---|---|
| **Voter ID (EPIC)** | No | Yes (`voterIdNumber`, `maskedVoterId`) | Masked (`WBD****567`) | Full + Masked |
| **Aadhaar Number** | No | Yes (`maskedAadhaar`) | Masked (`XXXX-XXXX-9123`) | Masked (`XXXX-XXXX-9123`) |
| **UPI ID (VPA)** | No | Yes (`upiId`, `maskedUpiId`) | Masked (`ra***@okaxis`) | Full + Masked |
| **KYC Document URLs** | No | Yes (`secureDocumentRefs`) | Count badge only | Protected Document Preview |

---

## 2. Format Validation & Optional Voter ID Support

1. **Optional Voter ID (EPIC) Validation:**
   - Voter ID is **optional** during technician onboarding (`document_upload_onboarding_page.dart`) so technicians without a Voter ID card can complete onboarding using Live Selfie + Aadhaar + UPI ID.
   - When provided, Voter ID is normalized to uppercase and validated against the Indian EPIC format (`^[A-Z]{3}[0-9]{7}$`, e.g., `WBD1234567`). Invalid formats are rejected with `HTTP 400 INVALID_VOTER_ID` (verified in `NET-02`).
   - Masked automatically via `maskVoterId('WBD1234567')` → `WBD****567`.

2. **UPI ID (VPA) Validation & Masking:**
   - Validated against standard NPCI VPA format (`^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$`, e.g., `ram988363@okaxis`). Invalid formats are rejected with `HTTP 400 INVALID_UPI_FORMAT` (verified in `NET-02`).
   - Masked automatically via `maskUpiId('ram988363@okaxis')` → `ra***@okaxis`.

3. **Duplicate Submission Lock & Idempotent Document Upsert:**
   - Rapid duplicate submissions within a 3-second window are intercepted (`recentKycSubmissionLocks`), and repeated uploads of the same `documentType` (`SELFIE`, `AADHAAR`, `VOTER_CARD`) upsert in place rather than appending duplicate records (verified in `NET-01`).

---

## 3. Self-Approval Prevention & Security Rules Hardening

1. **Backend RBAC Guards (`SELF_APPROVAL_FORBIDDEN`):**
   - `technicianController.verifySkillAdmin` and `adminController.updateTechnicianKyc` explicitly check `req.user.role` and `req.user.id === targetTechUid` and return `HTTP 403 SELF_APPROVAL_FORBIDDEN` if a technician attempts to approve their own skills or KYC (verified in `TECH-08`).

2. **Firestore Security Rules (`firestore.rules`):**
   - `technician_profiles/{techId}` blocks non-admin updates to `kycStatus == 'VERIFIED'`, `skillVerificationStatus == 'VERIFIED'`, `accountStatus == 'ACTIVE'`, `isAdminApproved`, and `verifiedByAdminUid`.
   - `technician_private/{techId}` allows read only by `isOwner(techId) || isAdmin()`, and blocks owners from modifying `kycVerifiedStatus`, `upiVerifiedStatus`, `verifiedByAdminUid`, or `verifiedAt`.

3. **Firebase Storage Rules (`storage.rules`):**
   - Restricts `/technicians/{techId}/kyc/{allPaths=**}` and `/kyc_documents/{userId}/{allPaths=**}` to authenticated owners (image/PDF <= 5 MB) and admins. Public access is strictly denied.

