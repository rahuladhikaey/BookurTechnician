const { v4: uuidv4 } = require('uuid');
const MongoTechnicianProfile = require('../models/MongoTechnicianProfile');
const MongoCatalog = require('../models/MongoCatalog');
const postgres = require('../config/postgres');

// In-Memory dynamic store for admin modules
let adminCategories = [
  {
    id: 'cat-elec',
    categoryId: 'electrician',
    name: 'Electrician Services',
    iconUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
    bannerUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
    active: true,
    displayOrder: 1,
    servicesCount: 4,
  },
  {
    id: 'cat-plum',
    categoryId: 'plumber',
    name: 'Plumber Services',
    iconUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500',
    bannerUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500',
    active: true,
    displayOrder: 2,
    servicesCount: 3,
  },
  {
    id: 'cat-carp',
    categoryId: 'carpenter',
    name: 'Carpenter Services',
    iconUrl: 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?w=500',
    bannerUrl: 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?w=500',
    active: true,
    displayOrder: 3,
    servicesCount: 3,
  },
  {
    id: 'cat-ac',
    categoryId: 'ac_repair',
    name: 'AC Repair & Service',
    iconUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500',
    bannerUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500',
    active: true,
    displayOrder: 4,
    servicesCount: 3,
  },
];

let adminServices = [
  {
    id: 'elec-01',
    categoryId: 'cat-elec',
    categoryName: 'Electrician Services',
    name: 'Switch & Socket Replacement',
    title: 'Switch & Socket Replacement',
    description: 'Repair and replacement of standard or modular electrical switches and wall sockets.',
    basePrice: 149,
    estimatedDurationMinutes: 30,
    active: true,
    taxRatePercent: 18,
  },
  {
    id: 'elec-02',
    categoryId: 'cat-elec',
    categoryName: 'Electrician Services',
    name: 'Fan Installation / Repair',
    title: 'Fan Installation / Repair',
    description: 'Ceiling, exhaust or wall fan installation and motor troubleshooting.',
    basePrice: 249,
    estimatedDurationMinutes: 45,
    active: true,
    taxRatePercent: 18,
  },
  {
    id: 'plum-01',
    categoryId: 'cat-plum',
    categoryName: 'Plumber Services',
    name: 'Tap / Faucet Leakage Repair',
    title: 'Tap / Faucet Leakage Repair',
    description: 'Repairing dripping faucets, spindle replacement and leak fix.',
    basePrice: 199,
    estimatedDurationMinutes: 30,
    active: true,
    taxRatePercent: 18,
  },
  {
    id: 'carp-01',
    categoryId: 'cat-carp',
    categoryName: 'Carpenter Services',
    name: 'Door Lock Installation / Repair',
    title: 'Door Lock Installation / Repair',
    description: 'Main door lock replacement, cylindrical lock fix, handle alignment.',
    basePrice: 299,
    estimatedDurationMinutes: 45,
    active: true,
    taxRatePercent: 18,
  },
  {
    id: 'ac-01',
    categoryId: 'cat-ac',
    categoryName: 'AC Repair & Service',
    name: 'AC Foam Jet Deep Cleaning',
    title: 'AC Foam Jet Deep Cleaning',
    description: '2x deeper indoor coil foam wash, outdoor unit jet wash, drain tray unclog.',
    basePrice: 599,
    estimatedDurationMinutes: 60,
    active: true,
    taxRatePercent: 18,
  },
];

let adminBanners = [
  {
    id: 'ban-01',
    title: '50% OFF on AC Deep Cleaning',
    subtitle: 'Beat the heat with certified AC experts',
    imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800',
    targetCategory: 'ac_repair',
    active: true,
  },
];

let adminAuditLogs = [
  { id: 'log-01', module: 'System', action: 'Polyglot backend initialized successfully', timestamp: new Date().toISOString() },
  { id: 'log-02', module: 'Auth', action: 'Admin logged in via Direct Access', timestamp: new Date().toISOString() },
];

