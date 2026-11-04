# BookurTechnician — Dispatch API & Socket.io Event Matrix

## 1. REST API Endpoints

| Method | Endpoint | Auth / RBAC | Description |
|---|---|---|---|
| `GET` | `/api/v1/technicians/availability` | `optionalAuth` | Query eligible ranked technicians for `(latitude, longitude, serviceId, category, scheduleDate, scheduleSlot, bookingMode)` or inspect a technician's working hours |
| `POST` | `/api/v1/technicians/availability` | `authenticateToken` (Tech/Admin) | Set working hours (`start_time`, `end_time`, `day_of_week`) & unavailable windows |
| `GET` | `/api/v1/dispatch/:bookingId/status` | `optionalAuth` (Owner/Admin) | Retrieve current dispatch session status, active offer countdown, or assigned technician |
| `GET` | `/api/v1/technician/offers` | `authenticateToken` (Technician) | Retrieve currently active `SENT` offer(s) for the authenticated technician |
| `POST` | `/api/v1/dispatch/:bookingId/start` | `authenticateToken` (Customer/Admin) | Start automatic sequential dispatch for a booking |
| `POST` | `/api/v1/dispatch/offers/:offerId/accept` | `authenticateToken` (Technician) | Atomically accept an active offer (`200 OK` for winner, `409 CONFLICT` on simultaneous/expired accept, `403 FORBIDDEN` if wrong technician) |
| `POST` | `/api/v1/dispatch/offers/:offerId/reject` | `authenticateToken` (Technician) | Reject an active offer with reason and immediately advance to next ranked candidate |
| `POST` | `/api/v1/dispatch/:bookingId/retry` | `authenticateToken` (Customer/Admin) | Restart sequential dispatch search from initial radius (`3 km`) |
| `POST` | `/api/v1/dispatch/:bookingId/manual-assign` | `authenticateToken` + `requireAdminRole` | Admin manual assignment or reassignment with mandatory audit log entry |
| `GET` | `/api/v1/admin/dispatch/live` | `authenticateToken` + `requireAdminRole` | Live dispatch sessions, stage counts, active config, and recent audit logs |
| `GET` | `/api/v1/admin/dispatch/:bookingId/history` | `authenticateToken` + `requireAdminRole` | Complete offer, rejection, timeout, and audit history for a specific booking |
| `PUT` | `/api/v1/admin/dispatch/config` | `authenticateToken` + `requireAdminRole` | Update search radii (`3/5/10/15 km`), offer timeout (`15–20s`), max attempts, auto-dispatch toggle, and ranking weights |

---

## 2. Socket.io Real-Time Events & Room Scoping

### Room Ownership Rules
- `tech_<technicianId>`: Restricted to the authenticated technician (`socket.user.id === technicianId`) and Admin.
- `cust_<customerId>`: Restricted to the authenticated customer (`socket.user.id === customerId`) and Admin.
- `booking_<bookingId>`: Restricted to the booking's customer, the assigned technician, and Admin.
- `admin_dispatch`: Restricted to `ADMIN` and `SUPER_ADMIN`.

### Event Catalog

| Event Name | Target Room(s) | Payload Highlights |
|---|---|---|
| `dispatch:offer:new` | `tech_<technicianId>` | `offerId`, `bookingId`, `serviceName`, `approximateCustomerArea` (masked), `distanceKm`, `estimatedTravelMinutes`, `appointmentTime`, `expectedEarning`, `expiresAt`, `attemptNumber` |
| `dispatch:offer:expired` | `tech_<technicianId>` | `offerId`, `bookingId`, `status: 'EXPIRED'` |
| `dispatch:offer:cancelled` | `tech_<technicianId>` | `offerId`, `bookingId`, `reason` |
| `dispatch:offer:accepted` | `tech_<technicianId>` | Full assignment confirmation & customer location |
| `booking:dispatch:started` | `cust_<customerId>`, `booking_<bookingId>` | `bookingId`, `sessionId`, `status: 'SEARCHING'`, `radiusKm` |
| `booking:dispatch:searching` | `cust_<customerId>`, `booking_<bookingId>` | `bookingId`, `sessionId`, `status`, `radiusKm`, `attemptNumber`, `message` |
| `booking:technician:assigned` | `cust_<customerId>`, `booking_<bookingId>` | `bookingId`, `technician` (name, avatar, rating, skills, maskedPhone, lat/lng), `etaMinutes`, `distanceKm`, `startOtp` |
| `booking:technician:reassigned` | `cust_<customerId>`, `booking_<bookingId>` | `bookingId`, `isReassigned: true`, `previousTechnicianId`, `technician` |
| `booking:dispatch:failed` | `cust_<customerId>`, `booking_<bookingId>` | `bookingId`, `status: 'NO_TECHNICIAN_AVAILABLE'`, `canRetry: true`, `canReschedule: true` |
| `booking:partner:location` | `cust_<customerId>`, `booking_<bookingId>` | `bookingId`, `technicianId`, `latitude`, `longitude`, `speed`, `heading`, `timestamp` |
| `admin:dispatch:new` | `admin_dispatch` | New dispatch session started |
| `admin:dispatch:updated` | `admin_dispatch` | Offer sent, radius expanded, assigned, reassigned, or failed |
| `admin:technician:status` | `admin_dispatch` | Technician online/offline status & telemetry |

