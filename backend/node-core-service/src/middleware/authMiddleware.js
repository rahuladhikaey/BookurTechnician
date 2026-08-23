const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_bookurtechnician_2026_secure';

/**
 * Authenticate JWT token from Authorization header (Bearer <token>)
 */
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    // Check if development master mode or allow public fallback for demo
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

/**
 * Role-Based Access Control (RBAC) Guard
 * @param  {...string} roles Allowed roles
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: `Forbidden: Requires one of [${roles.join(', ')}] permissions`,
      });
    }
    next();
  };
};

module.exports = { authenticateToken, requireRole };
