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
router.patch('/:id/status', bookingController.updateBookingStatus);
router.patch('/:id', bookingController.updateBookingStatus);
router.post('/:id/status', bookingController.updateBookingStatus);
router.post('/:id/accept', bookingController.acceptBooking);
router.post('/:id/arrive', authenticateToken, bookingController.markArrived);
router.post('/:id/cancel', (req, res) => {
  req.body.status = 'CANCELLED';
  return bookingController.updateBookingStatus(req, res);
});
router.post('/:id/resend-start-otp', bookingController.resendStartOtp);
router.post('/:id/verify-start-otp', bookingController.verifyStartOtp);
router.post('/:id/start', bookingController.verifyStartOtp);
router.post('/:id/resend-end-otp', bookingController.resendEndOtp);
router.post('/:id/generate-end-otp', bookingController.resendEndOtp);
router.post('/:id/add-bill', bookingController.addBillCharges);
router.post('/:id/verify-end-otp', bookingController.verifyEndOtp);
router.post('/:id/complete', bookingController.verifyEndOtp);

// In-App P2P Chat & Masked Calling
router.get('/:id/messages', bookingController.getBookingMessages);
router.post('/:id/messages', bookingController.sendBookingMessage);
router.post('/:id/call-masked', authenticateToken, bookingController.initiateBookingCall);

// Add-ons Approval Engine
router.get('/:id/addons', bookingController.getBookingAddons);
router.post('/:id/addons/:addonId/respond', bookingController.respondToAddon);

// Proof of Work
router.get('/:id/proof', bookingController.getBookingProof);

// Reviews & Ratings
router.post('/:id/reviews', bookingController.submitBookingReview);
router.get('/:id/reviews', bookingController.getBookingReview);

// 30-Day Service Guarantee & Warranty
router.post('/:id/warranty-claim', bookingController.claimWarrantyRevisit);
router.get('/:id/warranty-status', bookingController.getWarrantyStatus);

// GST Tax Invoice
router.get('/:id/invoice', bookingController.getBookingInvoice);

// Deletion & Cancellation
router.delete('/my-bookings', bookingController.clearCustomerBookings);
router.delete('/:id', bookingController.deleteBooking);

module.exports = router;
