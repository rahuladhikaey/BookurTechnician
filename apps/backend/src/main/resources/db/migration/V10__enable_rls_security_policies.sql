-- V10: Enable Row Level Security (RLS) on application tables and PostGIS spatial_ref_sys table to resolve Supabase security advisory

DO $$
BEGIN
    -- 1. PostGIS Reference Table (Resolves Supabase RLS Advisory on public.spatial_ref_sys)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'spatial_ref_sys') THEN
        ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Public read spatial_ref_sys" ON public.spatial_ref_sys;
        CREATE POLICY "Public read spatial_ref_sys"
        ON public.spatial_ref_sys
        FOR SELECT
        TO anon, authenticated, service_role
        USING (true);
    END IF;

    -- 2. User & Identity Tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customer_profiles') THEN
        ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customer_addresses') THEN
        ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;
    END IF;

    -- 3. Catalog & Service Tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_categories') THEN
        ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_brands') THEN
        ALTER TABLE public.service_brands ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_brand_models') THEN
        ALTER TABLE public.service_brand_models ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_items') THEN
        ALTER TABLE public.service_items ENABLE ROW LEVEL SECURITY;
    END IF;

    -- 4. Technician & Verification Tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'technician_profiles') THEN
        ALTER TABLE public.technician_profiles ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'technician_documents') THEN
        ALTER TABLE public.technician_documents ENABLE ROW LEVEL SECURITY;
    END IF;

    -- 5. Financial & Wallet Tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'technician_wallets') THEN
        ALTER TABLE public.technician_wallets ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'wallet_ledger') THEN
        ALTER TABLE public.wallet_ledger ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'withdrawal_requests') THEN
        ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payments') THEN
        ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'refunds') THEN
        ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
    END IF;

    -- 6. Booking & Operations Tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bookings') THEN
        ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'booking_status_history') THEN
        ALTER TABLE public.booking_status_history ENABLE ROW LEVEL SECURITY;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reviews') THEN
        ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;
