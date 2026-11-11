const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const { authenticate } = require('./authMiddleware');
const { acceptBookingOffer } = require('./dispatchService');
const { verifyStartOtp, verifyEndOtp } = require('./otpVerificationService');
const { createBooking, resendStartOtp, resendEndOtp, getCustomerOtps } = require('./bookingService');
const { updateTechnicianPresence } = require('./presenceService');
const { fetchTechnicianSkills, saveTechnicianSkills, toggleTechnicianSkill } = require('./skillService');

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

  // 7. Technician Skills Management (Authoritative & Canonical)
  const handleFetchSkills = async (req, res) => {
    try {
      const callerUid = req.user.uid;
      const isAdmin = req.user.admin === true || (req.user.role || '').toUpperCase() === 'ADMIN';
      const targetTechId = req.params.technicianId || req.query.technicianId || callerUid;
      const result = await fetchTechnicianSkills(db, { callerUid, targetTechId, isAdmin });
      res.status(200).json({
        success: true,
        data: result,
        profile: result,
        skills: result.skills,
        selectedSkills: result.selectedSkills,
      });
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'FETCH_SKILLS_FAILED', error: err.message });
    }
  };

  const handleSaveSkills = async (req, res) => {
    try {
      const callerUid = req.user.uid;
      const isAdmin = req.user.admin === true || (req.user.role || '').toUpperCase() === 'ADMIN';
      const rawSkills = Array.isArray(req.body)
        ? req.body
        : (req.body.skills || req.body.selectedSkills || req.body.data || []);
      const targetTechId = req.params.technicianId || req.body.technicianId || req.body.uid;

      const result = await saveTechnicianSkills(db, {
        callerUid,
        targetTechId,
        skills: rawSkills,
        isAdmin,
      });
      res.status(200).json({
        success: true,
        saveState: 'SAVED_TO_SERVER',
        message: 'Skills saved successfully to Cloud Firestore',
        data: result,
        profile: result.profile,
        skills: result.skills,
        selectedSkills: result.selectedSkills,
      });
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'SAVE_SKILLS_FAILED', error: err.message });
    }
  };

  const handleToggleSkill = async (req, res) => {
    try {
      const callerUid = req.user.uid;
      const isAdmin = req.user.admin === true || (req.user.role || '').toUpperCase() === 'ADMIN';
      const skillId = req.params.skillId;
      const targetTechId = req.params.technicianId || req.body.technicianId || req.body.uid;
      const enabled = req.body.enabled;

      const result = await toggleTechnicianSkill(db, {
        callerUid,
        targetTechId,
        skillId,
        enabled,
        isAdmin,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'TOGGLE_SKILL_FAILED', error: err.message });
    }
  };

  app.get('/api/technicians/skills', handleFetchSkills);
  app.get('/technicians/skills', handleFetchSkills);
  app.get('/admin/technicians/:technicianId/skills', handleFetchSkills);

  app.post('/api/technicians/skills', handleSaveSkills);
  app.post('/technicians/skills', handleSaveSkills);
  app.post('/api/technicians/skills/bulk', handleSaveSkills);
  app.post('/technicians/skills/bulk', handleSaveSkills);
  app.post('/admin/technicians/:technicianId/skills', handleSaveSkills);

  app.patch('/api/technicians/skills/:skillId/toggle', handleToggleSkill);
  app.patch('/technicians/skills/:skillId/toggle', handleToggleSkill);
  app.post('/api/technicians/skills/:skillId/toggle', handleToggleSkill);
  app.post('/technicians/skills/:skillId/toggle', handleToggleSkill);

  return app;
}

module.exports = {
  createApp,
};

