const express = require('express');
const router = express.Router();
const technicianController = require('../controllers/technicianController');
const bookingController = require('../controllers/bookingController');

const { authenticateToken, optionalAuth } = require('../middleware/authMiddleware');

// Location & Status
router.get('/nearby', technicianController.getNearbyTechnicians);
router.get('/count', technicianController.getNearbyTechnicians);
router.post('/location', optionalAuth, technicianController.syncLocation);
router.post('/location-sync', optionalAuth, technicianController.syncLocation);
router.post('/online-status', optionalAuth, technicianController.toggleOnlineStatus);
router.post('/toggle-status', optionalAuth, technicianController.toggleOnlineStatus);

// Jobs & Lifecycle for Technician App
router.get('/jobs', optionalAuth, bookingController.getTechnicianBookings);
router.patch('/jobs/:id/status', optionalAuth, bookingController.updateBookingStatus);
router.post('/jobs/:id/accept', optionalAuth, bookingController.acceptBooking);
router.post('/jobs/:id/verify-start-otp', optionalAuth, bookingController.verifyStartOtp);
router.post('/jobs/:id/verify-end-otp', optionalAuth, bookingController.verifyEndOtp);
router.post('/jobs/:id/resend-start-otp', optionalAuth, bookingController.resendStartOtp);
router.post('/jobs/:id/resend-end-otp', optionalAuth, bookingController.resendEndOtp);

// Skills Management (Active for service dispatches)
router.get('/skills', optionalAuth, technicianController.getSkills);
router.get('/skills/technician/:id', optionalAuth, technicianController.getSkills);
router.get('/skills/:id', optionalAuth, technicianController.getSkills);
router.post('/skills/bulk', optionalAuth, technicianController.saveSkillsBulk);
router.post('/skills', optionalAuth, technicianController.saveSkillsBulk);
router.put('/skills', optionalAuth, technicianController.saveSkillsBulk);
router.patch('/skills/:id/toggle', optionalAuth, technicianController.toggleSkill);

// Admin Skill & KYC Verification
router.post('/skills/admin/:id/verify', optionalAuth, technicianController.verifySkillAdmin);
router.post('/skills/admin/bulk-verify', optionalAuth, technicianController.verifySkillAdmin);
router.post('/skills/:id/verify', optionalAuth, technicianController.verifySkillAdmin);
router.post('/documents/admin/:id/verify', optionalAuth, technicianController.verifyDocumentAdmin);

// Profile Management
router.get('/profile', optionalAuth, technicianController.getProfile);
router.patch('/profile', optionalAuth, technicianController.updateProfile);
router.put('/profile', optionalAuth, technicianController.updateProfile);
router.post('/profile/photo', optionalAuth, technicianController.uploadProfilePhoto);

// Documents & KYC
router.get('/documents', optionalAuth, technicianController.getDocuments);
router.get('/documents/technician/:id', optionalAuth, technicianController.getDocuments);
router.get('/documents/:id', optionalAuth, technicianController.getDocuments);
router.post('/documents', optionalAuth, technicianController.submitDocument);
router.post('/documents/bulk', optionalAuth, technicianController.submitDocument);
router.post('/documents/upload', optionalAuth, technicianController.submitDocument);
router.post('/kyc', optionalAuth, technicianController.submitDocument);

// FCM Notifications
router.post('/fcm-token', (req, res) => res.json({ success: true, message: 'FCM Token registered' }));

module.exports = router;

