import { Request, Response } from 'express';
import { SpotlightBanner } from '../models/SpotlightBanner';
import { HeroBanner } from '../models/HeroBanner';

// Get active banners for client Home screen
export const getActiveBanners = async (req: Request, res: Response) => {
  try {
    const now = new Date();
    
    // Query spotlight banners where:
    // 1. isActive is true
    // 2. startDate <= current date <= endDate
    const banners = await SpotlightBanner.find({
      isActive: true,
      startDate: { $lte: now },
      endDate: { $gte: now }
    }).sort({ displayOrder: 1 }); // Sort by displayOrder ASC

    // Query hero banners where:
    // 1. active is true
    // 2. startDate <= current date <= endDate
    const heroes = await HeroBanner.find({
      active: true,
      startDate: { $lte: now },
      endDate: { $gte: now }
    }).sort({ displayOrder: 1 }); // Sort by displayOrder ASC

    // Map Mongoose documents to user-specified camelCase format with 'id' instead of '_id'
    const formattedBanners = banners.map(banner => ({
      id: banner._id.toString(),
      title: banner.title,
      subtitle: banner.subtitle,
      badgeText: banner.badgeText,
      ctaText: banner.ctaText,
      imageUrl: banner.imageUrl,
      serviceId: banner.serviceId || "",
      categoryId: banner.categoryId || "",
      displayOrder: banner.displayOrder,
      autoSlide: banner.autoSlide,
      slideDuration: banner.slideDuration,
      startDate: banner.startDate,
      endDate: banner.endDate
    }));

    const formattedHeroes = heroes.map(hero => ({
      id: hero._id.toString(),
      title: hero.title,
      subtitle: hero.subtitle,
      badgeText: hero.badgeText,
      ctaText: hero.ctaText,
      imageUrl: hero.imageUrl,
      targetServiceId: hero.targetServiceId || "",
      displayOrder: hero.displayOrder,
      active: hero.active,
      startDate: hero.startDate,
      endDate: hero.endDate
    }));

    return res.status(200).json({
      heroBanners: formattedHeroes,
      spotlightBanners: formattedBanners
    });
  } catch (error: any) {
    console.error('Error fetching active spotlight and hero banners:', error);
    return res.status(500).json({ error: error.message || 'Internal server error fetching banners.' });
  }
};

// Admin: Get all banners (active and inactive, any date range)
export const getAllBanners = async (req: Request, res: Response) => {
  try {
    const banners = await SpotlightBanner.find().sort({ displayOrder: 1 });
    
    const formattedBanners = banners.map(banner => ({
      id: banner._id.toString(),
      title: banner.title,
      subtitle: banner.subtitle,
      badgeText: banner.badgeText,
      ctaText: banner.ctaText,
      imageUrl: banner.imageUrl,
      serviceId: banner.serviceId || "",
      categoryId: banner.categoryId || "",
      displayOrder: banner.displayOrder,
      isActive: banner.isActive,
      autoSlide: banner.autoSlide,
      slideDuration: banner.slideDuration,
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
    console.error('Error fetching all banners for admin:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};

// Admin: Create a new spotlight banner
export const createBanner = async (req: Request, res: Response) => {
  try {
    const {
      title,
      subtitle,
      badgeText,
      ctaText,
      imageUrl,
      serviceId,
      categoryId,
      displayOrder,
      isActive,
      autoSlide,
      slideDuration,
      startDate,
      endDate
    } = req.body;

    if (!title || !subtitle || !badgeText || !ctaText || !imageUrl || !startDate || !endDate) {
      return res.status(400).json({ error: 'Missing required banner fields (title, subtitle, badgeText, ctaText, imageUrl, startDate, endDate).' });
    }

    const banner = new SpotlightBanner({
      title,
      subtitle,
      badgeText,
      ctaText,
      imageUrl,
      serviceId: serviceId || "",
      categoryId: categoryId || "",
      displayOrder: displayOrder !== undefined ? Number(displayOrder) : 0,
      isActive: isActive !== undefined ? Boolean(isActive) : true,
      autoSlide: autoSlide !== undefined ? Boolean(autoSlide) : true,
      slideDuration: slideDuration !== undefined ? Number(slideDuration) : 3000,
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
        serviceId: banner.serviceId,
        categoryId: banner.categoryId,
        displayOrder: banner.displayOrder,
        isActive: banner.isActive,
        autoSlide: banner.autoSlide,
        slideDuration: banner.slideDuration,
        startDate: banner.startDate,
        endDate: banner.endDate
      }
    });
  } catch (error: any) {
    console.error('Error creating banner:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};

// Admin: Update/Edit an existing banner
export const updateBanner = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const {
      title,
      subtitle,
      badgeText,
      ctaText,
      imageUrl,
      serviceId,
      categoryId,
      displayOrder,
      isActive,
      autoSlide,
      slideDuration,
      startDate,
      endDate
    } = req.body;

    const banner = await SpotlightBanner.findById(id);
    if (!banner) {
      return res.status(404).json({ error: 'Spotlight banner not found.' });
    }

    if (title !== undefined) banner.title = title;
    if (subtitle !== undefined) banner.subtitle = subtitle;
    if (badgeText !== undefined) banner.badgeText = badgeText;
    if (ctaText !== undefined) banner.ctaText = ctaText;
    if (imageUrl !== undefined) banner.imageUrl = imageUrl;
    if (serviceId !== undefined) banner.serviceId = serviceId;
    if (categoryId !== undefined) banner.categoryId = categoryId;
    if (displayOrder !== undefined) banner.displayOrder = Number(displayOrder);
    if (isActive !== undefined) banner.isActive = Boolean(isActive);
    if (autoSlide !== undefined) banner.autoSlide = Boolean(autoSlide);
    if (slideDuration !== undefined) banner.slideDuration = Number(slideDuration);
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
        serviceId: banner.serviceId,
        categoryId: banner.categoryId,
        displayOrder: banner.displayOrder,
        isActive: banner.isActive,
        autoSlide: banner.autoSlide,
        slideDuration: banner.slideDuration,
        startDate: banner.startDate,
        endDate: banner.endDate
      }
    });
  } catch (error: any) {
    console.error('Error updating banner:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};

// Admin: Delete a banner
export const deleteBanner = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const banner = await SpotlightBanner.findByIdAndDelete(id);
    if (!banner) {
      return res.status(404).json({ error: 'Spotlight banner not found.' });
    }

    return res.status(200).json({
      success: true,
      message: 'Spotlight banner deleted successfully.'
    });
  } catch (error: any) {
    console.error('Error deleting banner:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};
