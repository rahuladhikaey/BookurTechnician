# BOOKURTECHNICIAN — PHASE 6 SYSTEM ARCHITECTURE AUDIT

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Firebase Plan:** Spark (Free)  
**Audit Date:** 2026-11-08  
**Audit Scope:** Complete ecosystem forensic audit across all platforms

---

## EXECUTIVE SUMMARY

This audit examines the entire BookurTechnician ecosystem to verify end-to-end booking lifecycle integrity across Customer App, Technician App, Admin Panel, Node.js Backend, Firebase Services, and database layers.

**Critical Finding:** The system uses a **hybrid multi-database architecture** with PostgreSQL/PostGIS as the authoritative backend, Cloud Firestore as a secondary real-time sync layer, and in-memory stores for high-performance dispatch operations. This architecture is well-designed but introduces complexity in maintaining data consistency.

---

## 1. PLATFORM INVENTORY

### 1.1 Customer Flutter App
**Location:** `apps/customer_app_flutter/`

**Key Components:**
- `lib/services/firestore_rest_client.dart` - Direct Firestore REST API client with in-memory caching
- `lib/services/fcm_notification_service.dart` - FCM token registration and notification handling
- `lib/services/api_client.dart` - Backend API communication

**Database Access:**
- Primary: Cloud Firestore REST API (`https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents`)
- Secondary: Backend Node.js API endpoints
- In-memory cache with 30-second TTL for documents, 300-second TTL for categories

**Authentication:**
- Custom OTP-based challenge engine (local implementation in `firestore_rest_client.dart`)
- Stores session in device storage
- No direct Firebase Auth integration detected

**FCM Integration:**
- Registers device token via `/customer/fcm-token` endpoint
- Handles foreground/background notifications
- Notification tap routing to appropriate screens

**Status:** ✅ Operational with dual data access pattern

---

### 1.2 Technician Flutter App
**Location:** `apps/technician_app/`

**Key Components:**
- `lib/core/network/firestore_rest_client.dart` - Direct Firestore REST API client
- `lib/core/services/notification_service.dart` - FCM and socket notification handling
- `lib/core/services/location_service.dart` - GPS tracking and location updates

**Database Access:**
- Primary: Cloud Firestore REST API
- Secondary: Backend Node.js API endpoints
- In-memory cache similar to Customer App

**Authentication:**
- Custom OTP-based challenge engine (local implementation in `firestore_rest_client.dart`)
- Secure storage for technician credentials
- Role-based access control

**FCM Integration:**
- Registers device token via `/technician/fcm-token` endpoint
- Dual persistence: Firestore `technician_profiles` collection + PostgreSQL
- High-priority siren notifications for dispatch offers

**GPS/Location:**
- Continuous location tracking with background services
- Location updates persisted to Firestore and PostgreSQL
- Used for 15km radius eligibility checks

**Status:** ✅ Operational with comprehensive location tracking

---

### 1.3 React Admin Panel
**Location:** `apps/admin_panel/`

**Key Components:**
- `src/api/apiClient.js` - Multi-host auto-failover API client
- `src/api/firestoreAdapter.js` - Direct Firestore REST adapter for serverless fallback
- `src/config/firebaseConfig.js` - Firebase configuration

**Database Access:**
- Primary: Node.js Backend API (with multi-host failover)
- Secondary: Direct Cloud Firestore REST API (automatic fallback when backend unreachable)
- Tertiary: Simulated responses for development/testing

**Authentication:**
- Direct admin access via hardcoded credentials in production code:
  ```javascript
  const authRes = await this.directAdminAccess('admin@bookurtechnician.com', 'BT-ADMIN-KEY-PRIMARY-7788', 'BT-ADMIN-KEY-SECONDARY-9900');
  ```
- **CRITICAL SECURITY ISSUE:** Hardcoded admin credentials in source code (Line 107 of `apiClient.js`)

**Real-Time Features:**
- Socket.io integration for live dashboard updates
- Firestore listeners for booking status changes
- Auto-refresh with configurable intervals

**Status:** ⚠️ Operational with critical security vulnerability

---

### 1.4 Node.js Backend
**Location:** `backend/node-core-service/`

