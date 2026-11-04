const express = require('express');
const router = express.Router();
const technicianController = require('../controllers/technicianController');
const bookingController = require('../controllers/bookingController');

const { authenticateToken, optionalAuth, requireAdminRole } = require('../middleware/authMiddleware');

// Location, Availability & Status
const dispatchController = require('../controllers/dispatchController');
router.get('/availability', optionalAuth, dispatchController.getTechniciansAvailability);
router.post('/availability', authenticateToken, dispatchController.updateTechnicianAvailability);
router.put('/availability', authenticateToken, dispatchController.updateTechnicianAvailability);
router.get('/slots', optionalAuth, dispatchController.getAvailableSlots);
router.get('/available-slots', optionalAuth, dispatchController.getAvailableSlots);
router.get('/offers', authenticateToken, dispatchController.getTechnicianOffers);
router.get('/nearby', technicianController.getNearbyTechnicians);
router.get('/count', technicianController.getNearbyTechnicians);
router.post('/location', optionalAuth, technicianController.syncLocation);
router.post('/location-sync', optionalAuth, technicianController.syncLocation);
router.post('/online-status', optionalAuth, technicianController.toggleOnlineStatus);
router.post('/toggle-status', optionalAuth, technicianController.toggleOnlineStatus);

// Tier Membership & Analytics
router.get('/tier-status', optionalAuth, technicianController.getTierStatus);
router.get('/analytics/overview', optionalAuth, technicianController.getAnalyticsOverview);
router.get('/analytics/work-hours', optionalAuth, technicianController.getAnalyticsOverview);
router.post('/shift/heartbeat', optionalAuth, technicianController.logWorkHeartbeat);

// Wallet & Instant Withdrawal (Cryptographically Authenticated)
router.post('/withdraw', authenticateToken, technicianController.withdrawEarnings);
router.get('/wallet', authenticateToken, technicianController.getWalletLedger);
router.get('/wallet/ledger', authenticateToken, technicianController.getWalletLedger);

// Jobs & Lifecycle for Technician App
router.get('/jobs', authenticateToken, bookingController.getTechnicianBookings);
router.patch('/jobs/:id/status', authenticateToken, bookingController.updateBookingStatus);
router.post('/jobs/:id/accept', authenticateToken, bookingController.acceptBooking);
router.post('/jobs/:id/verify-start-otp', authenticateToken, bookingController.verifyStartOtp);
router.post('/jobs/:id/verify-end-otp', authenticateToken, bookingController.verifyEndOtp);
router.post('/jobs/:id/resend-start-otp', authenticateToken, bookingController.resendStartOtp);
router.post('/jobs/:id/resend-end-otp', authenticateToken, bookingController.resendEndOtp);
router.post('/jobs/:id/proof', authenticateToken, technicianController.uploadJobProofOfWork);
router.post('/jobs/:id/addons', authenticateToken, technicianController.createAddonCharge);
router.post('/jobs/:id/rate', authenticateToken, technicianController.rateCustomer);

// Real-Time Dispatch Requests & Proposals
router.get('/dispatch/pending', authenticateToken, dispatchController.getPendingDispatchRequests);
router.get('/dispatch/:id', authenticateToken, dispatchController.getDispatchRequestById);
router.post('/dispatch/:id/accept', authenticateToken, dispatchController.acceptDispatchRequest);
router.post('/dispatch/:id/decline', authenticateToken, dispatchController.declineDispatchRequest);
router.get('/proposals/pending', authenticateToken, dispatchController.getPendingDispatchRequests);
router.post('/proposals/:id/accept', authenticateToken, dispatchController.acceptDispatchRequest);
router.post('/proposals/:id/decline', authenticateToken, dispatchController.declineDispatchRequest);

// Skills Management (Active for service dispatches)
router.get('/skills', optionalAuth, technicianController.getSkills);
router.get('/skills/technician/:id', optionalAuth, technicianController.getSkills);
router.get('/skills/:id', optionalAuth, technicianController.getSkills);
router.post('/skills/bulk', authenticateToken, technicianController.saveSkillsBulk);
router.post('/skills', authenticateToken, technicianController.saveSkillsBulk);
router.put('/skills', authenticateToken, technicianController.saveSkillsBulk);
router.patch('/skills/:id/toggle', authenticateToken, technicianController.toggleSkill);

// Admin Skill & KYC Verification (Strict Admin RBAC)
router.post('/skills/admin/:id/verify', authenticateToken, requireAdminRole, technicianController.verifySkillAdmin);
router.post('/skills/admin/bulk-verify', authenticateToken, requireAdminRole, technicianController.verifySkillAdmin);
router.post('/skills/:id/verify', authenticateToken, requireAdminRole, technicianController.verifySkillAdmin);
router.post('/documents/admin/:id/verify', authenticateToken, requireAdminRole, technicianController.verifyDocumentAdmin);

// Profile Management
router.get('/profile', authenticateToken, technicianController.getProfile);
router.patch('/profile', authenticateToken, technicianController.updateProfile);
router.put('/profile', authenticateToken, technicianController.updateProfile);
router.post('/profile/photo', authenticateToken, technicianController.uploadProfilePhoto);

// Documents & KYC (Strict Authentication & Private Access)
router.get('/documents', authenticateToken, technicianController.getDocuments);
router.get('/documents/technician/:id', authenticateToken, technicianController.getDocuments);
router.get('/documents/:id', authenticateToken, technicianController.getDocuments);
router.post('/documents', authenticateToken, technicianController.submitDocument);
router.post('/documents/bulk', authenticateToken, technicianController.submitDocument);
router.post('/documents/upload', authenticateToken, technicianController.submitDocument);
router.post('/kyc', authenticateToken, technicianController.submitDocument);

// FCM Notifications
router.post('/fcm-token', optionalAuth, technicianController.registerFcmToken);

// Account Deletion (Google Play & Indus Appstore Compliance)
router.post('/account/delete', optionalAuth, technicianController.deleteAccount);
router.delete('/account', optionalAuth, technicianController.deleteAccount);

module.exports = router;


