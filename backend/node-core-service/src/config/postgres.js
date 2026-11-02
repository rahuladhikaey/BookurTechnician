const { Pool } = require('pg');

let pool = null;
let isPostgresConnected = false;

// In-memory fallback mock database if Postgres is not running locally during early dev
const inMemoryStore = {
  users: new Map(),
  bookings: new Map(),
  payments: new Map(),
  wallets: new Map(),
  messages: new Map(),
  addons: new Map(),
  proofOfWork: new Map(),
  reviews: new Map(),
  warranties: new Map(),
  withdrawals: new Map(),
  invoices: new Map(),
  auditLogs: [],
};

const initPostgres = async () => {
  try {
    const isCloudDb = !!process.env.DATABASE_URL || (process.env.PG_HOST && !process.env.PG_HOST.includes('localhost') && !process.env.PG_HOST.includes('127.0.0.1'));
    
    if (process.env.DATABASE_URL) {
      const cleanConnectionString = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]+/, '');
      pool = new Pool({
        connectionString: cleanConnectionString,
        ssl: isCloudDb ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 8000,
      });
    } else {
      pool = new Pool({
        host: process.env.PG_HOST || 'localhost',
        port: parseInt(process.env.PG_PORT || '5432', 10),
        database: process.env.PG_DATABASE || 'postgres',
        user: process.env.PG_USER || 'postgres',
        password: process.env.PG_PASSWORD || 'postgrespassword',
        ssl: isCloudDb ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 8000,
      });
    }

    const client = await pool.connect();
    const res = await client.query('SELECT NOW()');
    client.release();

    isPostgresConnected = true;
    const connectedTarget = process.env.DATABASE_URL ? 'Cloud PostgreSQL via DATABASE_URL' : `${process.env.PG_HOST || 'localhost'}:${process.env.PG_PORT || '5432'}`;
    console.log(`✅ [PostgreSQL] Connected successfully to ${connectedTarget} (ACID Transactions Engine)`);

    // Ensure core tables exist
    await createCoreTables();
  } catch (err) {
    console.warn('⚠️ [PostgreSQL] Connection warning (Offline/Mock fallback mode active):', err.message);
    isPostgresConnected = false;
  }
};

