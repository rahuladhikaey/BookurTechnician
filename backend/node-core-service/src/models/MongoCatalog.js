const mongoose = require('mongoose');

const ServiceItemSchema = new mongoose.Schema({
  id: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String },
  basePrice: { type: Number, required: true },
  estimatedDurationMins: { type: Number, default: 45 },
  imageUrl: { type: String },
  isActive: { type: Boolean, default: true },
  taxRatePercent: { type: Number, default: 18 },
});

const CatalogCategorySchema = new mongoose.Schema(
  {
    categoryId: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    icon: { type: String },
    bannerUrl: { type: String },
    displayOrder: { type: Number, default: 0 },
    services: [ServiceItemSchema],
  },
  { timestamps: true }
);

module.exports = mongoose.model('CatalogCategory', CatalogCategorySchema);
