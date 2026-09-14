# 🛠️ BookUrTechnician: Complete 100% Free Production Implementation Chart

This production architecture blueprint is designed to run the entire **BookUrTechnician** ecosystem at **₹0 / $0 Cost** using permanent free-tier cloud platforms, **Brevo Email OTP (300 free emails/day)**, Razorpay PG & Wallet Ledger, STOMP WebSockets for Live GPS Tracking, Cloudinary Media CDN, and Oracle Cloud Always Free VM.

---

## 🏛️ 100% Zero-Cost Production Stack Overview

```mermaid
graph TD
    subgraph "Clients (Free)"
        CA["📱 Customer Flutter App (Release APK/AAB)"]
        TA["📱 Technician Flutter App (Release APK/AAB)"]
        AP["💻 React Vite Admin Panel (Hosted on Vercel - Free)"]
    end

    subgraph "Edge & Gateway (100% Free)"
        CF["🛡️ Cloudflare DNS + Free Let's Encrypt SSL"]
        NGINX["🌐 Nginx Alpine Reverse Proxy & Rate Limiter"]
    end

    subgraph "Core Backend (Oracle Cloud Always Free - 24GB RAM, 4 OCPU)"
        SB["☕ Spring Boot 3 Backend (Java 21)"]
        WS["⚡ STOMP WebSocket Live GPS Broker"]
        DISPATCH["⏱️ Redis-backed 45s Dispatch & Escalation Engine"]
    end

    subgraph "Data & Media Storage (Free Tier)"
        PG[("🐘 PostgreSQL 16 + PostGIS (Docker / Supabase Free 500MB)")]
        RD[("🔴 Redis 7 Alpine (Docker / Upstash Free 10k req/day)")]
        CLD[("☁️ Cloudinary (Free 25GB Storage & CDN for Job Photos)")]
    end

    subgraph "External Free Integration Services"
        BREVO["✉️ Brevo / Sendinblue (300 Free OTP Emails/Day)"]
        RZP["💳 Razorpay PG (Free standard integration, 0 AMC)"]
        FCM["🔔 Firebase Cloud Messaging (FCM HTTP v1 - 100% Free)"]
        GM["🗺️ Google Maps SDK ($200 Monthly Free Credit)"]
    end

    CA --> CF
    TA --> CF
    AP --> CF
    CF --> NGINX
    NGINX --> SB
    NGINX --> WS
    SB --> PG
    SB --> RD
    SB --> CLD
    SB --> BREVO
    SB --> RZP
    SB --> FCM
    SB --> GM
```

---

## 📋 Comprehensive 7-Pillar Production Roadmap

---

### 1️⃣ Authentication: Brevo (Sendinblue) Email OTP Engine (300 Free Emails/Day)

* **Why Brevo?** 
  * 100% Free: **300 transactional emails per day** with 99.8% inbox delivery.
  * No expensive mobile SMS DLT registration or recurring SMS gateway charges.
  * Beautiful responsive HTML OTP email with 6-digit verification code.

```mermaid
sequenceDiagram
    autonumber
    actor User as Customer / Technician
    participant App as Flutter Mobile App
    participant Backend as Spring Boot Auth API
    participant Redis as Redis OTP Store
    participant Brevo as Brevo API (SMTP / REST v3)

    User->>App: Enters Email (e.g. user@gmail.com)
    App->>Backend: POST /api/v1/auth/request-otp { email, purpose: "LOGIN" }
    Backend->>Backend: Generate Secure 6-Digit Code (e.g. 749201)
    Backend->>Redis: SET otp:LOGIN:user@gmail.com = 749201 (TTL: 300s / 5 mins)
    Backend->>Brevo: POST https://api.brevo.com/v3/smtp/email
    Note over Brevo: Sends Branded HTML Template with 749201
    Brevo-->>User: Receives Email in Inbox (< 2 seconds)
    User->>App: Types 6-digit OTP
    App->>Backend: POST /api/v1/auth/verify-otp { email, otp: "749201", role }
    Backend->>Redis: GET & Compare OTP
    Backend->>Backend: Issue JWT Access Token (24h) & Refresh Token (30d)
    Backend-->>App: Return User Profile & Tokens
```

