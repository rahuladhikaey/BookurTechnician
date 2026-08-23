package com.bookurtechnician.technician.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class TechnicianSkillDtos {

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
        private String verificationStatus;
        private boolean enabled;
        private String rejectionReason;
        private Instant verifiedAt;
        private Instant createdAt;

        public TechnicianSkillDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private UUID skillId;
            private String skillName;
            private String skillSlug;
            private UUID categoryId;
            private String categoryName;
            private UUID serviceItemId;
            private String serviceItemName;
            private int experienceYears;
            private String verificationStatus;
            private boolean enabled;
            private String rejectionReason;
            private Instant verifiedAt;
            private Instant createdAt;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder skillId(UUID skillId) { this.skillId = skillId; return this; }
            public Builder skillName(String skillName) { this.skillName = skillName; return this; }
            public Builder skillSlug(String skillSlug) { this.skillSlug = skillSlug; return this; }
            public Builder categoryId(UUID categoryId) { this.categoryId = categoryId; return this; }
            public Builder categoryName(String categoryName) { this.categoryName = categoryName; return this; }
            public Builder serviceItemId(UUID serviceItemId) { this.serviceItemId = serviceItemId; return this; }
            public Builder serviceItemName(String serviceItemName) { this.serviceItemName = serviceItemName; return this; }
            public Builder experienceYears(int experienceYears) { this.experienceYears = experienceYears; return this; }
            public Builder verificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; return this; }
            public Builder enabled(boolean enabled) { this.enabled = enabled; return this; }
            public Builder rejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; return this; }
            public Builder verifiedAt(Instant verifiedAt) { this.verifiedAt = verifiedAt; return this; }
            public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }

            public TechnicianSkillDto build() {
                TechnicianSkillDto dto = new TechnicianSkillDto();
                dto.id = this.id;
                dto.skillId = this.skillId;
                dto.skillName = this.skillName;
                dto.skillSlug = this.skillSlug;
                dto.categoryId = this.categoryId;
                dto.categoryName = this.categoryName;
                dto.serviceItemId = this.serviceItemId;
                dto.serviceItemName = this.serviceItemName;
                dto.experienceYears = this.experienceYears;
                dto.verificationStatus = this.verificationStatus;
                dto.enabled = this.enabled;
                dto.rejectionReason = this.rejectionReason;
                dto.verifiedAt = this.verifiedAt;
                dto.createdAt = this.createdAt;
                return dto;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public UUID getSkillId() { return skillId; }
        public void setSkillId(UUID skillId) { this.skillId = skillId; }
        public String getSkillName() { return skillName; }
        public void setSkillName(String skillName) { this.skillName = skillName; }
        public String getSkillSlug() { return skillSlug; }
        public void setSkillSlug(String skillSlug) { this.skillSlug = skillSlug; }
        public UUID getCategoryId() { return categoryId; }
        public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }
        public String getCategoryName() { return categoryName; }
        public void setCategoryName(String categoryName) { this.categoryName = categoryName; }
        public UUID getServiceItemId() { return serviceItemId; }
        public void setServiceItemId(UUID serviceItemId) { this.serviceItemId = serviceItemId; }
        public String getServiceItemName() { return serviceItemName; }
        public void setServiceItemName(String serviceItemName) { this.serviceItemName = serviceItemName; }
        public int getExperienceYears() { return experienceYears; }
        public void setExperienceYears(int experienceYears) { this.experienceYears = experienceYears; }
        public String getVerificationStatus() { return verificationStatus; }
        public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }
        public boolean isEnabled() { return enabled; }
        public void setEnabled(boolean enabled) { this.enabled = enabled; }
        public String getRejectionReason() { return rejectionReason; }
        public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }
        public Instant getVerifiedAt() { return verifiedAt; }
        public void setVerifiedAt(Instant verifiedAt) { this.verifiedAt = verifiedAt; }
        public Instant getCreatedAt() { return createdAt; }
        public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    }

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

        public TechnicianSkillProfileResponse() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
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

            public Builder technicianId(UUID technicianId) { this.technicianId = technicianId; return this; }
            public Builder technicianCode(String technicianCode) { this.technicianCode = technicianCode; return this; }
            public Builder fullName(String fullName) { this.fullName = fullName; return this; }
            public Builder profileImageUrl(String profileImageUrl) { this.profileImageUrl = profileImageUrl; return this; }
            public Builder rating(BigDecimal rating) { this.rating = rating; return this; }
            public Builder totalRatingsCount(int totalRatingsCount) { this.totalRatingsCount = totalRatingsCount; return this; }
            public Builder totalJobsCompleted(int totalJobsCompleted) { this.totalJobsCompleted = totalJobsCompleted; return this; }
            public Builder skills(List<TechnicianSkillDto> skills) { this.skills = skills; return this; }
            public Builder totalSkillsCount(int totalSkillsCount) { this.totalSkillsCount = totalSkillsCount; return this; }
            public Builder verifiedSkillsCount(int verifiedSkillsCount) { this.verifiedSkillsCount = verifiedSkillsCount; return this; }
            public Builder pendingSkillsCount(int pendingSkillsCount) { this.pendingSkillsCount = pendingSkillsCount; return this; }

            public TechnicianSkillProfileResponse build() {
                TechnicianSkillProfileResponse r = new TechnicianSkillProfileResponse();
                r.technicianId = this.technicianId;
                r.technicianCode = this.technicianCode;
                r.fullName = this.fullName;
                r.profileImageUrl = this.profileImageUrl;
                r.rating = this.rating;
                r.totalRatingsCount = this.totalRatingsCount;
                r.totalJobsCompleted = this.totalJobsCompleted;
                r.skills = this.skills;
                r.totalSkillsCount = this.totalSkillsCount;
                r.verifiedSkillsCount = this.verifiedSkillsCount;
                r.pendingSkillsCount = this.pendingSkillsCount;
                return r;
            }
        }

        public UUID getTechnicianId() { return technicianId; }
        public void setTechnicianId(UUID technicianId) { this.technicianId = technicianId; }
        public String getTechnicianCode() { return technicianCode; }
        public void setTechnicianCode(String technicianCode) { this.technicianCode = technicianCode; }
        public String getFullName() { return fullName; }
        public void setFullName(String fullName) { this.fullName = fullName; }
        public String getProfileImageUrl() { return profileImageUrl; }
        public void setProfileImageUrl(String profileImageUrl) { this.profileImageUrl = profileImageUrl; }
        public BigDecimal getRating() { return rating; }
        public void setRating(BigDecimal rating) { this.rating = rating; }
        public int getTotalRatingsCount() { return totalRatingsCount; }
        public void setTotalRatingsCount(int totalRatingsCount) { this.totalRatingsCount = totalRatingsCount; }
        public int getTotalJobsCompleted() { return totalJobsCompleted; }
        public void setTotalJobsCompleted(int totalJobsCompleted) { this.totalJobsCompleted = totalJobsCompleted; }
        public List<TechnicianSkillDto> getSkills() { return skills; }
        public void setSkills(List<TechnicianSkillDto> skills) { this.skills = skills; }
        public int getTotalSkillsCount() { return totalSkillsCount; }
        public void setTotalSkillsCount(int totalSkillsCount) { this.totalSkillsCount = totalSkillsCount; }
        public int getVerifiedSkillsCount() { return verifiedSkillsCount; }
        public void setVerifiedSkillsCount(int verifiedSkillsCount) { this.verifiedSkillsCount = verifiedSkillsCount; }
        public int getPendingSkillsCount() { return pendingSkillsCount; }
        public void setPendingSkillsCount(int pendingSkillsCount) { this.pendingSkillsCount = pendingSkillsCount; }
    }

    public static class BulkSaveSkillsRequest {
        private List<SkillItemRequest> skills;

        public BulkSaveSkillsRequest() {}
        public BulkSaveSkillsRequest(List<SkillItemRequest> skills) { this.skills = skills; }

        public List<SkillItemRequest> getSkills() { return skills; }
        public void setSkills(List<SkillItemRequest> skills) { this.skills = skills; }
    }

    public static class SkillItemRequest {
        private UUID skillId;
        private int experienceYears = 1;
        private String certificateUrl;

        public SkillItemRequest() {}

        public UUID getSkillId() { return skillId; }
        public void setSkillId(UUID skillId) { this.skillId = skillId; }
        public int getExperienceYears() { return experienceYears; }
        public void setExperienceYears(int experienceYears) { this.experienceYears = experienceYears; }
        public String getCertificateUrl() { return certificateUrl; }
        public void setCertificateUrl(String certificateUrl) { this.certificateUrl = certificateUrl; }
    }

    public static class VerifySkillAdminRequest {
        private String status;
        private String rejectionReason;

        public VerifySkillAdminRequest() {}

        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public String getRejectionReason() { return rejectionReason; }
        public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }
    }
}
