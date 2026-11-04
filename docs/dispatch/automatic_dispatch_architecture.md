# BookurTechnician — Automatic Technician Dispatch Architecture

## 1. Executive Summary
The BookurTechnician Automatic Technician Dispatch Engine implements a production-grade, Uber/Rapido-style sequential technician matching, offer delivery, atomic locking, and real-time GPS tracking pipeline across:
- **Node.js Core Backend** (`backend/node-core-service/src/services/automaticDispatchEngine.js` & `dispatchController.js`)
- **PostgreSQL + PostGIS** (`backend/node-core-service/src/config/postgres.js`)
- **Cloud Firestore & FCM Push Notifications** (`bookmytechnician-53d94`)
- **EmailJS Transactional OTP Verification** (`backend/node-core-service/src/services/emailService.js`)
- **Socket.io Real-Time Authenticated Rooms** (`backend/node-core-service/src/server.js`)
- **Flutter Customer App** (`apps/customer_app_flutter`)
- **Flutter Technician App** (`apps/technician_app`)
- **React Admin Panel** (`apps/admin_panel`)

---

## 2. End-to-End Dispatch Workflow

```
CUSTOMER BOOKS SERVICE
   │
   ▼
BACKEND VALIDATES BOOKING & AUTHORITATIVE PRICING
   │
   ▼
SEND START OTP TO CUSTOMER REGISTERED EMAIL VIA EMAILJS API
   │
   ▼
CREATE DISPATCH SESSION (SEARCHING, Initial Radius = 3 km)
   │
   ▼
POSTGIS + HAVERSINE SPATIAL SCAN & 10-POINT ELIGIBILITY FILTER
   │
   ▼
MULTI-FACTOR RANKING ENGINE (35% ETA/Dist, 25% Skill, 20% Avail, 10% Rating, 10% Reliability)
   │
   ▼
SEQUENTIAL OFFER TO TOP-RANKED TECHNICIAN (#1 ONLY)
   ├── Socket Event: `dispatch:offer:new` -> `tech_<technicianId>`
   ├── FCM Push Alert (`technician_emergency_channel` / `siren_alarm`)
   └── Authoritative Server Expiration Timer (15–20s configurable)
   │
   ├──► IF ACCEPTED:
   │       ├── Atomic Mutex & PostgreSQL Row-Level Lock (`FOR UPDATE`)
   │       ├── Winner -> 200 OK; Simultaneous Loser -> 409 CONFLICT
   │       ├── Cancel other pending offers (`dispatch:offer:cancelled`)
   │       ├── Emit `booking:technician:assigned` -> `cust_<customerId>` & `booking_<bookingId>`
   │       ├── Live GPS Telemetry (`booking:partner:location`) -> Authorized Rooms Only
   │       ├── Arrival Geofence Verification (<= 500m) -> `ARRIVED`
   │       ├── Start OTP Verified -> `IN_PROGRESS` (End OTP emailed via EmailJS)
   │       └── End OTP Verified -> `COMPLETED`
   │
   └──► IF REJECTED / TIMED OUT / WENT OFFLINE:
           ├── Mark Offer `REJECTED` or `EXPIRED` in `dispatch_offers`
           ├── Log to `dispatch_audit_logs`
           ├── Offer to Next Ranked Eligible Technician (#2, #3...)
           └── If Radius Exhausted: Expand `3 km -> 5 km -> 10 km -> 15 km`
                 └── If All Radii Exhausted: Mark `FAILED_NO_TECHNICIAN` / `NO_TECHNICIAN_AVAILABLE`
                     and Emit `booking:dispatch:failed` with Retry / Reschedule options
```

---

## 3. Core Architectural Components
1. **Authoritative Dispatch Engine (`automaticDispatchEngine.js`)**:
   - Owns all dispatch session state (`dispatch_sessions`), sequential offer lifecycle (`dispatch_offers`), server-side expiration timers, radius expansion, and atomic assignment locks.
2. **Spatial Discovery (`postgresSpatialScanner.js` & `automaticDispatchEngine.js`)**:
   - Uses PostGIS `ST_DWithin` and `ST_Distance` on `technician_profiles.location` (`GIST` index) with Haversine verification.
3. **EmailJS OTP Service (`emailService.js`)**:
   - Dispatches 6-digit authentication OTPs and 4-digit booking Start/End OTPs to the user's registered email address via the EmailJS REST API (`service_noexwvl` / `template_159x4wr`).
4. **Restart Recovery (`recoverActiveDispatchSessions`)**:
   - Automatically resumes interrupted `SEARCHING` and `OFFERED` sessions on backend boot without duplicating active offers.