/**
 * GET /api/v1/admin/overview
 */
const getOverview = async (req, res) => {
  try {
    let totalBookings = 248;
    let completedBookings = 215;
    let activeTechnicians = 34;
    let totalGrossRevenue = 84500.0;
    let platformCommission = 12675.0;

    return res.json({
      success: true,
      data: {
        totalBookings,
        completedBookings,
        activeTechnicians,
        totalGrossRevenue,
        platformCommission,
        customerSatisfactionRate: '96.4%',
        averageEtaMinutes: 18,
      },
      stats: {
        totalBookings,
        completedBookings,
        activeTechnicians,
        totalGrossRevenue,
        platformCommission,
        customerSatisfactionRate: '96.4%',
        averageEtaMinutes: 18,
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

// ─── CATEGORIES CRUD ──────────────────────────────────────────────

const getCategories = async (req, res) => {
  return res.json({ success: true, data: adminCategories });
};

const createCategory = async (req, res) => {
  try {
    const { name, iconUrl, bannerUrl, active = true } = req.body;
    if (!name) return res.status(400).json({ success: false, error: 'Category name is required' });

    const newCategory = {
      id: 'cat-' + uuidv4().slice(0, 8),
      categoryId: name.toLowerCase().replace(/[^a-z0-9]/g, '_'),
      name: name.trim(),
      iconUrl: iconUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
      bannerUrl: bannerUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
      active: active !== false,
      displayOrder: adminCategories.length + 1,
      servicesCount: 0,
      createdAt: new Date().toISOString(),
    };

    adminCategories.push(newCategory);
    adminAuditLogs.unshift({ id: 'log-' + uuidv4().slice(0, 6), module: 'Services', action: `Created category "${name}"`, timestamp: new Date().toISOString() });

    console.log(`✅ [Admin] Created new category: "${name}" (#${newCategory.id})`);
    return res.status(201).json({ success: true, data: newCategory, category: newCategory });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateCategory = async (req, res) => {
  const { id } = req.params;
  const index = adminCategories.findIndex(c => c.id === id || c.categoryId === id);
  if (index === -1) return res.status(404).json({ success: false, error: 'Category not found' });

  adminCategories[index] = { ...adminCategories[index], ...req.body, updatedAt: new Date().toISOString() };
  return res.json({ success: true, data: adminCategories[index] });
};

const deleteCategory = async (req, res) => {
  const { id } = req.params;
  adminCategories = adminCategories.filter(c => c.id !== id && c.categoryId !== id);
  return res.json({ success: true, message: 'Category deleted successfully' });
};

// ─── SERVICES CRUD ────────────────────────────────────────────────

const getServices = async (req, res) => {
  return res.json({ success: true, data: adminServices });
};

const createService = async (req, res) => {
  try {
    const { name, title, categoryId, basePrice, description, estimatedDurationMinutes = 45 } = req.body;
    const serviceName = name || title;
    if (!serviceName) return res.status(400).json({ success: false, error: 'Service name is required' });

    const newService = {
      id: 'srv-' + uuidv4().slice(0, 8),
      categoryId: categoryId || 'cat-elec',
      name: serviceName,
      title: serviceName,
      description: description || '',
      basePrice: parseFloat(basePrice) || 199,
      estimatedDurationMinutes: parseInt(estimatedDurationMinutes, 10) || 45,
      active: true,
      taxRatePercent: 18,
      createdAt: new Date().toISOString(),
    };

    adminServices.push(newService);
    return res.status(201).json({ success: true, data: newService, service: newService });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const updateService = async (req, res) => {
  const { id } = req.params;
  const index = adminServices.findIndex(s => s.id === id);
  if (index === -1) return res.status(404).json({ success: false, error: 'Service not found' });

  adminServices[index] = { ...adminServices[index], ...req.body, updatedAt: new Date().toISOString() };
  return res.json({ success: true, data: adminServices[index] });
};

const deleteService = async (req, res) => {
  const { id } = req.params;
  adminServices = adminServices.filter(s => s.id !== id);
  return res.json({ success: true, message: 'Service deleted successfully' });
};

// ─── TECHNICIANS MANAGEMENT ──────────────────────────────────────

const getTechnicians = async (req, res) => {
  const mockTechs = [
    {
      id: 'tech-001',
      technicianId: 'tech-001',
      fullName: 'Rahul Sharma',
      phone: '+91 9876543210',
      category: 'ELECTRICIAN',
      skills: ['Wiring', 'Switchboard Repair', 'Fan Fix'],
      kycStatus: 'VERIFIED',
      rating: 4.85,
      totalJobsCompleted: 142,
      isOnline: true,
      walletBalance: 3450.0,
      joinedAt: '2026-01-15',
    },
    {
      id: 'tech-002',
      technicianId: 'tech-002',
      fullName: 'Amit Kumar',
      phone: '+91 9123456780',
      category: 'PLUMBER',
      skills: ['Pipe Fitting', 'Tap Repair'],
      kycStatus: 'PENDING',
      rating: 4.60,
      totalJobsCompleted: 45,
      isOnline: true,
      walletBalance: 1200.0,
      joinedAt: '2026-03-10',
    },
  ];
  return res.json({ success: true, data: mockTechs });
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

// ─── BOOKINGS OVERSIGHT ──────────────────────────────────────────

const getBookings = async (req, res) => {
  const mockBookings = [
    {
      id: 'BK-102938',
      bookingCode: 'BK-102938',
      customerName: 'Sohan Roy',
      customerPhone: '+91 9831000000',
      technicianName: 'Rahul Sharma',
      serviceName: 'Switch & Socket Replacement',
      category: 'ELECTRICIAN',
      status: 'IN_PROGRESS',
      address: 'Salt Lake Sector 5, Kolkata',
      totalAmount: 299.0,
      createdAt: new Date().toISOString(),
    },
    {
      id: 'BK-102939',
      bookingCode: 'BK-102939',
      customerName: 'Priya Sen',
      customerPhone: '+91 9831111111',
      technicianName: 'Amit Kumar',
      serviceName: 'Tap / Faucet Leakage Repair',
      category: 'PLUMBER',
      status: 'COMPLETED',
      address: 'New Town Action Area 1, Kolkata',
      totalAmount: 199.0,
      createdAt: new Date().toISOString(),
    },
  ];
  return res.json({ success: true, data: mockBookings });
};

const updateBookingStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  return res.json({ success: true, message: `Booking status updated to ${status}`, id, status });
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
  const reviews = [
    { id: 'rev-01', customerName: 'Sohan Roy', technicianName: 'Rahul Sharma', rating: 5, comment: 'Great service, on time and clean work!', createdAt: new Date().toISOString(), hidden: false },
    { id: 'rev-02', customerName: 'Priya Sen', technicianName: 'Amit Kumar', rating: 4, comment: 'Fixed the tap quickly.', createdAt: new Date().toISOString(), hidden: false },
  ];
  return res.json({ success: true, data: reviews });
};

const getAuditLogs = async (req, res) => res.json({ success: true, data: adminAuditLogs });

const getPayments = async (req, res) => {
  const payments = [
    { id: 'pay-01', bookingId: 'BK-102939', amount: 199.0, method: 'UPI', status: 'SUCCESS', date: new Date().toISOString() },
  ];
  return res.json({ success: true, data: payments });
};

const getWithdrawals = async (req, res) => {
  const withdrawals = [
    { id: 'wth-01', technicianId: 'tech-001', technicianName: 'Rahul Sharma', amount: 2000.0, status: 'PENDING', upiId: 'rahul@okhdfcbank', requestedAt: new Date().toISOString() },
  ];
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
  getTechnicians,
  updateTechnicianStatus,
  getPendingKycList,
  reviewKyc,
  getBookings,
  updateBookingStatus,
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
