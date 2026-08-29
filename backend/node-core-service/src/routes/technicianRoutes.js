const express = require('express');
const router = express.Router();
const technicianController = require('../controllers/technicianController');

// Location & Status
router.get('/nearby', technicianController.getNearbyTechnicians);
router.get('/count', technicianController.getNearbyTechnicians);
router.post('/location', technicianController.syncLocation);
router.post('/location-sync', technicianController.syncLocation);
router.post('/online-status', technicianController.toggleOnlineStatus);
router.post('/toggle-status', technicianController.toggleOnlineStatus);

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

// Documents & KYC
router.get('/documents', technicianController.getDocuments);
router.get('/documents/technician/:id', technicianController.getDocuments);
router.get('/documents/:id', technicianController.getDocuments);
router.post('/documents', technicianController.submitDocument);
router.post('/documents/bulk', technicianController.submitDocument);
router.post('/kyc', technicianController.submitDocument);

// FCM Notifications
router.post('/fcm-token', (req, res) => res.json({ success: true, message: 'FCM Token registered' }));

module.exports = router;
