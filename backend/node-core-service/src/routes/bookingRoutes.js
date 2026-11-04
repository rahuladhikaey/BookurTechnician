const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/bookingController');
const dispatchController = require('../controllers/dispatchController');
const technicianController = require('../controllers/technicianController');
const { authenticateToken, optionalAuth } = require('../middleware/authMiddleware');

// Public or optional token routes
router.post('/', optionalAuth, bookingController.createBooking);
router.get('/available-slots', optionalAuth, dispatchController.getAvailableSlots);
router.get('/slots', optionalAuth, dispatchController.getAvailableSlots);
router.get('/customer', optionalAuth, bookingController.getCustomerBookings);
router.get('/my-bookings', optionalAuth, bookingController.getCustomerBookings);
router.get('/technician', optionalAuth, bookingController.getTechnicianBookings);
router.get('/live-tracking/:id', optionalAuth, bookingController.getBookingLiveTracking);
router.get('/:id/live-tracking', optionalAuth, bookingController.getBookingLiveTracking);
router.get('/:id', optionalAuth, bookingController.getBookingById);

// Lifecycle actions & OTP Operations
router.patch('/:id/status', optionalAuth, bookingController.updateBookingStatus);
router.patch('/:id', optionalAuth, bookingController.updateBookingStatus);
router.post('/:id/status', optionalAuth, bookingController.updateBookingStatus);
router.post('/:id/accept', optionalAuth, bookingController.acceptBooking);
router.post('/:id/arrive', authenticateToken, bookingController.markArrived);
router.post('/:id/cancel', optionalAuth, (req, res) => {
  req.body.status = 'CANCELLED';
  return bookingController.updateBookingStatus(req, res);
});
router.post('/:id/resend-start-otp', optionalAuth, bookingController.resendStartOtp);
router.post('/:id/verify-start-otp', optionalAuth, bookingController.verifyStartOtp);
router.post('/:id/start', optionalAuth, bookingController.verifyStartOtp);
router.post('/:id/resend-end-otp', optionalAuth, bookingController.resendEndOtp);
router.post('/:id/generate-end-otp', optionalAuth, bookingController.resendEndOtp);
router.post('/:id/add-bill', optionalAuth, bookingController.addBillCharges);
router.post('/:id/verify-end-otp', optionalAuth, bookingController.verifyEndOtp);
router.post('/:id/complete', optionalAuth, bookingController.verifyEndOtp);

// In-App P2P Chat & Masked Calling
router.get('/:id/messages', optionalAuth, bookingController.getBookingMessages);
router.post('/:id/messages', optionalAuth, bookingController.sendBookingMessage);
router.post('/:id/call-masked', authenticateToken, bookingController.initiateBookingCall);

// Add-ons Approval Engine
router.get('/:id/addons', optionalAuth, bookingController.getBookingAddons);
router.post('/:id/addons', optionalAuth, technicianController.createAddonCharge);
router.post('/:id/addons/:addonId/respond', optionalAuth, bookingController.respondToAddon);

// Proof of Work
router.get('/:id/proof', optionalAuth, bookingController.getBookingProof);
router.post('/:id/proof', optionalAuth, technicianController.uploadJobProofOfWork);

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
