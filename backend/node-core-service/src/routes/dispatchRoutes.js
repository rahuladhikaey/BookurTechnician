const express = require('express');
const router = express.Router();
const dispatchController = require('../controllers/dispatchController');
const { optionalAuth } = require('../middleware/authMiddleware');

// Proposals & Dispatch Requests
router.get('/pending', optionalAuth, dispatchController.getPendingDispatchRequests);
router.get('/proposals/pending', optionalAuth, dispatchController.getPendingDispatchRequests);
router.get('/proposals/:id', optionalAuth, dispatchController.getDispatchRequestById);
router.post('/proposals/:id/accept', optionalAuth, dispatchController.acceptDispatchRequest);
router.post('/proposals/:id/decline', optionalAuth, dispatchController.declineDispatchRequest);

router.get('/:id', optionalAuth, dispatchController.getDispatchRequestById);
router.post('/:id/accept', optionalAuth, dispatchController.acceptDispatchRequest);
router.post('/:id/decline', optionalAuth, dispatchController.declineDispatchRequest);

module.exports = router;
