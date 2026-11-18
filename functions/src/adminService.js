/**
 * Monitoring-Only Admin Service (Firebase Spark Free)
 * Strictly preserves Technician Self-Accept architecture:
 * NO manual booking assignment or booking lifecycle force-override endpoints.
 */

async function getAdminDashboardOverview(db) {
  const [bkgSnap, techSnap, custSnap, catSnap, withdrawSnap] = await Promise.all([
    db.collection('bookings').limit(300).get(),
    db.collection('technician_profiles').limit(300).get(),
    db.collection('customers').limit(300).get(),
    db.collection('service_categories').limit(100).get(),
    db.collection('wallet_withdrawals').limit(200).get(),
  ]);

  const bookings = bkgSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const technicians = techSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const customers = custSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  const onlineTechs = technicians.filter((t) => t.isOnline === true && String(t.availabilityStatus || '').toUpperCase() !== 'OFFLINE').length;
  const activeBookings = bookings.filter((b) =>
    ['SEARCHING', 'PENDING', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'].includes(String(b.status || '').toUpperCase())
  ).length;
  const completedBookings = bookings.filter((b) => String(b.status || '').toUpperCase() === 'COMPLETED');
  const totalRevenue = completedBookings.reduce((sum, b) => sum + (Number(b.totalAmount ?? b.price) || 0), 0);

  return {
    success: true,
    data: {
      totalBookings: bookings.length,
      activeBookings,
      completedBookings: completedBookings.length,
      totalTechnicians: technicians.length,
      onlineTechnicians: onlineTechs,
      totalCustomers: customers.length,
      totalCategories: catSnap.size,
      pendingWithdrawals: withdrawSnap.docs.filter((d) => String(d.data()?.status || '').toUpperCase() === 'PENDING').length,
      totalRevenue,
    },
  };
}

async function listAdminBookings(db, { status } = {}) {
  const snap = await db.collection('bookings').limit(300).get();
  let list = snap.docs.map((d) => {
    const data = d.data();
    delete data.startOtp;
    delete data.endOtp;
    delete data.startOtpHash;
    delete data.endOtpHash;
    return { id: d.id, ...data };
  });
  if (status && status !== 'ALL') {
    const target = String(status).toUpperCase();
    list = list.filter((b) => String(b.status || '').toUpperCase() === target);
  }
  list.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  return { success: true, count: list.length, data: list };
}

async function listAdminTechnicians(db) {
  const snap = await db.collection('technician_profiles').limit(300).get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { success: true, count: list.length, data: list };
}

async function listAdminCustomers(db) {
  const snap = await db.collection('customers').limit(300).get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { success: true, count: list.length, data: list };
}

async function listAdminAuditLogs(db) {
  const [auditSnap, eventsSnap] = await Promise.all([
    db.collection('audit_logs').limit(100).get(),
    db.collection('booking_events').limit(100).get(),
  ]);
  const logs = [
    ...auditSnap.docs.map((d) => ({ id: d.id, source: 'audit_logs', ...d.data() })),
    ...eventsSnap.docs.map((d) => ({ id: d.id, source: 'booking_events', ...d.data() })),
  ].sort((a, b) => String(b.timestamp || b.createdAt || '').localeCompare(String(a.timestamp || a.createdAt || '')));
  return { success: true, count: logs.length, data: logs };
}

async function updateTechnicianKyc(db, { adminUid, technicianId, kycStatus, accountStatus, reason }) {
  if (!technicianId) {
    const err = new Error('Technician ID is required');
    err.status = 400;
    err.code = 'MISSING_TECHNICIAN_ID';
    throw err;
  }

  const ref = db.collection('technician_profiles').doc(technicianId);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Technician not found');
    err.status = 404;
    err.code = 'TECHNICIAN_NOT_FOUND';
    throw err;
  }

  const nowIso = new Date().toISOString();
  const patch = {
    updatedAt: nowIso,
    verifiedByAdminUid: adminUid,
  };
  if (kycStatus) {
    const rawKyc = String(kycStatus).trim().toUpperCase();
    if (rawKyc === 'ACTIVE' || rawKyc === 'APPROVED' || rawKyc === 'VERIFIED') {
      patch.kycStatus = 'VERIFIED';
      patch.accountStatus = 'ACTIVE';
      patch.isAdminApproved = true;
    } else if (rawKyc === 'SUSPENDED') {
      patch.accountStatus = 'SUSPENDED';
      patch.isAdminApproved = false;
    } else if (rawKyc === 'REJECTED') {
      patch.kycStatus = 'REJECTED';
      patch.isAdminApproved = false;
      patch.rejectionReason = String(reason || '');
    } else {
      patch.kycStatus = rawKyc;
    }
  }
  if (accountStatus) {
    const normAcc = String(accountStatus).trim().toUpperCase();
    if (normAcc === 'ACTIVE') {
      patch.accountStatus = 'ACTIVE';
      patch.status = 'Active';
    } else if (normAcc === 'SUSPENDED') {
      patch.accountStatus = 'SUSPENDED';
      patch.status = 'Suspended';
      patch.isOnline = false;
      patch.availabilityStatus = 'OFFLINE';
    } else {
      patch.accountStatus = normAcc;
    }
  }

  await ref.set(patch, { merge: true });
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_KYC_REVIEW',
    targetTechnicianUid: technicianId,
    technicianId,
    kycStatus: patch.kycStatus || snap.data().kycStatus || null,
    accountStatus: patch.accountStatus || snap.data().accountStatus || null,
    reason: reason || '',
    timestamp: nowIso,
    createdAt: nowIso,
  });

  return { success: true, technicianId, ...patch };
}

