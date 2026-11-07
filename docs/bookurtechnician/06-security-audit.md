# BOOKURTECHNICIAN — COMPLETE FORENSIC ARCHITECTURE AUDIT
## Document 06: Enterprise Security, Vulnerability & Data Integrity Audit

**Audit Date:** November 7, 2026  
**Auditor Roles:** Backend Security Auditor, Cloud Security Architect  
**Scope:** Customer App, Technician App, React Admin Panel, Node.js Core Service, Cloud Firestore, Firebase Storage, Payment & Location Telemetry

---

## 1. Vulnerability Classification Matrix

| Finding ID | Severity | Category | Target Component | Status |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | **CRITICAL** | Authorization Bypass | Cloud Firestore Security Rules | Active in `firestore.rules` |
| **SEC-02** | **CRITICAL** | Hardcoded Credentials | React Admin Panel (`apiClient.js`) | Present in source code |
| **SEC-03** | **HIGH** | PII & Location Data Leakage | Cloud Firestore (`technician_profiles`) | Publicly readable |
| **SEC-04** | **HIGH** | Financial Integrity (Price Tampering) | Flutter Customer App (`FirestoreRestClient`) | Unvalidated client totals |
| **SEC-05** | **HIGH** | Insecure Cryptographic Randomness | Flutter Customer App (OTP Generation) | Uses non-crypto `Random()` |
| **SEC-06** | **MEDIUM** | Secret Exposure in Config | Render Blueprint (`render.yaml`) | Hardcoded Admin & EmailJS keys |
| **SEC-07** | **MEDIUM** | Distributed Race Condition | Node.js Dispatch Engine (`automaticDispatchEngine.js`) | Process-local mutex |
| **SEC-08** | **MEDIUM** | Premature Customer Address Exposure | Cloud Firestore (`bookings`) | Full address stored pre-assignment |

---

## 2. In-Depth Vulnerability Evidence & Analysis

