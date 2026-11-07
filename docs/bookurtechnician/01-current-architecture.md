# BOOKURTECHNICIAN — COMPLETE FORENSIC ARCHITECTURE AUDIT
## Document 01: Current System Architecture & Runtime Discovery

**Audit Date:** November 7, 2026  
**Auditor Roles:** Principal Software Architect, Firebase Architect, Flutter/Android Lead, Backend Security Auditor  
**Project:** BookurTechnician (On-Demand Electrical & Home Services Marketplace)  
**Target Ecosystem:**
1. Customer App — Flutter (Android, `com.booktechnician.customer`)
2. Technician App — Flutter (Android, `com.booktechnician.technician`)
3. Admin Panel — React + Vite (`apps/admin_panel`)
4. Core API & Dispatch Service — Node.js Express (`backend/node-core-service`)
5. AI Matchmaking Service — Python FastAPI (`backend/python-ai-service`)
6. Primary Cloud Database — Google Cloud Firestore (`bookmytechnician-53d94`)
7. Secondary Storage & Services — PostgreSQL / PostGIS, Redis, Kafka, Firebase FCM, Razorpay

---

## 1. Executive Summary: The "Dual-Reality" Architectural State

The forensic audit reveals a critical fundamental reality: **BookurTechnician currently operates in two completely divergent architectural states:**

1. **The Intended Architecture (Designed in Code):**  
   A microservice/monolith hybrid comprising a Node.js Core API Gateway (Express 4, Socket.IO 4, PostgreSQL with PostGIS spatial scanning, Redis spatial caches, and Kafka event buses) paired with a Python AI Matchmaker service.
2. **The Actual Runtime Architecture (In the Wild):**  
   Because the production domain `https://api.bookurtechnician.online` does not resolve in DNS (`Name resolution failed`), and the fallback Render hosting (`bookurtechnician-backend.onrender.com`) returns HTTP 404 Not Found, **both Flutter apps and the React Admin Panel have automatically failed over to an unauthenticated, direct HTTP REST client layer communicating directly with Google Cloud Firestore (`https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents`)**.

```
                           [DUAL-REALITY ARCHITECTURE]

                     +---------------------------------------+
                     |    Customer App (Flutter Android)     |
                     +---------------------------------------+
                                    |
            +-----------------------+-----------------------+
            | (Primary Target)                              | (Automatic Fallback)
            v                                               v
+-------------------------------+               +-------------------------------+
|  api.bookurtechnician.online  |               |    Cloud Firestore REST API   |
|   (DNS Fails / Offline)       |               | (bookmytechnician-53d94)     |
+-------------------------------+               +-------------------------------+
            |                                               |
            x [DEAD END]                                    | Direct HTTP PATCH/GET
                                                            v
+-------------------------------+               +-------------------------------+
|   Node.js Core API Gateway    |               |   Firestore 'bookings' &      |
|  - automaticDispatchEngine    |               |   'technician_profiles'       |
|  - Socket.IO Server           |               +-------------------------------+
|  - FCM Push Trigger           |                               |
+-------------------------------+                               | Reads via REST
                                                                v
+-------------------------------+               +-------------------------------+
|  Technician App (Socket/FCM)  | <----[GAP]----+   Admin Panel (React Website) |
|   NEVER RECEIVES BOOKING!     |  No triggers  |  Sees booking in Firestore!   |
+-------------------------------+  or functions +-------------------------------+
```

---

## 2. Repository Component Inventory

| Component | Codebase Location | Primary Technology | Package ID / Name | Deployment Status |
| :--- | :--- | :--- | :--- | :--- |
| **Customer App** | `apps/customer_app_flutter` | Flutter 3.x / Dart / Riverpod | `com.booktechnician.customer` | Built Release APK (`v1.0.1+2`, 75.4 MB) |
| **Technician App** | `apps/technician_app` | Flutter 3.x / Dart / Riverpod | `com.booktechnician.technician` | Built Release APK (`v1.0.1+2`, 62.5 MB) |
| **Admin Panel** | `apps/admin_panel` | React 18, Vite 4, Tailwind/CSS | `admin_panel` | Firebase Hosting + Node Static (`dist/`) |
| **Core API Gateway** | `backend/node-core-service` | Node.js 18+, Express, Socket.IO | `bookurtechnician-core-service` | Configured for Render in `render.yaml` (currently offline) |
| **AI Matchmaker** | `backend/python-ai-service` | Python 3.11, FastAPI, Uvicorn | `bookurtechnician-ai-service` | Local microservice (`Dockerfile` present) |
| **Cloud Firestore** | Cloud Project | Google Cloud Firestore (Native) | `bookmytechnician-53d94` | **Active & Live** in `asia-south1` |
| **Relational DB** | Cloud / Local | PostgreSQL 15 + PostGIS | `bookurtechnician-db` | Render Postgres (expired/offline) |
| **In-Memory Cache** | Cloud / Local | Redis (ioredis) | Redis Cache | Fallback to in-memory Maps |

