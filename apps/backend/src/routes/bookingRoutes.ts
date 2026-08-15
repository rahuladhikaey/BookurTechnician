import { Router } from 'express';
import { dispatchBooking, createBooking, verifyStartOtp, verifyEndOtp } from '../controllers/bookingController';

const router = Router();

router.post('/dispatch', dispatchBooking);
router.post('/create', createBooking);
router.post('/verify-start', verifyStartOtp);
router.post('/verify-end', verifyEndOtp);

export default router;
