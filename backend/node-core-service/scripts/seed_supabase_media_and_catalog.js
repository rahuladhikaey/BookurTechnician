require('dotenv').config();
const { Pool } = require('pg');
const { getMasterCatalog, getFlattenedServices } = require('../src/config/masterCatalog');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres.hgjvwddlwofzpdurvpzd:Rahul%402005%40%23@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function runSeed() {
  console.log('🚀 [Supabase Seed] Connecting to Supabase Cloud PostgreSQL...');
  const client = await pool.connect();

  try {
    console.log('📦 [1/5] Creating Database Tables on Supabase...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
          id VARCHAR(64) PRIMARY KEY,
          phone VARCHAR(20) UNIQUE NOT NULL,
          email VARCHAR(255) UNIQUE,
          full_name VARCHAR(100),
          role VARCHAR(30) NOT NULL,
          is_phone_verified BOOLEAN DEFAULT true,
          is_email_verified BOOLEAN DEFAULT false,
          is_active BOOLEAN DEFAULT true,
          profile_image_url TEXT,
          fcm_token TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS customer_addresses (
          id VARCHAR(64) PRIMARY KEY,
          user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          address_type VARCHAR(20) DEFAULT 'HOME',
          house_flat VARCHAR(100),
          street VARCHAR(255),
          landmark VARCHAR(255),
          area VARCHAR(100),
          city VARCHAR(100) DEFAULT 'Kolkata',
          state VARCHAR(100) DEFAULT 'West Bengal',
          postal_code VARCHAR(20),
          latitude DOUBLE PRECISION,
          longitude DOUBLE PRECISION,
          is_primary BOOLEAN DEFAULT false,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS service_categories (
          id VARCHAR(64) PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          slug VARCHAR(100) UNIQUE NOT NULL,
          description TEXT,
          icon_url TEXT,
          banner_image_url TEXT,
          display_order INT DEFAULT 0,
          is_active BOOLEAN DEFAULT true,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS services (
          id VARCHAR(64) PRIMARY KEY,
          category_id VARCHAR(64) NOT NULL REFERENCES service_categories(id) ON DELETE CASCADE,
          name VARCHAR(150) NOT NULL,
          slug VARCHAR(150) UNIQUE NOT NULL,
          description TEXT,
          base_price NUMERIC(10, 2) NOT NULL,
          strike_price NUMERIC(10, 2),
          discount_percentage INT DEFAULT 0,
          estimated_time_minutes INT DEFAULT 45,
          warranty_period_days INT DEFAULT 30,
          image_url TEXT,
          is_popular BOOLEAN DEFAULT false,
          is_active BOOLEAN DEFAULT true,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS technician_profiles (
          id VARCHAR(64) PRIMARY KEY,
          technician_id VARCHAR(64) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          technician_code VARCHAR(30) UNIQUE NOT NULL,
          full_name VARCHAR(100) NOT NULL,
          phone VARCHAR(20) NOT NULL,
          category VARCHAR(50) DEFAULT 'ELECTRICIAN',
          skills TEXT[] DEFAULT '{}',
          experience_years INT DEFAULT 2,
          kyc_status VARCHAR(30) DEFAULT 'PENDING',
          is_online BOOLEAN DEFAULT false,
          current_latitude DOUBLE PRECISION,
          current_longitude DOUBLE PRECISION,
          rating NUMERIC(3, 2) DEFAULT 4.85,
          total_ratings_count INT DEFAULT 0,
          total_jobs_completed INT DEFAULT 0,
          acceptance_rate NUMERIC(5, 2) DEFAULT 98.00,
          wallet_balance NUMERIC(10, 2) DEFAULT 0.00,
          upi_id VARCHAR(100),
          upi_number VARCHAR(20),
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS technician_kyc_documents (
          id VARCHAR(64) PRIMARY KEY,
          technician_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          document_type VARCHAR(50) NOT NULL,
          document_number VARCHAR(100),
          front_image_url TEXT,
          back_image_url TEXT,
          file_size_mb NUMERIC(5, 2),
          verification_status VARCHAR(30) DEFAULT 'PENDING',
          rejection_reason TEXT,
          verified_at TIMESTAMP WITH TIME ZONE,
          uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS uploaded_media (
          id VARCHAR(64) PRIMARY KEY,
          file_name VARCHAR(255) NOT NULL,
          file_url TEXT NOT NULL,
          storage_bucket VARCHAR(100) NOT NULL DEFAULT 'app-assets',
          mime_type VARCHAR(50),
          file_size_bytes BIGINT,
          entity_type VARCHAR(50) NOT NULL,
          entity_id VARCHAR(64),
          is_public BOOLEAN DEFAULT true,
          uploaded_by VARCHAR(64),
          uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS bookings (
          id VARCHAR(64) PRIMARY KEY,
          booking_code VARCHAR(30) UNIQUE NOT NULL,
          customer_id VARCHAR(64) NOT NULL REFERENCES users(id),
          technician_id VARCHAR(64) REFERENCES users(id),
          service_id VARCHAR(64),
          service_name VARCHAR(150),
          category VARCHAR(50),
          service_items JSONB DEFAULT '[]'::jsonb,
          status VARCHAR(50) NOT NULL,
          full_address TEXT NOT NULL,
          latitude DOUBLE PRECISION,
          longitude DOUBLE PRECISION,
          base_price NUMERIC(10, 2) DEFAULT 199.00,
          visit_fee NUMERIC(10, 2) DEFAULT 49.00,
          gst_tax NUMERIC(10, 2) DEFAULT 44.64,
          total_amount NUMERIC(10, 2) NOT NULL,
          payment_method VARCHAR(30) DEFAULT 'ONLINE',
          payment_status VARCHAR(30) DEFAULT 'PENDING',
          start_otp VARCHAR(6) NOT NULL,
          end_otp VARCHAR(6) NOT NULL,
          schedule_date DATE DEFAULT CURRENT_DATE,
          time_slot VARCHAR(50) DEFAULT '3:00 PM – 4:00 PM',
          cancellation_reason TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS platform_settings (
          key VARCHAR(100) PRIMARY KEY,
          value JSONB NOT NULL,
          description TEXT,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `);

    console.log('🖼️ [2/5] Seeding Uploaded Pictures & App Media into Supabase...');
    const mediaFiles = [
      {
        id: 'media_banner_1',
        fileName: 'banner_3d_1.png',
        fileUrl: 'https://bookurtechnician.com/assets/images/banner_3d_1.png',
        storageBucket: 'app-assets',
        mimeType: 'image/png',
        sizeBytes: 1721781,
        entityType: 'BANNER',
        entityId: 'promo_banner_1',
      },
      {
        id: 'media_banner_2',
        fileName: 'banner_3d_2.png',
        fileUrl: 'https://bookurtechnician.com/assets/images/banner_3d_2.png',
        storageBucket: 'app-assets',
        mimeType: 'image/png',
        sizeBytes: 1912006,
        entityType: 'BANNER',
        entityId: 'promo_banner_2',
      },
      {
        id: 'media_banner_3',
        fileName: 'banner_3d_3.png',
        fileUrl: 'https://bookurtechnician.com/assets/images/banner_3d_3.png',
        storageBucket: 'app-assets',
        mimeType: 'image/png',
        sizeBytes: 2238173,
        entityType: 'BANNER',
        entityId: 'promo_banner_3',
      },
      {
        id: 'media_popular_1',
        fileName: 'popular_banner_1.png',
        fileUrl: 'https://bookurtechnician.com/assets/images/popular_banner_1.png',
        storageBucket: 'app-assets',
        mimeType: 'image/png',
        sizeBytes: 1762305,
        entityType: 'BANNER',
        entityId: 'popular_1',
      },
      {
        id: 'media_logo',
        fileName: 'app_logo.png',
        fileUrl: 'https://bookurtechnician.com/assets/images/app_logo.png',
        storageBucket: 'app-assets',
        mimeType: 'image/png',
        sizeBytes: 242349,
        entityType: 'OTHER',
        entityId: 'brand_logo',
      },
      {
        id: 'media_kyc_aadhaar_1',
        fileName: 'aadhaar_front_t1.jpg',
        fileUrl: 'https://bookurtechnician.com/docs/aadhaar_verified_t1.jpg',
        storageBucket: 'kyc-documents',
        mimeType: 'image/jpeg',
        sizeBytes: 450200,
        entityType: 'KYC_DOCUMENT',
        entityId: 'tech-001',
      },
      {
        id: 'media_kyc_voter_1',
        fileName: 'voter_front_t1.jpg',
        fileUrl: 'https://bookurtechnician.com/docs/voter_verified_t1.jpg',
        storageBucket: 'kyc-documents',
        mimeType: 'image/jpeg',
        sizeBytes: 380100,
        entityType: 'KYC_DOCUMENT',
        entityId: 'tech-001',
      },
      {
        id: 'media_kyc_upi_1',
        fileName: 'upi_qr_t1.png',
        fileUrl: 'https://bookurtechnician.com/docs/upi_qr_t1.png',
        storageBucket: 'kyc-documents',
        mimeType: 'image/png',
        sizeBytes: 120400,
        entityType: 'KYC_DOCUMENT',
        entityId: 'tech-001',
      }
    ];

    for (const m of mediaFiles) {
      await client.query(`
        INSERT INTO uploaded_media (id, file_name, file_url, storage_bucket, mime_type, file_size_bytes, entity_type, entity_id, is_public)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
        ON CONFLICT (id) DO UPDATE SET
          file_name = EXCLUDED.file_name,
          file_url = EXCLUDED.file_url,
          storage_bucket = EXCLUDED.storage_bucket,
          file_size_bytes = EXCLUDED.file_size_bytes;
      `, [m.id, m.fileName, m.fileUrl, m.storageBucket, m.mimeType, m.sizeBytes, m.entityType, m.entityId]);
    }

    console.log('📂 [3/5] Seeding Categories and 158 Master Services into Supabase...');
    const catalog = getMasterCatalog();
    let totalServicesSeeded = 0;

    for (let i = 0; i < catalog.length; i++) {
      const cat = catalog[i];
      const catSlug = cat.slug || cat.name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
      await client.query(`
        INSERT INTO service_categories (id, name, slug, description, icon_url, banner_image_url, display_order, is_active)
        VALUES ($1, $2, $3, $4, $5, $6, $7, true)
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          icon_url = EXCLUDED.icon_url,
          banner_image_url = EXCLUDED.banner_image_url,
          display_order = EXCLUDED.display_order;
      `, [cat.id, cat.name, catSlug, `Expert verified ${cat.name} at doorstep.`, cat.icon || '', cat.imageUrl || '', i + 1]);

      if (Array.isArray(cat.subcategories)) {
        for (const sub of cat.subcategories) {
          if (Array.isArray(sub.services)) {
            for (const srv of sub.services) {
              const serviceSlug = `${cat.id}_${srv.id}_${srv.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`.slice(0, 140);
              await client.query(`
                INSERT INTO services (
                  id, category_id, name, slug, description, base_price, strike_price,
                  discount_percentage, image_url, is_popular, is_active
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true)
                ON CONFLICT (id) DO UPDATE SET
                  name = EXCLUDED.name,
                  slug = EXCLUDED.slug,
                  base_price = EXCLUDED.base_price,
                  strike_price = EXCLUDED.strike_price,
                  image_url = EXCLUDED.image_url;
              `, [
                srv.id,
                cat.id,
                srv.name,
                serviceSlug,
                srv.description || `Professional ${srv.name} with 30-day service warranty.`,
                srv.basePrice || srv.price || 199,
                (srv.basePrice || srv.price || 199) * 1.3,
                20,
                srv.imageUrl || '',
                srv.isPopular || false,
              ]);
              totalServicesSeeded++;
            }
          }
        }
      }
    }
    console.log(`✅ [Catalog] Seeded ${totalServicesSeeded} individual services into Supabase!`);

    console.log('👷 [4/5] Seeding Verified Technicians & KYC Documents into Supabase...');
    const technicians = [
      {
        userId: 'tech-001',
        code: 'BT-TECH-1088',
        name: 'Rahul Adhikary (Master Technician)',
        phone: '+919876543210',
        email: 'rahul.tech@bookurtechnician.com',
        category: 'ELECTRICIAN',
        skills: ['Wiring', 'Switchboard Repair', 'Fan Installation', 'MCB Tripping', 'Inverter Repair'],
        rating: 4.95,
        jobs: 142,
        upi: 'rahul@oksbi',
        aadhar: 'XXXX-XXXX-9012',
        voter: 'WBD9876543',
      },
      {
        userId: 'tech-002',
        code: 'BT-TECH-2044',
        name: 'Amit Sharma',
        phone: '+919876543211',
        email: 'amit.sharma@bookurtechnician.com',
        category: 'AC_REPAIR',
        skills: ['AC Gas Leakage', 'Split AC Installation', 'Deep Jet Cleaning', 'Compressor Repair'],
        rating: 4.88,
        jobs: 98,
        upi: 'amit@paytm',
        aadhar: 'XXXX-XXXX-5678',
        voter: 'WBD1234567',
      },
      {
        userId: 'tech-003',
        code: 'BT-TECH-3099',
        name: 'Subhash Roy',
        phone: '+919876543212',
        email: 'subhash.roy@bookurtechnician.com',
        category: 'PLUMBING',
        skills: ['Water Motor Repair', 'Pipe Leakage', 'Tap Replacement', 'Bathroom Fitting'],
        rating: 4.82,
        jobs: 74,
        upi: 'subhash@ybl',
        aadhar: 'XXXX-XXXX-3344',
        voter: 'WBD5566778',
      },
      {
        userId: 'tech-004',
        code: 'BT-TECH-4011',
        name: 'Bikram Das',
        phone: '+919876543213',
        email: 'bikram.das@bookurtechnician.com',
        category: 'APPLIANCE',
        skills: ['Washing Machine PCB', 'Refrigerator Cooling', 'Microwave Repair', 'RO Water Purifier'],
        rating: 4.91,
        jobs: 112,
        upi: 'bikram@okhdfcbank',
        aadhar: 'XXXX-XXXX-7788',
        voter: 'WBD9988112',
      },
    ];

    for (const t of technicians) {
      await client.query(`
        INSERT INTO users (id, phone, email, full_name, role, is_active)
        VALUES ($1, $2, $3, $4, 'TECHNICIAN', true)
        ON CONFLICT (id) DO UPDATE SET
          phone = EXCLUDED.phone,
          email = EXCLUDED.email,
          full_name = EXCLUDED.full_name;
      `, [t.userId, t.phone, t.email, t.name]);

      await client.query(`
        INSERT INTO technician_profiles (
          id, technician_id, technician_code, full_name, phone, category, skills,
          rating, total_jobs_completed, kyc_status, is_online, upi_id, upi_number
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'VERIFIED', true, $10, $10)
        ON CONFLICT (technician_id) DO UPDATE SET
          full_name = EXCLUDED.full_name,
          skills = EXCLUDED.skills,
          rating = EXCLUDED.rating,
          total_jobs_completed = EXCLUDED.total_jobs_completed,
          kyc_status = 'VERIFIED',
          is_online = true,
          upi_id = EXCLUDED.upi_id;
      `, [t.userId, t.userId, t.code, t.name, t.phone, t.category, t.skills, t.rating, t.jobs, t.upi]);

      // KYC Aadhaar & Voter Docs
      await client.query(`
        INSERT INTO technician_kyc_documents (id, technician_id, document_type, document_number, front_image_url, verification_status)
        VALUES ($1, $2, 'AADHAAR', $3, $4, 'APPROVED')
        ON CONFLICT (id) DO UPDATE SET
          document_number = EXCLUDED.document_number,
          verification_status = 'APPROVED';
      `, [`doc_aadhaar_${t.userId}`, t.userId, t.aadhar, `https://bookurtechnician.com/docs/aadhaar_${t.userId}.jpg`]);

      await client.query(`
        INSERT INTO technician_kyc_documents (id, technician_id, document_type, document_number, front_image_url, verification_status)
        VALUES ($1, $2, 'VOTER_CARD', $3, $4, 'APPROVED')
        ON CONFLICT (id) DO UPDATE SET
          document_number = EXCLUDED.document_number,
          verification_status = 'APPROVED';
      `, [`doc_voter_${t.userId}`, t.userId, t.voter, `https://bookurtechnician.com/docs/voter_${t.userId}.jpg`]);
    }

    console.log('⚙️ [5/5] Seeding Platform Settings...');
    await client.query(`
      INSERT INTO platform_settings (key, value, description)
      VALUES
        ('booking_charge', '{"amount": 49.00}'::jsonb, 'Standard doorstep visiting fee'),
        ('gst_rate_percentage', '{"percentage": 18}'::jsonb, 'Standard GST tax rate'),
        ('emergency_service_surcharge', '{"amount": 100.00}'::jsonb, 'Emergency priority surcharge')
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    `);

    console.log('🎉 =======================================================');
    console.log('✅ [Supabase Seed Success] Master database schemas, 158 services, pictures metadata, and 4 verified technicians seeded successfully into Supabase!');
    console.log('🎉 =======================================================');
  } catch (err) {
    console.error('❌ [Supabase Seed Error]:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

runSeed();
