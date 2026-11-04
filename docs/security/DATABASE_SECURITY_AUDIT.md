# BookurTechnician — Database Security Audit

**Databases:** PostgreSQL (PostGIS extension), Redis (Cluster/Standalone), Cloud Firestore  
**Standard:** CIS PostgreSQL Benchmark & OWASP Top 10  
**Status:** Audited & Hardened  

---

## 1. PostgreSQL & PostGIS Security

### A. SQL Injection Vulnerability Analysis
- **Finding:** The entire database query layer was scanned for string concatenation and template literal injection (`${...}`) within SQL statements.
- **Result:** Zero instances of dynamic string concatenation were found. 100% of database interactions in `adminController.js`, `bookingController.js`, `customerController.js`, `technicianController.js`, and `postgresSpatialScanner.js` strictly use parameterized queries with positional parameters (`$1, $2, ...`).

Example of parameterized PostGIS query:
```javascript
const queryText = `
  SELECT id, full_name, phone, rating,
         ST_Distance(
           current_location,
           ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
         ) as distance_meters
  FROM technician_profiles
  WHERE is_online = true
    AND ST_DWithin(
          current_location,
          ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
          $3
        )
`;
const params = [custLat, custLng, radiusMeters];
const res = await postgres.query(queryText, params);
```

### B. Connection Security & Pooling
- **TLS Enforcement:** Connections in production utilize TLS/SSL encryption.
- **Connection Pool:** Managed via `pg.Pool` with connection timeout (5000ms), idle timeout (30000ms), and max pool size (20) to prevent denial of service from connection exhaustion.

---

## 2. Redis Cache Security

### A. Network Isolation
- Redis is bound strictly to localhost (`127.0.0.1`) or private cloud VPC subnet. It is never exposed to public internet interfaces.
- Protected by `REDIS_PASSWORD` when operating in networked production environments.

### B. Ephemeral Data & Key Expiration
- **OTP Records:** Strictly scoped to 10-minute TTL (`redis.setWithExpiry('otp:...', payload, 600)`).
- **Anti-Brute-Force Counters:** 15-minute TTL (`redis.setWithExpiry('otp_fail:...', count, 900)`).
- **Dispatch Sessions:** Active dispatch state is persisted authoritatively in PostgreSQL (`bookings` and `dispatch_audit_logs`); Redis acts purely as a low-latency geo-index (`GEOADD`, `GEORADIUS`). Financial records are never stored exclusively in Redis.

---

## 3. Data Retention & Privacy Compliance

- **Account Deletion:** Anonymizes phone (`+91-XXXXXX1234`) and email (`deleted_<id>@deleted.bookurtechnician.com`). Clears device tokens and customer addresses.
- **Financial Records Retention:** Section 133 of the Companies Act and statutory GST laws mandate retaining financial invoices (`invoices`) and ledger transactions (`wallet_transactions`, `ledger_transactions`) for 8 years. These are kept in immutable, anonymized state.
