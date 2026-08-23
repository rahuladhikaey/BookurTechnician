-- ============================================================================
-- BOOKURTECHNICIAN MIGRATION V3: 10 KM SEQUENTIAL DISPATCH & PROPOSALS
-- ============================================================================

-- 1. Extend Booking Status Check Constraint
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE bookings ADD CONSTRAINT bookings_status_check CHECK (status IN (
    'REQUESTED', 'PAYMENT_PENDING', 'PAYMENT_VERIFIED', 'CONFIRMED', 
    'SEARCHING_TECHNICIAN', 'TECHNICIAN_NOTIFIED', 'ASSIGNED', 
    'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 
    'CANCELLED', 'NO_TECHNICIAN_AVAILABLE'
));

-- 2. Create Booking Proposals Table for Sequential Dispatch Engine
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
CREATE INDEX IF NOT EXISTS idx_booking_proposals_status ON booking_proposals(status, expires_at);
