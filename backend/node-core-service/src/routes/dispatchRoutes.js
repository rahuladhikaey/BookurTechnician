const express = require('express');
const router = express.Router();
const dispatchController = require('../controllers/dispatchController');
const { authenticateToken, optionalAuth, requireAdminRole } = require('../middleware/authMiddleware');

// ─── SECTION 17 REQUIRED DISPATCH ENDPOINTS ─────────────────────────────────

// Technician Active Offers
router.get('/offers', authenticateToken, dispatchController.getTechnicianOffers);
router.get('/pending', optionalAuth, dispatchController.getTechnicianOffers);
router.get('/proposals/pending', optionalAuth, dispatchController.getTechnicianOffers);
router.get('/proposals/:id', optionalAuth, dispatchController.getDispatchRequestById);

// Sequential Offer Accept / Reject (Authenticated Technician Ownership Verified)
router.post('/offers/:offerId/accept', authenticateToken, dispatchController.acceptDispatchOffer);
router.post('/offers/:offerId/reject', authenticateToken, dispatchController.rejectDispatchOffer);
router.post('/offers/:offerId/decline', authenticateToken, dispatchController.rejectDispatchOffer);

// Legacy proposal accept/decline routes (preserved for backward compatibility)
router.post('/proposals/:id/accept', optionalAuth, dispatchController.acceptDispatchOffer);
router.post('/proposals/:id/decline', optionalAuth, dispatchController.rejectDispatchOffer);
router.post('/:id/accept', optionalAuth, dispatchController.acceptDispatchOffer);
router.post('/:id/decline', optionalAuth, dispatchController.rejectDispatchOffer);

// Booking Dispatch Lifecycle: Status, Start, Retry & Admin Manual Assign
router.get('/:bookingId/status', optionalAuth, dispatchController.getDispatchStatus);
router.post('/:bookingId/start', authenticateToken, dispatchController.startDispatch);
router.post('/:bookingId/retry', authenticateToken, dispatchController.retryDispatch);
router.post('/:bookingId/manual-assign', authenticateToken, requireAdminRole, dispatchController.manualAssignDispatch);

// Direct Offer ID lookup
router.get('/:id', optionalAuth, dispatchController.getDispatchRequestById);

module.exports = router;