const createCoreTables = async () => {
  if (!isPostgresConnected) return;
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(64) PRIMARY KEY,
        phone VARCHAR(20) UNIQUE,
        email VARCHAR(255) UNIQUE,
        full_name VARCHAR(100),
        role VARCHAR(30) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        fcm_token TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS bookings (
        id VARCHAR(64) PRIMARY KEY,
        booking_code VARCHAR(30) UNIQUE,
        customer_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64),
        service_id VARCHAR(64) NOT NULL,
        service_name VARCHAR(150),
        category VARCHAR(50),
        status VARCHAR(50) NOT NULL,
        address TEXT,
        latitude DOUBLE PRECISION,
        longitude DOUBLE PRECISION,
        total_amount NUMERIC(10, 2) DEFAULT 0,
        start_otp VARCHAR(6),
        end_otp VARCHAR(6),
        scheduled_time TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        booking_id VARCHAR(64),
        amount NUMERIC(10, 2) NOT NULL,
        type VARCHAR(20) NOT NULL,
        description TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS ledger_transactions (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        booking_id VARCHAR(64),
        type VARCHAR(40) NOT NULL,
        amount NUMERIC(10, 2) NOT NULL,
        direction VARCHAR(10) NOT NULL,
        status VARCHAR(30) DEFAULT 'SETTLED',
        reference_id VARCHAR(100),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_ledger_tech ON ledger_transactions(technician_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_ledger_booking ON ledger_transactions(booking_id);

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
        slug VARCHAR(100) UNIQUE,
        description TEXT,
        icon_url TEXT,
        banner_image_url TEXT,
        display_order INT DEFAULT 0,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS services (
        id VARCHAR(64) PRIMARY KEY,
        category_id VARCHAR(64) REFERENCES service_categories(id) ON DELETE CASCADE,
        name VARCHAR(150) NOT NULL,
        slug VARCHAR(150) UNIQUE,
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

      CREATE EXTENSION IF NOT EXISTS postgis;

      CREATE TABLE IF NOT EXISTS technician_profiles (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) UNIQUE NOT NULL,
        technician_code VARCHAR(30),
        full_name VARCHAR(100) NOT NULL,
        phone VARCHAR(20) NOT NULL,
        category VARCHAR(50) DEFAULT 'ELECTRICIAN',
        skills JSONB DEFAULT '[]'::jsonb,
        experience_years INT DEFAULT 2,
        kyc_status VARCHAR(30) DEFAULT 'PENDING',
        account_status VARCHAR(30) DEFAULT 'Active',
        is_online BOOLEAN DEFAULT false,
        current_latitude DOUBLE PRECISION,
        current_longitude DOUBLE PRECISION,
        location geography(Point, 4326),
        last_location_update TIMESTAMP WITH TIME ZONE,
        availability_status VARCHAR(30) DEFAULT 'AVAILABLE',
        rating NUMERIC(3, 2) DEFAULT 4.85,
        total_ratings_count INT DEFAULT 0,
        total_jobs_completed INT DEFAULT 0,
        wallet_balance NUMERIC(10, 2) DEFAULT 0.00,
        upi_id VARCHAR(100),
        upi_number VARCHAR(20),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS account_status VARCHAR(30) DEFAULT 'Active';

      CREATE INDEX IF NOT EXISTS idx_technician_profiles_location ON technician_profiles USING GIST(location);
      CREATE INDEX IF NOT EXISTS idx_technician_profiles_status_perf ON technician_profiles(is_online, availability_status, kyc_status, last_location_update);
      CREATE INDEX IF NOT EXISTS idx_technician_profiles_coords ON technician_profiles(current_latitude, current_longitude);

      CREATE TABLE IF NOT EXISTS technician_services (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        service_id VARCHAR(64) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        active BOOLEAN DEFAULT true,
        CONSTRAINT uq_technician_service UNIQUE(technician_id, service_id)
      );

      CREATE INDEX IF NOT EXISTS idx_tech_services_service ON technician_services(service_id, active);
      CREATE INDEX IF NOT EXISTS idx_tech_services_technician ON technician_services(technician_id, active);

      CREATE TABLE IF NOT EXISTS technician_kyc_documents (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
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
        storage_bucket VARCHAR(100) NOT NULL DEFAULT 'kyc-documents',
        mime_type VARCHAR(50),
        file_size_bytes BIGINT,
        entity_type VARCHAR(50) NOT NULL DEFAULT 'KYC_DOCUMENT',
        entity_id VARCHAR(64),
        is_public BOOLEAN DEFAULT true,
        uploaded_by VARCHAR(64),
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS dispatch_requests (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        service_id VARCHAR(64),
        service_name VARCHAR(150),
        customer_name VARCHAR(100),
        customer_address TEXT,
        distance_km DOUBLE PRECISION,
        estimated_payout NUMERIC(10, 2),
        total_amount NUMERIC(10, 2),
        status VARCHAR(30) DEFAULT 'PENDING',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '35 seconds'),
        responded_at TIMESTAMP WITH TIME ZONE
      );

      CREATE INDEX IF NOT EXISTS idx_dispatch_requests_tech_status ON dispatch_requests(technician_id, status);
      CREATE INDEX IF NOT EXISTS idx_dispatch_requests_booking ON dispatch_requests(booking_id);
      CREATE INDEX IF NOT EXISTS idx_dispatch_requests_expires ON dispatch_requests(expires_at, status);

      CREATE TABLE IF NOT EXISTS technician_work_logs (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        work_date DATE NOT NULL,
        online_minutes INT DEFAULT 0,
        completed_jobs INT DEFAULT 0,
        total_earnings NUMERIC(10, 2) DEFAULT 0,
        tier VARCHAR(20) DEFAULT 'COPPER',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        CONSTRAINT uq_tech_work_date UNIQUE(technician_id, work_date)
      );

      CREATE INDEX IF NOT EXISTS idx_tech_work_logs_date ON technician_work_logs(technician_id, work_date DESC);
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS tier VARCHAR(20) DEFAULT 'COPPER';
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS cod_balance NUMERIC(10, 2) DEFAULT 0.00;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS is_cod_suspended BOOLEAN DEFAULT false;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128);

      ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS device_tokens JSONB DEFAULT '[]'::jsonb;

      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS before_service_photos JSONB DEFAULT '[]'::jsonb;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS after_service_photos JSONB DEFAULT '[]'::jsonb;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS addon_charges NUMERIC(10, 2) DEFAULT 0.00;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancellation_fee NUMERIC(10, 2) DEFAULT 0.00;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS refund_amount NUMERIC(10, 2) DEFAULT 0.00;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS refund_id VARCHAR(100);
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS razorpay_payment_id VARCHAR(100);
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS razorpay_order_id VARCHAR(100);
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS warranty_until TIMESTAMP WITH TIME ZONE;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS warranty_claim_id VARCHAR(64);

      -- 1. Real-time P2P In-App Chat Messages
      CREATE TABLE IF NOT EXISTS booking_messages (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        sender_id VARCHAR(64) NOT NULL,
        sender_role VARCHAR(30) NOT NULL,
        receiver_id VARCHAR(64) NOT NULL,
        content TEXT NOT NULL,
        attachment_url TEXT,
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_booking_messages_booking ON booking_messages(booking_id, created_at ASC);

      -- 2. Add-on Services & Spare Parts Approval Engine
      CREATE TABLE IF NOT EXISTS booking_addons (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        title VARCHAR(200) NOT NULL,
        description TEXT,
        unit_price NUMERIC(10, 2) NOT NULL,
        quantity INT DEFAULT 1,
        total_price NUMERIC(10, 2) NOT NULL,
        status VARCHAR(30) DEFAULT 'PENDING',
        responded_at TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_booking_addons_booking ON booking_addons(booking_id, status);

      -- 3. Proof of Work (Before & After Defect Photos)
      CREATE TABLE IF NOT EXISTS booking_proof_of_work (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        type VARCHAR(20) NOT NULL,
        media_url TEXT NOT NULL,
        gps_lat DOUBLE PRECISION,
        gps_lng DOUBLE PRECISION,
        timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_booking_proof_booking ON booking_proof_of_work(booking_id, type);

      -- 4. Mutual 2-Way Reviews & Ratings
      CREATE TABLE IF NOT EXISTS booking_reviews (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) UNIQUE NOT NULL,
        customer_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        customer_rating NUMERIC(2, 1),
        customer_review TEXT,
        customer_tags JSONB DEFAULT '[]'::jsonb,
        technician_rating NUMERIC(2, 1),
        technician_review TEXT,
        tip_amount NUMERIC(10, 2) DEFAULT 0.00,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_reviews_technician ON booking_reviews(technician_id);

      -- 5. 30-Day Service Guarantee & Warranty Engine
      CREATE TABLE IF NOT EXISTS booking_warranties (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        customer_id VARCHAR(64) NOT NULL,
        revisit_booking_id VARCHAR(64),
        reason TEXT NOT NULL,
        status VARCHAR(30) DEFAULT 'CLAIMED',
        claimed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        resolved_at TIMESTAMP WITH TIME ZONE
      );
      CREATE INDEX IF NOT EXISTS idx_warranties_booking ON booking_warranties(booking_id);

      -- 6. Technician Instant Wallet Withdrawals
      CREATE TABLE IF NOT EXISTS technician_withdrawals (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        amount NUMERIC(10, 2) NOT NULL,
        upi_id VARCHAR(100) NOT NULL,
        status VARCHAR(30) DEFAULT 'PENDING',
        idempotency_key VARCHAR(100) UNIQUE,
        payout_reference VARCHAR(100),
        failure_reason TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        processed_at TIMESTAMP WITH TIME ZONE
      );
      CREATE INDEX IF NOT EXISTS idx_tech_withdrawals_tech ON technician_withdrawals(technician_id, created_at DESC);

      -- 7. GSTIN Tax Invoices
      CREATE TABLE IF NOT EXISTS invoices (
        id VARCHAR(64) PRIMARY KEY,
        invoice_number VARCHAR(64) UNIQUE NOT NULL,
        booking_id VARCHAR(64) NOT NULL,
        customer_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64),
        sac_code VARCHAR(20) DEFAULT '9987',
        base_amount NUMERIC(10, 2) NOT NULL,
        addon_amount NUMERIC(10, 2) DEFAULT 0.00,
        visit_fee NUMERIC(10, 2) DEFAULT 49.00,
        gst_amount NUMERIC(10, 2) NOT NULL,
        total_amount NUMERIC(10, 2) NOT NULL,
        pdf_url TEXT,
        payment_reference VARCHAR(100),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_invoices_booking ON invoices(booking_id);

      -- 8. Immutable Enterprise Operations Audit Trail
      CREATE TABLE IF NOT EXISTS audit_logs (
        id VARCHAR(64) PRIMARY KEY,
        actor_id VARCHAR(64) NOT NULL,
        actor_role VARCHAR(30) NOT NULL,
        action VARCHAR(100) NOT NULL,
        resource VARCHAR(50) NOT NULL,
        resource_id VARCHAR(64) NOT NULL,
        before_state JSONB,
        after_state JSONB,
        ip_address VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource, resource_id);
    `);

    // Auto-backfill PostGIS geography point if coordinates exist but location is null
    try {
      await pool.query(`
        UPDATE technician_profiles 
        SET location = ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)::geography
        WHERE location IS NULL AND current_latitude IS NOT NULL AND current_longitude IS NOT NULL;
      `);
    } catch (_) {
      // Safe skip if postgis extension is absent
    }

    // Auto-sync master catalog services into PostgreSQL
    try {
      const { getMasterCatalog, getFlattenedServices } = require('./masterCatalog');
      const cats = getMasterCatalog();
      for (const cat of cats) {
        await pool.query(`
          INSERT INTO service_categories (id, name, slug, description, icon_url, banner_image_url, display_order, is_active)
          VALUES ($1, $2, $3, $4, $5, $6, $7, true)
          ON CONFLICT (id) DO UPDATE 
          SET name = EXCLUDED.name,
              slug = EXCLUDED.slug,
              icon_url = EXCLUDED.icon_url,
              banner_image_url = EXCLUDED.banner_image_url,
              display_order = EXCLUDED.display_order,
              is_active = true;
        `, [
          cat.id,
          cat.name,
          (cat.slug || cat.name || '').toLowerCase().replace(/[^a-z0-9]+/g, '-'),
          cat.name,
          cat.imageUrl || cat.icon || '',
          cat.imageUrl || '',
          cat.displayOrder || 1,
        ]);
      }

      const services = getFlattenedServices();
      for (const s of services) {
        await pool.query(`
          INSERT INTO services (id, category_id, name, slug, description, base_price, strike_price, discount_percentage, estimated_time_minutes, warranty_period_days, image_url, is_popular, is_active)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, true)
          ON CONFLICT (id) DO UPDATE
          SET name = EXCLUDED.name,
              category_id = EXCLUDED.category_id,
              slug = EXCLUDED.slug,
              base_price = EXCLUDED.base_price,
              strike_price = EXCLUDED.strike_price,
              discount_percentage = EXCLUDED.discount_percentage,
              estimated_time_minutes = EXCLUDED.estimated_time_minutes,
              image_url = EXCLUDED.image_url,
              is_active = true;
        `, [
          s.id,
          s.categoryId || s.category?.id || 'cat_electrical',
          s.name,
          (s.slug || s.name || '').toLowerCase().replace(/[^a-z0-9]+/g, '-'),
          s.description || s.name,
          s.offerPrice || s.price || 149,
          s.basePrice || s.price || 199,
          s.discount || 0,
          s.durationMinutes || 45,
          30,
          s.imageUrl || '',
          s.isPopular || false,
        ]);
      }
      console.log(`📦 [PostgreSQL] Synced ${cats.length} categories and ${services.length} services to PostgreSQL`);
    } catch (syncErr) {
      console.warn('⚠️ [PostgreSQL] Catalog sync notice:', syncErr.message);
    }

    console.log('✅ [PostgreSQL] Core transactional & KYC schemas verified');
  } catch (err) {
    console.error('❌ [PostgreSQL] Failed to initialize tables:', err.message);
  }
};

const query = async (text, params) => {
  if (isPostgresConnected && pool) {
    return pool.query(text, params);
  }
  return { rows: [] };
};

const isPgHealthy = () => isPostgresConnected;

module.exports = { initPostgres, query, isPgHealthy, getPool: () => pool, inMemoryStore };
