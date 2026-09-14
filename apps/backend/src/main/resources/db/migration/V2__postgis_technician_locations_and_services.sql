-- ============================================================================
-- V2__postgis_technician_locations_and_services.sql
-- BookurTechnician PostGIS Spatial Engine & Technician Service Mapping
-- ============================================================================

-- 1. Ensure PostGIS spatial extension is enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add spatial location geography point and tracking fields to technician_profiles
ALTER TABLE technician_profiles 
    ADD COLUMN IF NOT EXISTS location geography(Point, 4326),
    ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS availability_status VARCHAR(30) DEFAULT 'AVAILABLE';

-- 3. High-performance GIST Spatial Index for ST_DWithin and ST_Distance radius queries
CREATE INDEX IF NOT EXISTS idx_technician_profiles_location 
    ON technician_profiles USING GIST(location);

-- 4. Composite index for filtering active, verified, online technicians with fresh GPS
CREATE INDEX IF NOT EXISTS idx_technician_profiles_status_perf 
    ON technician_profiles(is_online, availability_status, kyc_status, last_location_update);

-- 5. Backfill location geography column from current_latitude and current_longitude if present
UPDATE technician_profiles
SET location = ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)::geography,
    last_location_update = COALESCE(updated_at, NOW()),
    availability_status = CASE WHEN is_online = true THEN 'AVAILABLE' ELSE 'OFFLINE' END
WHERE current_latitude IS NOT NULL 
  AND current_longitude IS NOT NULL 
  AND location IS NULL
  AND current_latitude BETWEEN -90 AND 90
  AND current_longitude BETWEEN -180 AND 180;

-- 6. Normalized relationship table linking technicians with specific services they offer
CREATE TABLE IF NOT EXISTS technician_services (
    id VARCHAR(64) PRIMARY KEY,
    technician_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    service_id VARCHAR(64) NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    active BOOLEAN DEFAULT true,
    CONSTRAINT uq_technician_service UNIQUE(technician_id, service_id)
);

CREATE INDEX IF NOT EXISTS idx_tech_services_service ON technician_services(service_id, active);
CREATE INDEX IF NOT EXISTS idx_tech_services_technician ON technician_services(technician_id, active);
