const express = require('express');
const router = express.Router();
const {
  createBooking,
  acceptBooking,
  verifyStartOtp,
  resendEndEmail,
  verifyEndOtp,
} = require('../controllers/bookingController');

router.post('/create', createBooking);
router.post('/accept', acceptBooking);
router.post('/verify-start-otp', verifyStartOtp);
router.post('/resend-end-email', resendEndEmail);
router.post('/verify-end-otp', verifyEndOtp);

module.exports = router;
