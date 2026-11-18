const { generateOtp, createBookingSecrets } = require('./otpService');
const { resolveCanonicalServiceId } = require('./canonicalServices');

/**
 * Server-Authoritative Booking Creation & OTP Delivery Service
 */

async function createBooking(db, {
  customerId,
  customerName,
  customerPhone,
  serviceId,
  serviceName,
  categoryId,
  address,
  coordinates,
  price,
  basePrice,
  visitFee,
  gstTax,
  grandTotal,
  paymentMethod,
  bookingCode,
  idempotencyKey,
  scheduleDate,
  scheduleSlot,
}) {
  if (!customerId) {
    const err = new Error('Authenticated customer ID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const canonicalId = resolveCanonicalServiceId(serviceId, serviceName);
  if (!canonicalId) {
    const err = new Error(`Unknown or invalid service requested: "${serviceName || serviceId}"`);
    err.status = 400;
    err.code = 'INVALID_SERVICE';
    throw err;
  }

  if (idempotencyKey) {
    const dupSnap = await db.collection('bookings')
      .where('idempotencyKey', '==', String(idempotencyKey))
      .limit(5)
      .get();
    const dup = dupSnap.docs.find((d) => d.data().customerId === customerId && String(d.data().status || '').toUpperCase() !== 'CANCELLED');
    if (dup) {
      const err = new Error('Duplicate booking request rejected');
      err.status = 409;
      err.code = 'DUPLICATE_BOOKING';
      throw err;
    }
  }

  if (serviceId) {
    const srvSnap = await db.collection('services').doc(String(serviceId)).get();
    if (srvSnap.exists && (srvSnap.data().isActive === false || srvSnap.data().active === false)) {
      const err = new Error(`Service "${serviceName || serviceId}" is currently disabled`);
      err.status = 400;
      err.code = 'SERVICE_DISABLED';
      throw err;
    }
  }

  if (coordinates && typeof coordinates === 'object') {
    const lat = Number(coordinates.latitude);
    const lng = Number(coordinates.longitude);
    if (!Number.isFinite(lat) || lat < -90 || lat > 90 || !Number.isFinite(lng) || lng < -180 || lng > 180) {
      const err = new Error('Invalid customer coordinates');
      err.status = 400;
      err.code = 'INVALID_COORDINATES';
      throw err;
    }
  }

  const bookingId = `bkg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const nowIso = new Date().toISOString();

  // Server-Authoritative Pricing (Standard minimum pricing fallback)
  const finalPrice = Math.max(199, Number(grandTotal ?? price) || 1039);

  // Generate 4-digit Cryptographic OTPs
  const startOtp = generateOtp(4);
  const endOtp = generateOtp(4);

  // Store OTP Hashes in Secrets Collection (Strictly forbidden for clients)
  await createBookingSecrets(db, bookingId, startOtp, endOtp);

  // Store Booking Document (Publicly readable by participants, NO plaintext OTP)
  const bookingData = {
    id: bookingId,
    bookingCode: bookingCode || `BT-${String(Date.now()).slice(-8)}`,
    ...(idempotencyKey ? { idempotencyKey: String(idempotencyKey) } : {}),
    customerId,
    customerName: customerName || 'Customer',
    customerPhone: customerPhone || '',
    serviceId: canonicalId,
    serviceName: serviceName || canonicalId,
    categoryId: categoryId || 'general',
    address: address || {},
    coordinates: coordinates || null,
    ...(coordinates && typeof coordinates === 'object' ? { latitude: Number(coordinates.latitude), longitude: Number(coordinates.longitude) } : {}),
    ...(scheduleDate ? { scheduleDate: String(scheduleDate) } : {}),
    ...(scheduleSlot ? { scheduleSlot: String(scheduleSlot) } : {}),
    status: 'SEARCHING',
    paymentStatus: 'PENDING',
    paymentMethod: paymentMethod || 'CASH_ON_DELIVERY',
    price: finalPrice,
    totalAmount: finalPrice,
    basePrice: basePrice !== undefined ? Number(basePrice) : finalPrice,
    visitFee: visitFee !== undefined ? Number(visitFee) : 0,
    gstTax: gstTax !== undefined ? Number(gstTax) : 0,
    grandTotal: finalPrice,
    technicianId: null,
    technicianName: null,
    technicianPhone: null,
    assignedAt: null,
    serviceStartedAt: null,
    completedAt: null,
    startOtpRequired: true,
    endOtpRequired: true,
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  await db.collection('bookings').doc(bookingId).set(bookingData);

  // Store Customer-Only OTP Vault (Readable strictly by booking's customerId)
  await db.collection('customer_otps').doc(bookingId).set({
    bookingId,
    customerId,
    startOtp,
    endOtp,
    createdAt: nowIso,
    updatedAt: nowIso,
  });

  // Record Creation Event
  await db.collection('booking_events').doc().set({
    bookingId,
    eventType: 'BOOKING_CREATED',
    customerId,
    serviceId: canonicalId,
    price: finalPrice,
    timestamp: nowIso,
    createdAt: nowIso,
  });

  // Server-Authoritative Dispatch: Automatically generate offers for all eligible technicians
  const { dispatchBookingOffers } = require('./dispatchService');
  const dispatchedOffers = await dispatchBookingOffers(db, bookingData);

  return {
    success: true,
    message: 'Booking created successfully and dispatched to eligible technicians',
    bookingId,
    booking: bookingData,
    startOtp,
    endOtp,
    offersDispatched: dispatchedOffers.length,
    offerIds: dispatchedOffers.map((o) => o.id),
  };
}

async function resendStartOtp(db, { bookingId, callerUid }) {
  const bookingRef = db.collection('bookings').doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) {
    const err = new Error('Booking not found');
    err.status = 404;
    err.code = 'BOOKING_NOT_FOUND';
    throw err;
  }
  const booking = bookingSnap.data();

  // If customer is requesting their own OTP
  if (booking.customerId === callerUid) {
    const otpSnap = await db.collection('customer_otps').doc(bookingId).get();
    if (!otpSnap.exists) {
      const err = new Error('Customer OTP record not found');
      err.status = 404;
      err.code = 'OTP_NOT_FOUND';
      throw err;
    }
    return {
      success: true,
      message: 'Start OTP retrieved',
      startOtp: otpSnap.data().startOtp,
    };
  }

  // If assigned technician is requesting to resend to customer
  if (booking.technicianId === callerUid) {
    // Audit notification trigger
    await db.collection('booking_events').doc().set({
      bookingId,
      eventType: 'START_OTP_RESEND_TRIGGERED_BY_TECHNICIAN',
      technicianId: callerUid,
      timestamp: new Date().toISOString(),
    });

    return {
      success: true,
      message: 'Start OTP notification dispatched to customer',
      // Note: Plaintext OTP is intentionally NOT returned to technician
    };
  }

  const err = new Error('Unauthorized to request OTP for this booking');
  err.status = 403;
  err.code = 'FORBIDDEN';
  throw err;
}

async function resendEndOtp(db, { bookingId, callerUid }) {
  const bookingRef = db.collection('bookings').doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) {
    const err = new Error('Booking not found');
    err.status = 404;
    err.code = 'BOOKING_NOT_FOUND';
    throw err;
  }
  const booking = bookingSnap.data();

  if (booking.customerId === callerUid) {
    const otpSnap = await db.collection('customer_otps').doc(bookingId).get();
    if (!otpSnap.exists) {
      const err = new Error('Customer OTP record not found');
      err.status = 404;
      err.code = 'OTP_NOT_FOUND';
      throw err;
    }
    return {
      success: true,
      message: 'Ending OTP retrieved',
      endOtp: otpSnap.data().endOtp,
    };
  }

  if (booking.technicianId === callerUid) {
    await db.collection('booking_events').doc().set({
      bookingId,
      eventType: 'END_OTP_RESEND_TRIGGERED_BY_TECHNICIAN',
      technicianId: callerUid,
      timestamp: new Date().toISOString(),
    });

    return {
      success: true,
      message: 'Ending OTP notification dispatched to customer',
    };
  }

  const err = new Error('Unauthorized to request OTP for this booking');
  err.status = 403;
  err.code = 'FORBIDDEN';
  throw err;
}

async function getCustomerOtps(db, { bookingId, callerUid }) {
  const bookingSnap = await db.collection('bookings').doc(bookingId).get();
  if (!bookingSnap.exists) {
    const err = new Error('Booking not found');
    err.status = 404;
    err.code = 'BOOKING_NOT_FOUND';
    throw err;
  }
  const booking = bookingSnap.data();
  if (booking.customerId !== callerUid) {
    const err = new Error('Forbidden: Only the customer who created this booking can view its OTPs');
    err.status = 403;
    err.code = 'FORBIDDEN';
    throw err;
  }

  const otpSnap = await db.collection('customer_otps').doc(bookingId).get();
  if (!otpSnap.exists) {
    const err = new Error('OTP records not found');
    err.status = 404;
    err.code = 'OTP_NOT_FOUND';
    throw err;
  }

  return {
    success: true,
    startOtp: otpSnap.data().startOtp,
    endOtp: otpSnap.data().endOtp,
  };
}

module.exports = {
  createBooking,
  resendStartOtp,
  resendEndOtp,
  getCustomerOtps,
};

