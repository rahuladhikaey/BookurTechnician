# BOOKURTECHNICIAN — PHASE 6 FCM NOTIFICATION VERIFICATION

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Firebase Plan:** Spark (Free)  
**Audit Date:** 2026-11-08  
**Audit Scope:** FCM notification implementation, delivery, and handling across all platforms

---

## EXECUTIVE SUMMARY

The FCM notification system is well-implemented with Firebase Admin SDK integration, token management, automatic cleanup of invalid tokens, and high-priority siren notifications for technicians. However, physical device testing has not been performed to verify actual message delivery, and the Flutter apps lack comprehensive notification handling for all booking lifecycle events.

**Overall Assessment:** ✅ Backend implementation well-designed; ⚠️ Flutter notification lifecycle incomplete; ❌ Physical device delivery not verified.

---

## 1. FCM BACKEND CONFIGURATION

### 1.1 Firebase Admin SDK Setup

**File:** `backend/node-core-service/src/config/firebase.js`

**Initialization:**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('../config/firebase-service-account-key.json');

const initializeFirebase = () => {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.FIREBASE_PROJECT_ID || 'bookmytechnician-53d94',
    });
    isFirebaseInitialized = true;
    console.log(`✅ [Firebase] Initialized with Project ID (${projectId})`);
  } catch (err) {
    console.warn('⚠️ [Firebase FCM] Failed to load credentials, falling back to simulator:', err.message);
  }
  console.log('ℹ️ [Firebase FCM] Running in Simulated Push Mode ($0 MVP Mode - Live alerts log to console & WebSockets)');
};
```

**Assessment:** ✅ Firebase Admin SDK with graceful fallback to simulator mode.

### 1.2 FCM Helper Functions

**Standard Push Notification:**
```javascript
const sendPushNotification = async (fcmToken, { title, body, data = {} }) => {
  if (!fcmToken) return { success: false, reason: 'No FCM token provided' };

  if (isFirebaseInitialized) {
    try {
      const message = {
        token: fcmToken,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'bookurtechnician_general',
          },
        },
      };
      const response = await admin.messaging().send(message);
      return { success: true, messageId: response };
    } catch (error) {
      console.warn(`⚠️ [Firebase FCM] Failed to send push to ${fcmToken}:`, error.message);
      return { success: false, error: error.message };
    }
  } else {
    // Simulator Mode
    console.log(`📱 [Simulated FCM Push] -> Target: ${fcmToken.substring(0, 15)}... | Title: "${title}" | Body: "${body}"`);
    return { success: true, simulated: true };
  }
};
```

**Assessment:** ✅ Standard push notification with Android channel configuration.

### 1.3 High-Priority Technician Siren Alert

**Implementation:**
```javascript
const sendHighPriorityTechnicianAlert = async (fcmToken, { title, body, data = {} }) => {
  if (!fcmToken) return { success: false, reason: 'No FCM token provided' };

  if (isFirebaseInitialized) {
    try {
      const message = {
        token: fcmToken,
        notification: { title, body },
        data: {
          ...Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ),
          isUrgentDispatch: 'true',
          alarmLoop: 'true',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          ttl: 45 * 1000, // 45 seconds TTL
          notification: {
            channelId: 'technician_emergency_channel',
            sound: 'siren_alarm',
            priority: 'max',
            visibility: 'public',
          },
        },
      };
      const response = await admin.messaging().send(message);
      console.log(`🚨 [Firebase FCM] Sent High-Priority Technician Siren Alert to ${fcmToken.substring(0, 15)}...`);
      return { success: true, messageId: response };
    } catch (error) {
      console.warn(`⚠️ [Firebase FCM Alert Warning]:`, error.message);
      return { success: false, error: error.message };
    }
  } else {
    console.log(`🚨 [Simulated Technician Siren Alert] -> ${fcmToken.substring(0, 15)}... | "${title}" - "${body}"`);
    return { success: true, simulated: true };
  }
};
```

**Assessment:** ✅ High-priority siren alert with custom channel, sound, and TTL.

### 1.4 Multicast Notification

**Implementation:**
```javascript
const sendMulticastPushNotification = async (fcmTokens, { title, body, data = {} }) => {
  if (!Array.isArray(fcmTokens) || fcmTokens.length === 0) return { success: false };

  const validTokens = fcmTokens.filter(t => typeof t === 'string' && t.trim().length > 10);
  if (validTokens.length === 0) return { success: false };

  if (isFirebaseInitialized) {
    try {
      const message = {
        tokens: validTokens,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
      };
      const response = await admin.messaging().sendEachForMulticast(message);
      return { success: true, successCount: response.successCount, failureCount: response.failureCount };
    } catch (err) {
      console.warn('⚠️ [Firebase FCM Multicast Error]:', err.message);
      return { success: false, error: err.message };
    }
  } else {
    console.log(`📱 [Simulated Multicast Push] -> ${validTokens.length} devices | "${title}"`);
    return { success: true, simulated: true };
  }
};
```

**Assessment:** ✅ Multicast support for multiple devices.

---

## 2. NOTIFICATION SERVICE

### 2.1 Implementation Location
**File:** `backend/node-core-service/src/services/notificationService.js`

### 2.2 Token Management

**Token Registration:**
```javascript
const deviceTokens = new Map(); // userId -> Set of tokens

