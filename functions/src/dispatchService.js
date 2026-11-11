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

module.exports = {
  acceptBookingOffer,
};

