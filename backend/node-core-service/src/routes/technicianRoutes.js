const express = require('express');
const router = express.Router();
const technicianController = require('../controllers/technicianController');

// Location & Status
router.post('/location-sync', technicianController.syncLocation);
router.post('/toggle-status', technicianController.toggleOnlineStatus);

// Skills Management (Active for service dispatches)
router.get('/skills', technicianController.getSkills);
router.post('/skills/bulk', technicianController.saveSkillsBulk);
router.patch('/skills/:id/toggle', technicianController.toggleSkill);

// Profile Management
router.get('/profile', technicianController.getProfile);
router.patch('/profile', technicianController.updateProfile);

// Documents & KYC
router.get('/documents', technicianController.getDocuments);
router.post('/documents', technicianController.submitDocument);
router.post('/kyc', technicianController.submitDocument);

module.exports = router;
