const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/bookingController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Public or optional token routes
router.post('/', bookingController.createBooking);
router.get('/customer', bookingController.getCustomerBookings);
router.get('/my-bookings', bookingController.getCustomerBookings);
router.get('/technician', bookingController.getTechnicianBookings);
router.get('/live-tracking/:id', bookingController.getBookingLiveTracking);
router.get('/:id/live-tracking', bookingController.getBookingLiveTracking);
router.get('/:id', bookingController.getBookingById);

// Lifecycle actions & OTP Operations
router.post('/:id/accept', bookingController.acceptBooking);
router.post('/:id/resend-start-otp', bookingController.resendStartOtp);
router.post('/:id/verify-start-otp', bookingController.verifyStartOtp);
router.post('/:id/resend-end-otp', bookingController.resendEndOtp);
router.post('/:id/generate-end-otp', bookingController.resendEndOtp);
router.post('/:id/add-bill', bookingController.addBillCharges);
router.post('/:id/verify-end-otp', bookingController.verifyEndOtp);
router.patch('/:id/status', bookingController.updateBookingStatus);

module.exports = router;
