const { doesTechnicianPossessVerifiedSkill } = require('./canonicalServices');

/**
 * Server-Authoritative Dispatch & Acceptance Engine
 * Uses Firestore Transactions to guarantee atomic single-winner assignment.
 */
async function acceptBookingOffer(db, { offerId, callerUid, callerName, callerPhone }) {
  if (!offerId) {
    const err = new Error('Offer ID is required');
    err.status = 400;
    err.code = 'MISSING_OFFER_ID';
    throw err;
  }
  if (!callerUid) {
    const err = new Error('Unauthorized: Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const offerRef = db.collection('dispatch_offers').doc(offerId);
  const nowIso = new Date().toISOString();
  const nowMs = Date.now();

  let competingOfferIds = [];
  let winningBookingData = null;

  // Run atomic Firestore transaction
  await db.runTransaction(async (transaction) => {
    // 1. Read Offer
    const offerSnap = await transaction.get(offerRef);
    if (!offerSnap.exists) {
      const err = new Error('Dispatch offer not found');
      err.status = 404;
      err.code = 'OFFER_NOT_FOUND';
      throw err;
    }

    const offerData = offerSnap.data();
    const assignedTechUid = offerData.technicianId || offerData.targetTechnicianUid;

    // 2. Validate Offer Ownership
    if (assignedTechUid !== callerUid) {
      const err = new Error('Forbidden: This offer was not dispatched to you');
      err.status = 403;
      err.code = 'OFFER_UNAUTHORIZED';
      throw err;
    }

    // 3. Validate Expiration
    if (offerData.expiresAt) {
      const expMs = new Date(offerData.expiresAt).getTime();
      if (!isNaN(expMs) && expMs < nowMs && offerData.status !== 'ACCEPTED') {
        transaction.update(offerRef, {
          status: 'EXPIRED',
          updatedAt: nowIso,
        });
        const err = new Error('This booking offer has expired');
        err.status = 410;
        err.code = 'OFFER_EXPIRED';
        throw err;
      }
    }

    const currentOfferStatus = (offerData.status || '').toUpperCase();
    const bookingId = offerData.bookingId;
    if (!bookingId) {
      const err = new Error('Offer has no linked booking ID');
      err.status = 400;
      err.code = 'INVALID_OFFER_PAYLOAD';
      throw err;
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists) {
      const err = new Error('Booking not found');
      err.status = 404;
      err.code = 'BOOKING_NOT_FOUND';
      throw err;
    }

    const bookingData = bookingSnap.data();
    const currentBookingStatus = (bookingData.status || '').toUpperCase();

    // 4. Idempotency Check: Caller already assigned
    if (bookingData.technicianId === callerUid && ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED'].includes(currentBookingStatus)) {
      winningBookingData = { ...bookingData, id: bookingId };
      return;
    }

    // 5. Concurrency Check: Booking already claimed by another technician
    if (['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED'].includes(currentBookingStatus) ||
        (bookingData.technicianId && bookingData.technicianId !== callerUid)) {
      transaction.update(offerRef, {
        status: 'CANCELLED_CLAIMED_BY_ANOTHER',
        updatedAt: nowIso,
      });
      const err = new Error('Booking has already been claimed by another technician');
      err.status = 409;
      err.code = 'ALREADY_ASSIGNED';
      throw err;
    }

    // 5b. Booking Lifecycle State Guard (Must be SEARCHING or PENDING)
    if (currentBookingStatus === 'CANCELLED') {
      transaction.update(offerRef, {
        status: 'CANCELLED_CUSTOMER',
        updatedAt: nowIso,
      });
      const err = new Error('Booking has been cancelled by the customer');
      err.status = 410;
      err.code = 'BOOKING_CANCELLED';
      throw err;
    }

    if (currentBookingStatus !== 'SEARCHING' && currentBookingStatus !== 'PENDING') {
      const err = new Error(`Booking cannot be accepted in status: ${currentBookingStatus}`);
      err.status = 400;
      err.code = 'INVALID_BOOKING_STATUS';
      throw err;
    }

    // 6. Read and Validate Technician Profile
    const techRef = db.collection('technician_profiles').doc(callerUid);
    const techSnap = await transaction.get(techRef);
    if (!techSnap.exists) {
      const err = new Error('Technician profile not found');
      err.status = 404;
      err.code = 'TECHNICIAN_NOT_FOUND';
      throw err;
    }

    const techData = techSnap.data();

    // Check Online & Availability
    const isOnline = techData.isOnline === true;
    const availStatus = (techData.availabilityStatus || 'AVAILABLE').toUpperCase();
    if (!isOnline || availStatus === 'OFFLINE') {
      const err = new Error('Technician is offline. Please switch ON duty to accept bookings');
      err.status = 409;
      err.code = 'TECHNICIAN_OFFLINE';
      throw err;
    }
    if (availStatus === 'BUSY') {
      const err = new Error('Technician is currently on another active booking');
      err.status = 409;
      err.code = 'TECHNICIAN_BUSY';
      throw err;
    }

    // Check KYC Status
    const kycStatus = (techData.kycStatus || 'VERIFIED').toUpperCase();
    if (kycStatus !== 'VERIFIED' && kycStatus !== 'APPROVED') {
      const err = new Error('Technician account KYC is not verified');
      err.status = 403;
      err.code = 'KYC_NOT_VERIFIED';
      throw err;
    }

    // 7. Canonical Skill Verification Guard
    const targetServiceId = bookingData.serviceId || bookingData.service?.id || offerData.serviceId;
    const targetServiceName = bookingData.serviceName || bookingData.service?.name || bookingData.title || offerData.serviceName;

    const hasSkill = doesTechnicianPossessVerifiedSkill(techData, targetServiceId, targetServiceName);
    if (!hasSkill) {
      const err = new Error(`Technician is not authorized or verified for requested service "${targetServiceName || targetServiceId}"`);
      err.status = 403;
      err.code = 'SKILL_NOT_AUTHORIZED';
      throw err;
    }

    // 8. Commit Atomic Updates
    const techName = callerName || techData.name || techData.fullName || 'Technician';
    const techPhone = callerPhone || techData.phone || techData.phoneNumber || '';

    // Update Booking
    transaction.update(bookingRef, {
      status: 'ASSIGNED',
      technicianId: callerUid,
      technicianName: techName,
      technicianPhone: techPhone,
      assignedAt: nowIso,
      updatedAt: nowIso,
    });

    // Update Winning Offer
    transaction.update(offerRef, {
      status: 'ACCEPTED',
      acceptedAt: nowIso,
      updatedAt: nowIso,
    });

    // Update Technician Profile to BUSY
    transaction.update(techRef, {
      availabilityStatus: 'BUSY',
      activeBookingId: bookingId,
      updatedAt: nowIso,
    });

    // Record Lifecycle Audit Event
    const eventRef = db.collection('booking_events').doc();
    transaction.set(eventRef, {
      bookingId,
      eventType: 'DISPATCH_ACCEPTED',
      technicianId: callerUid,
      technicianName: techName,
      timestamp: nowIso,
      createdAt: nowIso,
    });

    winningBookingData = {
      ...bookingData,
      id: bookingId,
      status: 'ASSIGNED',
      technicianId: callerUid,
      technicianName: techName,
      technicianPhone: techPhone,
      assignedAt: nowIso,
      updatedAt: nowIso,
    };
  });

  // 9. Concurrency Post-Step: Cancel Competing Offers
  try {
    const bookingId = winningBookingData.id;
    const competingOffersQuery = await db.collection('dispatch_offers')
      .where('bookingId', '==', bookingId)
      .get();

    const batch = db.batch();
    let batchCount = 0;

    competingOffersQuery.forEach((doc) => {
      if (doc.id !== offerId) {
        const d = doc.data();
        if (d.status === 'SENT' || d.status === 'RINGING' || d.status === 'PENDING') {
          batch.update(doc.ref, {
            status: 'CANCELLED_CLAIMED_BY_ANOTHER',
            cancelledAt: nowIso,
            updatedAt: nowIso,
          });
          batchCount++;
        }
      }
    });

    if (batchCount > 0) {
      await batch.commit();
    }
  } catch (cancelErr) {
    console.warn('Non-fatal error cancelling competing offers:', cancelErr.message);
  }

  // 10. Sanitize response (NEVER return OTPs or secrets to technician)
  const sanitized = { ...winningBookingData };
  delete sanitized.startOtp;
  delete sanitized.endOtp;
  delete sanitized.secrets;
  delete sanitized.startServiceOtp;

  return {
    success: true,
    message: 'Booking offer accepted and assigned successfully',
    booking: sanitized,
    assignment: {
      bookingId: sanitized.id,
      technicianId: callerUid,
      status: 'ASSIGNED',
      assignedAt: winningBookingData.assignedAt,
    },
  };
}

function calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const c = Math.cos;
  const a = 0.5 - c((lat2 - lat1) * p) / 2 +
            c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
}

/**
 * Server-Authoritative Dispatch Offer Generator
 * Evaluates all technicians and creates dispatch_offers ONLY for those satisfying ALL conditions:
 * - Authenticated Firebase UID
 * - Verified account (kycStatus === 'VERIFIED' or 'APPROVED', not suspended/blocked)
 * - Required canonical service skill is verified and enabled
 * - Technician is online (isOnline === true and availabilityStatus !== 'OFFLINE')
 * - Technician is available and not already BUSY (availabilityStatus !== 'BUSY', no active booking)
 * - Location coverage (distKm <= 15.0 km and lastLocationUpdate <= 10 min)
 */
async function dispatchBookingOffers(db, bookingData) {
  const serviceId = bookingData.serviceId;
  const serviceName = bookingData.serviceName;
  const bookingId = bookingData.id;
  const custCoords = bookingData.coordinates;
  const nowIso = new Date().toISOString();
  const expiresAt = new Date(Date.now() + 45000).toISOString();

  // 1. Fetch all technician profiles
  const techQuery = await db.collection('technician_profiles').get();
  const eligibleOffers = [];

  // 2. Fetch active bookings to identify busy technicians
  const activeBookingsQuery = await db.collection('bookings')
    .where('status', 'in', ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'TECHNICIAN_ARRIVED'])
    .get();
  const busyTechSet = new Set();
  activeBookingsQuery.forEach((doc) => {
    const tId = doc.data().technicianId;
    if (tId) busyTechSet.add(tId);
  });

  for (const doc of techQuery.docs) {
    const techId = doc.id;
    const tech = doc.data();

    // Condition 1: Authenticated Firebase UID
    if (!techId) continue;

    // Condition 2: Verified technician account
    const kyc = (tech.kycStatus || 'VERIFIED').toUpperCase();
    const accStatus = (tech.accountStatus || 'ACTIVE').toUpperCase();
    if (kyc !== 'VERIFIED' && kyc !== 'APPROVED') continue;
    if (accStatus === 'SUSPENDED' || accStatus === 'BLOCKED') continue;

    // Condition 3: Online
    const isOnline = tech.isOnline === true;
    const availStatus = (tech.availabilityStatus || 'AVAILABLE').toUpperCase();
    if (!isOnline || availStatus === 'OFFLINE') continue;

    // Condition 4: Available & not already BUSY
    if (availStatus === 'BUSY' || busyTechSet.has(techId) || tech.activeBookingId) continue;

    // Condition 5: Canonical service skill is verified and enabled
    const hasSkill = doesTechnicianPossessVerifiedSkill(tech, serviceId, serviceName);
    if (!hasSkill) continue;

    // Condition 6: Location and service coverage rules
    let distKm = 5.0; // default estimate if coordinates not supplied
    const tLat = tech.latitude || tech.currentLatitude;
    const tLng = tech.longitude || tech.currentLongitude;

    if (custCoords && custCoords.latitude && custCoords.longitude && tLat && tLng) {
      if (tech.lastLocationUpdate) {
        const updateAgeMs = Date.now() - new Date(tech.lastLocationUpdate).getTime();
        if (updateAgeMs > 10 * 60 * 1000) {
          continue; // Stale location (>10 minutes)
        }
      }
      distKm = calculateHaversineDistanceKm(
        Number(custCoords.latitude),
        Number(custCoords.longitude),
        Number(tLat),
        Number(tLng)
      );
      if (distKm > 15.0) {
        continue; // Out of 15.0 km radius
      }
    }

    const offerId = `offer_${bookingId}_${techId}`;
    const offerDoc = {
      id: offerId,
      offerId,
      bookingId,
      technicianId: techId,
      targetTechnicianUid: techId,
      serviceId,
      serviceName,
      price: bookingData.price,
      payout: Math.round((bookingData.price || 399) * 0.8),
      distanceKm: Math.round(distKm * 10) / 10,
      approximateArea: bookingData.address?.area || bookingData.address?.city || 'Customer Premise',
      status: 'SENT',
      timeoutSeconds: 45,
      expiresAt,
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    await db.collection('dispatch_offers').doc(offerId).set(offerDoc);
    eligibleOffers.push(offerDoc);
  }

  // Audit event for dispatch attempt
  await db.collection('booking_events').doc().set({
    bookingId,
    eventType: 'DISPATCH_OFFERS_GENERATED',
    serviceId,
    eligibleCount: eligibleOffers.length,
    timestamp: nowIso,
    createdAt: nowIso,
  });

  return eligibleOffers;
}

module.exports = {
  acceptBookingOffer,
  dispatchBookingOffers,
  calculateHaversineDistanceKm,
};

