# BookurTechnician — Real Device & FCM Notification Dispatch Test Report

## 1. Notification & Socket Delivery Architecture
- **Foreground Real-Time Delivery:** Socket.io (`dispatch:offer:new`, `dispatch:offer:expired`, `dispatch:offer:cancelled`, `dispatch:offer:accepted`) scoped to room `tech_<technicianId>`.
- **Background / Locked / Terminated Push Delivery:** Firebase Cloud Messaging (`firebase-admin` in `notificationService.js`) configured with:
  - Android Priority: `high` (`ttl: 45s`)
  - Android Notification Channel: `technician_emergency_channel`
  - Sound: `siren_alarm`
  - Click Action: `FLUTTER_NOTIFICATION_CLICK`
  - Provider Diagnostics: `fcm_message_id` and `fcm_delivery_status` recorded per offer in `dispatch_offers`
  - Invalid Token Cleanup: Automatically removes tokens when FCM returns `registration-token-not-registered` or `invalid-registration-token`.
- **EmailJS OTP Delivery:** All authentication OTPs and booking Start/End OTPs are sent to the user's registered email address via `emailService.js` (`service_noexwvl` / `template_159x4wr`).

---

## 2. Physical Device Verification Status (Section 20 Honesty Protocol)
Per Section 20 requirements ("Never claim that a phone will ring if its settings or OS prevent the alert" and "Do not claim PASS without real execution evidence"):

| Scenario | Automated Backend / Socket / API Status | Physical Android Hardware ADB Status | Notes |
|---|---|---|---|
| **Technician Foreground App** | `VERIFIED (PASS)` | `NOT VERIFIED (No physical Android device attached via ADB)` | Verified via live Socket.io client (`dispatch:offer:new`) + `IncomingJobAlertOverlay` |
| **Technician Background App** | `CODE & FCM PAYLOAD VERIFIED` | `NOT VERIFIED (No physical Android device attached via ADB)` | High-priority FCM payload + `firebaseMessagingBackgroundHandler` configured |
| **Technician Locked Screen** | `CODE & FCM PAYLOAD VERIFIED` | `NOT VERIFIED (No physical Android device attached via ADB)` | Full-screen high-importance channel `technician_emergency_channel` configured |
| **Technician Terminated App** | `CODE & REST RESYNC VERIFIED` | `NOT VERIFIED (No physical Android device attached via ADB)` | `BookingRequestManager.syncPendingRequests()` fetches `/api/v1/technician/offers` on launch |
| **Customer Searching -> Assigned** | `VERIFIED (PASS)` | `NOT VERIFIED (No physical Android device attached via ADB)` | Verified via `booking:dispatch:started`, `booking:dispatch:searching`, `booking:technician:assigned` |
| **EmailJS Registered Email OTP** | `VERIFIED (PASS)` | `VERIFIED (LIVE HTTP 200 OK)` | Confirmed live EmailJS dispatch (`Service: service_noexwvl, Template: template_159x4wr`) |

