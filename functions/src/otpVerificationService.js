const { hashOtp } = require('./otpService');

/**
 * Authoritative OTP Verification Service
 * Guarantees zero plaintext exposure, atomic verification, and lockout protection.
 * Note: In Firestore transactions, all reads MUST precede all writes.
 */

async function verifyStartOtp(db, { bookingId, callerUid, enteredOtp }) {
  if (!bookingId) {
    const err = new Error('Booking ID is required');
    err.status = 400;
    err.code = 'MISSING_BOOKING_ID';
    throw err;
  }
  if (!enteredOtp || String(enteredOtp).trim().length !== 4) {
    const err = new Error('A 4-digit numeric Start OTP is required');
    err.status = 400;
    err.code = 'INVALID_OTP_FORMAT';
    throw err;
  }

  const bookingRef = db.collection('bookings').doc(bookingId);
  const secretsRef = db.collection('booking_secrets').doc(bookingId);
  const nowIso = new Date().toISOString();

  let verificationOutcome = null;

  await db.runTransaction(async (transaction) => {
    // ─── 1. ALL READS FIRST ───
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists) {
      const err = new Error('Booking not found');
      err.status = 404;
      err.code = 'BOOKING_NOT_FOUND';
      throw err;
    }
    const bookingData = bookingSnap.data();

    // Verify Technician Authorization
    if (bookingData.technicianId !== callerUid) {
      const err = new Error('Unauthorized: You are not the assigned technician for this booking');
      err.status = 403;
      err.code = 'TECHNICIAN_NOT_ASSIGNED';
      throw err;
    }

    // Verify State
    const currentStatus = (bookingData.status || '').toUpperCase();
    if (currentStatus === 'IN_PROGRESS') {
      verificationOutcome = { success: true, status: 'IN_PROGRESS', isIdempotent: true };
      return;
    }
    if (!['ASSIGNED', 'ACCEPTED', 'CONFIRMED', 'PENDING'].includes(currentStatus)) {
      const err = new Error(`Cannot start service: Booking is in invalid state "${currentStatus}"`);
      err.status = 400;
      err.code = 'INVALID_BOOKING_STATUS';
      throw err;
    }

    const secretsSnap = await transaction.get(secretsRef);
    if (!secretsSnap.exists) {
      const err = new Error('Security challenge record not found for this booking');
      err.status = 404;
      err.code = 'SECRETS_NOT_FOUND';
      throw err;
    }
    const secretsData = secretsSnap.data();

    // Check Lockout
    if (secretsData.startLockedOut === true || (secretsData.failedStartAttempts || 0) >= 3) {
      const err = new Error('Maximum Start OTP attempts exceeded (3 failed attempts). Verification is locked.');
      err.status = 403;
      err.code = 'OTP_LOCKED_OUT';
      throw err;
    }

    // ─── 2. HASH COMPARISON ───
    const computedHash = hashOtp(enteredOtp, secretsData.salt);
    const expectedHash = secretsData.startOtpHash;

    if (computedHash !== expectedHash) {
      const nextFailed = (secretsData.failedStartAttempts || 0) + 1;
      const isLocked = nextFailed >= 3;
      const remainingAttempts = Math.max(0, 3 - nextFailed);

      // Record failed attempt in Firestore transaction
      transaction.update(secretsRef, {
        failedStartAttempts: nextFailed,
        startLockedOut: isLocked,
        updatedAt: nowIso,
      });

      verificationOutcome = {
        success: false,
        isLocked,
        remainingAttempts,
      };
      return;
    }

    // ─── 3. SUCCESS WRITES ───
    transaction.update(bookingRef, {
      status: 'IN_PROGRESS',
      serviceStartedAt: nowIso,
      updatedAt: nowIso,
    });

    transaction.update(secretsRef, {
      failedStartAttempts: 0,
      startVerifiedAt: nowIso,
      updatedAt: nowIso,
    });

    const eventRef = db.collection('booking_events').doc();
    transaction.set(eventRef, {
      bookingId,
      eventType: 'SERVICE_STARTED',
      technicianId: callerUid,
      timestamp: nowIso,
      createdAt: nowIso,
    });

    verificationOutcome = {
      success: true,
      status: 'IN_PROGRESS',
    };
  });

  if (!verificationOutcome.success) {
    const err = new Error(
      verificationOutcome.isLocked
        ? 'Maximum Start OTP attempts reached (3 failed attempts). Verification locked.'
        : `Invalid Start OTP code. ${verificationOutcome.remainingAttempts} attempts remaining.`
    );
    err.status = verificationOutcome.isLocked ? 403 : 400;
    err.code = verificationOutcome.isLocked ? 'OTP_LOCKED_OUT' : 'INVALID_OTP';
    err.remainingAttempts = verificationOutcome.remainingAttempts;
    throw err;
  }

  return {
    success: true,
    status: 'IN_PROGRESS',
    message: 'Start OTP verified successfully. Job is now IN_PROGRESS.',
  };
}

