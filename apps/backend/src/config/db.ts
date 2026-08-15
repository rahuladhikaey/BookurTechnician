import mongoose from 'mongoose';

export const connectDB = async (): Promise<void> => {
  try {
    const mongoUri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/hyperlocal';
    await mongoose.connect(mongoUri);
    console.log('MongoDB Connected Successfully to:', mongoUri);
  } catch (error) {
    console.error('MongoDB Connection Error:', error);
    process.exit(1);
  }
};
