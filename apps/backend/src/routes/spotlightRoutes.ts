import { Router } from 'express';
import {
  getActiveBanners,
  getAllBanners,
  createBanner,
  updateBanner,
  deleteBanner
} from '../controllers/spotlightController';

const router = Router();

// Client-facing endpoint: Get active spotlight banners for home screen
router.get('/home', getActiveBanners);

// Admin-facing endpoints for Spotlight Banners management
router.get('/spotlight-banners', getAllBanners);
router.post('/spotlight-banners', createBanner);
router.put('/spotlight-banners/:id', updateBanner);
router.delete('/spotlight-banners/:id', deleteBanner);

export default router;
