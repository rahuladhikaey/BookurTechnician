require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres.hgjvwddlwofzpdurvpzd:Rahul%402005%40%23@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function main() {
  console.log('📂 [Supabase Storage] Registering local images & banner files into Storage...');
  const client = await pool.connect();
  try {
    const assetsDir = path.join(__dirname, '../../../apps/customer_app_flutter/assets/images');
    const files = fs.readdirSync(assetsDir).filter(f => f.endsWith('.png') || f.endsWith('.jpg'));

    for (const file of files) {
      const filePath = path.join(assetsDir, file);
      const stats = fs.statSync(filePath);
      const isBanner = file.includes('banner');
      const bucketId = isBanner ? 'service-banners' : 'app-assets';
      const objId = uuidv4();

      await client.query(`
        INSERT INTO storage.objects (
          id, bucket_id, name, metadata, user_metadata, created_at, updated_at
        )
        VALUES (
          $1::uuid, $2::text, $3::text, 
          jsonb_build_object('size', $4::bigint, 'mimetype', 'image/png', 'cacheControl', 'max-age=3600'),
          jsonb_build_object('originalName', $3::text),
          NOW(), NOW()
        )
        ON CONFLICT (bucket_id, name) DO NOTHING;
      `, [objId, bucketId, file, stats.size]);

      console.log(`   ✓ Registered in [${bucketId}]: ${file} (${(stats.size / 1024).toFixed(1)} KB)`);
    }

    console.log('\n🎉 [Success] All files and buckets are successfully registered in Supabase Storage!');
  } catch (err) {
    console.error('❌ Error registering files:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

main();
