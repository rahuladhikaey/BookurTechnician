package com.bookurtechnician.servicecatalog.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public class CatalogDtos {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CategoryHierarchyDto {
        private UUID id;
        private String name;
        private String slug;
        private String iconUrl;
        private int displayOrder;
        private List<ServiceHierarchyDto> services;
        private List<SkillDto> skills;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ServiceHierarchyDto {
        private UUID id;
        private String name;
        private String slug;
        private BigDecimal price;
        private String description;
        private List<SkillDto> skills;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SkillDto {
        private UUID id;
        private UUID categoryId;
        private String categoryName;
        private UUID serviceItemId;
        private String serviceItemName;
        private String name;
        private String slug;
        private String description;
        private int displayOrder;
        private boolean active;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateSkillRequest {
        private UUID categoryId;
        private UUID serviceItemId;
        private String name;
        private String description;
        private int displayOrder;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateSkillRequest {
        private String name;
        private String description;
        private int displayOrder;
        private Boolean active;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SkillCompatibilityDto {
        private UUID skillId;
        private String skillName;
        private String categoryName;
        private List<CompatibleServiceSummary> compatibleServices;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CompatibleServiceSummary {
        private UUID serviceId;
        private String serviceName;
        private String categoryName;
        private BigDecimal price;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateSkillCompatibilityRequest {
        private List<UUID> serviceItemIds;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DispatchMatchingConfigDto {
        private UUID id;
        private double searchRadiusKm;
        private boolean strictSkillMatching;
        private double scoreWeightDistance;
        private double scoreWeightRating;
        private double scoreWeightAcceptance;
        private double scoreWeightExperience;
        private String priorityPolicy;
        private int notificationTimeoutSeconds;
        private int maxDispatchAttempts;
        private boolean autoEscalateToAdmin;
        private String updatedByEmail;
    }
}
