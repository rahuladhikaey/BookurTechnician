# Production Blockers Tracking & Resolution Log
**Audit Date:** November 2026  
**Status:** **ALL CODE-LEVEL P0 BLOCKERS RESOLVED (0 REMAINING)**

---

## 1. P0 Blocker Ledger

| ID | Category | Description | Root Cause | Resolution | Status |
|---|---|---|---|---|---|
| **BLK-01** | Booking / Catalog | Static hardcoded booking slots in mobile app | Client app held hardcoded arrays of times without checking actual technician schedule or conflict | Implemented `/api/v1/catalog/services/:id/slots` computing dynamic 1-hour slots based on service duration, working hours, and existing bookings | **RESOLVED** |
| **BLK-02** | Concurrency | Double booking conflict on simultaneous checkout | No lock or conflict query check before inserting booking | Added slot conflict check during `createBooking` and atomic conditional SQL update during `acceptBooking` returning `409 Conflict` | **RESOLVED** |
| **BLK-03** | Financial Security | Client-controlled price tampering | Server accepted `grandTotal` and `servicePrice` directly from client HTTP request | Server recalculates base price, visit fee (₹49), and 18% GST strictly from DB master catalog. Tampered client values rejected/overwritten | **RESOLVED** |
| **BLK-04** | Payment Security | Razorpay signature bypass with `startsWith('pay_')` | Insecure developer fallback permitted fake payment IDs | Removed all prefix bypasses. Implemented `crypto.timingSafeEqual` HMAC-SHA256 signature verification | **RESOLVED** |
| **BLK-05** | Webhook Security | Signature failure on JSON stringification | Express JSON parser mutates raw bytes required for cryptographic verification | Captured `req.rawBody = buf` in `server.js` and enforced raw buffer verification with event deduplication | **RESOLVED** |
| **BLK-06** | Authentication | Master OTP bypasses (`123456`, `1234`, `0000`, `4821`) | Development convenience fallbacks left in production controllers and Flutter screens | Removed all bypasses. Enforced `crypto.randomInt(100000, 1000000)`. Production fails closed on incorrect OTP | **RESOLVED** |
| **BLK-07** | State Machine | Client could directly post `COMPLETED` | Booking state controller permitted arbitrary status updates | Implemented `VALID_TRANSITIONS` table and enforced mandatory start OTP, before/after proof, and end OTP | **RESOLVED** |
| **BLK-08** | Notification / FCM | FCM registration token field mismatch | Technician app sent `fcmToken`, backend expected `token` | Unified contract to accept `fcmToken || token`. Persists to PostgreSQL `fcm_token` and `device_tokens`. Rejects synthetic tokens | **RESOLVED** |
| **BLK-09** | Notification / FCM | Synthetic token generation (`tech_fcm_`, `cust_fcm_`) | Backend attempted to dispatch pushes to synthetic IDs | Created `notificationService.js` that looks up real tokens from `users` table and automatically prunes stale/expired tokens | **RESOLVED** |
| **BLK-10** | Geofence | Technician could mark arrived from any GPS location | Client-only distance calculation | Backend computes Haversine distance from customer booking coordinates. Rejects arrival if distance > 500m | **RESOLVED** |
| **BLK-11** | Privacy / GPS | Global GPS broadcast leaked partner location | `io.emit('job:partner_location')` broadcasted to all connected sockets | Scoped telemetry strictly to `booking_<id>`, `cust_<id>`, `tech_<id>`, and `admin_dispatch` | **RESOLVED** |
| **BLK-12** | Authorization / Admin | Admin routes unauthenticated or relying on headers | Admin endpoints did not enforce JWT or RBAC verification | Applied `authenticateToken` and `requireAdminRole` to all `/api/v1/admin` routes. Secured `clean-slate` to 403 Forbidden in production | **RESOLVED** |
| **BLK-13** | IDOR | Chat messages readable by unauthorized users | `getBookingMessages` did not verify if requesting user was booking participant | Enforced identity check: only customer, assigned technician, or admin can read/send messages for a booking | **RESOLVED** |
| **BLK-14** | Telecom Masking | Simulated phone calls | App simulated masked calling without provider integration | Implemented `telecomMaskingService.js` (Exotel/Twilio). Fails closed with 503 instead of pretending calls work when unconfigured | **RESOLVED** |
| **BLK-15** | Payouts | Simulated instant UPI payouts | Ledger engine generated synthetic `UPI-RZPX-...` IDs | Integrated real RazorpayX payouts API and webhook reconciliation. Queues for admin approval if unconfigured | **RESOLVED** |

---

## 2. Infrastructure Pre-Launch Checklist (Action for DevOps)

The following production credentials must be populated in the production `.env` / cloud secrets manager before public DNS traffic cutover:
- [ ] `RAZORPAY_KEY_ID` & `RAZORPAY_KEY_SECRET` (Live Production Keys)
- [ ] `RAZORPAY_WEBHOOK_SECRET` (Production Webhook Secret)
- [ ] `RAZORPAYX_KEY_ID` & `RAZORPAYX_KEY_SECRET` & `RAZORPAYX_ACCOUNT_NUMBER` (RazorpayX Payouts)
- [ ] `EXOTEL_API_KEY` & `EXOTEL_API_TOKEN` & `EXOTEL_CALLER_ID` & `EXOTEL_SID` (Or Twilio Voice)
- [ ] `FIREBASE_SERVICE_ACCOUNT_JSON` (Google Service Account Private Key)
- [ ] `BUSINESS_GSTIN` & `BUSINESS_LEGAL_NAME` (Registered Business Tax Identifier)
