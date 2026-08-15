import express, { Request, Response } from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { connectDB } from './config/db';
import bookingRoutes from './routes/bookingRoutes';
import spotlightRoutes from './routes/spotlightRoutes';
import heroRoutes from './routes/heroRoutes';
import { configureSockets } from './sockets/telemetrySocket';
import { Partner } from './models/Partner';
import { SpotlightBanner } from './models/SpotlightBanner';
import { HeroBanner } from './models/HeroBanner';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

import legalRoutes from './routes/legalRoutes';
import technicianBannerRoutes from './routes/technicianBannerRoutes';
import technicianIdRoutes, { renderPublicVerificationHtml } from './routes/technicianIdRoutes';
import { TechnicianBanner } from './models/TechnicianBanner';
import { TechnicianProfile } from './models/TechnicianProfile';

// Middleware
app.use(express.json());

// Enable custom CORS headers for HTTP requests (like React admin panel fetch)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.header('Access-Control-Allow-Methods', 'PUT, POST, PATCH, DELETE, GET');
    return res.status(200).json({});
  }
  next();
});

// Routes
app.use('/', legalRoutes);
app.use('/api', technicianBannerRoutes);
app.use('/api/technicians', technicianIdRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api', spotlightRoutes);
app.use('/api', heroRoutes);

// Public Standalone QR Verification Webpage
app.get('/verify-tech/:token', async (req: Request, res: Response) => {
  try {
    const { token } = req.params;
    const profile = await TechnicianProfile.findOne({ qr_verification_token: token });
    const html = renderPublicVerificationHtml(token, profile);
    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  } catch (error) {
    res.status(500).send('<h1>Verification Error</h1>');
  }
});

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', service: 'hyperlocal-telemetry-backend' });
});

// Seed default partners if none exist
const seedMockPartners = async () => {
  try {
    const count = await Partner.countDocuments();
    if (count === 0) {
      console.log('Seeding mock partners around Bengaluru area for dispatch testing...');
      await Partner.insertMany([
        {
          name: 'Rahul Sharma',
          phone: '+91 98765 43210',
          isOnline: true,
          rating: 4.9,
          location: {
            type: 'Point',
            coordinates: [77.585566, 12.982598] // [longitude, latitude] (Tech start location)
          }
        },
        {
          name: 'Amit Kumar',
          phone: '+91 99887 76655',
          isOnline: true,
          rating: 4.7,
          location: {
            type: 'Point',
            coordinates: [77.590000, 12.978000]
          }
        }
      ]);
      console.log('Mock partners seeded successfully.');
    }
  } catch (error) {
    console.error('Seeding error:', error);
  }
};

// Seed default spotlight banners if none exist
const seedMockSpotlightBanners = async () => {
  try {
    const count = await SpotlightBanner.countDocuments();
    if (count === 0) {
      console.log('Seeding default mock spotlight banners...');

      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const nextYear = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

      await SpotlightBanner.insertMany([
        {
          badgeText: 'TRENDING',
          title: 'Expert Home Services',
          subtitle: 'Professional technicians at your doorstep',
          ctaText: 'Book Now',
          imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000',
          serviceId: 'ac_clean',
          categoryId: 'cat_ac',
          displayOrder: 1,
          isActive: true,
          autoSlide: true,
          slideDuration: 3500,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'POPULAR',
          title: 'Keep Your Appliances Running',
          subtitle: 'AC, refrigerator, washing machine & more',
          ctaText: 'Explore Services',
          imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=1000',
          serviceId: 'fridge_rep',
          categoryId: 'cat_refrigerator',
          displayOrder: 2,
          isActive: true,
          autoSlide: true,
          slideDuration: 3500,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'TOP RATED',
          title: 'Reliable Electrical Solutions',
          subtitle: 'Safe installation, repair & maintenance',
          ctaText: 'Book a Technician',
          imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=1000',
          serviceId: 'pop_wiring',
          categoryId: 'cat_light',
          displayOrder: 3,
          isActive: true,
          autoSlide: true,
          slideDuration: 3500,
          startDate: yesterday,
          endDate: nextYear
        }
      ]);

      console.log('Mock spotlight banners seeded successfully.');
    }
  } catch (error) {
    console.error('Error seeding spotlight banners:', error);
  }
};

