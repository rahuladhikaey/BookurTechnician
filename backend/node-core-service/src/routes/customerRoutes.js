const express = require('express');
const router = express.Router();
const customerController = require('../controllers/customerController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Enforce mandatory cryptographic authentication across all customer routes
router.use(authenticateToken);

// Customer Profile
router.get('/profile', customerController.getProfile);
router.put('/profile', customerController.updateProfile);
router.post('/profile', customerController.updateProfile);

// Customer Saved Service Addresses
router.get('/addresses', customerController.getAddresses);
router.post('/addresses', customerController.addAddress);
router.put('/addresses/:id', customerController.updateAddress);
router.delete('/addresses/:id', customerController.deleteAddress);

// Live GPS Location & Primary Address Sync
router.post('/location', customerController.updateLocation);

// FCM Device Token Registration
router.post('/fcm-token', customerController.registerFcmToken);

// Account Deletion (Google Play & Indus Appstore Compliance)
router.post('/account/delete', customerController.deleteAccount);
router.delete('/account', customerController.deleteAccount);

module.exports = router;

