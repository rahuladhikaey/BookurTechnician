const { getMasterCatalog, getFlattenedServices } = require('../config/masterCatalog');

/**
 * GET /api/v1/catalog/categories
 * Returns full live synchronized category and services hierarchy for Customer & Partner App
 */
const getCatalog = async (req, res) => {
  try {
    const categories = getMasterCatalog();
    return res.json({
      success: true,
      data: categories,
      categories: categories,
      count: categories.length,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/catalog/services
 * Returns flattened list of all services with live pricing and images
 */
const getServices = async (req, res) => {
  try {
    const services = getFlattenedServices();
    return res.json({
      success: true,
      data: services,
      services: services,
      count: services.length,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  getCatalog,
  getServices,
  DEFAULT_CATALOG: getMasterCatalog(),
};
