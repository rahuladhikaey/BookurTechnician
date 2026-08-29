const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');

// Overview & Executive Analytics
router.get('/overview', adminController.getOverview);
router.get('/stats', adminController.getOverview);

// Categories Management
router.get('/categories', adminController.getCategories);
router.post('/categories', adminController.createCategory);
router.put('/categories/:id', adminController.updateCategory);
router.delete('/categories/:id', adminController.deleteCategory);

// Services Management & Dynamic Pricing
router.get('/services', adminController.getServices);
router.post('/services', adminController.createService);
router.put('/services/:id', adminController.updateService);
router.delete('/services/:id', adminController.deleteService);
router.put('/pricing/:id', adminController.updatePricing);

// Real-time Bookings & Dispatch
router.get('/bookings', adminController.getBookings);
router.get('/bookings/:id/live-tracking', adminController.getBookingLiveTracking);
router.patch('/bookings/:id/status', adminController.updateBookingStatus);
router.put('/bookings/:id/status', adminController.updateBookingStatus);
router.post('/bookings/:id/assign', adminController.assignBooking);
router.post('/bookings/:id/cancel', adminController.cancelBooking);
router.delete('/bookings/:id', adminController.deleteBooking);
router.delete('/bookings', adminController.clearAllBookings);

// Customers Management
router.get('/customers', adminController.getCustomers);

// Technicians Management & KYC
router.get('/technicians', adminController.getTechnicians);
router.patch('/technicians/:id/status', adminController.updateTechnicianStatus);
router.patch('/technicians/:id/kyc', adminController.updateTechnicianKyc);
router.put('/technicians/:id/kyc', adminController.updateTechnicianKyc);
router.get('/kyc-pending', adminController.getPendingKycList);
router.post('/kyc-review', adminController.reviewKyc);

// Banners
router.get('/banners', adminController.getBanners);
router.post('/banners', adminController.createBanner);
router.delete('/banners/:id', adminController.deleteBanner);

// Reviews, Payments, Withdrawals, Support, Notifications, Audit Logs
router.get('/reviews', adminController.getReviews);
router.get('/payments', adminController.getPayments);
router.get('/withdrawals', adminController.getWithdrawals);
router.patch('/withdrawals/:id/status', adminController.updateWithdrawalStatus);
router.get('/support/tickets', adminController.getSupportTickets);
router.get('/notifications/history', adminController.getNotificationsHistory);
router.post('/notifications', adminController.createNotification);
router.get('/audit-logs', adminController.getAuditLogs);

module.exports = router;