require('dotenv').config();
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres.hgjvwddlwofzpdurvpzd:Rahul%402005%40%23@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function createBuckets() {
  console.log('🪣 [Supabase Storage] Creating Storage Buckets in Supabase...');
  const client = await pool.connect();
  try {
    // 1. Create storage schema buckets
    await client.query(`
      INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
      VALUES 
        ('app-assets', 'app-assets', true, 52428800, ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml', 'audio/mpeg']),
        ('service-banners', 'service-banners', true, 52428800, ARRAY['image/png', 'image/jpeg', 'image/webp']),
        ('avatars', 'avatars', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp']),
        ('kyc-documents', 'kyc-documents', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
      ON CONFLICT (id) DO UPDATE SET
        public = EXCLUDED.public,
        file_size_limit = EXCLUDED.file_size_limit;
    `);

    // 2. Set public read access policies
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies WHERE policyname = 'Public Access for app-assets'
        ) THEN
          CREATE POLICY "Public Access for app-assets" ON storage.objects FOR SELECT USING (bucket_id IN ('app-assets', 'service-banners', 'avatars', 'kyc-documents'));
        END IF;
      END $$;
    `);

    const res = await client.query('SELECT id, name, public, created_at FROM storage.buckets ORDER BY name;');
    console.log(`\n✅ Successfully created ${res.rows.length} Supabase Storage Buckets:`);
    res.rows.forEach((b, idx) => {
      console.log(`   ${idx + 1}. 📁 Bucket: "${b.name}" (Public: ${b.public})`);
    });
  } catch (err) {
    console.error('❌ Storage creation error:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

createBuckets();
