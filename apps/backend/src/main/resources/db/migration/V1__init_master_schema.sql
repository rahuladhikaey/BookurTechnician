-- ============================================================================
-- BOOKURTECHNICIAN COMPLETE MASTER PRODUCTION DATABASE SCHEMA
-- Flyway Single Master Migration: V1__init_master_schema.sql
-- ============================================================================

-- ─── 1. CORE EXTENSIONS ──────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ─── 2. USERS & ROLES ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(100),
    role VARCHAR(30) NOT NULL CHECK (role IN ('CUSTOMER', 'TECHNICIAN', 'ADMIN', 'FINANCE_ADMIN', 'SUPER_ADMIN')),
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
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ─── 3. CUSTOMER PROFILES ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_profiles (
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
CREATE TABLE IF NOT EXISTS customer_addresses (
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

CREATE INDEX IF NOT EXISTS idx_customer_addresses_geom ON customer_addresses USING GIST (coordinates);
CREATE INDEX IF NOT EXISTS idx_customer_addresses_customer_id ON customer_addresses(customer_id);

-- ─── 5. SERVICE CATEGORIES & SERVICE ITEMS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS service_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    icon_url TEXT,
    banner_url TEXT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS service_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES service_categories(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    booking_charge NUMERIC(10,2) DEFAULT 49.00,
    advance_prepayment_pct INT DEFAULT 30,
    technician_payout_amount NUMERIC(10,2),
    duration_minutes INT DEFAULT 45,
    warranty_text VARCHAR(100) DEFAULT '30-Day Service Warranty',
    description TEXT,
    image_url TEXT,
    is_popular BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_service_items_category ON service_items(category_id);
CREATE INDEX IF NOT EXISTS idx_service_items_slug ON service_items(slug);

CREATE TABLE IF NOT EXISTS service_brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    logo_url TEXT,
    category_id UUID REFERENCES service_categories(id),
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS service_brand_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID NOT NULL REFERENCES service_brands(id) ON DELETE CASCADE,
    model_name VARCHAR(100) NOT NULL,
    model_number VARCHAR(100),
    is_active BOOLEAN DEFAULT true
);

-- ─── 6. SERVICE SKILLS & COMPATIBILITY MATRIX ────────────────────────────────
CREATE TABLE IF NOT EXISTS service_skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES service_categories(id) ON DELETE CASCADE,
    service_item_id UUID REFERENCES service_items(id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(150) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_service_skills_category ON service_skills(category_id);

CREATE TABLE IF NOT EXISTS skill_service_compatibilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    skill_id UUID NOT NULL REFERENCES service_skills(id) ON DELETE CASCADE,
    service_item_id UUID NOT NULL REFERENCES service_items(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_skill_service_comp UNIQUE(skill_id, service_item_id)
);

-- ─── 7. TECHNICIAN PROFILES & FLEET WALLETS ──────────────────────────────────
CREATE TABLE IF NOT EXISTS technician_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    technician_code VARCHAR(30) UNIQUE NOT NULL,
    primary_category_id UUID REFERENCES service_categories(id),
    skills_list TEXT[],
    is_online BOOLEAN DEFAULT false,
    current_location GEOMETRY(Point, 4326),
    location_updated_at TIMESTAMP WITH TIME ZONE,
    kyc_status VARCHAR(30) DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'SUBMITTED', 'VERIFIED', 'REJECTED')),
    rejection_reason TEXT,
    rating NUMERIC(3,2) DEFAULT 5.00 CHECK (rating BETWEEN 1.00 AND 5.00),
    total_ratings_count INT DEFAULT 0,
    total_jobs_completed INT DEFAULT 0,
    upi_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_technician_profiles_geom ON technician_profiles USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_technician_profiles_online ON technician_profiles(is_online);
CREATE INDEX IF NOT EXISTS idx_technician_profiles_kyc ON technician_profiles(kyc_status);

CREATE TABLE IF NOT EXISTS technician_skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    skill_id UUID NOT NULL REFERENCES service_skills(id) ON DELETE CASCADE,
    experience_years INT DEFAULT 1,
    verification_status VARCHAR(30) DEFAULT 'PENDING' CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    is_enabled BOOLEAN DEFAULT true,
    certificate_url TEXT,
    rejection_reason TEXT,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_technician_skill UNIQUE(technician_id, skill_id)
);