async function listAdminTechnicianDocuments(db, technicianId) {
  if (!technicianId) {
    const err = new Error('Technician ID is required');
    err.status = 400;
    err.code = 'MISSING_TECHNICIAN_ID';
    throw err;
  }
  const [docsSnap, techSnap] = await Promise.all([
    db.collection('technician_documents').where('technicianId', '==', technicianId).limit(50).get(),
    db.collection('technician_profiles').doc(technicianId).get(),
  ]);
  const docs = docsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  if (docs.length === 0 && techSnap.exists) {
    const t = techSnap.data();
    const img = t.selfieImageUrl || t.profileImageUrl;
    if (img) {
      docs.push({
        id: `selfie_${technicianId}`,
        technicianId,
        documentType: 'SELFIE',
        secureUrl: img,
        verificationStatus: t.kycStatus || 'PENDING',
      });
    }
  }
  return { success: true, count: docs.length, data: docs };
}

async function getAdminLiveDispatch(db) {
  const [bkgSnap, offerSnap, techSnap] = await Promise.all([
    db.collection('bookings').limit(200).get(),
    db.collection('dispatch_offers').limit(300).get(),
    db.collection('technician_profiles').limit(300).get(),
  ]);

  const bookings = bkgSnap.docs.map((d) => {
    const data = d.data();
    delete data.startOtp;
    delete data.endOtp;
    delete data.startOtpHash;
    delete data.endOtpHash;
    return { id: d.id, ...data };
  });
  const offers = offerSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const onlineTechnicians = techSnap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((t) => t.isOnline === true && String(t.availabilityStatus || '').toUpperCase() !== 'OFFLINE');

  return {
    success: true,
    monitoringOnly: true,
    activeBookingsCount: bookings.filter((b) =>
      ['SEARCHING', 'PENDING', 'ASSIGNED', 'ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'].includes(String(b.status || '').toUpperCase())
    ).length,
    offersCount: offers.length,
    onlineTechniciansCount: onlineTechnicians.length,
    data: {
      bookings,
      offers,
      onlineTechnicians,
    },
  };
}

async function getAdminDispatchHistory(db, bookingId) {
  if (!bookingId) {
    const err = new Error('Booking ID is required');
    err.status = 400;
    err.code = 'MISSING_BOOKING_ID';
    throw err;
  }

  const [offerSnap, eventSnap] = await Promise.all([
    db.collection('dispatch_offers').where('bookingId', '==', bookingId).limit(100).get(),
    db.collection('booking_events').where('bookingId', '==', bookingId).limit(100).get(),
  ]);

  const offers = offerSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const events = eventSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  offers.sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')));
  events.sort((a, b) => String(a.timestamp || a.createdAt || '').localeCompare(String(b.timestamp || b.createdAt || '')));

  return {
    success: true,
    bookingId,
    offers,
    events,
    data: {
      bookingId,
      offers,
      events,
    },
  };
}

async function listAdminCategories(db) {
  const snap = await db.collection('service_categories').limit(150).get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  list.sort((a, b) => (Number(a.displayOrder) || 999) - (Number(b.displayOrder) || 999));
  return { success: true, count: list.length, data: list };
}

