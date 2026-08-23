-- V11: Safely attempt RLS enablement on PostGIS spatial_ref_sys reference table

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'spatial_ref_sys') THEN
        BEGIN
            ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
            
            DROP POLICY IF EXISTS "Public read spatial_ref_sys" ON public.spatial_ref_sys;
            CREATE POLICY "Public read spatial_ref_sys"
            ON public.spatial_ref_sys
            FOR SELECT
            TO anon, authenticated, service_role
            USING (true);
        EXCEPTION WHEN OTHERS THEN
            -- Gracefully handle permission error if connection user is not table owner (e.g. extension owned by postgres/supabase_admin)
            RAISE NOTICE 'Skipped spatial_ref_sys RLS modification due to permission constraints: %', SQLERRM;
        END;
    END IF;
END $$;