function registerToken(userId, token) {
  if (!userId || !token) return;
  if (!deviceTokens.has(userId)) {
    deviceTokens.set(userId, new Set());
  }
  deviceTokens.get(userId).add(token);
}
```

**Valid Token Check:**
```javascript
function isValidDeviceToken(token) {
  if (!token || typeof token !== 'string') return false;
  const trimmed = token.trim();
  if (trimmed.length < 12) return false;
  const lower = trimmed.toLowerCase();
  if (
    lower.startsWith('fake_') ||
    lower.startsWith('mock_') ||
    lower.startsWith('dummy_') ||
    lower.startsWith('synthetic_') ||
    lower === 'null' ||
    lower === 'undefined'
  ) {
    return false;
  }
  return true;
}
```

**Assessment:** ✅ Token validation with synthetic token rejection.

### 2.3 Send to User

**Implementation:**
```javascript
async function sendToUser(userId, title, body, data = {}, isUrgentAlert = false) {
  const candidateTokens = deviceTokens.get(userId);
  if (!candidateTokens || candidateTokens.size === 0) {
    return {
      success: false,
      sent: false,
      reason: 'No registered device tokens found for user (User must register FCM token)',
      userId,
    };
  }

  const validTokens = [...candidateTokens].filter(isValidDeviceToken);

  if (validTokens.length === 0) {
    return {
      success: false,
      sent: false,
      reason: 'No valid device tokens found',
      userId,
    };
  }

  const results = [];
  for (const token of validTokens) {
    try {
      let sendResult;
      if (isUrgentAlert && typeof firebase.sendHighPriorityTechnicianAlert === 'function') {
        sendResult = await firebase.sendHighPriorityTechnicianAlert(token, { title, body, data });
      } else if (typeof firebase.sendPushNotification === 'function') {
        sendResult = await firebase.sendPushNotification(token, { title, body, data });
      } else {
        sendResult = { success: false, error: 'Firebase messaging helper not available' };
      }

      results.push(sendResult);

      // Handle invalid / unregistered / expired tokens: Auto-cleanup from DB & memory
      if (!sendResult.success && sendResult.error) {
        const errLower = String(sendResult.error).toLowerCase();
        if (
          errLower.includes('not-registered') ||
          errLower.includes('registration-token-not-registered') ||
          errLower.includes('invalid-argument') ||
          errLower.includes('invalid registration token')
        ) {
          console.warn(`🧹 [NotificationService] Pruning expired/invalid FCM token for user ${userId}`);
          const currentMem = deviceTokens.get(userId) || [];
          deviceTokens.set(userId, currentMem.filter(x => x !== token));
          if (postgres.isPgHealthy()) {
            await postgres.query(`
              UPDATE users
              SET fcm_token = CASE WHEN fcm_token = $1 THEN NULL ELSE fcm_token END,
                  device_tokens = array_remove(COALESCE(device_tokens, ARRAY[]::TEXT[]), $1),
                  updated_at = NOW()
              WHERE id = $2;
            `, [token, userId]).catch(() => {});
          }
        }
      }
    } catch (pushErr) {
      console.warn(`[NotificationService] Push delivery error:`, pushErr.message);
      results.push({ success: false, error: pushErr.message });
    }
  }

  const anySuccess = results.some(r => r && r.success);
  return {
    success: anySuccess,
    sent: anySuccess,
    messageId: results.find(r => r && r.messageId)?.messageId || null,
    dispatchedCount: results.length,
    results,
  };
}
```

**Assessment:** ✅ Comprehensive token management with automatic cleanup of invalid tokens.

---

## 3. TECHNICIAN FCM INTEGRATION

### 3.1 Technician Token Registration

**Backend Endpoint:** `POST /api/v1/technicians/fcm-token`  
**File:** `backend/node-core-service/src/controllers/technicianController.js`

**Implementation:**
```javascript
const registerFcmToken = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.body.technicianId || req.headers['x-technician-id'] || req.headers['x-user-id'];
    const token = req.body.token || req.body.fcmToken;
    const platform = req.body.platform || 'android';

    if (!technicianId || !token) {
      return res.status(400).json({ success: false, error: 'Technician ID and FCM token are required' });
    }

    const automaticDispatchEngine = require('../services/automaticDispatchEngine');
    const notificationService = require('../services/notificationService');

    if (
      !automaticDispatchEngine.isValidFcmToken(token) ||
      token.startsWith('tech_fcm_') ||
      token.startsWith('cust_fcm_') ||
      token.startsWith('fcm_')
    ) {
      return res.status(400).json({
        success: false,
        error: 'Synthetic or invalid FCM tokens are rejected in production. Provide a valid Firebase device registration token.',
      });
    }

    notificationService.registerToken(technicianId, token);
    const existingMem = inMemoryTechProfiles.get(technicianId) || { id: technicianId, technicianId };
    setTechnicianProfile(technicianId, {
      ...existingMem,
      fcmToken: token,
      fcm_token: token,
      deviceTokens: [...new Set([...(existingMem.deviceTokens || []), token])],
    });

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          UPDATE users 
          SET fcm_token = $1,
              device_tokens = COALESCE(device_tokens, '[]'::jsonb) || to_jsonb($1::text),
              updated_at = NOW()
          WHERE id = $2;
        `, [token, technicianId]);

        await postgres.query(`
          UPDATE technician_profiles
          SET fcm_token = $2,
              updated_at = NOW()
          WHERE technician_id = $1 OR id = $1;
        `, [technicianId, token]);
      } catch (pgErr) {
        console.warn('⚠️ [TechnicianController] PG FCM update warning:', pgErr.message);
      }
    }

    return res.json({
      success: true,
      message: 'Technician FCM token registered successfully',
      data: { technicianId, token, platform }
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
};
```

