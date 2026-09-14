-- ============================================================================
-- V3__create_dispatch_attempts_and_service_taxonomy.sql
-- Real-time Dispatch System, Dispatch Attempts & Service Taxonomy
-- ============================================================================

-- 1. Table for tracking sequential dispatch attempts and response metrics
CREATE TABLE IF NOT EXISTS dispatch_attempts (
    id VARCHAR(64) PRIMARY KEY,
    booking_id VARCHAR(64) NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    technician_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    distance_km NUMERIC(8, 2) NOT NULL,
    attempt_number INT NOT NULL DEFAULT 1,
    status VARCHAR(30) NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'TIMEOUT', 'EXPIRED')),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    CONSTRAINT uq_booking_technician_attempt UNIQUE(booking_id, technician_id, attempt_number)
);

CREATE INDEX IF NOT EXISTS idx_dispatch_attempts_booking ON dispatch_attempts(booking_id, status);
CREATE INDEX IF NOT EXISTS idx_dispatch_attempts_technician ON dispatch_attempts(technician_id, status);
CREATE INDEX IF NOT EXISTS idx_dispatch_attempts_created ON dispatch_attempts(sent_at DESC);

-- 2. Real-time technician location history tracking (for live map tracking & audits)
CREATE TABLE IF NOT EXISTS technician_locations (
    id VARCHAR(64) PRIMARY KEY,
    technician_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    booking_id VARCHAR(64) REFERENCES bookings(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location geography(Point, 4326),
    accuracy_meters DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    speed_mps DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_technician_locations_spatial ON technician_locations USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_technician_locations_tech_time ON technician_locations(technician_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_technician_locations_booking ON technician_locations(booking_id) WHERE booking_id IS NOT NULL;

-- 3. Seed / Ensure Canonical Service Categories
INSERT INTO service_categories (id, name, description, icon_url, active)
VALUES 
    ('cat_ac', 'AC Service', 'Professional Air Conditioner installation, servicing and deep chemical cleaning', 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=200', true),
    ('cat_laptop', 'Laptop Service', 'Chip-level repairs, screen replacements, keyboard repairs and diagnostics', 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=200', true),
    ('cat_fan', 'Fan Service', 'Ceiling and exhaust fan installation, rewinding, and maintenance', 'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=200', true),
    ('cat_refrigerator', 'Refrigerator Service', 'Single and double door fridge gas charging, compressor repair and diagnostics', 'https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=200', true),
    ('cat_washing_machine', 'Washing Machine Service', 'Front load, top load and semi-automatic washing machine repair & service', 'https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?w=200', true),
    ('cat_light', 'Light Service', 'LED panel lights, chandelier, tube light installation and emergency lighting', 'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=200', true),
    ('cat_popular', 'Popular Services', 'High-demand residential and commercial electrical and appliance services', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=200', true)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    active = true;

-- 4. Seed Canonical Service Items with exact skill mappings
INSERT INTO services (id, category_id, name, description, base_price, estimated_duration_minutes, active)
VALUES
    -- AC Service
    ('srv_ac_installation', 'cat_ac', 'New AC Installation', 'Complete split or window AC mounting, copper piping, vacuuming & gas check', 1499.00, 90, true),
    ('srv_ac_cleaning', 'cat_ac', 'AC Cleaning', 'Deep jet pump foam cleaning, filter disinfection, cooling coil flush', 499.00, 45, true),
    
    -- Laptop Service
    ('srv_laptop_keyboard', 'cat_laptop', 'Keyboard Replacement', 'OEM keyboard replacement with key alignment and warranty', 899.00, 45, true),
    ('srv_laptop_screen', 'cat_laptop', 'Screen Replacement', 'Original FHD/IPS screen panel replacement with dead pixel check', 2499.00, 60, true),
    ('srv_laptop_repair', 'cat_laptop', 'Laptop Repair & Service', 'Full hardware diagnosis, motherboard repair, thermal paste repasting', 599.00, 60, true),
    
    -- Fan Service
    ('srv_fan_installation', 'cat_fan', 'New Fan Installation', 'Safe ceiling fan mounting, downrod fitting, capacitor balancing & regulator setup', 199.00, 30, true),
    ('srv_fan_cleaning', 'cat_fan', 'Fan Service & Cleaning', 'Deep cleaning, bearing lubrication, noise diagnosis and capacitor replacement', 149.00, 30, true),
    
    -- Refrigerator Service
    ('srv_fridge_repair', 'cat_refrigerator', 'Refrigerator Repair', 'Thermostat, relay, cooling coil and compressor repair with genuine parts', 499.00, 60, true),
    ('srv_fridge_service', 'cat_refrigerator', 'Refrigerator Service', 'Deep coil cleaning, defrost check, condenser flush & gas top-up', 399.00, 45, true),
    
    -- Washing Machine Service
    ('srv_wm_repair', 'cat_washing_machine', 'Washing Machine Repair', 'Drum error, drain motor, inlet valve and PCB board troubleshooting', 499.00, 60, true),
    ('srv_wm_service', 'cat_washing_machine', 'Washing Machine Service', 'Descaling, drum deep sterilization, filter flush and vibration check', 399.00, 45, true),
    
    -- Light Service
    ('srv_light_installation', 'cat_light', 'Light Installation', 'Wall sconce, chandelier, recessed spotlight and concealed wiring light fitment', 149.00, 30, true),
    ('srv_light_repair', 'cat_light', 'Light Repair', 'Short circuit, flickering diagnosis, ballast/driver replacement', 129.00, 30, true),
    ('srv_light_led_tube', 'cat_light', 'LED/Tube Light Service', 'Batten fitting, LED tube replacement, bracket mounting', 99.00, 20, true),
    
    -- Popular Service
    ('srv_home_wiring', 'cat_popular', 'Full Home Wiring', 'Complete house rewiring, MCB distribution board setup, earthing & load testing', 4999.00, 240, true)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    base_price = EXCLUDED.base_price,
    category_id = EXCLUDED.category_id,
    active = true;