#### Brevo Email OTP Service Blueprint:
* Endpoint: `https://api.brevo.com/v3/smtp/email`
* Header: `api-key: ${BREVO_API_KEY}`
* Payload:
```json
{
  "sender": { "name": "BookUrTechnician Support", "email": "auth@bookurtechnician.com" },
  "to": [{ "email": "customer@example.com" }],
  "subject": "749201 is your BookUrTechnician Verification Code",
  "htmlContent": "<div style='font-family: Arial; padding: 20px; background: #f8fafc;'><div style='max-width: 480px; margin: auto; background: white; border-radius: 12px; padding: 28px; border: 1px solid #e2e8f0;'><h2 style='color: #0f172a; margin-top: 0;'>BookUrTechnician</h2><p style='color: #475569; font-size: 15px;'>Your one-time verification code is:</p><div style='font-size: 32px; font-weight: 800; letter-spacing: 6px; color: #2563eb; padding: 16px; background: #eff6ff; border-radius: 8px; text-align: center; margin: 20px 0;'>749201</div><p style='color: #94a3b8; font-size: 13px;'>Valid for 5 minutes. If you did not request this, please ignore.</p></div></div>"
}
```

---

### 2️⃣ Payment Gateway, Technician Wallet & Automatic Payouts

```mermaid
graph TD
    subgraph "Customer Payment"
        PAY_REQ["Customer Books Service"] --> CHOOSE_PAY{"Payment Mode"}
        CHOOSE_PAY -- "Online (UPI / Card / NetBanking)" --> RZP_ORDER["Create Razorpay Order (POST /api/v1/payments/create-order)"]
        RZP_ORDER --> RZP_MODAL["Customer Completes Payment on Razorpay"]
        RZP_MODAL --> WEBHOOK["Webhook /api/v1/payments/webhook verifies HMAC SHA-256"]
        WEBHOOK --> SET_PAID["Mark Booking as PAID & Lock Funds in Escrow"]
        CHOOSE_PAY -- "Cash on Delivery (COD)" --> COD_SET["Mark Booking as COD_PENDING"]
    end

    subgraph "Job Completion & Technician Wallet Settlement"
        JOB_END["Technician Completes Job (Total: ₹1,000)"]
        JOB_END --> CALC["Commission Engine: 15% Platform Fee (₹150), 85% Tech Share (₹850)"]
        CALC --> LEDGER["Update TechnicianWallet Ledger: +₹850"]
        LEDGER --> CHECK_BALANCE{"Tech Wallet Balance"}
        CHECK_BALANCE -- "Balance < -₹200 (Negative COD dues)" --> BLOCK_TECH["🚫 Block Tech from receiving new bookings until recharged"]
        CHECK_BALANCE -- "Balance >= ₹500 & Auto-Payout Enabled" --> PAYOUT["Trigger Instant RazorpayX Payout to Tech UPI VPA"]
    end
```

#### Key Technical Rules:
1. **Idempotent Webhooks**: All webhook events (`payment.captured`, `payment.failed`, `refund.processed`) store transaction IDs in Redis with a 24-hour TTL to prevent double-crediting.
2. **Platform Commission Deduction**:
   - For Online Payments: Platform retains 15% immediately, remaining 85% is credited to the technician's wallet.
   - For COD Payments: Technician collects 100% cash from the customer; the system debits the 15% platform commission from the technician's wallet balance.
3. **Minimum Wallet Balance Enforcer**:
   - If a technician's wallet balance falls below `-₹200` (due to unpaid COD commissions), their status is automatically switched from `ONLINE` to `SUSPENDED_UNPAID_DUES`.

---

### 3️⃣ Live GPS Tracking & Google Maps Polylines

```mermaid
sequenceDiagram
    autonumber
    participant TechApp as Tech App (Background GPS)
    participant Spring as Spring Boot STOMP Broker
    participant Redis as Redis Pub/Sub
    participant CustApp as Customer App (Google Map)
    participant GMap as Google Maps Directions API

    Note over TechApp: Status transitions to "ON_THE_WAY"
    loop Every 3-5 Seconds
        TechApp->>Spring: WebSocket SEND /app/tracking/update { bookingId, lat, lng, heading, speed }
        Spring->>Redis: PUBLISH channel:tracking:{bookingId}
        Redis->>Spring: Broadcast to /topic/tracking/{bookingId}
        Spring-->>CustApp: Push dynamic coordinate payload
        CustApp->>CustApp: Smooth Marker Animation (Bearing rotation + Interpolation)
    end
    CustApp->>GMap: Fetch polyline & ETA ("Arriving in 11 mins")
    GMap-->>CustApp: Render dynamic blue route overlay on road
```

