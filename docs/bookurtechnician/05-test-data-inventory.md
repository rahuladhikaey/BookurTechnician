# BOOKURTECHNICIAN — COMPLETE FORENSIC ARCHITECTURE AUDIT
## Document 05: Test Data, Mock Records & Synthetic Seed Inventory

**Audit Date:** November 7, 2026  
**Auditor Roles:** Database Security Auditor, Backend Data Architect  
**Investigation Target:** BUG 3 — "Fake test data: Identify test customers, technicians, services, bookings and related records. Only produce a read-only inventory. Do not delete anything."

---

## 1. Executive Summary & Inventory Guidelines

This inventory distinguishes between:
1. **Real Production Assets:** Master service categories, approved services, production catalog pricing.
2. **Real Physical Test Records:** Real device test accounts created by the founder/developer during live field tests (e.g., Technician Ram `+91 9883637054`, Customer Rahul Adhikary `+91 8145343534`).
3. **Synthetic / Mock / Shell Records:** Generated placeholder accounts, mock bookings, and automated test audit entries that must be cataloged prior to production go-live.

> [!IMPORTANT]
> **READ-ONLY AUDIT POLICY ENFORCED:**  
> Per prompt instructions, **no database records, user accounts, or collection documents have been deleted or modified**. This is an inventory and risk analysis only.

---

## 2. Cloud Firestore (`bookmytechnician-53d94`) Inventory

Direct forensic inspection of Cloud Firestore collections via REST API reveals the following document distribution:

### 2.1. Collection: `technician_profiles` (Total: 4 Documents)

