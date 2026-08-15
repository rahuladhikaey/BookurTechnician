import { Schema, model, Document } from 'mongoose';

export interface ISpotlightBanner extends Document {
  title: string;
  subtitle: string;
  badgeText: string;
  ctaText: string;
  imageUrl: string;
  serviceId?: string;
  categoryId?: string;
  displayOrder: number;
  isActive: boolean;
  autoSlide: boolean;
  slideDuration: number;
  startDate: Date;
  endDate: Date;
  createdAt: Date;
  updatedAt: Date;
}

const SpotlightBannerSchema = new Schema<ISpotlightBanner>(
  {
    title: { type: String, required: true },
    subtitle: { type: String, required: true },
    badgeText: { type: String, required: true },
    ctaText: { type: String, required: true },
    imageUrl: { type: String, required: true },
    serviceId: { type: String },
    categoryId: { type: String },
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    autoSlide: { type: Boolean, default: true },
    slideDuration: { type: Number, default: 3000 },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true }
  },
  { timestamps: true }
);

export const SpotlightBanner = model<ISpotlightBanner>('SpotlightBanner', SpotlightBannerSchema);
