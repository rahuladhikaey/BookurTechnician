# Phase 5 — Firebase Spark Plan Optimization & Quota Safety

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Current Firebase Plan:** Spark (Free) — **Preserved (No Billing Upgrade Required)**  

---

## 1. Spark (Free) Plan Constraints & Optimization Strategy

The **BookurTechnician** platform operates within the Firebase **Spark (Free)** tier limits:
- **Cloud Firestore Daily Free Quota:** 50,000 document reads/day, 20,000 document writes/day, 20,000 document deletes/day, 1 GiB storage.
- **No Paid Cloud Functions Required:** All backend logic runs on the Node.js Core Service (`backend/node-core-service`) with synchronized Cloud Firestore REST persistence (`firestoreSync.js`) and client-side Firestore REST fallback (`FirestoreRestClient`).

---

## 2. Implemented Read & Write Optimizations

### 2.1 Version-Gated Catalog Caching (`catalogVersion`)
- Both the Node.js backend (`GET /api/v1/catalog/categories`) and Cloud Firestore (`service_categories` documents) include a monotonic integer `catalogVersion`.
- The Customer Flutter App (`apps/customer_app_flutter/lib/booking_provider.dart` and `services/firestore_rest_client.dart`) caches the 8 categories and 158 services in `SharedPreferences` (`bt_cached_catalog_v1` and `bt_cached_catalog_version_v1`) with a 15-minute TTL.
- When `catalogVersion` increases (e.g., Admin updates a service price or disables a service), the Customer App automatically invalidates its local cache and fetches fresh catalog data.

### 2.2 Partial Document Writes via `updateMask.fieldPaths`
- `backend/node-core-service/src/config/firestoreSync.js` (`upsertDocument`) and `apps/technician_app/lib/core/network/firestore_rest_client.dart` append `?updateMask.fieldPaths=...` to Firestore `PATCH` requests whenever a field mask is supplied.
- Prevents full-document overwrites, reduces payload size, and guarantees that updating skills never overwrites KYC, UPI, or GPS fields.

### 2.3 Paginated & Scoped Queries
- `GET /api/v1/catalog/services` supports `categoryId`, `subcategoryId`, `isActive`, `page`, and `limit` parameters (`NET-03`), ensuring the Admin Panel and mobile clients fetch only the slice of services needed.
- Customer App live availability queries filter only online technicians with fresh heartbeats (`lastLocationUpdate` within 5 minutes) and matching `canonicalServiceId`.

### 2.4 Exponential Backoff & Explicit Save States
- All Firestore REST operations implement retry with exponential backoff and random jitter on `HTTP 429` / `503` transient errors.
- Technician App onboarding and skill screens (`skill_selection_page.dart`, `document_upload_onboarding_page.dart`, `my_skills_page.dart`) surface explicit save states to the technician:
  - `Saving...`
  - `Saved to server` (`SAVED_TO_SERVER`)
  - `Saved locally, waiting to sync` (`SAVED_LOCALLY_PENDING_SYNC`)
  - `Failed to save` (`FAILED_TO_SAVE`)