// Seed default mock hero banners if none exist
const seedMockHeroBanners = async () => {
  try {
    const count = await HeroBanner.countDocuments();
    if (count === 0) {
      console.log('Seeding default mock hero banners...');

      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const nextYear = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

      await HeroBanner.insertMany([
        {
          badgeText: 'Trending',
          title: 'Expert AC Service',
          subtitle: 'Starting from ₹299',
          ctaText: 'Book Now',
          imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000',
          targetServiceId: 'ac_clean',
          displayOrder: 1,
          active: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'Popular',
          title: 'Expert Electrician at Your Doorstep',
          subtitle: 'Starting from ₹249',
          ctaText: 'Book Now',
          imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=1000',
          targetServiceId: 'pop_inspect',
          displayOrder: 2,
          active: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'New',
          title: 'Professional fan installation',
          subtitle: 'Starting from ₹199',
          ctaText: 'Book Now',
          imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=1000',
          targetServiceId: 'fan_install',
          displayOrder: 3,
          active: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'Recommended',
          title: 'Keep your refrigerator running perfectly',
          subtitle: 'Service & Repair',
          ctaText: 'Book Now',
          imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=1000',
          targetServiceId: 'fridge_rep',
          displayOrder: 4,
          active: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'Special Offer',
          title: 'Washing Machine Service',
          subtitle: 'Starting from ₹699',
          ctaText: 'Explore',
          imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=1000',
          targetServiceId: 'washing_clean',
          displayOrder: 5,
          active: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          badgeText: 'Same-Day',
          title: 'Same-Day Technician Service',
          subtitle: 'Handyman & Repairs',
          ctaText: 'Book Now',
          imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=1000',
          targetServiceId: 'pop_wiring',
          displayOrder: 6,
          active: true,
          startDate: yesterday,
          endDate: nextYear
        }
      ]);

      console.log('Mock hero banners seeded successfully.');
    }
  } catch (error) {
    console.error('Error seeding hero banners:', error);
  }
};

// Seed default 4 technician promotional banners if none exist
const seedMockTechnicianBanners = async () => {
  try {
    const count = await TechnicianBanner.countDocuments();
    if (count === 0) {
      console.log('Seeding default 4 technician promotional banners...');
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const nextYear = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

      await TechnicianBanner.insertMany([
        {
          bannerId: 'tech_banner_1',
          title: 'Earn More With BookurTechnician',
          subtitle: 'Stay online and get more service requests',
          ctaText: 'GO ONLINE →',
          imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000',
          targetType: 'ONLINE_TOGGLE',
          displayOrder: 1,
          isActive: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          bannerId: 'tech_banner_2',
          title: 'Get More Jobs Near You',
          subtitle: 'Accept nearby service requests and grow your earnings',
          ctaText: 'VIEW JOBS →',
          imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=1000',
          targetType: 'JOBS',
          displayOrder: 2,
          isActive: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          bannerId: 'tech_banner_3',
          title: 'Build Your Technician Profile',
          subtitle: 'Complete more jobs. Maintain a great rating. Get more opportunities.',
          ctaText: 'VIEW PERFORMANCE →',
          imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=1000',
          targetType: 'PERFORMANCE',
          displayOrder: 3,
          isActive: true,
          startDate: yesterday,
          endDate: nextYear
        },
        {
          bannerId: 'tech_banner_4',
          title: 'Track Your Earnings',
          subtitle: 'See today\'s jobs, weekly earnings and payout history',
          ctaText: 'VIEW EARNINGS →',
          imageUrl: 'https://images.unsplash.com/photo-1556742049-0a67c5574f73?w=1000',
          targetType: 'EARNINGS',
          displayOrder: 4,
          isActive: true,
          startDate: yesterday,
          endDate: nextYear
        }
      ]);
      console.log('Mock technician banners seeded successfully.');
    }
  } catch (error) {
    console.error('Error seeding technician banners:', error);
  }
};

// Seed default official technician identity card if none exists
const seedMockTechnicianProfile = async () => {
  try {
    const count = await TechnicianProfile.countDocuments();
    if (count === 0) {
      console.log('Seeding default technician profile for Rahul Adhikary (BT-TECH-000001)...');
      await TechnicianProfile.create({
        technician_code: 'BT-TECH-000001',
        user_id: 'tech_user_rahul_01',
        full_name: 'Rahul Adhikary',
        phone: '+91 98765 43210',
        email: 'rahul.adhikary@bookurtechnician.com',
        profile_photo_url: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400',
        join_date: new Date('2026-08-15'),
        skills: ['AC Service', 'Electrical', 'Fan Service'],
        verification_status: 'APPROVED',
        qr_verification_token: 'verify_tech_000001_secure',
      });
      console.log('Technician identity BT-TECH-000001 created successfully.');
    }
  } catch (error) {
    console.error('Error seeding technician profile:', error);
  }
};

// Connect to DB and start
const PORT = process.env.PORT || 3000;
connectDB().then(async () => {
  await seedMockPartners();
  await seedMockSpotlightBanners();
  await seedMockHeroBanners();
  await seedMockTechnicianBanners();
  await seedMockTechnicianProfile();

  configureSockets(io);

  httpServer.listen(PORT, () => {
    console.log(`Hyperlocal Dispatch Server running on port ${PORT}`);
  });
});
