const crypto = require('crypto');
const admin = require('firebase-admin');
const { generateSalt, hashOtp } = require('./otpService');
const { deriveNameFromEmail, sendOtpEmail } = require('./emailService');
const { signJwt, verifyJwt } = require('./jwtHelper');

const OTP_TTL_MS = 10 * 60 * 1000;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 3;
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000;

function generateSixDigitOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

function normalizeIdentifier({ email, phone }) {
  const cleanEmail = String(email || '').trim().toLowerCase();
  const cleanPhone = String(phone || '').trim();
  const identifier = cleanEmail || cleanPhone.toLowerCase();
  return { cleanEmail, cleanPhone, identifier };
}

function buildChallengeDocId(identifier) {
  return `otp_${String(identifier).replace(/[^a-zA-Z0-9_-]/g, '_')}`;
}

function resolveCanonicalTechUid(rawId, phone = '') {
  const clean = String(rawId || phone || '').trim();
  if (!clean || clean === 'BT-PARTNER') return 'uid_tech_partner';
  if (
    clean.length >= 20 &&
    !clean.includes('@') &&
    !clean.startsWith('+') &&
    !clean.startsWith('tech_') &&
    !clean.startsWith('uid_')
  ) {
    return clean;
  }
  if (clean.startsWith('uid_tech_')) return clean;
  const digits = String(phone || clean).replace(/\D/g, '');
  if (digits.length >= 10) {
    return `uid_tech_${digits.slice(-10)}`;
  }
  if (clean.startsWith('tech_')) {
    return `uid_${clean}`;
  }
  return `uid_tech_${clean.replace(/[^a-zA-Z0-9]/g, '_')}`;
}

function resolveCanonicalCustomerUid(email, phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.length >= 10) {
    return `uid_cust_${digits.slice(-10)}`;
  }
  return `uid_cust_${String(email || '').trim().toLowerCase().replace(/[^a-zA-Z0-9]/g, '_')}`;
}

function resolveTechnicianCode(uid, phone = '') {
  const digits = String(phone || uid || '').replace(/\D/g, '');
  if (digits.length >= 6) {
    return `BT-${digits.slice(-6)}`;
  }
  let hash = 0;
  for (let i = 0; i < String(uid).length; i++) {
    hash = ((hash << 5) - hash + String(uid).charCodeAt(i)) | 0;
  }
  return `BT-${String(Math.abs(hash)).padStart(6, '0').slice(0, 6)}`;
}

function timingSafeEquals(a, b) {
  const hashA = crypto.createHash('sha256').update(String(a || '')).digest();
  const hashB = crypto.createHash('sha256').update(String(b || '')).digest();
  return crypto.timingSafeEqual(hashA, hashB);
}