#### Key Technical Deliverables:
1. **Background GPS Ping (`flutter_background_service`)**:
   - Runs battery-optimized GPS updates only when an active job is in `ON_THE_WAY` status.
2. **WebSocket STOMP Broker (Spring Boot)**:
   - Topic: `/topic/tracking/{bookingId}`
   - Latency: `< 80ms` for real-time smooth marker movement.

---

### 4️⃣ Proof of Work: Job Before & After Photos (Cloudinary Free 25GB)

```mermaid
stateDiagram-v2
    [*] --> TechnicianArrived: Tech reaches customer location
    TechnicianArrived --> UploadBeforePhotos: Upload 1-4 Defect Photos (Watermarked with Time & GPS)
    UploadBeforePhotos --> StartJobOTP: Customer provides 4-Digit Start OTP
    StartJobOTP --> JobInProgress: Technician working on repair
    JobInProgress --> UploadAfterPhotos: Upload 1-4 Fixed Component Photos
    UploadAfterPhotos --> GenerateInvoice: System attaches photos to PDF Invoice
    GenerateInvoice --> CustomerSignatureAndPayment: Customer approves & completes payment
    CustomerSignatureAndPayment --> [*]
```

#### Storage Strategy (100% Free):
- **Cloudinary Free Tier**: 25 GB storage & bandwidth per month.
- **Client-Side Compression**: Flutter app compresses images to `.webp` (max 400KB each) before upload to save bandwidth and storage.

---

### 5️⃣ Intelligent Dispatch & 45-Second Siren Escalation Engine

```mermaid
graph TD
    A["Customer Places Booking"] --> B["Spatial Query: Find 'Online' Techs within 5km radius"]
    B --> C{"Any Tech Available?"}
    C -- "No" --> D["Expand Search to 8km radius / Notify Admin"]
    C -- "Yes" --> E["Sort Techs by Distance + Rating + Acceptance Score"]
    E --> F["Dispatch to Rank 1 Tech with 45-Second Countdown"]
    F --> G{"Tech Response in 45s?"}
    G -- "Accepts" --> H["Assign Job, Lock Booking & Send Push Alert to Customer"]
    G -- "Rejects or 45s Timeout" --> I["Record Missed Job Penalty (-2 pts) & Auto-Escalate to Rank 2 Tech"]
    I --> F
```

#### Technician Alarm Trigger:
- Uses **FCM v1 High-Priority Data Messages** combined with `flutter_local_notifications`.
- Plays loud loop siren (`siren_alarm.mp3`) with continuous vibration and full-screen notification banner until accepted or timed out.

---

### 6️⃣ Customer Support, SOS Emergency & Mutual Rating System

```mermaid
graph LR
    subgraph "SOS Safety Protocol"
        SOS_BTN["🚨 3-Second Hold on SOS Button"] --> ALERT_DB["Create Critical Safety Incident in DB"]
        ALERT_DB --> EMAIL_ADMIN["Send Emergency Email Alert via Brevo to Ops Team"]
        ALERT_DB --> TRIGGER_DIALER["Open Device Native Dialer with 112 (Emergency Police)"]
    end

    subgraph "Mutual Rating System"
        JOB_DONE["Job Marked Completed"] --> CUST_RATING["Customer Rates Tech (1-5 ⭐ + Review tags)"]
        JOB_DONE --> TECH_RATING["Tech Rates Customer (1-5 ⭐)"]
        CUST_RATING --> CHECK_SCORE{"Rating <= 2.5?"}
        CHECK_SCORE -- "Yes" --> FLAG_TECH["Auto-Flag Tech for Quality Investigation & Throttling"]
        CHECK_SCORE -- "No" --> UPDATE_AVG["Recalculate Weighted Average Rating"]
    end
```

---

### 7️⃣ 100% Free Production Cloud Deployment (Oracle Cloud Always Free)

