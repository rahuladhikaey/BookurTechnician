import mongoose, { Document, Schema } from 'mongoose';

export interface ITechnicianProfile extends Document {
  technician_code: string; // e.g. BT-TECH-000001
  user_id: string;
  full_name: string;
  phone: string;
  email: string;
  profile_photo_url: string;
  join_date: Date;
  skills: string[];
  verification_status: 'APPROVED' | 'PENDING' | 'SUSPENDED';
  qr_verification_token: string;
  update_history: Array<{
    timestamp: Date;
    field: string;
    previousValue: string;
    newValue: string;
    reason: string;
  }>;
  createdAt: Date;
  updatedAt: Date;
}

const TechnicianProfileSchema = new Schema<ITechnicianProfile>(
  {
    technician_code: {
      type: String,
      required: true,
      unique: true,
      index: true,
      trim: true,
    },
    user_id: {
      type: String,
      required: true,
      index: true,
    },
    full_name: {
      type: String,
      required: true,
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      trim: true,
      default: '',
    },
    profile_photo_url: {
      type: String,
      required: true,
    },
    join_date: {
      type: Date,
      required: true,
      default: Date.now,
    },
    skills: {
      type: [String],
      default: ['AC Service', 'Electrical', 'Fan Service'],
    },
    verification_status: {
      type: String,
      enum: ['APPROVED', 'PENDING', 'SUSPENDED'],
      default: 'APPROVED',
      index: true,
    },
    qr_verification_token: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    update_history: [
      {
        timestamp: { type: Date, default: Date.now },
        field: { type: String, required: true },
        previousValue: { type: String, default: '' },
        newValue: { type: String, required: true },
        reason: { type: String, default: 'Selfie Update' },
      },
    ],
  },
  {
    timestamps: true,
  }
);

export const TechnicianProfile = mongoose.model<ITechnicianProfile>(
  'TechnicianProfile',
  TechnicianProfileSchema
);
