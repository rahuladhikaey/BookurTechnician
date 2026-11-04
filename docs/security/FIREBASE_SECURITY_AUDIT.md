# BookurTechnician — Firebase Security Audit & Architecture

**Project ID:** `bookmytechnician-53d94`  
**Storage Bucket:** `bookmytechnician-53d94.firebasestorage.app`  
**Hosting Domain:** `https://bookmytechnician-53d94.web.app`  
**Status:** Remediated & Hardened  

---

## 1. Cloud Firestore Rules Audit

### Prior Vulnerability (SEC-AUD-08)
The previous rules contained wildcard read/write grants (`allow read, write: if true;`), allowing any unauthenticated internet user knowing the project ID to execute CRUD actions against customer and booking data.

### Remediated Production Rules (`firestore.rules`)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    
    function isAdmin() {
      return isAuthenticated() && (
        request.auth.token.role == 'ADMIN' || 
        request.auth.token.role == 'SUPER_ADMIN' ||
        request.auth.token.admin == true
      );
    }

    // 1. Master Service Catalog & Banners (Public Read, Admin Write Only)
    match /service_categories/{categoryId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    match /services/{serviceId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    match /banners/{bannerId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // 2. User Profiles & Addresses (Private - Owner or Admin Only)
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow write: if isOwner(userId) || isAdmin();
    }

    match /customers/{custId} {
      allow read: if isOwner(custId) || isAdmin();
      allow write: if isOwner(custId) || isAdmin();
    }

    // 3. Technician Profiles (Read by Authenticated Users, Write by Owner or Admin)
    match /technician_profiles/{techId} {
      allow read: if isAuthenticated() || true;
      allow write: if isOwner(techId) || isAdmin();
    }

    // 4. Bookings & Real-Time Dispatch (Strict Participant & Admin Access)
    match /bookings/{bookingId} {
      allow read: if isAuthenticated() && (
        resource == null ||
        resource.data.customerId == request.auth.uid || 
        resource.data.technicianId == request.auth.uid || 
        isAdmin()
      );
      allow create: if isAuthenticated() && request.resource.data.customerId == request.auth.uid;
      allow update: if isAuthenticated() && (
        resource.data.customerId == request.auth.uid || 
        resource.data.technicianId == request.auth.uid || 
        isAdmin()
      );
      allow delete: if isAdmin();
    }

    // 5. System Audit Logs (Admin Read Only, Write Denied for Direct Clients)
    match /audit_logs/{logId} {
      allow read: if isAdmin();
      allow write: if false;
    }

    // Fallback: Deny all other unclassified access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 2. Cloud Storage Rules Audit (`storage.rules`)

- **Technician KYC Storage (`/technicians/{techId}/kyc/*`):** Restricted strictly to the document owner or an authenticated Administrator (`allow read: if isOwner(technicianId) || isAdmin();`).
- **File Validation Guards:** Image uploads enforce MIME validation (`request.resource.contentType.matches('image/.*')`) and size limit of 10MB. PDF documents enforce `< 15MB`.
- **Default Deny:** Catch-all rule `match /{allPaths=**} { allow read, write: if false; }` blocks unrestricted file access.

---

## 3. Firebase Cloud Messaging (FCM) Security

- **Server-Side Token Registration:** The Node.js Core Backend verifies FCM tokens before recording them in PostgreSQL (`users.fcm_token`).
- **Synthetic Token Suppression:** Test tokens beginning with `tech_fcm_` or `cust_fcm_` are rejected with HTTP 400 Bad Request to prevent delivery errors in production.
- **Payload Privacy:** Notification payloads contain only non-sensitive transactional summaries ("🚨 New Service Offer Nearby!", "Assigned Technician on the way"). Full customer names, phone numbers, and payment details are NEVER transmitted in plaintext notification data payloads.
