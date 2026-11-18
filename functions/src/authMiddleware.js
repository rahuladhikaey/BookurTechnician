const admin = require('firebase-admin');
const { verifyJwt } = require('./jwtHelper');

/**
 * Authentication & Identity Middleware
 * Accepts Firebase ID Tokens and backend-signed session JWTs (when JWT_SECRET is configured),
 * plus emulator/test mock headers strictly in emulator or test environments.
 */
async function authenticate(req, res, next) {
  try {
    // 1. Emulator / Testing Mock Authentication
    const isEmulator =
      process.env.FUNCTIONS_EMULATOR === 'true' ||
      !!process.env.FIREBASE_AUTH_EMULATOR_HOST ||
      process.env.NODE_ENV === 'test';

    const mockUid = req.headers['x-mock-user-id'] || req.headers['x-technician-id'];
    if (isEmulator && mockUid) {
      const mockRole = String(req.headers['x-mock-role'] || 'TECHNICIAN').trim().toUpperCase();
      req.user = {
        uid: String(mockUid).trim(),
        email: req.headers['x-mock-email'] || `${mockUid}@bookurtechnician.com`,
        role: mockRole,
        admin: mockRole === 'ADMIN' || mockRole === 'SUPER_ADMIN',
        isMock: true,
      };
      return next();
    }

    // 2. Bearer Token Extraction
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        code: 'UNAUTHORIZED',
        error: 'Missing or malformed Authorization header (Bearer token required)',
      });
    }

    const token = authHeader.split('Bearer ')[1].trim();
    if (!token) {
      return res.status(401).json({
        success: false,
        code: 'UNAUTHORIZED',
        error: 'Empty Bearer token provided',
      });
    }

    // 3a. Primary: Verify Firebase ID Token (Client Firebase Auth)
    if (admin.apps.length > 0) {
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        const tokenRole = String(decodedToken.role || (decodedToken.admin ? 'ADMIN' : 'USER')).toUpperCase();
        req.user = {
          uid: decodedToken.uid,
          email: decodedToken.email || '',
          role: tokenRole,
          admin: decodedToken.admin === true || tokenRole === 'ADMIN' || tokenRole === 'SUPER_ADMIN',
          token: decodedToken,
        };
        return next();
      } catch (_) {
        // Fall through to backend session JWT verification if configured
      }
    }

    // 3b. Secondary: Verify backend-issued HS256 JWT (when JWT_SECRET is configured)
    const jwtSecret = (process.env.JWT_SECRET || '').trim();
    if (jwtSecret) {
      const payload = verifyJwt(token, jwtSecret);
      if (payload && (payload.uid || payload.id) && payload.tokenType !== 'refresh') {
        const role = String(payload.role || 'CUSTOMER').toUpperCase();
        req.user = {
          uid: String(payload.uid || payload.id).trim(),
          email: payload.email || '',
          role,
          admin: role === 'ADMIN' || role === 'SUPER_ADMIN',
          token: payload,
        };
        return next();
      }
    }

    return res.status(401).json({
      success: false,
      code: 'INVALID_TOKEN',
      error: 'Invalid or expired authentication token',
    });
  } catch (error) {
    console.error('Authentication verification error:', error.message);
    return res.status(401).json({
      success: false,
      code: 'INVALID_TOKEN',
      error: 'Invalid or expired authentication token',
    });
  }
}

function requireRole(allowedRoles = []) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', error: 'Authentication required' });
    }
    if (allowedRoles.length === 0) return next();
    const userRole = (req.user.role || '').toUpperCase();
    if (allowedRoles.includes(userRole) || (allowedRoles.includes('ADMIN') && req.user.admin)) {
      return next();
    }
    return res.status(403).json({
      success: false,
      code: 'FORBIDDEN',
      error: `Access denied. Required roles: ${allowedRoles.join(', ')}`,
    });
  };
}

module.exports = {
  authenticate,
  requireRole,
};

