const admin = require('firebase-admin');

/**
 * Authentication & Identity Middleware
 * Pure Firebase Architecture (Token Verification + Emulator Mocking)
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
      req.user = {
        uid: String(mockUid).trim(),
        email: req.headers['x-mock-email'] || `${mockUid}@bookurtechnician.com`,
        role: req.headers['x-mock-role'] || 'TECHNICIAN',
        isMock: true,
      };
      return next();
    }

    // 2. Production Firebase ID Token Authentication
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        code: 'UNAUTHORIZED',
        error: 'Missing or malformed Authorization header (Bearer token required)',
      });
    }

    const idToken = authHeader.split('Bearer ')[1].trim();
    if (!idToken) {
      return res.status(401).json({
        success: false,
        code: 'UNAUTHORIZED',
        error: 'Empty Bearer token provided',
      });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email || '',
      role: decodedToken.role || (decodedToken.admin ? 'ADMIN' : 'USER'),
      admin: decodedToken.admin === true,
      token: decodedToken,
    };
    next();
  } catch (error) {
    console.error('Authentication verification error:', error.message);
    return res.status(401).json({
      success: false,
      code: 'INVALID_TOKEN',
      error: 'Invalid or expired Firebase authentication token',
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

