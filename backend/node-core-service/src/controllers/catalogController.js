const MongoCatalog = require('../models/MongoCatalog');

const DEFAULT_CATALOG = [
  {
    categoryId: 'electrician',
    name: 'Electrician Services',
    icon: 'flash_on',
    services: [
      { id: 'elec-01', title: 'Switch & Socket Replacement', basePrice: 149, estimatedDurationMins: 30 },
      { id: 'elec-02', title: 'Fan Installation / Repair', basePrice: 249, estimatedDurationMins: 45 },
      { id: 'elec-03', title: 'Full House Wiring Checkup', basePrice: 599, estimatedDurationMins: 90 },
      { id: 'elec-04', title: 'MCB Fuse Tripping Repair', basePrice: 299, estimatedDurationMins: 40 },
    ],
  },
  {
    categoryId: 'plumber',
    name: 'Plumber Services',
    icon: 'plumbing',
    services: [
      { id: 'plum-01', title: 'Tap / Faucet Leakage Repair', basePrice: 199, estimatedDurationMins: 30 },
      { id: 'plum-02', title: 'Toilet Flush Tank Repair', basePrice: 349, estimatedDurationMins: 45 },
      { id: 'plum-03', title: 'Water Tank Pipe Fitting', basePrice: 699, estimatedDurationMins: 120 },
    ],
  },
  {
    categoryId: 'carpenter',
    name: 'Carpenter Services',
    icon: 'handyman',
    services: [
      { id: 'carp-01', title: 'Door Lock Installation / Repair', basePrice: 299, estimatedDurationMins: 45 },
      { id: 'carp-02', title: 'Furniture Assembly', basePrice: 499, estimatedDurationMins: 60 },
      { id: 'carp-03', title: 'Cupboard Hinge Fixing', basePrice: 199, estimatedDurationMins: 30 },
    ],
  },
  {
    categoryId: 'ac_repair',
    name: 'AC Repair & Service',
    icon: 'ac_unit',
    services: [
      { id: 'ac-01', title: 'AC Foam Jet Deep Cleaning', basePrice: 599, estimatedDurationMins: 60 },
      { id: 'ac-02', title: 'AC Gas Refill & Leak Check', basePrice: 1899, estimatedDurationMins: 90 },
      { id: 'ac-03', title: 'AC Installation / Uninstallation', basePrice: 1199, estimatedDurationMins: 75 },
    ],
  },
];

/**
 * GET /api/v1/catalog/categories
 */
const getCatalog = async (req, res) => {
  try {
    let categories = [];
    try {
      categories = await MongoCatalog.find();
    } catch (e) {}

    if (!categories || categories.length === 0) {
      categories = DEFAULT_CATALOG;
    }

    return res.json({ success: true, categories });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = { getCatalog, DEFAULT_CATALOG };
