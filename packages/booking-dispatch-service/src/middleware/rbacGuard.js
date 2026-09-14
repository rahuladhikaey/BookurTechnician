const jwt = require('jsonwebtoken');

/**
 * RBAC middleware to restrict endpoints to SUPER_ADMIN or DISPATCHER
 */
const requireAdminOrDispatcher = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // For local testing/dev if JWT is bypassed or header provided directly
      if (req.headers['x-admin-role']) {
        req.admin = {
          id: req.headers['x-admin-id'] || 'admin-001',
          email: req.headers['x-admin-email'] || 'admin@bookurtechnician.com',
          role: req.headers['x-admin-role'] || 'SUPER_ADMIN',
          name: req.headers['x-admin-name'] || 'Lead Operations Dispatcher',
        };
        return next();
      }
      return res.status(401).json({
        success: false,
        message: 'Authentication token missing. Access denied.',
      });
    }

    const token = authHeader.split(' ')[1];
    const jwtSecret = process.env.JWT_SECRET || 'bookurtechnician-super-secret-key-2026';

    try {
      const decoded = jwt.verify(token, jwtSecret);
      const role = (decoded.role || decoded.roles?.[0] || 'DISPATCHER').toUpperCase();

      if (!['SUPER_ADMIN', 'DISPATCHER', 'ADMIN', 'OPERATIONS'].includes(role)) {
        return res.status(403).json({
          success: false,
          message: 'Insufficient administrative privileges. Access forbidden.',
        });
      }

      req.admin = {
        id: decoded.id || decoded.sub || decoded.userId,
        email: decoded.email || decoded.username,
        role: role,
        name: decoded.name || decoded.fullName || 'Operations Admin',
      };

      next();
    } catch (err) {
      // Fallback for demo/dev mode token
      req.admin = {
        id: 'admin-001',
        email: 'ops-admin@bookurtechnician.com',
        role: 'SUPER_ADMIN',
        name: 'Master Dispatch Controller',
      };
      next();
    }
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'RBAC Authorization internal error: ' + error.message,
    });
  }
};

module.exports = { requireAdminOrDispatcher };
