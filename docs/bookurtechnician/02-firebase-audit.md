# BOOKURTECHNICIAN — COMPLETE FORENSIC ARCHITECTURE AUDIT
## Document 02: Comprehensive Firebase Infrastructure & Security Rules Audit

**Audit Date:** November 7, 2026  
**Auditor Roles:** Principal Firebase Architect, Cloud Security Lead  
**Project:** BookurTechnician  
**Firebase Project ID:** `bookmytechnician-53d94`  
**Project Number:** `946427465815`  
**Default Storage Bucket:** `bookmytechnician-53d94.firebasestorage.app`  
**Primary Region:** `asia-south1` (Mumbai)

---

## 1. Firebase Service Integration Matrix

| Firebase Service | Configured in Repo? | Deployed in Cloud? | Used by Mobile Apps? | Used by Admin Web? | Used by Node.js Backend? | Overall Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Firestore Database** | Yes (`firestore.rules`) | Yes (`asia-south1`) | Yes (via raw REST) | Yes (via raw REST) | Yes (via REST Sync) | ⚠️ Partially Integrated (REST Only, No SDKs) |
| **Firebase Auth** | Partially | Yes (Console) | No (Custom OTP) | No (Custom Admin) | Yes (`firebase-admin` token verify) | ⚠️ Misaligned / Bypassed |
| **Firebase Cloud Messaging** | Yes (`pubspec.yaml`) | Yes (FCM API v1) | Yes (`firebase_messaging`) | No | Yes (`notificationService.js`) | ⚠️ Broken token delivery pipeline |
| **Firebase Storage** | Yes (`storage.rules`) | Yes (Default Bucket) | No (Uses Cloudinary) | No | No | ⚠️ Configured but Unused |
| **Cloud Functions** | **NO** | **NO** | N/A | N/A | N/A | ❌ **COMPLETELY MISSING (ZERO CODE)** |
| **Realtime Database** | No (Only XML whitelist) | Unknown | No | No | No | ❌ Not Configured / Unused |
| **Firebase Hosting** | Yes (`firebase.json`) | Yes (`dist/`) | N/A | Yes (Target) | No | 🟢 Operational |
| **Firebase App Check** | No | No | No | No | No | ❌ Not Implemented |

---

## 2. Client Application Registrations

