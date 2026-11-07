# Google Sign-In & Android Firebase Registration Verification

**Date:** 2026-11-07  
**Firebase Project:** `bookmytechnician-53d94` (Project Number `946427465815`)  
**Package Names:**
* Customer App: `com.booktechnician.customer` (App ID `1:946427465815:android:2fc570b9e9e9108a54d312`)
* Technician App: `com.booktechnician.technician` (App ID `1:946427465815:android:9f46258e7601915a54d312`)

---

## 1. Keystore Fingerprints

Extracted directly from the local developer debug keystore (`~/.android/debug.keystore`):

* **Debug SHA-1:** `9D:8D:1E:EF:8E:8B:21:6A:90:C2:CC:D5:B3:A5:ED:77:97:17:88:D8`
* **Debug SHA-256:** `4D:50:BF:57:77:3A:E3:88:1F:02:31:E2:1E:7F:CF:E3:C5:A1:EB:FE:89:EC:11:5F:5C:CB:D6:E3:30:40:54:4B`

---

## 2. Firebase Android Registration & Live OAuth Clients

Both fingerprints were registered in Firebase using the official Firebase Management API (`firebase_create_android_sha`).

### Generated OAuth 2.0 Clients
* **Customer Android OAuth Client:** `946427465815-5oij64ur613235o4holpjaomvpuoi769.apps.googleusercontent.com`
* **Technician Android OAuth Client:** `946427465815-ebgh94pf70h171a7a9g3kkm5b06d649v.apps.googleusercontent.com`
* **Web OAuth Client (Server-side verification):** `946427465815-bh7rle8dgn2s4c41c19l2tkrakcdcm7a.apps.googleusercontent.com`

---

## 3. Configuration Sync Status

* **Customer `google-services.json`:** Synchronized with active OAuth clients and API keys at [google-services.json](file:///d:/BookurTechnician/apps/customer_app_flutter/android/app/google-services.json).
* **Technician `google-services.json`:** Synchronized with active OAuth clients and API keys at [google-services.json](file:///d:/BookurTechnician/apps/technician_app/android/app/google-services.json).

---

## 4. Gap Analysis: Missing Client SDK Implementation

While the Firebase project and `google-services.json` configuration are 100% ready for Google Sign-In:

1. **Missing Package:** Neither `apps/customer_app_flutter/pubspec.yaml` nor `apps/technician_app/pubspec.yaml` includes the `google_sign_in` package.
2. **Missing UI Flow:** Neither application currently has a "Sign in with Google" button on its login screen. Authentication currently operates via Phone & Email OTP.
3. **Play App Signing Note:** When building release `.aab` bundles for Google Play Store, the Play App Signing SHA-1 fingerprint must be extracted from Google Play Console (Release > Setup > App signing) and added to Firebase, otherwise release builds will throw Google Sign-In error `10` (`DEVELOPER_ERROR`).

