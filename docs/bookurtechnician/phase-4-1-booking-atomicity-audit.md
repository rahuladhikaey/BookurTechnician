# BOOKURTECHNICIAN — PHASE 4.1 BOOKING ATOMICITY & CONCURRENCY AUDIT

**Audit Date:** 2026-11-08  
**Firebase Project:** `bookmytechnician-53d94` (`asia-south1`, Database UID: `d0f3f390-85c6-4214-80ae-98d8c67c7adb`)  
**Auditor Role:** Principal Firebase Architect & Distributed Systems Security Auditor  

---

## 1. Executive Summary & Critical Phase 4 Flaws Identified

During the independent Phase 4.1 forensic review of the Phase 4 codebase, **three critical booking safety vulnerabilities** were discovered in the actual source code:

1. **Client-Side Optimistic Fake Booking Creation (CRITICAL FLAW — FIXED):**
   - In [`apps/customer_app_flutter/lib/booking_provider.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart) (`confirmOrder` and `confirmDirectServiceBooking`), the Customer App previously instantiated a local `Booking` object with `BookingStatus.confirmed` **before** calling `ApiClient.post('/bookings', payload)` and wrapped the network call in a `try { ... } catch (e) {}` block that swallowed all errors.
   - Furthermore, in [`apps/customer_app_flutter/lib/screens/catalog_screens.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart), `final targetBookingId = booked?.id ?? code;` navigated the user to `BookingTrackingScreen` even when `booked == null` or when the server returned `409 Conflict`, `429 Too Many Requests`, or `503 Network Error`!
2. **Non-Transactional Firestore Booking Writes (CRITICAL FLAW — FIXED):**
   - In [`apps/customer_app_flutter/lib/services/firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart), `POST /bookings` previously read `technician_profiles` (using cached data), picked the first online technician, and performed a non-atomic `PATCH` on `/bookings/{id}` without locking the technician or verifying `currentDocument.updateTime`. Two customers booking simultaneously could be assigned the exact same technician.
3. **Unsafe Backend Fallback to Offline / Out-of-Radius Technicians (CRITICAL FLAW — FIXED):**
   - In [`backend/node-core-service/src/controllers/bookingController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/bookingController.js), when `scanTechniciansWithin15Km` returned `0` candidates, a fallback block queried `technician_profiles` without online, freshness, or 15 km radius filters.

---

## 2. Corrective Architecture Implemented

### 2.1 Authoritative Pre-Assignment Verification (6 Mandatory Gates)
Both the Node.js Core Service ([`bookingController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/bookingController.js#L108-L468) + [`automaticDispatchEngine.js`](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L600-L736)) and the Cloud Firestore Direct Transaction Engine ([`firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L1106-L1367)) now enforce 6 strict pre-assignment gates using **live uncached server data** (`forceRefresh: true`):

| Gate | Verification Rule | Explicit Rejection Code | HTTP Status |
| :--- | :--- | :--- | :---: |
| **1. Idempotency Guard** | Rejects duplicate `idempotencyKey` or active duplicate `(customerId, serviceId)` booking | `DUPLICATE_BOOKING` | `409` |
| **2. Technician Auth & KYC** | `kycStatus == 'VERIFIED'` (or `APPROVED`) and `accountStatus == 'ACTIVE'` | `NO_TECHNICIAN_ONLINE` | `409` |
| **3. Live Online Presence** | `isOnline == true` and `availabilityStatus == 'AVAILABLE'` | `TECHNICIAN_WENT_OFFLINE` | `409` |
| **4. Fresh GPS Heartbeat** | `lastLocationUpdate` timestamp age $\le 10\text{ minutes}$ ($600\text{ seconds}$) | `STALE_LOCATION` | `409` |
| **5. Canonical Skill Match** | Requested `serviceId` matches technician's declared `skills[]` with `enabled == true` | `SKILL_MISMATCH` | `409` |
| **6. 15 km Haversine Radius** | Exact Haversine distance between customer GPS and fresh technician GPS $\le 15.0\text{ km}$ | `OUT_OF_RADIUS` | `409` |
| **7. Zero Active Conflict** | Technician `availabilityStatus != 'BUSY'` and not assigned to any `ASSIGNED`/`ACCEPTED`/`IN_PROGRESS` booking | `TECHNICIAN_BUSY_CONFLICT` | `409` |

### 2.2 Atomic Firestore `:commit` Transaction with Optimistic Concurrency Precondition
In [`FirestoreRestClient.atomicAssignBookingTransaction()`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L416-L524), booking assignment executes a single atomic HTTP `POST` to:
```
https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents:commit
```
containing two coupled writes in a single atomic batch:
1. **Write 1 (`technician_profiles/{techId}`):**
   - Sets `availabilityStatus = 'BUSY'` and `activeBookingId = bookingId`.
   - Enforces `currentDocument: {'updateTime': expectedTechUpdateTime}` (captured from the live `forceRefresh: true` read of the technician document).
   - If another customer's request modified the technician document a millisecond earlier, Firestore's `PESSIMISTIC` concurrency engine rejects the commit with `409 ABORTED`, which is translated to `409 TECHNICIAN_BUSY_CONFLICT`.
2. **Write 2 (`bookings/{bookingId}`):**
   - Creates the booking document with `status = 'ASSIGNED'`, `technicianId = internalUid`, `technicianCode = BT-XXXXXX`, and `currentDocument: {'exists': false}` so the same booking ID can never be overwritten twice.
3. **In-Memory Concurrency Mutex (`_activeTechnicianLocks` & `technicianAssignmentLocks`):**
   - Serializes concurrent in-process requests targeting the same `technicianId` before they even hit the network wire.

### 2.3 Customer App Failure Handling (Zero Fake Bookings)
- In [`booking_provider.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart#L1695-L1950), `confirmOrder()` and `confirmDirectServiceBooking()` now:
  1. Force a live availability revalidation (`fetchSingleServiceAvailability(..., forceRefresh: true)`) before submitting `POST /bookings`.
  2. Only create and persist `liveBooking` when `res.statusCode == 200 || res.statusCode == 201`.
  3. On any `409`, `429`, `503`, or socket exception, populate `state.bookingErrorCode` and `state.bookingError` and return `null`.
- In [`catalog_screens.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart#L1735-L1852), if `booked == null`, the checkout modal closes and displays an explicit `Booking Not Confirmed (<ERROR_CODE>)` `AlertDialog` instead of navigating to `BookingTrackingScreen`.

---

## 3. Automated Concurrency & Failure Test Verification

| Test Scenario | Test Suite & Location | Result |
| :--- | :--- | :---: |
| **Scenario 1:** Two customers attempting to book the same technician simultaneously | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** (1st: `201 ASSIGNED`, 2nd: `409 TECHNICIAN_BUSY_CONFLICT`) |
| **Scenario 2:** Technician going offline during checkout | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** (`409 TECHNICIAN_WENT_OFFLINE`, `booked == null`) |
| **Scenario 3:** Stale GPS location (>10 mins old) | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** (`409 STALE_LOCATION`) |
| **Scenario 6:** Network disconnection during booking | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) | **PASS** (`NETWORK_ERROR`, `activeBooking == null`) |
| **Scenario 7:** Duplicate booking request (same `idempotencyKey`) | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** (`409 DUPLICATE_BOOKING`) |

