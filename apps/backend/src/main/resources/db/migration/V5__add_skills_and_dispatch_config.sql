-- ============================================================================
-- BOOKURTECHNICIAN MIGRATION V5: SERVICE SKILLS, COMPATIBILITY & DISPATCH CONFIG
-- ============================================================================

-- 1. Service Skills
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
CREATE INDEX IF NOT EXISTS idx_service_skills_slug ON service_skills(slug);

-- 2. Skill Service Compatibilities (Many-to-Many Mapping)
CREATE TABLE IF NOT EXISTS skill_service_compatibilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    skill_id UUID NOT NULL REFERENCES service_skills(id) ON DELETE CASCADE,
    service_item_id UUID NOT NULL REFERENCES service_items(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_skill_service_comp UNIQUE(skill_id, service_item_id)
);

CREATE INDEX IF NOT EXISTS idx_skill_service_comp_skill ON skill_service_compatibilities(skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_service_comp_item ON skill_service_compatibilities(service_item_id);

-- 3. Technician Skills (Technician Onboarding & Verification)
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

CREATE INDEX IF NOT EXISTS idx_technician_skills_tech ON technician_skills(technician_id);
CREATE INDEX IF NOT EXISTS idx_technician_skills_skill ON technician_skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_technician_skills_status ON technician_skills(verification_status);

-- 4. Dispatch Matching Dynamic Configurations
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

-- Seed Initial Default Dispatch Configuration
INSERT INTO dispatch_matching_configs (
    id, search_radius_km, strict_skill_matching, score_weight_distance, 
    score_weight_rating, score_weight_acceptance, score_weight_experience, 
    priority_policy, notification_timeout_seconds, max_dispatch_attempts, 
    auto_escalate_to_admin, updated_by_email, created_at, updated_at
) VALUES (
    gen_random_uuid(), 10.0, true, 0.40, 0.30, 0.15, 0.15, 'BALANCED', 30, 5, true, 'system@bookurtechnician.com', NOW(), NOW()
) ON CONFLICT DO NOTHING;
