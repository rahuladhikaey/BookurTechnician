const mongoose = require('mongoose');

const PayoutTransactionSchema = new mongoose.Schema(
  {
    payoutCode: {
      type: String,
      required: true,
      unique: true,
      index: true,
      default: () => `PAY-${Date.now().toString(36).toUpperCase()}-${Math.floor(1000 + Math.random() * 9000)}`,
    },
    technicianId: {
      type: String,
      required: true,
      index: true,
    },
    technicianName: {
      type: String,
      default: 'Partner Technician',
    },
    technicianPhone: {
      type: String,
    },
    amount: {
      type: Number,
      required: true,
      min: [1, 'Amount must be at least ₹1'],
    },
    paymentMethod: {
      type: String,
      enum: ['UPI', 'IMPS', 'NEFT', 'BANK_TRANSFER'],
      default: 'UPI',
    },
    utrReference: {
      type: String,
      required: [true, 'Bank UTR / Transaction Reference is strictly mandatory for reconciliation'],
      unique: true,
      trim: true,
      index: true,
    },
    destinationUpi: {
      type: String,
    },
    bankAccountDetails: {
      accountNumber: String,
      ifscCode: String,
      bankName: String,
      accountHolderName: String,
    },
    status: {
      type: String,
      enum: ['PENDING', 'PROCESSED', 'FAILED', 'REVERSED'],
      default: 'PROCESSED',
      index: true,
    },
    processedBy: {
      adminId: String,
      adminEmail: String,
      adminRole: String,
    },
    disbursedAt: {
      type: Date,
      default: Date.now,
    },
    notes: {
      type: String,
      default: 'Admin payout disbursement settled',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('PayoutTransaction', PayoutTransactionSchema);