CREATE TABLE IF NOT EXISTS technician_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('AADHAAR_FRONT', 'AADHAAR_BACK', 'PAN_CARD', 'DRIVING_LICENSE', 'POLICE_VERIFICATION', 'TRADE_CERTIFICATE')),
    secure_cloudinary_url TEXT NOT NULL,
    masked_number VARCHAR(50),
    verification_status VARCHAR(30) DEFAULT 'PENDING' CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    reviewer_notes TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS technician_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID UNIQUE NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    available_balance NUMERIC(10,2) DEFAULT 0.00 CHECK (available_balance >= 0),
    total_withdrawn NUMERIC(10,2) DEFAULT 0.00 CHECK (total_withdrawn >= 0),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code VARCHAR(50) UNIQUE NOT NULL,
    technician_id UUID NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    destination_upi_id VARCHAR(100) NOT NULL,
    utr_number VARCHAR(100) UNIQUE,
    status VARCHAR(30) DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED', 'SETTLED')),
    rejection_reason TEXT,
    settled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 8. BOOKINGS & DUAL OTP LIFECYCLE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_code VARCHAR(30) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES users(id),
    technician_id UUID REFERENCES technician_profiles(id),
    service_id UUID NOT NULL REFERENCES service_items(id),
    address_id UUID NOT NULL REFERENCES customer_addresses(id),
    scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
    service_window_start TIMESTAMP WITH TIME ZONE,
    service_window_end TIMESTAMP WITH TIME ZONE,
    status VARCHAR(40) DEFAULT 'CONFIRMED' CHECK (status IN (
        'PENDING', 'CONFIRMED', 'SEARCHING_TECHNICIAN', 'TECHNICIAN_NOTIFIED',
        'ASSIGNED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'EXPIRED'
    )),
    total_amount NUMERIC(10,2) NOT NULL,
    booking_charge NUMERIC(10,2) DEFAULT 49.00,
    advance_prepayment_amount NUMERIC(10,2) DEFAULT 0.00,
    remaining_payable_amount NUMERIC(10,2),
    technician_payout_amount NUMERIC(10,2),
    payment_status VARCHAR(30) DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PARTIALLY_PAID', 'PAID', 'REFUNDED')),
    payment_method VARCHAR(30) DEFAULT 'ONLINE' CHECK (payment_method IN ('ONLINE', 'CASH_ON_DELIVERY', 'UPI_QR')),
    start_otp VARCHAR(6),
    end_otp VARCHAR(6),
    start_otp_expires_at TIMESTAMP WITH TIME ZONE,
    end_otp_expires_at TIMESTAMP WITH TIME ZONE,
    failed_otp_attempts INT DEFAULT 0,
    is_force_assigned BOOLEAN DEFAULT false,
    force_assigned_by VARCHAR(255),
    force_assigned_at TIMESTAMP WITH TIME ZONE,
    start_otp_bypassed BOOLEAN DEFAULT false,
    end_otp_bypassed BOOLEAN DEFAULT false,
    otp_bypassed_by VARCHAR(255),
    otp_bypassed_at TIMESTAMP WITH TIME ZONE,
    otp_bypass_reason TEXT,
    cancellation_reason TEXT,
    cancelled_by VARCHAR(30),
    service_started_at TIMESTAMP WITH TIME ZONE,
    service_completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_technician ON bookings(technician_id);

CREATE TABLE IF NOT EXISTS booking_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    previous_status VARCHAR(40),
    new_status VARCHAR(40) NOT NULL,
    notes TEXT,
    changed_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─── 9. PAYMENTS, REFUNDS & REVIEWS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    razorpay_order_id VARCHAR(100),
    razorpay_payment_id VARCHAR(100),
    amount NUMERIC(10,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    status VARCHAR(30) DEFAULT 'CREATED' CHECK (status IN ('CREATED', 'CAPTURED', 'FAILED', 'REFUNDED')),
    raw_webhook_payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    razorpay_refund_id VARCHAR(100),
    amount NUMERIC(10,2) NOT NULL,
    reason TEXT,
    status VARCHAR(30) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSED', 'FAILED', 'SETTLED')),
    settled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES users(id),
    technician_id UUID NOT NULL REFERENCES technician_profiles(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    is_hidden BOOLEAN DEFAULT false,
    is_flagged BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS promotional_banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(150) NOT NULL,
    image_url TEXT NOT NULL,
    target_route VARCHAR(255),
    category_id UUID REFERENCES service_categories(id),
    service_id UUID REFERENCES service_items(id),
    banner_type VARCHAR(50) DEFAULT 'PROMOTIONAL',
    discount_percentage INT,
    badge_text VARCHAR(50),
    coupon_code VARCHAR(50),
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '30 days'
);

-- ─── 10. DISPATCH ENGINE & CONTROL TOWER ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS dispatch_matching_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    search_radius_km DOUBLE PRECISION NOT NULL DEFAULT 10.0,
    strict_skill_matching BOOLEAN NOT NULL DEFAULT true,
    score_weight_distance DOUBLE PRECISION NOT NULL DEFAULT 0.40,
    score_weight_rating DOUBLE PRECISION NOT NULL DEFAULT 0.30,
    score_weight_acceptance DOUBLE PRECISION NOT NULL DEFAULT 0.15,
    score_weight_experience DOUBLE PRECISION NOT NULL DEFAULT 0.15,
    priority_policy VARCHAR(50) NOT NULL DEFAULT 'BALANCED',
    notification_timeout_seconds INT NOT NULL DEFAULT 30,
    max_dispatch_attempts INT NOT NULL DEFAULT 5,
    auto_escalate_to_admin BOOLEAN NOT NULL DEFAULT true,
    updated_by_email VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dispatch_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    attempt_number INT DEFAULT 1,
    status VARCHAR(30) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'TIMEOUT', 'CANCELLED')),
    response_deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    responded_at TIMESTAMP WITH TIME ZONE,
    calculated_score NUMERIC(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id),
    booking_id UUID REFERENCES bookings(id),
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'MEDIUM' CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
    status VARCHAR(30) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_type VARCHAR(30) DEFAULT 'ALL' CHECK (recipient_type IN ('ALL', 'CUSTOMERS', 'TECHNICIANS', 'INDIVIDUAL')),
    recipient_user_id UUID REFERENCES users(id),
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'BROADCAST',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_knowledge_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    token_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_faqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
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
