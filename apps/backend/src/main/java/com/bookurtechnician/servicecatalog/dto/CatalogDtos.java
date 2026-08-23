package com.bookurtechnician.servicecatalog.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public class CatalogDtos {

    public static class CategoryHierarchyDto {
        private UUID id;
        private String name;
        private String slug;
        private String iconUrl;
        private int displayOrder;
        private List<ServiceHierarchyDto> services;
        private List<SkillDto> skills;

        public CategoryHierarchyDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private String name;
            private String slug;
            private String iconUrl;
            private int displayOrder;
            private List<ServiceHierarchyDto> services;
            private List<SkillDto> skills;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder name(String name) { this.name = name; return this; }
            public Builder slug(String slug) { this.slug = slug; return this; }
            public Builder iconUrl(String iconUrl) { this.iconUrl = iconUrl; return this; }
            public Builder displayOrder(int displayOrder) { this.displayOrder = displayOrder; return this; }
            public Builder services(List<ServiceHierarchyDto> services) { this.services = services; return this; }
            public Builder skills(List<SkillDto> skills) { this.skills = skills; return this; }

            public CategoryHierarchyDto build() {
                CategoryHierarchyDto dto = new CategoryHierarchyDto();
                dto.id = this.id;
                dto.name = this.name;
                dto.slug = this.slug;
                dto.iconUrl = this.iconUrl;
                dto.displayOrder = this.displayOrder;
                dto.services = this.services;
                dto.skills = this.skills;
                return dto;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getSlug() { return slug; }
        public void setSlug(String slug) { this.slug = slug; }
        public String getIconUrl() { return iconUrl; }
        public void setIconUrl(String iconUrl) { this.iconUrl = iconUrl; }
        public int getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }
        public List<ServiceHierarchyDto> getServices() { return services; }
        public void setServices(List<ServiceHierarchyDto> services) { this.services = services; }
        public List<SkillDto> getSkills() { return skills; }
        public void setSkills(List<SkillDto> skills) { this.skills = skills; }
    }

    public static class ServiceHierarchyDto {
        private UUID id;
        private String name;
        private String slug;
        private BigDecimal price;
        private String description;
        private List<SkillDto> skills;

        public ServiceHierarchyDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private String name;
            private String slug;
            private BigDecimal price;
            private String description;
            private List<SkillDto> skills;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder name(String name) { this.name = name; return this; }
            public Builder slug(String slug) { this.slug = slug; return this; }
            public Builder price(BigDecimal price) { this.price = price; return this; }
            public Builder description(String description) { this.description = description; return this; }
            public Builder skills(List<SkillDto> skills) { this.skills = skills; return this; }

            public ServiceHierarchyDto build() {
                ServiceHierarchyDto dto = new ServiceHierarchyDto();
                dto.id = this.id;
                dto.name = this.name;
                dto.slug = this.slug;
                dto.price = this.price;
                dto.description = this.description;
                dto.skills = this.skills;
                return dto;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getSlug() { return slug; }
        public void setSlug(String slug) { this.slug = slug; }
        public BigDecimal getPrice() { return price; }
        public void setPrice(BigDecimal price) { this.price = price; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public List<SkillDto> getSkills() { return skills; }
        public void setSkills(List<SkillDto> skills) { this.skills = skills; }
    }

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

        public SkillDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
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

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder categoryId(UUID categoryId) { this.categoryId = categoryId; return this; }
            public Builder categoryName(String categoryName) { this.categoryName = categoryName; return this; }
            public Builder serviceItemId(UUID serviceItemId) { this.serviceItemId = serviceItemId; return this; }
            public Builder serviceItemName(String serviceItemName) { this.serviceItemName = serviceItemName; return this; }
            public Builder name(String name) { this.name = name; return this; }
            public Builder slug(String slug) { this.slug = slug; return this; }
            public Builder description(String description) { this.description = description; return this; }
            public Builder displayOrder(int displayOrder) { this.displayOrder = displayOrder; return this; }
            public Builder active(boolean active) { this.active = active; return this; }

            public SkillDto build() {
                SkillDto dto = new SkillDto();
                dto.id = this.id;
                dto.categoryId = this.categoryId;
                dto.categoryName = this.categoryName;
                dto.serviceItemId = this.serviceItemId;
                dto.serviceItemName = this.serviceItemName;
                dto.name = this.name;
                dto.slug = this.slug;
                dto.description = this.description;
                dto.displayOrder = this.displayOrder;
                dto.active = this.active;
                return dto;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public UUID getCategoryId() { return categoryId; }
        public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }
        public String getCategoryName() { return categoryName; }
        public void setCategoryName(String categoryName) { this.categoryName = categoryName; }
        public UUID getServiceItemId() { return serviceItemId; }
        public void setServiceItemId(UUID serviceItemId) { this.serviceItemId = serviceItemId; }
        public String getServiceItemName() { return serviceItemName; }
        public void setServiceItemName(String serviceItemName) { this.serviceItemName = serviceItemName; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getSlug() { return slug; }
        public void setSlug(String slug) { this.slug = slug; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public int getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }
        public boolean isActive() { return active; }
        public void setActive(boolean active) { this.active = active; }
    }

    public static class CreateSkillRequest {
        private UUID categoryId;
        private UUID serviceItemId;
        private String name;
        private String description;
        private int displayOrder;

        public CreateSkillRequest() {}

        public UUID getCategoryId() { return categoryId; }
        public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }
        public UUID getServiceItemId() { return serviceItemId; }
        public void setServiceItemId(UUID serviceItemId) { this.serviceItemId = serviceItemId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public int getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }
    }

    public static class UpdateSkillRequest {
        private String name;
        private String description;
        private int displayOrder;
        private Boolean active;

        public UpdateSkillRequest() {}

        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public int getDisplayOrder() { return displayOrder; }
        public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }
        public Boolean getActive() { return active; }
        public void setActive(Boolean active) { this.active = active; }
    }

    public static class SkillCompatibilityDto {
        private UUID skillId;
        private String skillName;
        private String categoryName;
        private List<CompatibleServiceSummary> compatibleServices;

        public SkillCompatibilityDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID skillId;
            private String skillName;
            private String categoryName;
            private List<CompatibleServiceSummary> compatibleServices;

            public Builder skillId(UUID skillId) { this.skillId = skillId; return this; }
            public Builder skillName(String skillName) { this.skillName = skillName; return this; }
            public Builder categoryName(String categoryName) { this.categoryName = categoryName; return this; }
            public Builder compatibleServices(List<CompatibleServiceSummary> compatibleServices) { this.compatibleServices = compatibleServices; return this; }

            public SkillCompatibilityDto build() {
                SkillCompatibilityDto dto = new SkillCompatibilityDto();
                dto.skillId = this.skillId;
                dto.skillName = this.skillName;
                dto.categoryName = this.categoryName;
                dto.compatibleServices = this.compatibleServices;
                return dto;
            }
        }

        public UUID getSkillId() { return skillId; }
        public void setSkillId(UUID skillId) { this.skillId = skillId; }
        public String getSkillName() { return skillName; }
        public void setSkillName(String skillName) { this.skillName = skillName; }
        public String getCategoryName() { return categoryName; }
        public void setCategoryName(String categoryName) { this.categoryName = categoryName; }
        public List<CompatibleServiceSummary> getCompatibleServices() { return compatibleServices; }
        public void setCompatibleServices(List<CompatibleServiceSummary> compatibleServices) { this.compatibleServices = compatibleServices; }
    }

    public static class CompatibleServiceSummary {
        private UUID serviceId;
        private String serviceName;
        private String categoryName;
        private BigDecimal price;

        public CompatibleServiceSummary() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID serviceId;
            private String serviceName;
            private String categoryName;
            private BigDecimal price;

            public Builder serviceId(UUID serviceId) { this.serviceId = serviceId; return this; }
            public Builder serviceName(String serviceName) { this.serviceName = serviceName; return this; }
            public Builder categoryName(String categoryName) { this.categoryName = categoryName; return this; }
            public Builder price(BigDecimal price) { this.price = price; return this; }

            public CompatibleServiceSummary build() {
                CompatibleServiceSummary s = new CompatibleServiceSummary();
                s.serviceId = this.serviceId;
                s.serviceName = this.serviceName;
                s.categoryName = this.categoryName;
                s.price = this.price;
                return s;
            }
        }

        public UUID getServiceId() { return serviceId; }
        public void setServiceId(UUID serviceId) { this.serviceId = serviceId; }
        public String getServiceName() { return serviceName; }
        public void setServiceName(String serviceName) { this.serviceName = serviceName; }
        public String getCategoryName() { return categoryName; }
        public void setCategoryName(String categoryName) { this.categoryName = categoryName; }
        public BigDecimal getPrice() { return price; }
        public void setPrice(BigDecimal price) { this.price = price; }
    }

    public static class UpdateSkillCompatibilityRequest {
        private List<UUID> serviceItemIds;

        public UpdateSkillCompatibilityRequest() {}

        public List<UUID> getServiceItemIds() { return serviceItemIds; }
        public void setServiceItemIds(List<UUID> serviceItemIds) { this.serviceItemIds = serviceItemIds; }
    }

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

        public DispatchMatchingConfigDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
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

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder searchRadiusKm(double searchRadiusKm) { this.searchRadiusKm = searchRadiusKm; return this; }
            public Builder strictSkillMatching(boolean strictSkillMatching) { this.strictSkillMatching = strictSkillMatching; return this; }
            public Builder scoreWeightDistance(double scoreWeightDistance) { this.scoreWeightDistance = scoreWeightDistance; return this; }
            public Builder scoreWeightRating(double scoreWeightRating) { this.scoreWeightRating = scoreWeightRating; return this; }
            public Builder scoreWeightAcceptance(double scoreWeightAcceptance) { this.scoreWeightAcceptance = scoreWeightAcceptance; return this; }
            public Builder scoreWeightExperience(double scoreWeightExperience) { this.scoreWeightExperience = scoreWeightExperience; return this; }
            public Builder priorityPolicy(String priorityPolicy) { this.priorityPolicy = priorityPolicy; return this; }
            public Builder notificationTimeoutSeconds(int notificationTimeoutSeconds) { this.notificationTimeoutSeconds = notificationTimeoutSeconds; return this; }
            public Builder maxDispatchAttempts(int maxDispatchAttempts) { this.maxDispatchAttempts = maxDispatchAttempts; return this; }
            public Builder autoEscalateToAdmin(boolean autoEscalateToAdmin) { this.autoEscalateToAdmin = autoEscalateToAdmin; return this; }
            public Builder updatedByEmail(String updatedByEmail) { this.updatedByEmail = updatedByEmail; return this; }

            public DispatchMatchingConfigDto build() {
                DispatchMatchingConfigDto dto = new DispatchMatchingConfigDto();
                dto.id = this.id;
                dto.searchRadiusKm = this.searchRadiusKm;
                dto.strictSkillMatching = this.strictSkillMatching;
                dto.scoreWeightDistance = this.scoreWeightDistance;
                dto.scoreWeightRating = this.scoreWeightRating;
                dto.scoreWeightAcceptance = this.scoreWeightAcceptance;
                dto.scoreWeightExperience = this.scoreWeightExperience;
                dto.priorityPolicy = this.priorityPolicy;
                dto.notificationTimeoutSeconds = this.notificationTimeoutSeconds;
                dto.maxDispatchAttempts = this.maxDispatchAttempts;
                dto.autoEscalateToAdmin = this.autoEscalateToAdmin;
                dto.updatedByEmail = this.updatedByEmail;
                return dto;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public double getSearchRadiusKm() { return searchRadiusKm; }
        public void setSearchRadiusKm(double searchRadiusKm) { this.searchRadiusKm = searchRadiusKm; }
        public boolean isStrictSkillMatching() { return strictSkillMatching; }
        public void setStrictSkillMatching(boolean strictSkillMatching) { this.strictSkillMatching = strictSkillMatching; }
        public double getScoreWeightDistance() { return scoreWeightDistance; }
        public void setScoreWeightDistance(double scoreWeightDistance) { this.scoreWeightDistance = scoreWeightDistance; }
        public double getScoreWeightRating() { return scoreWeightRating; }
        public void setScoreWeightRating(double scoreWeightRating) { this.scoreWeightRating = scoreWeightRating; }
        public double getScoreWeightAcceptance() { return scoreWeightAcceptance; }
        public void setScoreWeightAcceptance(double scoreWeightAcceptance) { this.scoreWeightAcceptance = scoreWeightAcceptance; }
        public double getScoreWeightExperience() { return scoreWeightExperience; }
        public void setScoreWeightExperience(double scoreWeightExperience) { this.scoreWeightExperience = scoreWeightExperience; }
        public String getPriorityPolicy() { return priorityPolicy; }
        public void setPriorityPolicy(String priorityPolicy) { this.priorityPolicy = priorityPolicy; }
        public int getNotificationTimeoutSeconds() { return notificationTimeoutSeconds; }
        public void setNotificationTimeoutSeconds(int notificationTimeoutSeconds) { this.notificationTimeoutSeconds = notificationTimeoutSeconds; }
        public int getMaxDispatchAttempts() { return maxDispatchAttempts; }
        public void setMaxDispatchAttempts(int maxDispatchAttempts) { this.maxDispatchAttempts = maxDispatchAttempts; }
        public boolean isAutoEscalateToAdmin() { return autoEscalateToAdmin; }
        public void setAutoEscalateToAdmin(boolean autoEscalateToAdmin) { this.autoEscalateToAdmin = autoEscalateToAdmin; }
        public String getUpdatedByEmail() { return updatedByEmail; }
        public void setUpdatedByEmail(String updatedByEmail) { this.updatedByEmail = updatedByEmail; }
    }
}
