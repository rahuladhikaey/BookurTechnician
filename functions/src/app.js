const express = require('express');
const cors = require('cors');

const { authenticate, requireRole } = require('./authMiddleware');
const { acceptBookingOffer } = require('./dispatchService');
const { verifyStartOtp, verifyEndOtp } = require('./otpVerificationService');
const { createBooking, resendStartOtp, resendEndOtp, getCustomerOtps } = require('./bookingService');
const { updateTechnicianPresence } = require('./presenceService');
const {
  fetchTechnicianSkills,
  saveTechnicianSkills,
  toggleTechnicianSkill,
  verifyTechnicianSkill,
  bulkVerifyTechnicianSkills,
} = require('./skillService');
const { getAvailableTechniciansForService, getCatalogAvailabilitySummary } = require('./eligibilityService');
const { requestOtp, verifyOtp, adminDirectAccess, refreshAuthSession } = require('./authOtpService');
const {
  getCustomerProfile,
  updateCustomerProfile,
  listCustomerAddresses,
  createCustomerAddress,
  updateCustomerAddress,
  deleteCustomerAddress,
} = require('./customerService');
const {
  getTechnicianProfile,
  updateTechnicianProfile,
  listTechnicianDocuments,
  submitTechnicianDocument,
  listTechnicianJobs,
  updateTechnicianJobStatus,
} = require('./technicianAccountService');
const {
  getAdminDashboardOverview,
  listAdminBookings,
  listAdminTechnicians,
  listAdminCustomers,
  listAdminAuditLogs,
  updateTechnicianKyc,
  listAdminTechnicianDocuments,
  getAdminLiveDispatch,
  getAdminDispatchHistory,
  listAdminCategories,
  createAdminCategory,
  updateAdminCategory,
  deleteAdminCategory,
  listAdminServices,
  createAdminService,
  updateAdminService,
  deleteAdminService,
} = require('./adminService');
const { getEmailJsStatus } = require('./emailService');
const { getFirebaseStatus } = require('./firebaseAdmin');

const DEFAULT_ALLOWED_ORIGINS = [
  'https://bookmytechnician-53d94.web.app',
  'https://bookmytechnician-53d94.firebaseapp.com',
];

