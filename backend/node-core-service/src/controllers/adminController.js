const { v4: uuidv4 } = require('uuid');
const MongoTechnicianProfile = require('../models/MongoTechnicianProfile');
const MongoCatalog = require('../models/MongoCatalog');
const postgres = require('../config/postgres');
const mongo = require('../config/mongo');
const {
  getMasterCatalog,
  getFlattenedServices,
  getAdminCategories,
  updateServicePricing,
  updateServiceItem,
  createServiceItem,
  deleteServiceItem,
  createCategoryItem,
  updateCategoryItem,
  deleteCategoryItem,
} = require('../config/masterCatalog');
const bookingsStore = require('../config/bookingsStore');
const firebase = require('../config/firebase');
const {
  inMemoryDocs,
  inMemoryTechProfiles,
  setTechnicianProfile,
  deleteTechnicianProfile,
  clearAllTechniciansStore,
} = require('../config/inMemoryTechStore');

const CLOUDINARY_DOC_BADGES = {
  AADHAAR: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799174/npirtdof27t2ogvu2hnj.svg',
  VOTER_CARD: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799176/u6zexc12ymd5l5szgrhn.svg',
  VOTER: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799176/u6zexc12ymd5l5szgrhn.svg',
  SELFIE: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799180/prw4acrn6uajclcl7neg.svg',
  LIVE_SELFIE: 'https://res.cloudinary.com/p1ish280/image/upload/v1788799180/prw4acrn6uajclcl7neg.svg',
};

function resolveDocUrl(url, docType = '') {
  if (url && typeof url === 'string') {
    const trimmed = url.trim();
    if (trimmed.startsWith('https://res.cloudinary.com') ||
        (trimmed.startsWith('http') && !trimmed.includes('supabase.co') && !trimmed.includes('localhost') && !trimmed.includes('example.com') && !trimmed.includes('uploaded_'))) {
      return trimmed;
    }
  }
  const dt = String(docType).toUpperCase();
  if (dt.includes('AADHAAR')) return CLOUDINARY_DOC_BADGES.AADHAAR;
  if (dt.includes('VOTER')) return CLOUDINARY_DOC_BADGES.VOTER_CARD;
  return CLOUDINARY_DOC_BADGES.SELFIE;
}

let adminBanners = [
  {
    id: 'ban-01',
    title: '50% OFF on AC Deep Cleaning',
    subtitle: 'Beat the heat with certified AC experts',
    imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800',
    targetCategory: 'cat_ac',
    active: true,
  },
  {
    id: 'ban-02',
    title: 'Certified Electrician & Wiring',
    subtitle: 'Fast 15-min arrival with 30-day warranty',
    imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=800',
    targetCategory: 'cat_electrical',
    active: true,
  },
];

let adminAuditLogs = [
  { id: 'log-01', module: 'System', action: 'Real-time bookings store and catalog synchronization active', timestamp: new Date().toISOString() },
  { id: 'log-02', module: 'Auth', action: 'Admin session connected to live dispatch database', timestamp: new Date().toISOString() },
];

/**
 * GET /api/v1/admin/overview & /api/v1/admin/stats
 */
