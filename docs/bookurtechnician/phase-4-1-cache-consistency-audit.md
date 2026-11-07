# BOOKURTECHNICIAN — PHASE 4.1 CACHE CONSISTENCY & PRESENCE INTEGRITY AUDIT

**Audit Date:** 2026-11-08  
**Firebase Project:** `bookmytechnician-53d94` (`asia-south1`)  
**Auditor Role:** Principal Flutter & Firebase Systems Architect  

---

## 1. Executive Summary & Phase 4 Findings

An independent code inspection of the Customer App, Technician App, and Firestore REST layer evaluated how cached catalog and availability states behave across app restarts, network failures, and checkout confirmation:

1. **In-Memory vs. Persistent Cache Survival Across App Restarts (FIXED):**
   - Previously, `FirestoreRestClient._memoryCache` stored `service_categories` (5-minute TTL) and `technician_profiles` (30-second TTL) strictly in RAM (`static final Map<String, _CachedResult> _memoryCache = {}`). Upon cold app restart, RAM caches were wiped, while `AppState.serviceAvailabilityCounts` started empty until live network calls completed.
   - However, if a cached snapshot was restored or held in `AppState`, the UI did not distinguish between **cached availability** and **live server-confirmed availability**.
2. **Skill Saves Overwriting Technician GPS & Heartbeat Timestamps (CRITICAL FLAW — FIXED):**
   - In [`apps/technician_app/lib/features/onboarding/data/skill_service.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/features/onboarding/data/skill_service.dart) (`saveSelectedSkills` and `toggleSkill`) and [`apps/technician_app/lib/core/network/firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/firestore_rest_client.dart) (`handleDioRequest` for `/skills`), saving or toggling a skill previously acquired device GPS or fallback coordinates (`22.5726, 88.3639`), set `lastLocationUpdate: DateTime.now().toUtc().toIso8601String()`, and set `isOnline: true`.
   - This meant a technician who was actually offline or had stale GPS could appear "online with fresh GPS" simply by editing their skills!

---

## 2. Corrective Implementation

### 2.1 Persistent Cache Survival & Explicit Cached vs. Live Labelling
In [`apps/customer_app_flutter/lib/booking_provider.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart):
1. **Persistent Storage Across Restarts (`SharedPreferences`):**
   - Category catalog is persisted under `'bt_cached_categories_v1'` whenever `loadCatalog()` receives a live `200 OK` response.
   - Service availability counts and timestamp are persisted under `'bt_cached_availability_v1'` via `_persistAvailabilityCache(counts)` whenever `fetchNearbyAvailability()` or `fetchSingleServiceAvailability()` receives a live `200 OK` response.
2. **Explicit State Flags in `AppState`:**
   - Added `isAvailabilityCached` (`bool`), `availabilityCachedAt` (`DateTime?`), and `isCategoriesCached` (`bool`) to `AppState`.
   - On cold start, `restoreCachedCatalogAndAvailability()` loads the persisted catalog (`isCategoriesCached: true`) and availability snapshot (`isAvailabilityCached: true`), immediately followed by a live server refresh.
3. **Clear UI Distinction Between Cached and Live Data:**
   - `AppState.getServiceAvailabilityText(serviceId)` returns:
     - When `isAvailabilityCached == true`: `'Cached (N online) • Verifying live...'`
     - When `isAvailabilityCached == false` (live server confirmed): `'N technician(s) available nearby'`
   - In [`apps/customer_app_flutter/lib/screens/catalog_screens.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart#L606-L611), the subtitle explicitly displays:
     - `'Cached status shown • Live server verification required before booking'` when `state.isAvailabilityCached == true`.
4. **Zero Booking Authorization from Cached Availability Alone:**
   - Added `AppState.isServiceLiveConfirmedAvailable(serviceId)` which returns `true` **only** when `aState == ServiceAvailabilityState.available && !isAvailabilityCached && count > 0`.
   - Both `confirmOrder()` and `confirmDirectServiceBooking()` in [`booking_provider.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart#L1705-L1855) execute an immediate, uncached `await fetchSingleServiceAvailability(service.id, lat: lat, lng: lng, forceRefresh: true)` call before submitting `POST /bookings`, and `POST /bookings` in [`firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L1136-L1156) queries `technician_profiles` and `bookings` with `forceRefresh: true` (bypassing `_memoryCache`).

### 2.2 Strict Separation of Skill Updates from GPS & Presence Updates
In [`apps/technician_app/lib/features/onboarding/data/skill_service.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/features/onboarding/data/skill_service.dart#L181-L390) and [`apps/technician_app/lib/core/network/firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/firestore_rest_client.dart#L663-L793):
- Removed `package:geolocator/geolocator.dart` from `skill_service.dart`.
- Removed `latitude`, `longitude`, `currentLatitude`, `currentLongitude`, `lastLocationUpdate`, `isOnline`, `online`, and `availabilityStatus` from all skill save and skill toggle payloads.
- Firestore `PATCH` operations for skill updates use `updateMask.fieldPaths` restricted strictly to `id`, `uid`, `technicianId`, `technicianCode`, `skills`, `categories`, `category`, `totalSkillsCount`, `verifiedSkillsCount`, `pendingSkillsCount`, and `updatedAt`.
- GPS coordinates and `lastLocationUpdate` are updated **exclusively** by [`LocationTrackingService`](file:///d:/BookurTechnician/apps/technician_app/lib/core/location/location_tracking_service.dart) when the technician is actively online with valid GPS permissions.

---

## 3. Automated Verification Results

| Verification Check | Test File | Result |
| :--- | :--- | :---: |
| **Scenario 5:** Cold app restart restores cached categories and availability from `SharedPreferences`, marks `isAvailabilityCached == true`, displays `'Cached (2 online) • Verifying live...'`, and forces live server revalidation before booking | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) | **PASS** |
| **Skill vs. GPS Separation:** `POST /technicians/skills/bulk` writes skill & category fields via `updateMask` and never touches `latitude`, `longitude`, `lastLocationUpdate`, or `isOnline` | [`phase_4_1_presence_and_otp_test.dart`](file:///d:/BookurTechnician/apps/technician_app/test/phase_4_1_presence_and_otp_test.dart) | **PASS** |

