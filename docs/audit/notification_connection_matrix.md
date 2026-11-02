# Notification Connection Matrix & Event Dispatch Guide
**Authoritative Push Engine:** `notificationService.js` + `firebase.js`  
**Realtime Foreground Bus:** Socket.io (Room-Scoped)

---

## 1. Notification Event Lifecycle

| Trigger Event | Target Recipient | Channel | Android Notification Channel | Sound / Priority | Payload / Data Keys |
|---|---|---|---|---|---|
| **New Job Broadcast** | Nearby Technicians (<= 15km) | FCM + Socket.io | `technician_emergency_channel` | `siren_alarm` (MAX priority, loop) | `{ type: 'NEW_JOB_ALERT', bookingId, amount, customerName, distanceKm, isUrgentDispatch: 'true' }` |
| **Technician Assigned** | Customer | FCM + Socket.io | `bookurtechnician_general` | Default (High priority) | `{ type: 'TECHNICIAN_ASSIGNED', bookingId, technicianName, startOtp, status: 'ACCEPTED' }` |
| **Technician Arrived** | Customer | FCM + Socket.io | `bookurtechnician_general` | Default (High priority) | `{ type: 'TECHNICIAN_ARRIVED', bookingId, status: 'ARRIVED' }` |
| **Service Started (OTP Verified)** | Customer | FCM + Socket.io | `bookurtechnician_general` | Default (High priority) | `{ type: 'SERVICE_STARTED', bookingId, endOtp, status: 'IN_PROGRESS' }` |
| **Completion OTP Resend** | Customer | FCM + Socket.io | `bookurtechnician_general` | Default (High priority) | `{ type: 'END_OTP', bookingId, endOtp }` |
| **Job Completed** | Customer | FCM + Socket.io | `bookurtechnician_general` | Default (High priority) | `{ type: 'JOB_COMPLETED', bookingId, status: 'COMPLETED' }` |
| **In-App P2P Chat Message** | Receiver (Customer or Tech) | FCM + Socket.io | `bookurtechnician_chat` | Subtle tone (High priority) | `{ type: 'CHAT_MESSAGE', bookingId, messageId }` |
| **Booking Cancelled** | Affected Counterparty | FCM + Socket.io | `bookurtechnician_general` | Default (High priority) | `{ type: 'BOOKING_CANCELLED', bookingId, status: 'CANCELLED', refundId }` |
| **Payment Captured** | Customer | Socket.io | N/A (Foreground) | Foreground UI confirmation | `{ bookingId, paymentId, status: 'PAID' }` |
| **Live GPS Telemetry** | Customer + Admin | Socket.io | N/A (Foreground) | Foreground live map update | `{ bookingId, latitude, longitude, heading, speed }` |

---

## 2. Token Registration & Lifecycle Rules
1. **No Synthetic Tokens:** Tokens starting with `cust_fcm_`, `tech_fcm_`, or `fcm_` are strictly rejected by the backend with HTTP `400 Bad Request`.
2. **Pruning of Stale Tokens:** If Firebase returns `messaging/registration-token-not-registered` or `messaging/invalid-argument`, `notificationService` automatically deletes the token from the user's `device_tokens` array in PostgreSQL.
3. **Multi-Device Support:** Both `fcm_token` (primary) and `device_tokens` (array) are populated so multiple logged-in devices receive notifications.
