-- V9: Add Dynamic Service Pricing, Booking Charge, Prepayment and Technician Payout Columns

ALTER TABLE service_items
ADD COLUMN IF NOT EXISTS booking_charge NUMERIC(10, 2) DEFAULT 49.00,
ADD COLUMN IF NOT EXISTS advance_prepayment_pct INT DEFAULT 30,
ADD COLUMN IF NOT EXISTS technician_payout_amount NUMERIC(10, 2);

-- Set default initial payout amounts for existing records based on price
UPDATE service_items 
SET booking_charge = 49.00 
WHERE booking_charge IS NULL;

UPDATE service_items 
SET advance_prepayment_pct = 30 
WHERE advance_prepayment_pct IS NULL;

UPDATE service_items 
SET technician_payout_amount = ROUND(price * 0.80, 2) 
WHERE technician_payout_amount IS NULL AND price IS NOT NULL;