| Document ID | Full Name | Phone | Categories / Skills | Status | Classification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tech_9883637054` | Ram | `+91 9883637054` | AC Services (8 verified skills: `ac_install`, `ac_deep_cleaning`, etc.) | `isOnline: true`, `isApproved: true`, `accountStatus: 'APPROVED'` | **Real Physical Test Device** (Ranaghat test phone) |
| `tech_partner_01` | Service Partner | `+91 9883637054` | AC Services | `isOnline: true`, `isApproved: true` | **Synthetic Seed / Dummy** |
| `tech_1793880481199`| Unnamed | Empty | General | `accountStatus: 'Pending_Verification'` | **Incomplete Registration Shell** |
| `tech_1793880511310`| Unnamed | Empty | General | `accountStatus: 'Pending_Verification'` | **Incomplete Registration Shell** |

- **Deletion Risk Analysis:**
  - `tech_9883637054`: Do **NOT** delete without user approval. This is the founder's active testing device and contains verified skills.
  - `tech_partner_01`: Safe to purge. Synthetic baseline record.
  - `tech_1793880481199`, `tech_1793880511310`: Safe to purge. Abandoned signup shells created during connection testing.

### 2.2. Collection: `bookings` (Total: 2 Documents)

| Document ID | Customer Name | Phone | Service Booked | Amount | Status | Classification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `bkg_1793789038012` | Rahul Adhikary | `+91 8145343534` | AC installation | ₹1,532.82 | `CONFIRMED` (tech: `null`) | **Real Field Test Booking** (Nov 4, 16:13 IST) |
| `BK-219924` | (Empty Name) | (Empty) | (Empty) | ₹0.00 | `CONFIRMED` | **Synthetic Mock Booking** |

- **Deletion Risk Analysis:**
  - `BK-219924`: Safe to purge. Malformed synthetic booking created during socket testing.
  - `bkg_1793789038012`: Contains real field test coordinates and customer phone. Safe to archive or purge prior to final production store launch.

### 2.3. Collection: `users` (Total: 1 Document)

| Document ID | Full Name | Email | Phone | Role | Classification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `admin-master-001` | System Administrator | `admin@bookurtechnician.com` | `+919999999999` | `SUPER_ADMIN` | **System Super Admin** |

- **Deletion Risk Analysis:** **DO NOT DELETE**. This is the root administrator identity required for Admin Panel login.

### 2.4. Collection: `service_categories` (Total: 8 Documents)
- `cat_ac` (AC Services - 17 services)
- `cat_appliances` (Home Appliances - 9 services)
- `cat_cctv` (CCTV & Security - 6 services)
- `cat_computer` (Laptop & Computer - 8 services)
- `cat_electrical` (Electrical Services - 24 services)
- `cat_plumbing` (Plumbing Services - 18 services)
- `cat_cleaning` (Cleaning & Pest - 10 services)
- `cat_carpentry` (Carpentry - 8 services)
- **Classification:** **REAL PRODUCTION MASTER CATALOG**. Do **NOT** delete.

### 2.5. Collection: `services` (Total: 100 Documents)
- Master service items (`ac_install`, `fan_rep`, `switch_rep`, etc.).
- **Classification:** **REAL PRODUCTION MASTER CATALOG**. Do **NOT** delete.

### 2.6. Collection: `dispatch_audit_logs` (Total: 100 Documents)
- Documents named `daudit_00004706-62f`, `daudit_012ba160-780`, etc.
- Generated automatically by test scripts running `automaticDispatchEngine.js`.
- **Classification:** **SYNTHETIC TEST LOGS**. Safe to purge for clean production launch.

### 2.7. Empty Collections
- `customers`: 0 documents
- `banners`: 0 documents
- `presence`: 0 documents
- `dispatch_requests`: 0 documents
- `audit_logs`: 0 documents

---

## 3. Codebase Hardcoded Mock / Test Data Inventory

### 3.1. Node.js Backend Hardcoded References
1. **Fallback Mock Dispatch Queries:**
   - In [`backend/node-core-service/src/controllers/bookingController.js` lines 213-234](file:///d:/BookurTechnician/backend/node-core-service/src/controllers/bookingController.js#L213-L234):
     When Postgres spatial query returns 0 candidates, it runs a fallback query searching for any profile with `is_online = true OR is_approved = true`.
2. **Hardcoded Admin Credentials:**
   - In [`backend/node-core-service/render.yaml` line 30](file:///d:/BookurTechnician/render.yaml#L30):
     `ADMIN_SECRET_KEY: BookurAdminMaster2026#Secure!`
   - In [`apps/admin_panel/src/api/apiClient.js` line 107](file:///d:/BookurTechnician/apps/admin_panel/src/api/apiClient.js#L107):
     `directAdminAccess('admin@bookurtechnician.com', 'BT-ADMIN-KEY-PRIMARY-7788', 'BT-ADMIN-KEY-SECONDARY-9900')`

### 3.2. React Admin Panel Test Fallbacks
1. In [`apps/admin_panel/src/features/payouts/FinancialSettlementPortal.jsx` line 208](file:///d:/BookurTechnician/apps/admin_panel/src/features/payouts/FinancialSettlementPortal.jsx#L208):
   `tx.utrReference || 'UTR-MOCK-7788'`
2. In [`apps/admin_panel/src/App.jsx` line 87](file:///d:/BookurTechnician/apps/admin_panel/src/App.jsx#L87):
   `token && !token.startsWith('bt_mock_')`
   Supports a legacy mock token prefix `bt_mock_` for offline UI testing.

### 3.3. Flutter Customer App Placeholder Images
1. In [`apps/customer_app_flutter/lib/screens/catalog_screens.dart` line 372](file:///d:/BookurTechnician/apps/customer_app_flutter/lib/screens/catalog_screens.dart#L372):
   Unsplash fallback image URL: `https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop` when a service has an empty `imageUrl`. (Our recent fix added a branded vector gradient header so broken Unsplash URLs never cause visual defects).

---

## 4. Deletion Risk Assessment & Safe Purge Protocol

Prior to production public launch, the following clean-slate protocol is recommended:

```
+-------------------------------------------------------------------------------+
|                         SAFE CLEAN-SLATE PURGE ORDER                          |
+-------------------------------------------------------------------------------+
| 1. PURGE (Safe):                                                              |
|    - Cloud Firestore 'dispatch_audit_logs' (100 synthetic test records)       |
|    - Cloud Firestore 'bookings/BK-219924' (Malformed test booking)            |
|    - Cloud Firestore 'technician_profiles/tech_partner_01' (Synthetic seed)  |
|    - Cloud Firestore shells: 'tech_1793880481199', 'tech_1793880511310'       |
|                                                                               |
| 2. REVIEW & PRESERVE (Founder Decision):                                      |
|    - 'technician_profiles/tech_9883637054' (Ram - Active founder test device)|
|    - 'bookings/bkg_1793789038012' (Rahul - Field test booking)                |
|                                                                               |
| 3. STRICTLY PRESERVE (Mission Critical):                                      |
|    - 'users/admin-master-001' (Super Admin Account)                           |
|    - 'service_categories' (All 8 master categories)                           |
|    - 'services' (All 100 master services)                                     |
+-------------------------------------------------------------------------------+
```

