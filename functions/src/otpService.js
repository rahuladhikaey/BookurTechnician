const crypto = require('crypto');

/**
 * Cryptographic OTP Service
 * HMAC-SHA256 salted hashing with attempt tracking & lockout protection.
 * Plaintext OTPs are NEVER stored in public collections.
 */

function generateOtp(length = 4) {
  const min = Math.pow(10, length - 1);
  const max = Math.pow(10, length);
  return String(crypto.randomInt(min, max));
}

function generateSalt() {
  return crypto.randomBytes(16).toString('hex');
}

function hashOtp(otp, salt) {
  return crypto.createHmac('sha256', salt).update(String(otp).trim()).digest('hex');
}

async function createBookingSecrets(db, bookingId, startOtp, endOtp, transaction = null) {
  const salt = generateSalt();
  const startOtpHash = hashOtp(startOtp, salt);
  const endOtpHash = hashOtp(endOtp, salt);

  const secretsRef = db.collection('booking_secrets').doc(bookingId);
  const secretData = {
    bookingId,
    salt,
    startOtpHash,
    endOtpHash,
    failedStartAttempts: 0,
    failedEndAttempts: 0,
    startLockedOut: false,
    endLockedOut: false,
    startVerifiedAt: null,
    endVerifiedAt: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  if (transaction) {
    transaction.set(secretsRef, secretData);
  } else {
    await secretsRef.set(secretData);
  }

  return { salt, startOtpHash, endOtpHash };
}

module.exports = {
  generateOtp,
  generateSalt,
  hashOtp,
  createBookingSecrets,
};

