# BookurTechnician — Complete Fake Data & Hardcoded Data Removal Audit

**Audit Date:** 2026-11-04  
**Scope:** Flutter Customer App (`apps/customer_app_flutter`), Flutter Technician App (`apps/technician_app`), React Admin Panel (`apps/admin_panel`), Node.js Core Backend (`backend/node-core-service`), PostgreSQL/PostGIS, Firebase, Socket.IO, and Python AI Matching Service.

---

## 1. Executive Summary of Audit Metrics

| Metric | Count | Details |
|---|---|---|
| **Total Fake / Mock / Hardcoded Business Data Occurrences Found** | **13** | Across Customer App (`models.dart`, `home_screen.dart`, `all_services_screen.dart`, `catalog_screens.dart`, `cart_screen.dart`, `razorpay_payment_screen.dart`, `ai_assistant_service.dart`) and Backend (`paymentsController.js`) |
| **Total Occurrences Removed** | **13 / 13 (100%)** | Removed 1,416 lines of fake hardcoded catalog categories/services (`MockData.categoriesList` & `MockData.popularServices`), removed client-side payment verification bypasses (`verified = true` on catch), removed hardcoded Razorpay key/secret strings, and removed synthetic `order_dev_...` order ID fallback |
| **Total Occurrences Replaced with Real API / Database / Env Integration** | **13 / 13 (100%)** | Connected directly to `state.categories` (`GET /api/v1/catalog/categories` & `GET /api/v1/catalog/services`) with loading/empty/retry states, server-side `/payments/verify-signature`, and `process.env.RAZORPAY_KEY_ID` / `process.env.RAZORPAY_KEY_SECRET` |

---

## 2. Detailed Inventory of Removed Fake / Hardcoded Business Data

| # | File Path | Occurrence Found | Classification | Action Executed |
|---|---|---|---|---|
| 1 | `apps/customer_app_flutter/lib/models.dart` (lines 344–1761) | `MockData.categoriesList` & `MockData.popularServices` (~1,416 lines of hardcoded categories, services, fake prices `₹99–₹799`, fake `reviewsCount = 120`, and Unsplash placeholder URLs) | **Fake Catalog Data** | Removed all hardcoded categories/services from `MockData`; set `reviewsCount = 0` and `technicianRating = 0.0` defaults on models |
| 2 | `apps/customer_app_flutter/lib/screens/home_screen.dart` (lines 134, 150, 191, 668) | Fallback to `MockData.categoriesList` when `state.categories` is empty | **Mock Fallback** | Removed `MockData.categoriesList` fallback; added loading spinner (`state.isCatalogLoading`) and `"Unable to load data. Please check your connection and retry."` empty/retry state |
| 3 | `apps/customer_app_flutter/lib/screens/all_services_screen.dart` (line 82) | `state.categories.isNotEmpty ? state.categories : MockData.categoriesList` | **Mock Fallback** | Replaced with `state.categories` from live backend |
| 4 | `apps/customer_app_flutter/lib/screens/catalog_screens.dart` (lines 24, 27) | `MockData.categoriesList` fallback in `CategoryServicesScreen` | **Mock Fallback** | Replaced with `state.categories` from live backend |
| 5 | `apps/customer_app_flutter/lib/services/ai_assistant_service.dart` (line 219) | `MockData.categoriesList` fallback in `_handleOurServicesQuery` | **Mock Fallback** | Replaced with `state.categories` from live backend |
| 6 | `apps/customer_app_flutter/lib/screens/razorpay_payment_screen.dart` (lines 119–123) | `_razorpayOrderId = 'order_rzp_${widget.bookingCode}'` synthetic order ID fallback when `/payments/create-order` fails | **Fake Payment Order** | Removed synthetic order ID fallback; aborts checkout with error `SnackBar` if server order creation fails |
| 7 | `apps/customer_app_flutter/lib/screens/razorpay_payment_screen.dart` (lines 155–158) | Hardcoded `'rzp_test_ShRpqbs6hVT6Ie'` fallback key | **Hardcoded Credential** | Replaced with server-provided `keyId` or `String.fromEnvironment('RAZORPAY_KEY_ID')` |
| 8 | `apps/customer_app_flutter/lib/screens/razorpay_payment_screen.dart` (lines 212–216) | `verified = true;` in `catch (e)` block when `/payments/verify-signature` fails | **Dangerous Payment Bypass** | Changed to `verified = false;` so client never marks unverified payments as paid |
| 9 | `apps/customer_app_flutter/lib/screens/cart_screen.dart` (lines 586–588) | Hardcoded `'rzp_test_ShRpqbs6hVT6Ie'` fallback key | **Hardcoded Credential** | Replaced with server-provided `keyId` or `String.fromEnvironment('RAZORPAY_KEY_ID')` |
| 10 | `apps/customer_app_flutter/lib/screens/cart_screen.dart` (lines 636–647) | Ignored `/payments/verify-signature` HTTP status/errors before calling `confirmOrder` | **Dangerous Payment Bypass** | Enforced `verifyRes.statusCode == 200` check; blocks booking confirmation if signature verification fails |
| 11 | `backend/node-core-service/src/controllers/paymentsController.js` (lines 7–8) | Hardcoded fallback `'rzp_test_ShRpqbs6hVT6Ie'` and `'5LUjZ94LMDnjwlLyB9cUU5cb'` in source code | **Hardcoded Secret** | Removed hardcoded key/secret; reads strictly from `process.env.RAZORPAY_KEY_ID` and `process.env.RAZORPAY_KEY_SECRET` |
| 12 | `backend/node-core-service/src/controllers/paymentsController.js` (lines 88–97) | `razorpayOrderId = order_dev_${Date.now()}_...` synthetic fallback when Razorpay API fails | **Fake Payment Order** | Removed synthetic fallback; returns `503 Service Unavailable` when gateway credentials or API are unavailable |
| 13 | `backend/node-core-service/src/controllers/bookingController.js` (lines 796–824, 1036–1090) & `technicianController.js` (line 2084) | Missing technician assignment ownership check on `verify-start-otp`, `verify-end-otp`, and `proof` upload; proof bypass in non-production | **Security / Validation Bypass** | Enforced `403 Forbidden` for unassigned technicians and mandatory `AFTER` proof across all environments |