async function verifyEndOtp(db, { bookingId, callerUid, enteredOtp }) {
  if (!bookingId) {
    const err = new Error('Booking ID is required');
    err.status = 400;
    err.code = 'MISSING_BOOKING_ID';
    throw err;
  }
  if (!enteredOtp || String(enteredOtp).trim().length !== 4) {
    const err = new Error('A 4-digit numeric Ending OTP is required');
    err.status = 400;
    err.code = 'INVALID_OTP_FORMAT';
    throw err;
  }

  const bookingRef = db.collection('bookings').doc(bookingId);
  const secretsRef = db.collection('booking_secrets').doc(bookingId);
  const techRef = db.collection('technician_profiles').doc(callerUid);
  const nowIso = new Date().toISOString();

  let verificationOutcome = null;

  await db.runTransaction(async (transaction) => {
    // ─── 1. ALL READS FIRST ───
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists) {
      const err = new Error('Booking not found');
      err.status = 404;
      err.code = 'BOOKING_NOT_FOUND';
      throw err;
    }
    const bookingData = bookingSnap.data();

    // Verify Technician Authorization
    if (bookingData.technicianId !== callerUid) {
      const err = new Error('Unauthorized: You are not the assigned technician for this booking');
      err.status = 403;
      err.code = 'TECHNICIAN_NOT_ASSIGNED';
      throw err;
    }

    // Verify State
    const currentStatus = (bookingData.status || '').toUpperCase();
    if (currentStatus === 'COMPLETED') {
      verificationOutcome = {
        success: true,
        status: 'COMPLETED',
        payoutAmount: bookingData.technicianPayoutAmount || 0,
        isIdempotent: true,
      };
      return;
    }
    if (currentStatus !== 'IN_PROGRESS') {
      const err = new Error(`Cannot complete service: Booking is in "${currentStatus}" (Must be IN_PROGRESS)`);
      err.status = 400;
      err.code = 'INVALID_BOOKING_STATUS';
      throw err;
    }

    const secretsSnap = await transaction.get(secretsRef);
    if (!secretsSnap.exists) {
      const err = new Error('Security challenge record not found for this booking');
      err.status = 404;
      err.code = 'SECRETS_NOT_FOUND';
      throw err;
    }
    const secretsData = secretsSnap.data();

    // Check Lockout
    if (secretsData.endLockedOut === true || (secretsData.failedEndAttempts || 0) >= 3) {
      const err = new Error('Maximum End OTP attempts exceeded (3 failed attempts). Verification is locked.');
      err.status = 403;
      err.code = 'OTP_LOCKED_OUT';
      throw err;
    }

    // Read tech profile (must be read before any writes!)
    const techSnap = await transaction.get(techRef);

    // ─── 2. HASH COMPARISON ───
    const computedHash = hashOtp(enteredOtp, secretsData.salt);
    const expectedHash = secretsData.endOtpHash;

    if (computedHash !== expectedHash) {
      const nextFailed = (secretsData.failedEndAttempts || 0) + 1;
      const isLocked = nextFailed >= 3;
      const remainingAttempts = Math.max(0, 3 - nextFailed);

      // Record failed attempt in Firestore transaction
      transaction.update(secretsRef, {
        failedEndAttempts: nextFailed,
        endLockedOut: isLocked,
        updatedAt: nowIso,
      });

      verificationOutcome = {
        success: false,
        isLocked,
        remainingAttempts,
      };
      return;
    }

    // ─── 3. SUCCESS WRITES ───
    const totalAmount = Number(bookingData.totalAmount || bookingData.price || bookingData.grandTotal || 0);
    // Standard technician share: 80% of service charge
    const finalPayout = Math.round(totalAmount > 0 ? totalAmount * 0.8 : 800);

    transaction.update(bookingRef, {
      status: 'COMPLETED',
      completedAt: nowIso,
      technicianPayoutAmount: finalPayout,
      updatedAt: nowIso,
    });

    transaction.update(secretsRef, {
      failedEndAttempts: 0,
      endVerifiedAt: nowIso,
      updatedAt: nowIso,
    });

    if (techSnap.exists) {
      const techData = techSnap.data();
      const currentWallet = Number(techData.walletBalance || 0);
      const totalJobs = Number(techData.totalJobsCompleted || 0);

      transaction.update(techRef, {
        availabilityStatus: 'AVAILABLE',
        activeBookingId: null,
        walletBalance: currentWallet + finalPayout,
        totalJobsCompleted: totalJobs + 1,
        updatedAt: nowIso,
      });
    }

    const eventRef = db.collection('booking_events').doc();
    transaction.set(eventRef, {
      bookingId,
      eventType: 'SERVICE_COMPLETED',
      technicianId: callerUid,
      payoutAmount: finalPayout,
      timestamp: nowIso,
      createdAt: nowIso,
    });

    verificationOutcome = {
      success: true,
      status: 'COMPLETED',
      payoutAmount: finalPayout,
    };
  });

  if (!verificationOutcome.success) {
    const err = new Error(
      verificationOutcome.isLocked
        ? 'Maximum End OTP attempts reached (3 failed attempts). Account locked.'
        : `Invalid End OTP code. ${verificationOutcome.remainingAttempts} attempts remaining.`
    );
    err.status = verificationOutcome.isLocked ? 403 : 400;
    err.code = verificationOutcome.isLocked ? 'OTP_LOCKED_OUT' : 'INVALID_OTP';
    err.remainingAttempts = verificationOutcome.remainingAttempts;
    throw err;
  }

  return {
    success: true,
    status: 'COMPLETED',
    payoutAmount: verificationOutcome.payoutAmount,
    message: 'Service completed successfully! Earnings credited to wallet.',
  };
}

module.exports = {
  verifyStartOtp,
  verifyEndOtp,
};
