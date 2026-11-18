/**
 * Authoritative Customer Profile & Address Service (Firebase Spark Free + Render)
 * Strict owner isolation (`req.user.uid`) and privilege-field protection.
 */

const BLOCKED_PRIVILEGE_KEYS = new Set([
  'role',
  'admin',
  'isAdmin',
  'superAdmin',
  'isSuperAdmin',
  'verifiedAdmin',
  'roles',
  'privileges',
  'permissions',
  'customClaims',
  'walletBalance',
]);

async function getCustomerProfile(db, { uid }) {
  if (!uid) {
    const err = new Error('Authenticated customer UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const [custSnap, userSnap] = await Promise.all([
    db.collection('customers').doc(uid).get(),
    db.collection('users').doc(uid).get(),
  ]);

  const custData = custSnap.exists ? custSnap.data() : {};
  const userData = userSnap.exists ? userSnap.data() : {};
  const merged = {
    id: uid,
    uid,
    customerId: uid,
    fullName: custData.fullName || custData.name || userData.fullName || userData.name || 'Customer',
    name: custData.name || custData.fullName || userData.name || userData.fullName || 'Customer',
    phone: custData.phone || userData.phone || '',
    email: custData.email || userData.email || '',
    gender: custData.gender || null,
    dateOfBirth: custData.dateOfBirth || null,
    anniversaryDate: custData.anniversaryDate || null,
    profilePhotoUrl: custData.profilePhotoUrl || null,
    role: 'CUSTOMER',
    createdAt: custData.createdAt || userData.createdAt || null,
    updatedAt: custData.updatedAt || userData.updatedAt || null,
  };

  return {
    success: true,
    data: {
      ...merged,
      user: {
        id: uid,
        uid,
        fullName: merged.fullName,
        phone: merged.phone,
        email: merged.email,
        role: 'CUSTOMER',
      },
    },
  };
}

