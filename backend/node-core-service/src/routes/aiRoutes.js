const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');

router.post('/match', aiController.matchTechnicians);
router.post('/dynamic-pricing', aiController.computeDynamicPricing);
router.post('/diagnostics', aiController.diagnoseIssue);

module.exports = router;