**Key Components:**
- `src/controllers/bookingController.js` - Booking creation and management
- `src/controllers/technicianController.js` - Technician profile and availability
- `src/controllers/customerController.js` - Customer operations
- `src/services/automaticDispatchEngine.js` - Core dispatch and eligibility logic
- `src/services/notificationService.js` - FCM and socket notifications
- `src/config/postgres.js` - PostgreSQL/PostGIS connection
- `src/config/redis.js` - Redis caching and OTP storage
- `src/config/firebase.js` - Firebase Admin SDK and FCM
- `src/config/firestoreSync.js` - Firestore synchronization bridge

**Database Architecture:**
1. **PostgreSQL with PostGIS** (Authoritative):
   - `bookings` table
   - `users` table (customers and technicians)
   - `technician_profiles` table
   - `dispatch_sessions` table
   - `dispatch_offers` table
   - `dispatch_requests` table
   - `dispatch_audit_logs` table
   - `technician_availability` table
   - `technician_service_skills` table
   - `technician_location_updates` table

2. **Cloud Firestore** (Secondary/Sync):
   - `bookings` collection
   - `customers` collection
   - `technician_profiles` collection
   - `services` collection
   - `service_categories` collection
   - `dispatch_offers` collection
   - `dispatch_audit_logs` collection

3. **Redis** (Caching):
   - OTP challenges
   - Failed attempt counters
   - Session data

4. **In-Memory Stores** (High-Performance):
   - `dispatchSessionsStore` - Active dispatch sessions
   - `dispatchOffersStore` - Pending and accepted offers
   - `inMemoryTechProfiles` - Technician profile cache
   - `inMemorySkills` - Technician skills cache
   - `technicianAvailabilityStore` - Availability schedules
   - `technicianSkillsStore` - Service skill mappings
   - `technicianLocationsHistory` - Location update history
   - `dispatchAuditLogsStore` - Audit trail cache
   - `activeOfferTimers` - Expiration timers
   - `bookingLocks` - Atomic mutex locks

**Authentication:**
- Firebase Auth verification via Admin SDK (when credentials available)
- OTP-based authentication with SHA-256 hashing
- Anti-automation guards with rate limiting
- PostgreSQL user records

**FCM Integration:**
- Firebase Admin SDK for push notifications
- High-priority technician siren alerts
- Multicast support for multiple devices
- Automatic token cleanup for invalid/expired tokens

**Socket.io Integration:**
- Real-time dispatch offer delivery
- Live location streaming
- Status update broadcasting
- Admin dashboard live feeds

**Status:** ✅ Comprehensive but complex architecture with multiple data layers

---

### 1.5 Firebase Configuration

**Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Plan:** Spark (Free)

**Enabled Services:**
- Cloud Firestore
- Firebase Authentication (configured but not fully utilized by Flutter apps)
- Firebase Cloud Messaging (FCM)
- Firebase Storage
- Firebase Hosting (for Admin Panel)

**Firestore Rules Status:**
- Defined in `firestore.rules`
- Covers: service catalog, user profiles, technician profiles, bookings, dispatch requests, chat, presence, audit logs
- **Missing:** `dispatch_offers` collection rules (present in backend but not defined in security rules)
- **Missing:** `dispatch_sessions` collection rules
- **Missing:** `dispatch_audit_logs` collection rules (defined but may not match backend collection name)

**Firestore Indexes Status:**
- Defined in `firestore.indexes.json`
- Covers: bookings (customer queries, technician queries, status queries)
- Covers: technician_profiles (online status, category-based queries)
- Covers: dispatch_requests (technician queries)
- **Missing:** Composite indexes for complex dispatch queries (e.g., online + category + radius)

**Status:** ⚠️ Partially configured with missing security rules and indexes

---

## 2. DATABASE CONNECTION DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                     CUSTOMER FLUTTER APP                         │
│  ┌────────────────┐    ┌────────────────┐    ┌──────────────┐ │
│  │ Firestore REST │    │   Backend API  │    │   FCM Token  │ │
│  │    Client      │◄──►│    (HTTP)      │◄──►│  Registration │ │
│  └────────────────┘    └────────────────┘    └──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
           │                      │                      │
           ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CLOUD FIRESTORE (Secondary)                    │
│  • bookings            • customers        • services            │
│  • technician_profiles • dispatch_offers  • dispatch_audit_logs │
└─────────────────────────────────────────────────────────────────┘
           │                      ▲
           │                      │
           │  Sync Bridge         │
           │                      │
           ▼                      │
