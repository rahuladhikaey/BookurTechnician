// ============================================================================
// BOOKURTECHNICIAN CENTRALIZED DISPATCH ENGINE & DISPATCH REQUEST CONTROLLER
// Atomic Concurrency, 30s-35s Server Expiry, Cascading Re-dispatch, and Sync
// ============================================================================

const postgres = require('../config/postgres');
const bookingsStore = require('../config/bookingsStore');
const firebase = require('../config/firebase');
const kafka = require('../config/kafka');
const { calculateHaversineDistanceKm } = require('../services/postgresSpatialScanner');

// In-Memory active dispatch proposals store (fast cache + fallback)
const activeDispatchStore = new Map();

/**
 * Creates and registers a new unique dispatch request
 */
async function registerDispatchRequest({
  bookingId,
  technicianId,
  serviceId,
  serviceName,
  customerName,
  customerAddress,
  distanceKm,
  estimatedPayout,
  totalAmount,
  timeoutSeconds = 35,
  candidatesQueue = [],
}) {
  const dispatchRequestId = `disp_req_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + timeoutSeconds * 1000);

  const proposal = {
    id: dispatchRequestId,
    dispatchRequestId,
    proposalId: dispatchRequestId,
    bookingId,
    technicianId,
    serviceId: serviceId || 'srv_general',
    serviceName: serviceName || 'General Service',
    serviceType: serviceName || 'General Service',
    customerName: customerName || 'Customer',
    customerAddress: customerAddress || 'Customer Location',
    distanceKm: parseFloat(distanceKm || 1.8).toFixed(1),
    estimatedPayout: parseFloat(estimatedPayout || 350).toFixed(0),
    payout: parseFloat(estimatedPayout || 350).toFixed(0),
    totalAmount: parseFloat(totalAmount || 499).toFixed(0),
    status: 'PENDING',
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    timeoutSeconds,
    candidatesQueue,
  };

  // 1. Save to in-memory store
  activeDispatchStore.set(dispatchRequestId, proposal);

  // 2. Persist to PostgreSQL if available
  if (postgres.isPgHealthy()) {
    try {
      await postgres.query(
        `INSERT INTO dispatch_requests (
          id, booking_id, technician_id, service_id, service_name, customer_name, 
          customer_address, distance_km, estimated_payout, total_amount, status, 
          created_at, expires_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        ON CONFLICT (id) DO UPDATE SET status = $11, expires_at = $13`,
        [
          dispatchRequestId,
          bookingId,
          technicianId,
          proposal.serviceId,
          proposal.serviceName,
          proposal.customerName,
          proposal.customerAddress,
          proposal.distanceKm,
          proposal.estimatedPayout,
          proposal.totalAmount,
          'PENDING',
          now,
          expiresAt,
        ]
      );
    } catch (e) {
      console.warn('⚠️ [DispatchStore] PostgreSQL insert error (using in-memory):', e.message);
    }
  }

  // 3. Schedule automatic server-side expiry & cascading
  setTimeout(async () => {
    await handleServerSideExpiry(dispatchRequestId);
  }, timeoutSeconds * 1000);

  console.log(`[DISPATCH] REQUEST_CREATED id=${dispatchRequestId} booking=${bookingId} tech=${technicianId} distance=${distanceKm}km status=PENDING`);

  return proposal;
}

/**
 * Handles server-side timeout when technician does not respond within the time limit
 */
async function handleServerSideExpiry(dispatchRequestId) {
  const proposal = activeDispatchStore.get(dispatchRequestId);
  if (!proposal) return;

  if (proposal.status === 'PENDING') {
    proposal.status = 'EXPIRED';
    proposal.respondedAt = new Date().toISOString();
    activeDispatchStore.set(dispatchRequestId, proposal);

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(
          `UPDATE dispatch_requests SET status = 'EXPIRED', responded_at = NOW() WHERE id = $1 AND status = 'PENDING'`,
          [dispatchRequestId]
        );
      } catch (_) {}
    }

    console.log(`[DISPATCH] REQUEST_EXPIRED id=${dispatchRequestId} booking=${proposal.bookingId} tech=${proposal.technicianId}`);

    // Notify technician that proposal expired
    if (global.io) {
      global.io.to(`tech_${proposal.technicianId}`).emit('booking:expired', {
        dispatchRequestId,
        bookingId: proposal.bookingId,
        message: 'Job request timed out and was forwarded to another partner.',
      });
      global.io.to(`tech_${proposal.technicianId}`).emit('dispatch:expired', {
        dispatchRequestId,
        bookingId: proposal.bookingId,
      });
    }

    // Cascade dispatch to the next candidate in the queue
    if (Array.isArray(proposal.candidatesQueue) && proposal.candidatesQueue.length > 0) {
      const nextCandidate = proposal.candidatesQueue.shift();
      console.log(`[DISPATCH] CASCADING to next candidate tech=${nextCandidate.technicianId} for booking=${proposal.bookingId}`);
      
      const newProposal = await registerDispatchRequest({
        bookingId: proposal.bookingId,
        technicianId: nextCandidate.technicianId,
        serviceId: proposal.serviceId,
        serviceName: proposal.serviceName,
        customerName: proposal.customerName,
        customerAddress: proposal.customerAddress,
        distanceKm: nextCandidate.distanceKm || '2.5',
        estimatedPayout: proposal.estimatedPayout,
        totalAmount: proposal.totalAmount,
        timeoutSeconds: 30,
        candidatesQueue: proposal.candidatesQueue,
      });

      // Emit to new technician
      if (global.io) {
        const ringingPayload = {
          event: 'TECHNICIAN_BOOKING_REQUEST',
          type: 'NEW_JOB_ALERT',
          dispatchRequestId: newProposal.id,
          proposalId: newProposal.id,
          bookingId: newProposal.bookingId,
          serviceId: newProposal.serviceId,
          serviceName: newProposal.serviceName,
          serviceType: newProposal.serviceName,
          customerName: newProposal.customerName,
          customerAddress: newProposal.customerAddress,
          distanceKm: String(newProposal.distanceKm),
          estimatedEarning: parseFloat(newProposal.estimatedPayout),
          payout: String(newProposal.estimatedPayout),
          totalAmount: parseFloat(newProposal.totalAmount),
          timeoutSeconds: 30,
          createdAt: newProposal.createdAt,
          expiresAt: newProposal.expiresAt,
          playRingtone: true,
          vibrate: true,
        };

        global.io.to(`tech_${nextCandidate.technicianId}`).emit('booking:dispatch_ringing', ringingPayload);
        global.io.to(`tech_${nextCandidate.technicianId}`).emit('TECHNICIAN_BOOKING_REQUEST', ringingPayload);
        if (nextCandidate.phone) {
          global.io.to(`tech_${nextCandidate.phone}`).emit('booking:dispatch_ringing', ringingPayload);
          global.io.to(`tech_${nextCandidate.phone}`).emit('TECHNICIAN_BOOKING_REQUEST', ringingPayload);
        }
      }
    }
  }
}

/**
 * GET /api/v1/technicians/dispatch/pending
 * GET /api/v1/dispatch/proposals/pending
 * GET /api/v1/dispatch/pending
 * Returns active pending proposal for the authenticated technician
 */
const getPendingDispatchRequests = async (req, res) => {
  try {
    const technicianId = req.user?.id || req.user?.sub || req.headers['x-technician-id'] || req.query.technicianId;
    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Technician identity required' });
    }

    const now = new Date();

    // 1. Check in-memory store
    for (const [id, proposal] of activeDispatchStore.entries()) {
      if (
        (proposal.technicianId === technicianId || proposal.phone === technicianId) &&
        proposal.status === 'PENDING' &&
        new Date(proposal.expiresAt) > now
      ) {
        const remainingSeconds = Math.max(0, Math.round((new Date(proposal.expiresAt).getTime() - now.getTime()) / 1000));
        return res.json({
          success: true,
          hasPending: true,
          proposal: {
            ...proposal,
            remainingSeconds,
          },
          data: {
            ...proposal,
            remainingSeconds,
          },
        });
      }
    }

    // 2. Check PostgreSQL
    if (postgres.isPgHealthy()) {
      const pgRes = await postgres.query(
        `SELECT * FROM dispatch_requests 
         WHERE (technician_id = $1) 
           AND status = 'PENDING' 
           AND expires_at > NOW() 
         ORDER BY created_at DESC LIMIT 1`,
        [technicianId]
      );

      if (pgRes.rows.length > 0) {
        const row = pgRes.rows[0];
        const remainingSeconds = Math.max(0, Math.round((new Date(row.expires_at).getTime() - now.getTime()) / 1000));
        const formatted = {
          id: row.id,
          dispatchRequestId: row.id,
          proposalId: row.id,
          bookingId: row.booking_id,
          technicianId: row.technician_id,
          serviceId: row.service_id,
          serviceName: row.service_name,
          serviceType: row.service_name,
          customerName: row.customer_name,
          customerAddress: row.customer_address,
          distanceKm: String(row.distance_km || 1.8),
          estimatedPayout: String(row.estimated_payout || 350),
          payout: String(row.estimated_payout || 350),
          totalAmount: String(row.total_amount || 499),
          status: row.status,
          createdAt: row.created_at,
          expiresAt: row.expires_at,
          timeoutSeconds: 30,
          remainingSeconds,
        };

        return res.json({
          success: true,
          hasPending: true,
          proposal: formatted,
          data: formatted,
        });
      }
    }

    return res.json({
      success: true,
      hasPending: false,
      proposal: null,
      data: null,
      message: 'No pending dispatch proposals found.',
    });
  } catch (error) {
    console.error('❌ Error fetching pending dispatch:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/technicians/dispatch/:id
 * GET /api/v1/dispatch/proposals/:id
 */
const getDispatchRequestById = async (req, res) => {
  try {
    const { id } = req.params;
    let proposal = activeDispatchStore.get(id);

    if (!proposal && postgres.isPgHealthy()) {
      const pgRes = await postgres.query('SELECT * FROM dispatch_requests WHERE id = $1 OR booking_id = $1', [id]);
      if (pgRes.rows.length > 0) {
        const row = pgRes.rows[0];
        proposal = {
          id: row.id,
          dispatchRequestId: row.id,
          proposalId: row.id,
          bookingId: row.booking_id,
          technicianId: row.technician_id,
          serviceName: row.service_name,
          customerName: row.customer_name,
          customerAddress: row.customer_address,
          distanceKm: String(row.distance_km),
          payout: String(row.estimated_payout),
          status: row.status,
          expiresAt: row.expires_at,
        };
      }
    }

    if (!proposal) {
      return res.status(404).json({ success: false, error: 'Dispatch request not found' });
    }

    return res.json({ success: true, data: proposal, proposal });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/dispatch/:id/accept
 * POST /api/v1/dispatch/proposals/:id/accept
 * Atomic Acceptance of Dispatch Request
 */
const acceptDispatchRequest = async (req, res) => {
  try {
    const targetId = req.params.id;
    const technicianId = req.user?.id || req.user?.sub || req.headers['x-technician-id'] || req.body.technicianId;

    if (!technicianId) {
      return res.status(401).json({ success: false, error: 'Unauthorized: valid technician identifier required' });
    }

    console.log(`[DISPATCH] REQUEST_ACCEPTED_ATTEMPT id=${targetId} tech=${technicianId}`);

    // Retrieve proposal if exists
    let proposal = activeDispatchStore.get(targetId);
    let bookingId = proposal?.bookingId || targetId;

    // 1. Fetch technician profile
    let techName = 'Verified Partner';
    let techPhone = '';
    let techRating = 4.85;
    let techAvatar = '';
    let techLat = 22.5726;
    let techLng = 88.3639;

    if (postgres.isPgHealthy()) {
      const tpRes = await postgres.query(
        `SELECT * FROM technician_profiles WHERE technician_id = $1 OR phone = $1`,
        [technicianId]
      );
      if (tpRes.rows.length > 0) {
        const row = tpRes.rows[0];
        techName = row.full_name || techName;
        techPhone = row.phone || techPhone;
        techRating = parseFloat(row.rating) || techRating;
        if (row.current_latitude && row.current_longitude) {
          techLat = parseFloat(row.current_latitude);
          techLng = parseFloat(row.current_longitude);
        }
      }
    }

    // 2. ATOMIC ACCEPTANCE TRANSACTION IN POSTGRESQL
    let bookingAssigned = null;

    if (postgres.isPgHealthy()) {
      // Find matching booking
      const bookRes = await postgres.query(
        `UPDATE bookings 
         SET technician_id = $1, status = 'ACCEPTED', updated_at = NOW() 
         WHERE (id = $2 OR booking_code = $2) 
           AND (technician_id IS NULL OR technician_id = $1)
           AND status IN ('CONFIRMED', 'PENDING', 'TECHNICIAN_REQUESTED')
         RETURNING *`,
        [technicianId, bookingId]
      );

      if (bookRes.rows.length === 0) {
        // Check if already assigned
        const checkRes = await postgres.query(
          `SELECT * FROM bookings WHERE id = $1 OR booking_code = $1`,
          [bookingId]
        );
        if (checkRes.rows.length > 0 && checkRes.rows[0].technician_id !== technicianId) {
          console.log(`[DISPATCH] CONFLICT id=${targetId} booking=${bookingId} already assigned to ${checkRes.rows[0].technician_id}`);
          return res.status(409).json({
            success: false,
            error: 'This booking has already been assigned to another partner.',
            code: 'BOOKING_ALREADY_ASSIGNED',
          });
        }
      } else {
        bookingAssigned = bookRes.rows[0];
      }

      // Mark technician as BUSY
      await postgres.query(
        `UPDATE technician_profiles SET availability_status = 'BUSY', updated_at = NOW() WHERE technician_id = $1 OR phone = $1`,
        [technicianId]
      );

      // Update dispatch_requests table
      await postgres.query(
        `UPDATE dispatch_requests SET status = 'ACCEPTED', responded_at = NOW() WHERE (id = $1 OR booking_id = $2) AND technician_id = $3`,
        [targetId, bookingId, technicianId]
      ).catch(() => {});

      // Cancel all other pending requests for this booking
      await postgres.query(
        `UPDATE dispatch_requests SET status = 'CANCELLED', responded_at = NOW() WHERE booking_id = $1 AND id != $2 AND status = 'PENDING'`,
        [bookingId, targetId]
      ).catch(() => {});
    }

    // In-Memory store update
    if (proposal) {
      proposal.status = 'ACCEPTED';
      proposal.respondedAt = new Date().toISOString();
      activeDispatchStore.set(targetId, proposal);
    }

    let memoryBooking = bookingsStore.getBookingById(bookingId);
    if (memoryBooking) {
      if (memoryBooking.technicianId && memoryBooking.technicianId !== technicianId && memoryBooking.status === 'ACCEPTED') {
        return res.status(409).json({
          success: false,
          error: 'This booking has already been assigned to another partner.',
          code: 'BOOKING_ALREADY_ASSIGNED',
        });
      }
      memoryBooking.technicianId = technicianId;
      memoryBooking.technicianName = techName;
      memoryBooking.technician = techName;
      memoryBooking.technicianPhone = techPhone;
      memoryBooking.status = 'ACCEPTED';
      memoryBooking.updatedAt = new Date().toISOString();
      bookingsStore.assignTechnician(bookingId, technicianId, techName, techPhone, memoryBooking.category, techRating, techAvatar);
    }

    const startOtp = memoryBooking?.startOtp || bookingAssigned?.start_otp || '4829';
    const custLat = parseFloat(memoryBooking?.latitude || bookingAssigned?.latitude || 22.5726);
    const custLng = parseFloat(memoryBooking?.longitude || bookingAssigned?.longitude || 88.3639);
    const distanceKm = calculateHaversineDistanceKm(custLat, custLng, techLat, techLng);

    const technicianDetailsPayload = {
      bookingId,
      bookingCode: memoryBooking?.bookingCode || bookingAssigned?.booking_code || bookingId,
      status: 'ACCEPTED',
      technicianId,
      technicianName: techName,
      technicianPhone: techPhone,
      technicianRating: techRating,
      technicianAvatar: techAvatar,
      technicianLatitude: techLat,
      technicianLongitude: techLng,
      distanceKm: distanceKm.toFixed(1),
      etaMinutes: Math.max(2, Math.round((distanceKm / 25) * 60)),
      startOtp,
    };

    console.log(`[DISPATCH] TECHNICIAN_ASSIGNED booking=${bookingId} tech=${technicianId} (${techName})`);

    // 3. BROADCAST REAL-TIME NOTIFICATIONS
    if (global.io) {
      const custId = memoryBooking?.customerId || bookingAssigned?.customer_id;
      if (custId) {
        global.io.to(`cust_${custId}`).emit('booking:technician_assigned', technicianDetailsPayload);
        global.io.to(`cust_${custId}`).emit('booking:confirmed', technicianDetailsPayload);
        global.io.to(`cust_${custId}`).emit('job:partner_location', {
          technicianId,
          latitude: techLat,
          longitude: techLng,
          speed: 15,
          heading: 45,
          timestamp: Date.now(),
        });
      }

      // Claimed notification to other technicians (stops their audio & closes popups)
      global.io.emit('booking:claimed', {
        bookingId,
        claimedByTechnicianId: technicianId,
        message: 'This job has been claimed by another partner.',
      });

      global.io.emit('job:status_update', {
        bookingId,
        status: 'ASSIGNED',
        technician: technicianDetailsPayload,
      });
    }

    // 4. FCM to Customer
    const custId = memoryBooking?.customerId || bookingAssigned?.customer_id;
    if (custId) {
      await firebase.sendPushNotification(`cust_fcm_${custId}`, {
        title: '✅ Technician Assigned!',
        body: `${techName} (${distanceKm.toFixed(1)} km away) is on the way. Service Start OTP is ${startOtp}.`,
        data: {
          bookingId,
          technicianId,
          technicianName: techName,
          startOtp,
          status: 'ACCEPTED',
        },
      });
    }

    return res.json({
      success: true,
      message: 'Job accepted successfully! Navigate to customer address.',
      data: {
        bookingId,
        status: 'ACCEPTED',
        technicianId,
        startOtp,
        booking: memoryBooking || bookingAssigned,
      },
    });
  } catch (error) {
    console.error('❌ Accept Dispatch Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/technicians/dispatch/:id/decline
 * POST /api/v1/dispatch/proposals/:id/decline
 * Decline Proposal & Trigger Cascading Re-dispatch
 */
const declineDispatchRequest = async (req, res) => {
  try {
    const targetId = req.params.id;
    const technicianId = req.user?.id || req.user?.sub || req.headers['x-technician-id'] || req.body.technicianId;

    console.log(`[DISPATCH] REQUEST_DECLINED id=${targetId} tech=${technicianId}`);

    let proposal = activeDispatchStore.get(targetId);

    if (proposal) {
      proposal.status = 'DECLINED';
      proposal.respondedAt = new Date().toISOString();
      activeDispatchStore.set(targetId, proposal);
    }

    if (postgres.isPgHealthy()) {
      await postgres.query(
        `UPDATE dispatch_requests SET status = 'DECLINED', responded_at = NOW() WHERE id = $1 OR (booking_id = $1 AND technician_id = $2)`,
        [targetId, technicianId]
      ).catch(() => {});
    }

    // Cascade to next candidate if available
    if (proposal && Array.isArray(proposal.candidatesQueue) && proposal.candidatesQueue.length > 0) {
      const nextCandidate = proposal.candidatesQueue.shift();
      console.log(`[DISPATCH] CASCADING after decline to next candidate tech=${nextCandidate.technicianId} for booking=${proposal.bookingId}`);

      const newProposal = await registerDispatchRequest({
        bookingId: proposal.bookingId,
        technicianId: nextCandidate.technicianId,
        serviceId: proposal.serviceId,
        serviceName: proposal.serviceName,
        customerName: proposal.customerName,
        customerAddress: proposal.customerAddress,
        distanceKm: nextCandidate.distanceKm || '2.5',
        estimatedPayout: proposal.estimatedPayout,
        totalAmount: proposal.totalAmount,
        timeoutSeconds: 30,
        candidatesQueue: proposal.candidatesQueue,
      });

      if (global.io) {
        const ringingPayload = {
          event: 'TECHNICIAN_BOOKING_REQUEST',
          type: 'NEW_JOB_ALERT',
          dispatchRequestId: newProposal.id,
          proposalId: newProposal.id,
          bookingId: newProposal.bookingId,
          serviceId: newProposal.serviceId,
          serviceName: newProposal.serviceName,
          serviceType: newProposal.serviceName,
          customerName: newProposal.customerName,
          customerAddress: newProposal.customerAddress,
          distanceKm: String(newProposal.distanceKm),
          estimatedEarning: parseFloat(newProposal.estimatedPayout),
          payout: String(newProposal.estimatedPayout),
          totalAmount: parseFloat(newProposal.totalAmount),
          timeoutSeconds: 30,
          createdAt: newProposal.createdAt,
          expiresAt: newProposal.expiresAt,
          playRingtone: true,
          vibrate: true,
        };

        global.io.to(`tech_${nextCandidate.technicianId}`).emit('booking:dispatch_ringing', ringingPayload);
        global.io.to(`tech_${nextCandidate.technicianId}`).emit('TECHNICIAN_BOOKING_REQUEST', ringingPayload);
        if (nextCandidate.phone) {
          global.io.to(`tech_${nextCandidate.phone}`).emit('booking:dispatch_ringing', ringingPayload);
          global.io.to(`tech_${nextCandidate.phone}`).emit('TECHNICIAN_BOOKING_REQUEST', ringingPayload);
        }
      }
    }

    return res.json({
      success: true,
      message: 'Proposal declined. Forwarding request to next available partner.',
    });
  } catch (error) {
    console.error('❌ Decline Dispatch Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  registerDispatchRequest,
  getPendingDispatchRequests,
  getDispatchRequestById,
  acceptDispatchRequest,
  declineDispatchRequest,
};
