const express = require('express');
const router = express.Router();
const paymentsController = require('../controllers/paymentsController');

// Razorpay Order Creation & Verification
router.post('/create-order', paymentsController.createOrder);
router.post('/verify', paymentsController.verifySignature);
router.post('/verify-signature', paymentsController.verifySignature);
router.post('/webhook', paymentsController.handleWebhook);

module.exports = router;
