package com.bookurtechnician.technician.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class TechnicianSkillDtos {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TechnicianSkillDto {
        private UUID id;
        private UUID skillId;
        private String skillName;
        private String skillSlug;
        private UUID categoryId;
        private String categoryName;
        private UUID serviceItemId;
        private String serviceItemName;
        private int experienceYears;
        private String verificationStatus; // PENDING, VERIFIED, REJECTED
        private boolean enabled;
        private String rejectionReason;
        private Instant verifiedAt;
        private Instant createdAt;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TechnicianSkillProfileResponse {
        private UUID technicianId;
        private String technicianCode;
        private String fullName;
        private String profileImageUrl;
        private BigDecimal rating;
        private int totalRatingsCount;
        private int totalJobsCompleted;
        private List<TechnicianSkillDto> skills;
        private int totalSkillsCount;
        private int verifiedSkillsCount;
        private int pendingSkillsCount;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class BulkSaveSkillsRequest {
        private List<SkillItemRequest> skills;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SkillItemRequest {
        private UUID skillId;
        private int experienceYears = 1;
        private String certificateUrl;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VerifySkillAdminRequest {
        private String status; // VERIFIED, REJECTED, PENDING
        private String rejectionReason;
    }
}
