const crypto = require('crypto');
const axios = require('axios');
const postgres = require('../config/postgres');
const bookingsStore = require('../config/bookingsStore');
const firebase = require('../config/firebase');

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || '';
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || RAZORPAY_KEY_SECRET;

/**
 * Helper to get Razorpay Basic Auth Header
 */
const getRazorpayAuthHeader = () => {
  const token = Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
  return `Basic ${token}`;
};

/**
 * POST /api/v1/payments/create-order
 * Creates a genuine Razorpay Order via REST API with automated fallback
 */
const createOrder = async (req, res) => {
  try {
    const { bookingId, amount: requestedAmount, currency = 'INR', notes = {} } = req.body;

    if (!bookingId) {
      return res.status(400).json({ success: false, error: 'bookingId is required to create a payment order' });
    }

    // 1. Locate booking details
    let booking = bookingsStore.getBookingById(bookingId);
    if (!booking && postgres.isPgHealthy()) {
      try {
        const pgRes = await postgres.query('SELECT * FROM bookings WHERE id = $1 OR booking_code = $1', [bookingId]);
        if (pgRes.rows.length > 0) {
          booking = pgRes.rows[0];
        }
      } catch (_) {}
    }

    const payableAmount = parseFloat(requestedAmount || booking?.totalAmount || booking?.grandTotal || booking?.total_amount || 299);
    const amountInPaise = Math.round(payableAmount * 100);
    const receiptCode = (booking?.bookingCode || booking?.booking_code || bookingId || '').slice(-40);

    let razorpayOrderId = null;

    // 2. Call Razorpay Orders API
    if (RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET && !RAZORPAY_KEY_ID.includes('placeholder')) {
      try {
        const rzpResponse = await axios.post(
          'https://api.razorpay.com/v1/orders',
          {
            amount: amountInPaise,
            currency,
            receipt: receiptCode || `rcpt_${Date.now()}`,
            notes: {
              bookingId,
              customerName: booking?.customerName || 'Customer',
              ...notes,
            },
          },
          {
            headers: {
              Authorization: getRazorpayAuthHeader(),
              'Content-Type': 'application/json',
            },
            timeout: 5000,
          }
        );

        if (rzpResponse.data && rzpResponse.data.id) {
          razorpayOrderId = rzpResponse.data.id;
          console.log(`💳 [Razorpay] Created live order ${razorpayOrderId} for Booking #${bookingId} (₹${payableAmount})`);
        }
      } catch (rzpErr) {
        console.error('❌ [Razorpay API Call Error]:', rzpErr.response?.data?.error?.description || rzpErr.message);
        if (process.env.NODE_ENV === 'production') {
          return res.status(502).json({
            success: false,
            error: 'Failed to initiate secure order with Razorpay payment gateway',
            details: rzpErr.response?.data?.error?.description || rzpErr.message
          });
        }
      }
    }

    if (!razorpayOrderId) {
      return res.status(503).json({
        success: false,
        error: 'Razorpay gateway unavailable or credentials missing. Cannot generate payment order.'
      });
    }

    // 3. Persist order ID on booking record
    if (booking) {
      booking.razorpayOrderId = razorpayOrderId;
      bookingsStore.updateBookingStatus(bookingId, booking.status || 'CONFIRMED', { razorpayOrderId });
    }

    if (postgres.isPgHealthy()) {
      await postgres.query(
        `UPDATE bookings SET updated_at = NOW() WHERE id = $1 OR booking_code = $1`,
        [bookingId]
      ).catch(() => {});
    }

    return res.json({
      success: true,
      message: 'Razorpay order created successfully',
      data: {
        razorpayOrderId,
        orderId: razorpayOrderId,
        keyId: RAZORPAY_KEY_ID,
        amount: amountInPaise,
        currency,
        bookingId,
        bookingCode: receiptCode,
      },
    });
  } catch (error) {
    console.error('❌ Create Razorpay Order Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/payments/verify-signature (also handles /payments/verify)
 * Validates HMAC SHA-256 cryptographic signature from Razorpay checkout
 */
const verifySignature = async (req, res) => {
  try {
    const {
      bookingId,
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
    } = req.body;

    if (!razorpayPaymentId) {
      return res.status(400).json({ success: false, error: 'razorpayPaymentId is required for verification' });
    }

    // Strict Cryptographic HMAC SHA-256 validation (No bypasses)
    if (!razorpayOrderId || !razorpaySignature) {
      return res.status(400).json({
        success: false,
        error: 'Both razorpayOrderId and razorpaySignature are strictly required for payment verification',
      });
    }

    if (!RAZORPAY_KEY_SECRET) {
      return res.status(500).json({
        success: false,
        error: 'Razorpay secret key is not configured on server',
      });
    }

    let isSignatureValid = false;
    try {
      const body = `${razorpayOrderId}|${razorpayPaymentId}`;
      const expectedSignature = crypto
        .createHmac('sha256', RAZORPAY_KEY_SECRET)
        .update(body)
        .digest('hex');

      const expectedBuf = Buffer.from(expectedSignature, 'utf8');
      const receivedBuf = Buffer.from(razorpaySignature, 'utf8');

      if (expectedBuf.length === receivedBuf.length && crypto.timingSafeEqual(expectedBuf, receivedBuf)) {
        isSignatureValid = true;
        console.log(`✅ [Razorpay HMAC] Cryptographic signature verified for Payment #${razorpayPaymentId}`);
      } else {
        console.warn(`⚠️ [Razorpay HMAC] Signature mismatch. Payment #${razorpayPaymentId} rejected.`);
      }
    } catch (cryptoErr) {
      console.warn('⚠️ [Razorpay HMAC] Signature verification calculation error:', cryptoErr.message);
    }

    if (!isSignatureValid) {
      return res.status(400).json({
        success: false,
        error: 'Invalid payment signature verification failed.',
      });
    }

    // 4. Update Booking in stores
    let booking = bookingId ? bookingsStore.getBookingById(bookingId) : null;
    if (booking) {
      booking.paymentStatus = 'PAID';
      booking.paymentMethod = 'ONLINE_RAZORPAY';
      booking.razorpayPaymentId = razorpayPaymentId;
      booking.razorpayOrderId = razorpayOrderId || booking.razorpayOrderId;
      bookingsStore.updateBookingStatus(bookingId, booking.status || 'CONFIRMED', {
        paymentStatus: 'PAID',
        paymentMethod: 'ONLINE_RAZORPAY',
        razorpayPaymentId,
      });
    }

    // Record in PostgreSQL
    if (postgres.isPgHealthy() && bookingId) {
      try {
        await postgres.query(
          `UPDATE bookings 
           SET updated_at = NOW(),
               razorpay_payment_id = $1,
               razorpay_order_id = $2
           WHERE id = $3 OR booking_code = $3`,
          [razorpayPaymentId, razorpayOrderId, bookingId]
        );

        // Record in payments audit table
        await postgres.query(
          `INSERT INTO wallet_transactions (id, user_id, booking_id, amount, type, description)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            `PAY-${Date.now()}`,
            booking?.customerId || 'customer',
            bookingId,
            parseFloat(booking?.totalAmount || booking?.grandTotal || 299),
            'PAYMENT_CAPTURED',
            `Online Payment via Razorpay (${razorpayPaymentId})`,
          ]
        ).catch(() => {});
      } catch (pgErr) {
        console.warn('[Payments PG Update Warning]:', pgErr.message);
      }
    }

    // 5. Emit real-time payment confirmation scoped strictly to customer and booking rooms
    if (global.io) {
      const payload = {
        bookingId,
        paymentId: razorpayPaymentId,
        orderId: razorpayOrderId,
        status: 'PAID',
        timestamp: Date.now(),
      };
      if (booking?.customerId) {
        global.io.to(`cust_${booking.customerId}`).emit('booking:payment_success', payload);
      }
      global.io.to(`booking_${bookingId}`).emit('booking:paid', payload);
    }

    // 6. Send FCM Notification to customer using real token lookup
    if (booking?.customerId && postgres.isPgHealthy()) {
      try {
        const uRes = await postgres.query('SELECT fcm_token, device_tokens FROM users WHERE id = $1', [booking.customerId]);
        if (uRes.rows.length > 0) {
          const userToken = uRes.rows[0].fcm_token;
          if (userToken && !userToken.startsWith('cust_fcm_')) {
            firebase.sendPushNotification(userToken, {
              title: '💳 Payment Received!',
              body: `Payment of ₹${booking.totalAmount || booking.grandTotal || 299} confirmed. We are assigning your expert technician.`,
              data: { bookingId, paymentId: razorpayPaymentId, status: 'PAID' },
            }).catch(() => {});
          }
        }
      } catch (_) {}
    }

    return res.json({
      success: true,
      message: 'Payment verified and captured successfully',
      data: {
        bookingId,
        paymentId: razorpayPaymentId,
        orderId: razorpayOrderId,
        status: 'PAID',
      },
    });
  } catch (error) {
    console.error('❌ Verify Payment Signature Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

const processedWebhookEvents = new Set();

/**
 * POST /api/v1/payments/webhook
 * Handles asynchronous server-to-server Razorpay webhooks with raw body HMAC & idempotency
 */
const handleWebhook = async (req, res) => {
  try {
    const signature = req.headers['x-razorpay-signature'];
    const event = req.body;

    if (!signature) {
      return res.status(400).json({ status: 'missing_signature', error: 'x-razorpay-signature header required' });
    }

    if (RAZORPAY_WEBHOOK_SECRET) {
      try {
        // Authoritative raw request body capture for cryptographic HMAC
        const rawBody = req.rawBody ? req.rawBody : Buffer.from(JSON.stringify(req.body));
        const expectedSignature = crypto
          .createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
          .update(rawBody)
          .digest('hex');

        const expectedBuf = Buffer.from(expectedSignature, 'utf8');
        const receivedBuf = Buffer.from(signature, 'utf8');

        if (expectedBuf.length !== receivedBuf.length || !crypto.timingSafeEqual(expectedBuf, receivedBuf)) {
          console.warn('⚠️ [Razorpay Webhook] Invalid webhook cryptographic signature');
          return res.status(400).json({ status: 'invalid_signature', error: 'Cryptographic HMAC mismatch' });
        }
      } catch (sigErr) {
        console.warn('⚠️ [Razorpay Webhook] Signature check error:', sigErr.message);
        return res.status(400).json({ status: 'signature_verification_failed' });
      }
    }

    const eventId = event.id || (event.payload?.payment?.entity?.id ? `${event.event}_${event.payload.payment.entity.id}` : null);
    if (eventId) {
      if (processedWebhookEvents.has(eventId)) {
        console.log(`ℹ️ [Razorpay Webhook] Idempotency: Webhook ${eventId} already processed.`);
        return res.json({ status: 'already_processed', eventId });
      }
      processedWebhookEvents.add(eventId);
      if (processedWebhookEvents.size > 5000) {
        const [oldest] = processedWebhookEvents;
        processedWebhookEvents.delete(oldest);
      }
    }

    const eventType = event.event;
    console.log(`🔔 [Razorpay Webhook] Received event: ${eventType}`);

    if (eventType === 'payment.captured' || eventType === 'order.paid') {
      const entity = event.payload?.payment?.entity || event.payload?.order?.entity;
      const notes = entity?.notes || {};
      const bookingId = notes.bookingId;

      if (bookingId) {
        const booking = bookingsStore.getBookingById(bookingId);
        if (booking) {
          booking.paymentStatus = 'PAID';
        }
        if (global.io) {
          global.io.emit('booking:paid', { bookingId, paymentId: entity.id, status: 'PAID' });
        }
      }
    }

    return res.json({ status: 'ok' });
  } catch (error) {
    console.error('❌ Webhook Handler Error:', error);
    return res.status(500).json({ status: 'error', message: error.message });
  }
};

/**
 * POST /api/v1/payments/payout-webhook
 * Reconciles technician payouts from RazorpayX webhook
 */
const handlePayoutWebhook = async (req, res) => {
  try {
    const rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body));
    const signature = req.headers['x-razorpay-signature'];

    const payoutService = require('../services/payoutService');
    const result = await payoutService.handlePayoutWebhook(rawBody, signature);
    return res.json({ success: true, ...result });
  } catch (err) {
    console.error('❌ Payout Webhook Error:', err.message);
    return res.status(400).json({ success: false, error: err.message });
  }
};

module.exports = {
  createOrder,
  verifySignature,
  handleWebhook,
  handlePayoutWebhook,
};