async function isGenuineAdminEmail(db, email) {
  const normalized = String(email || '').trim().toLowerCase();
  if (!normalized || !normalized.includes('@')) return false;

  // 1. Server-configured Admin allowlist (Render env variables only; never user-editable)
  const configuredAdmins = [
    process.env.ADMIN_EMAIL || '',
    ...String(process.env.ADMIN_ALLOWLIST_EMAILS || '').split(','),
  ]
    .map((e) => String(e || '').trim().toLowerCase())
    .filter((e) => e.includes('@'));

  for (const adminEmail of configuredAdmins) {
    if (timingSafeEquals(normalized, adminEmail)) {
      return true;
    }
  }

  // 2. Backend-only protected system_admins collection (Firestore Rules deny ALL client access)
  // NEVER trust client-writable `users/{uid}.role` for Admin privilege checks.
  if (db) {
    try {
      const snap = await db.collection('system_admins').where('email', '==', normalized).limit(1).get();
      if (!snap.empty) {
        const data = snap.docs[0].data() || {};
        const adminRole = String(data.role || '').toUpperCase();
        if (data.active !== false && (adminRole === 'ADMIN' || adminRole === 'SUPER_ADMIN')) {
          return true;
        }
      }
    } catch (_) {}
  }

  // 3. Authoritative Firebase Auth custom claims (set strictly by Firebase Admin SDK)
  if (admin.apps.length > 0 && (!process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
    try {
      const fbUser = await admin.auth().getUserByEmail(normalized);
      const claims = fbUser?.customClaims || {};
      const claimRole = String(claims.role || '').toUpperCase();
      if (claims.admin === true || claimRole === 'ADMIN' || claimRole === 'SUPER_ADMIN') {
        return true;
      }
    } catch (_) {}
  }

  return false;
}

function sanitizeRole(requestedRole, email = '', isVerifiedAdmin = false) {
  const upper = String(requestedRole || 'CUSTOMER').trim().toUpperCase();
  if (upper === 'TECHNICIAN') return 'TECHNICIAN';
  if (upper === 'ADMIN' || upper === 'SUPER_ADMIN') {
    if (isVerifiedAdmin) {
      return upper === 'SUPER_ADMIN' ? 'SUPER_ADMIN' : 'ADMIN';
    }
    // Never allow client-driven escalation to ADMIN
    return 'CUSTOMER';
  }
  return 'CUSTOMER';
}

async function findExistingAccount(db, { cleanEmail, cleanPhone, role }) {
  const normalizedPhoneDigits = cleanPhone.replace(/\D/g, '').slice(-10);
  const targetRole = String(role || 'CUSTOMER').toUpperCase();

  if (cleanEmail) {
    if (targetRole === 'ADMIN' || targetRole === 'SUPER_ADMIN') {
      const adminSnap = await db.collection('system_admins').where('email', '==', cleanEmail).limit(1).get();
      if (!adminSnap.empty) {
        const doc = adminSnap.docs[0];
        return { uid: doc.id, data: doc.data() };
      }
      const userSnap = await db.collection('users').where('email', '==', cleanEmail).limit(1).get();
      if (!userSnap.empty) {
        const doc = userSnap.docs[0];
        const r = String(doc.data()?.role || '').toUpperCase();
        if (r === 'ADMIN' || r === 'SUPER_ADMIN') {
          return { uid: doc.id, data: doc.data() };
        }
      }
      return null;
    }

    const colName = targetRole === 'TECHNICIAN' ? 'technician_profiles' : 'customers';
    const [roleSnap, userSnap] = await Promise.all([
      db.collection(colName).where('email', '==', cleanEmail).limit(1).get(),
      db.collection('users').where('email', '==', cleanEmail).limit(5).get(),
    ]);
    if (!roleSnap.empty) {
      const doc = roleSnap.docs[0];
      return { uid: doc.id, data: doc.data() };
    }
    for (const doc of userSnap.docs) {
      const docRole = String(doc.data()?.role || '').toUpperCase();
      if (docRole === targetRole) {
        return { uid: doc.id, data: doc.data() };
      }
    }
  }

  if (cleanPhone && targetRole !== 'ADMIN' && targetRole !== 'SUPER_ADMIN') {
    const candidates = [cleanPhone];
    if (normalizedPhoneDigits.length === 10) {
      candidates.push(normalizedPhoneDigits, `+91${normalizedPhoneDigits}`);
    }
    const colName = targetRole === 'TECHNICIAN' ? 'technician_profiles' : 'customers';
    for (const candidate of [...new Set(candidates)]) {
      const snap = await db.collection(colName).where('phone', '==', candidate).limit(1).get();
      if (!snap.empty) {
        const doc = snap.docs[0];
        return { uid: doc.id, data: doc.data() };
      }
    }
  }

  if (cleanEmail && admin.apps.length > 0 && !process.env.FIRESTORE_EMULATOR_HOST) {
    try {
      const fbUser = await admin.auth().getUserByEmail(cleanEmail);
      const claims = fbUser?.customClaims || {};
      const claimRole = String(claims.role || '').toUpperCase();
      if (fbUser && fbUser.uid && (!claimRole || claimRole === targetRole)) {
        return {
          uid: fbUser.uid,
          data: {
            email: fbUser.email,
            fullName: fbUser.displayName || deriveNameFromEmail(cleanEmail),
            phone: fbUser.phoneNumber || '',
          },
        };
      }
    } catch (_) {}
  }

  return null;
}

/**
 * Generate an OTP challenge stored in Firestore `otp_challenges` and send via EmailJS.
 */
async function requestOtp(
  db,
  { email, phone, name, fullName, role = 'CUSTOMER', purpose, isResend = false },
  { sendOtpEmailFn = sendOtpEmail, nowMs = Date.now() } = {}
) {
  const { cleanEmail, cleanPhone, identifier } = normalizeIdentifier({ email, phone });
  if (!identifier) {
    const err = new Error('Email or phone number is required');
    err.status = 400;
    err.code = 'MISSING_IDENTIFIER';
    throw err;
  }

  const requestedUpperRole = String(role || 'CUSTOMER').trim().toUpperCase();
  const isAdminRequest = requestedUpperRole === 'ADMIN' || requestedUpperRole === 'SUPER_ADMIN';
  const verifiedAdmin = isAdminRequest ? await isGenuineAdminEmail(db, cleanEmail) : false;
  const upperPurpose = String(purpose || '').trim().toUpperCase();

  if (isAdminRequest && !verifiedAdmin) {
    const err = new Error('Forbidden: Email is not authorized for Administrator access.');
    err.status = 403;
    err.code = 'ADMIN_AUTHORIZATION_REQUIRED';
    throw err;
  }

  const resolvedRole = sanitizeRole(role, cleanEmail, verifiedAdmin);
  const existing = await findExistingAccount(db, {
    cleanEmail,
    cleanPhone,
    role: resolvedRole,
  });

  if (!isResend) {
    if (upperPurpose === 'LOGIN' && !existing && !verifiedAdmin) {
      const err = new Error('No account found with this email or phone. Please sign up to create a new account.');
      err.status = 404;
      err.code = 'ACCOUNT_NOT_FOUND';
      err.extra = { notFound: true, identifier };
      throw err;
    }
    if (upperPurpose === 'REGISTER' && existing) {
      const err = new Error('An account with this email or phone already exists. Please log in.');
      err.status = 409;
      err.code = 'ACCOUNT_ALREADY_EXISTS';
      err.extra = { alreadyExists: true, identifier };
      throw err;
    }
  }

  const targetEmail = cleanEmail || String(existing?.data?.email || '').trim().toLowerCase();
  if (!targetEmail || !targetEmail.includes('@')) {
    const err = new Error('A valid email address is required for OTP verification delivery');
    err.status = 400;
    err.code = 'EMAIL_REQUIRED';
    throw err;
  }

  const docId = buildChallengeDocId(identifier);
  const challengeRef = db.collection('otp_challenges').doc(docId);

  const otp = generateSixDigitOtp();
  const salt = generateSalt();
  const otpHash = hashOtp(otp, salt);

  const candidateName = String(fullName || name || '').trim();
  const resolvedName =
    candidateName ||
    existing?.data?.fullName ||
    existing?.data?.name ||
    deriveNameFromEmail(targetEmail);

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(challengeRef);
    let requestCount = 0;
    let windowStartMs = nowMs;

    if (snap.exists) {
      const prev = snap.data();
      const prevWindowStart = Number(prev.windowStartMs) || 0;
      const prevCount = Number(prev.requestCount) || 0;
      if (nowMs - prevWindowStart < RATE_LIMIT_WINDOW_MS) {
        if (prevCount >= MAX_REQUESTS_PER_WINDOW) {
          const err = new Error('Rate limit exceeded: Maximum 3 OTP requests allowed within 10 minutes.');
          err.status = 429;
          err.code = 'OTP_RATE_LIMIT_EXCEEDED';
          err.extra = { retryAfter: Math.ceil((RATE_LIMIT_WINDOW_MS - (nowMs - prevWindowStart)) / 1000) };
          throw err;
        }
        requestCount = prevCount;
        windowStartMs = prevWindowStart;
      }
    }

    transaction.set(challengeRef, {
      id: docId,
      identifier,
      email: targetEmail,
      phone: cleanPhone || existing?.data?.phone || '',
      role: resolvedRole,
      purpose: String(purpose || (existing ? 'LOGIN' : 'REGISTER')).toUpperCase(),
      fullName: resolvedName,
      salt,
      otpHash,
      consumed: false,
      failedAttempts: 0,
      lockedUntilMs: 0,
      requestCount: requestCount + 1,
      windowStartMs,
      requestedAtMs: nowMs,
      expiresAtMs: nowMs + OTP_TTL_MS,
      updatedAt: new Date(nowMs).toISOString(),
    });
  });

  const emailResult = await sendOtpEmailFn(targetEmail, otp, resolvedRole, resolvedName);
  if (!emailResult || emailResult.success !== true) {
    const err = new Error(emailResult?.error || 'Failed to dispatch verification email');
    err.status = emailResult?.configured === false ? 503 : 502;
    err.code = emailResult?.code || 'EMAIL_DISPATCH_FAILED';
    throw err;
  }

  return {
    success: true,
    message: `OTP sent successfully to ${targetEmail}`,
    identifier,
    name: resolvedName,
    emailSent: true,
    expiresInSeconds: OTP_TTL_MS / 1000,
  };
}

