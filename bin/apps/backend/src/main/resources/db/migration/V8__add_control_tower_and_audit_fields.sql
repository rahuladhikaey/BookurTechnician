-- V8: Add Control Tower Dispatch Override and Emergency OTP Bypass Fields

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS is_force_assigned BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS force_assigned_by VARCHAR(100),
ADD COLUMN IF NOT EXISTS force_assigned_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS start_otp_bypassed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS end_otp_bypassed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS otp_bypassed_by VARCHAR(100),
ADD COLUMN IF NOT EXISTS otp_bypassed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS otp_bypass_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_bookings_is_force_assigned ON bookings(is_force_assigned);
