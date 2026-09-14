const mongoose = require('mongoose');

const MongoActivityLogSchema = new mongoose.Schema(
  {
    eventType: { type: String, required: true },
    bookingId: { type: String },
    userId: { type: String },
    role: { type: String },
    details: { type: mongoose.Schema.Types.Mixed },
    ipAddress: { type: String },
  },
  { timestamps: true }
);

module.exports = mongoose.model('ActivityLog', MongoActivityLogSchema);