/**
 * Verify an OTP challenge atomically via Firestore transaction and resolve user profile + session tokens.
 */
async function verifyOtp(
  db,
  { email, phone, otp, role, fullName, name, fcmToken, latitude, longitude },
  { nowMs = Date.now() } = {}
) {
  const { cleanEmail, cleanPhone, identifier } = normalizeIdentifier({ email, phone });
  const inputOtp = String(otp || '').trim();
  if (!identifier || !inputOtp) {
    const err = new Error('Identifier and OTP are required');
    err.status = 400;
    err.code = 'MISSING_OTP_CREDENTIALS';
    throw err;
  }

  const docId = buildChallengeDocId(identifier);
  const challengeRef = db.collection('otp_challenges').doc(docId);
  let verifiedChallenge = null;

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(challengeRef);
    if (!snap.exists) {
      const err = new Error('OTP has expired or was not requested. Please request a new OTP.');
      err.status = 400;
      err.code = 'OTP_EXPIRED';
      throw err;
    }

    const challenge = snap.data();
    const lockedUntilMs = Number(challenge.lockedUntilMs) || 0;
    if (lockedUntilMs > nowMs) {
      const err = new Error('Too many incorrect OTP attempts. For your security, this identifier is locked for 15 minutes.');
      err.status = 429;
      err.code = 'OTP_ATTEMPT_LIMIT_EXCEEDED';
      err.extra = { retryAfter: Math.ceil((lockedUntilMs - nowMs) / 1000) };
      throw err;
    }

    if (challenge.consumed === true) {
      const err = new Error('This OTP has already been used. Please request a new OTP.');
      err.status = 400;
      err.code = 'OTP_ALREADY_USED';
      throw err;
    }

    if (Number(challenge.expiresAtMs || 0) < nowMs) {
      const err = new Error('OTP has expired. Please request a new OTP.');
      err.status = 400;
      err.code = 'OTP_EXPIRED';
      throw err;
    }

    const expectedHash = String(challenge.otpHash || '');
    const actualHash = hashOtp(inputOtp, challenge.salt || '');
    let valid = false;
    if (expectedHash.length > 0 && actualHash.length === expectedHash.length) {
      valid = crypto.timingSafeEqual(Buffer.from(actualHash, 'hex'), Buffer.from(expectedHash, 'hex'));
    }

    if (!valid) {
      const nextFailed = (Number(challenge.failedAttempts) || 0) + 1;
      const locked = nextFailed >= MAX_FAILED_ATTEMPTS;
      transaction.update(challengeRef, {
        failedAttempts: nextFailed,
        lockedUntilMs: locked ? nowMs + LOCKOUT_DURATION_MS : 0,
        updatedAt: new Date(nowMs).toISOString(),
      });
      const err = new Error(
        locked
          ? 'Maximum failed OTP attempts reached. Account locked for 15 minutes.'
          : `Invalid OTP. ${MAX_FAILED_ATTEMPTS - nextFailed} attempts remaining.`
      );
      err.status = locked ? 429 : 400;
      err.code = locked ? 'OTP_ATTEMPT_LIMIT_EXCEEDED' : 'INVALID_OTP';
      err.extra = { attemptsRemaining: Math.max(0, MAX_FAILED_ATTEMPTS - nextFailed) };
      throw err;
    }

    transaction.update(challengeRef, {
      consumed: true,
      otpHash: '',
      salt: '',
      failedAttempts: 0,
      lockedUntilMs: 0,
      verifiedAtMs: nowMs,
      updatedAt: new Date(nowMs).toISOString(),
    });
    verifiedChallenge = challenge;
  });

  const finalEmail = cleanEmail || String(verifiedChallenge.email || '').trim().toLowerCase();
  const finalPhone = cleanPhone || String(verifiedChallenge.phone || '').trim();
  const rawRequestedRole = String(role || verifiedChallenge.role || 'CUSTOMER').trim().toUpperCase();
  const challengeRole = String(verifiedChallenge.role || 'CUSTOMER').trim().toUpperCase();
  const isAdminRequest =
    rawRequestedRole === 'ADMIN' ||
    rawRequestedRole === 'SUPER_ADMIN' ||
    challengeRole === 'ADMIN' ||
    challengeRole === 'SUPER_ADMIN';
  const verifiedAdmin = isAdminRequest ? await isGenuineAdminEmail(db, finalEmail) : false;

  if (isAdminRequest && !verifiedAdmin) {
    const err = new Error('Forbidden: Verified administrator privileges required.');
    err.status = 403;
    err.code = 'ADMIN_AUTHORIZATION_REQUIRED';
    throw err;
  }

  const resolvedRole = sanitizeRole(verifiedChallenge.role || role, finalEmail, verifiedAdmin);
  const existing = await findExistingAccount(db, {
    cleanEmail: finalEmail,
    cleanPhone: finalPhone,
    role: resolvedRole,
  });

  const resolvedUid =
    existing?.uid ||
    (verifiedAdmin
      ? `admin_${finalEmail.replace(/[^a-zA-Z0-9]/g, '_')}`
      : (resolvedRole === 'TECHNICIAN'
          ? resolveCanonicalTechUid(finalPhone || finalEmail, finalPhone)
          : resolveCanonicalCustomerUid(finalEmail, finalPhone)));

  const resolvedName =
    String(fullName || name || existing?.data?.fullName || verifiedChallenge.fullName || '').trim() ||
    deriveNameFromEmail(finalEmail);
  const nowIso = new Date(nowMs).toISOString();
  const partnerCode = resolvedRole === 'TECHNICIAN'
    ? (existing?.data?.technicianCode || resolveTechnicianCode(resolvedUid, finalPhone))
    : undefined;

  const userPatch = {
    id: resolvedUid,
    uid: resolvedUid,
    email: finalEmail,
    phone: finalPhone,
    fullName: resolvedName,
    name: resolvedName,
    role: resolvedRole,
    updatedAt: nowIso,
    ...(fcmToken ? { fcmToken } : {}),
    ...(existing ? {} : { createdAt: nowIso }),
  };

  await db.collection('users').doc(resolvedUid).set(userPatch, { merge: true });

  if (resolvedRole === 'CUSTOMER') {
    await db.collection('customers').doc(resolvedUid).set(
      {
        ...userPatch,
        customerId: resolvedUid,
        status: existing?.data?.status || 'ACTIVE',
      },
      { merge: true }
    );
  } else if (resolvedRole === 'TECHNICIAN') {
    // Preserve admin-governed KYC, skills, ratings, and online presence fields on login
    const existingTech = existing?.data || {};
    const parsedLat = Number(latitude);
    const parsedLng = Number(longitude);
    const hasCoords = Number.isFinite(parsedLat) && Number.isFinite(parsedLng) && parsedLat !== 0 && parsedLng !== 0;

    await db.collection('technician_profiles').doc(resolvedUid).set(
      {
        id: resolvedUid,
        uid: resolvedUid,
        technicianId: resolvedUid,
        technicianCode: partnerCode,
        fullName: existingTech.fullName || resolvedName,
        name: existingTech.name || resolvedName,
        email: finalEmail || existingTech.email || '',
        phone: finalPhone || existingTech.phone || '',
        phoneNumber: finalPhone || existingTech.phoneNumber || '',
        updatedAt: nowIso,
        ...(existing ? {} : {
          createdAt: nowIso,
          accountStatus: 'Pending_Verification',
          kycStatus: 'PENDING',
          isOnline: false,
          availabilityStatus: 'OFFLINE',
          skills: [],
          selectedSkills: [],
        }),
        ...(hasCoords ? { latitude: parsedLat, longitude: parsedLng, lastLocationUpdate: nowIso } : {}),
      },
      { merge: true }
    );
  }

  return buildAuthSessionResponse({
    resolvedUid,
    resolvedName,
    finalEmail,
    finalPhone,
    resolvedRole,
    partnerCode,
  });
}