```mermaid
graph TD
    subgraph "Oracle Cloud Infrastructure (Always Free: 4 ARM OCPU, 24GB RAM, 200GB SSD)"
        subgraph "Docker Compose Mesh"
            NGINX_CONT["🌐 Nginx (SSL Certbot, Rate Limiting, Reverse Proxy)"]
            SPRING_CONT["☕ Spring Boot 3 Backend Container (Port 8080)"]
            PG_CONT["🐘 PostgreSQL 16 + PostGIS (Port 5432)"]
            REDIS_CONT["🔴 Redis 7 Alpine (Port 6379)"]
        end
    end

    subgraph "Frontend & Storage (Zero-Cost)"
        VERCEL["⚡ Vercel (React Vite Admin Panel - Free SSL & Custom Domain)"]
        CLOUDINARY["☁️ Cloudinary (Free 25GB Media Storage)"]
        BREVO_CLOUD["✉️ Brevo SMTP API (Free 300 Emails/Day)"]
    end

    NGINX_CONT --> SPRING_CONT
    SPRING_CONT --> PG_CONT
    SPRING_CONT --> REDIS_CONT
    SPRING_CONT --> CLOUDINARY
    SPRING_CONT --> BREVO_CLOUD
    VERCEL --> NGINX_CONT
```

#### Production Docker Compose Specification (`docker-compose.prod.yml`):
```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: bt-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    depends_on:
      - backend
    restart: always

  backend:
    build:
      context: ./apps/backend
      dockerfile: Dockerfile
    container_name: bt-backend
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - DB_URL=jdbc:postgresql://postgres:5432/bookurtechnician
      - DB_USER=postgres
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - JWT_SECRET=${JWT_SECRET}
      - BREVO_API_KEY=${BREVO_API_KEY}
      - BREVO_SENDER_EMAIL=auth@bookurtechnician.com
      - RAZORPAY_KEY_ID=${RAZORPAY_KEY_ID}
      - RAZORPAY_KEY_SECRET=${RAZORPAY_KEY_SECRET}
      - CLOUDINARY_URL=${CLOUDINARY_URL}
    depends_on:
      - postgres
      - redis
    restart: always

  postgres:
    image: postgis/postgis:16-3.4-alpine
    container_name: bt-postgres
    environment:
      POSTGRES_DB: bookurtechnician
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always

  redis:
    image: redis:7-alpine
    container_name: bt-redis
    volumes:
      - redis_data:/data
    restart: always

volumes:
  postgres_data:
  redis_data:
```

---

## 🎯 Implementation Phases & Rollout Plan

| Phase | Module | Key Deliverables |
| :--- | :--- | :--- |
| **Phase 1** | **Brevo Email OTP Service** | Configured `BrevoEmailService` in Spring Boot, HTML OTP template, 5-min Redis TTL, zero phone SMS cost |
| **Phase 2** | **Payment & Wallet Engine** | Razorpay PG Order API, Webhook signature verification, Technician Wallet ledger, auto-commission cut & negative balance blocking |
| **Phase 3** | **Live GPS Tracking & Maps** | STOMP WebSocket endpoints, Redis PubSub live tracking, Google Maps smooth marker & polyline routing in Flutter |
| **Phase 4** | **45s Dispatch & Siren Alerts** | PostGIS radius search, Redis 45s countdown timer, FCM v1 high-priority siren alarm on technician phone |
| **Phase 5** | **Proof of Work & Safety** | Before/After photo uploads to Cloudinary, SOS emergency broadcast, 2-way rating engine |
| **Phase 6** | **Zero-Cost Production Deploy** | Oracle Cloud Always Free VM setup, Docker Compose deployment, Let's Encrypt SSL, Vercel React Admin live |

---

## 🔒 Verification & Testing Strategy
1. **Brevo OTP Deliverability Test**: Send test OTPs to Gmail, Outlook, Yahoo to verify < 3 second delivery and spam score 0.
2. **Razorpay Webhook Test**: Simulate webhook events with invalid vs valid signatures to guarantee zero fraud.
3. **GPS Stress Test**: Stream 50 concurrent GPS location updates over WebSockets to ensure server CPU remains < 10% on free tier.
4. **End-to-End Booking Flow**: Customer Book $\rightarrow$ 45s Siren on Tech App $\rightarrow$ Accept $\rightarrow$ Live Track $\rightarrow$ Before Photos $\rightarrow$ Start OTP $\rightarrow$ After Photos $\rightarrow$ Razorpay Payment $\rightarrow$ Wallet Split.
