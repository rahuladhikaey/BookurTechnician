const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const { authenticate } = require('./authMiddleware');
const { acceptBookingOffer } = require('./dispatchService');
const { verifyStartOtp, verifyEndOtp } = require('./otpVerificationService');
const { createBooking, resendStartOtp, resendEndOtp, getCustomerOtps } = require('./bookingService');
const { updateTechnicianPresence } = require('./presenceService');

function createApp(db) {
  const app = express();

  app.use(cors({ origin: true }));
  app.use(express.json());

  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'bookurtechnician-backend-2nd-gen', timestamp: new Date().toISOString() });
  });

  // Apply authentication to all /api and business routes
  app.use(authenticate);

  // 1. Create Booking (Customer)
  const handleCreateBooking = async (req, res) => {
    try {
      const customerId = req.user.uid;
      const result = await createBooking(db, {
        customerId,
        customerName: req.body.customerName || req.user.email,
        customerPhone: req.body.customerPhone || '',
        serviceId: req.body.serviceId || req.body.service?.id,
        serviceName: req.body.serviceName || req.body.service?.name,
        categoryId: req.body.categoryId,
        address: req.body.address,
        coordinates: req.body.coordinates,
        price: req.body.price || req.body.totalAmount,
        paymentMethod: req.body.paymentMethod,
      });
      res.status(201).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'INTERNAL_ERROR', error: err.message });
    }
  };

  app.post('/api/bookings/create', handleCreateBooking);
  app.post('/createBooking', handleCreateBooking);
  app.post('/bookings', handleCreateBooking);

  // 2. Accept Booking Offer (Technician - Atomic Single-Winner)
  const handleAcceptOffer = async (req, res) => {
    try {
      const offerId = req.params.offerId || req.body.offerId || req.body.proposalId;
      const callerUid = req.user.uid;
      const result = await acceptBookingOffer(db, {
        offerId,
        callerUid,
        callerName: req.body.technicianName,
        callerPhone: req.body.technicianPhone,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ACCEPTANCE_FAILED', error: err.message });
    }
  };

  app.post('/api/dispatch/accept', handleAcceptOffer);
  app.post('/acceptBookingOffer', handleAcceptOffer);
  app.post('/technician/offers/:offerId/accept', handleAcceptOffer);
  app.post('/proposals/:offerId/accept', handleAcceptOffer);
  app.post('/dispatch_offers/:offerId/accept', handleAcceptOffer);

  // 3. Verify Start OTP (Technician)
  const handleVerifyStartOtp = async (req, res) => {
    try {
      const bookingId = req.params.bookingId || req.body.bookingId;
      const callerUid = req.user.uid;
      const enteredOtp = req.body.startOtp || req.body.otp || req.body.code;
      const result = await verifyStartOtp(db, {
        bookingId,
        callerUid,
        enteredOtp,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        success: false,
        code: err.code || 'VERIFICATION_FAILED',
        error: err.message,
        remainingAttempts: err.remainingAttempts,
      });
    }
  };

  app.post('/api/bookings/:bookingId/verify-start-otp', handleVerifyStartOtp);
  app.post('/verifyStartOtp', handleVerifyStartOtp);

  // 4. Verify End OTP (Technician)
  const handleVerifyEndOtp = async (req, res) => {
    try {
      const bookingId = req.params.bookingId || req.body.bookingId;
      const callerUid = req.user.uid;
      const enteredOtp = req.body.endOtp || req.body.otp || req.body.code;
      const result = await verifyEndOtp(db, {
        bookingId,
        callerUid,
        enteredOtp,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        success: false,
        code: err.code || 'VERIFICATION_FAILED',
        error: err.message,
        remainingAttempts: err.remainingAttempts,
      });
    }
  };

  app.post('/api/bookings/:bookingId/verify-end-otp', handleVerifyEndOtp);
  app.post('/verifyEndOtp', handleVerifyEndOtp);

  // Dynamic status router for Flutter DioClient: PATCH /bookings/:bookingId/status
  app.patch('/bookings/:bookingId/status', async (req, res) => {
    const status = (req.body.status || '').toUpperCase();
    if (status === 'IN_PROGRESS' && req.body.startOtp) {
      return handleVerifyStartOtp(req, res);
    }
    if (status === 'COMPLETED' && req.body.endOtp) {
      return handleVerifyEndOtp(req, res);
    }
    res.status(400).json({
      success: false,
      code: 'UNSUPPORTED_STATUS_TRANSITION',
      error: 'Status changes require authoritative OTP verification (startOtp or endOtp required)',
    });
  });

  // 5. Technician Presence & Location Heartbeat
  const handlePresenceUpdate = async (req, res) => {
    try {
      const callerUid = req.user.uid;
      const result = await updateTechnicianPresence(db, {
        callerUid,
        latitude: req.body.latitude,
        longitude: req.body.longitude,
        heading: req.body.heading,
        speed: req.body.speed,
        accuracy: req.body.accuracy,
        isOnline: req.body.isOnline,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'PRESENCE_UPDATE_FAILED', error: err.message });
    }
  };

  app.post('/api/technician/presence', handlePresenceUpdate);
  app.post('/updateTechnicianPresence', handlePresenceUpdate);
  app.post('/presence/heartbeat', handlePresenceUpdate);
  app.post('/technician/location', handlePresenceUpdate);

  // 6. OTP Resend & Customer Retrieval
  app.post('/bookings/:bookingId/resend-start-otp', async (req, res) => {
    try {
      const bookingId = req.params.bookingId;
      const callerUid = req.user.uid;
      const result = await resendStartOtp(db, { bookingId, callerUid });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'RESEND_FAILED', error: err.message });
    }
  });

  app.post('/bookings/:bookingId/resend-end-otp', async (req, res) => {
    try {
      const bookingId = req.params.bookingId;
      const callerUid = req.user.uid;
      const result = await resendEndOtp(db, { bookingId, callerUid });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'RESEND_FAILED', error: err.message });
    }
  });

  app.get('/bookings/:bookingId/customer-otps', async (req, res) => {
    try {
      const bookingId = req.params.bookingId;
      const callerUid = req.user.uid;
      const result = await getCustomerOtps(db, { bookingId, callerUid });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'FETCH_FAILED', error: err.message });
    }
  });

  return app;
}

module.exports = {
  createApp,
};

