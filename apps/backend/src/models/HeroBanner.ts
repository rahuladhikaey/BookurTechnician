import { Schema, model, Document } from 'mongoose';

export interface IHeroBanner extends Document {
  title: string;
  subtitle: string;
  badgeText: string;
  ctaText: string;
  imageUrl: string;
  targetServiceId?: string;
  displayOrder: number;
  active: boolean;
  startDate: Date;
  endDate: Date;
  createdAt: Date;
  updatedAt: Date;
}

const HeroBannerSchema = new Schema<IHeroBanner>(
  {
    title: { type: String, required: true },
    subtitle: { type: String, required: true },
    badgeText: { type: String, required: true },
    ctaText: { type: String, required: true },
    imageUrl: { type: String, required: true },
    targetServiceId: { type: String, default: "" },
    displayOrder: { type: Number, default: 0 },
    active: { type: Boolean, default: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true }
  },
  { timestamps: true }
);

export const HeroBanner = model<IHeroBanner>('HeroBanner', HeroBannerSchema);
