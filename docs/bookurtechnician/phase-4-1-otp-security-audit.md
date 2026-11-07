# BOOKURTECHNICIAN — PHASE 4.1 IDENTITY & OTP SECURITY AUDIT

**Audit Date:** 2026-11-08  
**Firebase Project:** `bookmytechnician-53d94` (`asia-south1`)  
**Auditor Role:** Principal Application Security Engineer  

---

## 1. Executive Summary & Critical Phase 4 Vulnerabilities Remediated

During the Phase 4.1 forensic security audit of authentication, OTP generation/verification, and user identity across the Customer App, Technician App, and Node.js Backend, **five severe security flaws** were identified and remediated:

1. **Client-Side OTP Generation & Local Memory Comparison (CRITICAL — FIXED):**
   - Previously, [`apps/technician_app/lib/features/auth/presentation/auth_provider.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/features/auth/presentation/auth_provider.dart) generated a 6-digit OTP on the client (`_lastGeneratedOtp = (100000 + Random().nextInt(900000)).toString()`) and verified it locally in Dart memory (`if (_lastGeneratedOtp != null && otp.trim() == _lastGeneratedOtp)`).
   - Similarly, [`apps/customer_app_flutter/lib/screens/login_screen.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/login_screen.dart) (`_resendOtp`) generated a local OTP on the client when the backend was unreachable.
2. **Hardcoded `'123456'` Master OTP Backdoors (CRITICAL — FIXED):**
   - Previously, `auth_provider.dart`,both apps' `firestore_rest_client.dart` (`if (otp.length < 4) return 400;` accepting any 4+ digit code), and [`backend/node-core-service/src/controllers/authController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/authController.js) (`process.env.NODE_ENV !== 'production' ? '123456' : generateOtp()`) allowed trivial authentication bypass.
3. **Hardcoded EmailJS Private Key in Client Dart Code (CRITICAL — FIXED):**
   - Both [`apps/technician_app/lib/core/network/email_service.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/email_service.dart) and [`apps/customer_app_flutter/lib/services/email_service.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/email_service.dart) contained a hardcoded EmailJS `privateKey` (`accessToken`) in client source code.
4. **Weak `Math.random()` OTP Generation & Plaintext Redis Storage (HIGH — FIXED):**
   - In [`authController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/authController.js) and [`bookingController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/bookingController.js), OTPs were generated using non-cryptographic `Math.random()` and stored in plaintext in Redis without request rate limiting.
5. **Conflation of Internal User Identity (`uid`) with Public Partner Code (`BT-XXXXXX`) (HIGH — FIXED):**
   - In `firestore_rest_client.dart` and `authController.js`, technician IDs sometimes defaulted to `'BT-PARTNER'` or mixed internal UIDs with public display codes.

---

## 2. Corrective Security Architecture Implemented

