# BOOKURTECHNICIAN — PRODUCTION RELEASE ARCHITECTURE

## 1. Executive Summary & Production Topology

BookurTechnician is an enterprise-grade, on-demand home services marketplace designed for sub-second technician discovery, automated Uber/Rapido-style dispatch, dual-OTP doorstep verification, and digital tax invoice fulfillment.

```mermaid
flowchart TD
    subgraph Client Apps
        CA["Customer App\n(Flutter • Android / Web)"]
        TA["Technician App\n(Flutter • Android)"]
        AP["Admin Panel\n(React 18 + Vite • Firebase Hosting)"]
    end

    subgraph Firebase Cloud [Project: bookmytechnician-53d94 (asia-south1)]
        FBA["Firebase Auth"]
        FCM["Firebase Cloud Messaging (FCM)"]
        FBS["Firebase Cloud Storage\n(kyc-documents, service-proofs)"]
        CFS["Cloud Firestore\n(Direct Fallback & Real-time Mirror)"]
        FBH["Firebase Hosting\n(https://bookmytechnician-53d94.web.app)"]
    end

    subgraph Core Backend [Node.js Express Cluster]
        API["Node.js Core API Gateway (Port 4000)"]
        ADE["Automatic Dispatch Engine\n(Progressive 3-5-10-15 km rings)"]
        SIO["Socket.IO Server\n(Private Booking Telemetry Rooms)"]
        PYAI["Python AI Matching Service (Port 8000)"]
    end

    subgraph Persistence Layer
        PG[("PostgreSQL 15 + PostGIS (AWS ap-south-1)\n17 Relational Tables + Spatial Geography")]
        RD[("Redis 7 (Distributed Locks & TTL)")]
    end

    subgraph External Infrastructure
        RZP["Razorpay Gateway (Payments & Payouts)"]
        GMAPS["Google Maps Platform (Geocoding & Matrix)"]
    end

    CA -->|HTTPS / REST| API
    CA -->|WSS / Socket.IO| SIO
    CA -->|Auth| FBA
    CA -->|Fallback Mirror| CFS

    TA -->|HTTPS / REST| API
    TA -->|Duty Location WSS| SIO
    TA -->|Duty Siren Alarms| FCM
    TA -->|KYC & Proofs| FBS

    AP -->|HTTPS / Admin API| API
    AP -->|Direct Firestore Fallback| CFS
    FBH -->|Serves Web SPA| AP

    API --> ADE
    API --> SIO
    ADE --> PYAI
    API --> PG
    API --> RD
    API --> RZP
    API --> GMAPS
    API --> FCM
```

---

## 2. Component Inventory & Production Specifications

| Component | Technology | Production Identity / ID | Host / Endpoint |
| :--- | :--- | :--- | :--- |
| **Customer App** | Flutter 3.44.9 / Dart 3.12.2 | `com.booktechnician.customer` | Android Play Store & Indus Appstore |
| **Technician App** | Flutter 3.44.9 / Dart 3.12.2 | `com.booktechnician.technician` | Android Play Store & Indus Appstore |
| **Admin Panel** | React 18, Vite 4.5.14 | Web SPA | `https://bookmytechnician-53d94.web.app` |
| **Core API Gateway** | Node.js 20 LTS, Express | `node-core-service` | Dedicated Production VM / Container |
| **AI Matchmaker** | Python 3.11, FastAPI | `python-ai-service` | `http://localhost:8000` / Cloud Run |
| **Primary Database** | PostgreSQL 15 + PostGIS | `bookurtechnician_prod` | `aws-0-ap-south-1.pooler.supabase.com:5432` |
| **Cloud Firestore** | NoSQL Document Store | `bookmytechnician-53d94` | `asia-south1` (Mumbai) |
| **Push Notifications** | Firebase Cloud Messaging (v1) | Project `946427465815` | Google FCM High-Priority API |
| **Media & Proofs** | Firebase Cloud Storage | Bucket `bookmytechnician-53d94.firebasestorage.app` | Google Cloud Storage Asia |
| **Payment Gateway** | Razorpay Node.js SDK | RBI-certified Aggregator | `api.razorpay.com` |

---

## 3. Communication Matrix & Security Protocols

