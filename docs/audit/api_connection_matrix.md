# API Connection Matrix & Service Contract
**Environment:** BookUrTechnician Production V1  
**Protocol:** REST (JSON) + WebSocket (Socket.io)

---

| Method | Endpoint Path | Auth Required | Role | Request Payload | Response | DB Effect | Realtime / Push Event | Idempotent |
|---|---|---|---|---|---|---|---|---|
| **POST** | `/api/v1/auth/request-otp` | No | Any | `{ phone, email, purpose, role }` | `{ success: true, message: 'OTP sent' }` | Inserts record into `otps` table | SMS / Email dispatched | Yes |
| **POST** | `/api/v1/auth/verify-otp` | No | Any | `{ phone, email, otp, fullName, fcmToken }` | `{ success: true, accessToken, user }` | Upserts `users` record; stores `fcm_token` | None | Yes |
| **GET** | `/api/v1/catalog/services/:id/slots` | No | Public | Query: `?date=YYYY-MM-DD` | `{ success: true, slots: [...] }` | Reads `services`, `bookings`, `technician_profiles` | None | Yes |
| **POST** | `/api/v1/bookings` | Yes | CUSTOMER | `{ serviceId, date, timeSlot, address, latitude, longitude }` | `{ success: true, booking: { ... } }` | Inserts `bookings` (status: `PENDING`/`CONFIRMED`) | `io.to('admin_dispatch')`, high-priority siren FCM to nearby tech | No |
| **POST** | `/api/v1/bookings/:id/accept` | Yes | TECHNICIAN | `{}` (Identity from JWT) | `{ success: true, status: 'ACCEPTED' }` | Atomic conditional update (`WHERE technician_id IS NULL`) | `io.to('cust_<id>')`, real FCM push to customer with Start OTP | Yes |
| **POST** | `/api/v1/bookings/:id/arrive` | Yes | TECHNICIAN | `{ latitude, longitude }` | `{ success: true, status: 'ARRIVED', distanceMeters }` | Updates `bookings.status = 'ARRIVED'` | `io.to('cust_<id>')`, `io.to('booking_<id>')` | Yes |
| **POST** | `/api/v1/bookings/:id/verify-start-otp` | Yes | TECHNICIAN | `{ otp }` | `{ success: true, status: 'IN_PROGRESS', endOtp }` | Validates `start_otp`; sets `status = 'IN_PROGRESS'` | `io.to('cust_<id>')`, real FCM push with Completion OTP | Yes |
| **POST** | `/api/v1/bookings/:id/verify-end-otp` | Yes | TECHNICIAN | `{ otp }` | `{ success: true, status: 'COMPLETED', settlement }` | Validates `end_otp` & proof of work; sets `status = 'COMPLETED'` | Ledger credits technician wallet, debits platform fee | Yes |
| **POST** | `/api/v1/bookings/:id/call-masked` | Yes | CUSTOMER / TECH | `{}` (Identity from JWT) | `{ success: true, callRequestId, status: 'INITIATED' }` | Inserts into `masked_call_logs` | Initiates Exotel/Twilio voice bridge | No |
| **GET** | `/api/v1/bookings/:id/messages` | Yes | PARTICIPANT | None | `{ success: true, messages: [...] }` | Reads `booking_messages` (scoped to booking) | None | Yes |
| **POST** | `/api/v1/bookings/:id/messages` | Yes | PARTICIPANT | `{ content }` | `{ success: true, message: { ... } }` | Inserts into `booking_messages` | `io.to('booking_<id>')`, real FCM push to receiver | No |
| **POST** | `/api/v1/payments/create-order` | Yes | CUSTOMER | `{ bookingId, amount, currency }` | `{ success: true, order: { id, amount } }` | Updates `bookings.razorpay_order_id` | None | Yes |
| **POST** | `/api/v1/payments/verify` | Yes | CUSTOMER | `{ razorpayOrderId, razorpayPaymentId, razorpaySignature }` | `{ success: true, status: 'PAID' }` | Verifies cryptographic HMAC; sets `payment_status = 'PAID'` | `io.to('cust_<id>')`, `io.to('booking_<id>')` | Yes |
| **POST** | `/api/v1/payments/webhook` | Raw Body | Razorpay | Razorpay Webhook Event | `{ status: 'ok' }` | Idempotent payment capture reconciliation | `io.to('booking_<id>')` | Yes |
| **POST** | `/api/v1/payments/payout-webhook` | Raw Body | RazorpayX | RazorpayX Payout Event | `{ success: true }` | Updates `technician_withdrawals.status`; settles ledger | Updates technician wallet | Yes |
| **POST** | `/api/v1/technicians/fcm-token` | Yes | TECHNICIAN | `{ fcmToken, platform }` | `{ success: true }` | Updates `users.fcm_token` and `device_tokens` | None | Yes |
| **POST** | `/api/v1/customer/fcm-token` | Yes | CUSTOMER | `{ fcmToken, platform }` | `{ success: true }` | Updates `users.fcm_token` and `device_tokens` | None | Yes |
| **GET** | `/api/v1/admin/withdrawals` | Yes | ADMIN | Query: `?status=PENDING` | `{ success: true, data: [...] }` | Reads `technician_withdrawals` joined with profiles | None | Yes |
| **POST** | `/api/v1/admin/withdrawals/:id/status` | Yes | ADMIN | `{ status: 'REJECTED', failureReason }` | `{ success: true }` | Updates withdrawal; reverses debit in ledger if rejected | Adjusts technician wallet balance | Yes |
