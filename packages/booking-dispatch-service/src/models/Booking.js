const mongoose = require('mongoose');

const BookingSchema = new mongoose.Schema(
  {
    bookingCode: { type: String, required: true, unique: true, index: true },
    customerId: { type: String, required: true, index: true },
    customerEmail: { type: String, required: true },
    customerName: { type: String, default: 'Customer' },
    customerPhone: { type: String },
    customerAddress: { type: String, required: true },
    customerLocation: {
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
    technicianId: { type: String, index: true, default: null },
    serviceType: { type: String, required: true },
    scheduledSlot: { type: String, default: '1 Hour Window' },
    status: {
      type: String,
      enum: ['PENDING', 'ACCEPTED', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
      default: 'PENDING',
      index: true,
    },
    distanceKm: { type: Number, default: 0 },
    payoutAmount: { type: Number, default: 450 },
    
    // ─── DUAL-OTP LIFECYCLE ───
    startOtp: {
      code: { type: String, required: true },
      expiresAt: { type: Date, required: true }, // 3 Hours
      isVerified: { type: Boolean, default: false },
      verifiedAt: { type: Date },
    },
    endOtp: {
      code: { type: String },
      expiresAt: { type: Date }, // 24 Hours
      isVerified: { type: Boolean, default: false },
      verifiedAt: { type: Date },
    },
    failedAttempts: { type: Number, default: 0 },
  },
  { timestamps: true }
);

BookingSchema.index({ customerLocation: '2dsphere' });

module.exports = mongoose.model('Booking', BookingSchema);
