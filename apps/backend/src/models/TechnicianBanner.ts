import { Schema, model, Document } from 'mongoose';

export interface ITechnicianBanner extends Document {
  bannerId: string;
  imageUrl: string;
  title: string;
  subtitle: string;
  ctaText: string;
  targetType: 'ONLINE_TOGGLE' | 'JOBS' | 'PERFORMANCE' | 'EARNINGS' | 'CUSTOM';
  targetId?: string;
  displayOrder: number;
  isActive: boolean;
  startDate: Date;
  endDate: Date;
  createdAt: Date;
  updatedAt: Date;
}

const TechnicianBannerSchema = new Schema<ITechnicianBanner>(
  {
    bannerId: { type: String, required: true, unique: true },
    imageUrl: { type: String, required: true },
    title: { type: String, required: true },
    subtitle: { type: String, required: true },
    ctaText: { type: String, required: true },
    targetType: { 
      type: String, 
      enum: ['ONLINE_TOGGLE', 'JOBS', 'PERFORMANCE', 'EARNINGS', 'CUSTOM'], 
      default: 'JOBS' 
    },
    targetId: { type: String, default: '' },
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true }
  },
  { timestamps: true }
);

export const TechnicianBanner = model<ITechnicianBanner>('TechnicianBanner', TechnicianBannerSchema);
