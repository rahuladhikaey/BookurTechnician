/**
 * Enterprise Security Middleware for BookurTechnician
 * Features:
 * - Enterprise HTTP Security Headers (OWASP Top 10 API Security)
 * - Anti-Brute-Force & Adaptive Rate Limiting
 * - Input Sanitization & Anti-Prototype Pollution
 */

// In-memory sliding window rate limiter stores
const rateLimitBuckets = new Map();

/**
 * Enterprise Security Headers Middleware
 * Enforces HSTS, CSP, X-Frame-Options, X-Content-Type-Options & removes Express fingerprint
 */
const securityHeaders = (req, res, next) => {
  // 1. Remove Express server identification
  res.removeHeader('X-Powered-By');

  // 2. Transport & Framing Security
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

  // 3. Permissive Content Security Policy allowing necessary CDN scripts, fonts, and Socket.io websockets
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self' https: data: blob: 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https: wss: ws:; img-src 'self' https: data: blob:;"
  );

  next();
};

/**
 * Sliding Window Rate Limiting Factory
 * @param {Object} options Configuration options
 * @param {number} options.windowMs Window duration in milliseconds (default: 60,000 = 1 min)
 * @param {number} options.max Maximum allowed requests in window
 * @param {string} options.message Error message on limit exceeded
 */
const createRateLimiter = ({ windowMs = 60000, max = 120, message = 'Too many requests, please try again later.' } = {}) => {
  return (req, res, next) => {
    // Skip rate limiting during test executions if explicitly flagged
    if (process.env.DISABLE_RATE_LIMITER === 'true') {
      return next();
    }

    const ip = req.ip || req.headers['x-forwarded-for'] || req.socket.remoteAddress || '127.0.0.1';
    const key = `${req.baseUrl || req.path}:${ip}`;
    const now = Date.now();

    let bucket = rateLimitBuckets.get(key);
    if (!bucket) {
      bucket = { timestamps: [] };
      rateLimitBuckets.set(key, bucket);
    }

    // Filter timestamps within current window
    bucket.timestamps = bucket.timestamps.filter(ts => now - ts < windowMs);

    if (bucket.timestamps.length >= max) {
      const oldest = bucket.timestamps[0];
      const retryAfterSeconds = Math.ceil((windowMs - (now - oldest)) / 1000);
      res.setHeader('Retry-After', retryAfterSeconds);
      return res.status(429).json({
        success: false,
        error: message,
        retryAfter: retryAfterSeconds,
      });
    }

    bucket.timestamps.push(now);

    // Periodically clean up old buckets
    if (rateLimitBuckets.size > 10000) {
      for (const [k, b] of rateLimitBuckets.entries()) {
        if (b.timestamps.length === 0 || now - b.timestamps[b.timestamps.length - 1] > windowMs) {
          rateLimitBuckets.delete(k);
        }
      }
    }

    next();
  };
};

/**
 * Sensitive Endpoint Rate Limiter (e.g. OTP, Login, Password attempts)
 * 15 requests per minute per IP
 */
const authRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 15,
  message: 'Too many authentication attempts. Please wait 1 minute before retrying.',
});

/**
 * General Public API Rate Limiter
 * 200 requests per minute per IP
 */
const apiRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 200,
  message: 'API rate limit exceeded. Please throttle your requests.',
});

/**
 * Anti-Prototype Pollution & Null Byte Sanitization Middleware
 */
const sanitizeInputs = (req, res, next) => {
  const sanitize = (obj) => {
    if (!obj || typeof obj !== 'object') return obj;
    for (const key of Object.keys(obj)) {
      if (key === '__proto__' || key === 'constructor' || key === 'prototype') {
        delete obj[key];
        continue;
      }
      if (typeof obj[key] === 'string') {
        // Strip null bytes to prevent null byte poison attacks
        obj[key] = obj[key].replace(/\0/g, '');
      } else if (typeof obj[key] === 'object') {
        sanitize(obj[key]);
      }
    }
    return obj;
  };

  if (req.body) sanitize(req.body);
  if (req.query) sanitize(req.query);
  if (req.params) sanitize(req.params);

  next();
};

module.exports = {
  securityHeaders,
  createRateLimiter,
  authRateLimiter,
  apiRateLimiter,
  sanitizeInputs,
};

