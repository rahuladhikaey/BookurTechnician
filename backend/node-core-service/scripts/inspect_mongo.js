require('dotenv').config();
const mongoose = require('mongoose');

async function run() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB!');
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Collections:', collections.map(c => c.name));

    for (const col of collections) {
      const docs = await mongoose.connection.db.collection(col.name).find({}).limit(5).toArray();
      console.log(`\n--- Collection: ${col.name} (${docs.length} sample docs) ---`);
      console.log(JSON.stringify(docs, null, 2));
    }
  } catch (e) {
    console.error('Mongo Error:', e);
  } finally {
    await mongoose.disconnect();
  }
}

run();