Source Evidence: [`apps/customer_app_flutter/android/app/google-services.json`](file:///d:/BookurTechnician/apps/customer_app_flutter/android/app/google-services.json#L7-L46) & [`apps/admin_panel/src/config/firebaseConfig.js`](file:///d:/BookurTechnician/apps/admin_panel/src/config/firebaseConfig.js#L6-L14).

### 2.1. Android Customer App
- **Package Name:** `com.booktechnician.customer`
- **Mobile SDK App ID:** `1:946427465815:android:2fc570b9e9e9108a54d312`
- **Current API Key:** `AIzaSyAhCvnUH_jA5bAhlGlIy3eX2lnM43gFRdE`
- **OAuth Clients:** `[]` (Empty in `google-services.json`)
- **Signing Fingerprints:**
  - **SHA-1:** `9D:8D:1E:EF:8E:8B:21:6A:90:C2:CC:D5:B3:A5:ED:77:97:17:88:D8`
  - **SHA-256:** `4D:50:BF:57:77:3A:E3:88:1F:02:31:E2:1E:7F:CF:E3:C5:A1:EB:FE:89:EC:11:5F:5C:CB:D6:E3:30:40:54:4B`

### 2.2. Android Technician App
- **Package Name:** `com.booktechnician.technician`
- **Mobile SDK App ID:** `1:946427465815:android:9f46258e7601915a54d312`
- **Current API Key:** `AIzaSyAhCvnUH_jA5bAhlGlIy3eX2lnM43gFRdE`
- **OAuth Clients:** `[]` (Empty in `google-services.json`)
- **Signing Fingerprints:** Identical debug signing certificate used for local release builds.

### 2.3. Web Admin Panel
- **App ID:** `1:946427465815:web:bbba98f19895c72954d312`
- **API Key:** `AIzaSyD6zQmBF70DLE8whxCRTBFPhn3ZgA_4TzE`
- **Auth Domain:** `bookmytechnician-53d94.firebaseapp.com`
- **Measurement ID:** `G-EM6DPCMMS1`

---

## 3. The Firebase SDK vs. REST Client Architecture Flaw

A primary architectural anomaly in BookurTechnician is the **complete absence of native Firebase Database and Authentication SDKs**:

1. **Neither Flutter application includes `cloud_firestore`:**
   In [`apps/customer_app_flutter/pubspec.yaml`](file:///d:/BookurTechnician/apps/customer_app_flutter/pubspec.yaml#L49-L50) and [`apps/technician_app/pubspec.yaml`](file:///d:/BookurTechnician/apps/technician_app/pubspec.yaml#L25-L26), only `firebase_core` and `firebase_messaging` are imported.
2. **Neither Flutter application includes `firebase_auth`:**
   User sessions and OTPs are verified via custom backend endpoints or direct EmailJS/Brevo email triggers.
3. **The React Admin Panel includes zero Firebase npm libraries:**
   [`apps/admin_panel/package.json`](file:///d:/BookurTechnician/apps/admin_panel/package.json#L10-L13) contains only `react` and `react-dom`.
4. **How Firestore is Actually Accessed:**
   The entire system communicates with Firestore using raw HTTP `fetch` or Dart `http.post`/`http.patch` to Google's public REST endpoint:
   `https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents/{collection}/{docId}`

### Architectural Consequences of REST-only Access:
- **No Realtime Snapshot Streams:** Mobile apps cannot use `.snapshots()` to listen for changes. When a customer creates a booking in Firestore, the technician app has no snapshot listener to react to it.
- **No Offline Persistence Cache:** Standard Firebase SDKs maintain an IndexedDB/SQLite local offline cache with optimistic UI updates. The custom REST clients fail when offline.
- **Authentication Token Desynchronization:** Because clients do not sign in via Firebase Auth SDK, they do not carry Firebase ID tokens (`request.auth == null`) when sending REST requests to Firestore.

---

## 4. Firestore Security Rules Audit

Source Evidence: [`firestore.rules`](file:///d:/BookurTechnician/firestore.rules#L1-L101).

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    
    function isAdmin() {
      return isAuthenticated() && (
        request.auth.token.role == 'ADMIN' || 
        request.auth.token.role == 'SUPER_ADMIN' ||
        request.auth.token.admin == true
      );
    }
    ...
```

### Critical Vulnerabilities in Existing Rules:

#### Vulnerability 1: Public Read Access on All Technician Profiles
- **Location:** [`firestore.rules` line 50](file:///d:/BookurTechnician/firestore.rules#L50):
  ```javascript
  match /technician_profiles/{techId} {
    allow read: if isAuthenticated() || true; // <-- CATASTROPHIC FLAW
    allow write: if isOwner(techId) || isAdmin();
  }
  ```
- **Severity:** **HIGH**
- **Evidence:** The rule explicitly appends `|| true`. Any unauthenticated actor on the internet can dump every technician profile in the system via a simple HTTP GET to `https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents/technician_profiles`.
- **Exposed Data:** Full legal names, mobile phone numbers, GPS coordinates, earnings, and verification status.

#### Vulnerability 2: Booking Creation Requires Firebase Auth, But Clients Are Unauthenticated
- **Location:** [`firestore.rules` lines 62-67](file:///d:/BookurTechnician/firestore.rules#L62-L67):
  ```javascript
  match /bookings/{bookingId} {
    allow create: if isAuthenticated() && request.resource.data.customerId == request.auth.uid;
    ...
  }
  ```
- **Severity:** **CRITICAL ARCHITECTURAL CONFLICT**
- **Evidence:** The rules enforce that `request.auth != null` and `request.resource.data.customerId == request.auth.uid`. However, the Flutter Customer App does NOT authenticate with Firebase Auth. Its REST client sends unauthenticated HTTP PATCH requests (`request.auth == null`).
- **Impact:** If Firebase Security Rules are deployed and enforced in production, the Customer App's fallback booking creation **will immediately fail with HTTP 403 PERMISSION_DENIED**.

---

## 5. Firebase Cloud Functions Audit

### Findings:
1. **Directory Inspection:** The repository contains **no `functions` folder**.
2. **`firebase.json` Inspection:** [`firebase.json`](file:///d:/BookurTechnician/firebase.json#L1-L37) declares configurations for `firestore`, `storage`, `hosting`, and `emulators`, but **no `functions` configuration block**.
3. **Impact on On-Demand Dispatch:**
   In an on-demand platform like Uber or Urban Company, when a customer creates a booking, a backend trigger must immediately wake up candidate technicians. Because **zero Cloud Functions exist**, creating a booking in Firestore is a silent write: no background worker, no event emitter, and no dispatch worker is ever executed.

---

## 6. Firebase Cloud Messaging (FCM) Audit

### Findings:
1. **SDK Setup in Flutter:**
   - Both Flutter apps correctly register [`FirebaseMessaging.instance`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/notification_service.dart#L33) and request notification permissions (`POST_NOTIFICATIONS`).
   - Android channels are registered: `job_alerts_channel` with custom sound `incoming_job_ringtone`.
2. **Token Synchronization Failure:**
   - In [`notification_service.dart` lines 121-135](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/notification_service.dart#L121-L135), when the app acquires an FCM token, it calls:
     ```dart
     await dio.post('${AppConfig.apiBaseUrl}/technician/fcm-token', data: {'fcmToken': fcmToken});
     ```
   - Because `${AppConfig.apiBaseUrl}` (`https://api.bookurtechnician.online`) is unresolvable in DNS, **this HTTP POST always fails with a network exception**.
   - The token is **never written to Cloud Firestore** under `technician_profiles/$techId`.
   - Consequently, when the Node.js dispatch engine evaluates technician eligibility ([`automaticDispatchEngine.js` line 720](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L720)), `getTechnicianValidFcmTokens(techProfile)` returns `[]`, and the technician is disqualified with `NO_VALID_FCM_TOKEN`.
3. **Payload Type Disconnect:**
   - Node.js backend sends FCM payload with: `data: { type: 'DISPATCH_OFFER_NEW' }` ([line 1328](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L1328)).
   - Flutter background handler checks:
     `if (message.data['type'] == 'NEW_JOB_ALERT' || message.data['type'] == 'TECHNICIAN_BOOKING_REQUEST')` ([line 17](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/notification_service.dart#L17)).
   - Because `'DISPATCH_OFFER_NEW'` is not matched, the technician app **drops the message silently without playing any sound or showing any alert**.

