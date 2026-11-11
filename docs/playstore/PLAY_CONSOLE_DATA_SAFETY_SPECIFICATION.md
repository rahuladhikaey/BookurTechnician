# GOOGLE PLAY CONSOLE DATA SAFETY SECTION SPECIFICATION
## BookurTechnician (Customer App) & BookurTechnician Partner (Technician App)
**Compliance Standard:** Google Play User Data Policy & India Digital Personal Data Protection Act, 2023 (DPDP Act 2023).

Google Play Console requires developers to declare all user data collected and/or shared by their applications. Below is the exact, comprehensive breakdown to fill in each section of the Google Play Console Data Safety questionnaire.

---

# SECTION 1: GLOBAL DATA PRACTICES OVERVIEW

| Question in Play Console | Answer | Legal / Technical Justification |
|---|---|---|
| **Does your app collect or share any of the required user data types?** | **Yes** | The app collects identity, location, and device telemetry to facilitate hyperlocal doorstep services. |
| **Is all user data collected by your app encrypted in transit?** | **Yes** | All network traffic strictly uses TLS 1.3 / HTTPS with modern cipher suites and certificate validation. |
| **Do you provide a way for users to request that their data be deleted?** | **Yes** | In-app deletion via Profile > Settings > Delete Account, plus a public web deletion URL at `https://bookurtechnician.online/delete-account`. |
| **Does your app allow users to create an account?** | **Yes** | Mobile phone OTP-based authentication. |
| **Is account creation optional or mandatory?** | **Mandatory** | Account creation is required to assign technicians, process payments, and ensure doorstep safety. |
| **Can users request account deletion within the app and via a web link?** | **Yes** | Both in-app and external web deletion URLs are active. |

---

# SECTION 2: DATA TYPES COLLECTED & SHARED TABLE

### 1. Location Data
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **Approximate Location** | **Yes** | **No** | Stored during active session | Required | • App functionality (Catalog availability, regional pricing)<br>• Fraud prevention & security |
| **Precise Location (GPS)** | **Yes** | **Shared with assigned technician only** | Stored (with timestamp) | Required | • App functionality (Matching nearest technician, live navigation & ETA)<br>• Fraud prevention & security (Ensuring technician is physically at customer door) |

*DPDP / Play Policy Note:* Customer precise location is never shared with the public or other customers; it is strictly shared with the single assigned technician partner for the duration of an active service booking.

---

### 2. Personal Information
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **Name** | **Yes** | **Shared with assigned technician** | Stored | Required | • App functionality (Technician greeting, invoice generation)<br>• Account management |
| **Email Address** | **Yes** | **No** | Stored | Optional / Required for invoices | • App functionality (Tax invoices, booking confirmations)<br>• Developer communications<br>• Account management |
| **Phone Number** | **Yes** | **Shared via Masked Relay** | Stored | Required | • App functionality (OTP login, technician arrival coordination)<br>• Account management<br>• Fraud prevention & security |
| **Address** | **Yes** | **Shared with assigned technician** | Stored | Required | • App functionality (Doorstep service delivery, route calculation) |
| **User IDs** | **Yes** | **No** | Stored | Required | • App functionality (Canonical account linking)<br>• Analytics |

*DPDP / Play Policy Note:* Phone numbers are masked through a secure cloud telephony bridge during customer-technician calls to prevent personal phone disclosure.

---

### 3. Financial Information
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **User Payment Info** | **Processed directly by Payment Gateway (Razorpay)** | **Shared with Payment Gateway (Razorpay)** | Ephemeral / Not stored on app servers | Required for online checkout | • App functionality (Order payment, refunds, GST invoicing)<br>• Fraud prevention & security |
| **Bank Account / UPI ID (Technician Partner App Only)** | **Yes** | **Shared with Payout Gateway** | Stored in encrypted vault (AES-256) | Required for technician payouts | • App functionality (Weekly earnings transfer, service compensation)<br>• Account management |

*PCI-DSS & RBI Note:* Full debit/credit card numbers and CVVs are NEVER captured, processed, or stored on BookurTechnician servers. All card transactions use PCI-DSS Level 1 compliant tokenized checkout provided by RBI-authorized payment aggregators (Razorpay).

---

### 4. Photos and Videos
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **Photos** | **Yes** | **Shared with assigned technician / admin** | Stored in private storage bucket | Optional (Customer) / Required (Technician KYC) | • App functionality (Customer uploads appliance fault photos; Technician uploads profile picture & job completion proof)<br>• Fraud prevention (KYC verification) |

---

### 5. Audio Files
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **Voice / Sound Recordings** | **Yes** (Customer support calls / Voice notes) | **No** | Stored temporarily | Optional | • App functionality (Customer voice description of defect)<br>• Customer support & dispute resolution |

---

### 6. App Activity & Performance
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **App Interactions** | **Yes** | **No** | Stored | Optional | • Analytics (Improving search & booking flow) |
| **Crash Logs** | **Yes** (Firebase Crashlytics) | **No** | Stored | Optional | • Analytics & App stability |
| **Diagnostics / Performance** | **Yes** | **No** | Stored | Optional | • Analytics (API latency tracking, Firestore 429 telemetry) |

---

### 7. Device or Other Identifiers
| Field in Console | Collected? | Shared? | Ephemeral / Stored? | Required / Optional? | Purposes Selected in Console |
|---|---|---|---|---|---|
| **Device or other IDs** | **Yes** (FCM Push Token, Android ID) | **Shared with FCM (Google)** | Stored | Required | • App functionality (Push alerts for incoming jobs, booking updates)<br>• Fraud prevention & device binding |

---

# SECTION 3: THIRD-PARTY SDK DECLARATIONS

| SDK Name | Vendor | Purpose | Data Handled | Link to SDK Privacy Policy |
|---|---|---|---|---|
| **Firebase Cloud Messaging (FCM)** | Google LLC | Push Notifications & Live Alerts | FCM Device Token, Booking Event Payloads | https://policies.google.com/privacy |
| **Firebase Cloud Firestore** | Google LLC | Real-time database & sync | Encrypted booking states, profile projection | https://policies.google.com/privacy |
| **Razorpay SDK** | Razorpay Software Pvt Ltd | In-app Payment Processing | Transaction ID, Amount, Payment Method | https://razorpay.com/privacy/ |
| **Google Maps SDK** | Google LLC | Map display & Geocoding | Coordinate telemetry, Map tiles | https://policies.google.com/privacy |
| **EmailJS / Brevo** | EmailJS / Sendinblue | Transactional OTP & Invoices | Email address, User first name, OTP | https://www.emailjs.com/legal/privacy-policy/ |

---

# SECTION 4: ACCOUNT DELETION URL & IN-APP MECHANISM (MANDATORY GOOGLE PLAY REQUIREMENT)

Google Play Developer Policy requires all apps that allow account creation to provide both:
1. **In-App Account Deletion Path:**  
   Navigate to: `Bottom Navigation > Profile > Settings > Privacy Center > Delete Account`.
2. **Web-Based Account Deletion URL:**  
   Direct Public URL: `https://bookurtechnician.online/delete-account`  
   *Requirements Satisfied:* Users can request total account and data wipe without reinstalling the app. All personal data, location history, and profile records are expunged within 30 days in strict accordance with the DPDP Act 2023.

