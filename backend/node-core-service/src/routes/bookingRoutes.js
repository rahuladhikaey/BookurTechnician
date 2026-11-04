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
router.patch('/:id/status', authenticateToken, bookingController.updateBookingStatus);
router.patch('/:id', authenticateToken, bookingController.updateBookingStatus);
router.post('/:id/status', authenticateToken, bookingController.updateBookingStatus);
router.post('/:id/accept', authenticateToken, bookingController.acceptBooking);
router.post('/:id/arrive', authenticateToken, bookingController.markArrived);
router.post('/:id/cancel', authenticateToken, (req, res) => {
  req.body.status = 'CANCELLED';
  return bookingController.updateBookingStatus(req, res);
});
router.post('/:id/resend-start-otp', authenticateToken, bookingController.resendStartOtp);
router.post('/:id/verify-start-otp', authenticateToken, bookingController.verifyStartOtp);
router.post('/:id/start', authenticateToken, bookingController.verifyStartOtp);
router.post('/:id/resend-end-otp', authenticateToken, bookingController.resendEndOtp);
router.post('/:id/generate-end-otp', authenticateToken, bookingController.resendEndOtp);
router.post('/:id/add-bill', authenticateToken, bookingController.addBillCharges);
router.post('/:id/verify-end-otp', authenticateToken, bookingController.verifyEndOtp);
router.post('/:id/complete', authenticateToken, bookingController.verifyEndOtp);

// In-App P2P Chat & Masked Calling
router.get('/:id/messages', authenticateToken, bookingController.getBookingMessages);
router.post('/:id/messages', authenticateToken, bookingController.sendBookingMessage);
router.post('/:id/call-masked', authenticateToken, bookingController.initiateBookingCall);

// Add-ons Approval Engine
router.get('/:id/addons', authenticateToken, bookingController.getBookingAddons);
router.post('/:id/addons', authenticateToken, technicianController.createAddonCharge);
router.post('/:id/addons/:addonId/respond', authenticateToken, bookingController.respondToAddon);

// Proof of Work
router.get('/:id/proof', authenticateToken, bookingController.getBookingProof);
router.post('/:id/proof', authenticateToken, technicianController.uploadJobProofOfWork);

// Reviews & Ratings
router.post('/:id/reviews', authenticateToken, bookingController.submitBookingReview);
router.get('/:id/reviews', optionalAuth, bookingController.getBookingReview);

// 30-Day Service Guarantee & Warranty
router.post('/:id/warranty-claim', authenticateToken, bookingController.claimWarrantyRevisit);
router.get('/:id/warranty-status', optionalAuth, bookingController.getWarrantyStatus);

// GST Tax Invoice
router.get('/:id/invoice', optionalAuth, bookingController.getBookingInvoice);

// Deletion & Cancellation
router.delete('/my-bookings', authenticateToken, bookingController.clearCustomerBookings);
router.delete('/:id', authenticateToken, bookingController.deleteBooking);

module.exports = router;
