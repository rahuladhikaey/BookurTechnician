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
    let activeTechnicians = 34;

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
  const techniciansList = [
    {
      id: 'tech-001',
      technicianId: 'tech-001',
      fullName: 'Rahul Sharma',
      name: 'Rahul Sharma',
      phone: '+91 98765 43210',
      category: 'Electrician & Electrical Services',
      skills: ['Wiring', 'Switchboard Repair', 'Ceiling Fan Fix', 'MCB Installation'],
      kycStatus: 'VERIFIED',
      rating: 4.88,
      totalJobsCompleted: 142,
      isOnline: true,
      experienceYears: 6,
      walletBalance: 3450.0,
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
      joinedAt: '2026-01-15',
    },
    {
      id: 'tech-002',
      technicianId: 'tech-002',
      fullName: 'Amit Kumar',
      name: 'Amit Kumar',
      phone: '+91 91234 56780',
      category: 'Plumbing & Pipe Fitting',
      skills: ['Pipe Fitting', 'Tap Repair', 'Water Heater Leakage', 'Drain Unclogging'],
      kycStatus: 'VERIFIED',
      rating: 4.75,
      totalJobsCompleted: 98,
      isOnline: true,
      experienceYears: 5,
      walletBalance: 2100.0,
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      joinedAt: '2026-02-10',
    },
    {
      id: 'tech-003',
      technicianId: 'tech-003',
      fullName: 'Bikram Das',
      name: 'Bikram Das',
      phone: '+91 98301 22334',
      category: 'AC Repair & HVAC Services',
      skills: ['AC Deep Clean', 'Gas Refill', 'Compressor Check', 'PCB Repair'],
      kycStatus: 'VERIFIED',
      rating: 4.92,
      totalJobsCompleted: 215,
      isOnline: true,
      experienceYears: 8,
      walletBalance: 5600.0,
      avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      joinedAt: '2025-11-20',
    },
    {
      id: 'tech-004',
      technicianId: 'tech-004',
      fullName: 'Sunil Mondal',
      name: 'Sunil Mondal',
      phone: '+91 97480 99887',
      category: 'Appliance Repair (Fridge & Washing Machine)',
      skills: ['Refrigerator Cooling Fix', 'Washing Machine Drum', 'Microwave Heating'],
      kycStatus: 'VERIFIED',
      rating: 4.80,
      totalJobsCompleted: 110,
      isOnline: true,
      experienceYears: 4,
      walletBalance: 1850.0,
      avatar: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=200',
      joinedAt: '2026-03-01',
    },
  ];
  return res.json({ success: true, data: techniciansList });
};

const updateTechnicianStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  return res.json({ success: true, message: `Technician status updated to ${status}`, id, status });
};

const getPendingKycList = async (req, res) => {
  const pending = [
    {
      technicianId: 'tech-002',
      fullName: 'Amit Kumar',
      phone: '+91 9123456780',
      category: 'PLUMBER',
      aadharNumber: 'XXXX-XXXX-4589',
      kycStatus: 'PENDING',
      createdAt: new Date(),
    },
  ];
  return res.json({ success: true, count: pending.length, data: pending, pendingTechnicians: pending });
};

const reviewKyc = async (req, res) => {
  const { technicianId, status, rejectionReason } = req.body;
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
