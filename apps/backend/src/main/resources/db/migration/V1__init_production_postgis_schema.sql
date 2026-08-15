-- ============================================================================
-- BOOKURTECHNICIAN PRODUCTION DATABASE SCHEMA (POSTGRESQL + POSTGIS)
-- Flyway Migration: V1__init_production_postgis_schema.sql
-- Single Source of Truth for Hyperlocal On-Demand Service Engine
-- ============================================================================

-- ─── 1. CORE EXTENSIONS ──────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ─── 2. USERS & ROLES ────────────────────────────────────────────────────────
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(100),
    role VARCHAR(30) NOT NULL CHECK (role IN ('CUSTOMER', 'TECHNICIAN', 'ADMIN', 'FINANCE_ADMIN', 'SUPER_ADMIN')),
    is_phone_verified BOOLEAN DEFAULT true,
    is_email_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    profile_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 3. CUSTOMER PROFILES (DYNAMIC COMPLETION SCORE) ─────────────────────────
CREATE TABLE customer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date_of_birth DATE,
    anniversary_date DATE,
    gender VARCHAR(20),
    profile_completion_percentage INT DEFAULT 25 CHECK (profile_completion_percentage BETWEEN 0 AND 100),
    compliance_status VARCHAR(30) DEFAULT 'INCOMPLETE' CHECK (compliance_status IN ('INCOMPLETE', 'PARTIALLY_COMPLETE', 'COMPLETE')),
    has_valid_name BOOLEAN DEFAULT false,
    has_verified_phone BOOLEAN DEFAULT true,
    has_verified_email BOOLEAN DEFAULT false,
    has_service_address BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 4. CUSTOMER ADDRESSES (SPATIAL POSTGIS) ─────────────────────────────────
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL CHECK (address_type IN ('HOME', 'WORK', 'OTHER')),
    house_flat VARCHAR(100) NOT NULL,
    street VARCHAR(255) NOT NULL,
    area VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    postal_code VARCHAR(10) NOT NULL,
    landmark TEXT,
    coordinates GEOMETRY(Point, 4326),
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_customer_addresses_geom ON customer_addresses USING GIST (coordinates);
CREATE INDEX idx_customer_addresses_customer_id ON customer_addresses(customer_id);

-- ─── 5. SERVICE CATALOG: CATEGORIES, ITEMS & BRANDS ──────────────────────────
CREATE TABLE service_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    icon_url TEXT,
    banner_url TEXT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE service_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES service_categories(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    duration_minutes INT DEFAULT 45,
    warranty_text VARCHAR(100) DEFAULT '30-Day Service Warranty',
    description TEXT,
    image_url TEXT,
    is_popular BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE service_brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    logo_url TEXT,
    category_id UUID REFERENCES service_categories(id),
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE service_brand_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID NOT NULL REFERENCES service_brands(id) ON DELETE CASCADE,
    model_name VARCHAR(150) NOT NULL,
    model_number VARCHAR(100),
    is_active BOOLEAN DEFAULT true
);

-- ─── 6. TECHNICIAN PROFILES & KYC VERIFICATION ───────────────────────────────
CREATE TABLE technician_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    technician_code VARCHAR(30) UNIQUE NOT NULL, -- e.g. BT-TECH-000001
    primary_category_id UUID REFERENCES service_categories(id),
    skills_list TEXT[] DEFAULT '{}',
    is_online BOOLEAN DEFAULT false,
    current_location GEOMETRY(Point, 4326),
    location_updated_at TIMESTAMP WITH TIME ZONE,
    kyc_status VARCHAR(30) DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'SUBMITTED', 'VERIFIED', 'REJECTED')),
    rejection_reason TEXT,
    rating NUMERIC(2,1) DEFAULT 5.0 CHECK (rating BETWEEN 1.0 AND 5.0),
    total_ratings_count INT DEFAULT 0,
    total_jobs_completed INT DEFAULT 0,
    upi_id VARCHAR(100) NOT NULL DEFAULT 'technician@upi',
    is_upi_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_technicians_geom ON technician_profiles USING GIST (current_location);
CREATE INDEX idx_technicians_online ON technician_profiles (is_online, kyc_status);

