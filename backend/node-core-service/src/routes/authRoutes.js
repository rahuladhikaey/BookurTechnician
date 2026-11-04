const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

router.post('/request-otp', authController.requestOtp);
router.post('/resend-otp', authController.resendOtp);
router.post('/verify-otp', authController.verifyOtp);
router.post('/admin/direct-access', authController.adminDirectAccess);
router.post('/logout', authController.logout);

// Public Web Account Deletion (Google Play & Indus Appstore requirement)
router.post('/account-deletion-request', authController.submitAccountDeletionRequest);
router.get('/account-deletion-status/:requestId', authController.getAccountDeletionStatus);

module.exports = router;

