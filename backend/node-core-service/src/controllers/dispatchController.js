// ============================================================================
// BOOKURTECHNICIAN - DISPATCH CONTROLLER (PRODUCTION GRADE)
// Exposes Customer, Technician & Admin Dispatch Endpoints backed by
// automaticDispatchEngine.js with strict RBAC & ownership enforcement.
// ============================================================================

const automaticDispatchEngine = require('../services/automaticDispatchEngine');
const bookingsStore = require('../config/bookingsStore');
const { inMemoryTechProfiles } = require('../config/inMemoryTechStore');

/**
 * GET /api/v1/technicians/availability
 * Returns eligible & available technicians for a service, location, and appointment slot,
 * or returns a specific technician's working hours schedule.
 */
const getTechniciansAvailability = async (req, res) => {
  try {
    const {
      technicianId,
      latitude,
      longitude,
      serviceId,
      serviceName,
      category,
      scheduleDate,
      scheduleSlot,
      bookingMode = 'INSTANT',
      radiusKm = 15,
    } = req.query;

    if (technicianId) {
      const schedule = automaticDispatchEngine.getTechnicianAvailability(technicianId);
      const profile = inMemoryTechProfiles.get(technicianId) || null;
      return res.json({
        success: true,
        technicianId,
        isOnline: Boolean(profile?.isOnline ?? profile?.is_online),
        availabilityStatus: profile?.availabilityStatus || profile?.availability_status || 'AVAILABLE',
        schedule,
      });
    }

    if (latitude != null && longitude != null) {
      const { rankedCandidates, excludedDiagnostics } =
        await automaticDispatchEngine.findAndRankEligibleTechnicians(
          {
            serviceId,
            serviceName,
            category,
            latitude: parseFloat(latitude),
            longitude: parseFloat(longitude),
            scheduleDate,
            scheduleSlot,
            bookingMode,
          },
          parseFloat(radiusKm) || 15
        );

      return res.json({
        success: true,
        availableCount: rankedCandidates.length,
        radiusKm: parseFloat(radiusKm) || 15,
        bookingMode,
        technicians: rankedCandidates.map(c => ({
          technicianId: c.technicianId,
          name: c.name,
          category: c.category,
          rating: c.rating,
          completedJobs: c.completedJobs,
          distanceKm: c.distanceKm,
          etaMinutes: c.etaMinutes,
          etaSource: c.etaSource,
          rankingScore: c.rankingScore,
        })),
        excludedCount: excludedDiagnostics.length,
      });
    }

    // Default: list availability summary of all registered technicians
    const allTechs = Array.from(inMemoryTechProfiles.values()).map(t => ({
      technicianId: t.id || t.technicianId,
      name: t.name || t.fullName,
      category: t.category,
      kycStatus: t.kycStatus || t.kyc_status,
      isOnline: Boolean(t.isOnline ?? t.is_online),
      availabilityStatus: t.availabilityStatus || t.availability_status || 'AVAILABLE',
      schedule: automaticDispatchEngine.getTechnicianAvailability(t.id || t.technicianId),
    }));

    return res.json({
      success: true,
      count: allTechs.length,
      technicians: allTechs,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/availability
 * Updates working hours & unavailable windows for a technician.
 */
const updateTechnicianAvailability = async (req, res) => {
  try {
    const authUserId = req.user?.id;
    const userRole = String(req.user?.role || '').toUpperCase();
    const targetTechId =
      userRole === 'ADMIN' || userRole === 'SUPER_ADMIN'
        ? req.body.technicianId || authUserId
        : authUserId;

    if (!targetTechId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: Technician identity required' });
    }

    const scheduleList = Array.isArray(req.body.schedule)
      ? req.body.schedule
      : [req.body];

    const saved = await automaticDispatchEngine.setTechnicianAvailability(targetTechId, scheduleList);
    return res.json({
      success: true,
      technicianId: targetTechId,
      schedule: saved,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/dispatch/:bookingId/status
 */
const getDispatchStatus = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const statusData = automaticDispatchEngine.getBookingDispatchStatus(bookingId);
    if (!statusData) {
      return res.status(404).json({ success: false, error: 'Booking dispatch status not found' });
    }

    // Security check: Customer can only inspect their own booking status (unless Admin or assigned Technician)
    if (req.user) {
      const role = String(req.user.role || '').toUpperCase();
      const booking = bookingsStore.getBookingById(bookingId);
      if (
        role === 'CUSTOMER' &&
        booking &&
        booking.customerId &&
        String(booking.customerId) !== String(req.user.id)
      ) {
        return res.status(403).json({
          success: false,
          error: 'Forbidden: You cannot inspect another customer booking dispatch status',
        });
      }
    }

    return res.json({
      success: true,
      data: statusData,
      ...statusData,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/technician/offers (and legacy /api/v1/dispatch/pending)
 */
const getTechnicianOffers = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.query.technicianId;
    if (!technicianId) {
      return res.json({ success: true, hasPending: false, offers: [], proposal: null });
    }

    // If req.user is present and is a TECHNICIAN, enforce they can only query their own offers
    if (
      req.user &&
      String(req.user.role || '').toUpperCase() === 'TECHNICIAN' &&
      req.query.technicianId &&
      String(req.query.technicianId) !== String(req.user.id)
    ) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: Cannot view dispatch offers for another technician',
      });
    }

    const activeOffers = automaticDispatchEngine.getTechnicianActiveOffers(technicianId);
    const topOffer = activeOffers[0] || null;

    return res.json({
      success: true,
      hasPending: activeOffers.length > 0,
      count: activeOffers.length,
      offers: activeOffers,
      proposal: topOffer
        ? {
            proposalId: topOffer.id,
            offerId: topOffer.id,
            dispatchRequestId: topOffer.id,
            bookingId: topOffer.bookingId,
            serviceName: topOffer.serviceName,
            serviceType: topOffer.serviceName,
            approximateCustomerArea: topOffer.approximateArea,
            customerAddress: topOffer.approximateArea,
            customerName: 'Verified Customer',
            distanceKm: topOffer.distanceKm,
            estimatedTravelMinutes: topOffer.etaMinutes,
            appointmentTime: topOffer.appointmentTime,
            expectedEarning: topOffer.expectedEarning,
            payout: topOffer.expectedEarning,
            totalAmount: topOffer.totalAmount,
            remainingSeconds: topOffer.remainingSeconds,
            timeoutSeconds: topOffer.remainingSeconds,
            expiresAt: topOffer.expiresAt,
            attemptNumber: topOffer.attemptNumber,
          }
        : null,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/dispatch/proposals/:id
 */
const getDispatchRequestById = async (req, res) => {
  try {
    const { id } = req.params;
    const offer = automaticDispatchEngine.dispatchOffersStore.get(id);
    if (!offer) {
      return res.status(404).json({ success: false, error: 'Dispatch offer not found' });
    }
    return res.json({ success: true, data: offer, proposal: offer });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/dispatch/:bookingId/start
 */
const startDispatch = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = bookingsStore.getBookingById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, error: 'Booking not found' });
    }

    // Ownership check if Customer
    if (req.user) {
      const role = String(req.user.role || '').toUpperCase();
      if (role === 'CUSTOMER' && booking.customerId && String(booking.customerId) !== String(req.user.id)) {
        return res.status(403).json({ success: false, error: 'Forbidden: Cannot start dispatch for another customer booking' });
      }
      if (role === 'TECHNICIAN') {
        return res.status(403).json({ success: false, error: 'Forbidden: Technicians cannot trigger booking dispatch' });
      }
    }

    const session = await automaticDispatchEngine.startDispatchForBooking(booking, {
      bookingMode: req.body.bookingMode || booking.bookingMode || 'INSTANT',
      offerTimeoutSeconds: req.body.offerTimeoutSeconds,
      radiiKm: req.body.radiiKm,
      actorId: req.user?.id || 'SYSTEM',
      actorRole: req.user?.role || 'SYSTEM',
      forceRestart: Boolean(req.body.forceRestart),
      forceAuto: true,
    });

    return res.json({
      success: true,
      message: 'Automatic technician dispatch started',
      data: session,
      session,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/dispatch/offers/:offerId/accept
 * (Also handles legacy /api/v1/dispatch/proposals/:id/accept)
 */
const acceptDispatchOffer = async (req, res) => {
  try {
    const offerOrBookingId = req.params.offerId || req.params.id;
    const technicianId = req.user?.id || req.body?.technicianId;

    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: Authenticated technician identity required' });
    }

    if (req.user && String(req.user.role || '').toUpperCase() === 'CUSTOMER') {
      return res.status(403).json({ success: false, error: 'Forbidden: Customers cannot accept technician dispatch offers' });
    }

    const result = await automaticDispatchEngine.acceptOffer(offerOrBookingId, technicianId);

    return res.status(200).json({
      success: true,
      message: 'Booking offer accepted and atomically assigned',
      bookingId: result.booking?.id || result.offer.bookingId,
      offerId: result.offer.id,
      technicianId,
      data: result.assignment,
      booking: result.booking,
    });
  } catch (error) {
    const code = error.statusCode || 500;
    return res.status(code).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * POST /api/v1/dispatch/offers/:offerId/reject
 * (Also handles legacy /api/v1/dispatch/proposals/:id/decline)
 */
const rejectDispatchOffer = async (req, res) => {
  try {
    const offerOrBookingId = req.params.offerId || req.params.id;
    const technicianId = req.user?.id || req.body?.technicianId;
    const reason = req.body?.reason || 'REJECTED_BY_TECHNICIAN';

    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: Authenticated technician identity required' });
    }

    const offer = await automaticDispatchEngine.rejectOffer(offerOrBookingId, technicianId, reason);
    return res.status(200).json({
      success: true,
      message: 'Offer rejected; cascading to next eligible technician',
      offerId: offer.id,
      bookingId: offer.bookingId,
      status: offer.status,
    });
  } catch (error) {
    const code = error.statusCode || 500;
    return res.status(code).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * POST /api/v1/dispatch/:bookingId/retry
 */
const retryDispatch = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = bookingsStore.getBookingById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, error: 'Booking not found' });
    }

    if (req.user) {
      const role = String(req.user.role || '').toUpperCase();
      if (role === 'CUSTOMER' && booking.customerId && String(booking.customerId) !== String(req.user.id)) {
        return res.status(403).json({ success: false, error: 'Forbidden: Cannot retry dispatch for another customer booking' });
      }
      if (role === 'TECHNICIAN') {
        return res.status(403).json({ success: false, error: 'Forbidden: Technicians cannot retry booking dispatch' });
      }
    }

    const session = await automaticDispatchEngine.startDispatchForBooking(booking, {
      bookingMode: req.body?.bookingMode || booking.bookingMode || 'INSTANT',
      offerTimeoutSeconds: req.body?.offerTimeoutSeconds,
      radiiKm: req.body?.radiiKm,
      actorId: req.user?.id || 'CUSTOMER',
      actorRole: req.user?.role || 'CUSTOMER',
      forceRestart: true,
      forceAuto: true,
    });

    return res.json({
      success: true,
      message: 'Dispatch search restarted from initial radius',
      data: session,
      session,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/dispatch/:bookingId/manual-assign
 * Admin-only manual assignment / reassignment with full audit logging.
 */
const manualAssignDispatch = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { technicianId, reason } = req.body;

    if (!technicianId) {
      return res.status(400).json({ success: false, error: 'technicianId is required for manual assignment' });
    }

    const result = await automaticDispatchEngine.manualAssignBooking(bookingId, technicianId, {
      id: req.user?.id || 'admin',
      role: req.user?.role || 'ADMIN',
      reason: reason || 'ADMIN_MANUAL_ASSIGNMENT',
    });

    return res.json({
      success: true,
      message: result.isReassignment
        ? 'Booking manually reassigned to technician and audited'
        : 'Booking manually assigned to technician and audited',
      data: result,
    });
  } catch (error) {
    const code = error.statusCode || 500;
    return res.status(code).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/admin/dispatch/live
 */
const getAdminLiveDispatch = async (req, res) => {
  try {
    const overview = automaticDispatchEngine.getLiveAdminDispatchOverview();
    return res.json({
      success: true,
      data: overview,
      ...overview,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/admin/dispatch/:bookingId/history
 */
const getAdminDispatchHistory = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const history = automaticDispatchEngine.getBookingDispatchHistory(bookingId);
    return res.json({
      success: true,
      data: history,
      ...history,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * PUT /api/v1/admin/dispatch/config
 */
const updateAdminDispatchConfig = async (req, res) => {
  try {
    const updated = automaticDispatchEngine.updateDispatchConfig(
      req.body || {},
      req.user?.id || 'admin',
      req.user?.role || 'ADMIN'
    );
    return res.json({
      success: true,
      message: 'Dispatch engine configuration updated',
      config: updated,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/technicians/slots & GET /api/v1/bookings/available-slots
 * Phase 2: Backend-authoritative real-time slot availability engine
 */
const getAvailableSlots = async (req, res) => {
  try {
    const {
      serviceId,
      serviceName,
      category,
      latitude,
      longitude,
      date,
      scheduleDate,
      durationMinutes = 60,
      radiusKm = 15,
    } = req.query;

    const result = await automaticDispatchEngine.getAvailableTimeSlots({
      serviceId,
      serviceName,
      category,
      latitude: latitude != null ? parseFloat(latitude) : 22.5726,
      longitude: longitude != null ? parseFloat(longitude) : 88.3639,
      date: date || scheduleDate || new Date().toISOString().split('T')[0],
      durationMinutes: parseInt(durationMinutes, 10) || 60,
      radiusKm: parseFloat(radiusKm) || 15,
    });

    return res.json({
      success: true,
      data: result.slots,
      ...result,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  getTechniciansAvailability,
  updateTechnicianAvailability,
  getAvailableSlots,
  getDispatchStatus,
  getTechnicianOffers,
  getPendingDispatchRequests: getTechnicianOffers,
  getDispatchRequestById,
  startDispatch,
  acceptDispatchOffer,
  acceptDispatchRequest: acceptDispatchOffer,
  rejectDispatchOffer,
  declineDispatchRequest: rejectDispatchOffer,
  retryDispatch,
  manualAssignDispatch,
  getAdminLiveDispatch,
  getAdminDispatchHistory,
  updateAdminDispatchConfig,
};
