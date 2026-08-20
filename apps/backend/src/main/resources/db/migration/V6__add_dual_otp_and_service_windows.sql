-- ============================================================================
-- BOOKURTECHNICIAN MIGRATION V6: DUAL-OTP LIFECYCLE & 1-HOUR SERVICE WINDOWS
-- ============================================================================

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS start_otp_expires_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS end_service_otp VARCHAR(6),
    ADD COLUMN IF NOT EXISTS end_otp_expires_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS failed_otp_attempts INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_bookings_start_otp_expires ON bookings(start_otp_expires_at);
CREATE INDEX IF NOT EXISTS idx_bookings_end_otp_expires ON bookings(end_otp_expires_at);
