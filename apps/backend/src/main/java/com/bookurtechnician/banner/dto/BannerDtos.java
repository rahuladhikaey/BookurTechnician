package com.bookurtechnician.banner.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

public class BannerDtos {

    public static class BannerResponse {
        private UUID id;
        private String title;
        private String subtitle;
        private String imageUrl;
        private String bannerType;
        private String badgeText;
        private String ctaText;
        private String targetType;
        private String targetPayload;
        private UUID categoryId;
        private UUID serviceId;
        private Integer displayOrder;
        private boolean active;

        public BannerResponse() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private String title;
            private String subtitle;
            private String imageUrl;
            private String bannerType;
            private String badgeText;
            private String ctaText;
            private String targetType;
            private String targetPayload;
            private UUID categoryId;
            private UUID serviceId;
            private Integer displayOrder;
            private boolean active;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder title(String title) { this.title = title; return this; }
            public Builder subtitle(String subtitle) { this.subtitle = subtitle; return this; }
            public Builder imageUrl(String imageUrl) { this.imageUrl = imageUrl; return this; }
            public Builder bannerType(String bannerType) { this.bannerType = bannerType; return this; }
            public Builder badgeText(String badgeText) { this.badgeText = badgeText; return this; }
            public Builder ctaText(String ctaText) { this.ctaText = ctaText; return this; }
            public Builder targetType(String targetType) { this.targetType = targetType; return this; }
            public Builder targetPayload(String targetPayload) { this.targetPayload = targetPayload; return this; }
            public Builder categoryId(UUID categoryId) { this.categoryId = categoryId; return this; }
            public Builder serviceId(UUID serviceId) { this.serviceId = serviceId; return this; }
            public Builder displayOrder(Integer displayOrder) { this.displayOrder = displayOrder; return this; }
            public Builder active(boolean active) { this.active = active; return this; }

            public BannerResponse build() {
                BannerResponse res = new BannerResponse();
                res.id = this.id;
                res.title = this.title;
                res.subtitle = this.subtitle;
                res.imageUrl = this.imageUrl;
                res.bannerType = this.bannerType;
                res.badgeText = this.badgeText;
                res.ctaText = this.ctaText;
                res.targetType = this.targetType;
                res.targetPayload = this.targetPayload;
                res.categoryId = this.categoryId;
                res.serviceId = this.serviceId;
                res.displayOrder = this.displayOrder;
                res.active = this.active;
                return res;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public String getTitle() { return title; }
        public void setTitle(String title) { this.title = title; }
        public String getSubtitle() { return subtitle; }
        public void setSubtitle(String subtitle) { this.subtitle = subtitle; }
        public String getImageUrl() { return imageUrl; }
        public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
        public String getBannerType() { return bannerType; }
        public void setBannerType(String bannerType) { this.bannerType = bannerType; }
        public String getBadgeText() { return badgeText; }
        public void setBadgeText(String badgeText) { this.badgeText = badgeText; }
        public String getCtaText() { return ctaText; }
        public void setCtaText(String ctaText) { this.ctaText = ctaText; }
        public String getTargetType() { return targetType; }
        public void setTargetType(String targetType) { this.targetType = targetType; }
        public String getTargetPayload() { return targetPayload; }
        public void setTargetPayload(String targetPayload) { this.targetPayload = targetPayload; }
        public UUID getCategoryId() { return categoryId; }
        public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }
        public UUID getServiceId() { return serviceId; }
        public void setServiceId(UUID serviceId) { this.serviceId = serviceId; }
        public Integer getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(Integer displayOrder) { this.displayOrder = displayOrder; }
        public boolean isActive() { return active; }
        public void setActive(boolean active) { this.active = active; }
    }

    public static class CreateBannerRequest {
        @NotBlank(message = "Title is required")
        private String title;
        private String subtitle;
        @NotBlank(message = "Image URL is required")
        private String imageUrl;
        private String bannerType; // HERO, SPOTLIGHT, RUNNING
        private String badgeText;
        private String ctaText;
        private String targetType;
        private String targetPayload;
        private UUID categoryId;
        private UUID serviceId;
        private Integer displayOrder;
        private boolean active = true;

        public CreateBannerRequest() {}

        public String getTitle() { return title; }
        public void setTitle(String title) { this.title = title; }
        public String getSubtitle() { return subtitle; }
        public void setSubtitle(String subtitle) { this.subtitle = subtitle; }
        public String getImageUrl() { return imageUrl; }
        public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
        public String getBannerType() { return bannerType; }
        public void setBannerType(String bannerType) { this.bannerType = bannerType; }
        public String getBadgeText() { return badgeText; }
        public void setBadgeText(String badgeText) { this.badgeText = badgeText; }
        public String getCtaText() { return ctaText; }
        public void setCtaText(String ctaText) { this.ctaText = ctaText; }
        public String getTargetType() { return targetType; }
        public void setTargetType(String targetType) { this.targetType = targetType; }
        public String getTargetPayload() { return targetPayload; }
        public void setTargetPayload(String targetPayload) { this.targetPayload = targetPayload; }
        public UUID getCategoryId() { return categoryId; }
        public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }
        public UUID getServiceId() { return serviceId; }
        public void setServiceId(UUID serviceId) { this.serviceId = serviceId; }
        public Integer getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(Integer displayOrder) { this.displayOrder = displayOrder; }
        public boolean isActive() { return active; }
        public void setActive(boolean active) { this.active = active; }
    }

    public static class UpdateBannerRequest {
        private String title;
        private String subtitle;
        private String imageUrl;
        private String bannerType;
        private String badgeText;
        private String ctaText;
        private String targetType;
        private String targetPayload;
        private UUID categoryId;
        private UUID serviceId;
        private Integer displayOrder;
        private Boolean active;

        public UpdateBannerRequest() {}

        public String getTitle() { return title; }
        public void setTitle(String title) { this.title = title; }
        public String getSubtitle() { return subtitle; }
        public void setSubtitle(String subtitle) { this.subtitle = subtitle; }
        public String getImageUrl() { return imageUrl; }
        public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
        public String getBannerType() { return bannerType; }
        public void setBannerType(String bannerType) { this.bannerType = bannerType; }
        public String getBadgeText() { return badgeText; }
        public void setBadgeText(String badgeText) { this.badgeText = badgeText; }
        public String getCtaText() { return ctaText; }
        public void setCtaText(String ctaText) { this.ctaText = ctaText; }
        public String getTargetType() { return targetType; }
        public void setTargetType(String targetType) { this.targetType = targetType; }
        public String getTargetPayload() { return targetPayload; }
        public void setTargetPayload(String targetPayload) { this.targetPayload = targetPayload; }
        public UUID getCategoryId() { return categoryId; }
        public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }
        public UUID getServiceId() { return serviceId; }
        public void setServiceId(UUID serviceId) { this.serviceId = serviceId; }
        public Integer getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(Integer displayOrder) { this.displayOrder = displayOrder; }
        public Boolean getActive() { return active; }
        public void setActive(Boolean active) { this.active = active; }
    }
}
