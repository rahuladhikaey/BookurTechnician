

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

      -- 9. Technician Availability & Working Hours (Section 14 & 16)
      CREATE TABLE IF NOT EXISTS technician_availability (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
        start_time VARCHAR(10) NOT NULL DEFAULT '08:00',
        end_time VARCHAR(10) NOT NULL DEFAULT '21:00',
        is_available BOOLEAN DEFAULT true,
        unavailable_from TIMESTAMP WITH TIME ZONE,
        unavailable_until TIMESTAMP WITH TIME ZONE,
        max_concurrent_jobs INT DEFAULT 1,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        CONSTRAINT uq_tech_availability_day UNIQUE(technician_id, day_of_week)
      );
      CREATE INDEX IF NOT EXISTS idx_tech_availability_tech ON technician_availability(technician_id, day_of_week, is_available);

      -- 10. Technician Service Skills Mapping (Section 3 & 16)
      CREATE TABLE IF NOT EXISTS technician_service_skills (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        service_id VARCHAR(64) NOT NULL,
        category_id VARCHAR(64),
        proficiency_level VARCHAR(30) DEFAULT 'EXPERT',
        is_verified BOOLEAN DEFAULT true,
        active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        CONSTRAINT uq_tech_service_skill UNIQUE(technician_id, service_id)
      );
      CREATE INDEX IF NOT EXISTS idx_tech_service_skills_lookup ON technician_service_skills(service_id, active, is_verified);
      CREATE INDEX IF NOT EXISTS idx_tech_service_skills_tech ON technician_service_skills(technician_id, active);

      -- 11. Dispatch Sessions (Booking Dispatch Lifecycle - Section 6 & 16)
      CREATE TABLE IF NOT EXISTS dispatch_sessions (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) UNIQUE NOT NULL,
        booking_mode VARCHAR(20) NOT NULL DEFAULT 'INSTANT',
        status VARCHAR(40) NOT NULL DEFAULT 'SEARCHING',
        current_radius_km DOUBLE PRECISION NOT NULL DEFAULT 3.0,
        attempt_number INT NOT NULL DEFAULT 0,
        max_attempts INT NOT NULL DEFAULT 12,
        offer_timeout_seconds INT NOT NULL DEFAULT 20,
        active_offer_id VARCHAR(64),
        assigned_technician_id VARCHAR(64),
        scheduled_dispatch_at TIMESTAMP WITH TIME ZONE,
        failure_reason TEXT,
        config_snapshot JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_dispatch_sessions_status ON dispatch_sessions(status, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_dispatch_sessions_booking ON dispatch_sessions(booking_id);

      -- 12. Dispatch Offers (Sequential Technician Offers - Section 6, 7 & 16)
      CREATE TABLE IF NOT EXISTS dispatch_offers (
        id VARCHAR(64) PRIMARY KEY,
        session_id VARCHAR(64) NOT NULL REFERENCES dispatch_sessions(id) ON DELETE CASCADE,
        booking_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
        attempt_number INT NOT NULL DEFAULT 1,
        radius_km DOUBLE PRECISION NOT NULL DEFAULT 3.0,
        distance_km DOUBLE PRECISION,
        eta_minutes INT,
        eta_source VARCHAR(30) DEFAULT 'HAVERSINE_ESTIMATE',
        expected_earning NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
        total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
        service_id VARCHAR(64),
        service_name VARCHAR(150),
        approximate_area TEXT,
        appointment_time VARCHAR(100),
        ranking_score NUMERIC(6, 4) DEFAULT 0.0000,
        ranking_reasons JSONB DEFAULT '{}'::jsonb,
        sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
        responded_at TIMESTAMP WITH TIME ZONE,
        rejection_reason TEXT,
        fcm_message_id VARCHAR(128),
        fcm_delivery_status VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_dispatch_offers_tech_status ON dispatch_offers(technician_id, status, expires_at);
      CREATE INDEX IF NOT EXISTS idx_dispatch_offers_booking_status ON dispatch_offers(booking_id, status);
      CREATE INDEX IF NOT EXISTS idx_dispatch_offers_session ON dispatch_offers(session_id, attempt_number);

      -- 13. Persistent Technician Location Updates (Section 12 & 16)
      CREATE TABLE IF NOT EXISTS technician_location_updates (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        booking_id VARCHAR(64),
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        speed DOUBLE PRECISION DEFAULT 0,
        heading DOUBLE PRECISION DEFAULT 0,
        recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_tech_location_updates_tech ON technician_location_updates(technician_id, recorded_at DESC);
      CREATE INDEX IF NOT EXISTS idx_tech_location_updates_booking ON technician_location_updates(booking_id, recorded_at DESC);

      -- 14. Dispatch Audit Logs (Section 15, 16 & 21)
      CREATE TABLE IF NOT EXISTS dispatch_audit_logs (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        session_id VARCHAR(64),
        offer_id VARCHAR(64),
        technician_id VARCHAR(64),
        actor_id VARCHAR(64),
        actor_role VARCHAR(30) DEFAULT 'SYSTEM',
        event_type VARCHAR(60) NOT NULL,
        details JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_dispatch_audit_booking ON dispatch_audit_logs(booking_id, created_at ASC);
      CREATE INDEX IF NOT EXISTS idx_dispatch_audit_tech ON dispatch_audit_logs(technician_id, created_at DESC);

      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT true;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS service_radius_km DOUBLE PRECISION DEFAULT 15.0;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS acceptance_rate NUMERIC(5, 2) DEFAULT 95.00;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS completed_offers_count INT DEFAULT 10;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS total_offers_count INT DEFAULT 10;
      ALTER TABLE technician_profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(128);
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_idempotency_key ON bookings(idempotency_key) WHERE idempotency_key IS NOT NULL;

      -- 15. Booking Status History (Phase 3 & 15)
      CREATE TABLE IF NOT EXISTS booking_status_history (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        previous_status VARCHAR(50),
        new_status VARCHAR(50) NOT NULL,
        actor_id VARCHAR(64),
        actor_role VARCHAR(30) DEFAULT 'SYSTEM',
        reason TEXT,
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_booking_status_history_booking ON booking_status_history(booking_id, created_at ASC);

      -- 16. Technician Locations (Phase 8 & 15)
      CREATE TABLE IF NOT EXISTS technician_locations (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        booking_id VARCHAR(64),
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        speed DOUBLE PRECISION DEFAULT 0,
        heading DOUBLE PRECISION DEFAULT 0,
        accuracy DOUBLE PRECISION DEFAULT 10,
        recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_technician_locations_tech ON technician_locations(technician_id, recorded_at DESC);
      CREATE INDEX IF NOT EXISTS idx_technician_locations_booking ON technician_locations(booking_id, recorded_at DESC);

      -- 17. Technician Assignments (Phase 6 & 15)
      CREATE TABLE IF NOT EXISTS technician_assignments (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        session_id VARCHAR(64),
        offer_id VARCHAR(64),
        technician_id VARCHAR(64) NOT NULL,
        assignment_type VARCHAR(30) NOT NULL DEFAULT 'AUTOMATIC_DISPATCH',
        assigned_by VARCHAR(64) DEFAULT 'SYSTEM',
        reason TEXT,
        status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
        assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        released_at TIMESTAMP WITH TIME ZONE
      );
      CREATE INDEX IF NOT EXISTS idx_tech_assignments_booking ON technician_assignments(booking_id, status);
      CREATE INDEX IF NOT EXISTS idx_tech_assignments_tech ON technician_assignments(technician_id, status);

      -- 18. Service Proofs (Phase 10 & 15)
      CREATE TABLE IF NOT EXISTS service_proofs (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        proof_type VARCHAR(30) NOT NULL,
        media_url TEXT NOT NULL,
        summary_notes TEXT,
        gps_lat DOUBLE PRECISION,
        gps_lng DOUBLE PRECISION,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_service_proofs_booking ON service_proofs(booking_id, proof_type);

      -- 19. Payments & Webhook Events & Refunds (Phase 11 & 15)
      CREATE TABLE IF NOT EXISTS payments (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        customer_id VARCHAR(64) NOT NULL,
        razorpay_order_id VARCHAR(100),
        razorpay_payment_id VARCHAR(100),
        amount NUMERIC(10, 2) NOT NULL,
        currency VARCHAR(10) DEFAULT 'INR',
        method VARCHAR(40) DEFAULT 'ONLINE_RAZORPAY',
        status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);
      CREATE INDEX IF NOT EXISTS idx_payments_rzp_order ON payments(razorpay_order_id);

      CREATE TABLE IF NOT EXISTS payment_webhook_events (
        id VARCHAR(64) PRIMARY KEY,
        event_id VARCHAR(128) UNIQUE NOT NULL,
        event_type VARCHAR(80) NOT NULL,
        booking_id VARCHAR(64),
        payment_id VARCHAR(100),
        payload JSONB DEFAULT '{}'::jsonb,
        processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_payment_webhooks_event ON payment_webhook_events(event_id);

      CREATE TABLE IF NOT EXISTS refunds (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        payment_id VARCHAR(100),
        customer_id VARCHAR(64),
        amount NUMERIC(10, 2) NOT NULL,
        cancellation_fee NUMERIC(10, 2) DEFAULT 0.00,
        gateway_refund_id VARCHAR(100),
        reason TEXT,
        status VARCHAR(30) NOT NULL DEFAULT 'PROCESSED',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_refunds_booking ON refunds(booking_id);

      -- 20. Technician Earnings Ledger (Phase 11 & 15)
      CREATE TABLE IF NOT EXISTS technician_earnings_ledger (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64) NOT NULL,
        gross_amount NUMERIC(10, 2) NOT NULL,
        platform_fee NUMERIC(10, 2) NOT NULL,
        net_earning NUMERIC(10, 2) NOT NULL,
        payment_method VARCHAR(30) DEFAULT 'ONLINE',
        status VARCHAR(30) DEFAULT 'SETTLED',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_tech_earnings_ledger_tech ON technician_earnings_ledger(technician_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_tech_earnings_ledger_booking ON technician_earnings_ledger(booking_id);

      -- 21. Notifications & Booking Audit Logs (Phase 14 & 15)
      CREATE TABLE IF NOT EXISTS notifications (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        role VARCHAR(30) DEFAULT 'CUSTOMER',
        title VARCHAR(200) NOT NULL,
        body TEXT NOT NULL,
        type VARCHAR(60) DEFAULT 'GENERAL',
        data JSONB DEFAULT '{}'::jsonb,
        fcm_message_id VARCHAR(128),
        delivery_status VARCHAR(40) DEFAULT 'SENT',
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS booking_audit_logs (
        id VARCHAR(64) PRIMARY KEY,
        booking_id VARCHAR(64) NOT NULL,
        actor_id VARCHAR(64),
        actor_role VARCHAR(30) DEFAULT 'SYSTEM',
        event_type VARCHAR(60) NOT NULL,
        before_state JSONB,
        after_state JSONB,
        details JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_booking_audit_logs_booking ON booking_audit_logs(booking_id, created_at ASC);

      -- 22. Account Deletion Requests (Google Play & Indus Appstore Compliance)
      CREATE TABLE IF NOT EXISTS account_deletion_requests (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64),
        role VARCHAR(30) DEFAULT 'CUSTOMER',
        phone VARCHAR(30),
        email VARCHAR(120),
        reason TEXT,
        status VARCHAR(30) DEFAULT 'COMPLETED',
        details JSONB DEFAULT '{}'::jsonb,
        anonymized_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_user ON account_deletion_requests(user_id, status);
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
