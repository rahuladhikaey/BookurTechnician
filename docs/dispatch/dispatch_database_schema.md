# BookurTechnician — Dispatch Database Schema & Indexes

All tables and spatial indexes are defined idempotently in `backend/node-core-service/src/config/postgres.js`.

## 1. `technician_availability`
Stores working hours per day of week and temporary unavailability windows for both instant and scheduled booking eligibility.
- `id` `VARCHAR(64) PRIMARY KEY`
- `technician_id` `VARCHAR(64) NOT NULL`
- `day_of_week` `SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6)`
- `start_time` `VARCHAR(10) NOT NULL DEFAULT '08:00'`
- `end_time` `VARCHAR(10) NOT NULL DEFAULT '21:00'`
- `is_available` `BOOLEAN DEFAULT true`
- `unavailable_from` `TIMESTAMP WITH TIME ZONE`
- `unavailable_until` `TIMESTAMP WITH TIME ZONE`
- `max_concurrent_jobs` `INT DEFAULT 1`
- `updated_at` `TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Unique Constraint:** `uq_tech_availability_day UNIQUE(technician_id, day_of_week)`
- **Index:** `idx_tech_availability_tech(technician_id, day_of_week, is_available)`

## 2. `technician_service_skills`
Maps technicians to verified services and categories.
- `id` `VARCHAR(64) PRIMARY KEY`
- `technician_id` `VARCHAR(64) NOT NULL`
- `service_id` `VARCHAR(64) NOT NULL`
- `category_id` `VARCHAR(64)`
- `proficiency_level` `VARCHAR(30) DEFAULT 'EXPERT'`
- `is_verified` `BOOLEAN DEFAULT true`
- `active` `BOOLEAN DEFAULT true`
- `created_at` `TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Unique Constraint:** `uq_tech_service_skill UNIQUE(technician_id, service_id)`
- **Indexes:** `idx_tech_service_skills_lookup(service_id, active, is_verified)`, `idx_tech_service_skills_tech(technician_id, active)`

## 3. `dispatch_sessions`
Tracks the lifecycle of automatic dispatch for each booking.
- `id` `VARCHAR(64) PRIMARY KEY`
- `booking_id` `VARCHAR(64) UNIQUE NOT NULL`
- `booking_mode` `VARCHAR(20) NOT NULL DEFAULT 'INSTANT'` (`INSTANT` | `SCHEDULED`)
- `status` `VARCHAR(40) NOT NULL DEFAULT 'SEARCHING'` (`SEARCHING` | `OFFERED` | `ASSIGNED` | `FAILED_NO_TECHNICIAN` | `CANCELLED`)
- `current_radius_km` `DOUBLE PRECISION NOT NULL DEFAULT 3.0`
- `attempt_number` `INT NOT NULL DEFAULT 0`
- `max_attempts` `INT NOT NULL DEFAULT 12`
- `offer_timeout_seconds` `INT NOT NULL DEFAULT 20`
- `active_offer_id` `VARCHAR(64)`
- `assigned_technician_id` `VARCHAR(64)`
- `scheduled_dispatch_at` `TIMESTAMP WITH TIME ZONE`
- `failure_reason` `TEXT`
- `config_snapshot` `JSONB DEFAULT '{}'::jsonb`
- `created_at`, `updated_at` `TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Indexes:** `idx_dispatch_sessions_status(status, updated_at DESC)`, `idx_dispatch_sessions_booking(booking_id)`

## 4. `dispatch_offers`
Stores each sequential booking offer sent to an eligible ranked technician.
- `id` `VARCHAR(64) PRIMARY KEY`
- `session_id` `VARCHAR(64) NOT NULL REFERENCES dispatch_sessions(id) ON DELETE CASCADE`
- `booking_id` `VARCHAR(64) NOT NULL`
- `technician_id` `VARCHAR(64) NOT NULL`
- `status` `VARCHAR(30) NOT NULL DEFAULT 'PENDING'` (`PENDING` | `SENT` | `ACCEPTED` | `REJECTED` | `EXPIRED` | `CANCELLED`)
- `attempt_number` `INT NOT NULL DEFAULT 1`
- `radius_km`, `distance_km` `DOUBLE PRECISION`
- `eta_minutes` `INT`, `eta_source` `VARCHAR(30)`
- `expected_earning`, `total_amount` `NUMERIC(10, 2)`
- `service_id`, `service_name`, `approximate_area`, `appointment_time`
- `ranking_score` `NUMERIC(6, 4)`
- `ranking_reasons` `JSONB`
- `sent_at`, `expires_at`, `responded_at` `TIMESTAMP WITH TIME ZONE`
- `rejection_reason` `TEXT`
- `fcm_message_id` `VARCHAR(128)`, `fcm_delivery_status` `VARCHAR(50)`
- **Indexes:** `idx_dispatch_offers_tech_status(technician_id, status, expires_at)`, `idx_dispatch_offers_booking_status(booking_id, status)`, `idx_dispatch_offers_session(session_id, attempt_number)`

## 5. `technician_location_updates`
Persistent location telemetry log.
- `id` `VARCHAR(64) PRIMARY KEY`
- `technician_id` `VARCHAR(64) NOT NULL`
- `booking_id` `VARCHAR(64)`
- `latitude`, `longitude`, `speed`, `heading` `DOUBLE PRECISION`
- `recorded_at` `TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Indexes:** `idx_tech_location_updates_tech(technician_id, recorded_at DESC)`, `idx_tech_location_updates_booking(booking_id, recorded_at DESC)`

## 6. `dispatch_audit_logs`
Immutable audit trail of every dispatch start, offer sent, accept, reject, timeout, radius expansion, offline invalidation, and admin manual intervention.
- `id` `VARCHAR(64) PRIMARY KEY`
- `booking_id`, `session_id`, `offer_id`, `technician_id`, `actor_id` `VARCHAR(64)`
- `actor_role` `VARCHAR(30)`
- `event_type` `VARCHAR(60) NOT NULL`
- `details` `JSONB`
- `created_at` `TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Indexes:** `idx_dispatch_audit_booking(booking_id, created_at ASC)`, `idx_dispatch_audit_tech(technician_id, created_at DESC)`

