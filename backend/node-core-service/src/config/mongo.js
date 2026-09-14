const dns = require('dns');
const mongoose = require('mongoose');

try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {}

let isConnected = false;

const connectMongo = async () => {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/bookurtechnician_core';
  try {
    mongoose.set('strictQuery', false);
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 6000,
    });
    isConnected = true;
    const isCloud = uri.includes('mongodb+srv://') || !uri.includes('localhost');
    console.log(`✅ [MongoDB] Connected successfully (${isCloud ? 'Cloud MongoDB Atlas' : 'Local MongoDB'} Unstructured Catalog & Profiles store)`);
  } catch (err) {
    console.warn('⚠️ [MongoDB] Connection warning (Offline/Mock fallback mode active):', err.message);
    isConnected = false;
  }
};

const isMongoHealthy = () => isConnected && mongoose.connection.readyState === 1;

module.exports = { connectMongo, isMongoHealthy };
