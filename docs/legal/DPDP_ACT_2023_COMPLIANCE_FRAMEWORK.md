# DIGITAL PERSONAL DATA PROTECTION ACT, 2023 (DPDP ACT)
## COMPREHENSIVE STATUTORY COMPLIANCE & TECHNICAL IMPLEMENTATION FRAMEWORK
**Entity:** BookurTechnician Technologies Private Limited  
**Applicability:** Digital Personal Data processed within the territory of India under Act No. 22 of 2023.  
**Role:** Data Fiduciary  
**Affected Data Principals:** Customers, Technician Partners, and Website Visitors.

---

## 1. Statutory Architecture & Definitions (DPDP Act, 2023)

In accordance with the Digital Personal Data Protection Act, 2023 enacted by the Parliament of India:
- **Data Fiduciary (Section 2(i)):** BookurTechnician Technologies Private Limited determines the purpose and means of processing personal data.
- **Data Principal (Section 2(j)):** The individual to whom the personal data relates (Customers booking services and Technician Partners offering services).
- **Personal Data (Section 2(t)):** Any data about an individual who is identifiable by or in relation to such data (e.g., name, phone number, GPS coordinates, vehicle registration, address, biometric/photo).
- **Processing (Section 2(x)):** An automated operation or set of operations performed on digital personal data (collection, recording, organization, structuring, storage, retrieval, use, disclosure, erasure).
- **Consent Manager (Section 6(7)):** Interoperable framework enabling Data Principals to give, manage, review, or withdraw consent.

---

## 2. Section 5 — Notice Prior to Seeking Consent

The DPDP Act mandates that every request for consent must be preceded or accompanied by a clear, itemized notice in plain language.

### A. Notice Requirements Enforced:
1. **Specific Personal Data Collected:** Phone number, full name, service address, real-time GPS coordinates, device identifiers, and payment transaction tokens.
2. **Specific Lawful Purpose:**
   - Hyperlocal matching with the nearest available verified technician.
   - Live turn-by-turn navigation and arrival tracking.
   - Masked telephone bridge communication (protecting personal numbers).
   - Invoicing, taxation compliance (GST Act), and 30-day warranty fulfillment.
3. **Manner of Exercising Rights:** Clear links to in-app settings and web portals where Data Principals can review, download, update, or erase their personal records.
4. **Grievance Redressal Mechanism:** Clear publication of the Grievance & Data Protection Officer’s name, email, physical address, and telephone contact.
5. **Right to Complain to the Board:** Express statement informing the Data Principal of their right to file a complaint with the **Data Protection Board of India (DPBI)**.

### B. Multi-Lingual Availability (Eighth Schedule to Constitution of India)
Section 5(3) requires the notice to be available in English or any of the 22 languages specified in the Eighth Schedule. BookurTechnician provides immediate native translations in:
- **English** (National standard)
- **Bengali (বাংলা)** (Primary regional operational language in West Bengal)
- **Hindi (हिन्दी)** (National lingua franca)

---

## 3. Section 6 — Lawful, Informed & Unconditional Consent

1. **Affirmative Action:** Consent is captured only via an explicit, unambiguous action (e.g., tapping "Agree and Continue" or checking an un-ticked box). No pre-checked boxes are used.
2. **Unbundled Consent:** Service terms and data processing consents are separated. Essential service fulfillment consent is strictly separated from optional marketing communications.
3. **Ease of Withdrawal (Section 6(4)):** The Data Principal may withdraw consent at any time as easily as giving it. In-app toggles in `Profile > Settings > Notifications / Privacy Center` permit immediate revocation of optional telemetry.
4. **Consent Logging:** Every consent event records the User UID, timestamp, IP address, terms version (`v1.0.1`), and consent state in an immutable audit table.

---

## 4. Section 8 — General Obligations of Data Fiduciary

