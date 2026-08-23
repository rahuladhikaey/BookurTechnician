-- ============================================================================
-- BOOKURTECHNICIAN PRODUCTION DATABASE SCHEMA (POSTGRESQL)
-- Flyway Migration: V2__add_banner_types_and_review_indexes.sql
-- Add Banner Types, CTA, and Review Moderation Flags
-- ============================================================================

-- ─── 1. EXTEND BANNERS TABLE ───────────────────────────────────────────────────
ALTER TABLE banners ADD COLUMN IF NOT EXISTS banner_type VARCHAR(30) DEFAULT 'HERO' CHECK (banner_type IN ('HERO', 'SPOTLIGHT', 'RUNNING'));
ALTER TABLE banners ADD COLUMN IF NOT EXISTS badge_text VARCHAR(50);
ALTER TABLE banners ADD COLUMN IF NOT EXISTS cta_text VARCHAR(50) DEFAULT 'Book Now';
ALTER TABLE banners ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES service_categories(id) ON DELETE SET NULL;
ALTER TABLE banners ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES service_items(id) ON DELETE SET NULL;
ALTER TABLE banners ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_banners_type_active ON banners(banner_type, is_active, display_order);

-- ─── 2. EXTEND REVIEWS TABLE ──────────────────────────────────────────────────
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS is_flagged BOOLEAN DEFAULT false;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_reviews_technician_rating ON reviews(technician_id, rating);
CREATE INDEX IF NOT EXISTS idx_reviews_booking ON reviews(booking_id);