async function createAdminCategory(db, adminUid, body) {
  const name = String(body?.name || '').trim();
  if (!name) {
    const err = new Error('Category name is required');
    err.status = 400;
    err.code = 'INVALID_CATEGORY';
    throw err;
  }
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const id = String(body?.id || (slug.startsWith('cat_') ? slug : `cat_${slug}_${Date.now().toString(36)}`));
  const nowIso = new Date().toISOString();
  const docData = {
    id,
    name,
    slug,
    iconUrl: String(body?.iconUrl || body?.imageUrl || ''),
    bannerUrl: String(body?.bannerUrl || body?.imageUrl || ''),
    imageUrl: String(body?.imageUrl || body?.iconUrl || ''),
    displayOrder: Number(body?.displayOrder) || 1,
    active: body?.active !== false && body?.isActive !== false,
    isActive: body?.active !== false && body?.isActive !== false,
    subcategories: Array.isArray(body?.subcategories) ? body.subcategories : [],
    createdAt: nowIso,
    updatedAt: nowIso,
  };
  await db.collection('service_categories').doc(id).set(docData);
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_CATEGORY_CREATED',
    categoryId: id,
    name,
    timestamp: nowIso,
    createdAt: nowIso,
  });
  return { success: true, data: docData };
}

async function updateAdminCategory(db, adminUid, id, body) {
  if (!id) {
    const err = new Error('Category ID is required');
    err.status = 400;
    err.code = 'MISSING_CATEGORY_ID';
    throw err;
  }
  const ref = db.collection('service_categories').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Category not found');
    err.status = 404;
    err.code = 'CATEGORY_NOT_FOUND';
    throw err;
  }
  const nowIso = new Date().toISOString();
  const patch = {
    updatedAt: nowIso,
    ...(body?.name !== undefined ? { name: String(body.name).trim() } : {}),
    ...(body?.iconUrl !== undefined ? { iconUrl: String(body.iconUrl) } : {}),
    ...(body?.bannerUrl !== undefined ? { bannerUrl: String(body.bannerUrl) } : {}),
    ...(body?.imageUrl !== undefined ? { imageUrl: String(body.imageUrl) } : {}),
    ...(body?.displayOrder !== undefined ? { displayOrder: Number(body.displayOrder) || 1 } : {}),
  };
  if (body?.active !== undefined || body?.isActive !== undefined) {
    const activeVal = body.active !== false && body.isActive !== false;
    patch.active = activeVal;
    patch.isActive = activeVal;
  }
  await ref.set(patch, { merge: true });
  const updated = { id, ...snap.data(), ...patch };
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_CATEGORY_UPDATED',
    categoryId: id,
    timestamp: nowIso,
    createdAt: nowIso,
  });
  return { success: true, data: updated };
}

async function deleteAdminCategory(db, adminUid, id) {
  const ref = db.collection('service_categories').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Category not found');
    err.status = 404;
    err.code = 'CATEGORY_NOT_FOUND';
    throw err;
  }
  await ref.delete();
  const nowIso = new Date().toISOString();
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_CATEGORY_DELETED',
    categoryId: id,
    timestamp: nowIso,
    createdAt: nowIso,
  });
  return { success: true, id };
}

async function syncServiceIntoCategory(db, serviceDoc, remove = false) {
  const categoryId = serviceDoc?.categoryId;
  if (!categoryId) return;
  const catRef = db.collection('service_categories').doc(categoryId);
  const catSnap = await catRef.get();
  if (!catSnap.exists) return;

  const catData = catSnap.data();
  const subcategories = Array.isArray(catData.subcategories) ? [...catData.subcategories] : [];
  if (subcategories.length === 0 && !remove) {
    subcategories.push({
      id: `${categoryId}_general`,
      name: `${catData.name || 'General'} Services`,
      services: [serviceDoc],
    });
  } else {
    let found = false;
    for (const sub of subcategories) {
      if (!Array.isArray(sub.services)) sub.services = [];
      const idx = sub.services.findIndex((s) => s && s.id === serviceDoc.id);
      if (idx >= 0) {
        found = true;
        if (remove) {
          sub.services.splice(idx, 1);
        } else {
          sub.services[idx] = { ...sub.services[idx], ...serviceDoc };
        }
      }
    }
    if (!found && !remove && subcategories.length > 0) {
      subcategories[0].services.push(serviceDoc);
    }
  }
  await catRef.set({ subcategories, updatedAt: new Date().toISOString() }, { merge: true });
}