┌─────────────────────────────────────────────────────────────────┐
│              NODE.JS BACKEND (Authoritative)                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          PostgreSQL with PostGIS (Primary DB)           │   │
│  │  • bookings          • users (customers/technicians)     │   │
│  │  • technician_profiles • dispatch_sessions              │   │
│  │  • dispatch_offers   • dispatch_requests                │   │
│  │  • dispatch_audit_logs • technician_availability        │   │
│  │  • technician_service_skills • technician_location_updates│   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Redis (Caching Layer)                      │   │
│  │  • OTP challenges    • Failed attempt counters           │   │
│  │  • Session data                                        │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           In-Memory Stores (High-Performance)           │   │
│  │  • dispatchSessionsStore • dispatchOffersStore          │   │
│  │  • inMemoryTechProfiles • inMemorySkills                │   │
│  │  • technicianAvailabilityStore • technicianSkillsStore   │   │
│  │  • technicianLocationsHistory • dispatchAuditLogsStore  │   │
│  │  • activeOfferTimers • bookingLocks                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              External Services                          │   │
│  │  • Firebase Admin SDK (FCM, Auth)                        │   │
│  │  • Python AI Matchmaker Service                          │   │
│  │  • Socket.io (Real-time)                                 │   │
│  │  • Google Maps API                                       │   │
│  │  • EmailJS (OTP emails)                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
           │                      │                      │
           ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TECHNICIAN FLUTTER APP                         │
│  ┌────────────────┐    ┌────────────────┐    ┌──────────────┐ │
│  │ Firestore REST │    │   Backend API  │    │   FCM Siren  │ │
│  │    Client      │◄──►│    (HTTP)      │◄──►│  Notifications│ │
│  └────────────────┘    └────────────────┘    └──────────────┘ │
│  ┌────────────────┐    ┌────────────────┐                     │
│  │  GPS Location  │    │   Socket.io    │                     │
│  │   Tracking     │◄──►│   Client       │                     │
│  └────────────────┘    └────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
           │                      │
           ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   REACT ADMIN PANEL                              │
│  ┌────────────────┐    ┌────────────────┐    ┌──────────────┐ │
│  │ Multi-Host API │    │   Firestore    │    │   Socket.io  │ │
│  │    Client      │◄──►│   Adapter      │◄──►│   Dashboard   │ │
│  └────────────────┘    └────────────────┘    └──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. DATA CONSISTENCY ANALYSIS

### 3.1 Source of Truth Determination

**Authoritative Source:** PostgreSQL with PostGIS

**Rationale:**
1. Booking records are created first in PostgreSQL via `bookingController.js`
2. Dispatch sessions and offers are tracked in PostgreSQL tables
3. Atomic locking and transaction mechanisms are implemented at PostgreSQL level
4. Audit logs are written to PostgreSQL `dispatch_audit_logs` table
5. Technician eligibility and availability are validated against PostgreSQL

**Secondary Sources:**
- **Cloud Firestore:** Used for real-time sync with Flutter apps (eventual consistency)
- **In-Memory Stores:** Used for high-performance dispatch operations (must sync to PostgreSQL)
- **Redis:** Used for temporary OTP storage and rate limiting

**Data Flow:**
```
Booking Creation → PostgreSQL (Authoritative) → Firestore Sync → Flutter Apps
                ↓
         In-Memory Dispatch Engine → PostgreSQL (Periodic Sync)
```

### 3.2 Identified Disconnected Modules

**Minor Issues:**
1. **Firebase Auth:** Configured but Flutter apps use custom OTP implementation instead
2. **Firestore Collections:** Some collections used by backend lack security rules definitions

**No Critical Disconnections Found:** All major components have defined communication paths.

### 3.3 Duplicate Data Sources

**Documented Duplicates:**
1. **Technician Profiles:**
   - PostgreSQL `technician_profiles` table
   - Firestore `technician_profiles` collection
   - In-memory `inMemoryTechProfiles` store
   - **Consistency Mechanism:** `firestoreSync.js` bridges PostgreSQL ↔ Firestore; profile updates trigger in-memory sync

2. **Bookings:**
   - PostgreSQL `bookings` table
   - Firestore `bookings` collection
   - In-memory `bookingsStore`
   - **Consistency Mechanism:** Firestore sync via `firestoreSync.js`; in-memory updated via `bookingsStore` methods