CREATE TABLE technician_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('AADHAAR_FRONT', 'AADHAAR_BACK', 'PAN_CARD', 'POLICE_VERIFICATION', 'SELFIE')),
    secure_cloudinary_url TEXT NOT NULL,
    masked_number VARCHAR(50),
    verification_status VARCHAR(30) DEFAULT 'PENDING' CHECK (verification_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    reviewer_notes TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 7. BOOKINGS & HYPERLOCAL DISPATCH LIFECYCLE ─────────────────────────────
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_code VARCHAR(30) UNIQUE NOT NULL, -- e.g. BT-92841029
    customer_id UUID NOT NULL REFERENCES users(id),
    technician_id UUID REFERENCES technician_profiles(id),
    address_id UUID NOT NULL REFERENCES customer_addresses(id),
    service_id UUID NOT NULL REFERENCES service_items(id),
    status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED' CHECK (status IN (
        'REQUESTED', 'CONFIRMED', 'ASSIGNED', 'ON_THE_WAY', 
        'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
    )),
    schedule_date DATE NOT NULL,
    schedule_slot VARCHAR(50) NOT NULL,
    base_price NUMERIC(10,2) NOT NULL,
    safety_fee NUMERIC(10,2) NOT NULL DEFAULT 49.00,
    gst_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(10,2) NOT NULL,
    platform_commission_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    technician_payout_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    start_service_otp VARCHAR(6),
    cancellation_reason TEXT,
    cancelled_by VARCHAR(30),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_technician ON bookings(technician_id);
CREATE INDEX idx_bookings_status ON bookings(status);

CREATE TABLE booking_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    previous_status VARCHAR(30),
    next_status VARCHAR(30) NOT NULL,
    actor_id UUID,
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 8. PAYMENTS & REFUNDS ENGINE ────────────────────────────────────────────
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id),
    razorpay_order_id VARCHAR(100) UNIQUE NOT NULL,
    razorpay_payment_id VARCHAR(100) UNIQUE,
    razorpay_signature VARCHAR(255),
    amount NUMERIC(10,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    payment_method VARCHAR(50),
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    refund_code VARCHAR(50) UNIQUE NOT NULL,
    booking_id UUID NOT NULL REFERENCES bookings(id),
    payment_id UUID NOT NULL REFERENCES payments(id),
    requested_amount NUMERIC(10,2) NOT NULL,
    non_refundable_amount NUMERIC(10,2) NOT NULL DEFAULT 49.00,
    refundable_amount NUMERIC(10,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'INITIATED' CHECK (status IN ('INITIATED', 'PROCESSING', 'SETTLED', 'FAILED')),
    razorpay_refund_id VARCHAR(100),
    cancellation_time TIMESTAMP WITH TIME ZONE NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    settled_at TIMESTAMP WITH TIME ZONE
);

-- ─── 9. TECHNICIAN WALLET & IMMUTABLE LEDGER ─────────────────────────────────
CREATE TABLE technician_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID UNIQUE NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    available_balance NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (available_balance >= 0),
    total_withdrawn NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE wallet_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES technician_wallets(id),
    entry_type VARCHAR(20) NOT NULL CHECK (entry_type IN ('CREDIT', 'DEBIT')),
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    balance_before NUMERIC(10,2) NOT NULL,
    balance_after NUMERIC(10,2) NOT NULL,
    reference_type VARCHAR(50) NOT NULL CHECK (reference_type IN ('BOOKING_EARNING', 'INCENTIVE_BONUS', 'UPI_WITHDRAWAL', 'ADMIN_ADJUSTMENT')),
    reference_id VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code VARCHAR(50) UNIQUE NOT NULL, -- e.g. WDR-918231
    technician_id UUID NOT NULL REFERENCES technician_profiles(id),
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    destination_upi_id VARCHAR(100) NOT NULL,
    status VARCHAR(30) DEFAULT 'PROCESSING' CHECK (status IN ('PROCESSING', 'SETTLED', 'REJECTED')),
    razorpayx_payout_id VARCHAR(100),
    utr_number VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    settled_at TIMESTAMP WITH TIME ZONE
);

-- ─── 10. REVIEWS & AUDIT LOGS ────────────────────────────────────────────────
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    technician_id UUID NOT NULL REFERENCES technician_profiles(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(150) NOT NULL,
    subtitle TEXT,
    image_url TEXT NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_payload TEXT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID,
    actor_email VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100),
    client_ip VARCHAR(50),
    changes_json JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
