-- ============================================================================
-- BOOKURTECHNICIAN — COMPLETE SUPABASE DATABASE SCHEMA & STORAGE SETUP
-- Target Database: Supabase PostgreSQL 16 + PostGIS Spatial Engine
-- ============================================================================

-- ─── 1. EXTENSIONS ──────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ─── 2. USERS & PROFILES ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(100),
    role VARCHAR(30) NOT NULL CHECK (role IN ('CUSTOMER', 'TECHNICIAN', 'ADMIN', 'SUPER_ADMIN')),
    is_phone_verified BOOLEAN DEFAULT true,
    is_email_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    profile_image_url TEXT,
    fcm_token TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ─── 3. CUSTOMER ADDRESSES ──────────────────────────────────────────────────
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

-- ─── 4. SERVICE CATEGORIES ──────────────────────────────────────────────────
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

-- ─── 5. SERVICES & CATALOG ──────────────────────────────────────────────────
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

CREATE INDEX IF NOT EXISTS idx_services_category ON services(category_id);

-- ─── 6. TECHNICIAN PROFILES & KYC ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS technician_profiles (
    id VARCHAR(64) PRIMARY KEY,
    technician_id VARCHAR(64) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    technician_code VARCHAR(30) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    category VARCHAR(50) DEFAULT 'ELECTRICIAN',
    skills TEXT[] DEFAULT '{}',
    experience_years INT DEFAULT 2,
    kyc_status VARCHAR(30) DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
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

-- ─── 7. TECHNICIAN KYC DOCUMENTS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS technician_kyc_documents (
    id VARCHAR(64) PRIMARY KEY,
    technician_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('AADHAAR', 'VOTER_CARD', 'UPI', 'DRIVING_LICENSE', 'PASSPORT')),
    document_number VARCHAR(100),
    front_image_url TEXT,
    back_image_url TEXT,
    file_size_mb NUMERIC(5, 2),
    verification_status VARCHAR(30) DEFAULT 'PENDING' CHECK (verification_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    verified_at TIMESTAMP WITH TIME ZONE,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 8. UPLOADED MEDIA / PICTURES REPOSITORY (SUPABASE STORAGE REPO) ─────────
CREATE TABLE IF NOT EXISTS uploaded_media (
    id VARCHAR(64) PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    storage_bucket VARCHAR(100) NOT NULL DEFAULT 'app-assets',
    mime_type VARCHAR(50),
    file_size_bytes BIGINT,
    entity_type VARCHAR(50) NOT NULL CHECK (entity_type IN ('BANNER', 'CATEGORY_ICON', 'SERVICE_THUMBNAIL', 'KYC_DOCUMENT', 'AVATAR', 'RECEIPT', 'OTHER')),
    entity_id VARCHAR(64),
    is_public BOOLEAN DEFAULT true,
    uploaded_by VARCHAR(64),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_uploaded_media_entity ON uploaded_media(entity_type, entity_id);

-- ─── 9. BOOKINGS & DISPATCH LIFECYCLE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bookings (
    id VARCHAR(64) PRIMARY KEY,
    booking_code VARCHAR(30) UNIQUE NOT NULL,
    customer_id VARCHAR(64) NOT NULL REFERENCES users(id),
    technician_id VARCHAR(64) REFERENCES users(id),
    service_id VARCHAR(64),
    service_name VARCHAR(150),
    category VARCHAR(50),
    service_items JSONB DEFAULT '[]'::jsonb,
    status VARCHAR(50) NOT NULL CHECK (status IN ('PENDING', 'DISPATCHED', 'ACCEPTED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    full_address TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    base_price NUMERIC(10, 2) DEFAULT 199.00,
    visit_fee NUMERIC(10, 2) DEFAULT 49.00,
    gst_tax NUMERIC(10, 2) DEFAULT 44.64,
    total_amount NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR(30) DEFAULT 'ONLINE',
    payment_status VARCHAR(30) DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'REFUNDED', 'FAILED')),
    start_otp VARCHAR(6) NOT NULL,
    end_otp VARCHAR(6) NOT NULL,
    schedule_date DATE DEFAULT CURRENT_DATE,
    time_slot VARCHAR(50) DEFAULT '3:00 PM – 4:00 PM',
    cancellation_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_technician ON bookings(technician_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- ─── 10. WALLET TRANSACTIONS & PAYMENTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id),
    booking_id VARCHAR(64) REFERENCES bookings(id),
    amount NUMERIC(10, 2) NOT NULL,
    type VARCHAR(30) NOT NULL CHECK (type IN ('CREDIT', 'DEBIT', 'SETTLEMENT', 'REFUND', 'COMMISSION')),
    payment_gateway VARCHAR(50) DEFAULT 'RAZORPAY',
    gateway_transaction_id VARCHAR(100),
    gateway_order_id VARCHAR(100),
    status VARCHAR(30) DEFAULT 'SUCCESS' CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 11. PLATFORM SETTINGS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS platform_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 12. AUDIT LOGS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(64) PRIMARY KEY,
    actor_id VARCHAR(64),
    actor_name VARCHAR(100),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id VARCHAR(64),
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
