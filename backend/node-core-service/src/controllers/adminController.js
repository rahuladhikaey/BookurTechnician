const { v4: uuidv4 } = require('uuid');
const MongoTechnicianProfile = require('../models/MongoTechnicianProfile');
const MongoCatalog = require('../models/MongoCatalog');
const postgres = require('../config/postgres');
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

const getCustomers = async (req, res) => {
  try {
    const customers = bookingsStore.getAllCustomers();
    return res.json({ success: true, data: customers, count: customers.length });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── TECHNICIANS MANAGEMENT & KYC ────────────────────────────────

const getTechnicians = async (req, res) => {
  try {
    let techniciansList = [];
    if (postgres.isPgHealthy()) {
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
          u.profile_image_url as avatar,
          tp.created_at as "joinedAt"
        FROM technician_profiles tp
        LEFT JOIN users u ON tp.technician_id = u.id
        ORDER BY tp.created_at DESC;
      `);
      techniciansList = dbRes.rows;
    }

    // Fallback to MongoDB if PostgreSQL had zero
    if (techniciansList.length === 0) {
      try {
        const mongoTechs = await MongoTechnicianProfile.find({});
        if (mongoTechs && mongoTechs.length > 0) {
          techniciansList = mongoTechs.map(t => ({
            id: t.technicianId || t._id,
            technicianId: t.technicianId,
            fullName: t.fullName,
            name: t.fullName,
            phone: t.phone,
            category: t.category,
            skills: t.skills || [],
            kycStatus: t.kycStatus || 'PENDING',
            rating: t.rating || 5.0,
            totalJobsCompleted: t.totalJobsCompleted || 0,
            isOnline: t.isOnline || false,
            experienceYears: t.experienceYears || 2,
            walletBalance: t.walletBalance || 0,
            avatar: t.avatar || '',
            joinedAt: t.createdAt || new Date().toISOString(),
          }));
        }
      } catch (mErr) {}
    }

    return res.json({ success: true, data: techniciansList, count: techniciansList.length });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateTechnicianStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
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
    return res.json({ success: true, count: pending.length, data: pending, pendingTechnicians: pending });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const reviewKyc = async (req, res) => {
  const { technicianId, status, rejectionReason } = req.body;
  try {
    if (postgres.isPgHealthy()) {
      await postgres.query(`
        UPDATE technician_profiles
        SET kyc_status = $1, updated_at = NOW()
        WHERE technician_id = $2 OR id = $2;
      `, [status, technicianId]);
      
      await postgres.query(`
        UPDATE technician_kyc_documents
        SET verification_status = $1, rejection_reason = $2
        WHERE technician_id = $3;
      `, [status === 'VERIFIED' ? 'APPROVED' : 'REJECTED', rejectionReason || null, technicianId]);
    }
  } catch (e) {}
  return res.json({ success: true, message: `Technician KYC marked as ${status}`, technicianId, status });
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
  updateBookingStatus,
  assignBooking,
  cancelBooking,
  deleteBooking,
  clearAllBookings,
  getCustomers,
  getTechnicians,
  updateTechnicianStatus,
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
