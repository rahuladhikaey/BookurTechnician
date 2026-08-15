import { Router } from 'express';
import {
  getAllHeroBanners,
  createHeroBanner,
  updateHeroBanner,
  deleteHeroBanner
} from '../controllers/heroController';

const router = Router();

// Admin-facing endpoints for Hero Banners
router.get('/hero-banners', getAllHeroBanners);
router.post('/hero-banners', createHeroBanner);
router.put('/hero-banners/:id', updateHeroBanner);
router.delete('/hero-banners/:id', deleteHeroBanner);

export default router;
