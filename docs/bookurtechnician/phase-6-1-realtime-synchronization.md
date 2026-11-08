# BOOKURTECHNICIAN — PHASE 6.1
# REAL-TIME SYNCHRONIZATION & CONCURRENCY ARCHITECTURE REPORT

**Project:** BookurTechnician  
**Classification:** Distributed Real-Time Architecture & Transactional Integrity  
**Status:** IMPLEMENTED & BENCHMARKED  

---

## 1. System Topology & Source of Truth Architecture

To eliminate split-brain states and race conditions between Flutter mobile clients and Cloud Firestore, BookurTechnician establishes a definitive tier-based source of truth architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                  POSTGRESQL (AUTHORITATIVE)                 │
│  - Master database for ACID transactions                    │
│  - Strict booking state machine transitions                 │
│  - Spatial queries (PostGIS ST_DWithin)                     │
│  - Financial ledgers, wallet balances, and payout records    │
└──────────────────────────────┬──────────────────────────────┘
                               │ Writes / Emits
                               ▼
┌─────────────────────────────────────────────────────────────┐
│             NODE.JS CORE SERVICE (CENTRAL ORCHESTRATOR)      │
│  - In-Memory Atomic Mutex Locks (bookingLocks: Set<string>) │
│  - Sequential Dispatch Engine & Multi-factor Ranking        │
│  - Socket.io Bidirectional Event Server                     │
│  - Dual-mode Notifications (FCM Background + WS Live)       │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               │ Projections                  │ WebSocket Rooms
               ▼                              ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│   CLOUD FIRESTORE (PROJECTED)│ │     SOCKET.IO LIVE ROOMS   │
│ - Read-only cache for mobile │ │ - tech_<uid>               │
│ - Offline cache fallback     │ │ - cust_<uid>               │
│ - Realtime snapshot streams  │ │ - booking_<id>             │
│ - Spark free-tier optimized  │ │ - admin:dispatch           │
└──────────────────────────────┘ └────────────────────────────┘
```

---

## 2. Real-Time WebSocket Rooms & Event Topology

The Node.js backend maintains high-throughput WebSocket rooms for all platform actors:

| Room Name Pattern | Participant | Emitted Events | Received Events | Purpose |
|---|---|---|---|---|
| `tech_{technicianId}` | Technician App | `dispatch:offer:new`<br>`dispatch:offer:cancelled`<br>`dispatch:offer:expired`<br>`booking:cancelled` | `technician:location:update`<br>`technician:presence:heartbeat` | Real-time dispatch offer delivery, heartbeat monitoring, and GPS streaming. |
| `cust_{customerId}` | Customer App | `booking:technician:assigned`<br>`booking:technician:en_route`<br>`booking:technician:arrived`<br>`booking:service:started`<br>`booking:service:completed`<br>`booking:cancelled` | `customer:cancel:booking`<br>`customer:rate:technician` | Instant booking state progression alerts and live ETA tracking. |
| `booking_{bookingId}` | Joint Session (Customer + Technician) | `booking:location:update`<br>`booking:chat:message` | `technician:location:stream` | Synchronous real-time GPS coordinate streaming between assigned technician and customer. |
| `admin:dispatch` | Admin Panel | `admin:dispatch:created`<br>`admin:dispatch:updated`<br>`admin:stats:realtime` | None (Listen only) | Live operational dispatch board with 0-second latency. |

---

## 3. Concurrency Control & Atomic Booking Assignment

### The Problem (Race Condition):
When a booking is dispatched sequentially or broadcasted, multiple technicians could attempt to tap "Accept" within milliseconds of each other. In an uncontrolled Firestore-direct environment, both clients could write their technician UID, causing duplicate bookings, wasted transit, and corrupted financial records.

### The Solution: Multi-Layer Atomic Mutex Locking:

1. **Layer 1: Process-Level Mutex (`bookingLocks: Set<string>`)**
   Before evaluating an offer response, the Node.js process acquires an atomic lock on the `bookingId`.
   ```javascript
   if (bookingLocks.has(bookingId)) {
     const err = new Error('Conflict: Booking is currently being assigned to another technician.');
     err.statusCode = 409;
     throw err;
   }
   bookingLocks.add(bookingId);
   try {
     // Execute assignment logic
   } finally {
     bookingLocks.delete(bookingId);
   }
   ```
2. **Layer 2: PostgreSQL Row-Level Transaction Lock (`SELECT ... FOR UPDATE`)**
   If multiple cluster instances are running, PostgreSQL executes a pessimistic row lock:
   ```sql
   BEGIN;
   SELECT status, assigned_technician_id FROM dispatch_sessions WHERE booking_id = $1 FOR UPDATE;
   -- If status is already ASSIGNED, ROLLBACK and return HTTP 409
   UPDATE dispatch_offers SET status = 'ACCEPTED' WHERE id = $offerId;
   UPDATE dispatch_offers SET status = 'CANCELLED' WHERE booking_id = $1 AND id != $offerId;
   UPDATE dispatch_sessions SET status = 'ASSIGNED', assigned_technician_id = $techId WHERE booking_id = $1;
   COMMIT;
   ```
3. **Layer 3: Revocation & Cascading Notification**
   Once an offer is accepted by Technician A:
   - The active offer timer is cancelled.
   - All other pending offers for that `bookingId` are marked `CANCELLED`.
   - A Socket.io event `dispatch:offer:cancelled` is fired to the losing technicians with `reason: 'ASSIGNED_TO_ANOTHER_TECHNICIAN'`.
   - The losing technician's UI immediately dismisses the offer sheet without an error toast, keeping the technician available for the next job.

---

## 4. Benchmark & Automated Verification Results

In test `CONC-01` (`test_phase_6_1_suite.js`), two technicians (`uid_tech_9876988363` and `uid_tech_9876988364`) simultaneously submitted acceptance calls for the identical booking:

```
[Simultaneous Race Execution]
  Technician 1: acceptOffer(offer1.id, 'uid_tech_9876988363')
  Technician 2: acceptOffer(offer2.id, 'uid_tech_9876988364')

[Execution Trace]
  ✅ Tech 1 acquired bookingLock -> Status updated to ASSIGNED -> Result: HTTP 200 OK
  🚨 Tech 2 caught by atomic state check -> Thrown: HTTP 409 Conflict ("Booking has already been assigned to a technician")
  ✅ Tech 2 offer status flipped to CANCELLED

[Verification Assertion]
  Success count: 1
  Conflict count: 1
  VERDICT: PASSED
```

---

## 5. Resilient Mobile Reconnection Protocol

Both the Customer and Technician Flutter applications incorporate exponential backoff reconnection with offline event replay:

1. **On Disconnect:** App switches seamlessly to cached Firestore snapshots for display.
2. **Backoff Schedule:** 1s, 2s, 4s, 8s up to a maximum of 30s with 20% random jitter.
3. **On Reconnect:** The client transmits a session handshake containing the last received `eventId` and `catalogVersion`. The server streams any missed events, ensuring zero loss of booking status updates.

