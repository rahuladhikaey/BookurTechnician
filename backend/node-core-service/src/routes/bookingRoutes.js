const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/bookingController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Public or optional token routes
router.post('/', bookingController.createBooking);
router.get('/customer', bookingController.getCustomerBookings);
router.get('/technician', bookingController.getTechnicianBookings);
router.get('/:id', bookingController.getBookingById);

// Lifecycle actions
router.post('/:id/accept', bookingController.acceptBooking);
router.post('/:id/verify-start-otp', bookingController.verifyStartOtp);
router.post('/:id/add-bill', bookingController.addBillCharges);
router.post('/:id/verify-end-otp', bookingController.verifyEndOtp);

module.exports = router;
