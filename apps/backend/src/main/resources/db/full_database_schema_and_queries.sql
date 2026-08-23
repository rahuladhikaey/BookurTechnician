-- ============================================================================
-- BOOKURTECHNICIAN COMPLETE MASTER DATABASE SCHEMA & SEED QUERIES SCRIPT
-- PostgreSQL 14+ with PostGIS Spatial Extension
-- ============================================================================
-- Application: BookurTechnician (Hyperlocal On-Demand Service Engine)
-- Target DB: PostgreSQL (Supabase / Render / AWS RDS / Self-Hosted Docker)
-- ============================================================================

-- ─── SECTION 1: DATABASE EXTENSIONS ─────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ─── SECTION 2: TABLE CREATIONS & CONSTRAINTS ───────────────────────────────

-- 1. USERS & ROLES
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
    fcm_token VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;

-- 2. CUSTOMER PROFILES
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

-- 3. CUSTOMER ADDRESSES (POSTGIS GEOMETRY)
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

-- 4. SERVICE CATEGORIES
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

-- 5. SERVICE ITEMS & PRICING
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

-- 6. SERVICE BRANDS & MODELS
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
    model_name VARCHAR(150) NOT NULL,
    model_number VARCHAR(100),
    is_active BOOLEAN DEFAULT true
);

-- 7. SERVICE SKILLS & COMPATIBILITY MAPPING
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

CREATE TABLE IF NOT EXISTS skill_service_compatibilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    skill_id UUID NOT NULL REFERENCES service_skills(id) ON DELETE CASCADE,
    service_item_id UUID NOT NULL REFERENCES service_items(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_skill_service_comp UNIQUE(skill_id, service_item_id)
);

-- 8. TECHNICIAN PROFILES & KYC
CREATE TABLE IF NOT EXISTS technician_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    technician_code VARCHAR(30) UNIQUE NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_technicians_geom ON technician_profiles USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_technicians_online ON technician_profiles (is_online, kyc_status);