async function updateCustomerProfile(db, { uid, body }) {
  if (!uid) {
    const err = new Error('Authenticated customer UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const input = body && typeof body === 'object' ? body : {};
  for (const key of Object.keys(input)) {
    if (BLOCKED_PRIVILEGE_KEYS.has(key)) {
      const err = new Error(`Forbidden field update: "${key}" cannot be modified by client`);
      err.status = 403;
      err.code = 'FORBIDDEN_FIELD_UPDATE';
      throw err;
    }
  }

  const nowIso = new Date().toISOString();
  const safePatch = { updatedAt: nowIso };
  const allowedFields = [
    'fullName',
    'name',
    'phone',
    'email',
    'gender',
    'dateOfBirth',
    'anniversaryDate',
    'profilePhotoUrl',
    'fcmToken',
  ];

  for (const field of allowedFields) {
    if (input[field] !== undefined) {
      safePatch[field] = input[field];
    }
  }
  if (safePatch.fullName && !safePatch.name) {
    safePatch.name = safePatch.fullName;
  } else if (safePatch.name && !safePatch.fullName) {
    safePatch.fullName = safePatch.name;
  }

  await Promise.all([
    db.collection('customers').doc(uid).set(safePatch, { merge: true }),
    db.collection('users').doc(uid).set(safePatch, { merge: true }),
  ]);

  return getCustomerProfile(db, { uid });
}

async function listCustomerAddresses(db, { uid }) {
  if (!uid) {
    const err = new Error('Authenticated customer UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const snap = await db.collection('customer_addresses').where('customerId', '==', uid).limit(50).get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  list.sort((a, b) => {
    const pDiff = (b.primary || b.isPrimary ? 1 : 0) - (a.primary || a.isPrimary ? 1 : 0);
    if (pDiff !== 0) return pDiff;
    return String(b.updatedAt || b.createdAt || '').localeCompare(String(a.updatedAt || a.createdAt || ''));
  });

  return { success: true, count: list.length, data: list, addresses: list };
}

function normalizeCoordinates(input) {
  if (input.latitude === undefined && input.longitude === undefined) {
    return null;
  }
  const lat = Number(input.latitude);
  const lng = Number(input.longitude);
  if (!Number.isFinite(lat) || lat < -90 || lat > 90 || !Number.isFinite(lng) || lng < -180 || lng > 180) {
    const err = new Error('Invalid address coordinates');
    err.status = 400;
    err.code = 'INVALID_COORDINATES';
    throw err;
  }
  return { lat, lng };
}

async function clearOtherPrimaryAddresses(db, uid, excludeId) {
  const snap = await db.collection('customer_addresses').where('customerId', '==', uid).limit(50).get();
  const batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    if (doc.id !== excludeId) {
      const d = doc.data();
      if (d.primary === true || d.isPrimary === true) {
        batch.set(doc.ref, { primary: false, isPrimary: false }, { merge: true });
        count++;
      }
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

async function createCustomerAddress(db, { uid, body }) {
  if (!uid) {
    const err = new Error('Authenticated customer UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const input = body && typeof body === 'object' ? body : {};
  const coords = normalizeCoordinates(input);
  const street = String(input.street || '').trim();
  const area = String(input.area || '').trim();
  const city = String(input.city || '').trim();
  if (!street && !area && !city && !coords) {
    const err = new Error('Address details or coordinates are required');
    err.status = 400;
    err.code = 'INVALID_ADDRESS';
    throw err;
  }

  const nowIso = new Date().toISOString();
  const addressId = `addr_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const isPrimary = input.primary === true || input.isPrimary === true;

  if (isPrimary) {
    await clearOtherPrimaryAddresses(db, uid, addressId);
  }

  const docData = {
    id: addressId,
    customerId: uid,
    houseFlat: String(input.houseFlat || ''),
    street,
    area,
    city,
    state: String(input.state || ''),
    postalCode: String(input.postalCode || ''),
    landmark: String(input.landmark || ''),
    addressType: String(input.addressType || 'HOME').toUpperCase(),
    latitude: coords ? coords.lat : null,
    longitude: coords ? coords.lng : null,
    primary: isPrimary,
    isPrimary,
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  await db.collection('customer_addresses').doc(addressId).set(docData);
  return { success: true, data: docData };
}

async function updateCustomerAddress(db, { uid, addressId, body }) {
  if (!uid) {
    const err = new Error('Authenticated customer UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }
  if (!addressId) {
    const err = new Error('Address ID is required');
    err.status = 400;
    err.code = 'MISSING_ADDRESS_ID';
    throw err;
  }

  const ref = db.collection('customer_addresses').doc(addressId);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Address not found');
    err.status = 404;
    err.code = 'ADDRESS_NOT_FOUND';
    throw err;
  }
  const existing = snap.data();
  if (existing.customerId !== uid) {
    const err = new Error('Forbidden: Cannot modify another customer\'s address');
    err.status = 403;
    err.code = 'FORBIDDEN';
    throw err;
  }

  const input = body && typeof body === 'object' ? body : {};
  const coords = normalizeCoordinates(input);
  const isPrimary = input.primary !== undefined
    ? Boolean(input.primary)
    : (input.isPrimary !== undefined ? Boolean(input.isPrimary) : Boolean(existing.primary || existing.isPrimary));

  if (isPrimary) {
    await clearOtherPrimaryAddresses(db, uid, addressId);
  }

  const nowIso = new Date().toISOString();
  const patch = {
    ...(input.houseFlat !== undefined ? { houseFlat: String(input.houseFlat) } : {}),
    ...(input.street !== undefined ? { street: String(input.street) } : {}),
    ...(input.area !== undefined ? { area: String(input.area) } : {}),
    ...(input.city !== undefined ? { city: String(input.city) } : {}),
    ...(input.state !== undefined ? { state: String(input.state) } : {}),
    ...(input.postalCode !== undefined ? { postalCode: String(input.postalCode) } : {}),
    ...(input.landmark !== undefined ? { landmark: String(input.landmark) } : {}),
    ...(input.addressType !== undefined ? { addressType: String(input.addressType).toUpperCase() } : {}),
    ...(coords ? { latitude: coords.lat, longitude: coords.lng } : {}),
    primary: isPrimary,
    isPrimary,
    updatedAt: nowIso,
  };

  await ref.set(patch, { merge: true });
  const updatedSnap = await ref.get();
  return { success: true, data: { id: addressId, ...updatedSnap.data() } };
}

async function deleteCustomerAddress(db, { uid, addressId }) {
  if (!uid) {
    const err = new Error('Authenticated customer UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }
  if (!addressId) {
    const err = new Error('Address ID is required');
    err.status = 400;
    err.code = 'MISSING_ADDRESS_ID';
    throw err;
  }

  const ref = db.collection('customer_addresses').doc(addressId);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Address not found');
    err.status = 404;
    err.code = 'ADDRESS_NOT_FOUND';
    throw err;
  }
  if (snap.data().customerId !== uid) {
    const err = new Error('Forbidden: Cannot delete another customer\'s address');
    err.status = 403;
    err.code = 'FORBIDDEN';
    throw err;
  }

  await ref.delete();
  return { success: true, addressId, message: 'Address deleted' };
}

module.exports = {
  getCustomerProfile,
  updateCustomerProfile,
  listCustomerAddresses,
  createCustomerAddress,
  updateCustomerAddress,
  deleteCustomerAddress,
};
