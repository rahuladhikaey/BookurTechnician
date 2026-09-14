const express = require('express');
const router = express.Router();
const catalogController = require('../controllers/catalogController');

router.get('/categories', catalogController.getCatalog);
router.get('/hierarchy', catalogController.getHierarchy);
router.get('/services', catalogController.getServices);
router.get('/availability', catalogController.getAvailability);
router.get('/availability/:serviceId', catalogController.getSingleServiceAvailability);
router.get('/services/:serviceId/availability', catalogController.getSingleServiceAvailability);
router.get('/:serviceId/availability', catalogController.getSingleServiceAvailability);
router.get('/technicians/nearby', catalogController.getNearbyTechniciansByService);

module.exports = router;
