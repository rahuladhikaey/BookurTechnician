-- Flyway Migration V7: Add FCM Token column to Users table for push notifications
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500);

CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;