3. **Dispatch Offers:**
   - PostgreSQL `dispatch_offers` table
   - Firestore `dispatch_offers` collection
   - In-memory `dispatchOffersStore`
   - **Consistency Mechanism:** Dual-write in `automaticDispatchEngine.js`

**Assessment:** Duplicates are intentional for performance and real-time requirements. Consistency mechanisms exist but should be tested for race conditions.

---

## 4. MISSING LISTENERS

### 4.1 Firestore Real-Time Listeners

**Current State:**
- Flutter apps use REST API polling with caching (30-second TTL)
- No real-time `onSnapshot` listeners detected in Flutter code
- Admin Panel uses Socket.io for real-time updates

**Impact:**
- Flutter apps may not receive instant status updates
- Customer/Technician may see stale data until cache expires or manual refresh
- Real-time synchronization depends on Socket.io from backend

**Recommendation:** Implement Firestore real-time listeners in Flutter apps for booking status and dispatch updates.

### 4.2 Socket.io Listeners

**Current State:**
- Backend emits events to specific rooms (`tech_${techId}`, `cust_${custId}`, `booking_${bookingId}`)
- Flutter apps do not appear to have Socket.io client integration
- Only Admin Panel uses Socket.io

**Impact:**
- Technicians may not receive real-time dispatch offers via Socket.io
- Customers may not receive real-time booking updates via Socket.io
- Dependency on FCM for real-time notifications (with delivery delays)

**Recommendation:** Implement Socket.io client in Flutter apps for instant real-time communication.

---

## 5. INCORRECT DOCUMENT PATHS

**No critical incorrect document paths found.** Collections and tables are consistently named across backend, Firestore, and Flutter apps.

**Minor Discrepancy:**
- Backend uses `dispatch_audit_logs` table/collection
- Firestore rules define `audit_logs` collection
- **Resolution:** Update Firestore rules to match backend naming convention.

---

## 6. INCONSISTENT IDENTIFIERS

### 6.1 Booking IDs