### A. Authentication & Session Security
- **Customers & Technicians:** Authenticated via Firebase Phone Authentication & cryptographically secure 6-digit OTP verification. Session tokens issued as HMAC-SHA256 JWTs with 1-hour access validity and sliding 30-day refresh tokens.
- **Role-Based Access Control (RBAC):** Backend middleware strictly verifies `role` (`CUSTOMER`, `TECHNICIAN`, `SUPER_ADMIN`). Route access enforces strict ownership checks; customers can only access their own bookings, and technicians can only access assigned jobs.
- **Admin Authentication:** Strict multi-factor authentication with dedicated secure endpoints (`/api/v1/auth/verify-otp`, `/api/v1/admin/*`). Admin credentials and destructive purge endpoints are completely isolated from mobile builds.

### B. Real-Time Dispatch & Telemetry
- **Sequential 1-by-1 Dispatch:** When a booking is submitted, the backend ranks eligible domain technicians and emits an exclusive 20-second offer to the top-ranked partner.
- **Zero Customer PII Leakage:** While an offer is pending, the technician receives only the approximate neighborhood name (e.g., "Salt Lake Sector 5, Kolkata"), estimated payout (₹), and distance. Full customer phone number and exact street address are revealed **only after atomic offer acceptance**.
- **Atomic Concurrency Protection:** Acceptance routes execute within PostgreSQL transactions (`SELECT ... FOR UPDATE` and atomic assignment tables). Simultaneous acceptance attempts return exactly one `200 OK` and one `409 Conflict`.
- **Private Socket.IO Scoping:** GPS coordinates emitted by en-route technicians are broadcast solely to the specific booking's tracking room (`booking:<id>`). Unauthorized clients are blocked with `403 Forbidden`.

### C. Doorstep Lifecycle State Machine
```
PENDING / SEARCHING
       │ (Progressive Geo Rings: 3km -> 5km -> 10km -> 15km)
       ▼
ASSIGNED / TECHNICIAN_ASSIGNED
       │ (Customer views live ETA & transit map)
       ▼
TECHNICIAN_ARRIVED (Automated 500m geofence check)
       │ (Customer provides 4-digit Start OTP)
       ▼
IN_PROGRESS / SERVICE_STARTED
       │ (Technician uploads Mandatory Proof of Work photos)
       ▼
COMPLETED (Customer provides 4-digit End OTP)
       │ (Atomic Wallet Credit + SAC 9987 Tax Invoice generated)
       ▼
30-DAY WARRANTY & MUTUAL RATINGS
```

---

## 4. Environment Variables & Production Secrets

The following environment variables are mandatory for deployment on the production host:

```bash
# Server & Port
NODE_ENV=production
PORT=4000
ALLOW_CLEAN_SLATE=false

# PostgreSQL Database (Supabase AWS ap-south-1)
DATABASE_URL=postgresql://postgres.hgjvwddlwofzpdurvpzd:YOUR_DB_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require
PG_MAX_POOL=25
PG_TIMEOUT_MS=8000

# Redis Cache & Locks
REDIS_URL=redis://default:YOUR_REDIS_PASSWORD@redis-prod.internal:6379

# Firebase Admin SDK
FIREBASE_PROJECT_ID=bookmytechnician-53d94
FIREBASE_STORAGE_BUCKET=bookmytechnician-53d94.firebasestorage.app
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}

# Razorpay Production API
RAZORPAY_KEY_ID=rzp_live_YOUR_LIVE_KEY
RAZORPAY_KEY_SECRET=YOUR_LIVE_SECRET
RAZORPAY_WEBHOOK_SECRET=YOUR_WEBHOOK_SECRET

# JWT Authentication
JWT_SECRET=YOUR_HIGH_ENTROPY_JWT_SECRET_256BIT
REFRESH_TOKEN_SECRET=YOUR_HIGH_ENTROPY_REFRESH_SECRET_256BIT

# Email & SMS (Production Notifications)
EMAILJS_SERVICE_ID=service_noexwvl
EMAILJS_TEMPLATE_ID=template_159x4wr
EMAILJS_PUBLIC_KEY=nQ7929H13pP08h5fN
```

---

## 5. Third-Party Compliance & Data Residency

- **Data Residency:** All core database instances and Firebase Cloud Firestore instances are hosted within Indian territory (`ap-south-1` AWS Mumbai and `asia-south1` GCP Mumbai), complying with Reserve Bank of India (RBI) payment data localization and Digital Personal Data Protection (DPDP) Act standards.
- **Cardholder Data:** No debit or credit card credentials are stored or processed on BookurTechnician infrastructure; all payment tokenization is handled directly by PCI-DSS Level 1 certified Razorpay.
- **Statutory Records:** Digital invoices conforming to SAC 9987 (Maintenance and repair services) are retained with anonymized customer references for statutory accounting audits.