1. **Reasonable Security Safeguards (Section 8(5)):**
   - **Encryption in Transit:** All client-server, socket, and database communications mandate TLS 1.3 / HTTPS with HSTS enabled.
   - **Encryption at Rest:** Storage databases (PostgreSQL, MongoDB, Cloud Storage) implement AES-256 encryption.
   - **Cryptographic Hashing:** Secrets, passwords, and OTP verification codes are hashed with SHA-256 / bcrypt before persisting; raw OTPs are NEVER written to disks or logs.
   - **Private Vault Architecture:** Technician Government IDs (Voter ID, Aadhaar, PAN) and financial details (UPI VPAs, bank account numbers) are held in an isolated private vault (`technician_private` collection) protected by least-privilege Firestore rules and backend authorization. Client applications NEVER receive raw unmasked KYC data.
2. **Personal Data Breach Notification (Section 8(6)):**
   - In the event of a personal data breach, BookurTechnician maintains an automated incident response protocol to notify:
     a) The **Data Protection Board of India (DPBI)** in the prescribed form and manner.
     b) Each affected Data Principal without undue delay, specifying the nature of the breach, affected data categories, potential consequences, and mitigation steps taken.
3. **Data Erasure & Purpose Completion (Section 8(7)):**
   - Personal data is retained only for the duration necessary to satisfy the purpose for which it was collected.
   - Non-statutory operational telemetry (e.g., granular GPS breadcrumbs) is automatically expunged after 90 days.
   - Tax and billing records are retained in an encrypted cold archive strictly for the period required by Indian taxation statutes (e.g., GST Section 36 — 72 months).

---

## 5. Section 9 — Processing of Personal Data of Children

1. **Age Gate:** The BookurTechnician Platform is strictly intended for individuals aged 18 and older. Registration requires explicit confirmation: `"I confirm I am 18 years of age or older"`.
2. **No Minor Processing:** The platform strictly prohibits processing personal data that is likely to cause any detrimental effect on the well-being of a child.
3. **No Behavioral Tracking / Targeted Ads:** BookurTechnician does not engage in behavioral monitoring, profiling, or targeted advertising directed at minors.

---

## 6. Sections 11, 12, 13 & 14 — Rights of Data Principals

### A. Right to Access Information (Section 11)
Data Principals have the right to obtain:
- A summary of personal data being processed.
- The identities of all other Data Fiduciaries and Data Processors with whom their personal data has been shared (e.g., Razorpay for payments, Google Cloud/Firebase for hosting).
- Any other information related to their personal data and processing.

### B. Right to Correction and Erasure (Section 12)
- **Correction:** Users can update their profile, saved addresses, and contact details directly within the app.
- **Erasure:** Users can initiate account deletion via:
  1. **In-App:** `Profile > Settings > Privacy Center > Delete Account`.
  2. **Web Portal:** `https://bookurtechnician.online/delete-account`.
  3. **Direct Email:** Writing to `privacy@bookurtechnician.com`.
  *Execution SLA:* Account is immediately deactivated; all personal data, address records, and profile details are permanently purged within 30 days unless retention is legally mandated.

### C. Right of Grievance Redressal (Section 13)
The designated Data Protection and Grievance Officer:
- **Officer Name:** Mr. Rahul Adhikary
- **Designation:** Chief Information Security Officer & Grievance Officer
- **Entity:** BookurTechnician Technologies Private Limited
- **Official Email:** `grievance@bookurtechnician.com` / `privacy@bookurtechnician.com`
- **Toll-Free Helpline:** `+91 98300 00000` (Mon–Sat, 10:00 AM – 6:00 PM IST)
- **Physical Address:** Salt Lake Sector V, Kolkata, West Bengal 700091, India
- **Acknowledgement SLA:** Within 24 hours of receipt.
- **Resolution SLA:** Formal resolution within 15 working days.

### D. Right to Nominate (Section 14)
Data Principals have the right to nominate another individual who, in the event of death or incapacity of the Data Principal, shall exercise their data protection rights. Nomination requests can be registered by emailing `grievance@bookurtechnician.com` with the nominee’s identity proof.

---

## 7. Data Protection Board of India (DPBI) Escalation
If a Data Principal is unsatisfied with the resolution provided by our Grievance Officer, they maintain the statutory right under Section 13(3) of the DPDP Act to file a complaint before the **Data Protection Board of India**.

