# BOOKURTECHNICIAN — PHASE 6.1
# NOTIFICATION LIFECYCLE & FCM TOKEN MANAGEMENT REPORT

**Project:** BookurTechnician  
**Classification:** Cloud Messaging & Real-Time Push Orchestration  
**Status:** IMPLEMENTED & AUDITED  

---

## 1. Overview & Notification Architecture

BookurTechnician employs a dual-channel notification strategy:
1. **High-Priority FCM (Firebase Cloud Messaging):** Awakens backgrounded or terminated mobile devices for critical job requests and safety OTP updates.
2. **WebSocket (Socket.io) In-App Broadcasts:** Provides instant zero-latency UI state updates when the application is active in the foreground.

In Phase 6.1, `backend/node-core-service/src/services/notificationService.js` was enhanced with all 13 required lifecycle notification triggers, automated FCM token pruning, and rapid-fire offer deduplication.

---

## 2. Technician Event Notifications (5 Triggers)

| Event Method | Payload & Sound Channel | Recipient Trigger | UI/System Behavior |
|---|---|---|---|
| **`notifyTechnicianNewRequest`** | Sound: `alarm_alert.mp3`<br>Priority: `high`<br>Channel: `dispatch_offers` | Sent when an automated dispatch offer is issued to the ranked technician. | Displays full-screen job card with 20-second countdown, customer distance, service price, and Accept/Reject buttons. |
| **`notifyTechnicianAcceptedElsewhere`** | Priority: `normal`<br>Silent data push | Sent to losing candidate technicians when a competing technician accepts. | Silently dismisses the active offer sheet without alerting sound, returning technician to available status. |
| **`notifyTechnicianOfferExpired`** | Sound: `default`<br>Priority: `normal` | Sent when 20-second offer timeout expires without technician response. | Dismisses offer sheet, records timeout in reliability metrics, advances engine to next candidate. |
| **`notifyTechnicianBookingCancelled`** | Sound: `default`<br>Priority: `high` | Sent if customer cancels while technician is en-route or arrived. | Halts navigation, alerts technician, and releases technician availability back to `AVAILABLE`. |
| **`notifyTechnicianBookingUpdate`** | Sound: `default`<br>Priority: `normal` | Sent when customer address details or notes are updated. | Updates booking details screen reactively. |

---

## 3. Customer Event Notifications (8 Triggers)

| Event Method | Title & Body Template | Trigger Condition |
|---|---|---|
| **`notifyCustomerBookingSubmitted`** | *"Booking Searching: Searching for the best technician near you..."* | Initial booking request submitted and enters `SEARCHING` dispatch queue. |
| **`notifyCustomerTechnicianAssigned`** | *"Technician Found: {name} ({rating}★) has been assigned to your service!"* | Sequential dispatch engine locks technician and transitions booking to `ASSIGNED`. |
| **`notifyCustomerTechnicianAccepted`** | *"Booking Confirmed: {name} has accepted your request and is preparing."* | Technician confirms job acceptance on their device. |
| **`notifyCustomerTechnicianEnRoute`** | *"Technician On The Way: {name} is en route. Estimated arrival in {eta} mins."* | Technician taps "Start Navigation" / "On The Way". |
| **`notifyCustomerTechnicianArrived`** | *"Technician Arrived: {name} has reached your location. Share Start OTP: {startOtp}."* | Technician arrives at customer GPS geofence. |
| **`notifyCustomerServiceStarted`** | *"Service Started: Your electrical service has begun. Track progress in app."* | Technician enters valid 4-digit Start OTP provided by customer. |
| **`notifyCustomerServiceCompleted`** | *"Service Completed: Work finished! Please verify completion and pay {amount}."* | Technician enters valid End OTP provided by customer. |
| **`notifyCustomerBookingCancelledOrExpired`** | *"Booking Update: {reason}"* | Booking cancelled by customer or timed out due to no available technicians. |

---

## 4. Alert Deduplication Mechanism

To prevent push notification storms when multiple server retries occur or network packets duplicate, `notificationService.js` enforces an in-memory alert deduplication cache:

```javascript
const sentOfferNotificationsDedup = new Map(); // offerId -> timestamp

async function sendToUser(userId, payload) {
  const offerId = payload.data?.offerId;
  if (offerId) {
    const lastSent = sentOfferNotificationsDedup.get(offerId);
    if (lastSent && Date.now() - lastSent < 10000) {
      console.log(`ℹ️ [Push Notification] Suppressed duplicate offer alert for offerId: ${offerId}`);
      return { success: true, deduplicated: true };
    }
    sentOfferNotificationsDedup.set(offerId, Date.now());
  }
  ...
}
```

**Verification:** In test `NOTIF-01` (`test_phase_6_1_suite.js`), identical rapid calls with the same `offerId` were successfully intercepted and flagged with `deduplicated: true`.

---

## 5. FCM Token Registration & Pruning Protocol

1. **Token Registration:** Clients register their current FCM device token on login and app open via `POST /api/users/fcm-token` or `POST /api/technicians/fcm-token`.
2. **Invalid Token Detection:** When sending via Firebase Admin SDK `messaging().send()`, the service catches error codes:
   - `messaging/registration-token-not-registered`
   - `messaging/invalid-registration-token`
3. **Automated Pruning:** Invalid tokens are instantly expunged from the PostgreSQL user/technician record and the in-memory cache to prevent subsequent delivery failures and eliminate unnecessary quota consumption.

