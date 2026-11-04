# BookurTechnician — Complete Enterprise Security Audit

**Classification:** Confirmed Vulnerability Audit & Defense Verification  
**Standard:** OWASP Top 10 API Security 2023, OWASP Mobile Top 10 2024, NIST SP 800-53  
**Status:** Audit Completed & Remediated  
**Date:** November 2026  

---

## 1. Executive Summary

This security audit conducted a comprehensive, zero-trust examination of the entire BookurTechnician on-demand marketplace ecosystem:
- **Node.js Core Backend Gateway** (`backend/node-core-service`)
- **Flutter Customer Application** (`apps/customer_app_flutter`)
- **Flutter Technician Application** (`apps/technician_app`)
- **React Enterprise Admin Panel** (`apps/admin_panel`)
- **Database & Persistence Tier** (PostgreSQL + PostGIS, Redis, Cloud Firestore)
- **Payment & Telecom Integrations** (Razorpay, Brevo/EmailJS, Firebase FCM)
- **Real-Time Communication Layer** (Socket.io)

All identified vulnerabilities were classified into standard severity tiers (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `INFORMATIONAL`) and remediated with cryptographic zero-trust enforcement.

---

## 2. Vulnerability Classification Matrix

| Finding ID | Severity | Category | Target Component | Status |
|---|---|---|---|---|
| **SEC-AUD-01** | **CRITICAL** | Broken Object Level Auth (IDOR) | `customerRoutes.js`, `customerController.js` | **REMEDIATED** |
| **SEC-AUD-02** | **CRITICAL** | Broken Object Level Auth (Deletion) | `bookingRoutes.js`, `bookingController.js` | **REMEDIATED** |
| **SEC-AUD-03** | **CRITICAL** | Broken Function Level Auth (BFLA) | `technicianRoutes.js`, `technicianController.js` | **REMEDIATED** |
| **SEC-AUD-04** | **CRITICAL** | Financial IDOR / Unauthorized Payout | `technicianRoutes.js`, `technicianController.js` | **REMEDIATED** |
| **SEC-AUD-05** | **CRITICAL** | Financial Data Leakage / IDOR | `technicianRoutes.js`, `technicianController.js` | **REMEDIATED** |
| **SEC-AUD-06** | **CRITICAL** | KYC Document Privacy Breach (IDOR) | `technicianRoutes.js`, `technicianController.js` | **REMEDIATED** |
| **SEC-AUD-07** | **CRITICAL** | WebSocket Real-Time Telemetry Snooping | `server.js` (`isAuthorizedToJoinRoom`) | **REMEDIATED** |
| **SEC-AUD-08** | **CRITICAL** | Cloud Firestore Open Rules Exposure | `firestore.rules` | **REMEDIATED** |
| **SEC-AUD-09** | **HIGH** | Authentication Bypass via Substring | `authController.js` (`adminDirectAccess`) | **REMEDIATED** |
| **SEC-AUD-10** | **HIGH** | Hardcoded Secret in Source Code | `bookingController.js` (lines 1278–1279) | **REMEDIATED** |
| **SEC-AUD-11** | **HIGH** | Plaintext OTP Leakage in Server Logs | `authController.js` (line 128) | **REMEDIATED** |
| **SEC-AUD-12** | **HIGH** | Missing OTP Brute-Force Rate Limiting | `authController.js` (`verifyOtp`) | **REMEDIATED** |
| **SEC-AUD-13** | **HIGH** | Price Tampering in Order Creation | `paymentsController.js` (`createOrder`) | **REMEDIATED** |
| **SEC-AUD-14** | **MEDIUM** | Missing HTTP Security Headers | `server.js` | **REMEDIATED** |
| **SEC-AUD-15** | **MEDIUM** | Privilege Escalation in OTP Verification | `authController.js` (`verifyOtp`) | **REMEDIATED** |
| **SEC-AUD-16** | **LOW** | Client Storage Token Encryption | `customer_app_flutter` (`api_client.dart`) | **DOCUMENTED** |
| **SEC-AUD-17** | **INFORMATIONAL**| Multi-Tenant PostGIS Query Audit | `postgresSpatialScanner.js` | **VERIFIED CLEAN** |

---

## 3. Detailed Vulnerability Analyses & Remediations