async function buildAuthSessionResponse({
  resolvedUid,
  resolvedName,
  finalEmail = '',
  finalPhone = '',
  resolvedRole = 'CUSTOMER',
  partnerCode,
  message = 'Authentication successful',
}) {
  const isAdminRole = resolvedRole === 'ADMIN' || resolvedRole === 'SUPER_ADMIN';
  let firebaseCustomToken = null;
  if (admin.apps.length > 0 && !process.env.FIRESTORE_EMULATOR_HOST) {
    try {
      firebaseCustomToken = await admin.auth().createCustomToken(resolvedUid, {
        role: resolvedRole,
        admin: isAdminRole,
      });
    } catch (_) {
      firebaseCustomToken = null;
    }
  }

  const jwtSecret = (process.env.JWT_SECRET || '').trim();
  const refreshSecret = (process.env.REFRESH_TOKEN_SECRET || jwtSecret).trim();
  const tokenPayload = {
    uid: resolvedUid,
    id: resolvedUid,
    email: finalEmail,
    phone: finalPhone,
    name: resolvedName,
    role: resolvedRole,
    ...(partnerCode ? { technicianCode: partnerCode } : {}),
  };

  const accessToken = jwtSecret
    ? signJwt({ ...tokenPayload, tokenType: 'access' }, jwtSecret, 7 * 24 * 3600)
    : null;
  const refreshToken = refreshSecret
    ? signJwt({ ...tokenPayload, tokenType: 'refresh' }, refreshSecret, 30 * 24 * 3600)
    : null;

  const userObj = {
    id: resolvedUid,
    uid: resolvedUid,
    customerId: resolvedUid,
    technicianId: resolvedUid,
    ...(partnerCode ? { technicianCode: partnerCode } : {}),
    phone: finalPhone,
    email: finalEmail,
    name: resolvedName,
    fullName: resolvedName,
    role: resolvedRole,
  };

  return {
    success: true,
    message,
    ...(accessToken ? { token: accessToken, accessToken } : {}),
    ...(refreshToken ? { refreshToken } : {}),
    ...(firebaseCustomToken ? { firebaseCustomToken } : {}),
    user: userObj,
    data: {
      ...(accessToken ? { token: accessToken, accessToken } : {}),
      ...(refreshToken ? { refreshToken } : {}),
      ...(firebaseCustomToken ? { firebaseCustomToken } : {}),
      user: userObj,
    },
  };
}

