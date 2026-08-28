const express = require('express');
const router = express.Router();
const catalogController = require('../controllers/catalogController');

router.get('/categories', catalogController.getCatalog);
router.get('/hierarchy', catalogController.getCatalog);
router.get('/services', catalogController.getServices);

module.exports = router;
