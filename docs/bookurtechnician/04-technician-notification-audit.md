# BOOKURTECHNICIAN — COMPLETE FORENSIC ARCHITECTURE AUDIT
## Document 04: Technician Notification, Ringtone & Alert System Audit

**Audit Date:** November 7, 2026  
**Auditor Roles:** Senior Flutter Engineer, Android Systems Specialist  
**Investigation Target:** BUG 2 — "Incoming booking ringing not working: Why technician Android devices do not play the incoming booking ringtone or show the expected incoming request interface."

---

## 1. Executive Forensic Summary: The Root Causes of BUG 2

The complete failure of the incoming booking ringtone and alert popup on technician Android devices is the result of a **four-stage failure cascade**:

```
[Trigger Stage: Direct Firestore Bypass]
  Customer booking is written to Cloud Firestore directly (Node backend offline).
  -> NO DISPATCH EVENT IS GENERATED!
  |
  v (If Backend Were Online)
[Registration Stage: FCM Token Missing in Backend/Firestore]
  Technician app attempts to sync FCM token to dead URL (api.bookurtechnician.online).
  Token is never saved to Firestore technician profile.
  Backend dispatch engine marks technician INELIGIBLE (NO_VALID_FCM_TOKEN).
  -> NO FCM PUSH IS SENT!
  |
  v (If FCM Push Were Sent)
[Routing Stage: Payload Type Mismatch in Flutter Handler]
  Backend sends payload with: type: 'DISPATCH_OFFER_NEW'
  Flutter notification handler strictly requires: type == 'NEW_JOB_ALERT' or 'TECHNICIAN_BOOKING_REQUEST'
  -> FLUTTER SILENTLY DROPS THE MESSAGE!
  |
  v (If Type Were Matched)
[OS Stage: Android 14+ Background Audio Restrictions]
  AudioAlertService attempts to play audio via audioplayers in the background without
  binding to an active FOREGROUND_SERVICE_MEDIA_PLAYBACK notification.
  -> ANDROID OS BLOCKS MEDIA PLAYBACK WHEN SCREEN IS OFF!
```

---

## 2. Component-by-Component Forensic Audit