/**
 * Authoritative Admin direct passkey login verified against Render environment secrets.
 */
async function adminDirectAccess(db, { email, accessKey1, accessKey2, password, key } = {}) {
  const configuredEmail = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const configuredKey1 = (process.env.ADMIN_KEY_PRIMARY || '').trim();
  const configuredKey2 = (process.env.ADMIN_KEY_SECONDARY || '').trim();
  const configuredSecret = (process.env.ADMIN_SECRET_KEY || '').trim();

  if (!configuredEmail || (!configuredKey1 && !configuredKey2 && !configuredSecret)) {
    const err = new Error('Server configuration error: ADMIN_EMAIL and ADMIN_SECRET_KEY are not configured.');
    err.status = 503;
    err.code = 'ADMIN_CREDENTIALS_UNCONFIGURED';
    throw err;
  }

  const trimmedEmail = String(email || '').trim().toLowerCase();
  const providedKey1 = String(accessKey1 || password || key || '').trim();
  const providedKey2 = String(accessKey2 || '').trim();

  if (!trimmedEmail || (!providedKey1 && !providedKey2)) {
    const err = new Error('Administrator email and passkey are required.');
    err.status = 401;
    err.code = 'MISSING_ADMIN_CREDENTIALS';
    throw err;
  }

  const emailMatches = timingSafeEquals(trimmedEmail, configuredEmail);
  const keyMatches = [configuredKey1, configuredKey2, configuredSecret]
    .filter(Boolean)
    .some((secret) =>
      (providedKey1 && timingSafeEquals(providedKey1, secret)) ||
      (providedKey2 && timingSafeEquals(providedKey2, secret))
    );

  if (!emailMatches || !keyMatches) {
    const err = new Error('Unauthorized: Invalid administrator credentials or access key.');
    err.status = 401;
    err.code = 'INVALID_ADMIN_CREDENTIALS';
    throw err;
  }

  const adminUid = `admin_${trimmedEmail.replace(/[^a-zA-Z0-9]/g, '_')}`;
  if (db) {
    const nowIso = new Date().toISOString();
    await db.collection('users').doc(adminUid).set(
      {
        id: adminUid,
        uid: adminUid,
        email: trimmedEmail,
        fullName: 'System Administrator',
        name: 'System Administrator',
        role: 'SUPER_ADMIN',
        updatedAt: nowIso,
      },
      { merge: true }
    );
    await db.collection('system_admins').doc(adminUid).set(
      {
        id: adminUid,
        uid: adminUid,
        email: trimmedEmail,
        role: 'SUPER_ADMIN',
        active: true,
        updatedAt: nowIso,
      },
      { merge: true }
    );
  }

  return buildAuthSessionResponse({
    resolvedUid: adminUid,
    resolvedName: 'System Administrator',
    finalEmail: trimmedEmail,
    finalPhone: '',
    resolvedRole: 'SUPER_ADMIN',
  });
}