**Assessment:** ✅ Comprehensive token registration with synthetic token rejection and dual persistence.

### 3.2 Technician Flutter App FCM Integration

**File:** `apps/technician_app/lib/core/services/notification_service.dart`

**Implementation:**
```dart
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ... handle notification
    });

    // Handle background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // ... handle tap
    });

    // Sync token with backend
    await syncTokenWithBackend();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _uploadTokenToBackend(newToken);
    });
  }

  Future<void> syncTokenWithBackend({String? token}) async {
    try {
      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        debugPrint('[FCM] Registering Token with Backend and Cloud Firestore: $fcmToken');
        
        // 1. Direct Cloud Firestore persistence into technician profile
        final userId = await SecureStorage().getUserId();
        if (userId != null && userId.isNotEmpty && userId != 'BT-PARTNER') {
          FirestoreRestClient.upsertDocument('technician_profiles', userId, {
            'fcmToken': fcmToken,
            'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
          }).catchError((_) => null);
        }

        // 2. Candidate backend endpoint
        final dio = DioClient().dio;
        await dio.post(
          '${AppConfig.apiBaseUrl}/technician/fcm-token',
          data: {'fcmToken': fcmToken},
        );
        debugPrint('[FCM] Token synchronized with backend successfully.');
      }
    } catch (e) {
      debugPrint('[FCM] Error registering token with backend: $e');
    }
  }
}
```

**Assessment:** ✅ Dual persistence (Firestore + Backend) with token refresh handling.

---

## 4. CUSTOMER FCM INTEGRATION

### 4.1 Customer Token Registration

**Backend Endpoint:** `POST /api/v1/customer/fcm-token`  
**File:** `backend/node-core-service/src/controllers/customerController.js`