**Observed Patterns:**
- Backend: UUID format (`a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
- Booking Code: `BK-123456` format (derived from booking ID)
- Flutter: Uses UUID or booking code interchangeably

**Consistency:** ✅ UUID-based booking IDs are authoritative; booking codes are human-readable aliases.

### 6.2 Technician IDs

**Observed Patterns:**
- PostgreSQL `users.id`: UUID
- PostgreSQL `technician_profiles.technician_id`: UUID
- Firestore `technician_profiles.id`: UUID
- In-memory stores: UUID

**Consistency:** ✅ Consistent UUID-based technician IDs across all systems.

---

## 7. MISSING DATABASE WRITES

**No critical missing database writes detected.** The backend implements comprehensive write operations for all key entities.

**Observation:** Some write operations include try-catch blocks that silently fail (e.g., PostgreSQL errors in `firestoreSync.js`). This is intentional for graceful degradation but may mask data sync issues.

---

## 8. STALE CACHED STATES

**Identified Stale Cache Risks:**

1. **Flutter In-Memory Cache:**
   - 30-second TTL for documents
   - 300-second TTL for categories
   - **Risk:** During active dispatch, 30-second delay may cause outdated UI
   - **Mitigation:** Manual cache invalidation on critical events

2. **In-Memory Technician Profiles:**
   - Updated via `setTechnicianProfile()` function
   - **Risk:** If profile updates occur outside this function, in-memory cache becomes stale
   - **Mitigation:** Ensure all profile updates go through centralized setter

3. **In-Memory Dispatch Stores:**
   - Reset on server restart via `recoverActiveDispatchSessions()`
   - **Risk:** Server restart during active dispatch may lose offer timers
   - **Mitigation:** Recovery mechanism implemented but should be tested

---

## 9. SILENT ERRORS

**Locations with Silent Error Handling:**

1. **Firestore Sync Errors:**
   ```javascript
   // firestoreSync.js
   try {
     await db.collection(collection).doc(cleanId).set(data, { merge: true });
     return true;
   } catch (_) {
     // Fallback to REST API below
   }
   ```
   **Risk:** Firestore sync failures may go unnoticed
   **Recommendation:** Add error logging for failed sync attempts

2. **PostgreSQL Errors in Sync:**
   ```javascript
   // automaticDispatchEngine.js
   if (postgres.isPgHealthy()) {
     try {
       await postgres.query(...);
     } catch (_) {}
   }
   ```
   **Risk:** Failed database writes may go unnoticed
   **Recommendation:** Add error logging for failed PostgreSQL writes

3. **FCM Delivery Errors:**
   - FCM errors are logged to console
   - **Risk:** Invalid tokens may not be cleaned up if logging is disabled
   **Current State:** ✅ Automatic token cleanup implemented in `notificationService.js`

---

## 10. FAKE LOCAL SUCCESS RESPONSES

**Detected Fake Success Responses:**

1. **Admin Panel Firestore Adapter:**
   ```javascript
   // firestoreAdapter.js
   if (cleanPath.includes('/auth/admin/direct-access')) {
     const token = `bt_firebase_admin_${Date.now()}`;
     return {
       success: true,
       accessToken: token,
       // ... fake user data
     };
   }
   ```
   **Risk:** Admin authentication bypassed when backend is unreachable
   **Severity:** 🔴 HIGH - Allows admin access without backend verification
   **Recommendation:** Remove fake auth response or require explicit "serverless mode" flag

2. **Firebase FCM Simulator Mode:**
   ```javascript
   // firebase.js
   if (!isFirebaseInitialized) {
     console.log(`📱 [Simulated FCM Push] -> Target: ${fcmToken.substring(0, 15)}...`);
     return { success: true, simulated: true };
   }
   ```
   **Risk:** Notifications may not actually be delivered in production
   **Severity:** 🟡 MEDIUM - Acceptable for development but should be disabled in production
   **Recommendation:** Add environment check to disable simulator in production

---

## 11. CRITICAL SECURITY VULNERABILITIES

### 11.1 Hardcoded Admin Credentials
**File:** `apps/admin_panel/src/api/apiClient.js`  
**Line:** 107  
**Issue:** Admin email and access keys hardcoded in production code  
**Severity:** 🔴 CRITICAL  
**Impact:** Anyone with source code access can gain admin privileges  
**Recommendation:** 
- Move credentials to environment variables
- Implement proper Firebase Auth token verification
- Remove hardcoded credentials immediately

### 11.2 Missing Firestore Security Rules
**Missing Rules:**
- `dispatch_offers` collection
- `dispatch_sessions` collection
- `dispatch_audit_logs` collection (rule exists but may not match backend collection name)

**Severity:** 🟡 MEDIUM  
**Impact:** Unauthorized read/write access to dispatch data via direct Firestore access  
**Recommendation:** Add comprehensive security rules for all dispatch-related collections

---

## 12. ARCHITECTURE RECOMMENDATIONS

### 12.1 High Priority
1. **Remove hardcoded admin credentials** - Move to environment variables
2. **Add missing Firestore security rules** - Protect dispatch collections
3. **Implement Firestore real-time listeners** - Replace polling in Flutter apps
4. **Add error logging for silent failures** - Improve observability

### 12.2 Medium Priority
1. **Standardize collection naming** - Align Firestore rules with backend naming
2. **Test cache invalidation** - Verify stale cache scenarios
3. **Add Firestore composite indexes** - Optimize complex queries
4. **Implement Socket.io in Flutter apps** - Reduce FCM dependency

### 12.3 Low Priority
1. **Document data flow diagrams** - Improve onboarding
2. **Add automated consistency checks** - Verify sync between databases
3. **Implement backup/restore procedures** - Disaster recovery preparedness

---

## 13. CONCLUSION

The BookurTechnician ecosystem demonstrates a sophisticated multi-database architecture designed for high-performance real-time dispatch operations. The hybrid approach using PostgreSQL (authoritative), Firestore (real-time sync), and in-memory stores (high-performance) is well-architected but introduces complexity.

**Key Strengths:**
- Comprehensive dispatch engine with atomic locking
- Multi-factor technician eligibility evaluation
- Automatic radius expansion and sequential offers
- Audit trail implementation
- Graceful degradation when backend unavailable

**Critical Issues:**
- Hardcoded admin credentials (security vulnerability)
- Missing Firestore security rules for dispatch collections
- Silent error handling may mask data sync issues
- Flutter apps rely on polling instead of real-time listeners

**Overall Assessment:** The architecture is sound but requires security hardening and improved observability before production deployment.

---

**Next Document:** Phase 6 Booking Dispatch Audit
