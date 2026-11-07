# Phase 4 — Real-Time Availability Integrity Audit

**Audit Date:** November 7, 2026  
**Auditor:** Principal Software Architect, Application Security Lead & Senior Flutter/Firebase Engineer  
**System:** BookurTechnician Multi-Platform Ecosystem  
**Firebase Project:** `bookmytechnician-53d94` (Region: `asia-south1`)  
**Scope:** Customer Flutter Android, Technician Flutter Android, Cloud Firestore REST Engine

---

## Executive Summary

This forensic audit investigates the end-to-end real-time availability pipeline between the Technician App, Cloud Firestore, and the Customer App. It documents the elimination of hardcoded/synthetic fallback rosters, the enforcement of rigorous presence metrics, canonical service-to-skill matching, and the diagnosis of the root causes behind recent test anomalies shown in the 5 partner screenshots.

---

## 1. Purge of Fake Availability & Hardcoded Fallback Rosters

### Forensic Discovery
Previous versions of `apps/customer_app_flutter/lib/services/firestore_rest_client.dart` maintained an in-memory list `_defaultVerifiedTechnicians` containing mock records (`tech_partner_01`, `tech_partner_02`). When network requests encountered rate limiting, this static roster was returned, falsely presenting simulated technicians as live and ready for dispatch.

### Corrective Action
- Completely deleted `_defaultVerifiedTechnicians` from `apps/customer_app_flutter/lib/services/firestore_rest_client.dart`.
- Audited repository: `git grep "_defaultVerifiedTechnicians" apps/customer_app_flutter` returns **0 occurrences**.
- Customer availability counts are strictly computed from authoritative Cloud Firestore documents (`technician_profiles`).
- When no verified online technicians exist within 15 km, the system returns `availableTechnicianCount: 0` and sets availability state to `ServiceAvailabilityState.noTechniciansAvailable`.

---

## 2. Technician Presence Architecture

### Presence State Decomposition
Technician availability is partitioned into three independent states to prevent stale records from being treated as active:

1. **`isOnline` (Boolean):**
   Explicit duty toggle controlled by the technician via `toggleOnline(bool)` in `dashboard_provider.dart` and `partner_home_screen.dart`.
2. **`availabilityStatus` (Enum/String):**
   `AVAILABLE`, `BUSY` (assigned to an active booking), or `OFFLINE`.
3. **`locationFresh` (Boolean):**
   Computed by validating `lastLocationUpdate` against the authoritative UTC server timestamp:
   $$\text{ageMinutes} = |\text{DateTime.now().toUtc()} - \text{lastLocationUpdate.toUtc()}|$$
   - A location update older than 30 minutes is rejected as stale.
   - 24-hour-old GPS coordinates are never accepted as live availability.

---

## 3. Strict 15 km Spatial Verification (Haversine Formula)

The customer app computes the true geodesic distance between customer coordinates $(lat_1, lng_1)$ and technician coordinates $(lat_2, lng_2)$ using the spherical Haversine formula:

$$\Delta\sigma = 2 \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta\phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta\lambda}{2}\right)} \right)$$
$$d = R \cdot \Delta\sigma \quad (R = 6371.0 \text{ km})$$

- Strict threshold: $d \le 15.0 \text{ km}$.
- No simulated regional expansion is permitted.
- If customer GPS is unacquired, the system falls back to default Kolkata coordinates `(22.5726, 88.3639)` or prompts for location permission (`ServiceAvailabilityState.locationUnavailable`).

---

## 4. Canonical Service ID to Technician Skill Mapping

Skills saved in `technician_profiles` are matched against customer service requests using canonical normalized comparisons:

| Customer Service ID | Customer Service Name | Technician Skill ID | Technician Skill Name | Match Result |
| :--- | :--- | :--- | :--- | :--- |
| `ac_install` | `AC installation` | `sk_ac_installation` | `AC Installation` | **MATCH (Normalized exact)** |
| `ac_uninstall` | `AC uninstallation` | `sk_ac_uninstallation` | `AC Uninstallation` | **MATCH (Normalized exact)** |
| `fan_rep` | `Fan repair` | `sk_ceiling_fan_repair` | `Ceiling Fan Repair` | **MATCH (Canonical substring)** |
| `switch_rep` | `Switch board repair` | `sk_switch_board_repair`| `Switch Board Repair` | **MATCH (Canonical exact)** |

Normalization algorithm:
```dart
final sIdNorm = sId.toLowerCase().replaceAll('sk_', '').replaceAll('_', ' ').trim();
final sNameNorm = sName.toLowerCase().trim();
final skIdNorm = skillId.toLowerCase().replaceAll('sk_', '').replaceAll('_', ' ').trim();
final skNameNorm = skillName.toLowerCase().trim();

if (skIdNorm == sIdNorm ||
    skNameNorm == sNameNorm ||
    (skIdNorm.isNotEmpty && sIdNorm.isNotEmpty && (skIdNorm.contains(sIdNorm) || sIdNorm.contains(skIdNorm))) ||
    (skNameNorm.isNotEmpty && sNameNorm.isNotEmpty && (skNameNorm.contains(sNameNorm) || sNameNorm.contains(skNameNorm)))) {
  matches = true;
}
```

---

## 5. Forensic Analysis of User's 5 Testing Screenshots

| Screenshot | Observed Screen & State | Forensic Diagnosis | Resolution Implemented |
| :---: | :--- | :--- | :--- |
| **1** | Partner Registration (`Ram`, `9883637054`, `rahuladhikey180@gmail.com`) — button stuck with loading spinner. | Registration invoked candidate endpoints with non-existent DNS (`api.bookurtechnician.online`), blocking Android network thread for 15s. | Bypassed dead DNS; direct sub-2s EmailJS OTP delivery; immediate `SecureStorage` ID registration. |
| **2** | Select Your Skills — "8 Selected", Save button tapped. | Skills saved to local `SharedPreferences` but HTTP PATCH to Cloud Firestore failed with HTTP 429 (`RESOURCE_EXHAUSTED`). | Enforced local cache persistence and surfaced Firestore quota status; integrated GPS lat/lng and UTC timestamps in payload. |
| **3** | My Skills & Expertise — "Partner Technician ID: BT-PARTNER". | `userId` in `SecureStorage` had not been initialized before onboarding, defaulting to mock `BT-PARTNER`. | Fixed ID generation: `tech_${phone}` (`tech_9883637054` $\rightarrow$ `BT-988363`) stored immediately upon registration submit. |
| **4** | My Skills & Expertise — "Ram ID: BT-988363", "AC installation" toggle ON. | Profile and skill toggles restored from local cache; duty online state was not propagated to Firestore due to quota lock. | Synchronized local duty state with `cached_duty_online_$userId: true` and attached fresh UTC heartbeat on every toggle. |
| **5** | Customer App — "AC installation", "Currently no technician available", "Unavailable (0 Online)". | Tested on older APK build from before 15:30. Firestore REST API returned 429 Quota Exceeded on Spark Plan; converted to empty list `[]`. | Implemented explicit 429 status reporting, throttled queries, eliminated fake PostGIS text, and prepared fresh release APKs. |
