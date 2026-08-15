import { Request, Response } from 'express';
import { HeroBanner } from '../models/HeroBanner';

// Admin: Get all hero banners
export const getAllHeroBanners = async (req: Request, res: Response) => {
  try {
    const banners = await HeroBanner.find().sort({ displayOrder: 1 });
    
    const formattedBanners = banners.map(banner => ({
      id: banner._id.toString(),
      title: banner.title,
      subtitle: banner.subtitle,
      badgeText: banner.badgeText,
      ctaText: banner.ctaText,
      imageUrl: banner.imageUrl,
      targetServiceId: banner.targetServiceId || "",
      displayOrder: banner.displayOrder,
      active: banner.active,
      startDate: banner.startDate,
      endDate: banner.endDate,
      createdAt: banner.createdAt,
      updatedAt: banner.updatedAt
    }));

    return res.status(200).json({
      success: true,
      banners: formattedBanners
    });
  } catch (error: any) {
    console.error('Error fetching all hero banners:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};

// Admin: Create a new hero banner
export const createHeroBanner = async (req: Request, res: Response) => {
  try {
    const {
      title,
      subtitle,
      badgeText,
      ctaText,
      imageUrl,
      targetServiceId,
      displayOrder,
      active,
      startDate,
      endDate
    } = req.body;

    if (!title || !subtitle || !badgeText || !ctaText || !imageUrl || !startDate || !endDate) {
      return res.status(400).json({ error: 'Missing required fields for hero banner.' });
    }

    const banner = new HeroBanner({
      title,
      subtitle,
      badgeText,
      ctaText,
      imageUrl,
      targetServiceId: targetServiceId || "",
      displayOrder: displayOrder !== undefined ? Number(displayOrder) : 0,
      active: active !== undefined ? Boolean(active) : true,
      startDate: new Date(startDate),
      endDate: new Date(endDate)
    });

    await banner.save();

    return res.status(201).json({
      success: true,
      banner: {
        id: banner._id.toString(),
        title: banner.title,
        subtitle: banner.subtitle,
        badgeText: banner.badgeText,
        ctaText: banner.ctaText,
        imageUrl: banner.imageUrl,
        targetServiceId: banner.targetServiceId,
        displayOrder: banner.displayOrder,
        active: banner.active,
        startDate: banner.startDate,
        endDate: banner.endDate
      }
    });
  } catch (error: any) {
    console.error('Error creating hero banner:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};

// Admin: Update an existing hero banner
export const updateHeroBanner = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const {
      title,
      subtitle,
      badgeText,
      ctaText,
      imageUrl,
      targetServiceId,
      displayOrder,
      active,
      startDate,
      endDate
    } = req.body;

    const banner = await HeroBanner.findById(id);
    if (!banner) {
      return res.status(404).json({ error: 'Hero banner not found.' });
    }

    if (title !== undefined) banner.title = title;
    if (subtitle !== undefined) banner.subtitle = subtitle;
    if (badgeText !== undefined) banner.badgeText = badgeText;
    if (ctaText !== undefined) banner.ctaText = ctaText;
    if (imageUrl !== undefined) banner.imageUrl = imageUrl;
    if (targetServiceId !== undefined) banner.targetServiceId = targetServiceId;
    if (displayOrder !== undefined) banner.displayOrder = Number(displayOrder);
    if (active !== undefined) banner.active = Boolean(active);
    if (startDate !== undefined) banner.startDate = new Date(startDate);
    if (endDate !== undefined) banner.endDate = new Date(endDate);

    await banner.save();

    return res.status(200).json({
      success: true,
      banner: {
        id: banner._id.toString(),
        title: banner.title,
        subtitle: banner.subtitle,
        badgeText: banner.badgeText,
        ctaText: banner.ctaText,
        imageUrl: banner.imageUrl,
        targetServiceId: banner.targetServiceId,
        displayOrder: banner.displayOrder,
        active: banner.active,
        startDate: banner.startDate,
        endDate: banner.endDate
      }
    });
  } catch (error: any) {
    console.error('Error updating hero banner:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};

// Admin: Delete a hero banner
export const deleteHeroBanner = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const banner = await HeroBanner.findByIdAndDelete(id);
    if (!banner) {
      return res.status(404).json({ error: 'Hero banner not found.' });
    }

    return res.status(200).json({
      success: true,
      message: 'Hero banner deleted successfully.'
    });
  } catch (error: any) {
    console.error('Error deleting hero banner:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};
