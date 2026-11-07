# Customer Live Availability Test & Spatial Matching Report

**File Inspected:** [booking_provider.dart](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart)  
**REST Client:** [firestore_rest_client.dart](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart)  
**UI Screen:** [catalog_screens.dart](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart)

---

## 1. Distinct Availability States

The Customer App previously represented network errors, database failures, and zero technicians as a single integer count `0`. This made database failures indistinguishable from "no partner available".

We refactored `BookingState` to track distinct states using `enum ServiceAvailabilityState`:

```dart
enum ServiceAvailabilityState {
  available,                // >= 1 active matching technician within 15 km
  noTechniciansAvailable,   // Database scanned successfully, 0 matching partners online
  checkingAvailability,     // Scanning / loading in progress
  networkError,             // Server unreachable / socket disconnected
  quotaExceeded,            // Firebase Spark daily quota reached (HTTP 429)
  locationUnavailable,      // GPS permissions denied or location services off
}
```

---

## 2. Dynamic UI Representation

In [catalog_screens.dart](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart), the Nearby Section and the Bottom Booking CTA adapt dynamically:

| State | Nearby Section Subtitle | CTA Button Text | Button State |
|---|---|---|---|
| `available` | *"Automated nearest technician dispatch upon booking confirmation"* | **Book Now** | Enabled (Active) |
| `noTechniciansAvailable` | *"No partners online in 15 km with matching skills right now."* | **Unavailable (0 Online)** | Disabled (Locked) |
| `checkingAvailability` | *"Scanning 15 km radius for certified partners..."* | **Checking...** | Disabled (Loading) |
| `quotaExceeded` | *"Firebase daily quota reached (Spark Plan). Upgrade to Blaze plan in Console."* | **Database Limit Reached** | Disabled (Amber Warning) |
| `networkError` | *"Unable to connect to server. Tap Reload to retry."* | **Connection Error** | Disabled (Retryable) |
| `locationUnavailable` | *"Please enable GPS location to detect local partners."* | **Turn On GPS** | Enabled (Opens GPS Dialog) |

---

## 3. Spatial Matching & Stale Location Logic

In [firestore_rest_client.dart](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart):

### A. Distance Filter (Haversine Formula)
```dart
static double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}
```
* Strict radius: **15.0 km**.
* Staging/Corridor fallback: up to **85.0 km** if reachable cluster is empty.

### B. Stale Location Filter (> 30 minutes)
Technicians who close the app without turning duty off are prevented from remaining as "ghost partners":
```dart
final lastUpdateStr = t['lastLocationUpdate']?.toString() ?? t['updatedAt']?.toString();
if (lastUpdateStr != null && lastUpdateStr.isNotEmpty) {
  final lastUpdate = DateTime.parse(lastUpdateStr);
  if (now.difference(lastUpdate).inMinutes > 30) {
    return false; // Stale location rejected
  }
}
```

### C. Enhanced Multi-Format Skill Matching
Supports:
1. Object map matching: `skill['skillId'] == sId` or `skill['name'].toLowerCase() == sName.toLowerCase()`.
2. Toggle status check: `skill['enabled'] != false`.
3. Raw string matching: `skill == sId` or `skill.contains(sId)`.
4. Substring bidirectional match: `sName.contains(skillName)`.
5. Category-level match: `category == catName` or `categories.contains(catName)`.

---

## 4. Why AC Installation Showed 0 Online in the User's Test

In the user's test:
1. Technician phone toggled "AC installation" to active.
2. The write to Cloud Firestore was rejected by Google with `HTTP 429 Quota Exceeded`.
3. The Customer App requested `/catalog/availability?serviceId=ac_install`.
4. Firestore returned `HTTP 429 Quota Exceeded` to the Customer App as well.
5. In previous code, `listCollection` caught the 429 and returned `[]`, resulting in `targetCount = 0` and HTTP 200.
6. The customer app displayed `Unavailable (0 Online)` because the server had reported 0 available technicians.
7. With our fix in place, the customer app now correctly identifies the `quotaExceeded` state and alerts the operator of the database capacity limit.

