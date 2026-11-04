const jwt = require('jsonwebtoken');
const { verifyFirebaseIdToken } = require('../config/firebase');
const postgres = require('../config/postgres');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_bookurtechnician_2026_secure';

/**
 * Resilient token parsing - extracts user payload from JWT or Firebase ID Token
 */
async function resolveUserFromToken(token, req) {
  if (!token) return null;

  // 1. First check standard backend JWT
  try {
    const verified = jwt.verify(token, JWT_SECRET);
    if (verified) return verified;
  } catch (_) {}

  // 2. Check if it's a Firebase ID Token
  try {
    const fbUser = await verifyFirebaseIdToken(token);
    if (fbUser && fbUser.uid) {
      // Lookup internal user in PostgreSQL
      if (postgres.isPgHealthy()) {
        const dbRes = await postgres.query(
          'SELECT id, role, is_suspended, full_name, phone, email FROM users WHERE firebase_uid = $1 OR id = $1',
          [fbUser.uid]
        );
        if (dbRes.rows.length > 0) {
          const userRow = dbRes.rows[0];
          if (userRow.is_suspended) {
            return { error: 'ACCOUNT_SUSPENDED' };
          }
          return {
            id: userRow.id,
            firebaseUid: fbUser.uid,
            role: userRow.role,
            phone: userRow.phone,
            email: userRow.email,
            name: userRow.full_name,
          };
        }
      }
      return {
        id: fbUser.uid,
        firebaseUid: fbUser.uid,
        role: 'CUSTOMER',
        phone: fbUser.phone_number,
        email: fbUser.email,
      };
    }
  } catch (_) {}

  // 3. Reject unverified tokens and header-based identity forging in production
  if (process.env.NODE_ENV === 'development' && process.env.ALLOW_DEV_HEADERS === 'true') {
    const techIdHeader = req.headers['x-technician-id'] || req.headers['x-user-id'];
    if (techIdHeader) {
      return { id: techIdHeader, role: req.headers['x-user-role'] || 'TECHNICIAN' };
    }
  }

  return null;
}

/**
 * Authenticate JWT or Firebase ID token from Authorization header (Bearer <token>)
 * Zero-trust: Identity MUST originate from verified cryptographic signature
 */
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Bearer authentication token required' });
  }

  const user = await resolveUserFromToken(token, req);
  if (!user) {
    return res.status(403).json({ success: false, error: 'Forbidden: Invalid, tampered, or expired access token' });
  }

  if (user.error === 'ACCOUNT_SUSPENDED') {
    return res.status(403).json({ success: false, error: 'Account has been suspended by administration.' });
  }

  req.user = user;
  next();
};

/**
 * Optional Auth - extracts user if verified token present, does NOT allow unverified header forging
 */
const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (token) {
    const user = await resolveUserFromToken(token, req);
    if (user && !user.error) {
      req.user = user;
    }
  }
  next();
};

/**
 * Role-Based Access Control (RBAC) Guard
 * @param  {...string} roles Allowed roles (case-insensitive)
 */
const requireRole = (...roles) => {
  const normalizedRoles = roles.map(r => r.toUpperCase());
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(401).json({ success: false, error: 'Unauthorized: Authentication required' });
    }
    const userRole = String(req.user.role).toUpperCase();
    if (!normalizedRoles.includes(userRole) && userRole !== 'ADMIN' && userRole !== 'SUPER_ADMIN') {
      return res.status(403).json({
        success: false,
        error: `Forbidden: Requires one of [${roles.join(', ')}] permissions`,
      });
    }
    next();
  };
};

/**
 * Granular Role Constants
 */
const ADMIN_ROLES = [
  'SUPER_ADMIN',
  'ADMIN',
  'OPERATIONS_ADMIN',
  'BOOKING_MANAGER',
  'VERIFICATION_ADMIN',
  'FINANCE_ADMIN',
  'CUSTOMER_SUPPORT',
  'READ_ONLY_AUDITOR',
];

/**
 * Strict Admin-Only Guard (Accepts Super Admin, Admin, and Granular Admin Sub-roles)
 */
const requireAdminRole = (req, res, next) => {
  const userRole = String(req.user?.role || '').toUpperCase();
  if (!req.user || (!ADMIN_ROLES.includes(userRole) && userRole !== 'ADMIN' && userRole !== 'SUPER_ADMIN')) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Administrative authorization required',
    });
  }

  // Prevent Read-Only Auditor from performing state-modifying actions
  if (userRole === 'READ_ONLY_AUDITOR' && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Read-Only Auditor is not permitted to perform data modifications.',
    });
  }

  next();
};

/**
 * Strict Super Admin Guard (Critical infrastructure & configuration operations)
 */
const requireSuperAdminRole = (req, res, next) => {
  const userRole = String(req.user?.role || '').toUpperCase();
  if (!req.user || userRole !== 'SUPER_ADMIN') {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Super Administrator authorization strictly required',
    });
  }
  next();
};

/**
 * Finance Admin Guard (Payouts, Ledger, Withdrawals)
 */
const requireFinanceRole = (req, res, next) => {
  const userRole = String(req.user?.role || '').toUpperCase();
  const allowed = ['SUPER_ADMIN', 'ADMIN', 'FINANCE_ADMIN'];
  if (!req.user || !allowed.includes(userRole)) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Finance Administrator authorization required for financial operations',
    });
  }
  next();
};

/**
 * Verification Admin Guard (KYC, Document Review, Skill Verification)
 */
const requireVerificationRole = (req, res, next) => {
  const userRole = String(req.user?.role || '').toUpperCase();
  const allowed = ['SUPER_ADMIN', 'ADMIN', 'OPERATIONS_ADMIN', 'VERIFICATION_ADMIN'];
  if (!req.user || !allowed.includes(userRole)) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden: Verification Administrator authorization required',
    });
  }
  next();
};

module.exports = {
  authenticateToken,
  optionalAuth,
  requireRole,
  requireAdminRole,
  requireSuperAdminRole,
  requireFinanceRole,
  requireVerificationRole,
  resolveUserFromToken,
  JWT_SECRET,
  ADMIN_ROLES,
};