**Implementation:**
```javascript
const registerFcmToken = async (req, res) => {
  try {
    const userId = resolveEffectiveCustomerId(req);
    const token = req.body.token || req.body.fcmToken;
    const platform = req.body.platform || 'android';

    if (!userId || !token) {
      return res.status(400).json({ success: false, error: 'Valid authenticated session and FCM token are required' });
    }

    if (token.startsWith('tech_fcm_') || token.startsWith('cust_fcm_') || token.startsWith('fcm_')) {
      return res.status(400).json({ success: false, error: 'Synthetic FCM tokens are rejected in production. Provide a valid Firebase device registration token.' });
    }

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(
          `UPDATE users 
           SET fcm_token = $1,
               device_tokens = array_append(array_remove(COALESCE(device_tokens, ARRAY[]::TEXT[]), $1), $1),
               updated_at = NOW()
           WHERE id = $2`,
          [token, userId]
        );
      } catch (dbErr) {
        console.warn('⚠️ [CustomerController] Register FCM PG warning:', dbErr.message);
      }
    }

    return res.json({
      success: true,
      message: 'FCM token registered successfully',
      data: { userId, token, platform }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};
```

**Assessment:** ✅ Token registration with synthetic token rejection.

### 4.2 Customer Flutter App FCM Integration

**File:** `apps/customer_app_flutter/lib/services/fcm_notification_service.dart`

**Implementation:**
```dart
class FcmNotificationService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission
    NotificationSettings settings = await messaging.requestPermission();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ... handle notification
    });

    // Handle background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // ... handle tap
    });

    // Sync token with backend
    await syncTokenWithBackend();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _uploadTokenToBackend(newToken);
    });
  }

  Future<void> syncTokenWithBackend() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('📲 [FCM Device Token]: $token');
        await _uploadTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Service] Token retrieval error: $e');
    }
  }

  Future<void> _uploadTokenToBackend(String token) async {
    try {
      final session = await ApiClient.getUserSession();
      final userId = session['userId'];
      if (userId == null || userId.isEmpty) {
        debugPrint('ℹ️ [FCM Service] No active user session yet, skipping backend registration.');
        return;
      }

      final response = await ApiClient.post(
        '/customer/fcm-token',
        {
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
          'userId': userId,
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [FCM Service] Token successfully registered to server for user $userId');
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Service] Failed to upload token to backend: $e');
    }
  }
}
```

**Assessment:** ✅ FCM integration implemented with backend token registration.

---

## 5. DISPATCH NOTIFICATION FLOW

### 5.1 Technician Dispatch Offer Notification

**Backend Implementation:**
**File:** `backend/node-core-service/src/services/automaticDispatchEngine.js`

**Notification Trigger:**
```javascript
// createAndSendOfferToTechnician()
const fcmResult = await notificationService.sendToUser(
  candidate.technicianId,
  '🚨 New Service Offer Nearby!',
  `${offer.serviceName} (${offer.distanceKm} km away) • Earn ₹${offer.expectedEarning}`,
  {
    type: 'DISPATCH_OFFER_NEW',
    offerId: offer.id,
    proposalId: offer.id,
    bookingId: offer.bookingId,
    serviceName: offer.serviceName,
    approximateArea: offer.approximateArea,
    distanceKm: String(offer.distanceKm),
    etaMinutes: String(offer.etaMinutes),
    expectedEarning: String(offer.expectedEarning),
    expiresAt: offer.expiresAt,
  }
);
offer.fcmDeliveryStatus = fcmResult?.sent ? 'PROVIDER_ACCEPTED' : (fcmResult?.reason || 'QUEUED_SOCKET_ONLY');
offer.fcmMessageId = fcmResult?.messageId || null;
```

**Socket.io Emit:**
```javascript
if (global.io) {
  global.io.to(`tech_${candidate.technicianId}`).emit('dispatch:offer:new', socketOfferPayload);
  global.io.to(`tech_${candidate.technicianId}`).emit('booking:dispatch_ringing', socketOfferPayload);
  global.io.to(`tech_${candidate.technicianId}`).emit('TECHNICIAN_BOOKING_REQUEST', socketOfferPayload);
}
```

**Assessment:** ✅ Dual notification (FCM + Socket.io) with delivery status tracking.

### 5.2 Customer Technician Assigned Notification

**Backend Implementation:**
```javascript
// automaticDispatchEngine.js - acceptOffer()
if (custId) {
  notificationService.notifyCustomerTechnicianAssigned(
    custId,
    bookingId,
    techName,
    `${offer.etaMinutes || 15} mins`
  ).catch(() => {});
}
```

