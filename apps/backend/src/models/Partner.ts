import { Schema, model, Document } from 'mongoose';

export interface IPartner extends Document {
  name: string;
  phone: string;
  isOnline: boolean;
  socketId?: string;
  rating: number;
  location: {
    type: 'Point';
    coordinates: [number, number]; // [longitude, latitude]
  };
}

const PartnerSchema = new Schema<IPartner>({
  name: { type: String, required: true },
  phone: { type: String, required: true, unique: true },
  isOnline: { type: Boolean, default: false },
  socketId: { type: String },
  rating: { type: Number, default: 4.8 },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      required: true,
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true
    }
  }
});

// Create 2dsphere index for geolocation queries
PartnerSchema.index({ location: '2dsphere' });

export const Partner = model<IPartner>('Partner', PartnerSchema);