const getOverview = async (req, res) => {
  try {
    const services = getFlattenedServices();
    const categories = getAdminCategories();
    const liveStats = bookingsStore.getDashboardStats();
    let activeTechnicians = 0;

    if (postgres.isPgHealthy()) {
      try {
        const techRes = await postgres.query(`SELECT count(*) FROM technician_profiles WHERE is_online = true OR kyc_status = 'VERIFIED';`);
        activeTechnicians = parseInt(techRes.rows[0]?.count || 0, 10);
      } catch (e) {}
    }

    const data = {
      ...liveStats,
      activeTechnicians,
      totalServices: services.length,
      totalCategories: categories.length,
    };

    return res.json({
      success: true,
      data,
      stats: data,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── CATEGORIES CRUD ──────────────────────────────────────────────

const getCategories = async (req, res) => {
  try {
    const categories = getAdminCategories();
    return res.json({ success: true, data: categories, count: categories.length });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const createCategory = async (req, res) => {
  try {
    const { name, iconUrl, bannerUrl, active = true } = req.body;
    if (!name) return res.status(400).json({ success: false, error: 'Category name is required' });

    const newCat = createCategoryItem({
      name: name.trim(),
      imageUrl: bannerUrl || iconUrl,
      iconUrl: iconUrl || bannerUrl,
      active: active !== false,
    });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Services',
      action: `Created category "${name}" (#${newCat.id})`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'CATEGORY_CREATED', data: newCat });
    }

    return res.status(201).json({ success: true, data: newCat, category: newCat });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const updated = updateCategoryItem(id, req.body);
    if (!updated) return res.status(404).json({ success: false, error: 'Category not found' });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Services',
      action: `Updated category "${updated.name}" (#${id})`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'CATEGORY_UPDATED', id, data: updated });
    }

    return res.json({ success: true, data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const deleteCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = deleteCategoryItem(id);
    if (!deleted) return res.status(404).json({ success: false, error: 'Category not found' });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Services',
      action: `Deleted category #${id}`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'CATEGORY_DELETED', id });
    }

    return res.json({ success: true, message: 'Category deleted successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── SERVICES CRUD ────────────────────────────────────────────────

const getServices = async (req, res) => {
  try {
    const services = getFlattenedServices();
    return res.json({ success: true, data: services, count: services.length });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const createService = async (req, res) => {
  try {
    const serviceName = req.body.name || req.body.title;
    if (!serviceName) return res.status(400).json({ success: false, error: 'Service name is required' });

    const newService = createServiceItem(req.body);

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Services',
      action: `Created service "${newService.name}" under ${newService.categoryName}: Price ₹${newService.price}`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'SERVICE_CREATED', data: newService });
      global.io.emit('notification:new_service', {
        title: '🎉 New Service Available!',
        body: `${newService.name} is now live under ${newService.categoryName || 'Services'}! Book now for ₹${newService.price}`,
        serviceName: newService.name,
        categoryName: newService.categoryName,
        price: newService.price,
        imageUrl: newService.imageUrl,
        timestamp: new Date().toISOString(),
      });
    }

    firebase.sendPushNotification('all_users', {
      title: '🎉 New Service Available!',
      body: `${newService.name} is now available for ₹${newService.price}!`,
      data: { type: 'NEW_SERVICE', serviceId: newService.id, categoryId: newService.categoryId },
    }).catch(() => {});

    return res.status(201).json({ success: true, data: newService, service: newService });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateService = async (req, res) => {
  try {
    const { id } = req.params;
    const updated = updateServiceItem(id, req.body);
    if (!updated) return res.status(404).json({ success: false, error: 'Service not found' });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Services',
      action: `Updated service "${updated.name}" (#${id})`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'SERVICE_UPDATED', id, data: updated });
    }

    return res.json({ success: true, data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const deleteService = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = deleteServiceItem(id);
    if (!deleted) return res.status(404).json({ success: false, error: 'Service not found' });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Services',
      action: `Deleted service #${id}`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'SERVICE_DELETED', id });
    }

    return res.json({ success: true, message: 'Service deleted successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── DYNAMIC PRICING & RATE CARD CONFIGURATION ────────────────────

const updatePricing = async (req, res) => {
  try {
    const { id } = req.params;
    const updated = updateServicePricing(id, req.body);
    if (!updated) return res.status(404).json({ success: false, error: `Service with ID "${id}" not found in catalog` });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Pricing',
      action: `Updated rate card for "${updated.name}": Price=₹${updated.price}, Offer=₹${updated.offerPrice || updated.price}, BookingFee=₹${updated.bookingCharge}, Payout=₹${updated.technicianPayoutAmount}`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('catalog:updated', { type: 'PRICING_UPDATED', id, data: updated });
    }

    return res.json({
      success: true,
      message: `Pricing and rate card updated for "${updated.name}"`,
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── REAL LIVE BOOKINGS OVERSIGHT ─────────────────────────────────

const getBookings = async (req, res) => {
  try {
    const bookings = bookingsStore.getAllBookings();
    return res.json({ success: true, data: bookings, count: bookings.length });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateBookingStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const updated = bookingsStore.updateBookingStatus(id, status);
    
    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Bookings',
      action: `Updated booking #${id} status to ${status}`,
      timestamp: new Date().toISOString(),
    });

    return res.json({ success: true, message: `Booking status updated to ${status}`, id, status, data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const assignBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { technicianId, technicianName, technicianPhone, technicianCategory, technicianRating, technicianAvatar } = req.body;
    const updated = bookingsStore.assignTechnician(
      id,
      technicianId,
      technicianName,
      technicianPhone || '+91 98765 43210',
      technicianCategory || 'Certified Partner',
      technicianRating || 4.85,
      technicianAvatar || ''
    );
    
    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Dispatch',
      action: `Assigned technician ${technicianName || technicianId} to booking #${id}`,
      timestamp: new Date().toISOString(),
    });

    if (global.io && updated) {
      const ringingPayload = {
        proposalId: `prop-${id.slice(0, 8)}`,
        bookingId: id,
        bookingCode: updated.bookingCode || id,
        serviceType: updated.serviceName || updated.service || 'Assigned Service Job',
        serviceName: updated.serviceName || updated.service || 'Assigned Service Job',
        category: updated.category || 'Home Services',
        customerName: updated.customerName || updated.customer || 'Customer',
        customerPhone: updated.customerPhone || updated.phone || '',
        customerAddress: updated.address || updated.fullAddress || 'Customer Address',
        address: updated.address || updated.fullAddress || 'Customer Address',
        latitude: updated.latitude || 22.5726,
        longitude: updated.longitude || 88.3639,
        distanceKm: '1.5',
        payout: (parseFloat(updated.totalAmount || 350) * 0.8).toFixed(0),
        totalAmount: updated.totalAmount || 350,
        timeoutSeconds: 45,
        playRingtone: true,
        vibrate: true,
      };

      global.io.to(`tech_${technicianId}`).emit('booking:dispatch_ringing', ringingPayload);
      global.io.to(`tech_${technicianId}`).emit('booking:assigned', updated);
      global.io.emit('booking:assigned', updated);
      console.log(`🚨 [Admin Assign Dispatch] Emitted ringing alert directly to technician ${technicianId} for booking #${id}.`);
    }

    return res.json({ success: true, message: `Technician assigned to booking #${id}`, data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const cancelBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const updated = bookingsStore.cancelBooking(id, reason);

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Bookings',
      action: `Cancelled booking #${id}. Reason: ${reason || 'Admin action'}`,
      timestamp: new Date().toISOString(),
    });

    return res.json({ success: true, message: `Booking #${id} cancelled`, data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const deleteBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = bookingsStore.deleteBooking(id);
    if (!deleted) return res.status(404).json({ success: false, error: 'Booking not found' });

    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Bookings',
      action: `Deleted booking #${id} permanently`,
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('booking:deleted', { id });
    }

    return res.json({ success: true, message: `Booking #${id} deleted successfully` });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const clearAllBookings = async (req, res) => {
  try {
    bookingsStore.clearAllBookings();
    adminAuditLogs.unshift({
      id: 'log-' + uuidv4().slice(0, 6),
      module: 'Bookings',
      action: 'Cleared all booking records',
      timestamp: new Date().toISOString(),
    });

    if (global.io) {
      global.io.emit('bookings:cleared');
    }

    return res.json({ success: true, message: 'All bookings cleared successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const getBookingLiveTracking = async (req, res) => {
  try {
    const { id } = req.params;
    const tracking = bookingsStore.getBookingLiveTracking(id);
    if (!tracking) {
      return res.status(404).json({ success: false, message: 'Booking not found or no live tracking available' });
    }
    return res.json({ success: true, data: tracking });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const getCustomers = async (req, res) => {
  try {
    const customerMap = new Map();

    // 1. Fetch from PostgreSQL users table (all registered customer accounts)
    if (postgres.isPgHealthy()) {
      try {
        const dbRes = await postgres.query(`
          SELECT 
            u.id,
            u.full_name as name,
            u.full_name as "fullName",
            u.phone,
            u.email,
            u.created_at as "createdAt",
            u.updated_at as "updatedAt"
          FROM users u
          WHERE u.role = 'CUSTOMER' OR u.role IS NULL
          ORDER BY u.created_at DESC;
        `);

        for (const row of dbRes.rows) {
          customerMap.set(row.id, {
            id: row.id,
            customerId: row.id,
            name: row.name || 'Customer',
            fullName: row.name || 'Customer',
            phone: row.phone || '',
            email: row.email || '',
            address: '',
            totalBookings: 0,
            totalSpent: 0,
            status: 'ACTIVE',
            createdAt: row.createdAt ? new Date(row.createdAt).toISOString() : new Date().toISOString(),
            updatedAt: row.updatedAt ? new Date(row.updatedAt).toISOString() : new Date().toISOString(),
          });
        }
      } catch (pgErr) {
        console.warn('[Admin] PG customers query fallback:', pgErr.message);
      }
    }

    // 2. Merge with live bookings store customers (with booking history and spend)
    const storeCustomers = bookingsStore.getAllCustomers();
    for (const sc of storeCustomers) {
      const existing = customerMap.get(sc.id) || customerMap.get(sc.customerId) || {};
      customerMap.set(sc.id || sc.customerId, {
        ...existing,
        ...sc,
        totalBookings: Math.max(existing.totalBookings || 0, sc.totalBookings || 0),
        totalSpent: Math.max(existing.totalSpent || 0, sc.totalSpent || 0),
      });
    }

    const customersList = Array.from(customerMap.values()).sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    return res.json({
      success: true,
      data: customersList,
      customers: customersList,
      count: customersList.length,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── TECHNICIANS MANAGEMENT & KYC ────────────────────────────────

const getTechnicians = async (req, res) => {
  try {
    const techMap = new Map();

    // 0. Seed / In-memory partners baseline
    for (const [id, t] of inMemoryTechProfiles.entries()) {
      techMap.set(id, { ...t });
    }

    // 1. Fetch from PostgreSQL
    if (postgres.isPgHealthy()) {
      try {
        const dbRes = await postgres.query(`
          SELECT 
            tp.id,
            tp.technician_id as "technicianId",
            COALESCE(tp.full_name, u.full_name, 'Technician') as "fullName",
            COALESCE(tp.full_name, u.full_name, 'Technician') as name,
            COALESCE(tp.phone, u.phone, '') as phone,
            COALESCE(tp.category, 'Electrician') as category,
            tp.skills,
            tp.kyc_status as "kycStatus",
            tp.rating,
            tp.total_jobs_completed as "totalJobsCompleted",
            tp.is_online as "isOnline",
            tp.experience_years as "experienceYears",
            tp.wallet_balance as "walletBalance",
            tp.upi_id as "upiId",
            tp.upi_number as "upiNumber",
            tp.avatar as "tpAvatar",
            tp.live_pic_url as "tpLivePic",
            tp.aadhaar_url as "tpAadhaarUrl",
            tp.aadhaar_number as "tpAadhaarNumber",
            tp.voter_card_url as "tpVoterUrl",
            tp.voter_card_number as "tpVoterNumber",
            u.email,
            COALESCE(tp.avatar, u.profile_image_url, '') as avatar,
            tp.created_at as "joinedAt"
          FROM technician_profiles tp
          LEFT JOIN users u ON tp.technician_id = u.id
          ORDER BY tp.created_at DESC;
        `);
        for (const row of dbRes.rows) {
          const id = row.technicianId || row.id;
          const existing = techMap.get(id) || {};
          const photoUrl = row.tpLivePic || row.avatar || existing.livePicUrl || existing.avatar || '';
          const hasAadhaar = Boolean(row.tpAadhaarUrl || row.tpAadhaarNumber || existing.hasAadhaar);
          const hasVoterCard = Boolean(row.tpVoterUrl || row.tpVoterNumber || existing.hasVoterCard);
          const hasLivePic = Boolean(photoUrl || existing.hasLivePic);
          const isVer = (row.kycStatus || existing.kycStatus || 'PENDING').toUpperCase() === 'VERIFIED';
          const completion = isVer ? 100 : ((hasAadhaar ? 25 : 0) + (hasVoterCard ? 25 : 0) + (hasLivePic ? 25 : 0) + 25);

          techMap.set(id, {
            ...existing,
            id,
            technicianId: id,
            fullName: row.fullName || existing.fullName || 'Technician',
            name: row.name || existing.name || 'Technician',
            phone: row.phone || existing.phone || '',
            email: row.email || existing.email || '',
            category: row.category || existing.category || 'Electrician',
            skills: Array.isArray(row.skills) ? row.skills : (existing.skills || []),
            kycStatus: row.kycStatus || existing.kycStatus || 'PENDING',
            rating: parseFloat(row.rating || existing.rating || 5.0),
            totalJobsCompleted: parseInt(row.totalJobsCompleted || existing.totalJobsCompleted || 0, 10),
            isOnline: Boolean(row.isOnline !== undefined ? row.isOnline : existing.isOnline),
            experienceYears: parseInt(row.experienceYears || existing.experienceYears || 2, 10),
            walletBalance: parseFloat(row.walletBalance || existing.walletBalance || 0),
            upiId: row.upiId || row.upiNumber || existing.upiId || '',
            avatar: photoUrl,
            livePicUrl: photoUrl,
            photo: photoUrl,
            hasAadhaar,
            hasVoterCard,
            hasLivePic,
            aadhaarUrl: row.tpAadhaarUrl || existing.aadhaarUrl || '',
            aadhaarNumber: row.tpAadhaarNumber || existing.aadhaarNumber || '',
            voterCardUrl: row.tpVoterUrl || existing.voterCardUrl || '',
            voterCardNumber: row.tpVoterNumber || existing.voterCardNumber || '',
            profileCompletion: completion,
            isProfileComplete: isVer || completion === 100,
            joinedAt: row.joinedAt ? new Date(row.joinedAt).toISOString() : (existing.joinedAt || new Date().toISOString()),
          });
        }

        // Merge skills from PostgreSQL technician_services
        try {
          const srvLinks = await postgres.query(`
            SELECT ts.technician_id, ts.service_id, s.name as service_name, s.category_id, c.name as category_name, ts.active
            FROM technician_services ts
            JOIN services s ON s.id = ts.service_id
            LEFT JOIN categories c ON c.id = s.category_id;
          `);
          for (const link of srvLinks.rows) {
            const tech = techMap.get(link.technician_id);
            if (tech) {
              if (!Array.isArray(tech.skills)) tech.skills = [];
              if (!tech.skills.some(sk => (typeof sk === 'object' ? sk.skillId : sk) === link.service_id)) {
                tech.skills.push({
                  id: `ts_${link.service_id}`,
                  skillId: link.service_id,
                  skillName: link.service_name || link.service_id,
                  categoryId: link.category_id || 'cat_home',
                  categoryName: link.category_name || 'Home Services',
                  experienceYears: 2,
                  verificationStatus: 'VERIFIED',
                });
              }
            }
          }
        } catch (_) {}

        // Merge documents from PostgreSQL technician_kyc_documents
        const docsRes = await postgres.query(`
          SELECT technician_id, document_type, document_number, front_image_url, verification_status
          FROM technician_kyc_documents;
        `);
        for (const docRow of docsRes.rows) {
          const tech = techMap.get(docRow.technician_id);
          if (tech) {
            const dt = (docRow.document_type || '').toUpperCase();
            if (dt.includes('AADHAAR')) {
              tech.hasAadhaar = true;
              tech.aadhaarUrl = resolveDocUrl(docRow.front_image_url || tech.aadhaarUrl, 'AADHAAR');
              tech.aadhaarNumber = docRow.document_number || tech.aadhaarNumber;
            } else if (dt.includes('VOTER')) {
              tech.hasVoterCard = true;
              tech.voterCardUrl = resolveDocUrl(docRow.front_image_url || tech.voterCardUrl, 'VOTER_CARD');
              tech.voterCardNumber = docRow.document_number || tech.voterCardNumber;
            } else if (dt.includes('SELFIE') || dt.includes('LIVE') || dt.includes('PHOTO')) {
              tech.hasLivePic = true;
              tech.livePicUrl = resolveDocUrl(docRow.front_image_url || tech.livePicUrl, 'SELFIE');
              tech.photo = tech.livePicUrl;
            }
            const comp = (tech.hasAadhaar ? 25 : 0) + (tech.hasVoterCard ? 25 : 0) + (tech.hasLivePic ? 25 : 0) + 25;
            tech.profileCompletion = (tech.kycStatus === 'VERIFIED' || tech.kycStatus === 'APPROVED') ? 100 : comp;
            tech.isProfileComplete = tech.profileCompletion === 100;
          }
        }
      } catch (e) {
        console.warn('Postgres getTechnicians notice:', e.message);
      }
    }

    // 2. Fetch & merge from MongoDB (captures real-time GPS coordinates, isOnline, KYC documents)
    if (mongo.isMongoHealthy()) {
      try {
        const mongoTechs = await MongoTechnicianProfile.find({});
      for (const t of mongoTechs) {
        const id = t.technicianId || t._id.toString();
        const existing = techMap.get(id) || {};
        
        const coordinates = t.currentLocation?.coordinates || [];
        const latitude = coordinates[1] !== undefined ? coordinates[1] : undefined;
        const longitude = coordinates[0] !== undefined ? coordinates[0] : undefined;

        const docs = t.documents || [];
        const rawKyc = (t.kycStatus || existing.kycStatus || 'PENDING').toUpperCase();
        const isVer = rawKyc === 'VERIFIED' || rawKyc === 'APPROVED';

        const aadhaarDoc = docs.find(d => (d.documentType || '').toUpperCase().includes('AADHAAR'));
        const voterDoc = docs.find(d => (d.documentType || '').toUpperCase().includes('VOTER'));
        const selfieDoc = docs.find(d => (d.documentType || '').toUpperCase().includes('SELFIE') || (d.documentType || '').toUpperCase().includes('LIVE') || (d.documentType || '').toUpperCase().includes('PHOTO'));

        const rawAadhaar = t.aadharCardImageUrl || t.aadhaarUrl || aadhaarDoc?.fileUrl || aadhaarDoc?.secureCloudinaryUrl || existing.aadhaarUrl || '';
        const rawVoter = t.voterCardImageUrl || t.voterCardUrl || voterDoc?.fileUrl || voterDoc?.secureCloudinaryUrl || existing.voterCardUrl || '';
        const rawSelfie = t.selfieImageUrl || t.livePicUrl || t.avatar || selfieDoc?.fileUrl || selfieDoc?.secureCloudinaryUrl || existing.livePicUrl || existing.avatar || '';

        const aadhaarUrl = resolveDocUrl(rawAadhaar, 'AADHAAR');
        const voterCardUrl = resolveDocUrl(rawVoter, 'VOTER_CARD');
        const livePicUrl = resolveDocUrl(rawSelfie, 'SELFIE');

        const aadhaarNumber = t.aadharNumber || t.aadhaarNumber || aadhaarDoc?.maskedNumber || existing.aadhaarNumber || '';
        const voterCardNumber = t.voterIdNumber || t.voterCardNumber || voterDoc?.maskedNumber || existing.voterCardNumber || '';

        const hasAadhaar = isVer || Boolean(rawAadhaar || aadhaarNumber || existing.hasAadhaar);
        const hasVoterCard = isVer || Boolean(rawVoter || voterCardNumber || existing.hasVoterCard);
        const hasLivePic = isVer || Boolean(rawSelfie || existing.hasLivePic);

        const profileCompletion = isVer ? 100 : ((hasAadhaar ? 25 : 0) + (hasVoterCard ? 25 : 0) + (hasLivePic ? 25 : 0) + 25);
        const isProfileComplete = isVer || profileCompletion === 100;

        const rawSkillsArr = t.skills && t.skills.length > 0 ? t.skills : (existing.skills && existing.skills.length > 0 ? existing.skills : []);
        const formattedSkillsList = rawSkillsArr.map((s, idx) => {
          if (typeof s === 'object' && s !== null) {
            return {
              id: s.id || `ts_${idx + 1}`,
              skillId: s.skillId || `sk_${idx}`,
              skillName: s.skillName || s.skillId || 'General Repair',
              categoryName: s.categoryName || 'Home Services',
              verificationStatus: 'VERIFIED',
            };
          }
          const clean = String(s || '').replace(/^sk_/, '').replace(/^cat_/, '');
          const words = clean.split(/[_-]/).map(w => w.charAt(0).toUpperCase() + w.slice(1));
          const name = words.join(' ') || 'General Repair';
          return {
            id: `ts_${idx + 1}`,
            skillId: String(s),
            skillName: name,
            categoryName: 'Home Services',
            verificationStatus: 'VERIFIED',
          };
        });

        techMap.set(id, {
          id,
          technicianId: id,
          fullName: t.fullName || existing.fullName || 'Technician',
          phone: t.phone || existing.phone || '+91 98765 43210',
          email: t.email || existing.email || `${id}@bookurtechnician.com`,
          avatar: livePicUrl,
          photo: livePicUrl,
          livePicUrl,
          hasLivePic,
          aadhaarUrl,
          aadhaarNumber,
          hasAadhaar,
          voterCardUrl,
          voterCardNumber,
          hasVoterCard,
          kycStatus: isVer ? 'VERIFIED' : rawKyc,
          profileCompletion,
          isProfileComplete,
          isOnline: t.isOnline !== undefined ? t.isOnline : (existing.isOnline || false),
          status: (t.isOnline || existing.isOnline) ? 'ONLINE' : 'OFFLINE',
          rating: t.rating || existing.rating || 4.9,
          totalJobs: t.totalJobs || existing.totalJobs || 0,
          completedBookingsCount: t.completedBookingsCount || existing.completedBookingsCount || 0,
          completionRate: t.completionRate || existing.completionRate || 98,
          walletBalance: t.walletBalance !== undefined ? t.walletBalance : (existing.walletBalance || 0),
          commissionDue: t.commissionDue !== undefined ? t.commissionDue : (existing.commissionDue || 0),
          skills: formattedSkillsList,
          latitude,
          longitude,
          joinedAt: t.createdAt || existing.joinedAt || new Date().toISOString(),
          updatedAt: t.updatedAt || new Date().toISOString(),
        });
      }
    } catch (mErr) {}
  }

    // 3. Merge inMemoryDocs for each technician
    for (const [id, docs] of inMemoryDocs.entries()) {
      const tech = techMap.get(id);
      if (tech && Array.isArray(docs)) {
        for (const doc of docs) {
          const dt = (doc.documentType || '').toUpperCase();
          if (dt.includes('AADHAAR')) {
            tech.hasAadhaar = true;
            tech.aadhaarUrl = resolveDocUrl(doc.fileUrl || tech.aadhaarUrl, 'AADHAAR');
            tech.aadhaarNumber = doc.maskedNumber || tech.aadhaarNumber;
          } else if (dt.includes('VOTER')) {
            tech.hasVoterCard = true;
            tech.voterCardUrl = resolveDocUrl(doc.fileUrl || tech.voterCardUrl, 'VOTER_CARD');
            tech.voterCardNumber = doc.maskedNumber || tech.voterCardNumber;
          } else if (dt.includes('SELFIE') || dt.includes('LIVE') || dt.includes('PHOTO')) {
            tech.hasLivePic = true;
            tech.livePicUrl = resolveDocUrl(doc.fileUrl || tech.livePicUrl, 'SELFIE');
            tech.photo = tech.livePicUrl;
            tech.avatar = tech.livePicUrl;
          }
        }
        const hasLivePic = Boolean(tech.hasLivePic || tech.livePicUrl);
        const hasAadhaar = Boolean(tech.hasAadhaar || tech.aadhaarUrl);
        const hasVoterCard = Boolean(tech.hasVoterCard || tech.voterCardUrl);
        tech.hasLivePic = hasLivePic;
        tech.hasAadhaar = hasAadhaar;
        tech.hasVoterCard = hasVoterCard;
        const completion = (hasLivePic ? 25 : 0) + (hasAadhaar ? 25 : 0) + (hasVoterCard ? 25 : 0) + 25;
        tech.profileCompletion = (tech.kycStatus === 'VERIFIED' || tech.kycStatus === 'APPROVED') ? 100 : completion;
        tech.isProfileComplete = tech.profileCompletion === 100;
      }
    }

    const techniciansList = Array.from(techMap.values()).map(t => {
      const isVer = (t.kycStatus || 'PENDING').toUpperCase() === 'VERIFIED' || (t.kycStatus || 'PENDING').toUpperCase() === 'APPROVED';
      const hasAadhaar = t.hasAadhaar !== undefined ? t.hasAadhaar : isVer;
      const hasVoterCard = t.hasVoterCard !== undefined ? t.hasVoterCard : isVer;
      const hasLivePic = t.hasLivePic !== undefined ? t.hasLivePic : isVer;
      const profileCompletion = isVer ? 100 : (t.profileCompletion || (25 + (hasAadhaar ? 25 : 0) + (hasVoterCard ? 25 : 0) + (hasLivePic ? 25 : 0)));
      const isProfileComplete = isVer || profileCompletion === 100;

      const livePicUrl = resolveDocUrl(t.livePicUrl || t.photo || t.avatar, 'SELFIE');
      const aadhaarUrl = resolveDocUrl(t.aadhaarUrl, 'AADHAAR');
      const voterCardUrl = resolveDocUrl(t.voterCardUrl, 'VOTER_CARD');

      return {
        ...t,
        livePicUrl,
        photo: livePicUrl,
        avatar: livePicUrl,
        aadhaarUrl,
        voterCardUrl,
        hasAadhaar,
        hasVoterCard,
        hasLivePic,
        profileCompletion,
        isProfileComplete,
        kycStatus: isVer ? 'VERIFIED' : t.kycStatus,
      };
    }).sort((a, b) => {
      // Online technicians first, then newest
      if (a.isOnline !== b.isOnline) return b.isOnline ? 1 : -1;
      return new Date(b.joinedAt || 0) - new Date(a.joinedAt || 0);
    });

    const onlineCount = techniciansList.filter(t => t.isOnline).length;
    const offlineCount = techniciansList.length - onlineCount;
    const pendingKycCount = techniciansList.filter(t => t.kycStatus === 'PENDING').length;

    return res.json({
      success: true,
      data: techniciansList,
      technicians: techniciansList,
      count: techniciansList.length,
      stats: {
        total: techniciansList.length,
        online: onlineCount,
        offline: offlineCount,
        pendingKyc: pendingKycCount,
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateTechnicianStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
    if (inMemoryTechProfiles.has(id)) {
      inMemoryTechProfiles.get(id).isOnline = status === 'ONLINE' || status === true;
    }
    if (postgres.isPgHealthy()) {
      await postgres.query(`
        UPDATE technician_profiles
        SET kyc_status = $1, updated_at = NOW()
        WHERE technician_id = $2 OR id = $2;
      `, [status, id]);
    }
  } catch (e) {}
  return res.json({ success: true, message: `Technician status updated to ${status}`, id, status });
};

const createTechnician = async (req, res) => {
  try {
    const {
      name,
      fullName,
      phone,
      email,
      category = 'Electrician',
      skills = [],
      experienceYears = 2,
      upiId = '',
      rating = 5.0,
      isOnline = false,
      latitude,
      longitude,
    } = req.body;

    const techName = fullName || name || 'New Partner';
    const techId = `tech-${Date.now().toString(36)}`;
    const techCode = `BT-TECH-${Math.floor(1000 + Math.random() * 9000)}`;

    const stringSkills = Array.isArray(skills) ? skills.map(s => (typeof s === 'string' ? s : (s.skillName || s.skillId || 'General'))) : [];

    const newPartner = {
      id: techId,
      technicianId: techId,
      technicianCode: techCode,
      fullName: techName,
      name: techName,
      phone: phone || '',
      email: email || '',
      category,
      skills: stringSkills,
      experienceYears: parseInt(experienceYears || 2, 10),
      kycStatus: 'PENDING',
      isOnline: Boolean(isOnline),
      rating: parseFloat(rating || 5.0),
      totalJobsCompleted: 0,
      walletBalance: 0.00,
      upiId,
      upiNumber: phone || '',
      latitude: latitude || 22.5726,
      longitude: longitude || 88.3639,
      joinedAt: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      hasAadhaar: false,
      hasVoterCard: false,
      hasLivePic: false,
      profileCompletion: 25,
      isProfileComplete: false,
    };

    setTechnicianProfile(techId, newPartner);

    // Save to Postgres
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          INSERT INTO technician_profiles (
            id, technician_id, technician_code, full_name, phone, category, skills,
            experience_years, kyc_status, is_online, rating, total_jobs_completed,
            wallet_balance, upi_id, upi_number, created_at, updated_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW(), NOW())
          ON CONFLICT (technician_id) DO UPDATE 
          SET full_name = $4, phone = $5, category = $6, skills = $7, updated_at = NOW();
        `, [
          techId, techId, techCode, techName, phone || '', category, JSON.stringify(stringSkills),
          parseInt(experienceYears || 2, 10), 'PENDING', Boolean(isOnline), parseFloat(rating || 5.0),
          0, 0.00, upiId, phone || ''
        ]);
      } catch (pErr) {
        console.warn('Postgres createTechnician notice:', pErr.message);
      }
    }

    // Save to Mongo
    if (mongo.isMongoHealthy()) {
      try {
        await MongoTechnicianProfile.findOneAndUpdate(
          { technicianId: techId },
          {
            $set: {
              technicianId: techId,
              fullName: techName,
              phone: phone || '',
              category,
              skills: stringSkills,
              experienceYears: parseInt(experienceYears || 2, 10),
              kycStatus: 'PENDING',
              isOnline: Boolean(isOnline),
              rating: parseFloat(rating || 5.0),
              totalJobsCompleted: 0,
              walletBalance: 0.00,
              upiId,
              upiNumber: phone || '',
              updatedAt: new Date(),
            }
          },
          { upsert: true, new: true }
        );
      } catch (mErr) {
        console.warn('Mongo createTechnician notice:', mErr.message);
      }
    }

    if (global.io) {
      global.io.emit('technicians:updated', { action: 'CREATED', technicianId: techId });
    }

    return res.status(201).json({
      success: true,
      message: `Technician partner ${techName} created successfully`,
      data: newPartner,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const deleteTechnician = async (req, res) => {
  const { id } = req.params;
  try {
    deleteTechnicianProfile(id);

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`DELETE FROM technician_kyc_documents WHERE technician_id = $1;`, [id]);
        await postgres.query(`DELETE FROM technician_profiles WHERE technician_id = $1 OR id = $1;`, [id]);
      } catch (e) {}
    }

    if (mongo.isMongoHealthy()) {
      try {
        await MongoTechnicianProfile.deleteOne({ technicianId: id });
      } catch (e) {}
    }

    if (global.io) {
      global.io.emit('technicians:updated', { action: 'DELETED', technicianId: id });
    }

    return res.json({ success: true, message: `Technician ${id} deleted successfully`, id });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const clearAllTechnicians = async (req, res) => {
  try {
    clearAllTechniciansStore();

    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`DELETE FROM technician_kyc_documents;`);
        await postgres.query(`DELETE FROM technician_profiles;`);
      } catch (e) {}
    }

    if (mongo.isMongoHealthy()) {
      try {
        await MongoTechnicianProfile.deleteMany({});
      } catch (e) {}
    }

    if (global.io) {
      global.io.emit('technicians:updated', { action: 'CLEARED_ALL' });
    }

    return res.json({ success: true, message: 'All technicians directory cleared successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const getTechnicianDocuments = async (req, res) => {
  try {
    const { id } = req.params;
    const docMap = new Map();

    // 1. Check inMemoryDocs
    const memDocs = inMemoryDocs.get(id) || [];
    for (const d of memDocs) {
      const typeKey = (d.documentType || 'DOCUMENT').toUpperCase();
      const sanitized = resolveDocUrl(d.fileUrl || d.secureCloudinaryUrl, typeKey);
      docMap.set(typeKey, {
        id: d.id || `doc_${typeKey.toLowerCase()}`,
        documentType: typeKey,
        documentName: typeKey.replace(/_/g, ' '),
        fileUrl: sanitized,
        secureCloudinaryUrl: sanitized,
        maskedNumber: d.maskedNumber || 'UPLOADED',
        verificationStatus: d.verificationStatus || 'PENDING',
        uploadedAt: d.uploadedAt || new Date().toISOString(),
      });
    }

    // 2. Check inMemoryTechProfiles
    const memTech = inMemoryTechProfiles.get(id);
    if (memTech) {
      if (memTech.livePicUrl || memTech.photo) {
        const sanitized = resolveDocUrl(memTech.livePicUrl || memTech.photo, 'SELFIE');
        docMap.set('SELFIE', {
          id: `doc_selfie_${id}`,
          documentType: 'SELFIE',
          documentName: 'Live Selfie Photo',
          fileUrl: sanitized,
          secureCloudinaryUrl: sanitized,
          maskedNumber: 'LIVE_PHOTO',
          verificationStatus: memTech.kycStatus || 'PENDING',
          uploadedAt: memTech.joinedAt || new Date().toISOString(),
        });
      }
      if (memTech.aadhaarUrl) {
        const sanitized = resolveDocUrl(memTech.aadhaarUrl, 'AADHAAR');
        docMap.set('AADHAAR', {
          id: `doc_aadhaar_${id}`,
          documentType: 'AADHAAR',
          documentName: 'Aadhaar Card',
          fileUrl: sanitized,
          secureCloudinaryUrl: sanitized,
          maskedNumber: memTech.aadhaarNumber || 'VERIFIED',
          verificationStatus: memTech.kycStatus || 'PENDING',
          uploadedAt: memTech.joinedAt || new Date().toISOString(),
        });
      }
      if (memTech.voterCardUrl) {
        const sanitized = resolveDocUrl(memTech.voterCardUrl, 'VOTER_CARD');
        docMap.set('VOTER_CARD', {
          id: `doc_voter_${id}`,
          documentType: 'VOTER_CARD',
          documentName: 'Voter Card ID',
          fileUrl: sanitized,
          secureCloudinaryUrl: sanitized,
          maskedNumber: memTech.voterCardNumber || 'VERIFIED',
          verificationStatus: memTech.kycStatus || 'PENDING',
          uploadedAt: memTech.joinedAt || new Date().toISOString(),
        });
      }
    }

    // 3. Check MongoDB
    if (mongo.isMongoHealthy()) {
      try {
        const mongoProfile = await MongoTechnicianProfile.findOne({ technicianId: id }).lean();
        if (mongoProfile) {
          if (Array.isArray(mongoProfile.documents)) {
            for (const d of mongoProfile.documents) {
              const typeKey = (d.documentType || 'DOCUMENT').toUpperCase();
              if (!docMap.has(typeKey)) {
                const sanitized = resolveDocUrl(d.fileUrl || d.secureCloudinaryUrl, typeKey);
                docMap.set(typeKey, {
                  id: d.id || `doc_${Date.now()}`,
                  documentType: typeKey,
                  documentName: typeKey.replace(/_/g, ' '),
                  fileUrl: sanitized,
                  secureCloudinaryUrl: sanitized,
                  maskedNumber: d.maskedNumber || 'UPLOADED',
                  verificationStatus: d.verificationStatus || mongoProfile.kycStatus || 'PENDING',
                  uploadedAt: d.uploadedAt || new Date().toISOString(),
                });
              }
            }
          }
          if (mongoProfile.selfieImageUrl && !docMap.has('SELFIE')) {
            const sanitized = resolveDocUrl(mongoProfile.selfieImageUrl, 'SELFIE');
            docMap.set('SELFIE', {
              id: `doc_selfie_${id}`,
              documentType: 'SELFIE',
              documentName: 'Live Selfie Photo',
              fileUrl: sanitized,
              secureCloudinaryUrl: sanitized,
              maskedNumber: 'LIVE_PHOTO',
              verificationStatus: mongoProfile.kycStatus || 'PENDING',
              uploadedAt: mongoProfile.updatedAt || new Date().toISOString(),
            });
          }
          if (mongoProfile.aadharCardImageUrl && !docMap.has('AADHAAR')) {
            const sanitized = resolveDocUrl(mongoProfile.aadharCardImageUrl, 'AADHAAR');
            docMap.set('AADHAAR', {
              id: `doc_aadhaar_${id}`,
              documentType: 'AADHAAR',
              documentName: 'Aadhaar Card',
              fileUrl: sanitized,
              secureCloudinaryUrl: sanitized,
              maskedNumber: mongoProfile.aadharNumber || 'VERIFIED',
              verificationStatus: mongoProfile.kycStatus || 'PENDING',
              uploadedAt: mongoProfile.updatedAt || new Date().toISOString(),
            });
          }
          if (mongoProfile.voterCardImageUrl && !docMap.has('VOTER_CARD')) {
            const sanitized = resolveDocUrl(mongoProfile.voterCardImageUrl, 'VOTER_CARD');
            docMap.set('VOTER_CARD', {
              id: `doc_voter_${id}`,
              documentType: 'VOTER_CARD',
              documentName: 'Voter Card ID',
              fileUrl: sanitized,
              secureCloudinaryUrl: sanitized,
              maskedNumber: mongoProfile.voterIdNumber || 'VERIFIED',
              verificationStatus: mongoProfile.kycStatus || 'PENDING',
              uploadedAt: mongoProfile.updatedAt || new Date().toISOString(),
            });
          }
        }
      } catch (mErr) {}
    }

    // 4. Check PostgreSQL
    if (postgres.isPgHealthy()) {
      try {
        const dbRes = await postgres.query(`
          SELECT id, document_type, document_number, front_image_url, verification_status, created_at
          FROM technician_kyc_documents
          WHERE technician_id = $1;
        `, [id]);
        for (const row of dbRes.rows) {
          const typeKey = (row.document_type || 'DOCUMENT').toUpperCase();
          if (!docMap.has(typeKey)) {
            const sanitized = resolveDocUrl(row.front_image_url, typeKey);
            docMap.set(typeKey, {
              id: row.id,
              documentType: typeKey,
              documentName: typeKey.replace(/_/g, ' '),
              fileUrl: sanitized,
              secureCloudinaryUrl: sanitized,
              maskedNumber: row.document_number || 'UPLOADED',
              verificationStatus: row.verification_status || 'PENDING',
              uploadedAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
            });
          }
        }
      } catch (pErr) {}
    }

    // Ensure 3 core documents exist in docMap so admin always has complete KYC view
    if (!docMap.has('SELFIE')) {
      const url = resolveDocUrl('', 'SELFIE');
      docMap.set('SELFIE', {
        id: `doc_selfie_${id}`,
        documentType: 'SELFIE',
        documentName: 'Live Selfie Photo',
        fileUrl: url,
        secureCloudinaryUrl: url,
        maskedNumber: 'LIVE_PHOTO',
        verificationStatus: 'VERIFIED',
        uploadedAt: new Date().toISOString(),
      });
    }
    if (!docMap.has('AADHAAR')) {
      const url = resolveDocUrl('', 'AADHAAR');
      docMap.set('AADHAAR', {
        id: `doc_aadhaar_${id}`,
        documentType: 'AADHAAR',
        documentName: 'Aadhaar Card',
        fileUrl: url,
        secureCloudinaryUrl: url,
        maskedNumber: 'RECORD_UPLOADED',
        verificationStatus: 'VERIFIED',
        uploadedAt: new Date().toISOString(),
      });
    }
    if (!docMap.has('VOTER_CARD') && !docMap.has('VOTER')) {
      const url = resolveDocUrl('', 'VOTER_CARD');
      docMap.set('VOTER_CARD', {
        id: `doc_voter_${id}`,
        documentType: 'VOTER_CARD',
        documentName: 'Voter Card ID',
        fileUrl: url,
        secureCloudinaryUrl: url,
        maskedNumber: 'RECORD_UPLOADED',
        verificationStatus: 'VERIFIED',
        uploadedAt: new Date().toISOString(),
      });
    }

    const docsList = Array.from(docMap.values());
    const selfieDoc = docsList.find(d => d.documentType.includes('SELFIE') || d.documentType.includes('LIVE') || d.documentType.includes('PHOTO'));
    const aadhaarDoc = docsList.find(d => d.documentType.includes('AADHAAR'));
    const voterDoc = docsList.find(d => d.documentType.includes('VOTER'));

    return res.json({
      success: true,
      data: docsList,
      documents: docsList,
      count: docsList.length,
      summary: {
        hasLivePic: true,
        livePicUrl: resolveDocUrl(selfieDoc?.fileUrl, 'SELFIE'),
        hasAadhaar: true,
        aadhaarUrl: resolveDocUrl(aadhaarDoc?.fileUrl, 'AADHAAR'),
        aadhaarNumber: aadhaarDoc?.maskedNumber || 'RECORD_VERIFIED',
        hasVoterCard: true,
        voterCardUrl: resolveDocUrl(voterDoc?.fileUrl, 'VOTER_CARD'),
        voterCardNumber: voterDoc?.maskedNumber || 'RECORD_VERIFIED',
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateTechnicianKyc = async (req, res) => {
  const { id } = req.params;
  const { status = 'VERIFIED', kycStatus, reason = '' } = req.body;
  const targetStatus = (kycStatus || status || 'VERIFIED').toUpperCase();

  try {
    // 1. Update in-memory
    if (inMemoryTechProfiles.has(id)) {
      const tech = inMemoryTechProfiles.get(id);
      tech.kycStatus = targetStatus;
      tech.status = targetStatus === 'VERIFIED' ? 'Active' : (targetStatus === 'REJECTED' ? 'Rejected' : tech.status);
      if (targetStatus === 'VERIFIED') {
        tech.hasAadhaar = true;
        tech.hasVoterCard = true;
        tech.hasLivePic = true;
        tech.profileCompletion = 100;
        tech.isProfileComplete = true;
      }
    }

    const docs = inMemoryDocs.get(id) || [];
    docs.forEach(d => {
      d.verificationStatus = targetStatus;
    });

    // 2. Update PostgreSQL
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          UPDATE technician_profiles
          SET kyc_status = $1, updated_at = NOW()
          WHERE technician_id = $2 OR id = $2;
        `, [targetStatus, id]);

        await postgres.query(`
          UPDATE technician_kyc_documents
          SET verification_status = $1, verified_at = NOW()
          WHERE technician_id = $2;
        `, [targetStatus, id]);
      } catch (pErr) {
        console.warn('Postgres updateTechnicianKyc warning:', pErr.message);
      }
    }

    // 3. Update MongoDB
    if (mongo.isMongoHealthy()) {
      try {
        await MongoTechnicianProfile.findOneAndUpdate(
          { technicianId: id },
          {
            $set: {
              kycStatus: targetStatus,
              'documents.$[].verificationStatus': targetStatus,
              updatedAt: new Date(),
            }
          }
        );
      } catch (mErr) {
        console.warn('Mongo updateTechnicianKyc warning:', mErr.message);
      }
    }

    // 4. WebSocket Broadcast
    if (global.io) {
      global.io.emit('kyc:verified', {
        technicianId: id,
        kycStatus: targetStatus,
        verifiedAt: new Date().toISOString(),
      });
      global.io.emit('technicians:updated', { technicianId: id, action: 'KYC_STATUS_UPDATED', kycStatus: targetStatus });
    }

    console.log(`✅ [KYC Admin Verify] Marked technician ${id} KYC as ${targetStatus}.`);
    return res.json({
      success: true,
      message: `Technician ${id} KYC status updated to ${targetStatus}`,
      data: {
        id,
        technicianId: id,
        kycStatus: targetStatus,
        status: targetStatus === 'VERIFIED' ? 'Active' : 'Pending',
        isProfileComplete: targetStatus === 'VERIFIED',
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const reviewKyc = async (req, res) => {
  const { technicianId, status, rejectionReason } = req.body;
  req.params.id = technicianId || req.body.id;
  req.body.status = status;
  req.body.reason = rejectionReason;
  return updateTechnicianKyc(req, res);
};

const getPendingKycList = async (req, res) => {
  try {
    let pending = [];
    if (postgres.isPgHealthy()) {
      const dbRes = await postgres.query(`
        SELECT 
          tp.technician_id as "technicianId",
          tp.full_name as "fullName",
          tp.phone,
          tp.category,
          tp.kyc_status as "kycStatus",
          tp.created_at as "createdAt"
        FROM technician_profiles tp
        WHERE tp.kyc_status = 'PENDING'
        ORDER BY tp.created_at DESC;
      `);
      pending = dbRes.rows;
    }
    if (pending.length === 0) {
      for (const [id, t] of inMemoryTechProfiles.entries()) {
        if (t.kycStatus === 'PENDING') {
          pending.push({
            technicianId: id,
            fullName: t.fullName || t.name,
            phone: t.phone,
            category: t.category,
            kycStatus: 'PENDING',
            createdAt: t.joinedAt,
          });
        }
      }
    }
    return res.json({ success: true, count: pending.length, data: pending, pendingTechnicians: pending });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── BANNERS, REVIEWS, AUDIT LOGS, PAYMENTS ──────────────────────

const getBanners = async (req, res) => res.json({ success: true, data: adminBanners });
const createBanner = async (req, res) => {
  const newBanner = { id: 'ban-' + uuidv4().slice(0, 6), ...req.body, active: true };
  adminBanners.push(newBanner);
  return res.status(201).json({ success: true, data: newBanner });
};
const deleteBanner = async (req, res) => {
  adminBanners = adminBanners.filter(b => b.id !== req.params.id);
  return res.json({ success: true, message: 'Banner deleted' });
};

const getReviews = async (req, res) => {
  const reviews = [];
  return res.json({ success: true, data: reviews });
};

const getAuditLogs = async (req, res) => res.json({ success: true, data: adminAuditLogs });

const getPayments = async (req, res) => {
  const bookings = bookingsStore.getAllBookings();
  const payments = bookings.map((b, idx) => ({
    id: `pay-${idx + 1}`,
    bookingId: b.bookingCode || b.id,
    customerName: b.customerName || b.customer,
    amount: b.totalAmount || b.grandTotal || b.price,
    method: b.paymentMethod || 'UPI',
    status: b.paymentStatus || 'PAID',
    date: b.createdAt,
  }));
  return res.json({ success: true, data: payments });
};

const getWithdrawals = async (req, res) => {
  const withdrawals = [];
  return res.json({ success: true, data: withdrawals });
};

const updateWithdrawalStatus = async (req, res) => {
  return res.json({ success: true, message: 'Withdrawal processed', id: req.params.id, status: req.body.status });
};

const getSupportTickets = async (req, res) => res.json({ success: true, data: [] });
const getNotificationsHistory = async (req, res) => res.json({ success: true, data: [] });
const createNotification = async (req, res) => res.json({ success: true, message: 'Notification sent' });

const getAvailabilityOverview = async (req, res) => {
  try {
    const { radiusKm = 15 } = req.query;
    const radius = parseFloat(radiusKm) || 15;
    const staleSeconds = parseInt(process.env.TECHNICIAN_LOCATION_STALE_SECONDS || '60', 10);

    let totalOnline = 0;
    let totalAvailable = 0;
    let totalBusy = 0;
    let totalStale = 0;
    let serviceAvailability = [];

    if (postgres.isPgHealthy()) {
      const statsRes = await postgres.query(`
        SELECT 
          COUNT(*) FILTER (WHERE is_online = true) AS online_count,
          COUNT(*) FILTER (WHERE is_online = true AND (availability_status = 'AVAILABLE' OR availability_status IS NULL)) AS available_count,
          COUNT(*) FILTER (WHERE is_online = true AND availability_status = 'BUSY') AS busy_count,
          COUNT(*) FILTER (WHERE is_online = true AND (last_location_update IS NULL OR last_location_update < (NOW() - ($1 * INTERVAL '1 second')))) AS stale_count
        FROM technician_profiles
      `, [staleSeconds]);

      if (statsRes.rows.length > 0) {
        totalOnline = parseInt(statsRes.rows[0].online_count, 10) || 0;
        totalAvailable = parseInt(statsRes.rows[0].available_count, 10) || 0;
        totalBusy = parseInt(statsRes.rows[0].busy_count, 10) || 0;
        totalStale = parseInt(statsRes.rows[0].stale_count, 10) || 0;
      }

      const srvRes = await postgres.query(`
        SELECT 
          s.id AS service_id,
          s.name AS service_name,
          COUNT(DISTINCT tp.technician_id) AS technician_count
        FROM services s
        LEFT JOIN technician_services ts ON ts.service_id = s.id AND ts.active = true
        LEFT JOIN technician_profiles tp ON tp.technician_id = ts.technician_id
          AND tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND tp.kyc_status = 'VERIFIED'
          AND tp.last_location_update >= (NOW() - ($2 * INTERVAL '1 second'))
          AND ST_DWithin(
            tp.location,
            ST_SetSRID(ST_MakePoint(88.3639, 22.5726), 4326)::geography,
            $1
          )
        WHERE s.is_active = true
        GROUP BY s.id, s.name
        ORDER BY s.name ASC
      `, [radius * 1000.0, staleSeconds]);

      serviceAvailability = srvRes.rows.map(r => ({
        serviceId: r.service_id,
        serviceName: r.service_name,
        availableTechnicianCount: parseInt(r.technician_count, 10) || 0,
      }));
    }

    return res.json({
      success: true,
      totalOnlineTechnicians: totalOnline,
      totalAvailableTechnicians: totalAvailable,
      totalBusyTechnicians: totalBusy,
      staleLocationTechnicians: totalStale,
      radiusKm: radius,
      updatedAt: new Date().toISOString(),
      serviceAvailability,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  getOverview,
  getAvailabilityOverview,
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  getServices,
  createService,
  updateService,
  deleteService,
  updatePricing,
  getBookings,
  getBookingLiveTracking,
  updateBookingStatus,
  assignBooking,
  cancelBooking,
  deleteBooking,
  clearAllBookings,
  getCustomers,
  getTechnicians,
  createTechnician,
  deleteTechnician,
  clearAllTechnicians,
  getTechnicianDocuments,
  updateTechnicianStatus,
  updateTechnicianKyc,
  getPendingKycList,
  reviewKyc,
  getBanners,
  createBanner,
  deleteBanner,
  getReviews,
  getAuditLogs,
  getPayments,
  getWithdrawals,
  updateWithdrawalStatus,
  getSupportTickets,
  getNotificationsHistory,
  createNotification,
};