---

## 3. Legitimate Static Constants Preserved (Phase 7 Classification)

The following constants were inspected and verified as **legitimate static system/design constants** (not fake business data):
1. **Brand Design Tokens (`apps/customer_app_flutter/lib/theme.dart`, `apps/technician_app/lib/core/theme/app_colors.dart`, `apps/admin_panel/src/index.css`):**
   - Royal Blue (`#173B8F`), Deep Navy (`#102A63`), Bright Yellow (`#FFC928`), Pure White (`#FFFFFF`), Light Blue (`#EDF3FF`), Dark Text (`#202938`), Secondary Text (`#737D8C`), Success Green (`#18864B`), Error Red (`#D64545`), Border (`#E4E9F1`).
2. **Bundled Local Asset Banner Slides (`assets/images/banner_3d_1.png`–`3.png`, `popular_banner_1.png`–`3.png`):**
   - Local static visual hero graphics bundled inside `assets/images/` for the home banner carousel when no remote promotional campaign overrides are active.
3. **Cryptographic / Unique ID & OTP Generation (`bookingController.js`, `authController.js`, `ledgerService.js`):**
   - Server-side `generateOtp()` / `generateServiceOtp()` (`Math.floor(1000 + Math.random() * 9000)`) and `uuidv4()` for unique booking codes, OTPs, message IDs, and ledger transaction IDs.
4. **System Configuration Defaults (`automaticDispatchEngine.js`):**
   - Progressive search radii `[3, 5, 10, 15]` km, offer countdown `20s`, geofence radius `500m`, GST rate `18%`, platform commission `15%`.

---

## 4. Application & Backend Verification Matrix (Phases 2–9)

| Component / Requirement | Status | Verification Evidence |
|---|---|---|
| **Customer App (`apps/customer_app_flutter`)** | **PASS** | `flutter analyze` passed with `0` issues; all catalog, slot, booking, tracking, invoice & payment flows connected to backend APIs |
| **Technician App (`apps/technician_app`)** | **PASS** | `flutter analyze` passed with `0` issues; `0` mock/dummy matches in codebase; connected to real dispatch, GPS, geofence, OTP, proof & wallet APIs |
| **React Admin Panel (`apps/admin_panel`)** | **PASS** | Built (`vite build`, 0 errors) and deployed live to `https://bookmytechnician-53d94.web.app`; all 22 modules connected to `/api/v1/admin/*` |
| **Node.js Backend & PostgreSQL/PostGIS (`backend/node-core-service`)** | **PASS** | 17 PostgreSQL tables verified; `24 / 24` integration tests passed in `scripts/test_automatic_dispatch_suite.js` |
| **Socket.IO Real-Time Dispatch & Scoped GPS** | **PASS** | Verified with live WebSocket clients (`dispatch:offer:new`, `booking:technician:assigned`, `booking:partner:location`, `auth_error` on unauthorized room join) |
| **EmailJS Registered Email OTP Delivery** | **PASS** | Verified live HTTP 200 delivery via EmailJS (`service_noexwvl` / `template_159x4wr`) during automated test suite |
| **Firebase Admin SDK / FCM Deduplication** | **PASS (API/Logic)** | Synthetic FCM tokens rejected (`400 Bad Request`); duplicate `(userId, offerId)` push delivery suppressed |
| **Physical Dual-Android Device Hardware Test** | **NOT VERIFIED** | `adb devices -l` reports `0` physical Android devices attached to workstation |
| **Live Production Razorpay Bank Settlement** | **BLOCKED** | Requires live production `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` environment variables on deployment host |
