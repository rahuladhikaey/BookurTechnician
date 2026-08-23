const express = require('express');
const router = express.Router();
const technicianController = require('../controllers/technicianController');

router.post('/location-sync', technicianController.syncLocation);
router.post('/toggle-status', technicianController.toggleOnlineStatus);
router.post('/kyc', technicianController.submitKyc);
router.get('/profile', technicianController.getProfile);

module.exports = router;