### SEC-AUD-01: Broken Object Level Authorization on Customer Routes
- **Severity:** `CRITICAL` (CVSS 9.1)
- **Location:** `backend/node-core-service/src/routes/customerRoutes.js`, `src/controllers/customerController.js`
- **Vulnerability Mechanics:** Customer profile, address, and deletion endpoints were mounted without `authenticateToken`. The controller derived identity from `req.query.userId || req.headers['x-user-id']`.
- **Attack Vector:** An unauthenticated attacker could issue `GET /api/v1/customer/profile?userId=<victim_id>` to extract the victim's full name, phone number, email, and exact home GPS coordinates.
- **Remediation:** Mounted `router.use(authenticateToken)`. Implemented `resolveEffectiveCustomerId(req)` which authoritatively binds `userId = req.user.id` unless the authenticated token holds `ADMIN` or `SUPER_ADMIN` role.

### SEC-AUD-02: Unauthenticated Booking Deletion & Cancellation IDOR
- **Severity:** `CRITICAL` (CVSS 8.8)
- **Location:** `backend/node-core-service/src/routes/bookingRoutes.js` (lines 64–65), `bookingController.js`
- **Vulnerability Mechanics:** `DELETE /api/v1/bookings/:id` and `DELETE /my-bookings` lacked authentication and ownership checks.
- **Attack Vector:** Any network user could send HTTP DELETE requests to wipe active bookings from the database without authentication.
- **Remediation:** Mounted `authenticateToken` on all deletion and cancellation routes. Verified that only the booking owner (`customerId === req.user.id`) or an Admin can delete or cancel a booking.

### SEC-AUD-03: Broken Function Level Authorization on Admin Verification
- **Severity:** `CRITICAL` (CVSS 9.3)
- **Location:** `backend/node-core-service/src/routes/technicianRoutes.js` (lines 65–68), `technicianController.js`
- **Vulnerability Mechanics:** Endpoints `/api/v1/technicians/documents/admin/:id/verify` and `/skills/admin/:id/verify` were mounted with `optionalAuth` and lacked administrative RBAC checks.
- **Attack Vector:** An unverified technician could POST `{ status: 'VERIFIED' }` to their own document verification endpoint and bypass administrative background checks.
- **Remediation:** Replaced `optionalAuth` with mandatory `authenticateToken` and `requireAdminRole` middleware on all admin verification routes.

### SEC-AUD-04: Financial IDOR on Instant Wallet Withdrawals
- **Severity:** `CRITICAL` (CVSS 9.4)
- **Location:** `backend/node-core-service/src/controllers/technicianController.js` (`withdrawEarnings`)
- **Vulnerability Mechanics:** Controller allowed `technicianId` to be provided in the request body (`req.body.technicianId || req.headers['x-technician-id']`).
- **Attack Vector:** An attacker could supply another technician's ID and withdraw that technician's hard-earned balance to the attacker's UPI address.
- **Remediation:** Bound `technicianId` strictly to `req.user.id`. Explicitly rejected requests where `req.body.technicianId` does not match the authenticated session.

### SEC-AUD-05: Financial Data Leakage on Technician Wallet Ledger
- **Severity:** `CRITICAL` (CVSS 8.2)
- **Location:** `backend/node-core-service/src/controllers/technicianController.js` (`getWalletLedger`)
- **Vulnerability Mechanics:** `getWalletLedger` read `req.query.technicianId` without checking if the caller was an authorized administrator or the ledger owner.
- **Attack Vector:** Any user or rival technician could query other technicians' lifetime earnings, COD cash liabilities, and bank transfer history.
- **Remediation:** Enforced strict identity checks: non-admin callers can only inspect their own ledger (`technicianId = req.user.id`).

### SEC-AUD-06: KYC Identity Document Leakage (IDOR)
- **Severity:** `CRITICAL` (CVSS 8.9)
- **Location:** `backend/node-core-service/src/controllers/technicianController.js` (`getDocuments`)
- **Vulnerability Mechanics:** `getDocuments` resolved `technicianId` from query or params without checking caller authorization.
- **Attack Vector:** Unauthorized users could inspect scanned government documents (Aadhaar cards, PAN cards, trade certificates).
- **Remediation:** Enforced cryptographic session ownership: non-admin callers requesting another technician's documents receive HTTP 403 Forbidden.

### SEC-AUD-07: Real-Time WebSocket Telemetry Snooping
- **Severity:** `CRITICAL` (CVSS 9.0)
- **Location:** `backend/node-core-service/src/server.js` (`isAuthorizedToJoinRoom`)
- **Vulnerability Mechanics:** The room authorization callback defaulted to returning `true` for unauthenticated sockets (`!user`) requesting `tech_*`, `cust_*`, and `booking_*` rooms.
- **Attack Vector:** An attacker could connect to Socket.io with no token, join `booking_<id>` or `tech_<id>`, and intercept live GPS coordinates and chat messages.
- **Remediation:** Hardened `isAuthorizedToJoinRoom`: unauthenticated connections are denied from joining all private and operational rooms.

