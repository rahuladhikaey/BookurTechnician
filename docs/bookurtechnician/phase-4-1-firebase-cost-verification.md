# BOOKURTECHNICIAN — PHASE 4.1 FIREBASE BILLING, QUOTA & COST VERIFICATION

**Audit Date:** 2026-11-08  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1` (Mumbai)  
**Database UID:** `d0f3f390-85c6-4214-80ae-98d8c67c7adb`  
**Auditor Role:** Principal Firebase Infrastructure & FinOps Architect  

---

## 1. Live Cloud Firestore Database Configuration (Verified via Firebase MCP)

Using `mcp_firebase-mcp-server_firestore_get_database` against project `bookmytechnician-53d94`, the authoritative live database metadata is:

| Parameter | Live Verified Value | Architectural Implication |
| :--- | :--- | :--- |
| **`name`** | `projects/bookmytechnician-53d94/databases/(default)` | Default production database |
| **`uid`** | `d0f3f390-85c6-4214-80ae-98d8c67c7adb` | Provisioned `2026-04-04T06:34:54.377050Z` |
| **`locationId`** | `asia-south1` (Mumbai, India) | Regional pricing: \$0.036/100k reads, \$0.108/100k writes, \$0.012/100k deletes |
| **`type`** | `FIRESTORE_NATIVE` | Native mode (supports `:commit` atomic transactions & real-time listeners) |
| **`databaseEdition`** | `STANDARD` | Standard edition |
| **`concurrencyMode`** | `PESSIMISTIC` | Enforces lock acquisition & `currentDocument.updateTime` preconditions |
| **`appEngineIntegrationMode`** | `DISABLED` | Independent of legacy App Engine |
| **`pointInTimeRecoveryEnablement`** | `POINT_IN_TIME_RECOVERY_DISABLED` | Zero PITR storage overhead |
| **`freeTier`** | `true` | **50,000 free reads/day, 20,000 free writes/day, 20,000 free deletes/day, 1 GiB storage** preserved even on Blaze! |

---

## 2. Why Blaze Does NOT Permanently Eliminate HTTP 429 Errors

A critical correction in Phase 4.1 is removing the false assumption that upgrading a Firebase project from Spark to Blaze permanently eliminates `HTTP 429 RESOURCE_EXHAUSTED` or `409 ABORTED` errors. Even on the Blaze Pay-As-You-Go plan, Cloud Firestore returns `429` or `409` under the following conditions:

1. **Single-Document Write Hotspots (>1 write/sec sustained):**
   - Updating a single document (such as a popular technician's `technician_profiles/{id}` document or a global counter) faster than once per second causes lock contention and `429 RESOURCE_EXHAUSTED` / `409 ABORTED`.
2. **500/50/5 Traffic Ramp-Up Rule Violation:**
   - Increasing traffic to a new collection or lexicographically sequential document ID range faster than 500 ops/sec initially and +50% every 5 minutes triggers automatic `429` throttling while Firestore splits tablet ranges.
3. **Pessimistic Concurrency Lock Contention (`concurrencyMode: PESSIMISTIC`):**
   - Simultaneous `:commit` transactions targeting the same technician document cause optimistic/pessimistic precondition failures (`409 ABORTED`).
4. **GCP Billing Budget / Quota Caps:**
   - Custom daily spending limits or per-minute API quota caps configured in Google Cloud Console return `429 RESOURCE_EXHAUSTED`.

---

## 3. Corrective Quota, Backoff & Telemetry Implementation

### 3.1 Exponential Backoff with Full Jitter (`_requestWithBackoff`)
Implemented in both [`apps/customer_app_flutter/lib/services/firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L141-L189) and [`apps/technician_app/lib/core/network/firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/firestore_rest_client.dart#L136-L184):
- Automatically retries retryable responses (`HTTP 429`, `HTTP 503`, and `HTTP 409` containing `ABORTED`) up to `maxRetries = 3`.
- Delay formula per retry attempt $k \in \{1, 2, 3\}$:
  $$\text{Delay}(k) = 150\text{ ms} \times 2^{k-1} + \text{UniformRandom}(0, 100\text{ ms})$$
  (producing jittered backoffs of $\approx 150\text{–}250\text{ ms}$, $300\text{–}400\text{ ms}$, and $600\text{–}700\text{ ms}$).

### 3.2 Never Converting Quota Errors into False Empty Availability
- When retries are exhausted on `HTTP 429`, `FirestoreRestClient.isLastRequestQuotaExceeded` is set to `true` and `/catalog/availability` returns `HTTP 429` with `code: 'QUOTA_EXCEEDED'`.
- In [`booking_provider.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart#L550-L561), `HTTP 429` transitions `serviceAvailabilityStates[serviceId]` to `ServiceAvailabilityState.quotaExceeded` (never `noTechniciansAvailable`) and sets `bookingErrorCode: 'QUOTA_EXCEEDED'`.
- In [`catalog_screens.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart#L611-L612), the UI explicitly displays `'Server rate limit (HTTP 429) or database quota reached. Tap Reload to retry.'` and button label `'Database Limit Reached'`.

### 3.3 Real-Time Operation Telemetry & Free Quota Preservation
Both apps' `FirestoreRestClient` now record exact operation counters (`totalReads`, `totalWrites`, `totalDeletes`, `totalRetries`, `total429Responses`) and expose `getTelemetrySummary()` with live `asia-south1` cost calculation.

To preserve the daily free tier (`50,000` reads/day, `20,000` writes/day):
- **Technician Stationary Heartbeat:** `3 minutes` (`180s`) stationary interval + `30m` displacement filter in [`location_tracking_service.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/location/location_tracking_service.dart).
- **Customer Availability Cooldown:** `15s` cooldown on repeated spatial scans for identical coordinates + `30s` TTL in `_memoryCache` (bypassed only on explicit reload or pre-booking `forceRefresh: true` revalidation).

---

## 4. Daily Read/Write Volume & Monthly Cost Model (`asia-south1`)

### 4.1 Per-Actor Daily Operation Breakdown
- **Per Active Technician (8 hours online/day):**
  - Stationary heartbeats (1 write / 3 mins): $20 \times 8 = 160\text{ writes/day}$
  - Movement updates during 4 active jobs ($\ge 30\text{m}$ displacement): $\approx 80\text{ writes/day}$
  - Online/offline status & skill/profile reads/writes: $\approx 10\text{ writes/day}$, $25\text{ reads/day}$
  - **Total per Technician:** **$250\text{ writes/day}$**, **$25\text{ reads/day}$**
- **Per Active Customer Session (Browsing + 1 Booking):**
  - Catalog load (`service_categories` cached 5 mins): $8\text{ reads}$
  - Nearby availability scan (`technician_profiles` cached 30s) + pre-booking live `forceRefresh: true` revalidation ($N_{\text{tech}}$ docs read per scan): $2 \times N_{\text{tech}}\text{ reads}$
  - Atomic booking `:commit` transaction: $2\text{ writes}$ (`technician_profiles` + `bookings`) + $6\text{ reads}$ (status tracking)

### 4.2 Projected Daily & Monthly Cost Table (`freeTier: true` Deducted)

| Scale Tier | Active Techs / Day | Customer Sessions / Day | Daily Reads | Daily Writes | Billable Reads / Day (>50k Free) | Billable Writes / Day (>20k Free) | Est. Monthly Cost (USD) | Est. Monthly Cost (INR @ ₹84/\$) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Tier 1: Pilot** | 25 | 200 | 12,225 | 6,650 | **0** (Within Free Tier) | **0** (Within Free Tier) | **\$0.00 / mo** | **₹0 / mo** |
| **Tier 2: City Launch** | 80 | 500 | 52,000 | 21,000 | 2,000 / day | 1,000 / day | **\$0.05 / mo** | **₹4.54 / mo** |
| **Tier 3: Regional Scale** | 250 | 2,000 | 260,000 | 66,500 | 210,000 / day | 46,500 / day | **\$3.78 / mo** | **₹317.52 / mo** |

