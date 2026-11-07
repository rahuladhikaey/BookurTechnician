# Remaining Production Blockers & Roadmap

**Date:** 2026-11-07  
**Severity:** Critical Launch Blockers & Action Items

---

## 1. Blocker 1 (CRITICAL): Firebase Spark Plan Quota Exhaustion (`HTTP 429`)

* **Severity:** **P0 — Hard Blocker**
* **Impact:** Every Firestore REST write and read currently fails with:
  ```json
  {"error": {"code": 429, "message": "Quota exceeded.", "status": "RESOURCE_EXHAUSTED"}}
  ```
  No technician can save skills to Firestore, no location pings succeed, and customer availability checks are blocked.
* **Resolution:** Upgrade Firebase Project `bookmytechnician-53d94` from **Spark** to **Blaze (Pay as you go)** in the [Firebase Console](https://console.firebase.google.com/project/bookmytechnician-53d94/usage). The free tier allowances (50,000 reads/day, 20,000 writes/day) remain free; burst traffic will no longer disable the database.

---

## 2. Blocker 2: DNS & Backend Gateway Unavailability

* **Severity:** **P1 — High**
* **Impact:** `AppConfig.apiBaseUrl` references `https://api.bookurtechnician.online/api/v1`. This DNS record does not resolve, causing connection attempts to stall until timeouts expire.
* **Resolution:**
  - Either point the DNS record for `api.bookurtechnician.online` to the active server/Render instance, or
  - Consolidate on Cloud Firestore as the single authoritative mobile data store as specified in the Phase 2 migration architecture.

---

## 3. Blocker 3: Client Google Sign-In SDK Missing

* **Severity:** **P2 — Medium**
* **Impact:** OAuth clients and SHA fingerprints are configured in Firebase and `google-services.json`, but `google_sign_in` package is not present in `pubspec.yaml`.
* **Resolution:** Add `google_sign_in: ^6.2.1` to `pubspec.yaml` and implement the Google OAuth button on `login_page.dart` once phone OTP testing is completed.

---

## 4. Blocker 4: Play App Signing SHA Fingerprints

* **Severity:** **P2 — Launch Gate**
* **Impact:** When published to Google Play, Google strips the local release keystore and re-signs the APK with Google's Play App Signing key.
* **Resolution:** Once the first internal testing `.aab` is uploaded to Google Play Console, copy the SHA-1 and SHA-256 fingerprints from Google Play Console > App Integrity > App signing and add them to Firebase Console.

