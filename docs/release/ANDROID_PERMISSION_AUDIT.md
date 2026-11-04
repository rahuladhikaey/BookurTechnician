# BOOKURTECHNICIAN — ANDROID PERMISSION & PRIVACY AUDIT

This comprehensive permission audit covers the merged manifests of both Android applications:
- **Customer App:** `com.booktechnician.customer`
- **Technician Partner App:** `com.booktechnician.technician`

---

## 1. Customer Application (`com.booktechnician.customer`)

| Permission | Feature / Screen | Mandatory / Optional | When Requested | Behavior on Denial | Data Transmission & Storage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `android.permission.INTERNET` | All network features (Catalog discovery, booking creation, Socket.IO live tracking, payment) | **Mandatory** | Install time (Normal permission) | App cannot communicate with backend; offline cached catalog and retry prompt shown. | Encrypted TLS 1.3 payload transmitted to `bookurtechnician.online` & Firebase Cloud Firestore. |
| `android.permission.ACCESS_FINE_LOCATION` | Address Picker, Home Screen Nearby Availability Radar, Checkout Address Selection | **Optional** (Manual address entry supported) | When customer taps "Use Current Location" on Map or Cart Screen | Falls back gracefully to manual address entry, landmark input, and city/pincode selection. | Latitude/Longitude coordinates transmitted to PostGIS backend only when saving a service address. |
| `android.permission.ACCESS_COARSE_LOCATION` | City-level service availability radar | **Optional** | Prompted alongside fine location on Android 12+ (API 31+) | Allows city-level catalog browsing without precise doorstep coordinates. | Transmitted only as generalized district coordinate. |
| `android.permission.POST_NOTIFICATIONS` | Booking assignment alerts, arrival alerts, Start/End OTP delivery, invoice download | **Optional** | Prompted on Android 13+ (API 33+) upon first booking submission | Push notifications are not shown; in-app real-time status updates and SMS/Email OTP fallbacks still deliver OTP. | Device FCM token registered securely in backend database; never shared with third parties. |

> [!NOTE]
> **No Background Location:** The Customer App **never** requests `ACCESS_BACKGROUND_LOCATION`. GPS access terminates immediately when the app is minimized or closed.

---

## 2. Technician Partner Application (`com.booktechnician.technician`)

| Permission | Feature / Screen | Mandatory / Optional | When Requested | Behavior on Denial | Data Transmission & Storage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `android.permission.INTERNET` | Duty state sync, dispatch proposals, real-time Socket.IO GPS streaming, wallet settlements | **Mandatory** | Install time | App cannot communicate with dispatch engine; partner placed in offline mode. | Encrypted TLS 1.3 payload transmitted to backend & Cloud Firestore. |
| `android.permission.ACCESS_FINE_LOCATION` | Doorstep navigation, 500m geofence arrival check, nearby dispatch offer scoring | **Mandatory while On Duty** | When partner toggles status to "GO ON DUTY" | Partner cannot go On Duty for instant nearby dispatches; prompted with an explanation dialog. | GPS coordinates streamed to private `booking:<id>` room only during active transit. |
| `android.permission.ACCESS_COARSE_LOCATION` | Approximate locality discovery | **Mandatory** | Combined with Fine Location dialog | Partner receives only approximate area alerts. | Transmitted as cellular/Wi-Fi triangulated coordinates. |
| `android.permission.ACCESS_BACKGROUND_LOCATION` | Background incoming job alerts and customer transit tracking while navigating | **Mandatory while On Duty** | Step-by-step prominent disclosure dialog after foreground location permission | Background location updates cease; partner receives alerts only while app is open on screen. | Transmitted solely to active assigned customer room; halts immediately upon job completion or toggling Off Duty. |
| `android.permission.FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_LOCATION` | Persistent Android Foreground Service (`BackgroundService`) with ongoing notification | **Mandatory while On Duty** | Automatically activated when partner taps "GO ON DUTY" | Android OS will terminate background GPS sync when memory is constrained. | Active service displays persistent Android notification "BookUrTechnician Partner • On Duty". |
| `android.permission.POST_NOTIFICATIONS` | High-priority 20-second incoming job alarms, earnings credit notifications | **Mandatory** | Onboarding / Login | Audible alarm notifications will not pop up; partner may miss incoming dispatch proposals. | FCM registration token stored in PostgreSQL `technician_profiles`. |
| `android.permission.USE_FULL_SCREEN_INTENT` & `TURN_SCREEN_ON` | Full-screen incoming service siren dialog when phone screen is locked or asleep | **Mandatory for Uber-style alerts** | Installed / runtime manifest capability | Partner hears audio chime but screen does not wake automatically; must unlock manually. | Local device intent only; zero telemetry transmitted. |
| `android.permission.VIBRATE` & `WAKE_LOCK` | Haptic vibration pattern during incoming 20s offer and preventing CPU sleep | **Optional** | Automatic runtime invocation during offer window | Phone will not vibrate during incoming job offers. | Local hardware control only. |
| `android.permission.CAMERA` | KYC document capture (Aadhaar/Voter Card) and mandatory after-service Proof of Work photo | **Mandatory for Job Proof & KYC** | When technician taps "Take Photo" in KYC or Completion screen | Technician cannot complete KYC or verify after-service photo proof without camera access. | Images uploaded to encrypted Firebase Storage bucket (`bookmytechnician-53d94.firebasestorage.app`). |

---

## 3. Google Play & Indus Appstore Policy Compliance Checklist

1. **Prominent Background Location Disclosure:**  
   The Technician App presents an explicit in-app prompt prior to requesting `ACCESS_BACKGROUND_LOCATION`, detailing that location is accessed in the background *only while On Duty* to enable customer ETA updates and doorstep geofencing.
2. **Foreground Service Types:**  
   In compliance with Android 14+ (API 34/35/36) Google Play requirements, the foreground service declares `android:foregroundServiceType="location"`, directly aligned with the live transit tracking feature.
3. **No Unused Permissions:**  
   Neither application requests `READ_CONTACTS`, `READ_CALL_LOG`, `PROCESS_OUTGOING_CALLS`, `READ_EXTERNAL_STORAGE` (unrestricted), or `RECORD_AUDIO`. Android's modern photo picker (`image_picker`) and direct camera intents are utilized exclusively.

