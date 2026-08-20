const mongoose = require('mongoose');

const TechnicianSchema = new mongoose.Schema(
  {
    technicianCode: { type: String, required: true, unique: true, index: true },
    name: { type: String, required: true },
    phone: { type: String, required: true },
    email: { type: String },
    category: { type: String, required: true, index: true },
    rating: { type: Number, default: 4.8 },
    totalReviews: { type: Number, default: 45 },
    currentCoords: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
      },
    },
    isOnline: { type: Boolean, default: false, index: true },
    activeBookingId: { type: String, default: null },
    lastHeartbeat: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

TechnicianSchema.index({ currentCoords: '2dsphere' });

module.exports = mongoose.model('Technician', TechnicianSchema);
