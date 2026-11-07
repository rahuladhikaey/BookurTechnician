# BOOKURTECHNICIAN — COMPLETE FORENSIC ARCHITECTURE AUDIT
## Document 03: Booking Dispatch Engine & Delivery Lifecycle Audit

**Audit Date:** November 7, 2026  
**Auditor Roles:** Principal Software Architect, Backend Security Auditor  
**Investigation Target:** BUG 1 — "Technician booking request not appearing: Why customer bookings reach Admin but do not reach nearby online technicians."

---

## 1. Executive Forensic Summary: The Root Cause of BUG 1

The phenomenon where **customer bookings reach the Admin Panel but never appear on nearby online technicians' devices** is caused by an architectural disconnect between client failover routes:

1. **The Booking Never Touched the Backend Dispatch Engine:**  
   When the Customer App created booking `bkg_1793789038012`, the primary Node.js backend candidates failed to connect. The app automatically fell back to [`FirestoreRestClient.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L428-L442) and wrote the booking directly to the Cloud Firestore `bookings` collection.
2. **The Admin Panel Reads Cloud Firestore Directly:**  
   The React Admin Panel runs [`firestoreAdapter.js`](file:///d:/BookurTechnician/apps/admin_panel/src/api/firestoreAdapter.js#L70), which continuously polls or fetches the Cloud Firestore `bookings` collection via REST. As a result, the booking was immediately visible in the Admin Panel.
3. **No Trigger Exists in Cloud Firestore to Dispatch to Technicians:**  
   Cloud Firestore is a passive database. Because there are **zero Cloud Functions** deployed, writing a booking document does not trigger any webhook, notification, or dispatch worker.
4. **The Technician App Has No Firestore Listener:**  
   The Technician App does not have the `cloud_firestore` package installed and does not poll Firestore for new bookings. It relies 100% on Socket.IO and FCM push notifications.
5. **The Result:** The booking landed in Firestore as an unassigned orphan. The Node.js dispatch engine was completely bypassed, no Socket.IO event was emitted, no FCM push was sent, and the nearby technician received zero notifications.

---

## 2. Forensic Analysis of Real Test Booking `bkg_1793789038012`

On November 4, 2026, at 16:13:58 IST, a real test was conducted on physical Android devices in Birnagar, Ranaghat, West Bengal:

### Customer Side:
- **Booking ID:** `bkg_1793789038012`
- **Customer Name:** Rahul Adhikary (`+91 8145343534`)
- **Service Booked:** "AC installation" (`serviceId: ac_install`, `category: AC Services`)
- **Customer Location:** `lat: 23.2219612, lng: 88.5672127` (Birnagar, Ranaghat)
- **Status in Firestore:** `CONFIRMED`
- **Technician ID in Firestore:** `null` (Never assigned!)

### Technician Side:
- **Technician ID:** `tech_9883637054`
- **Technician Name:** Ram (`+91 9883637054`)
- **Technician Skills:** 8 verified skills declared, including `ac_install` ("AC installation") toggled ON.
- **Technician Location:** `lat: 23.2219548, lng: 88.5672115` (Ranaghat)
- **Physical Distance:** **0.0012 km (1.2 meters away from the customer!)**
- **Technician Status:** `isOnline: true`, `availabilityStatus: "AVAILABLE"`

### The Evidence:
Despite both devices being online, verified, sharing identical service skills, and situated 1.2 meters apart in the real world:
- The Customer App UI navigated to the tracking screen with "Assigning Expert...".
- The Admin Panel displayed booking `bkg_1793789038012` in `BookingsManager.jsx`.
- **Technician Ram's phone stayed completely silent. No popup appeared. No ringtone played.**

---

## 3. End-to-End Booking Lifecycle Trace

```
[CUSTOMER APP]
  |
  | 1. User taps "Book Now" for "AC installation"
  |    Calls ApiClient.post('/bookings', payload)
  v
[NETWORK CLIENT]
  |
  | 2. Attempts HTTP POST to candidate hosts:
  |    - https://api.bookurtechnician.online/api/v1 (DNS Name Resolution Failed)
  |    - https://bookurtechnician.onrender.com/api/v1 (HTTP 404 Not Found)
  |    - http://192.168.1.3:4000/api/v1 (Connection Refused - No server on port 4000)
  |
  | 3. All backend candidates throw exceptions after 3500ms timeout
  v
[FIRESTORE REST FALLBACK]
  |
  | 4. ApiClient catches error and calls FirestoreRestClient.handleRequest('POST', '/bookings')
  | 5. Generates bookingId: 'bkg_1793789038012', startOtp: '7487', endOtp: '4070'
  | 6. Sends HTTP PATCH to:
  |    https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents/bookings/bkg_1793789038012
  v
[CLOUD FIRESTORE (bookmytechnician-53d94)]
  |
  | 7. Document created in 'bookings' collection.
  |    Status: 'CONFIRMED', technicianId: null.
  |
  +-----------------------------------+-----------------------------------+
  |                                                                       |
  v (Direct Read)                                                         x (MISSING LINK)
[REACT ADMIN PANEL]                                             [NODE.JS DISPATCH ENGINE]
  |                                                                       |
  | 8. api.getBookings() fails on Render ->                               x Node.js was never called.
  |    calls firestoreAdapter.js ->                                       x automaticDispatchEngine.js never ran.
  |    reads 'bookings' from Firestore REST                               x No Socket.IO event emitted.
  v                                                                       x No FCM push sent.
[ADMIN SEES BOOKING!]                                                     v
                                                                [TECHNICIAN APP NEVER HEARS OF BOOKING!]
```

---

## 4. Audit of the Intended Backend Dispatch Engine

Even if the Node.js backend were online, our forensic audit of [`backend/node-core-service/src/services/automaticDispatchEngine.js`](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L1) reveals **three fatal architectural blockers** that would still prevent the booking from reaching the technician:

### Blocker 1: Socket.IO Authentication Handshake Mismatch
- **In Node.js:** [`server.js` lines 140-155](file:///d:/BookurTechnician/backend/node-core-service/src/server.js#L140-L155) enforces authentication on all Socket.IO connections via `io.use()`:
  ```javascript
  const rawToken = socket.handshake?.auth?.token || socket.handshake?.headers?.authorization;
  if (rawToken) {
    const resolved = await resolveUserFromToken(rawToken);
    if (resolved && !resolved.error) socket.user = resolved;
  }
  ```
  In [`server.js` line 173-179](file:///d:/BookurTechnician/backend/node-core-service/src/server.js#L173-L179):
  ```javascript
  if (roomName.startsWith('tech_')) {
    if (!user) return false; // REJECTS IF NOT AUTHENTICATED
    ...
  }
  ```
- **In Technician Flutter App:** [`apps/technician_app/lib/core/services/socket_service.dart` lines 73-84](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/socket_service.dart#L73-L84):
  ```dart
  _socket = io.io(
    url,
    io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableAutoConnect()
        .enableReconnection()
        .build(), // <-- NO AUTH TOKEN PROVIDED!
  );
  ```
- **Result:** The technician socket is unauthenticated (`socket.user == null`). When it calls `join:room: tech_tech_9883637054`, the server rejects it with `Forbidden: Unauthorized to join room`. The client never joins the room, so `io.to('tech_' + techId).emit()` never reaches the phone.

### Blocker 2: Strict `NO_VALID_FCM_TOKEN` Disqualification Rule
- **In Node.js:** [`automaticDispatchEngine.js` lines 718-722](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L718-L722):
  ```javascript
  // 10. Technician has a registered valid FCM token for push notification
  const validTokens = getTechnicianValidFcmTokens(techProfile);
  if (validTokens.length === 0) {
    reasons.push('NO_VALID_FCM_TOKEN');
  }
  ```
- **Evidence:** Line 727 specifies `eligible: reasons.length === 0`.
- Because the technician's FCM token was never saved to Firestore or PostgreSQL, `validTokens.length` is 0.
- **Result:** The dispatch engine immediately disqualifies the technician as **INELIGIBLE**, excluding them from the candidate ranking pool.

### Blocker 3: Stale GPS Coordinates Check (10-Minute Expiry)
- **In Node.js:** [`automaticDispatchEngine.js` lines 683-690](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L683-L690):
  ```javascript
  const ageSec = (Date.now() - new Date(lastLocTs).getTime()) / 1000;
  if (ageSec > dispatchConfig.gpsFreshnessThresholdSeconds) { // 600 seconds (10 mins)
    reasons.push(`STALE_GPS_COORDINATES (${Math.round(ageSec)}s old)`);
  }
  ```
- **Evidence:** If a technician has not moved or sent a GPS ping in the last 10 minutes, the dispatch engine marks them ineligible.

---

## 5. Race Conditions and Concurrency Audit

### 5.1. Booking Acceptance Locking
- In [`automaticDispatchEngine.js` line 33](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L33):
  `const bookingLocks = new Set();`
- When a technician accepts an offer:
  ```javascript
  if (bookingLocks.has(bookingId)) {
    return { success: false, error: 'Booking is currently being accepted by another technician' };
  }
  bookingLocks.add(bookingId);
  ```
- **Vulnerability:** `bookingLocks` is an in-memory `Set` local to a single Node.js process. In a scaled multi-instance deployment (e.g., Kubernetes, Render horizontal scaling, or Cloud Run), two technicians could accept the same booking concurrently on different instances without mutual exclusion.
- **Solution:** A distributed Redis lock (`SET booking:lock:<id> <token> NX EX 10`) or an atomic database row lock (`SELECT id FROM bookings WHERE id = $1 FOR UPDATE`) must be used.

