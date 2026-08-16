package com.bookurtechnician.banner.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

public class BannerDtos {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
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
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
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
        private boolean active;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
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
    }
}
