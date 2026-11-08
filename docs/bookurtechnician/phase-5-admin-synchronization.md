# Phase 5 — Admin Panel Synchronization & RBAC Governance

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Firebase Plan:** Spark (Free)  

---

## 1. Service Catalog Manager (`ServicesManager.jsx`)

The React Admin Panel's **Service Catalog Manager** (`apps/admin_panel/src/features/services/ServicesManager.jsx`) is connected directly to the central catalog (`GET/POST/PUT/PATCH/DELETE /api/v1/admin/services` and `/api/v1/catalog/services`):

- **Full 158-Service Inventory:** Displays all 158 canonical services across 8 categories and 21 subcategories.
- **Multi-Dimensional Filtering:**
  - Category filter (`All Categories` or any of the 8 categories).
  - Dynamic Subcategory filter (`All Subcategories` or subcategories scoped to the selected category).
  - Status filter (`All Status`, `Active Only`, `Disabled Only`).
  - Instant search across service name, `canonicalServiceId`, category, subcategory, and description.
- **Spark-Safe Pagination:** Paginates table views (`25 services per page`) with page navigation controls to prevent excessive DOM rendering and read bandwidth.
- **1-Click Enable / Disable Toggle (`handleToggleServiceStatus`):**
  - Allows admins to immediately enable or disable any service.
  - Increments `catalogVersion` and syncs the updated `isActive` flag to Cloud Firestore (`services/{serviceId}` and `service_categories/{categoryId}`).
  - Disabled services are automatically hidden from active Customer App browsing and blocked at booking creation with `HTTP 400 SERVICE_DISABLED` (verified in `CAT-05`).
- **Display Order & Booking Count:** Shows each service's `displayOrder` and cumulative `bookingCount` directly in the management table.

---

## 2. Technician Fleet & KYC Governance (`TechniciansManager.jsx`)

The React Admin Panel's **Technician Fleet Manager** (`apps/admin_panel/src/features/technicians/TechniciansManager.jsx`) is synchronized with `technician_profiles/{uid}`, `technician_private/{uid}`, and `technician_audit_logs`:

- **Privacy-Safe General List:**
  - Displays `technicianCode` (`BT-988363`), `uid`, `onboardingStep` badge (`SKILLS_SAVED`, `KYC_SUBMITTED`, `ACTIVE`), `maskedUpiId` (`ra***@okaxis`), and `maskedVoterId` (`WBD****567`) in the general table.
  - Unmasked UPI IDs and raw KYC document URLs are never exposed in general table rows (verified in `ADM-01`).
- **360° Partner Profile Modal:**
  - **Overview & Skills Tab:** Shows declared skills with their `canonicalServiceId` (`ac_install`, etc.), experience years, active/disabled toggle state, and individual skill Approve/Reject controls (`ADM-02`, `ADM-04`).
  - **KYC Documents Tab:** Protected review view for authorized admins to inspect Live Selfie, Aadhaar, and optional Voter ID documents and approve/reject KYC (`ADM-03`).
  - **Audit History Tab (`detailTab === 'audit'`):** Displays the chronological, immutable audit trail (`GET /api/v1/admin/audit-logs`) filtered for the selected technician.

---

## 3. Immutable Admin Audit Logging

Every administrative action on a technician or catalog item creates an immutable audit record containing:
- `id` (`aud_<timestamp>_<rand>`)
- `adminUid` (e.g., `admin_master`)
- `action` (`APPROVE_TECHNICIAN_KYC`, `VERIFY_TECHNICIAN_SKILL`, `UPDATE_TECHNICIAN_STATUS`, `UPDATE_SERVICE`, `CREATE_SERVICE`)
- `targetTechnicianUid` / `targetId`
- `previousStatus` / `previousValue`
- `updatedStatus` / `updatedValue`
- `reason` / `notes`
- `timestamp` (ISO-8601 UTC)

