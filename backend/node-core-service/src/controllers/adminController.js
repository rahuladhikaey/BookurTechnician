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
            tp.full_name as "fullName",
            tp.full_name as name,
            tp.phone,
            tp.category,
            tp.skills,
            tp.kyc_status as "kycStatus",
            tp.rating,
            tp.total_jobs_completed as "totalJobsCompleted",
            tp.is_online as "isOnline",
            tp.experience_years as "experienceYears",
            tp.wallet_balance as "walletBalance",
            tp.upi_id as "upiId",
            tp.upi_number as "upiNumber",
            u.email,
            u.profile_image_url as avatar,
            tp.created_at as "joinedAt"
          FROM technician_profiles tp
          LEFT JOIN users u ON tp.technician_id = u.id
          ORDER BY tp.created_at DESC;
        `);
        for (const row of dbRes.rows) {
          const id = row.technicianId || row.id;
          const existing = techMap.get(id) || {};
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
            avatar: row.avatar || existing.avatar || '',
            livePicUrl: row.avatar || existing.livePicUrl || '',
            photo: row.avatar || existing.photo || '',
            joinedAt: row.joinedAt ? new Date(row.joinedAt).toISOString() : (existing.joinedAt || new Date().toISOString()),
          });
        }

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
              tech.aadhaarUrl = docRow.front_image_url || tech.aadhaarUrl;
              tech.aadhaarNumber = docRow.document_number || tech.aadhaarNumber;
            } else if (dt.includes('VOTER')) {
              tech.hasVoterCard = true;
              tech.voterCardUrl = docRow.front_image_url || tech.voterCardUrl;
              tech.voterCardNumber = docRow.document_number || tech.voterCardNumber;
            } else if (dt.includes('SELFIE') || dt.includes('LIVE') || dt.includes('PHOTO')) {
              tech.hasLivePic = true;
              tech.livePicUrl = docRow.front_image_url || tech.livePicUrl;
              tech.photo = docRow.front_image_url || tech.photo;
            }
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

        const aadhaarUrl = t.aadharCardImageUrl || t.aadhaarUrl || aadhaarDoc?.fileUrl || aadhaarDoc?.secureCloudinaryUrl || existing.aadhaarUrl || '';
        const voterCardUrl = t.voterCardImageUrl || t.voterCardUrl || voterDoc?.fileUrl || voterDoc?.secureCloudinaryUrl || existing.voterCardUrl || '';
        const livePicUrl = t.selfieImageUrl || t.livePicUrl || t.avatar || selfieDoc?.fileUrl || selfieDoc?.secureCloudinaryUrl || existing.livePicUrl || existing.avatar || '';

        const aadhaarNumber = t.aadharNumber || t.aadhaarNumber || aadhaarDoc?.maskedNumber || existing.aadhaarNumber || '';
        const voterCardNumber = t.voterIdNumber || t.voterCardNumber || voterDoc?.maskedNumber || existing.voterCardNumber || '';

        const hasAadhaar = isVer || Boolean(aadhaarUrl || aadhaarNumber || existing.hasAadhaar);
        const hasVoterCard = isVer || Boolean(voterCardUrl || voterCardNumber || existing.hasVoterCard);
        const hasLivePic = isVer || Boolean(livePicUrl || existing.hasLivePic);

        const profileCompletion = isVer ? 100 : ((hasAadhaar ? 25 : 0) + (hasVoterCard ? 25 : 0) + (hasLivePic ? 25 : 0) + 25);
        const isProfileComplete = isVer || profileCompletion === 100;

        const rawSkillsArr = t.skills && t.skills.length > 0 ? t.skills : (existing.skills && existing.skills.length > 0 ? existing.skills : ['Wiring', 'Switchboard Repair']);
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
          name: t.fullName || existing.name || 'Technician',
          phone: t.phone || existing.phone || '',
          email: t.email || existing.email || '',
          category: t.category || existing.category || 'Electrician',
          skills: formattedSkillsList,
          kycStatus: isVer ? 'VERIFIED' : rawKyc,
          kycDocuments: docs,
          hasAadhaar,
          hasVoterCard,
          hasLivePic,
          aadhaarUrl,
          voterCardUrl,
          livePicUrl,
          photo: livePicUrl,
          avatar: livePicUrl || existing.avatar || '',
          aadhaarNumber,
          voterCardNumber,
          upiId: t.upiId || t.upiNumber || existing.upiId || '',
          isProfileComplete,
          profileCompletion,
          rating: t.rating || existing.rating || 5.0,
          totalJobsCompleted: t.totalJobsCompleted || existing.totalJobsCompleted || 0,
          isOnline: t.isOnline !== undefined ? Boolean(t.isOnline) : (existing.isOnline !== undefined ? existing.isOnline : false),
          experienceYears: t.experienceYears || existing.experienceYears || 2,
          walletBalance: t.walletBalance || existing.walletBalance || 0,
          latitude: latitude !== undefined ? latitude : existing.latitude,
          longitude: longitude !== undefined ? longitude : existing.longitude,
          joinedAt: t.createdAt ? new Date(t.createdAt).toISOString() : (existing.joinedAt || new Date().toISOString()),
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
            tech.aadhaarUrl = doc.fileUrl || tech.aadhaarUrl;
            tech.aadhaarNumber = doc.maskedNumber || tech.aadhaarNumber;
          } else if (dt.includes('VOTER')) {
            tech.hasVoterCard = true;
            tech.voterCardUrl = doc.fileUrl || tech.voterCardUrl;
            tech.voterCardNumber = doc.maskedNumber || tech.voterCardNumber;
          } else if (dt.includes('SELFIE') || dt.includes('LIVE') || dt.includes('PHOTO')) {
            tech.hasLivePic = true;
            tech.livePicUrl = doc.fileUrl || tech.livePicUrl;
            tech.photo = doc.fileUrl || tech.photo;
            tech.avatar = doc.fileUrl || tech.avatar;
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

      return {
        ...t,
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
      docMap.set(typeKey, {
        id: d.id || `doc_${typeKey.toLowerCase()}`,
        documentType: typeKey,
        documentName: typeKey.replace(/_/g, ' '),
        fileUrl: d.fileUrl || d.secureCloudinaryUrl || '',
        secureCloudinaryUrl: d.secureCloudinaryUrl || d.fileUrl || '',
        maskedNumber: d.maskedNumber || 'UPLOADED',
        verificationStatus: d.verificationStatus || 'PENDING',
        uploadedAt: d.uploadedAt || new Date().toISOString(),
      });
    }

    // 2. Check inMemoryTechProfiles
    const memTech = inMemoryTechProfiles.get(id);
    if (memTech) {
      if (memTech.livePicUrl || memTech.photo) {
        docMap.set('SELFIE', {
          id: `doc_selfie_${id}`,
          documentType: 'SELFIE',
          documentName: 'Live Selfie Photo',
          fileUrl: memTech.livePicUrl || memTech.photo,
          secureCloudinaryUrl: memTech.livePicUrl || memTech.photo,
          maskedNumber: 'LIVE_PHOTO',
          verificationStatus: memTech.kycStatus || 'PENDING',
          uploadedAt: memTech.joinedAt || new Date().toISOString(),
        });
      }
      if (memTech.aadhaarUrl) {
        docMap.set('AADHAAR', {
          id: `doc_aadhaar_${id}`,
          documentType: 'AADHAAR',
          documentName: 'Aadhaar Card',
          fileUrl: memTech.aadhaarUrl,
          secureCloudinaryUrl: memTech.aadhaarUrl,
          maskedNumber: memTech.aadhaarNumber || 'VERIFIED',
          verificationStatus: memTech.kycStatus || 'PENDING',
          uploadedAt: memTech.joinedAt || new Date().toISOString(),
        });
      }
      if (memTech.voterCardUrl) {
        docMap.set('VOTER_CARD', {
          id: `doc_voter_${id}`,
          documentType: 'VOTER_CARD',
          documentName: 'Voter Card ID',
          fileUrl: memTech.voterCardUrl,
          secureCloudinaryUrl: memTech.voterCardUrl,
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
                docMap.set(typeKey, {
                  id: d.id || `doc_${Date.now()}`,
                  documentType: typeKey,
                  documentName: typeKey.replace(/_/g, ' '),
                  fileUrl: d.fileUrl || d.secureCloudinaryUrl || '',
                  secureCloudinaryUrl: d.secureCloudinaryUrl || d.fileUrl || '',
                  maskedNumber: d.maskedNumber || 'UPLOADED',
                  verificationStatus: d.verificationStatus || mongoProfile.kycStatus || 'PENDING',
                  uploadedAt: d.uploadedAt || new Date().toISOString(),
                });
              }
            }
          }
          if (mongoProfile.selfieImageUrl && !docMap.has('SELFIE')) {
            docMap.set('SELFIE', {
              id: `doc_selfie_${id}`,
              documentType: 'SELFIE',
              documentName: 'Live Selfie Photo',
              fileUrl: mongoProfile.selfieImageUrl,
              secureCloudinaryUrl: mongoProfile.selfieImageUrl,
              maskedNumber: 'LIVE_PHOTO',
              verificationStatus: mongoProfile.kycStatus || 'PENDING',
              uploadedAt: mongoProfile.updatedAt || new Date().toISOString(),
            });
          }
          if (mongoProfile.aadharCardImageUrl && !docMap.has('AADHAAR')) {
            docMap.set('AADHAAR', {
              id: `doc_aadhaar_${id}`,
              documentType: 'AADHAAR',
              documentName: 'Aadhaar Card',
              fileUrl: mongoProfile.aadharCardImageUrl,
              secureCloudinaryUrl: mongoProfile.aadharCardImageUrl,
              maskedNumber: mongoProfile.aadharNumber || 'VERIFIED',
              verificationStatus: mongoProfile.kycStatus || 'PENDING',
              uploadedAt: mongoProfile.updatedAt || new Date().toISOString(),
            });
          }
          if (mongoProfile.voterCardImageUrl && !docMap.has('VOTER_CARD')) {
            docMap.set('VOTER_CARD', {
              id: `doc_voter_${id}`,
              documentType: 'VOTER_CARD',
              documentName: 'Voter Card ID',
              fileUrl: mongoProfile.voterCardImageUrl,
              secureCloudinaryUrl: mongoProfile.voterCardImageUrl,
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
            docMap.set(typeKey, {
              id: row.id,
              documentType: typeKey,
              documentName: typeKey.replace(/_/g, ' '),
              fileUrl: row.front_image_url || '',
              secureCloudinaryUrl: row.front_image_url || '',
              maskedNumber: row.document_number || 'UPLOADED',
              verificationStatus: row.verification_status || 'PENDING',
              uploadedAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
            });
          }
        }
      } catch (pErr) {}
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
        hasLivePic: Boolean(selfieDoc?.fileUrl),
        livePicUrl: selfieDoc?.fileUrl || '',
        hasAadhaar: Boolean(aadhaarDoc?.fileUrl),
        aadhaarUrl: aadhaarDoc?.fileUrl || '',
        aadhaarNumber: aadhaarDoc?.maskedNumber || '',
        hasVoterCard: Boolean(voterDoc?.fileUrl),
        voterCardUrl: voterDoc?.fileUrl || '',
        voterCardNumber: voterDoc?.maskedNumber || '',
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

module.exports = {
  getOverview,
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