CREATE TABLE IF NOT EXISTS technician_documents (
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

-- 9. BOOKINGS & HYPERLOCAL DISPATCH
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_code VARCHAR(30) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES users(id),
    technician_id UUID REFERENCES technician_profiles(id),
    address_id UUID NOT NULL REFERENCES customer_addresses(id),
    service_id UUID NOT NULL REFERENCES service_items(id),
    status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED' CHECK (status IN (
        'REQUESTED', 'PAYMENT_PENDING', 'PAYMENT_VERIFIED', 'CONFIRMED', 
        'SEARCHING_TECHNICIAN', 'TECHNICIAN_NOTIFIED', 'ASSIGNED', 
        'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 
        'CANCELLED', 'NO_TECHNICIAN_AVAILABLE'
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
    start_otp_expires_at TIMESTAMP WITH TIME ZONE,
    end_service_otp VARCHAR(6),
    end_otp_expires_at TIMESTAMP WITH TIME ZONE,
    failed_otp_attempts INT DEFAULT 0,
    cancellation_reason TEXT,
    cancelled_by VARCHAR(30),
    is_force_assigned BOOLEAN DEFAULT FALSE,
    force_assigned_by VARCHAR(100),
    force_assigned_at TIMESTAMP WITH TIME ZONE,
    start_otp_bypassed BOOLEAN DEFAULT FALSE,
    end_otp_bypassed BOOLEAN DEFAULT FALSE,
    otp_bypassed_by VARCHAR(100),
    otp_bypassed_at TIMESTAMP WITH TIME ZONE,
    otp_bypass_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_technician ON bookings(technician_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

CREATE TABLE IF NOT EXISTS booking_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    previous_status VARCHAR(30),
    next_status VARCHAR(30) NOT NULL,
    actor_id UUID,
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS booking_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    distance_meters NUMERIC(10,2) NOT NULL,
    estimated_earnings NUMERIC(10,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    responded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_booking_proposals_booking ON booking_proposals(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_proposals_tech ON booking_proposals(technician_id, status);

-- 10. PAYMENTS & REFUNDS
CREATE TABLE IF NOT EXISTS payments (
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

CREATE TABLE IF NOT EXISTS refunds (
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

-- 11. TECHNICIAN WALLET & LEDGER
CREATE TABLE IF NOT EXISTS technician_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID UNIQUE NOT NULL REFERENCES technician_profiles(id) ON DELETE CASCADE,
    available_balance NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (available_balance >= 0),
    total_withdrawn NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallet_ledger (
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

CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code VARCHAR(50) UNIQUE NOT NULL,
    technician_id UUID NOT NULL REFERENCES technician_profiles(id),
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    destination_upi_id VARCHAR(100) NOT NULL,
    status VARCHAR(30) DEFAULT 'PROCESSING' CHECK (status IN ('PROCESSING', 'SETTLED', 'REJECTED')),
    razorpayx_payout_id VARCHAR(100),
    utr_number VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    settled_at TIMESTAMP WITH TIME ZONE
);

-- 12. REVIEWS, BANNERS & AUDIT LOGS
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    technician_id UUID NOT NULL REFERENCES technician_profiles(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    is_hidden BOOLEAN DEFAULT false,
    is_flagged BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(150) NOT NULL,
    subtitle TEXT,
    image_url TEXT NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_payload TEXT,
    banner_type VARCHAR(30) DEFAULT 'HERO' CHECK (banner_type IN ('HERO', 'SPOTLIGHT', 'RUNNING')),
    badge_text VARCHAR(50),
    cta_text VARCHAR(50) DEFAULT 'Book Now',
    category_id UUID REFERENCES service_categories(id) ON DELETE SET NULL,
    service_id UUID REFERENCES service_items(id) ON DELETE SET NULL,
    display_order INT DEFAULT 0,
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

-- 13. SUPPORT TICKETS, NOTIFICATIONS & AI ASSISTANT CMS
CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    customer_name VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(255),
    subject VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    priority VARCHAR(30) NOT NULL DEFAULT 'MEDIUM' CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
    assigned_to VARCHAR(100),
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    recipient_type VARCHAR(30) NOT NULL CHECK (recipient_type IN ('CUSTOMER', 'TECHNICIAN', 'ADMIN', 'ALL')),
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
    metadata_json JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_knowledge_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
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

-- 14. DISPATCH MATCHING ALGORITHM CONFIGURATION
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

-- ─── SECTION 3: COMPREHENSIVE INITIAL SEED DATA ────────────────────────────

-- 1. Default System Users (Admin, Customers, Technicians)
INSERT INTO users (id, phone, email, full_name, role, is_phone_verified, is_email_verified, is_active, created_at, updated_at) VALUES 
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '+919999999999', 'admin@bookurtechnician.com', 'Super Admin', 'SUPER_ADMIN', true, true, true, NOW(), NOW()),
('c1111111-1111-1111-1111-111111111111', '+919876543210', 'rahul.customer@gmail.com', 'Rahul Sharma', 'CUSTOMER', true, true, true, NOW(), NOW()),
('c2222222-2222-2222-2222-222222222222', '+919876543211', 'priya.verma@gmail.com', 'Priya Verma', 'CUSTOMER', true, true, true, NOW(), NOW()),
('t1111111-1111-1111-1111-111111111111', '+919811122233', 'rajesh.tech@gmail.com', 'Rajesh Kumar', 'TECHNICIAN', true, true, true, NOW(), NOW()),
('t2222222-2222-2222-2222-222222222222', '+919822233344', 'amit.tech@gmail.com', 'Amit Singh', 'TECHNICIAN', true, true, true, NOW(), NOW())
ON CONFLICT (phone) DO NOTHING;

-- 2. Customer Profiles & PostGIS Addresses
INSERT INTO customer_profiles (id, user_id, profile_completion_percentage, compliance_status, has_valid_name, has_verified_phone, has_verified_email, has_service_address) VALUES 
('cp111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 100, 'COMPLETE', true, true, true, true),
('cp222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', 100, 'COMPLETE', true, true, true, true)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO customer_addresses (id, customer_id, address_type, house_flat, street, area, city, state, postal_code, landmark, coordinates, is_primary) VALUES 
('ca111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 'HOME', 'Flat 402, Sunshine Apts', 'MG Road', 'Indiranagar', 'Bengaluru', 'Karnataka', '560038', 'Near Metro Station', ST_SetSRID(ST_MakePoint(77.6412, 12.9784), 4326), true),
('ca222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', 'HOME', 'No 15, 27th Main', 'Sector 1', 'HSR Layout', 'Bengaluru', 'Karnataka', '560102', 'Opposite BDA Complex', ST_SetSRID(ST_MakePoint(77.6412, 12.9141), 4326), true)
ON CONFLICT (id) DO NOTHING;

-- 3. Service Categories
INSERT INTO service_categories (id, name, slug, icon_url, banner_url, display_order, is_active) VALUES 
('cat-11111111-1111-1111-1111-111111111111', 'Electrical & Home Electrical', 'electrical-services', 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500', 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800', 1, true),
('cat-22222222-2222-2222-2222-222222222222', 'AC Services', 'ac-services', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800', 2, true),
('cat-33333333-3333-3333-3333-333333333333', 'Refrigerator', 'refrigerator-services', 'https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=500', 'https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=800', 3, true),
('cat-44444444-4444-4444-4444-444444444444', 'Washing Machine', 'washing-machine-services', 'https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?w=500', 'https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?w=800', 4, true),
('cat-55555555-5555-5555-5555-555555555555', 'Computer & Laptop', 'computer-laptop-services', 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=800', 5, true),
('cat-66666666-6666-6666-6666-666666666666', 'TV & Entertainment', 'tv-entertainment-services', 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=500', 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=800', 6, true)
ON CONFLICT (slug) DO NOTHING;

-- 4. Service Items with Pricing & Payout Rates
INSERT INTO service_items (id, category_id, name, slug, price, booking_charge, advance_prepayment_pct, technician_payout_amount, duration_minutes, warranty_text, description, image_url, is_popular, is_active) VALUES 
('srv-11111111-1111-1111-1111-111111111111', 'cat-11111111-1111-1111-1111-111111111111', 'Fan & Lighting Services', 'fan-lighting-services', 299.00, 49.00, 30, 239.00, 45, '30-Day Service Warranty', 'Fan installation, LED light fitting & bulb repair by certified electrician', 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500', true, true),
('srv-11111111-2222-2222-2222-222222222222', 'cat-11111111-1111-1111-1111-111111111111', 'Switchboard & Wiring', 'switchboard-wiring', 399.00, 49.00, 30, 319.00, 60, '30-Day Service Warranty', 'Switchboard repair, MCB replacement & short circuit troubleshooting', 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500', true, true),
('srv-22222222-1111-1111-1111-111111111111', 'cat-22222222-2222-2222-2222-222222222222', 'Split AC Deep Cleaning & Servicing', 'split-ac-cleaning', 499.00, 49.00, 30, 399.00, 60, '30-Day Service Warranty', 'Foam jet deep cleaning, filter wash, and cooling check for split AC', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500', true, true),
('srv-22222222-2222-2222-2222-222222222222', 'cat-22222222-2222-2222-2222-222222222222', 'AC Gas Charging & Inspection', 'ac-gas-charging', 1499.00, 95.00, 30, 1199.00, 90, '60-Day Gas Leakage Warranty', 'Full refrigerant gas refill (R32/R410) with pressure testing', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500', false, true),
('srv-33333333-1111-1111-1111-111111111111', 'cat-33333333-3333-3333-3333-333333333333', 'Single & Double Door Refrigerator Repair', 'refrigerator-repair', 399.00, 49.00, 30, 319.00, 60, '30-Day Service Warranty', 'Thermostat, compressor relay, gasket replacement & cooling repair', 'https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=500', true, true),
('srv-44444444-1111-1111-1111-111111111111', 'cat-44444444-4444-4444-4444-444444444444', 'Automatic Washing Machine Servicing', 'washing-machine-servicing', 399.00, 49.00, 30, 319.00, 60, '30-Day Service Warranty', 'Drum descaling, motor check & noise diagnosis for front/top load', 'https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?w=500', true, true),
('srv-55555555-1111-1111-1111-111111111111', 'cat-55555555-5555-5555-5555-555555555555', 'Laptop Diagnosis & Chip-level Repair', 'laptop-repair', 499.00, 49.00, 30, 399.00, 60, '30-Day Hardware Warranty', 'Screen replacement, keyboard fix, RAM/SSD upgrade & motherboard repair', 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', true, true),
('srv-66666666-1111-1111-1111-111111111111', 'cat-66666666-6666-6666-6666-666666666666', 'Smart TV Wall Mount Installation', 'tv-wall-mounting', 349.00, 49.00, 30, 279.00, 45, '30-Day Fitting Warranty', 'Heavy duty wall bracket installation & cable management for LED/OLED TV', 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=500', true, true)
ON CONFLICT (slug) DO NOTHING;

-- 5. Service Skills
INSERT INTO service_skills (id, category_id, service_item_id, name, slug, description, display_order, is_active) VALUES 
('skl-11111111-1111-1111-1111-111111111111', 'cat-11111111-1111-1111-1111-111111111111', 'srv-11111111-1111-1111-1111-111111111111', 'Basic Electrician', 'electrical-services-basic-electrician', 'Certified for wiring, fan & light fixture repairs', 1, true),
('skl-22222222-1111-1111-1111-111111111111', 'cat-22222222-2222-2222-2222-222222222222', 'srv-22222222-1111-1111-1111-111111111111', 'AC Deep Cleaning', 'ac-services-ac-deep-cleaning', 'Expert in jet pump foam servicing for split & window AC', 1, true),
('skl-22222222-2222-2222-2222-222222222222', 'cat-22222222-2222-2222-2222-222222222222', 'srv-22222222-2222-2222-2222-222222222222', 'AC Gas Charging', 'ac-services-ac-gas-charging', 'Certified for gas leak inspection and vacuum refill', 2, true),
('skl-33333333-1111-1111-1111-111111111111', 'cat-33333333-3333-3333-3333-333333333333', 'srv-33333333-1111-1111-1111-111111111111', 'Refrigerator Repair', 'refrigerator-services-refrigerator-repair', 'Expert in compressor relay, gas charging & cooling repair', 1, true)
ON CONFLICT (slug) DO NOTHING;

-- 6. Technician Profiles, Wallets, and Verification Documents
INSERT INTO technician_profiles (id, user_id, technician_code, primary_category_id, skills_list, is_online, current_location, location_updated_at, kyc_status, rating, total_ratings_count, total_jobs_completed, upi_id, is_upi_verified) VALUES 
('tp111111-1111-1111-1111-111111111111', 't1111111-1111-1111-1111-111111111111', 'BT-TECH-000001', 'cat-22222222-2222-2222-2222-222222222222', ARRAY['AC Deep Cleaning', 'AC Gas Charging'], true, ST_SetSRID(ST_MakePoint(77.6400, 12.9750), 4326), NOW(), 'VERIFIED', 4.9, 42, 58, 'rajesh.kumar@okicici', true),
('tp222222-2222-2222-2222-222222222222', 't2222222-2222-2222-2222-222222222222', 'BT-TECH-000002', 'cat-11111111-1111-1111-1111-111111111111', ARRAY['Basic Electrician', 'Switchboard Repair'], true, ST_SetSRID(ST_MakePoint(77.6350, 12.9120), 4326), NOW(), 'VERIFIED', 4.8, 28, 35, 'amit.singh@upi', true)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO technician_wallets (id, technician_id, available_balance, total_withdrawn) VALUES 
('tw111111-1111-1111-1111-111111111111', 'tp111111-1111-1111-1111-111111111111', 1250.00, 4500.00),
('tw222222-2222-2222-2222-222222222222', 'tp222222-2222-2222-2222-222222222222', 850.00, 2400.00)
ON CONFLICT (technician_id) DO NOTHING;

INSERT INTO technician_skills (id, technician_id, skill_id, experience_years, verification_status, is_enabled) VALUES 
('ts111111-1111-1111-1111-111111111111', 'tp111111-1111-1111-1111-111111111111', 'skl-22222222-1111-1111-1111-111111111111', 5, 'VERIFIED', true),
('ts222222-2222-2222-2222-222222222222', 'tp222222-2222-2222-2222-222222222222', 'skl-11111111-1111-1111-1111-111111111111', 4, 'VERIFIED', true)
ON CONFLICT (technician_id, skill_id) DO NOTHING;

-- 7. Bookings, Payments & Reviews
INSERT INTO bookings (id, booking_code, customer_id, technician_id, address_id, service_id, status, schedule_date, schedule_slot, base_price, safety_fee, gst_amount, grand_total, platform_commission_amount, technician_payout_amount, start_service_otp, end_service_otp) VALUES 
('b1111111-1111-1111-1111-111111111111', 'BT-92841001', 'c1111111-1111-1111-1111-111111111111', 'tp111111-1111-1111-1111-111111111111', 'ca111111-1111-1111-1111-111111111111', 'srv-22222222-1111-1111-1111-111111111111', 'COMPLETED', CURRENT_DATE, '10:00 AM - 11:00 AM', 499.00, 49.00, 0.00, 548.00, 149.00, 399.00, '4821', '9102'),
('b2222222-2222-2222-2222-222222222222', 'BT-92841002', 'c2222222-2222-2222-2222-222222222222', 'tp222222-2222-2222-2222-222222222222', 'ca222222-2222-2222-2222-222222222222', 'srv-11111111-2222-2222-2222-222222222222', 'IN_PROGRESS', CURRENT_DATE, '02:00 PM - 03:00 PM', 399.00, 49.00, 0.00, 448.00, 129.00, 319.00, '7391', '1048')
ON CONFLICT (booking_code) DO NOTHING;

INSERT INTO payments (id, booking_id, razorpay_order_id, razorpay_payment_id, razorpay_signature, amount, currency, payment_method, status) VALUES 
('pay-11111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'order_N928102911', 'pay_P928102911', 'sig_918231', 548.00, 'INR', 'UPI', 'PAID'),
('pay-22222222-2222-2222-2222-222222222222', 'b2222222-2222-2222-2222-222222222222', 'order_N928102912', 'pay_P928102912', 'sig_918232', 448.00, 'INR', 'UPI', 'PAID')
ON CONFLICT (booking_id) DO NOTHING;

INSERT INTO reviews (id, booking_id, customer_id, technician_id, rating, review_text, is_hidden, is_flagged) VALUES 
('rev-11111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 'tp111111-1111-1111-1111-111111111111', 5, 'Rajesh arrived on time and did a thorough foam jet cleaning for my Split AC. Excellent service!', false, false)
ON CONFLICT (booking_id) DO NOTHING;

-- 8. Initial Default Dispatch Matching Algorithm Configuration
INSERT INTO dispatch_matching_configs (
    id, search_radius_km, strict_skill_matching, score_weight_distance, 
    score_weight_rating, score_weight_acceptance, score_weight_experience, 
    priority_policy, notification_timeout_seconds, max_dispatch_attempts, 
    auto_escalate_to_admin, updated_by_email, created_at, updated_at
) VALUES (
    gen_random_uuid(), 10.0, true, 0.40, 0.30, 0.15, 0.15, 'BALANCED', 30, 5, true, 'system@bookurtechnician.com', NOW(), NOW()
) ON CONFLICT DO NOTHING;

-- 9. Initial Sample Banners
INSERT INTO banners (
    id, title, subtitle, image_url, target_type, target_payload, banner_type, badge_text, cta_text, display_order, is_active
) VALUES 
(
    gen_random_uuid(), 'Express AC Deep Cleaning', 'Get instant 30-min technician arrival with 30-day warranty', 
    'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800', 'CATEGORY', 'ac-services', 'HERO', 'HOT OFFER', 'Book Now', 1, true
),
(
    gen_random_uuid(), 'Expert Electricians at ₹299', 'Switchboard, ceiling fan & wiring repairs near you', 
    'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800', 'CATEGORY', 'electrical-services', 'SPOTLIGHT', 'POPULAR', 'Explore', 2, true
) ON CONFLICT DO NOTHING;

-- ─── SECTION 4: OPERATIONAL & ANALYTICAL SQL QUERIES CHEATSHEET ────────────

-- Q1: Find Online & Verified Technicians within X km of Customer Address (PostGIS)
/*
SELECT 
    tp.id AS technician_id,
    u.full_name,
    u.phone,
    tp.rating,
    tp.total_jobs_completed,
    ST_Distance(
        tp.current_location, 
        ST_SetSRID(ST_MakePoint(77.5946, 12.9716), 4326)::geography
    ) / 1000.0 AS distance_km
FROM technician_profiles tp
JOIN users u ON tp.user_id = u.id
WHERE tp.is_online = true 
  AND tp.kyc_status = 'VERIFIED'
  AND ST_DWithin(
        tp.current_location, 
        ST_SetSRID(ST_MakePoint(77.5946, 12.9716), 4326)::geography, 
        10000
  )
ORDER BY distance_km ASC;
*/
