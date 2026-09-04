const express = require('express');
const router = express.Router();
const technicianController = require('../controllers/technicianController');
const bookingController = require('../controllers/bookingController');

const { authenticateToken } = require('../middleware/authMiddleware');

// Location & Status
router.get('/nearby', technicianController.getNearbyTechnicians);
router.get('/count', technicianController.getNearbyTechnicians);
router.post('/location', authenticateToken, technicianController.syncLocation);
router.post('/location-sync', authenticateToken, technicianController.syncLocation);
router.post('/online-status', authenticateToken, technicianController.toggleOnlineStatus);
router.post('/toggle-status', authenticateToken, technicianController.toggleOnlineStatus);

// Jobs & Lifecycle for Technician App
router.get('/jobs', bookingController.getTechnicianBookings);
router.patch('/jobs/:id/status', bookingController.updateBookingStatus);
router.post('/jobs/:id/accept', bookingController.acceptBooking);
router.post('/jobs/:id/verify-start-otp', bookingController.verifyStartOtp);
router.post('/jobs/:id/verify-end-otp', bookingController.verifyEndOtp);
router.post('/jobs/:id/resend-start-otp', bookingController.resendStartOtp);
router.post('/jobs/:id/resend-end-otp', bookingController.resendEndOtp);

// Skills Management (Active for service dispatches)
router.get('/skills', technicianController.getSkills);
router.get('/skills/technician/:id', technicianController.getSkills);
router.get('/skills/:id', technicianController.getSkills);
router.post('/skills/bulk', technicianController.saveSkillsBulk);
router.post('/skills', technicianController.saveSkillsBulk);
router.put('/skills', technicianController.saveSkillsBulk);
router.patch('/skills/:id/toggle', technicianController.toggleSkill);

// Profile Management
router.get('/profile', technicianController.getProfile);
router.patch('/profile', technicianController.updateProfile);
router.put('/profile', technicianController.updateProfile);
router.post('/profile/photo', technicianController.uploadProfilePhoto);

// Documents & KYC
router.get('/documents', technicianController.getDocuments);
router.get('/documents/technician/:id', technicianController.getDocuments);
router.get('/documents/:id', technicianController.getDocuments);
router.post('/documents', technicianController.submitDocument);
router.post('/documents/bulk', technicianController.submitDocument);
router.post('/documents/upload', technicianController.submitDocument);
router.post('/kyc', technicianController.submitDocument);

// FCM Notifications
router.post('/fcm-token', (req, res) => res.json({ success: true, message: 'FCM Token registered' }));

module.exports = router;
