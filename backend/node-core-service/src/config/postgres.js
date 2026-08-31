const { Pool } = require('pg');

let pool = null;
let isPostgresConnected = false;

// In-memory fallback mock database if Postgres is not running locally during early dev
const inMemoryStore = {
  users: new Map(),
  bookings: new Map(),
  payments: new Map(),
  wallets: new Map(),
};

const initPostgres = async () => {
  try {
    const isCloudDb = !!process.env.DATABASE_URL || (process.env.PG_HOST && !process.env.PG_HOST.includes('localhost') && !process.env.PG_HOST.includes('127.0.0.1'));
    
    if (process.env.DATABASE_URL) {
      const cleanConnectionString = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]+/, '');
      pool = new Pool({
        connectionString: cleanConnectionString,
        ssl: isCloudDb ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 8000,
      });
    } else {
      pool = new Pool({
        host: process.env.PG_HOST || 'localhost',
        port: parseInt(process.env.PG_PORT || '5432', 10),
        database: process.env.PG_DATABASE || 'postgres',
        user: process.env.PG_USER || 'postgres',
        password: process.env.PG_PASSWORD || 'postgrespassword',
        ssl: isCloudDb ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 8000,
      });
    }

    const client = await pool.connect();
    const res = await client.query('SELECT NOW()');
    client.release();

    isPostgresConnected = true;
    const connectedTarget = process.env.DATABASE_URL ? 'Cloud PostgreSQL via DATABASE_URL' : `${process.env.PG_HOST || 'localhost'}:${process.env.PG_PORT || '5432'}`;
    console.log(`✅ [PostgreSQL] Connected successfully to ${connectedTarget} (ACID Transactions Engine)`);

    // Ensure core tables exist
    await createCoreTables();
  } catch (err) {
    console.warn('⚠️ [PostgreSQL] Connection warning (Offline/Mock fallback mode active):', err.message);
    isPostgresConnected = false;
  }
};

const createCoreTables = async () => {
  if (!isPostgresConnected) return;
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(64) PRIMARY KEY,
        phone VARCHAR(20) UNIQUE,
        email VARCHAR(255) UNIQUE,
        full_name VARCHAR(100),
        role VARCHAR(30) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        fcm_token TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS bookings (
        id VARCHAR(64) PRIMARY KEY,
        booking_code VARCHAR(30) UNIQUE,
        customer_id VARCHAR(64) NOT NULL,
        technician_id VARCHAR(64),
        service_id VARCHAR(64) NOT NULL,
        service_name VARCHAR(150),
        category VARCHAR(50),
        status VARCHAR(50) NOT NULL,
        address TEXT,
        latitude DOUBLE PRECISION,
        longitude DOUBLE PRECISION,
        total_amount NUMERIC(10, 2) DEFAULT 0,
        start_otp VARCHAR(6),
        end_otp VARCHAR(6),
        scheduled_time TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        booking_id VARCHAR(64),
        amount NUMERIC(10, 2) NOT NULL,
        type VARCHAR(20) NOT NULL,
        description TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS technician_profiles (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) UNIQUE NOT NULL,
        technician_code VARCHAR(30),
        full_name VARCHAR(100) NOT NULL,
        phone VARCHAR(20) NOT NULL,
        category VARCHAR(50) DEFAULT 'ELECTRICIAN',
        skills JSONB DEFAULT '[]'::jsonb,
        experience_years INT DEFAULT 2,
        kyc_status VARCHAR(30) DEFAULT 'PENDING',
        is_online BOOLEAN DEFAULT false,
        current_latitude DOUBLE PRECISION,
        current_longitude DOUBLE PRECISION,
        rating NUMERIC(3, 2) DEFAULT 4.85,
        total_ratings_count INT DEFAULT 0,
        total_jobs_completed INT DEFAULT 0,
        wallet_balance NUMERIC(10, 2) DEFAULT 0.00,
        upi_id VARCHAR(100),
        upi_number VARCHAR(20),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS technician_kyc_documents (
        id VARCHAR(64) PRIMARY KEY,
        technician_id VARCHAR(64) NOT NULL,
        document_type VARCHAR(50) NOT NULL,
        document_number VARCHAR(100),
        front_image_url TEXT,
        back_image_url TEXT,
        file_size_mb NUMERIC(5, 2),
        verification_status VARCHAR(30) DEFAULT 'PENDING',
        rejection_reason TEXT,
        verified_at TIMESTAMP WITH TIME ZONE,
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS uploaded_media (
        id VARCHAR(64) PRIMARY KEY,
        file_name VARCHAR(255) NOT NULL,
        file_url TEXT NOT NULL,
        storage_bucket VARCHAR(100) NOT NULL DEFAULT 'kyc-documents',
        mime_type VARCHAR(50),
        file_size_bytes BIGINT,
        entity_type VARCHAR(50) NOT NULL DEFAULT 'KYC_DOCUMENT',
        entity_id VARCHAR(64),
        is_public BOOLEAN DEFAULT true,
        uploaded_by VARCHAR(64),
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `);
    console.log('✅ [PostgreSQL] Core transactional & KYC schemas verified');
  } catch (err) {
    console.error('❌ [PostgreSQL] Failed to initialize tables:', err.message);
  }
};

const query = async (text, params) => {
  if (isPostgresConnected && pool) {
    return pool.query(text, params);
  }
  return { rows: [] };
};

const isPgHealthy = () => isPostgresConnected;

module.exports = { initPostgres, query, isPgHealthy, inMemoryStore };
