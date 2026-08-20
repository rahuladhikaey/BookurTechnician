const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { requireAdminOrDispatcher } = require('../middleware/rbacGuard');

// All admin endpoints are protected by RBAC Guard (SUPER_ADMIN or DISPATCHER)
router.use(requireAdminOrDispatcher);

// 1. Overview Dashboard Stats
router.get('/stats/overview', adminController.getAdminOverviewStats);

// 2. Live Booking Radar & Pipeline
router.get('/bookings/live', adminController.getLiveBookings);
router.get('/bookings/:bookingId/nearby-technicians', adminController.getNearbyActiveTechnicians);

// 3. Dispatch Control Tower (Force Assign)
router.post('/bookings/:bookingId/force-assign', adminController.forceAssignTechnician);

// 4. Financial Ledger & Wallet Settlements
router.post('/payouts/release', adminController.releasePayout);
router.get('/payouts/history/:technicianId?', adminController.getPayoutHistory);

// 5. Partner Governance & Compliance (KYC)
router.patch('/partners/:partnerId/status', adminController.updatePartnerStatus);

// 6. Dispute Resolution & Emergency OTP Bypass
router.post('/bookings/:bookingId/bypass-otp', adminController.bypassOtp);

module.exports = router;
