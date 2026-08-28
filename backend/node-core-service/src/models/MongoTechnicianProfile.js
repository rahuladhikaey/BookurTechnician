const mongoose = require('mongoose');

const MongoTechnicianProfileSchema = new mongoose.Schema(
  {
    technicianId: { type: String, required: true, unique: true },
    fullName: { type: String, required: true },
    phone: { type: String, required: true },
    category: { type: String, required: true }, // ELECTRICIAN, PLUMBER, CARPENTER, AC_REPAIR
    skills: [{ type: String }],
    experienceYears: { type: Number, default: 2 },
    kycStatus: {
      type: String,
      enum: ['PENDING', 'VERIFIED', 'REJECTED'],
      default: 'PENDING',
    },
    aadharNumber: { type: String },
    aadharCardImageUrl: { type: String },
    voterIdNumber: { type: String },
    voterCardImageUrl: { type: String },
    upiId: { type: String },
    upiNumber: { type: String },
    selfieImageUrl: { type: String },
    rating: { type: Number, default: 4.8 },
    totalJobsCompleted: { type: Number, default: 0 },
    acceptanceRate: { type: Number, default: 95.0 },
    isOnline: { type: Boolean, default: false },
    currentLocation: {
      type: { type: String, default: 'Point' },
      coordinates: [Number], // [longitude, latitude]
    },
    walletBalance: { type: Number, default: 0 },
    fcmToken: { type: String },
  },
  { timestamps: true }
);

MongoTechnicianProfileSchema.index({ currentLocation: '2dsphere' });

module.exports = mongoose.model('TechnicianProfile', MongoTechnicianProfileSchema);
