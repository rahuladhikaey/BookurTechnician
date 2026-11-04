# BookurTechnician — React Admin Panel Security Architecture

**Hosting:** Firebase Hosting (`https://bookmytechnician-53d94.web.app` / `https://admin.bookurtechnician.online`)  
**Backend:** Node.js Core API Gateway  
**Standard:** OWASP Top 10 Web Application Security  

---

## 1. Enterprise Role-Based Access Control (RBAC)

The administrative backend enforces seven segregated roles:

| Administrative Role | Permissions | Prohibited Operations |
|---|---|---|
| **SUPER_ADMIN** | Full system authority, configuration changes, database management | None |
| **OPERATIONS_ADMIN** | Live dispatch control, manual reassignment, operational analytics | System configuration, database purge |
| **BOOKING_MANAGER** | Booking lifecycle oversight, rescheduling, customer dispute review | Financial payouts, system settings |
| **VERIFICATION_ADMIN** | Technician KYC document review, skill verification, onboarding status | Financial payouts, database management |
| **FINANCE_ADMIN** | Payout queue processing, ledger reconciliation, withdrawal audit | Technician skill verification, system settings |
| **CUSTOMER_SUPPORT** | Support ticket resolution, masked phone calling | Financial payouts, role modifications |
| **READ_ONLY_AUDITOR** | Reporting, audit log review, compliance inspection | All state-modifying requests (`POST`, `PUT`, `PATCH`, `DELETE`) |

---

## 2. Authentication & Direct Access Hardening

- **No Substring Bypass:** Substring-based authorization checks have been eliminated. Only verified administrative identities matching configured server records are granted admin tokens.
- **Access Key Timing Security:** Administrative authentication keys are verified authoritatively on the backend using timing-safe comparisons where applicable.
- **Fail Closed:** Attempts to authenticate as an administrator with invalid credentials trigger a high-priority security alert in system logs and return HTTP 401 Unauthorized.

---

## 3. Web Application Hardening

### A. HTTP Security Headers
Every response served by the backend Gateway includes:
```http
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self' https: data: blob: 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https: wss: ws:; img-src 'self' https: data: blob:;
```

### B. Cross-Site Scripting (XSS) Prevention
- React JSX automatically escapes dynamic string bindings by default.
- Input sanitization middleware strips null-byte poisons and deletes prototype-polluting properties (`__proto__`, `constructor`, `prototype`).
- No raw user inputs are injected via `dangerouslySetInnerHTML`.

### C. Cross-Origin Resource Sharing (CORS)
- Production CORS explicitly allows verified domains and mobile origins.
- Wildcard permissions with credentials are disallowed in production deployments.