---

## 3. Detailed Component Deep-Dive

### 3.1. Customer Flutter App (`apps/customer_app_flutter`)
- **Application ID:** `com.booktechnician.customer` ([build.gradle.kts](file:///d:/BookurTechnician/apps/customer_app_flutter/android/app/build.gradle.kts#L28))
- **Compile SDK:** 36 | **Target SDK:** 35 | **Min SDK:** 21
- **State Management:** `flutter_riverpod: ^2.6.1` ([pubspec.yaml](file:///d:/BookurTechnician/apps/customer_app_flutter/pubspec.yaml#L37))
- **Firebase Packages:**
  - `firebase_core: ^3.0.0`
  - `firebase_messaging: ^15.0.0`
  - **Noticeably Absent:** `cloud_firestore` is **not installed**. `firebase_auth` is **not installed**. `firebase_storage` is **not installed**.
- **Network Architecture:**
  - Central client: [`ApiClient`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/api_client.dart#L16).
  - Maintains candidate base URLs:
    1. `https://api.bookurtechnician.online/api/v1` (DNS unresolvable)
    2. `https://bookurtechnician.onrender.com/api/v1` (HTTP 404)
    3. `https://bookurtechnician-backend.onrender.com/api/v1` (HTTP 404)
    4. `http://192.168.1.3:4000/api/v1` (Local dev network)
  - **Fallback Mechanism:** Every HTTP verb (`get`, `post`, `put`, `delete`) catches candidate failure and delegates to [`FirestoreRestClient`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L8).
- **Socket Client:**
  - Connects to `AppConfig.socketUrl` in [`booking_provider.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/booking_provider.dart#L244-L260).
  - Listens for `notification:new_service`, `catalog:updated`, `availability:updated`, `technician:status_changed`.

### 3.2. Technician Flutter App (`apps/technician_app`)
- **Application ID:** `com.booktechnician.technician` ([build.gradle.kts](file:///d:/BookurTechnician/apps/technician_app/android/app/build.gradle.kts#L28))
- **Compile SDK:** 36 | **Target SDK:** 35 | **Min SDK:** 21
- **State Management:** `flutter_riverpod: ^2.6.1`
- **Firebase Packages:**
  - `firebase_core: ^3.0.0`
  - `firebase_messaging: ^15.0.0`
  - **Noticeably Absent:** `cloud_firestore`, `firebase_auth`, `firebase_storage` are **not installed**.
- **Real-Time Notification & Ringing Stack:**
  - [`TechnicianSocketService`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/socket_service.dart#L9): Socket.IO client configured to listen for `dispatch:offer:new`, `booking:dispatch_ringing`, `TECHNICIAN_BOOKING_REQUEST`, `booking:assigned`.
  - [`AudioAlertService`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/audio_alert_service.dart#L8): Looping playback of `sounds/incoming_job_ringtone.mp3` with heavy haptic vibration.
  - [`BookingRequestManager`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/booking_request_manager.dart#L76): Coordinates display of `IncomingJobAlertOverlay` with countdown timer.
  - [`NotificationService`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/notification_service.dart#L28): Firebase Messaging background and foreground message handling.

### 3.3. React Admin Panel (`apps/admin_panel`)
- **Framework:** React 18.2.0, Vite 4.4.5 ([package.json](file:///d:/BookurTechnician/apps/admin_panel/package.json#L10-L17))
- **Firebase Packages:** **Zero npm packages**. `firebase` is not in `package.json`.
- **API Client:** [`apiClient.js`](file:///d:/BookurTechnician/apps/admin_panel/src/api/apiClient.js#L16).
  - Candidate URLs: `VITE_API_BASE_URL` (`https://bookurtechnician-backend.onrender.com/api/v1`), `http://localhost:4000/api/v1`.
  - Automatic Fallback: [`handleFirestoreFallback()`](file:///d:/BookurTechnician/apps/admin_panel/src/api/firestoreAdapter.js#L82) translates CRUD endpoints (`/bookings`, `/technicians`, `/catalog`, `/customers`) directly into Google Cloud Firestore REST API calls.
- **Hosting:** Configured in [`firebase.json`](file:///d:/BookurTechnician/firebase.json#L8-L21) pointing to `apps/admin_panel/dist`.

### 3.4. Node.js Core Backend Service (`backend/node-core-service`)
- **Framework:** Node.js, Express 4.19, Socket.IO 4.7.5 ([package.json](file:///d:/BookurTechnician/backend/node-core-service/package.json#L24-L58))
- **Entry Point:** [`src/server.js`](file:///d:/BookurTechnician/backend/node-core-service/src/server.js#L1)
- **Key Modules:**
  - `src/controllers/bookingController.js`: Full lifecycle booking creation, pricing, OTP generation, and double-booking verification.
  - `src/services/automaticDispatchEngine.js`: Uber/Rapido-style sequential dispatch engine with 3km -> 5km -> 10km -> 15km expanding radius, 20s timeouts, multi-factor ranking (ETA, skills, rating, reliability).
  - `src/services/postgresSpatialScanner.js`: Dual-tier spatial scanner using PostGIS `ST_DWithin` and fallback Haversine SQL.
  - `src/config/inMemoryTechStore.js`: In-memory partner profile cache hydrated from Cloud Firestore on boot.
  - `src/config/bookingsStore.js`: In-memory booking cache with Firestore sync.

---

## 4. Connection & Communication Matrix

| Source | Destination | Protocol / Channel | Purpose | Live Status |
| :--- | :--- | :--- | :--- | :--- |
| **Customer App** | Node.js Gateway | HTTP REST (`/api/v1/bookings`) | Create bookings, auth, catalog | ❌ DNS Failure (`api.bookurtechnician.online`) |
| **Customer App** | Node.js Gateway | WebSocket (`ws://` / `wss://`) | Realtime tracking & catalog updates | ❌ Connection Timeout |
| **Customer App** | Cloud Firestore | HTTPS REST (`/v1/projects/...`) | Direct fallback for catalog & bookings | 🟢 **ACTIVE & LIVE** |
| **Technician App**| Node.js Gateway | HTTP REST (`/api/v1/technicians`)| Login, KYC, toggle duty, accept job | ❌ DNS Failure |
| **Technician App**| Node.js Gateway | WebSocket (Socket.IO) | Receive incoming booking ringing | ❌ Connection Timeout |
| **Technician App**| Cloud Firestore | HTTPS REST (`/v1/projects/...`) | Direct fallback for profile & skills | 🟢 **ACTIVE & LIVE** |
| **Technician App**| Firebase FCM | Native Push / Background Service| Receive background job alerts | ⚠️ Tokens not synced |
| **Admin Panel** | Node.js Gateway | HTTP REST (`/api/v1/admin`) | Dashboard, dispatch control tower | ❌ 404 Not Found on Render |
| **Admin Panel** | Cloud Firestore | HTTPS REST (`/v1/projects/...`) | Direct fallback to view bookings/techs| 🟢 **ACTIVE & LIVE** |
| **Node.js Gateway**| Python AI Service| HTTP REST (`:8000/api/v1/ai/match`)| Machine-learning candidate ranking | ⚠️ Standalone Fallback |
| **Node.js Gateway**| PostgreSQL/PostGIS| TCP Port 5432 (`pg`) | Authoritative persistence & spatial | ⚠️ Standalone Fallback |
| **Node.js Gateway**| Redis | TCP Port 6379 (`ioredis`) | Live GPS geospatial indexing & locks | ⚠️ Standalone Fallback |
| **Node.js Gateway**| Cloud Firestore | HTTPS REST (`googleapis.com`) | Bidirectional document hydration | 🟢 **ACTIVE & LIVE** |

---

## 5. Architectural Findings Summary

1. **The Codebase Has Massive Built-In Resilience:**  
   Because both Flutter applications and the React Admin Panel contain sophisticated REST fallback clients ([`firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L164), [`firestoreAdapter.js`](file:///d:/BookurTechnician/apps/admin_panel/src/api/firestoreAdapter.js#L82)), the user interface never crashes when the Node.js backend is offline.
2. **The Fallback Creates an Asymmetric Communication Black Hole:**  
   When a customer books a service, the booking is written directly to Cloud Firestore. The Admin Panel reads Cloud Firestore, so the Admin sees the booking immediately. **However, Cloud Firestore has no trigger mechanism (Cloud Function or webhook) to notify the Technician App.**
3. **The Technician App is purely reactive to Socket.IO and FCM:**  
   The Technician App does not poll Cloud Firestore for new bookings (nor does it have a snapshot listener). It sits waiting for a Socket.IO event or an FCM push notification—neither of which is ever sent by Cloud Firestore.

