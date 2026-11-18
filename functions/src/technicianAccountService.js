/**
 * Authoritative Technician Account, KYC Document & Job Execution Service
 * Preserves all P0 protections:
 * - Technicians can never modify kycStatus, accountStatus, isAdminApproved, walletBalance, or skill verification.
 * - Pre-work travel status transitions (`ON_THE_WAY`, `ARRIVED`) require ownership.
 * - `IN_PROGRESS` and `COMPLETED` strictly remain OTP-gated in otpVerificationService.
 */

const BLOCKED_TECH_PROFILE_KEYS = new Set([
  'role',
  'admin',
  'isAdmin',
  'superAdmin',
  'isSuperAdmin',
  'verifiedAdmin',
  'kycStatus',
  'kycVerified',
  'isVerified',
  'accountStatus',
  'status',
  'isAdminApproved',
  'adminApproved',
  'approvedByAdmin',
  'verifiedByAdminUid',
  'skills',
  'selectedSkills',
  'skillsVerificationStatus',
  'skillVerificationStatus',
  'verifiedSkillsCount',
  'pendingSkillsCount',
  'walletBalance',
  'rating',
  'totalRatingsCount',
  'totalJobsCompleted',
]);

const ALLOWED_DOCUMENT_TYPES = new Set([
  'SELFIE',
  'LIVE_SELFIE',
  'AADHAAR',
  'AADHAR',
  'VOTER_CARD',
  'VOTER',
  'PAN',
  'DRIVING_LICENSE',
  'CERTIFICATE',
]);

function sanitizeBookingForTechnician(docData, docId) {
  const clean = { id: docId, ...docData };
  delete clean.startOtp;
  delete clean.endOtp;
  delete clean.startOtpHash;
  delete clean.endOtpHash;
  return clean;
}

async function getTechnicianProfile(db, { uid }) {
  if (!uid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const ref = db.collection('technician_profiles').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    return {
      success: true,
      data: {
        id: uid,
        uid,
        technicianId: uid,
        technicianCode: `BT-${uid.slice(-6).toUpperCase()}`,
        fullName: 'Partner Technician',
        kycStatus: 'PENDING',
        accountStatus: 'PENDING_VERIFICATION',
        isOnline: false,
        walletBalance: 0,
        rating: 0,
        totalJobsCompleted: 0,
      },
    };
  }

  const data = snap.data();
  return {
    success: true,
    data: {
      id: snap.id,
      technicianId: snap.id,
      ...data,
    },
  };
}