### 2.1 Cryptographically Secure OTP Generation & SHA-256 Hashing
- **Node.js Backend ([`authController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/authController.js#L20-L26) & [`bookingController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/bookingController.js#L39-L41)):**
  - Replaced `Math.random()` with `crypto.randomInt(100000, 1000000).toString()` for 6-digit auth OTPs and `crypto.randomInt(1000, 10000).toString()` for 4-digit service start/end OTPs.
  - Auth OTPs are hashed with `crypto.createHash('sha256').update(otp).digest('hex')` (`otpHash`) before storing in Redis (`otp:${identifier}`) with a strict 600-second (10-minute) TTL. Plaintext OTPs are never persisted in Redis.
  - Verification uses constant-time `crypto.timingSafeEqual(Buffer.from(inputOtpHash, 'hex'), Buffer.from(storedHash, 'hex'))`.
- **Cloud Firestore Challenge Engine ([`customer_app_flutter/.../firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L526-L696) & [`technician_app/.../firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/firestore_rest_client.dart#L383-L556)):**
  - Implemented `Random.secure()` + FIPS 180-4 `sha256Hex()` in `requestOtpChallenge()` and `verifyOtpChallenge()`.
  - Stores only `otpHash` (never plaintext OTP) in the `otp_challenges` collection, never in `SharedPreferences`.
  - Removed all `'123456'` and `otp.length >= 4` backdoors.

### 2.2 Strict Expiry, Brute-Force Lockout, and Request Rate Limiting
| Security Control | Threshold Enforced | Error Code Returned | HTTP Status |
| :--- | :--- | :--- | :---: |
| **OTP Validity Window (Expiry)** | **10 minutes** (`600,000 ms`) from generation | `OTP_EXPIRED` | `400` |
| **OTP Request Rate Limit** | Max **3 OTP requests** per **10 minutes** per identifier | `OTP_RATE_LIMIT_EXCEEDED` | `429` |
| **OTP Verification Attempt Limit** | Max **5 failed attempts** $\rightarrow$ **15-minute lockout** (`900,000 ms`) | `OTP_ATTEMPT_LIMIT_EXCEEDED` | `429` |
| **Single-Use Replay Prevention** | OTP challenge is immediately deleted/consumed upon first valid verification | `OTP_EXPIRED` / `INVALID_OTP` | `400` |

### 2.3 Removal of Hardcoded Client Secrets
- In [`apps/technician_app/lib/core/network/email_service.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/email_service.dart#L9-L11) and [`apps/customer_app_flutter/lib/services/email_service.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/email_service.dart#L9-L11), removed the hardcoded EmailJS `privateKey` literal and replaced it with `const String.fromEnvironment('EMAILJS_PRIVATE_KEY', defaultValue: '')`, omitting `accessToken` from client payloads when not injected at build time.

### 2.4 Separation of Internal UID (`id` / `uid`) and Public Partner Code (`BT-XXXXXX`)
- **Backend ([`authController.js`](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/authController.js#L350-L435)):**
  - Every user and technician record uses an immutable UUID v4 (`userId`) as `id`, `uid`, and `technicianId`.
  - Technicians receive a separate public display code `technicianCode: 'BT-XXXXXX'` stored in the `technician_code` column and returned alongside `uid`.
- **Flutter Apps ([`technician_app/.../firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/technician_app/lib/core/network/firestore_rest_client.dart#L614-L624) & [`customer_app_flutter/.../firestore_rest_client.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L1063-L1075)):**
  - Internal identities use canonical UIDs (`uid_tech_<identifier>` and `uid_cust_<identifier>`).
  - Public partner codes (`BT-XXXXXX`) are stored strictly in `technicianCode` for UI display and customer-facing badges.

---

## 3. Automated Security Test Verification

| Test Case | Test Suite | Result |
| :--- | :--- | :---: |
| **Scenario 8A:** Expired OTP (>10 mins) rejected with `400 OTP_EXPIRED` | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** |
| **Scenario 8B:** 4th OTP request within 10 mins rejected with `429 OTP_RATE_LIMIT_EXCEEDED` | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** |
| **Scenario 8C:** 5 failed OTP attempts trigger 15-min lockout (`429 OTP_ATTEMPT_LIMIT_EXCEEDED`), rejecting even valid OTP during lockout | [`phase_4_1_booking_safety_test.dart`](file:///d:/BookurTechnician/apps/customer_app_flutter/test/phase_4_1_booking_safety_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** |
| **Scenario 8D:** Hardcoded `'123456'` master code rejected (`400 INVALID_OTP`) and single-use OTP replay rejected | [`phase_4_1_presence_and_otp_test.dart`](file:///d:/BookurTechnician/apps/technician_app/test/phase_4_1_presence_and_otp_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** |
| **Scenario 8E:** Internal `uid` (`uid_tech_...` / UUID) is distinct from public `technicianCode` (`BT-XXXXXX`) | [`phase_4_1_presence_and_otp_test.dart`](file:///d:/BookurTechnician/apps/technician_app/test/phase_4_1_presence_and_otp_test.dart) & [`test_phase_4_1_suite.js`](file:///d:/BookurTechnician/backend/node-core-service/scripts/test_phase_4_1_suite.js) | **PASS** |

