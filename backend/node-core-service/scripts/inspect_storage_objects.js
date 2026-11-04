require('dotenv').config();
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || '';

const pool = new Pool({
  connectionString: DATABASE_URL.replace(/[?&]sslmode=[^&]+/, ''),
  ssl: { rejectUnauthorized: false },
});

async function main() {
  const client = await pool.connect();
  try {
    const res = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_schema = 'storage' AND table_name = 'objects';
    `);
    console.log('Columns in storage.objects:');
    res.rows.forEach(r => console.log(` - ${r.column_name} (${r.data_type})`));
  } catch (e) {
    console.error(e.message);
  } finally {
    client.release();
    await pool.end();
  }
}
main();
