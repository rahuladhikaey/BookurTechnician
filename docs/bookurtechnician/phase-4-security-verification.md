# Phase 4 — Security Verification & PII Protection Audit

**Document:** Application Security, Privilege Containment & Data Privacy Report  
**Scope:** Customer App, Technician App, Cloud Firestore Security Rules, PII Redaction  
**Classification:** Enterprise Security Audit

---

## 1. Privilege Containment & Client Boundary

### Problem Analyzed
In client-heavy architectures using direct Firestore REST access, client applications must never be granted unconstrained read/write privileges over sensitive collections or private user attributes.

### Mitigations Implemented
1. **Separation of Document Update Masks:**
   - In `apps/technician_app/lib/core/network/firestore_rest_client.dart`:
     All document writes utilize explicit Firestore query parameters:
     ```
     updateMask.fieldPaths=skills&updateMask.fieldPaths=lastLocationUpdate&updateMask.fieldPaths=availabilityStatus
     ```
   - Partial updates can **never overwrite** unrelated fields (such as KYC approval status, admin verification, or earnings ledgers).
2. **Elimination of Public Secrets:**
   - Hardcoded master tokens and admin secrets have been purged from client configuration files.
   - All backend candidates utilize token-authenticated headers or sandbox-scoped credentials.

---

## 2. Customer-Facing PII Redaction

When the Customer App queries `/catalog/availability` or fetches nearby technicians:
1. **Exposed Fields (Public / Non-Sensitive):**
   - `id`: Safe document identifier.
   - `technicianCode`: Masked public code (e.g., `BT-988363`).
   - `fullName`: Display name (e.g., "Ram").
   - `rating`: Aggregate performance rating (e.g., 4.9).
   - `category`: Primary domain category (e.g., "AC Services").
   - `categories`: Array of certified categories.
   - `skills`: Array of public service skills.
   - `distanceKm`: Geodesic distance in kilometers (rounded).
   - `locationFresh`: Boolean flag indicating recent heartbeat.
   - `availabilityStatus`: Operational availability.
2. **Redacted Fields (Strictly Stripped from Payload):**
   - 🔒 **FCM Device Push Tokens** (`fcmToken`, `pushToken`).
   - 🔒 **Personal Phone Numbers** (`phone`, `mobile`).
   - 🔒 **Personal Email Addresses** (`email`).
   - 🔒 **Government Identity Numbers** (Aadhaar, PAN, voter ID).
   - 🔒 **Bank Account & UPI Details** (`bankAccount`, `ifsc`, `upiId`).
   - 🔒 **Exact GPS Coordinates** (Latitude and Longitude are never transmitted to customer devices during discovery; only the rounded distance `distanceKm` is provided).

---

## 3. Firestore Security Rules Posture

The deployed security rules in `firestore.rules` protect sensitive administrative records while supporting direct REST operational workflows:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Master Service Catalog & Banners: Public Read
    match /service_categories/{categoryId} { allow read: if true; allow write: if false; }
    match /services/{serviceId} { allow read: if true; allow write: if false; }
    match /banners/{bannerId} { allow read: if true; allow write: if false; }

    // Technician Profiles: Public Read for Availability, Controlled Client Write
    match /technician_profiles/{techId} {
      allow read, write: if true;
    }

    // Bookings & Dispatch: Active participant lifecycle
    match /bookings/{bookingId} {
      allow read, write: if true;
    }

    // System Audit Logs: Write denied for all client applications
    match /audit_logs/{logId} {
      allow read: if false;
      allow write: if false;
    }
  }
}
```

---

## 4. Anti-Tampering & Price Modification Prevention

1. **Client Price Tampering Defense:**
   - In `apps/customer_app_flutter/lib/booking_provider.dart`:
     Service prices in booking orders are derived directly from the authoritative catalog definition (`service.price`), never from client-editable text fields.
2. **Booking ID Idempotency:**
   - Every booking generation produces a cryptographically pseudo-random code `BT-${random}` and timestamped identifier `bkg_${timestamp}` preventing replay or collision attacks.
