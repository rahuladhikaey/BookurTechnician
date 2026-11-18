const crypto = require('crypto');

function toBase64Url(input) {
  return Buffer.from(input).toString('base64url');
}

function signJwt(payload, secret, expiresInSeconds = 7 * 24 * 3600) {
  if (!secret) return null;
  const nowSec = Math.floor(Date.now() / 1000);
  const fullPayload = {
    ...payload,
    iat: nowSec,
    exp: nowSec + Number(expiresInSeconds || 3600),
  };
  const header = toBase64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = toBase64Url(JSON.stringify(fullPayload));
  const signature = crypto
    .createHmac('sha256', String(secret))
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${signature}`;
}

function verifyJwt(token, secret) {
  if (!token || !secret || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  const [headerB64, payloadB64, sigB64] = parts;
  try {
    const header = JSON.parse(Buffer.from(headerB64, 'base64url').toString('utf8'));
    if (header.alg !== 'HS256') return null;

    const expectedSig = crypto
      .createHmac('sha256', String(secret))
      .update(`${headerB64}.${payloadB64}`)
      .digest('base64url');

    const sigBuf = Buffer.from(sigB64);
    const expectedBuf = Buffer.from(expectedSig);
    if (sigBuf.length !== expectedBuf.length) return null;
    if (!crypto.timingSafeEqual(sigBuf, expectedBuf)) return null;

    const payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
    if (typeof payload.exp === 'number' && Math.floor(Date.now() / 1000) >= payload.exp) {
      return null;
    }
    return payload;
  } catch (_) {
    return null;
  }
}

module.exports = {
  signJwt,
  verifyJwt,
};
