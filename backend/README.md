# BookurTechnician Production Polyglot MVP Backend ($0 Tier Ready)

A production-grade, zero-cost ($0 free-tier ready) multi-tier backend ecosystem for **BookurTechnician**, combining **Node.js (Express.js)**, **Python (FastAPI)**, and **Java (Spring Boot 3)**.

---

## 🏛️ Architecture Stack

| Service Layer | Technology | Port | Responsibilities |
| :--- | :--- | :--- | :--- |
| **Core API Gateway** | **Node.js (Express.js) + Socket.io** | `4000` | REST API, Dual-OTP Verification, Firebase FCM Push, Live WebSockets GPS sync |
| **AI Matchmaker** | **Python (FastAPI)** | `8000` | Multi-parameter Matchmaking Algorithm, Dynamic Pricing, Diagnostic Assistant |
| **Compute & Ledger** | **Java 21 / Spring Boot 3** | `8080` | ACID Financial Ledger, 15% Platform Commission Deductions, Payout Ledger |
| **NoSQL Database** | **MongoDB 7** | `27017` | Unstructured Catalogs, Partner Profiles, KYC Docs, Reviews |
| **Relational Database**| **PostgreSQL 16 + PostGIS** | `5432` | Structured Users, Bookings, ACID Ledgers |
| **Cache & Geo-Store** | **Redis 7** | `6379` | Ephemeral GPS 15km Radius Query (`GEOADD`/`GEORADIUS`), 5-min OTP store |
| **Event Streaming** | **Kafka / Internal Bus** | `9092` | Decoupled asynchronous event pipeline |

---

## 🚀 Quick Start (Local Development)

### Method 1: One-Click Runner (Windows)
Double-click `run_backend.bat` in the repository root or run:
```bash
.\run_backend.bat
```

### Method 2: Docker Compose
```bash
docker-compose up -d
```

### Method 3: Individual Service Commands

#### 1. Node.js Core Service
```bash
cd backend/node-core-service
npm install
npm start
# Listening on http://localhost:4000
```

#### 2. Python AI & Matchmaking Service
```bash
cd backend/python-ai-service
pip install -r requirements.txt
uvicorn app.main:app --port 8000 --reload
# Interactive Swagger Docs: http://localhost:8000/docs
```

#### 3. Java Spring Boot Service
```bash
mvn spring-boot:run
# Running on http://localhost:8080
```

---

## 📡 Key API Endpoints Reference

### 1. Authentication & OTP (`Node.js - Port 4000`)
- `POST /api/v1/auth/request-otp`
  - Body: `{ "phone": "+919876543210", "role": "CUSTOMER" }`
  - Response: `{ "success": true, "message": "OTP sent", "debugOtp": "123456" }`
- `POST /api/v1/auth/verify-otp`
  - Body: `{ "phone": "+919876543210", "otp": "123456" }`
  - Response: `{ "success": true, "token": "JWT_TOKEN", "user": { ... } }`

### 2. Real-Time Booking & Dual-OTP Lifecycle (`Node.js - Port 4000`)
- `POST /api/v1/bookings` -> Create booking, geo-search candidates within 15km, rank via Python AI, dispatch FCM push alerts.
- `POST /api/v1/bookings/:id/accept` -> Technician accepts booking.
- `POST /api/v1/bookings/:id/verify-start-otp` -> Start OTP verification upon arrival (marks `IN_PROGRESS`).
- `POST /api/v1/bookings/:id/add-bill` -> Technician adds spare parts / materials bill.
- `POST /api/v1/bookings/:id/verify-end-otp` -> Customer End OTP verification (marks `COMPLETED`, calls Java Spring Boot to settle 15% platform commission and credit technician wallet).

### 3. Python AI Matchmaking & Dynamic Pricing (`FastAPI - Port 8000`)
- `POST /api/v1/ai/match` -> Evaluates distance, rating, skill match, and acceptance rate to output ranked top picks.
- `POST /api/v1/ai/dynamic-pricing` -> Computes dynamic surge and labor estimate.
- `POST /api/v1/ai/diagnostics` -> Troubleshoots customer complaints and suggests required technician tools.

### 4. Java High-Performance Financial Ledger (`Spring Boot - Port 8080`)
- `POST /api/v1/ledger/settle` -> Double-entry ACID settlement.
- `GET /api/v1/ledger/wallet/{userId}` -> Returns real-time wallet ledger history and balance.

---

## ☁️ 100% Free-Tier ($0 Cloud) Deployment Blueprint

1. **Node.js Core Service**: Deploy as Free Web Service on [Render.com](https://render.com).
2. **Python AI Service**: Deploy on Render.com or Railway free credits.
3. **PostgreSQL DB**: Create free database on [Supabase](https://supabase.com) or [Neon](https://neon.tech) (includes PostGIS support).
4. **MongoDB**: Create free M0 cluster (512MB) on [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
5. **Redis**: Create free Redis store on [Upstash](https://upstash.com).
6. **Push Notifications**: Free tier on [Firebase Console](https://console.firebase.google.com) (Unlimited push notifications via FCM).