/**
 * Verify a refresh token and issue a fresh session accessToken + rotated refreshToken.
 */
async function refreshAuthSession(db, { refreshToken } = {}) {
  const token = String(refreshToken || '').trim();
  if (!token) {
    const err = new Error('Refresh token is required');
    err.status = 401;
    err.code = 'MISSING_REFRESH_TOKEN';
    throw err;
  }

  const refreshSecret = (process.env.REFRESH_TOKEN_SECRET || process.env.JWT_SECRET || '').trim();
  if (!refreshSecret) {
    const err = new Error('Refresh token verification unavailable: server secret not configured');
    err.status = 503;
    err.code = 'JWT_NOT_CONFIGURED';
    throw err;
  }

  const decoded = verifyJwt(token, refreshSecret);
  if (!decoded || !(decoded.uid || decoded.id) || (decoded.tokenType && decoded.tokenType !== 'refresh')) {
    const err = new Error('Invalid or expired refresh token');
    err.status = 401;
    err.code = 'INVALID_REFRESH_TOKEN';
    throw err;
  }

  const uid = String(decoded.uid || decoded.id).trim();
  const decodedRole = String(decoded.role || 'CUSTOMER').toUpperCase();
  let role = decodedRole;
  let email = String(decoded.email || '').trim().toLowerCase();
  let phone = String(decoded.phone || '').trim();
  let name = String(decoded.name || 'User').trim();
  let partnerCode = decoded.technicianCode;

  if (db) {
    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      const data = userDoc.data() || {};
      if (data.isSuspended === true || String(data.status || '').toUpperCase() === 'SUSPENDED') {
        const err = new Error('Account suspended');
        err.status = 403;
        err.code = 'ACCOUNT_SUSPENDED';
        throw err;
      }
      const storedRole = String(data.role || role).toUpperCase();
      // Never elevate a CUSTOMER/TECHNICIAN refresh token into ADMIN via DB field
      if ((storedRole === 'ADMIN' || storedRole === 'SUPER_ADMIN') &&
          decodedRole !== 'ADMIN' && decodedRole !== 'SUPER_ADMIN') {
        const err = new Error('Forbidden: Privilege escalation attempt blocked');
        err.status = 403;
        err.code = 'ADMIN_AUTHORIZATION_REQUIRED';
        throw err;
      }
      role = decodedRole;
      email = String(data.email || email).trim().toLowerCase();
      phone = String(data.phone || phone).trim();
      name = String(data.fullName || data.name || name).trim();
    }
  }

  if (role === 'ADMIN' || role === 'SUPER_ADMIN') {
    const verifiedAdmin = await isGenuineAdminEmail(db, email);
    if (!verifiedAdmin) {
      const err = new Error('Admin privileges revoked or unverified');
      err.status = 403;
      err.code = 'ADMIN_AUTHORIZATION_REQUIRED';
      throw err;
    }
  }

  return buildAuthSessionResponse({
    resolvedUid: uid,
    resolvedName: name,
    finalEmail: email,
    finalPhone: phone,
    resolvedRole: role,
    partnerCode,
    message: 'Session refreshed successfully',
  });
}

module.exports = {
  requestOtp,
  verifyOtp,
  adminDirectAccess,
  refreshAuthSession,
  isGenuineAdminEmail,
  resolveCanonicalTechUid,
  resolveCanonicalCustomerUid,
  resolveTechnicianCode,
  sanitizeRole,
};