async function updateTechnicianProfile(db, { callerUid, body }) {
  if (!callerUid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const input = body && typeof body === 'object' ? body : {};
  for (const key of Object.keys(input)) {
    if (BLOCKED_TECH_PROFILE_KEYS.has(key)) {
      const err = new Error(`Forbidden field update: "${key}" requires Admin verification`);
      err.status = 403;
      err.code = 'FORBIDDEN_FIELD_UPDATE';
      throw err;
    }
  }

  const nowIso = new Date().toISOString();
  const ref = db.collection('technician_profiles').doc(callerUid);
  const existingSnap = await ref.get();
  const existing = existingSnap.exists ? existingSnap.data() : {};

  const patch = {
    id: callerUid,
    uid: callerUid,
    technicianId: callerUid,
    updatedAt: nowIso,
  };

  if (input.fullName !== undefined) {
    patch.fullName = String(input.fullName).trim();
    patch.name = patch.fullName;
  } else if (input.name !== undefined) {
    patch.name = String(input.name).trim();
    patch.fullName = patch.name;
  }

  const imageVal = input.profileImageUrl ?? input.photoUrl ?? input.selfieImageUrl;
  if (imageVal !== undefined && String(imageVal).trim()) {
    const cleanImg = String(imageVal).trim();
    patch.profileImageUrl = cleanImg;
    patch.selfieImageUrl = cleanImg;
  }

  if (input.upiId !== undefined) {
    const upi = String(input.upiId).trim();
    patch.upiId = upi;
    patch.isUpiVerified = upi.includes('@');
    if (upi.includes('@')) {
      const [userPart, domainPart] = upi.split('@');
      patch.maskedUpiId = `${userPart.slice(0, 2)}***@${domainPart}`;
    }
  }

  if (input.experience !== undefined) patch.experience = String(input.experience);
  if (input.experienceYears !== undefined) patch.experienceYears = Number(input.experienceYears) || 0;
  if (input.onboardingStep !== undefined) patch.onboardingStep = String(input.onboardingStep);
  if (input.onboardingCompleted !== undefined) patch.onboardingCompleted = Boolean(input.onboardingCompleted);
  if (input.fcmToken !== undefined) {
    patch.fcmToken = String(input.fcmToken);
    patch.fcmTokenUpdatedAt = nowIso;
  }

  if (!existing.createdAt) patch.createdAt = nowIso;
  if (!existing.kycStatus) patch.kycStatus = 'PENDING';
  if (!existing.accountStatus) patch.accountStatus = 'PENDING_VERIFICATION';

  await ref.set(patch, { merge: true });
  return getTechnicianProfile(db, { uid: callerUid });
}

async function listTechnicianDocuments(db, { uid }) {
  if (!uid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const snap = await db.collection('technician_documents').where('technicianId', '==', uid).limit(50).get();
  const docs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  docs.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  return { success: true, count: docs.length, data: docs };
}

async function submitTechnicianDocument(db, { callerUid, body }) {
  if (!callerUid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const input = body && typeof body === 'object' ? body : {};
  const docType = String(input.documentType || '').trim().toUpperCase();
  const fileUrl = String(input.fileUrl || input.secureUrl || input.photoUrl || '').trim();
  const maskedNumber = String(input.maskedNumber || '').trim();

  if (!docType || !ALLOWED_DOCUMENT_TYPES.has(docType)) {
    const err = new Error(`Invalid KYC document type "${docType}"`);
    err.status = 400;
    err.code = 'INVALID_DOCUMENT_TYPE';
    throw err;
  }
  if (!fileUrl || !/^https?:\/\//i.test(fileUrl)) {
    const err = new Error('Valid document image URL is required');
    err.status = 400;
    err.code = 'INVALID_DOCUMENT_URL';
    throw err;
  }

  const nowIso = new Date().toISOString();
  const docId = `doc_${callerUid}_${docType.toLowerCase()}`;
  const docRecord = {
    id: docId,
    technicianId: callerUid,
    documentType: docType,
    secureUrl: fileUrl,
    fileUrl,
    maskedNumber,
    verificationStatus: 'PENDING',
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  await db.collection('technician_documents').doc(docId).set(docRecord, { merge: true });

  const techRef = db.collection('technician_profiles').doc(callerUid);
  const techSnap = await techRef.get();
  const existing = techSnap.exists ? techSnap.data() : {};
  const profilePatch = {
    id: callerUid,
    uid: callerUid,
    technicianId: callerUid,
    updatedAt: nowIso,
  };
  if (docType === 'SELFIE' || docType === 'LIVE_SELFIE') {
    profilePatch.profileImageUrl = fileUrl;
    profilePatch.selfieImageUrl = fileUrl;
  }
  if (!existing.kycStatus || existing.kycStatus === 'NOT_SUBMITTED') {
    profilePatch.kycStatus = 'PENDING';
  }
  if (!existing.createdAt) {
    profilePatch.createdAt = nowIso;
  }
  await techRef.set(profilePatch, { merge: true });

  return { success: true, data: docRecord };
}

async function listTechnicianJobs(db, { callerUid }) {
  if (!callerUid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const snap = await db.collection('bookings').where('technicianId', '==', callerUid).limit(100).get();
  const jobs = snap.docs.map((d) => sanitizeBookingForTechnician(d.data(), d.id));
  jobs.sort((a, b) => String(b.updatedAt || b.createdAt || '').localeCompare(String(a.updatedAt || a.createdAt || '')));
  return { success: true, count: jobs.length, data: jobs, bookings: jobs };
}

async function updateTechnicianJobStatus(db, { bookingId, callerUid, status }) {
  if (!bookingId) {
    const err = new Error('Booking ID is required');
    err.status = 400;
    err.code = 'MISSING_BOOKING_ID';
    throw err;
  }
  if (!callerUid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const normalizedNext = String(status || '').trim().toUpperCase();
  const mappedNext = normalizedNext === 'EN_ROUTE' || normalizedNext === 'TECHONTHEWAY'
    ? 'ON_THE_WAY'
    : (normalizedNext === 'TECHARRIVED' ? 'ARRIVED' : normalizedNext);

  if (!['ON_THE_WAY', 'ARRIVED'].includes(mappedNext)) {
    const err = new Error('Status transitions to IN_PROGRESS or COMPLETED strictly require Start/End OTP verification');
    err.status = 400;
    err.code = 'UNSUPPORTED_STATUS_TRANSITION';
    throw err;
  }

  const bookingRef = db.collection('bookings').doc(bookingId);
  const snap = await bookingRef.get();
  if (!snap.exists) {
    const err = new Error('Booking not found');
    err.status = 404;
    err.code = 'BOOKING_NOT_FOUND';
    throw err;
  }

  const booking = snap.data();
  if (booking.technicianId !== callerUid) {
    const err = new Error('Forbidden: You are not the assigned technician for this booking');
    err.status = 403;
    err.code = 'TECHNICIAN_NOT_ASSIGNED';
    throw err;
  }

  const currentStatus = String(booking.status || '').toUpperCase();
  const validSourceStates = mappedNext === 'ON_THE_WAY'
    ? ['ASSIGNED', 'ACCEPTED', 'CONFIRMED', 'ON_THE_WAY']
    : ['ASSIGNED', 'ACCEPTED', 'CONFIRMED', 'ON_THE_WAY', 'ARRIVED'];

  if (!validSourceStates.includes(currentStatus)) {
    const err = new Error(`Cannot transition booking from "${currentStatus}" to "${mappedNext}"`);
    err.status = 400;
    err.code = 'INVALID_BOOKING_STATUS';
    throw err;
  }

  const nowIso = new Date().toISOString();
  await bookingRef.set({
    status: mappedNext,
    ...(mappedNext === 'ON_THE_WAY' ? { enRouteAt: nowIso } : {}),
    ...(mappedNext === 'ARRIVED' ? { arrivedAt: nowIso } : {}),
    updatedAt: nowIso,
  }, { merge: true });

  await db.collection('booking_events').doc().set({
    bookingId,
    eventType: mappedNext === 'ON_THE_WAY' ? 'TECHNICIAN_ON_THE_WAY' : 'TECHNICIAN_ARRIVED',
    technicianId: callerUid,
    timestamp: nowIso,
    createdAt: nowIso,
  });

  const updated = (await bookingRef.get()).data();
  return {
    success: true,
    status: mappedNext,
    booking: sanitizeBookingForTechnician(updated, bookingId),
    data: sanitizeBookingForTechnician(updated, bookingId),
  };
}

module.exports = {
  getTechnicianProfile,
  updateTechnicianProfile,
  listTechnicianDocuments,
  submitTechnicianDocument,
  listTechnicianJobs,
  updateTechnicianJobStatus,
};
