# BookurTechnician — Payment & Financial Security Audit

**Payment Gateway:** Razorpay  
**Payout Engine:** RazorpayX / Bank Transfer / Instant UPI  
**Standard:** PCI-DSS Level 1 Merchant Best Practices  
**Status:** Hardened & Cryptographically Verified  

---

## 1. Authoritative Pricing Engine (Anti-Price-Tampering)

In on-demand service platforms, client-side price tampering represents a primary vector for financial fraud.

### Defensive Architecture:
1. When a client calls `POST /api/v1/payments/create-order`:
   - The backend looks up the booking from PostgreSQL/Memory.
   - The server computes the authoritative amount from `booking.totalAmount || booking.grandTotal`.
   - If the client supplies an altered amount (e.g. ₹1.00 instead of ₹499.00), the backend logs a `🚨 [SECURITY ALERT]` and overrides the value with the authoritative server amount.
   - The Razorpay order is generated strictly for `Math.round(serverAuthoritativeAmount * 100)` paise.

---

## 2. Cryptographic Payment Signature Verification

During client checkout completion:
1. The client sends `razorpayOrderId`, `razorpayPaymentId`, and `razorpaySignature` to `POST /api/v1/payments/verify-signature`.
2. The server verifies the signature using HMAC-SHA256:
   ```javascript
   const body = `${razorpayOrderId}|${razorpayPaymentId}`;
   const expectedSignature = crypto
     .createHmac('sha256', RAZORPAY_KEY_SECRET)
     .update(body)
     .digest('hex');

   const expectedBuf = Buffer.from(expectedSignature, 'utf8');
   const receivedBuf = Buffer.from(razorpaySignature, 'utf8');

   if (expectedBuf.length === receivedBuf.length && crypto.timingSafeEqual(expectedBuf, receivedBuf)) {
     isSignatureValid = true;
   }
   ```
3. **Timing Attack Protection:** `crypto.timingSafeEqual` prevents side-channel timing analysis.
4. Synthetic or bypass tokens (`startsWith('pay_')`) are strictly rejected.

---

## 3. Webhook Idempotency & Raw Body Verification

1. **Raw Body Capture:** Express preserves raw unparsed body buffers via `req.rawBody`.
2. **Signature Validation:** `x-razorpay-signature` is computed over `req.rawBody` and compared using `crypto.timingSafeEqual`.
3. **Idempotency Store:** Processed webhook IDs are tracked in a memory and database idempotency set. Duplicate webhook transmissions receive an immediate `status: already_processed` and prevent double-crediting.

---

## 4. Technician Wallet Ledger & Instant Payout Security

- **Double-Entry Ledger:** Technician earnings follow a strict double-entry ledger architecture (`CREDIT` on job completion, `DEBIT` on withdrawal).
- **KYC Verification Prerequisite:** Payouts and instant withdrawals are only permitted for accounts with `kyc_status = 'VERIFIED'`.
- **Ownership Binding:** `withdrawEarnings` strictly binds the target technician ID to `req.user.id`. Cross-technician withdrawal requests return HTTP 403 Forbidden.
