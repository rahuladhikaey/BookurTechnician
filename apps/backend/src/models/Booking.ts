import { Schema, model, Document } from 'mongoose';

export type BookingStatus = 'ASSIGNED' | 'EN_ROUTE' | 'ARRIVED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';

export interface IBooking extends Document {
  customerName: string;
  customerPhone: string;
  serviceTitle: string;
  price: number;
  status: BookingStatus;
  customerLocation: {
    type: 'Point';
    coordinates: [number, number]; // [longitude, latitude]
  };
  partnerLocation?: {
    type: 'Point';
    coordinates: [number, number]; // [longitude, latitude]
  };
  partnerId?: Schema.Types.ObjectId;
  startOtp: string; // Hashed or plaintext OTP
  endOtp: string;   // Hashed or plaintext OTP
  createdAt: Date;
}

const BookingSchema = new Schema<IBooking>({
  customerName: { type: String, required: true },
  customerPhone: { type: String, required: true },
  serviceTitle: { type: String, required: true },
  price: { type: Number, required: true },
  status: {
    type: String,
    enum: ['ASSIGNED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
    default: 'ASSIGNED'
  },
  customerLocation: {
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
  },
  partnerLocation: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number] // [longitude, latitude]
    }
  },
  partnerId: { type: Schema.Types.ObjectId, ref: 'Partner' },
  startOtp: { type: String, required: true },
  endOtp: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

BookingSchema.index({ customerLocation: '2dsphere' });
BookingSchema.index({ partnerLocation: '2dsphere' });

export const Booking = model<IBooking>('Booking', BookingSchema);
