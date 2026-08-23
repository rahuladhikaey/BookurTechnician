-- V11: Enable RLS and public read-only policy on PostGIS spatial_ref_sys table to resolve Supabase security advisory

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'spatial_ref_sys') THEN
        ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Public read spatial_ref_sys" ON public.spatial_ref_sys;
        CREATE POLICY "Public read spatial_ref_sys"
        ON public.spatial_ref_sys
        FOR SELECT
        TO anon, authenticated, service_role
        USING (true);
    END IF;
END $$;