async function listAdminServices(db) {
  const snap = await db.collection('services').limit(300).get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  list.sort((a, b) => (Number(a.displayOrder) || 999) - (Number(b.displayOrder) || 999));
  return { success: true, count: list.length, data: list };
}

async function createAdminService(db, adminUid, body) {
  const name = String(body?.name || '').trim();
  const price = Number(body?.price ?? body?.offerPrice ?? body?.basePrice);
  if (!name || !Number.isFinite(price) || price <= 0) {
    const err = new Error('Valid service name and positive price are required');
    err.status = 400;
    err.code = 'INVALID_SERVICE_PAYLOAD';
    throw err;
  }

  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const id = String(body?.id || `srv_${slug}_${Date.now().toString(36)}`);
  const nowIso = new Date().toISOString();
  const activeVal = body?.isActive !== false && body?.active !== false;

  const docData = {
    id,
    name,
    categoryId: String(body?.categoryId || 'cat_general'),
    subcategoryId: String(body?.subcategoryId || `${body?.categoryId || 'cat_general'}_general`),
    category: String(body?.category || body?.categoryName || 'Home Services'),
    categoryName: String(body?.categoryName || body?.category || 'Home Services'),
    description: String(body?.description || ''),
    imageUrl: String(body?.imageUrl || ''),
    price,
    basePrice: Number(body?.basePrice) || price,
    offerPrice: Number(body?.offerPrice) || price,
    discountPrice: Number(body?.discountPrice) || price,
    displayOrder: Number(body?.displayOrder) || 1,
    durationMinutes: Number(body?.durationMinutes) || 45,
    warrantyText: String(body?.warrantyText || '30 Days Warranty'),
    technicianPayoutAmount: Number(body?.technicianPayoutAmount) || Math.round(price * 0.8),
    isActive: activeVal,
    active: activeVal,
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  await db.collection('services').doc(id).set(docData);
  await syncServiceIntoCategory(db, docData, false);
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_SERVICE_CREATED',
    serviceId: id,
    name,
    timestamp: nowIso,
    createdAt: nowIso,
  });

  return { success: true, data: docData };
}

async function updateAdminService(db, adminUid, id, body) {
  if (!id) {
    const err = new Error('Service ID is required');
    err.status = 400;
    err.code = 'MISSING_SERVICE_ID';
    throw err;
  }
  const ref = db.collection('services').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Service not found');
    err.status = 404;
    err.code = 'SERVICE_NOT_FOUND';
    throw err;
  }

  const nowIso = new Date().toISOString();
  const patch = { updatedAt: nowIso };
  const stringFields = ['name', 'categoryId', 'subcategoryId', 'category', 'categoryName', 'description', 'imageUrl', 'warrantyText'];
  for (const f of stringFields) {
    if (body?.[f] !== undefined) patch[f] = String(body[f]);
  }
  const numFields = ['price', 'basePrice', 'offerPrice', 'discountPrice', 'displayOrder', 'bookingCharge', 'advancePrepaymentPct', 'technicianPayoutAmount', 'durationMinutes'];
  for (const f of numFields) {
    if (body?.[f] !== undefined && Number.isFinite(Number(body[f]))) patch[f] = Number(body[f]);
  }
  if (body?.active !== undefined || body?.isActive !== undefined) {
    const activeVal = body.active !== false && body.isActive !== false;
    patch.active = activeVal;
    patch.isActive = activeVal;
  }

  await ref.set(patch, { merge: true });
  const updated = { id, ...snap.data(), ...patch };
  await syncServiceIntoCategory(db, updated, false);
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_SERVICE_UPDATED',
    serviceId: id,
    timestamp: nowIso,
    createdAt: nowIso,
  });

  return { success: true, data: updated };
}

async function deleteAdminService(db, adminUid, id) {
  const ref = db.collection('services').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('Service not found');
    err.status = 404;
    err.code = 'SERVICE_NOT_FOUND';
    throw err;
  }
  const existing = { id, ...snap.data() };
  await ref.delete();
  await syncServiceIntoCategory(db, existing, true);
  const nowIso = new Date().toISOString();
  await db.collection('audit_logs').doc().set({
    actorUid: adminUid,
    action: 'ADMIN_SERVICE_DELETED',
    serviceId: id,
    timestamp: nowIso,
    createdAt: nowIso,
  });
  return { success: true, id };
}

module.exports = {
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
};
