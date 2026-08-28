require('dotenv').config();
const { Pool } = require('pg');
const mongoose = require('mongoose');
const MongoTechnicianProfile = require('../src/models/MongoTechnicianProfile');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres.hgjvwddlwofzpdurvpzd:Rahul%402005%40%23@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';
const MONGO_URI = process.env.MONGO_URI || 'mongodb+srv://server:Rahul%402005%40%23@prod-db.j8loxfl.mongodb.net/bookurtechnician_prod?retryWrites=true&w=majority&appName=prod-db';

const pool = new Pool({
  connectionString: DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function purgeAndResetForRealLaunch() {
  console.log('🧹 [Production Clean Slate] Purging all mock/fake data from Supabase and MongoDB...');
  const client = await pool.connect();

  try {
    // 1. Delete all fake bookings, transactions, kyc docs, addresses, and user profiles
    console.log('🗑️ [1/4] Deleting fake transactions, bookings, and customer addresses...');
    await client.query(`
      DELETE FROM wallet_transactions;
      DELETE FROM bookings;
      DELETE FROM customer_addresses;
      DELETE FROM technician_kyc_documents;
      DELETE FROM technician_profiles;
      DELETE FROM users WHERE role != 'SUPER_ADMIN';
    `);

    // 2. Ensure Super Admin account exists in users table
    console.log('👑 [2/4] Ensuring Super Admin account is ready...');
    await client.query(`
      INSERT INTO users (id, phone, email, full_name, role, is_active)
      VALUES (
        'admin-master-001',
        '+919999999999',
        'admin@bookurtechnician.com',
        'System Administrator',
        'SUPER_ADMIN',
        true
      )
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = 'SUPER_ADMIN';
    `);

    // 3. Clear MongoDB profiles if connected
    console.log('🍃 [3/4] Purging mock profiles from MongoDB Atlas...');
    try {
      if (mongoose.connection.readyState !== 1) {
        await mongoose.connect(MONGO_URI);
      }
      await MongoTechnicianProfile.deleteMany({});
      console.log('   ✓ MongoDB Technician profiles cleared for real incoming partner registrations.');
    } catch (mErr) {
      console.warn('   ⚠️ MongoDB connection skipped:', mErr.message);
    }

    // 4. Verify Clean Slate Counts
    console.log('📊 [4/4] Verifying Clean Slate database counts...');
    const usersCount = await client.query('SELECT count(*) FROM users;');
    const bookingsCount = await client.query('SELECT count(*) FROM bookings;');
    const techsCount = await client.query('SELECT count(*) FROM technician_profiles;');
    const srvCount = await client.query('SELECT count(*) FROM services;');
    const catCount = await client.query('SELECT count(*) FROM service_categories;');
    const mediaCount = await client.query('SELECT count(*) FROM uploaded_media;');

    console.log('\n=======================================================');
    console.log('🎉 [CLEAN PRODUCTION LAUNCH STATE READY]');
    console.log(`✓ Real Service Categories: ${catCount.rows[0].count}`);
    console.log(`✓ Real Master Services: ${srvCount.rows[0].count}`);
    console.log(`✓ Real Uploaded Banners & Media: ${mediaCount.rows[0].count}`);
    console.log(`✓ Real Customer / Tech Bookings: ${bookingsCount.rows[0].count} (Clean Slate 0)`);
    console.log(`✓ Active Technician Profiles: ${techsCount.rows[0].count} (Clean Slate 0)`);
    console.log(`✓ Super Admin Users: ${usersCount.rows[0].count} (Super Admin Active)`);
    console.log('=======================================================');
    console.log('Ready for real customer downloads, technician onboarding & live dispatches!');

  } catch (err) {
    console.error('❌ Purge Error:', err.message);
  } finally {
    client.release();
    await pool.end();
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  }
}

purgeAndResetForRealLaunch();