### 2.1. SEC-01 & SEC-03: Public Read Flaw in Technician Profiles & Firestore Rules Bypass
- **File:** [`firestore.rules` line 49-52](file:///d:/BookurTechnician/firestore.rules#L49-L52)
- **Vulnerable Code:**
  ```javascript
  // 3. Technician Profiles (Read by Authenticated Users, Write by Owner or Admin)
  match /technician_profiles/{techId} {
    allow read: if isAuthenticated() || true; // <-- CRITICAL SECURITY FLAW
    allow write: if isOwner(techId) || isAdmin();
  }
  ```
- **Exploitation Mechanism:**  
  The clause `|| true` makes the entire `technician_profiles` collection publicly readable without any authentication token. Anyone who knows or discovers the Firebase Project ID (`bookmytechnician-53d94`) can issue:
  `GET https://firestore.googleapis.com/v1/projects/bookmytechnician-53d94/databases/(default)/documents/technician_profiles`
  and retrieve a complete dump of every registered partner's full name, phone number, exact GPS latitude/longitude, and verified skills.
- **Remediation:** Remove `|| true`. Restrict read access strictly to authenticated users or via sanitized backend endpoints that mask phone numbers and precise coordinates.

---

### 2.2. SEC-02: Hardcoded Re-Authentication Keys in Admin Client
- **File:** [`apps/admin_panel/src/api/apiClient.js` lines 104-124](file:///d:/BookurTechnician/apps/admin_panel/src/api/apiClient.js#L104-L124)
- **Vulnerable Code:**
  ```javascript
  if ((response.status === 401 || response.status === 403) && !targetUrl.includes('/auth/')) {
    console.warn(`[ApiClient] Token expired (HTTP ${response.status}). Auto-refreshing...`);
    try {
      const authRes = await this.directAdminAccess(
        'admin@bookurtechnician.com',
        'BT-ADMIN-KEY-PRIMARY-7788',
        'BT-ADMIN-KEY-SECONDARY-9900'
      );
      const freshToken = authRes?.data?.accessToken || authRes?.accessToken || authRes?.token;
      if (freshToken) {
        this.setToken(freshToken, true);
        ...
  ```
- **Exploitation Mechanism:**  
  If the Admin Panel web bundle (`apps/admin_panel/dist`) is publicly accessible via Firebase Hosting, any user can inspect the compiled JavaScript bundle, extract the admin email and bypass keys (`BT-ADMIN-KEY-PRIMARY-7788`, `BT-ADMIN-KEY-SECONDARY-9900`), and forge administrative access.
- **Remediation:** Eliminate client-side backdoor keys. Implement standard HTTP-only cookie-based refresh tokens or standard Firebase Auth MFA sessions.

---

### 2.3. SEC-04: Client-Authoritative Pricing in Firestore Fallback
- **File:** [`apps/customer_app_flutter/lib/services/firestore_rest_client.dart` lines 428-437](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L428-L437)
- **Vulnerable Code:**
  ```dart
  final newBooking = {
    ...body,
    'id': bookingId,
    'bookingCode': bookingId,
    'status': body['status'] ?? 'CONFIRMED',
    'startOtp': startOtp,
    'endOtp': endOtp,
    'createdAt': DateTime.now().toIso8601String(),
  };
  await upsertDocument('bookings', bookingId, newBooking);
  ```
- **Analysis:**  
  In the Node.js backend ([`bookingController.js` lines 151-165](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/bookingController.js#L151-L165)), there is an authoritative price calculation engine that rejects client price tampering:
  ```javascript
  if (clientProvidedTotal !== null && Math.abs(clientProvidedTotal - calculatedGrandTotal) > 2.0) {
    console.warn(`🚨 Client price tampering detected! Enforcing backend price.`);
  }
  ```
  **HOWEVER**, when the app falls back to `FirestoreRestClient.dart`, **no such calculation exists**. Whatever `body['grandTotal']` or `body['basePrice']` the client sends is written directly into Cloud Firestore as the authoritative booking amount. An attacker using a modified APK or proxy could book a ₹1,299 AC installation for ₹1.00.
- **Remediation:** In Firestore-direct mode, Cloud Functions or Firestore Security Rules with numeric field validation (`request.resource.data.basePrice == ...`) must strictly validate prices.

---

### 2.4. SEC-05: Insecure Pseudo-Random OTP Generation
- **File:** [`apps/customer_app_flutter/lib/services/firestore_rest_client.dart` lines 423-427](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/services/firestore_rest_client.dart#L423-L427)
- **Vulnerable Code:**
  ```dart
  final rng = Random();
  final startOtp = (1000 + rng.nextInt(9000)).toString();
  final endOtp = (1000 + rng.nextInt(9000)).toString();
  ```
- **Analysis:**  
  Dart's default `Random()` is a linear congruential / Mersenne-twister style pseudo-random generator, **not cryptographically secure**. A malicious technician could predict future start/end OTPs from observed sequence values.
- **Remediation:** Use `Random.secure()` from `dart:math` or generate cryptographically secure OTPs on the server via `crypto.randomInt()`.

---

### 2.5. SEC-06: Secrets Exposed in Source Version Control (`render.yaml`)
- **File:** [`render.yaml` lines 29-42](file:///d:/BookurTechnician/render.yaml#L29-L42)
- **Exposed Variables:**
  - `ADMIN_SECRET_KEY`: `BookurAdminMaster2026#Secure!`
  - `EMAILJS_PUBLIC_KEY`: `hn2znBkgIi2lY8faY`
  - `EMAILJS_PRIVATE_KEY`: `DLj-DDHXaRY55ww2xu6Jg`
  - `EMAILJS_SERVICE_ID`: `service_u5wyepn`
  - `EMAILJS_TEMPLATE_ID`: `template_gl8uwjj`
- **Remediation:** Convert `render.yaml` to reference environment variables (`sync: false`) rather than committing plain-text keys in version control. Rotate EmailJS and Admin master keys immediately.

---

### 2.6. SEC-08: Customer PII / Address Exposed Prior to Assignment
- **Analysis:**  
  In the Node.js dispatch engine, [`automaticDispatchEngine.js` lines 126-137](file:///d:/BookurTechnician/backend/node-core-service/src/services/automaticDispatchEngine.js#L126-L137) implements `maskApproximateArea(fullAddress)` so candidate technicians only see "Birnagar, Nadia" prior to accepting.
  **HOWEVER**, in the direct Firestore fallback, the entire unmasked address (`Birnagar, Ranaghat - I, Nadia, West Bengal, 741127, India`) and full phone number (`+91 8145343534`) are written to the top-level `bookings` document immediately upon creation. If a technician reads the booking, the customer's exact home address and contact details are visible before any service agreement is formed.
- **Remediation:** Store exact address and phone in a private subcollection or separate document accessible only after `status == 'ACCEPTED'` and `technicianId == request.auth.uid`.