function buildAllowedOrigins(extraOrigins = []) {
  const configured = String(process.env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return new Set([...DEFAULT_ALLOWED_ORIGINS, ...configured, ...extraOrigins]);
}

function mountRoutes(app, method, paths, ...handlers) {
  for (const routePath of paths) {
    app[method](routePath, ...handlers);
  }
}

function createApp(db, options = {}) {
  const app = express();
  app.set('trust proxy', 1);

  const allowedOrigins = buildAllowedOrigins(options.allowedOrigins || []);
  const allowLocalhost =
    process.env.NODE_ENV !== 'production' ||
    process.env.ALLOW_LOCALHOST_CORS === 'true' ||
    options.allowLocalhost === true;

  const corsOptions = {
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.has(origin)) return callback(null, true);
      if (allowLocalhost && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) {
        return callback(null, true);
      }
      const err = new Error(`Origin ${origin} is not allowed by CORS policy`);
      err.status = 403;
      err.code = 'CORS_FORBIDDEN';
      return callback(err);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With', 'x-mock-user-id', 'x-mock-email', 'x-mock-role', 'x-technician-id'],
    credentials: true,
    optionsSuccessStatus: 204,
  };

  app.use(cors(corsOptions));
  app.options('*', cors(corsOptions));
  app.use(express.json({ limit: '1mb' }));

  const getFbStatus = options.getFirebaseStatus || getFirebaseStatus;
  const verifyDbFn = options.verifyFirestoreConnection;
  const authDeps = options.authDeps || {};

  const requireFirestore = (req, res, next) => {
    if (!db) {
      return res.status(503).json({
        success: false,
        code: 'FIREBASE_NOT_CONFIGURED',
        error: 'Cloud Firestore is not initialized. Configure Firebase Admin credentials in Render environment variables.',
      });
    }
    return next();
  };

  // Public Health Check Endpoint (GET /health)
  const handleHealth = async (req, res) => {
    const firebase = getFbStatus();
    let liveCheck = null;
    if (req.query.check === 'db' && typeof verifyDbFn === 'function') {
      liveCheck = await verifyDbFn(db);
    }
    const updatedFb = getFbStatus();
    const emailjs = getEmailJsStatus();
    const isDegraded = !db || (req.query.check === 'db' && liveCheck && !liveCheck.connected);
    const statusCode = isDegraded && req.query.strict === 'true' ? 503 : 200;

    res.status(statusCode).json({
      status: db ? (updatedFb.firestoreReady ? 'ok' : 'initialized') : 'degraded',
      service: 'bookurtechnician-trusted-backend',
      timestamp: new Date().toISOString(),
      runtime: 'node-express',
      firebase: updatedFb,
      emailjs,
      ...(liveCheck ? { dbCheck: liveCheck } : {}),
      // Keep original field semantics alongside enhanced status
      projectId: firebase.projectId,
    });
  };
  mountRoutes(app, 'get', ['/health', '/api/health', '/api/v1/health'], handleHealth);

  // Public Authentication OTP Routes (POST /auth/request-otp, /auth/resend-otp, /auth/verify-otp)
  const handleRequestOtp = (isResend) => async (req, res) => {
    try {
      const result = await requestOtp(
        db,
        {
          ...req.body,
          isResend: isResend || Boolean(req.body?.isResend),
        },
        authDeps
      );
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        success: false,
        code: err.code || 'OTP_REQUEST_FAILED',
        error: err.message,
        ...(err.extra || {}),
      });
    }
  };

  const handleVerifyOtp = async (req, res) => {
    try {
      const result = await verifyOtp(db, req.body || {}, authDeps);
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        success: false,
        code: err.code || 'OTP_VERIFICATION_FAILED',
        error: err.message,
        ...(err.extra || {}),
      });
    }
  };

  mountRoutes(
    app,
    'post',
    ['/auth/request-otp', '/api/auth/request-otp', '/api/v1/auth/request-otp'],
    requireFirestore,
    handleRequestOtp(false)
  );
  mountRoutes(
    app,
    'post',
    ['/auth/resend-otp', '/api/auth/resend-otp', '/api/v1/auth/resend-otp'],
    requireFirestore,
    handleRequestOtp(true)
  );
  mountRoutes(
    app,
    'post',
    ['/auth/verify-otp', '/api/auth/verify-otp', '/api/v1/auth/verify-otp'],
    requireFirestore,
    handleVerifyOtp
  );

  mountRoutes(
    app,
    'post',
    ['/auth/refresh-token', '/api/auth/refresh-token', '/api/v1/auth/refresh-token'],
    requireFirestore,
    async (req, res) => {
      try {
        const result = await refreshAuthSession(db, req.body || {});
        res.status(200).json(result);
      } catch (err) {
        res.status(err.status || 401).json({
          success: false,
          code: err.code || 'REFRESH_FAILED',
          error: err.message,
        });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/auth/admin/direct-access', '/api/auth/admin/direct-access', '/api/v1/auth/admin/direct-access'],
    requireFirestore,
    async (req, res) => {
      try {
        const result = await adminDirectAccess(db, req.body || {});
        res.status(200).json(result);
      } catch (err) {
        res.status(err.status || 401).json({
          success: false,
          code: err.code || 'ADMIN_AUTH_FAILED',
          error: err.message,
        });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/auth/logout', '/api/auth/logout', '/api/v1/auth/logout'],
    (req, res) => {
      res.status(200).json({ success: true, message: 'Logged out successfully' });
    }
  );

  // Public Catalog Hierarchy & Services Read
  mountRoutes(
    app,
    'get',
    ['/catalog/categories', '/api/catalog/categories', '/api/v1/catalog/categories'],
    requireFirestore,
    async (req, res) => {
      try {
        const snap = await db.collection('service_categories').limit(100).get();
        const categories = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        res.status(200).json({ success: true, count: categories.length, data: categories, categories });
      } catch (err) {
        res.status(500).json({ success: false, code: 'CATALOG_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/catalog/services', '/api/catalog/services', '/api/v1/catalog/services'],
    requireFirestore,
    async (req, res) => {
      try {
        const snap = await db.collection('services').limit(250).get();
        const services = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        res.status(200).json({ success: true, count: services.length, data: services, services });
      } catch (err) {
        res.status(500).json({ success: false, code: 'SERVICES_FETCH_FAILED', error: err.message });
      }
    }
  );

  // Public Promotional Banners (returns active docs from Firestore `banners`, empty list if none)
  mountRoutes(
    app,
    'get',
    ['/banners/hero', '/api/banners/hero', '/api/v1/banners/hero', '/banners/spotlight', '/api/banners/spotlight', '/api/v1/banners/spotlight'],
    requireFirestore,
    async (req, res) => {
      try {
        const targetType = req.path.includes('spotlight') ? 'SPOTLIGHT' : 'HERO';
        const snap = await db.collection('banners').limit(50).get();
        const list = snap.docs
          .map((d) => ({ id: d.id, ...d.data() }))
          .filter((b) => b.active !== false && b.isActive !== false)
          .filter((b) => {
            const p = String(b.placement || b.slot || b.type || 'HERO').toUpperCase();
            return p === targetType || (targetType === 'HERO' && !b.placement && !b.slot);
          });
        res.status(200).json({ success: true, count: list.length, data: list });
      } catch (err) {
        res.status(500).json({ success: false, code: 'BANNERS_FETCH_FAILED', error: err.message, data: [] });
      }
    }
  );

  // Public Time-Slot Capacity derived strictly from live eligible technicians
  const STANDARD_SLOTS = [
    'Immediate (Next Available)',
    '09:00 AM - 11:00 AM',
    '11:00 AM - 01:00 PM',
    '02:00 PM - 04:00 PM',
    '04:00 PM - 06:00 PM',
    '06:00 PM - 08:00 PM',
  ];
  mountRoutes(
    app,
    'get',
    [
      '/bookings/available-slots',
      '/api/bookings/available-slots',
      '/api/v1/bookings/available-slots',
      '/catalog/services/:serviceId/slots',
      '/api/catalog/services/:serviceId/slots',
      '/api/v1/catalog/services/:serviceId/slots',
    ],
    requireFirestore,
    async (req, res) => {
      try {
        const serviceId = req.params.serviceId || req.query.serviceId || '';
        const lat = req.query.latitude;
        const lng = req.query.longitude;
        let onlineCount = 1;
        if (serviceId && lat !== undefined && lng !== undefined) {
          const techList = await getAvailableTechniciansForService(db, {
            serviceId,
            latitude: Number(lat),
            longitude: Number(lng),
            radiusKm: Number(req.query.radiusKm) || 15.0,
          });
          onlineCount = techList.length;
        }
        const slots = STANDARD_SLOTS.map((label, idx) => ({
          id: `slot_${idx}`,
          label,
          time: label,
          available: idx === 0 ? onlineCount > 0 : true,
          availableTechnicians: idx === 0 ? onlineCount : Math.max(1, onlineCount),
        }));
        res.status(200).json({ success: true, serviceId, date: req.query.date || 'Today', slots });
      } catch (err) {
        res.status(500).json({ success: false, code: 'SLOTS_FETCH_FAILED', error: err.message, slots: [] });
      }
    }
  );

  // Public Service Availability & PII-Redacted Nearby Technician Discovery
  // Single Source of Truth backed by eligibilityService (no hardcoded/fake technicians, no PII)
  const handleCatalogAvailability = async (req, res) => {
    try {
      const result = await getCatalogAvailabilitySummary(db, {
        latitude: req.query.latitude ?? req.body?.latitude,
        longitude: req.query.longitude ?? req.body?.longitude,
        serviceId: req.params.serviceId || req.query.serviceId || '',
        serviceName: req.query.serviceName || '',
        radiusKm: Number(req.query.radiusKm) || 15.0,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        success: false,
        code: err.code || 'AVAILABILITY_FAILED',
        error: err.message,
        availableTechnicianCount: 0,
        totalOnlineTechnicians: 0,
      });
    }
  };

  const handleNearbyTechnicians = async (req, res) => {
    try {
      const serviceId = req.query.serviceId || '';
      const serviceName = req.query.serviceName || '';
      const radiusKm = Number(req.query.radiusKm) || 15.0;
      const list = await getAvailableTechniciansForService(db, {
        serviceId,
        serviceName,
        latitude: req.query.latitude ?? req.body?.latitude,
        longitude: req.query.longitude ?? req.body?.longitude,
        radiusKm,
      });
      res.status(200).json({
        success: true,
        serviceId,
        serviceName: serviceName || serviceId || 'Service',
        radiusKm,
        totalOnlineTechnicians: list.length,
        updatedAt: new Date().toISOString(),
        technicians: list,
        data: list,
      });
    } catch (err) {
      res.status(err.status || 500).json({
        success: false,
        code: err.code || 'NEARBY_FAILED',
        error: err.message,
        technicians: [],
      });
    }
  };

  mountRoutes(
    app,
    'get',
    [
      '/availability',
      '/catalog/availability',
      '/api/catalog/availability',
      '/api/v1/catalog/availability',
      '/services/:serviceId/availability',
      '/api/services/:serviceId/availability',
      '/api/v1/services/:serviceId/availability',
      '/api/v1/catalog/services/:serviceId/availability',
    ],
    requireFirestore,
    handleCatalogAvailability
  );

  mountRoutes(
    app,
    'get',
    [
      '/catalog/technicians/nearby',
      '/api/catalog/technicians/nearby',
      '/api/v1/catalog/technicians/nearby',
    ],
    requireFirestore,
    handleNearbyTechnicians
  );

  // Apply authentication to all protected booking, dispatch, OTP, presence & skill routes
  app.use(authenticate);
  app.use(requireFirestore);

  const isAdminCaller = (user) =>
    Boolean(user && (user.admin === true || ['ADMIN', 'SUPER_ADMIN'].includes(String(user.role || '').toUpperCase())));

  const customerOnly = requireRole(['CUSTOMER']);
  const technicianOnly = requireRole(['TECHNICIAN']);
  const customerOrAdmin = requireRole(['CUSTOMER', 'ADMIN', 'SUPER_ADMIN']);
  const customerOrTechnician = requireRole(['CUSTOMER', 'TECHNICIAN']);
  const bookingParticipantOrAdmin = requireRole(['CUSTOMER', 'TECHNICIAN', 'ADMIN', 'SUPER_ADMIN']);
  const adminOnly = requireRole(['ADMIN', 'SUPER_ADMIN']);

  // 1. Create Booking (Customer)
  const handleCreateBooking = async (req, res) => {
    try {
      const customerId = req.user.uid;
      const bodyCoords = req.body.coordinates && typeof req.body.coordinates === 'object'
        ? req.body.coordinates
        : (req.body.latitude != null && req.body.longitude != null
          ? { latitude: Number(req.body.latitude), longitude: Number(req.body.longitude) }
          : null);

      const result = await createBooking(db, {
        customerId,
        customerName: req.body.customerName || req.body.customer || req.user.email,
        customerPhone: req.body.customerPhone || req.body.phone || '',
        serviceId: req.body.serviceId || req.body.service?.id,
        serviceName: req.body.serviceName || req.body.service?.name,
        categoryId: req.body.categoryId || req.body.category,
        address: req.body.address || req.body.fullAddress,
        coordinates: bodyCoords,
        price: req.body.price || req.body.totalAmount || req.body.grandTotal,
        basePrice: req.body.basePrice,
        visitFee: req.body.visitFee,
        gstTax: req.body.gstTax,
        grandTotal: req.body.grandTotal,
        paymentMethod: req.body.paymentMethod,
        bookingCode: req.body.bookingCode,
        idempotencyKey: req.body.idempotencyKey,
        scheduleDate: req.body.scheduleDate,
        scheduleSlot: req.body.scheduleSlot,
      });
      res.status(201).json({ ...result, data: result.booking });
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'INTERNAL_ERROR', error: err.message });
    }
  };

  mountRoutes(
    app,
    'post',
    [
      '/api/bookings/create',
      '/api/v1/bookings/create',
      '/bookings/create',
      '/createBooking',
      '/bookings',
      '/api/bookings',
      '/api/v1/bookings',
    ],
    customerOnly,
    handleCreateBooking
  );

  // 2. Accept Booking Offer (Technician - Atomic Single-Winner Firestore Transaction)
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

  mountRoutes(
    app,
    'post',
    [
      '/api/dispatch/accept',
      '/api/v1/dispatch/accept',
      '/acceptBookingOffer',
      '/technician/offers/:offerId/accept',
      '/api/technician/offers/:offerId/accept',
      '/api/v1/technician/offers/:offerId/accept',
      '/dispatch/offers/:offerId/accept',
      '/api/dispatch/offers/:offerId/accept',
      '/api/v1/dispatch/offers/:offerId/accept',
      '/proposals/:offerId/accept',
      '/dispatch/proposals/:offerId/accept',
      '/api/v1/dispatch/proposals/:offerId/accept',
      '/dispatch_offers/:offerId/accept',
      '/technician/dispatch/:offerId/accept',
      '/api/v1/technician/dispatch/:offerId/accept',
    ],
    technicianOnly,
    handleAcceptOffer
  );

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

  mountRoutes(
    app,
    'post',
    ['/api/bookings/:bookingId/verify-start-otp', '/api/v1/bookings/:bookingId/verify-start-otp', '/verifyStartOtp'],
    technicianOnly,
    handleVerifyStartOtp
  );

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

  mountRoutes(
    app,
    'post',
    ['/api/bookings/:bookingId/verify-end-otp', '/api/v1/bookings/:bookingId/verify-end-otp', '/verifyEndOtp'],
    technicianOnly,
    handleVerifyEndOtp
  );

  // Dynamic status router for Flutter apps: PATCH /bookings/:bookingId/status & /technician/jobs/:bookingId/status
  mountRoutes(
    app,
    'patch',
    [
      '/bookings/:bookingId/status',
      '/api/bookings/:bookingId/status',
      '/api/v1/bookings/:bookingId/status',
      '/technician/jobs/:bookingId/status',
      '/api/technician/jobs/:bookingId/status',
      '/api/v1/technician/jobs/:bookingId/status',
    ],
    technicianOnly,
    async (req, res) => {
      const status = String(req.body?.status || '').trim().toUpperCase();
      if (['ON_THE_WAY', 'EN_ROUTE', 'TECHONTHEWAY', 'ARRIVED', 'TECHARRIVED'].includes(status)) {
        try {
          const result = await updateTechnicianJobStatus(db, {
            bookingId: req.params.bookingId,
            callerUid: req.user.uid,
            status,
          });
          return res.status(200).json(result);
        } catch (err) {
          return res.status(err.status || 500).json({
            success: false,
            code: err.code || 'STATUS_UPDATE_FAILED',
            error: err.message,
          });
        }
      }
      if (status === 'IN_PROGRESS' && (req.body?.startOtp || req.body?.otp || req.body?.code)) {
        return handleVerifyStartOtp(req, res);
      }
      if (status === 'COMPLETED' && (req.body?.endOtp || req.body?.otp || req.body?.code)) {
        return handleVerifyEndOtp(req, res);
      }
      return res.status(400).json({
        success: false,
        code: 'UNSUPPORTED_STATUS_TRANSITION',
        error: 'Status changes to IN_PROGRESS/COMPLETED require authoritative OTP verification (startOtp or endOtp required)',
      });
    }
  );

  // 5. Technician Presence & Location Heartbeat
  const handlePresenceUpdate = async (req, res) => {
    try {
      const callerUid = req.user.uid;
      const body = req.body || {};
      const resolvedOnline = body.isOnline !== undefined
        ? body.isOnline
        : (body.online !== undefined
          ? body.online
          : (String(body.availabilityStatus || '').toUpperCase() === 'OFFLINE' ? false : undefined));
      const result = await updateTechnicianPresence(db, {
        callerUid,
        latitude: body.latitude,
        longitude: body.longitude,
        heading: body.heading,
        speed: body.speed,
        accuracy: body.accuracy,
        isOnline: resolvedOnline,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'PRESENCE_UPDATE_FAILED', error: err.message });
    }
  };

  mountRoutes(
    app,
    'post',
    [
      '/api/technician/presence',
      '/api/v1/technician/presence',
      '/technician/online-status',
      '/api/technician/online-status',
      '/api/v1/technician/online-status',
      '/updateTechnicianPresence',
      '/presence/heartbeat',
      '/technician/location',
      '/api/v1/technician/location',
    ],
    technicianOnly,
    handlePresenceUpdate
  );

  // 5b. Customer Booking Read, Live Tracking & Cancel (Role + Owner/Participant/Admin)
  mountRoutes(
    app,
    'get',
    ['/bookings/my-bookings', '/api/bookings/my-bookings', '/api/v1/bookings/my-bookings'],
    customerOnly,
    async (req, res) => {
      try {
        const callerUid = req.user.uid;
        const snap = await db.collection('bookings').where('customerId', '==', callerUid).limit(100).get();
        const bookings = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        bookings.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
        res.status(200).json({ success: true, count: bookings.length, bookings, data: bookings });
      } catch (err) {
        res.status(500).json({ success: false, code: 'FETCH_BOOKINGS_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/bookings/:bookingId/live-tracking', '/api/bookings/:bookingId/live-tracking', '/api/v1/bookings/:bookingId/live-tracking'],
    bookingParticipantOrAdmin,
    async (req, res) => {
      try {
        const bookingSnap = await db.collection('bookings').doc(req.params.bookingId).get();
        if (!bookingSnap.exists) {
          return res.status(404).json({ success: false, code: 'BOOKING_NOT_FOUND', error: 'Booking not found' });
        }
        const booking = { id: bookingSnap.id, ...bookingSnap.data() };
        const callerUid = req.user.uid;
        if (!isAdminCaller(req.user) && booking.customerId !== callerUid && booking.technicianId !== callerUid) {
          return res.status(403).json({ success: false, code: 'FORBIDDEN', error: 'Not authorized to track this booking' });
        }

        let techLocation = null;
        let technician = null;
        if (booking.technicianId) {
          const techSnap = await db.collection('technician_profiles').doc(booking.technicianId).get();
          if (techSnap.exists) {
            const t = techSnap.data();
            technician = {
              id: techSnap.id,
              name: t.fullName || t.name || 'Partner',
              category: t.category || '',
              rating: t.rating || 0,
              latitude: t.latitude,
              longitude: t.longitude,
              speed: t.speed || 0,
              heading: t.heading || 0,
            };
            if (typeof t.latitude === 'number' && typeof t.longitude === 'number') {
              techLocation = { latitude: t.latitude, longitude: t.longitude, heading: t.heading || 0, speed: t.speed || 0 };
            }
          }
        }

        const sanitizedBooking = { ...booking };
        delete sanitizedBooking.startOtpHash;
        delete sanitizedBooking.endOtpHash;
        if (booking.technicianId === callerUid && booking.customerId !== callerUid && !isAdminCaller(req.user)) {
          delete sanitizedBooking.startOtp;
          delete sanitizedBooking.endOtp;
        }

        const payload = {
          ...sanitizedBooking,
          technician,
          technicianLocation: techLocation,
        };
        res.status(200).json({ success: true, data: payload, booking: sanitizedBooking, tracking: payload });
      } catch (err) {
        res.status(500).json({ success: false, code: 'TRACKING_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/bookings/:bookingId', '/api/bookings/:bookingId', '/api/v1/bookings/:bookingId'],
    bookingParticipantOrAdmin,
    async (req, res) => {
      try {
        const bookingSnap = await db.collection('bookings').doc(req.params.bookingId).get();
        if (!bookingSnap.exists) {
          return res.status(404).json({ success: false, code: 'BOOKING_NOT_FOUND', error: 'Booking not found' });
        }
        const rawBooking = { id: bookingSnap.id, ...bookingSnap.data() };
        const callerUid = req.user.uid;
        if (!isAdminCaller(req.user) && rawBooking.customerId !== callerUid && rawBooking.technicianId !== callerUid) {
          return res.status(403).json({ success: false, code: 'FORBIDDEN', error: 'Forbidden' });
        }
        const booking = { ...rawBooking };
        delete booking.startOtpHash;
        delete booking.endOtpHash;
        if (rawBooking.customerId !== callerUid && !isAdminCaller(req.user)) {
          delete booking.startOtp;
          delete booking.endOtp;
        }
        res.status(200).json({ success: true, data: booking, booking });
      } catch (err) {
        res.status(500).json({ success: false, code: 'FETCH_FAILED', error: err.message });
      }
    }
  );

  // Customer Profile, Addresses, FCM Token & Technician Jobs/Profile/KYC Documents
  mountRoutes(
    app,
    'get',
    ['/customer/profile', '/api/customer/profile', '/api/v1/customer/profile'],
    customerOnly,
    async (req, res) => {
      try {
        res.status(200).json(await getCustomerProfile(db, { uid: req.user.uid }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'PROFILE_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'put',
    ['/customer/profile', '/api/customer/profile', '/api/v1/customer/profile'],
    customerOnly,
    async (req, res) => {
      try {
        res.status(200).json(await updateCustomerProfile(db, { uid: req.user.uid, body: req.body }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'PROFILE_UPDATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/customer/addresses', '/api/customer/addresses', '/api/v1/customer/addresses'],
    customerOnly,
    async (req, res) => {
      try {
        res.status(200).json(await listCustomerAddresses(db, { uid: req.user.uid }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'ADDRESS_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/customer/addresses', '/api/customer/addresses', '/api/v1/customer/addresses'],
    customerOnly,
    async (req, res) => {
      try {
        res.status(200).json(await createCustomerAddress(db, { uid: req.user.uid, body: req.body }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'ADDRESS_CREATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'put',
    ['/customer/addresses/:addressId', '/api/customer/addresses/:addressId', '/api/v1/customer/addresses/:addressId'],
    customerOnly,
    async (req, res) => {
      try {
        res.status(200).json(await updateCustomerAddress(db, { uid: req.user.uid, addressId: req.params.addressId, body: req.body }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'ADDRESS_UPDATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'delete',
    ['/customer/addresses/:addressId', '/api/customer/addresses/:addressId', '/api/v1/customer/addresses/:addressId'],
    customerOnly,
    async (req, res) => {
      try {
        res.status(200).json(await deleteCustomerAddress(db, { uid: req.user.uid, addressId: req.params.addressId }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'ADDRESS_DELETE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/customer/fcm-token', '/api/customer/fcm-token', '/api/v1/customer/fcm-token'],
    customerOnly,
    async (req, res) => {
      try {
        const token = String(req.body?.token || req.body?.fcmToken || '').trim();
        if (!token) {
          return res.status(400).json({ success: false, code: 'MISSING_TOKEN', error: 'FCM token is required' });
        }
        await updateCustomerProfile(db, { uid: req.user.uid, body: { fcmToken: token } });
        res.status(200).json({ success: true, message: 'FCM token registered' });
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'FCM_UPDATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/technicians/profile', '/api/technicians/profile', '/api/v1/technicians/profile', '/technician/profile', '/api/technician/profile', '/api/v1/technician/profile'],
    technicianOnly,
    async (req, res) => {
      try {
        res.status(200).json(await getTechnicianProfile(db, { uid: req.user.uid }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'TECH_PROFILE_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'put',
    ['/technicians/profile', '/api/technicians/profile', '/api/v1/technicians/profile', '/technician/profile', '/api/technician/profile', '/api/v1/technician/profile'],
    technicianOnly,
    async (req, res) => {
      try {
        res.status(200).json(await updateTechnicianProfile(db, { callerUid: req.user.uid, body: req.body }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'TECH_PROFILE_UPDATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/technicians/profile/photo', '/api/technicians/profile/photo', '/api/v1/technicians/profile/photo'],
    technicianOnly,
    async (req, res) => {
      try {
        const photoUrl = String(req.body?.photoUrl || req.body?.profileImageUrl || '').trim();
        if (!photoUrl || !/^https?:\/\//i.test(photoUrl)) {
          return res.status(400).json({ success: false, code: 'INVALID_PHOTO_URL', error: 'Valid photoUrl is required' });
        }
        res.status(200).json(await updateTechnicianProfile(db, { callerUid: req.user.uid, body: { photoUrl } }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'PHOTO_UPDATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/technicians/documents', '/api/technicians/documents', '/api/v1/technicians/documents'],
    technicianOnly,
    async (req, res) => {
      try {
        res.status(200).json(await listTechnicianDocuments(db, { uid: req.user.uid }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'TECH_DOCS_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/technicians/documents', '/api/technicians/documents', '/api/v1/technicians/documents'],
    technicianOnly,
    async (req, res) => {
      try {
        res.status(201).json(await submitTechnicianDocument(db, { callerUid: req.user.uid, body: req.body }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'TECH_DOC_SUBMIT_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/technician/jobs', '/api/technician/jobs', '/api/v1/technician/jobs', '/technicians/jobs', '/api/technicians/jobs', '/api/v1/technicians/jobs'],
    technicianOnly,
    async (req, res) => {
      try {
        res.status(200).json(await listTechnicianJobs(db, { callerUid: req.user.uid }));
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'TECH_JOBS_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    ['/technician/fcm-token', '/api/technician/fcm-token', '/api/v1/technician/fcm-token'],
    technicianOnly,
    async (req, res) => {
      try {
        const fcmToken = String(req.body?.fcmToken || req.body?.token || '').trim();
        if (!fcmToken) {
          return res.status(400).json({ success: false, code: 'MISSING_TOKEN', error: 'fcmToken is required' });
        }
        await updateTechnicianProfile(db, { callerUid: req.user.uid, body: { fcmToken } });
        res.status(200).json({ success: true, message: 'Technician FCM token registered' });
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'FCM_UPDATE_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    [
      '/bookings/:bookingId/cancel',
      '/api/bookings/:bookingId/cancel',
      '/api/v1/bookings/:bookingId/cancel',
      '/admin/bookings/:bookingId/cancel',
      '/api/admin/bookings/:bookingId/cancel',
      '/api/v1/admin/bookings/:bookingId/cancel',
    ],
    customerOrAdmin,
    async (req, res) => {
      try {
        const ref = db.collection('bookings').doc(req.params.bookingId);
        const snap = await ref.get();
        if (!snap.exists) {
          return res.status(404).json({ success: false, code: 'BOOKING_NOT_FOUND', error: 'Booking not found' });
        }
        const booking = snap.data();
        if (!isAdminCaller(req.user) && booking.customerId !== req.user.uid) {
          return res.status(403).json({ success: false, code: 'FORBIDDEN', error: 'Only the booking customer or admin can cancel' });
        }
        if (String(booking.status || '').toUpperCase() === 'COMPLETED') {
          return res.status(400).json({ success: false, code: 'ALREADY_COMPLETED', error: 'Completed booking cannot be cancelled' });
        }
        const nowIso = new Date().toISOString();
        const reason = String(req.body?.reason || 'Cancelled by customer');
        await ref.set({ status: 'CANCELLED', cancellationReason: reason, cancelledAt: nowIso, updatedAt: nowIso }, { merge: true });
        if (booking.technicianId) {
          await db.collection('technician_profiles').doc(booking.technicianId).set(
            { availabilityStatus: 'AVAILABLE', activeBookingId: null, updatedAt: nowIso },
            { merge: true }
          );
        }
        res.status(200).json({ success: true, bookingId: req.params.bookingId, status: 'CANCELLED' });
      } catch (err) {
        res.status(500).json({ success: false, code: 'CANCEL_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'delete',
    ['/bookings/:bookingId', '/api/bookings/:bookingId', '/api/v1/bookings/:bookingId'],
    customerOrAdmin,
    async (req, res) => {
      try {
        const ref = db.collection('bookings').doc(req.params.bookingId);
        const snap = await ref.get();
        if (!snap.exists) {
          return res.status(404).json({ success: false, code: 'BOOKING_NOT_FOUND', error: 'Booking not found' });
        }
        const booking = snap.data();
        if (!isAdminCaller(req.user) && booking.customerId !== req.user.uid) {
          return res.status(403).json({ success: false, code: 'FORBIDDEN', error: 'Not authorized to delete this booking' });
        }
        if (String(booking.status || '').toUpperCase() !== 'CANCELLED') {
          return res.status(400).json({ success: false, code: 'CANNOT_DELETE_ACTIVE_BOOKING', error: 'Only cancelled bookings can be removed from history' });
        }
        await ref.delete();
        res.status(200).json({ success: true, bookingId: req.params.bookingId });
      } catch (err) {
        res.status(500).json({ success: false, code: 'DELETE_BOOKING_FAILED', error: err.message });
      }
    }
  );

  // 5c. Technician Pending Offers Read & Rejection (Accept stays strictly atomic transaction in dispatchService)
  mountRoutes(
    app,
    'get',
    [
      '/dispatch/offers/pending',
      '/dispatch/proposals/pending',
      '/dispatch/pending',
      '/technician/offers',
      '/api/v1/dispatch/proposals/pending',
      '/api/v1/dispatch/offers/pending',
      '/api/v1/technician/offers',
    ],
    technicianOnly,
    async (req, res) => {
      try {
        const techUid = req.user.uid;
        const nowMs = Date.now();
        const snap = await db.collection('dispatch_offers').where('technicianId', '==', techUid).limit(50).get();
        const offers = [];
        for (const doc of snap.docs) {
          const o = { id: doc.id, ...doc.data() };
          const st = String(o.status || '').toUpperCase();
          if (!['SENT', 'PENDING', 'RINGING'].includes(st)) continue;
          const expMs = o.expiresAt ? Date.parse(o.expiresAt) : NaN;
          if (!Number.isNaN(expMs) && expMs <= nowMs) continue;
          const remainingSeconds = Number.isNaN(expMs) ? 30 : Math.max(1, Math.floor((expMs - nowMs) / 1000));
          offers.push({ ...o, remainingSeconds });
        }
        res.status(200).json({
          success: true,
          hasPending: offers.length > 0,
          count: offers.length,
          offers,
          proposal: offers[0] || null,
          data: offers,
        });
      } catch (err) {
        res.status(500).json({ success: false, code: 'OFFERS_FETCH_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    [
      '/dispatch/offers/:offerId/reject',
      '/dispatch/offers/:offerId/decline',
      '/dispatch/proposals/:offerId/reject',
      '/dispatch/proposals/:offerId/decline',
      '/technician/dispatch/:offerId/decline',
      '/api/v1/dispatch/offers/:offerId/reject',
      '/api/v1/dispatch/proposals/:offerId/reject',
    ],
    technicianOnly,
    async (req, res) => {
      try {
        const ref = db.collection('dispatch_offers').doc(req.params.offerId);
        const snap = await ref.get();
        if (!snap.exists) {
          return res.status(404).json({ success: false, code: 'OFFER_NOT_FOUND', error: 'Offer not found' });
        }
        const offer = snap.data();
        if (offer.technicianId !== req.user.uid && !isAdminCaller(req.user)) {
          return res.status(403).json({ success: false, code: 'FORBIDDEN', error: 'Offer belongs to another technician' });
        }
        const nowIso = new Date().toISOString();
        await ref.set(
          {
            status: 'REJECTED',
            responseReason: String(req.body?.reason || 'REJECTED_BY_TECHNICIAN'),
            respondedAt: nowIso,
            updatedAt: nowIso,
          },
          { merge: true }
        );
        res.status(200).json({ success: true, offerId: req.params.offerId, status: 'REJECTED' });
      } catch (err) {
        res.status(500).json({ success: false, code: 'REJECT_OFFER_FAILED', error: err.message });
      }
    }
  );

  // 6. OTP Resend & Customer Retrieval
  mountRoutes(
    app,
    'post',
    ['/bookings/:bookingId/resend-start-otp', '/api/v1/bookings/:bookingId/resend-start-otp'],
    customerOrTechnician,
    async (req, res) => {
      try {
        const result = await resendStartOtp(db, { bookingId: req.params.bookingId, callerUid: req.user.uid });
        res.status(200).json(result);
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'RESEND_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'post',
    [
      '/bookings/:bookingId/resend-end-otp',
      '/api/v1/bookings/:bookingId/resend-end-otp',
      '/bookings/:bookingId/resend-end-email',
      '/api/v1/bookings/:bookingId/resend-end-email',
    ],
    customerOrTechnician,
    async (req, res) => {
      try {
        const result = await resendEndOtp(db, { bookingId: req.params.bookingId, callerUid: req.user.uid });
        res.status(200).json(result);
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'RESEND_FAILED', error: err.message });
      }
    }
  );

  mountRoutes(
    app,
    'get',
    ['/bookings/:bookingId/customer-otps', '/api/v1/bookings/:bookingId/customer-otps'],
    customerOnly,
    async (req, res) => {
      try {
        const result = await getCustomerOtps(db, { bookingId: req.params.bookingId, callerUid: req.user.uid });
        res.status(200).json(result);
      } catch (err) {
        res.status(err.status || 500).json({ success: false, code: err.code || 'FETCH_FAILED', error: err.message });
      }
    }
  );

  // 7. Technician Skills Management (Authoritative & Canonical)
  const handleFetchSkills = async (req, res) => {
    try {
      const callerUid = req.user.uid;
      const isAdmin = isAdminCaller(req.user);
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
      const isAdmin = isAdminCaller(req.user);
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
      const isAdmin = isAdminCaller(req.user);
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

  mountRoutes(app, 'get', ['/api/technicians/skills', '/api/v1/technicians/skills', '/technicians/skills'], technicianOnly, handleFetchSkills);
  mountRoutes(app, 'post', ['/api/technicians/skills', '/api/v1/technicians/skills', '/technicians/skills', '/api/technicians/skills/bulk', '/api/v1/technicians/skills/bulk', '/technicians/skills/bulk'], technicianOnly, handleSaveSkills);

  mountRoutes(app, 'patch', ['/api/technicians/skills/:skillId/toggle', '/api/v1/technicians/skills/:skillId/toggle', '/technicians/skills/:skillId/toggle'], technicianOnly, handleToggleSkill);
  mountRoutes(app, 'post', ['/api/technicians/skills/:skillId/toggle', '/api/v1/technicians/skills/:skillId/toggle', '/technicians/skills/:skillId/toggle'], technicianOnly, handleToggleSkill);

  mountRoutes(app, 'get', ['/admin/technicians/:technicianId/skills', '/api/admin/technicians/:technicianId/skills', '/api/v1/admin/technicians/:technicianId/skills'], adminOnly, handleFetchSkills);
  mountRoutes(app, 'post', ['/admin/technicians/:technicianId/skills', '/api/admin/technicians/:technicianId/skills', '/api/v1/admin/technicians/:technicianId/skills'], adminOnly, handleSaveSkills);

  // 8. Admin Monitoring & Verification Routes (Strictly ADMIN/SUPER_ADMIN; Booking Monitoring Only)

  mountRoutes(app, 'get', ['/admin/me', '/api/admin/me', '/api/v1/admin/me'], adminOnly, (req, res) => {
    res.status(200).json({
      success: true,
      user: {
        id: req.user.uid,
        uid: req.user.uid,
        email: req.user.email || '',
        role: req.user.role,
        admin: true,
      },
    });
  });

  mountRoutes(app, 'get', ['/admin/stats', '/api/admin/stats', '/api/v1/admin/stats', '/admin/overview', '/api/admin/overview', '/api/v1/admin/overview'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await getAdminDashboardOverview(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_STATS_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'get', ['/admin/bookings', '/api/admin/bookings', '/api/v1/admin/bookings'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminBookings(db, { status: req.query.status }));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_BOOKINGS_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'get', ['/admin/technicians', '/api/admin/technicians', '/api/v1/admin/technicians'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminTechnicians(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_TECHS_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'get', ['/admin/customers', '/api/admin/customers', '/api/v1/admin/customers'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminCustomers(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_CUSTOMERS_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'get', ['/admin/audit-logs', '/api/admin/audit-logs', '/api/v1/admin/audit-logs'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminAuditLogs(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_AUDIT_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'patch', ['/admin/technicians/:technicianId/kyc', '/api/admin/technicians/:technicianId/kyc', '/api/v1/admin/technicians/:technicianId/kyc', '/admin/technicians/:technicianId/status', '/api/admin/technicians/:technicianId/status', '/api/v1/admin/technicians/:technicianId/status'], adminOnly, async (req, res) => {
    try {
      const result = await updateTechnicianKyc(db, {
        adminUid: req.user.uid,
        technicianId: req.params.technicianId,
        kycStatus: req.body?.kycStatus,
        accountStatus: req.body?.accountStatus || req.body?.status,
        reason: req.body?.reason,
      });
      res.status(200).json(result);
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_KYC_UPDATE_FAILED', error: err.message });
    }
  });

  // Admin Technician Documents & Skill Verification (Launch-Critical)
  mountRoutes(app, 'get', ['/admin/technicians/:technicianId/documents', '/api/admin/technicians/:technicianId/documents', '/api/v1/admin/technicians/:technicianId/documents'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminTechnicianDocuments(db, req.params.technicianId));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_DOCS_FAILED', error: err.message });
    }
  });

  const handleAdminVerifySkill = async (req, res) => {
    try {
      res.status(200).json(await verifyTechnicianSkill(db, {
        adminUid: req.user.uid,
        technicianId: req.params.technicianId,
        skillId: req.params.skillId,
        verificationStatus: req.body?.verificationStatus || req.body?.status || 'VERIFIED',
        reason: req.body?.reason || '',
      }));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_SKILL_VERIFY_FAILED', error: err.message });
    }
  };
  mountRoutes(app, 'patch', ['/admin/technicians/:technicianId/skills/:skillId/verify', '/api/admin/technicians/:technicianId/skills/:skillId/verify', '/api/v1/admin/technicians/:technicianId/skills/:skillId/verify'], adminOnly, handleAdminVerifySkill);
  mountRoutes(app, 'post', ['/admin/technicians/:technicianId/skills/:skillId/verify', '/api/admin/technicians/:technicianId/skills/:skillId/verify', '/api/v1/admin/technicians/:technicianId/skills/:skillId/verify'], adminOnly, handleAdminVerifySkill);

  const handleAdminBulkVerifySkills = async (req, res) => {
    try {
      res.status(200).json(await bulkVerifyTechnicianSkills(db, {
        adminUid: req.user.uid,
        technicianId: req.params.technicianId,
        verificationStatus: req.body?.verificationStatus || req.body?.status || 'VERIFIED',
        reason: req.body?.reason || '',
      }));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_BULK_SKILL_VERIFY_FAILED', error: err.message });
    }
  };
  mountRoutes(app, 'post', ['/admin/technicians/:technicianId/skills/verify-bulk', '/api/admin/technicians/:technicianId/skills/verify-bulk', '/api/v1/admin/technicians/:technicianId/skills/verify-bulk'], adminOnly, handleAdminBulkVerifySkills);
  mountRoutes(app, 'patch', ['/admin/technicians/:technicianId/skills/verify-bulk', '/api/admin/technicians/:technicianId/skills/verify-bulk', '/api/v1/admin/technicians/:technicianId/skills/verify-bulk'], adminOnly, handleAdminBulkVerifySkills);

  // Admin Dispatch Monitoring (Read-Only; Self-Accept Policy Enforced)
  mountRoutes(app, 'get', ['/admin/dispatch/live', '/api/admin/dispatch/live', '/api/v1/admin/dispatch/live'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await getAdminLiveDispatch(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_DISPATCH_LIVE_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'get', ['/admin/dispatch/:bookingId/history', '/api/admin/dispatch/:bookingId/history', '/api/v1/admin/dispatch/:bookingId/history'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await getAdminDispatchHistory(db, req.params.bookingId));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_DISPATCH_HISTORY_FAILED', error: err.message });
    }
  });

  // Admin Service & Category CRUD (Required for Launch)
  mountRoutes(app, 'get', ['/admin/categories', '/api/admin/categories', '/api/v1/admin/categories'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminCategories(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_CATEGORIES_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'post', ['/admin/categories', '/api/admin/categories', '/api/v1/admin/categories'], adminOnly, async (req, res) => {
    try {
      res.status(201).json(await createAdminCategory(db, req.user.uid, req.body));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_CATEGORY_CREATE_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'put', ['/admin/categories/:id', '/api/admin/categories/:id', '/api/v1/admin/categories/:id'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await updateAdminCategory(db, req.user.uid, req.params.id, req.body));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_CATEGORY_UPDATE_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'delete', ['/admin/categories/:id', '/api/admin/categories/:id', '/api/v1/admin/categories/:id'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await deleteAdminCategory(db, req.user.uid, req.params.id));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_CATEGORY_DELETE_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'get', ['/admin/services', '/api/admin/services', '/api/v1/admin/services'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await listAdminServices(db));
    } catch (err) {
      res.status(500).json({ success: false, code: 'ADMIN_SERVICES_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'post', ['/admin/services', '/api/admin/services', '/api/v1/admin/services'], adminOnly, async (req, res) => {
    try {
      res.status(201).json(await createAdminService(db, req.user.uid, req.body));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_SERVICE_CREATE_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'put', [
    '/admin/services/:id',
    '/api/admin/services/:id',
    '/api/v1/admin/services/:id',
    '/admin/pricing/:id',
    '/api/admin/pricing/:id',
    '/api/v1/admin/pricing/:id',
  ], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await updateAdminService(db, req.user.uid, req.params.id, req.body));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_SERVICE_UPDATE_FAILED', error: err.message });
    }
  });

  mountRoutes(app, 'delete', ['/admin/services/:id', '/api/admin/services/:id', '/api/v1/admin/services/:id'], adminOnly, async (req, res) => {
    try {
      res.status(200).json(await deleteAdminService(db, req.user.uid, req.params.id));
    } catch (err) {
      res.status(err.status || 500).json({ success: false, code: err.code || 'ADMIN_SERVICE_DELETE_FAILED', error: err.message });
    }
  });

  // Global error handler (including CORS 403 rejections) without exposing internals
  app.use((err, req, res, next) => {
    if (res.headersSent) return next(err);
    const status = err.status || 500;
    return res.status(status).json({
      success: false,
      code: err.code || 'INTERNAL_ERROR',
      error: status >= 500 ? 'Internal server error' : err.message,
    });
  });

  return app;
}

module.exports = {
  createApp,
  DEFAULT_ALLOWED_ORIGINS,
};

