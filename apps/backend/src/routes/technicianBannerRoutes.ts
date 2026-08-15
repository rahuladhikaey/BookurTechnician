import { Router, Request, Response } from 'express';
import { TechnicianBanner } from '../models/TechnicianBanner';

const router = Router();

// GET all active technician promotional banners ordered by displayOrder
router.get('/technician-banners', async (req: Request, res: Response) => {
  try {
    const now = new Date();
    const banners = await TechnicianBanner.find({
      isActive: true,
      startDate: { $lte: now },
      endDate: { $gte: now }
    }).sort({ displayOrder: 1 });

    res.json({
      success: true,
      count: banners.length,
      data: banners
    });
  } catch (error) {
    console.error('Failed to fetch technician banners:', error);
    res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
});

// Admin: Create or update a technician promotional banner
router.post('/technician-banners', async (req: Request, res: Response) => {
  try {
    const {
      bannerId,
      imageUrl,
      title,
      subtitle,
      ctaText,
      targetType,
      targetId,
      displayOrder,
      isActive,
      startDate,
      endDate
    } = req.body;

    const banner = await TechnicianBanner.findOneAndUpdate(
      { bannerId },
      {
        imageUrl,
        title,
        subtitle,
        ctaText,
        targetType,
        targetId,
        displayOrder,
        isActive: isActive !== undefined ? isActive : true,
        startDate: startDate ? new Date(startDate) : new Date(Date.now() - 24 * 60 * 60 * 1000),
        endDate: endDate ? new Date(endDate) : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
      },
      { new: true, upsert: true }
    );

    res.status(201).json({ success: true, data: banner });
  } catch (error) {
    console.error('Failed to save technician banner:', error);
    res.status(500).json({ success: false, error: 'Failed to create banner' });
  }
});

// Admin: Delete a technician promotional banner
router.delete('/technician-banners/:bannerId', async (req: Request, res: Response) => {
  try {
    const { bannerId } = req.params;
    await TechnicianBanner.findOneAndDelete({ bannerId });
    res.json({ success: true, message: `Banner ${bannerId} deleted successfully` });
  } catch (error) {
    console.error('Failed to delete technician banner:', error);
    res.status(500).json({ success: false, error: 'Failed to delete banner' });
  }
});

export default router;
