require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres.hgjvwddlwofzpdurvpzd:Rahul%402005%40%23@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';

const pool = new Pool({
  connectionString: DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function main() {
  const client = await pool.connect();
  try {
    console.log('🔍 [Inspect] Reading current tables from Supabase...');
    const res = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `);

    console.log(`📋 Found ${res.rows.length} existing tables:`);
    res.rows.forEach((r, idx) => console.log(`   ${idx + 1}. ${r.table_name}`));

    console.log('\n🚀 [Schema Sync] Applying full master schema from supabase_schema.sql...');
    const schemaSql = fs.readFileSync(path.join(__dirname, '../../../supabase_schema.sql'), 'utf-8');
    await client.query(schemaSql);

    const afterRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `);

    console.log(`\n✅ ALL ${afterRes.rows.length} TABLES ARE NOW CREATED AND VERIFIED IN SUPABASE:`);
    afterRes.rows.forEach((r, idx) => console.log(`   ${idx + 1}. ${r.table_name}`));

  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

main();