### SEC-AUD-08: Cloud Firestore Security Rules Wildcard Exposure
- **Severity:** `CRITICAL` (CVSS 9.6)
- **Location:** `firestore.rules`
- **Vulnerability Mechanics:** Root fallback contained `match /{document=**} { allow read, write: if true; }`.
- **Attack Vector:** Direct client SDK queries could read or overwrite customer and booking collections.
- **Remediation:** Completely rewrote `firestore.rules`: catalog read is public; all client writes are blocked (managed authoritatively by Node.js backend using Firebase Admin SDK); private records are restricted to authenticated owners and admins.

### SEC-AUD-09: Admin Authentication Bypass via Substring Check
- **Severity:** `HIGH` (CVSS 8.5)
- **Location:** `backend/node-core-service/src/controllers/authController.js` (`adminDirectAccess`)
- **Vulnerability Mechanics:** Condition `trimmedEmail.includes('admin')` allowed any email with the word "admin" to receive a `SUPER_ADMIN` JWT without verifying an access key.
- **Attack Vector:** Supplying `fakeadmin@attacker.com` granted instantaneous super-administrator access.
- **Remediation:** Replaced with strict equality against configured administrative email (`admin@bookurtechnician.com`) AND mandatory cryptographic access key verification.

### SEC-AUD-10: Hardcoded Fallback Secrets in Source Code
- **Severity:** `HIGH` (CVSS 7.5)
- **Location:** `backend/node-core-service/src/controllers/bookingController.js` (lines 1278–1279)
- **Vulnerability Mechanics:** Fallback test Razorpay Key ID and Key Secret were present in source code.
- **Remediation:** Replaced hardcoded strings with `process.env.RAZORPAY_KEY_ID` and `process.env.RAZORPAY_KEY_SECRET`.

### SEC-AUD-11: Plaintext OTP Leakage in Application Logs
- **Severity:** `HIGH` (CVSS 7.2)
- **Location:** `backend/node-core-service/src/controllers/authController.js` (line 128)
- **Vulnerability Mechanics:** Server logged `🔑 [OTP Dispatch] For ... : 123456 [Valid 10 mins]` to stdout.
- **Remediation:** Replaced plaintext OTP output with masked tail logging (`***${otp.slice(-2)}`).

### SEC-AUD-12: Missing OTP Brute-Force Rate Limiting
- **Severity:** `HIGH` (CVSS 7.8)
- **Location:** `backend/node-core-service/src/controllers/authController.js` (`verifyOtp`)
- **Vulnerability Mechanics:** No failed attempt counter existed in Redis for OTP verification.
- **Remediation:** Implemented Redis attempt tracking: 5 consecutive failed attempts trigger an automatic 15-minute account lock (HTTP 429). Successful verification clears the counter.

### SEC-AUD-13: Price Tampering in Payment Order Creation
- **Severity:** `HIGH` (CVSS 8.1)
- **Location:** `backend/node-core-service/src/controllers/paymentsController.js` (`createOrder`)
- **Vulnerability Mechanics:** `const payableAmount = parseFloat(requestedAmount || booking?.totalAmount ...)`.
- **Attack Vector:** Sending `{ amount: 1.00 }` in the checkout request would generate a ₹1 Razorpay order for a ₹999 booking.
- **Remediation:** Enforced authoritative server price: `booking.totalAmount || booking.grandTotal` is the sole source of truth; any client discrepancies trigger a security alert and are overridden.

### SEC-AUD-14: Missing HTTP Security Headers
- **Severity:** `MEDIUM` (CVSS 5.3)
- **Location:** `backend/node-core-service/src/server.js`
- **Vulnerability Mechanics:** Missing HSTS, X-Content-Type-Options, X-Frame-Options, CSP, and Express fingerprint leak.
- **Remediation:** Created `backend/node-core-service/src/middleware/securityMiddleware.js` enforcing HSTS, nosniff, SAMEORIGIN, CSP, and removing `X-Powered-By`.

### SEC-AUD-15: Privilege Escalation via Client-Provided Role in OTP Verification
- **Severity:** `MEDIUM` (CVSS 6.5)
- **Location:** `backend/node-core-service/src/controllers/authController.js` (`verifyOtp`)
- **Vulnerability Mechanics:** `userRole = cachedData?.role || requestRole || 'CUSTOMER'`.
- **Remediation:** Enforced that client-provided `requestRole` can never assign `ADMIN` or `SUPER_ADMIN`.