### 2.1. Android Manifest Permissions & Configuration
Source Evidence: [`apps/technician_app/android/app/src/main/AndroidManifest.xml`](file:///d:/BookurTechnician/apps/technician_app/android/app/src/main/AndroidManifest.xml#L1-L37).

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.TURN_SCREEN_ON" />
```

- **Permission Status:** **HEALTHY**. All required high-priority call and notification permissions are correctly declared in the manifest.
- **Activity Flags:** `android:showWhenLocked="true"` and `android:turnScreenOn="true"` are present on `.MainActivity` ([line 31-32](file:///d:/BookurTechnician/apps/technician_app/android/app/src/main/AndroidManifest.xml#L31-L32)).
- **Default FCM Channel Meta-Data:**
  ```xml
  <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="job_alerts_channel" />
  ```
  Points to `job_alerts_channel`.

### 2.2. Audio Asset Verification
Source Evidence:
1. Local Flutter Asset: [`apps/technician_app/assets/sounds/incoming_job_ringtone.mp3`](file:///d:/BookurTechnician/apps/technician_app/assets/sounds/incoming_job_ringtone.mp3) (Verified present, 48 KB).
2. Android Raw Resource: [`apps/technician_app/android/app/src/main/res/raw/incoming_job_ringtone.mp3`](file:///d:/BookurTechnician/apps/technician_app/android/app/src/main/res/raw/incoming_job_ringtone.mp3) (Verified present, 48 KB).
3. `pubspec.yaml` declaration: Assets include `- assets/sounds/` ([line 42](file:///d:/BookurTechnician/apps/technician_app/pubspec.yaml#L42)).
- **Asset Status:** **HEALTHY**. The ringtone file is physically present in both the Flutter assets bundle and the native Android `res/raw/` directory.

### 2.3. The Payload Type Mismatch (The Code-Level Bug)
This is an exact code mismatch between the Node.js backend and the Flutter app:

#### The Sender (Node.js Dispatch Engine):
Source Evidence: [`backend/node-core-service/src/services/automaticDispatchEngine.js` line 1328](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L1328):
```javascript
const fcmResult = await notificationService.sendToUser(
  candidate.technicianId,
  '🚨 New Service Offer Nearby!',
  `${offer.serviceName} (${offer.distanceKm} km away) • Earn ₹${offer.expectedEarning}`,
  {
    type: 'DISPATCH_OFFER_NEW', // <-- VALUE TRANSMITTED BY BACKEND
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
```

#### The Receiver (Flutter Technician Notification Service):
Source Evidence: [`apps/technician_app/lib/core/services/notification_service.dart` lines 17-25 & 143-150](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/notification_service.dart#L17-L25):

**In Background Handler:**
```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Message received: ${message.messageId} | Data: ${message.data}');

  if (message.data['type'] == 'NEW_JOB_ALERT' ||
      message.data['type'] == 'TECHNICIAN_BOOKING_REQUEST' ||
      message.data['event'] == 'TECHNICIAN_BOOKING_REQUEST') {
    // Play loud incoming ringtone in background
    await AudioAlertService().startJobAlertRingtone();
    
    // Display local full-screen notification
    await NotificationService().showJobAlertNotification(message.data);
  }
}
```

**In Foreground Handler:**
```dart
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Received: ${message.data}');
    final data = message.data;

    if (data['type'] == 'NEW_JOB_ALERT' ||
        data['type'] == 'TECHNICIAN_BOOKING_REQUEST' ||
        data['event'] == 'TECHNICIAN_BOOKING_REQUEST') {
      showJobAlertNotification(data);
      BookingRequestManager().handleIncomingRequest(data);
    }
  }
```

- **The Proof:**  
  `message.data['type']` is `'DISPATCH_OFFER_NEW'`.
  The conditional checks ONLY for `'NEW_JOB_ALERT'` or `'TECHNICIAN_BOOKING_REQUEST'`.
  Because neither matches, **both the background and foreground handlers exit immediately without taking any action**.
  - `AudioAlertService().startJobAlertRingtone()` is **never called**.
  - `NotificationService().showJobAlertNotification()` is **never called**.
  - `BookingRequestManager().handleIncomingRequest()` is **never called**.

---

### 2.4. Android 14+ (API Level 34/35/36) Background Audio Restriction

Even when `AudioAlertService().startJobAlertRingtone()` is called in the background:
- [`AudioAlertService`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/audio_alert_service.dart#L25-L33) uses `audioplayers` with `mode: PlayerMode.mediaPlayer`.
- Starting in Android 14 (API 34), Google Play and Android OS enforce strict limits on background media playback. A background service or isolate cannot start audio playback unless:
  1. An ongoing notification with a foreground service of type `mediaPlayback` or `location` is active.
  2. The notification channel itself triggers the sound via `RawResourceAndroidNotificationSound('incoming_job_ringtone')` with `importance: Importance.max`.
- In BookurTechnician, [`NotificationService.showJobAlertNotification`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/notification_service.dart#L198) uses the native channel sound:
  ```dart
  sound: const RawResourceAndroidNotificationSound('incoming_job_ringtone')
  ```
  This is the correct approach for Android 14/15, but because `showJobAlertNotification` is never invoked due to the `type` mismatch, the notification is never posted to the Android notification manager.

---

### 2.5. Socket.IO Ringing Handler Analysis

In [`TechnicianSocketService`](file:///d:/BookurTechnician/apps/technician_app/lib/core/services/socket_service.dart#L123-L136):
```dart
_socket!.on('dispatch:offer:new', (data) {
  _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
});
_socket!.on('booking:dispatch_ringing', (data) {
  _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
});
_socket!.on('TECHNICIAN_BOOKING_REQUEST', (data) {
  _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
});
```
- In Socket.IO, the event names `'dispatch:offer:new'` and `'booking:dispatch_ringing'` **are correctly wired** to `_handleIncomingJobAlert()`, which calls `AudioAlertService().startJobAlertRingtone()` and `BookingRequestManager().handleIncomingRequest()`.
- **Why It Failed:** As proven in Document 03, the Socket.IO client connects without an auth token and is rejected by `server.js` when attempting to join the technician room. It never receives the socket message.

---

## 3. Summary of Files Requiring Modification for BUG 2

| File Path | Nature of Fix Required |
| :--- | :--- |
| `apps/technician_app/lib/core/services/notification_service.dart` | Add `'DISPATCH_OFFER_NEW'` to the accepted types in `firebaseMessagingBackgroundHandler`, `_handleForegroundMessage`, and `_handleMessageOpenedApp`. |
| `apps/technician_app/lib/core/services/notification_service.dart` | Update `syncTokenWithBackend()` to also save `fcmToken` to Cloud Firestore `technician_profiles/$techId` via `FirestoreRestClient`. |
| `apps/technician_app/lib/core/services/socket_service.dart` | Pass technician JWT token in `io.OptionBuilder().setAuth({'token': token})`. |
| `backend/node-core-service/src/services/automaticDispatchEngine.js` | Normalize FCM payload type across all dispatch paths to `'DISPATCH_OFFER_NEW'`. |
| `backend/node-core-service/src/services/automaticDispatchEngine.js` | Soften or bypass `NO_VALID_FCM_TOKEN` disqualification when Socket.IO connection is active. |