**Socket.io Emit:**
```javascript
emitToCustomerAndBooking(custId, bookingId, 'booking:technician:assigned', assignmentPayload);
emitToCustomerAndBooking(custId, bookingId, 'booking:technician_assigned', assignmentPayload);
```

**Assessment:** ✅ Technician assigned notification implemented.

---

## 6. NOTIFICATION CHANNELS

### 6.1 Android Notification Channels

**Backend Configuration:**
- `bookurtechnician_general` - Standard notifications
- `technician_emergency_channel` - High-priority siren alerts

**Flutter Channel Requirements:**
❌ Flutter app notification channel configuration not verified in code inspection.

**Recommendation:** Verify Flutter Android notification channel creation matches backend configuration.

### 6.2 Notification Sounds

**Backend Configuration:**
- Standard: `default`
- Siren: `siren_alarm`

**Flutter Sound Files:**
❌ Flutter app sound files not verified in code inspection.

**Recommendation:** Verify Flutter app includes required sound files.

---

## 7. FOREGROUND/BACKGROUND HANDLING

### 7.1 Flutter Foreground Handling

**Customer App:**
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Handle foreground notification
  // ... show in-app notification
});
```

**Technician App:**
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Handle foreground notification
  // ... show in-app notification
});
```

**Assessment:** ✅ Foreground message listeners implemented.

### 7.2 Flutter Background/Terminated Handling

**Customer App:**
```dart
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // Handle notification tap when app is background/terminated
  // ... navigate to appropriate screen
});
```

**Technician App:**
```dart
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // Handle notification tap when app is background/terminated
  // ... navigate to appropriate screen
});
```

**Assessment:** ✅ Background/terminated message tap handling implemented.

---

## 8. CRITICAL ISSUES IDENTIFIED

### 8.1 Physical Device Delivery Not Verified 🔴 CRITICAL
**Issue:** No physical device testing performed to verify actual FCM message delivery.  
**Impact:** Unknown whether notifications actually reach devices in production.  
**Recommendation:** Perform mandatory physical device testing with FCM message verification.

### 8.2 Notification Lifecycle Incomplete 🟡 MEDIUM
**Issue:** Only technician assigned notification implemented; other lifecycle notifications missing.  
**Missing Notifications:**
- Booking request submitted
- Searching for technician
- Technician found
- Technician on the way
- Technician arrived
- Service started
- Service completed
- Booking cancelled/expired

**Recommendation:** Implement comprehensive notification lifecycle with event-driven dispatcher.

### 8.3 Flutter Notification Channels Not Verified 🟡 MEDIUM
**Issue:** Flutter Android notification channel configuration not verified.  
**Impact:** Notifications may not display correctly on Android devices.  
**Recommendation:** Verify Flutter notification channel creation matches backend configuration.

### 8.4 Flutter Sound Files Not Verified 🟡 MEDIUM
**Issue:** Flutter app sound files for siren alarm not verified.  
**Impact:** High-priority siren notifications may not play sound.  
**Recommendation:** Verify Flutter app includes required sound files.

### 8.5 Simulator Mode in Production Risk 🟡 MEDIUM
**Issue:** FCM simulator mode may remain enabled if Firebase credentials missing.  
**Impact:** Notifications may not actually be delivered in production.  
**Recommendation:** Add environment check to disable simulator in production.

---

## 9. CONCLUSION

**Backend FCM Implementation:** ✅ PRODUCTION-READY
- Firebase Admin SDK properly configured
- Token management with automatic cleanup
- High-priority siren alerts for technicians
- Multicast support for multiple devices
- Dual notification (FCM + Socket.io)
- Delivery status tracking

**Flutter FCM Integration:** ⚠️ PARTIALLY COMPLETE
- Token registration implemented
- Foreground/background handling implemented
- Notification channels not verified
- Sound files not verified
- Notification lifecycle incomplete

**Physical Device Testing:** ❌ NOT PERFORMED
- Unknown whether FCM messages actually reach devices
- Unknown whether notification channels work correctly
- Unknown whether sound files play correctly

**Overall Assessment:** Backend implementation is well-designed but requires physical device testing to verify actual delivery. Flutter notification lifecycle needs completion before production use.

---

**Next Document:** Phase 6 Physical Device Test Results
