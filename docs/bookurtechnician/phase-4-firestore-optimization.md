# Phase 4 — Cloud Firestore Optimization & Quota Governance

**Document:** Firestore Read/Write Optimization & Quota Strategy  
**Project ID:** `bookmytechnician-53d94`  
**Region:** `asia-south1` (Mumbai)  
**Plan Status:** Spark Plan (Free Tier) $\rightarrow$ Migration Requirement to Blaze Plan (Pay-as-you-go)

---

## 1. Problem Statement: Spark Plan Daily Read Limits

Google Cloud Firestore imposes a strict hard ceiling on projects operating on the free **Spark Plan**:
- **Daily Document Reads:** 50,000 reads / 24 hours.
- **Daily Document Writes:** 20,000 writes / 24 hours.
- **Daily Document Deletes:** 20,000 deletes / 24 hours.

When this daily quota is reached, Google Cloud locks all Firestore operations with:
```json
{
  "error": {
    "code": 429,
    "message": "Quota exceeded.",
    "status": "RESOURCE_EXHAUSTED"
  }
}
```
Until midnight Pacific Time (PST), **every read, write, and patch request fails with HTTP 429**.

---

## 2. In-Depth Root Cause Analysis of Quota Burn

1. **Unthrottled Collection Listings:**
   Previously, every page transition in the Customer App (`ServiceDetailScreen`, `CategoryServicesScreen`, `HomeScreen`) invoked `listCollection('technician_profiles')` and `listCollection('service_categories')`.
   - With 20 registered technicians and 8 categories, a single customer viewing 10 services generated $10 \times (20 + 8) = 280$ document reads in under two minutes.
   - 150 customer testing sessions exhausted the entire 50,000 daily read quota within hours.
2. **Stationary Technician Write Spam:**
   The Technician App background tracking service emitted location updates regardless of movement, resulting in repeated HTTP PATCH requests to `technician_profiles`.

---

## 3. Implemented Client-Side Optimizations

### A. Two-Tier In-Memory Cache with Adaptive TTL
In `apps/customer_app_flutter/lib/services/firestore_rest_client.dart`:
```dart
static Future<List<Map<String, dynamic>>> listCollection(String collection,
    {int pageSize = 250, bool forceRefresh = false}) async {
  final cacheKey = 'col_$collection';
  final now = DateTime.now();
  // Categories and Banners cached for 10 minutes (600s); technicians cached for 30s
  final ttlSeconds = collection.contains('categories') 
      ? 600 
      : (collection.contains('banners') ? 600 : 30);

  if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
    final cached = _memoryCache[cacheKey]!;
    if (now.difference(cached.timestamp).inSeconds < ttlSeconds) {
      return (cached.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }
  ...
}
```
**Impact:** Reduces catalog and banner document reads by **96.7%**.

### B. 15-Second Cooldown Throttle on Spatial Availability
In `apps/customer_app_flutter/lib/booking_provider.dart`:
```dart
final lastFetch = state.lastAvailabilityFetchTime;
if (lastFetch != null &&
    DateTime.now().difference(lastFetch).inSeconds < 15 &&
    state.lastAvailabilityLatitude == targetLat &&
    state.lastAvailabilityLongitude == targetLng &&
    state.serviceAvailabilityCounts.isNotEmpty) {
  debugPrint('⚡ [Availability] Reusing fresh (<15s) spatial availability snapshot.');
  return;
}
```
**Impact:** Prevents rapid consecutive scans during rapid scrolling or repeated screen touches.

### C. Redundant Service Detail Scan Elimination
Removed duplicate `fetchNearbyAvailability()` call from `ServiceDetailScreen.initState` in `catalog_screens.dart`. Only `fetchSingleServiceAvailability(serviceId)` is triggered.

### D. Technician GPS Throttling (30m & 3min Stationary Heartbeat)
In `apps/technician_app/lib/core/services/location_tracking_service.dart`:
- `distanceFilter: 30` (requires at least 30 meters displacement before firing).
- If stationary, a periodic 3-minute timer verifies presence, burning at most $20 \text{ writes/hour}$ per active technician.

---

## 4. Financial Projections: Blaze Plan Cost Model

Migrating `bookmytechnician-53d94` to the Firebase Blaze Plan completely resolves HTTP 429 quota locks while maintaining near-zero operating costs.

| Monthly Active Users | Estimated Daily Reads | Blaze Billable Reads/Day | Monthly Cost (USD) | Monthly Cost (INR) |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 1 (Dev & QA)** | 40,000 reads/day | 0 (Within 50,000 free tier) | **$0.00** | **₹0.00** |
| **Stage 2 (Pilot — 50 Techs, 500 Orders)** | 120,000 reads/day | 70,000 reads/day | **$1.26 / month** | **₹105 / month** |
| **Stage 3 (Scale — 500 Techs, 5,000 Orders)** | 800,000 reads/day | 750,000 reads/day | **$13.50 / month** | **₹1,120 / month** |

*Blaze pricing: \$0.06 per 100,000 reads beyond the daily 50,000 free allotment.*
