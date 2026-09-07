require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function run() {
  try {
    const cols = await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'technician_profiles'");
    console.log('Columns in technician_profiles:', cols.rows.map(r => r.column_name));

    const rows = await pool.query('SELECT * FROM technician_profiles');
    console.log('Rows in technician_profiles:', JSON.stringify(rows.rows, null, 2));

    const docs = await pool.query('SELECT * FROM technician_kyc_documents');
    console.log('Rows in technician_kyc_documents:', JSON.stringify(docs.rows, null, 2));
  } catch (e) {
    console.error('Error:', e);
  } finally {
    await pool.end();
  }
}

run();
