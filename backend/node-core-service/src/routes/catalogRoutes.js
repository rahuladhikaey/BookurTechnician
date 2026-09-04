const express = require('express');
const router = express.Router();
const catalogController = require('../controllers/catalogController');

router.get('/categories', catalogController.getCatalog);
router.get('/hierarchy', catalogController.getHierarchy);
router.get('/services', catalogController.getServices);
router.get('/availability', catalogController.getAvailability);

module.exports = router;
