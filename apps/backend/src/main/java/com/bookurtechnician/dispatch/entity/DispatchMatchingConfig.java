package com.bookurtechnician.dispatch.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "dispatch_matching_configs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class DispatchMatchingConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "search_radius_km", nullable = false)
    private double searchRadiusKm = 15.0; // 15 KM Search Radius

    @Column(name = "strict_skill_matching", nullable = false)
    private boolean strictSkillMatching = true;

    @Column(name = "score_weight_distance", nullable = false)
    private double scoreWeightDistance = 0.40; // 40% Weight for distance

    @Column(name = "score_weight_rating", nullable = false)
    private double scoreWeightRating = 0.30; // 30% Weight for rating

    @Column(name = "score_weight_acceptance", nullable = false)
    private double scoreWeightAcceptance = 0.15; // 15% Weight for acceptance rate

    @Column(name = "score_weight_experience", nullable = false)
    private double scoreWeightExperience = 0.15; // 15% Weight for experience years

    @Column(name = "priority_policy", length = 50, nullable = false)
    private String priorityPolicy = "BALANCED"; // BALANCED, NEAREST_FIRST, HIGHEST_RATED, FAIR_SHARE

    @Column(name = "notification_timeout_seconds", nullable = false)
    private int notificationTimeoutSeconds = 30; // 30s proposal timer

    @Column(name = "max_dispatch_attempts", nullable = false)
    private int maxDispatchAttempts = 5; // Max 5 candidate attempts

    @Column(name = "auto_escalate_to_admin", nullable = false)
    private boolean autoEscalateToAdmin = true;

    @Column(name = "updated_by_email")
    private String updatedByEmail;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

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

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private double searchRadiusKm = 15.0;
        private boolean strictSkillMatching = true;
        private double scoreWeightDistance = 0.40;
        private double scoreWeightRating = 0.30;
        private double scoreWeightAcceptance = 0.15;
        private double scoreWeightExperience = 0.15;
        private String priorityPolicy = "BALANCED";
        private int notificationTimeoutSeconds = 30;
        private int maxDispatchAttempts = 5;
        private boolean autoEscalateToAdmin = true;

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

        public DispatchMatchingConfig build() {
            DispatchMatchingConfig c = new DispatchMatchingConfig();
            c.searchRadiusKm = this.searchRadiusKm;
            c.strictSkillMatching = this.strictSkillMatching;
            c.scoreWeightDistance = this.scoreWeightDistance;
            c.scoreWeightRating = this.scoreWeightRating;
            c.scoreWeightAcceptance = this.scoreWeightAcceptance;
            c.scoreWeightExperience = this.scoreWeightExperience;
            c.priorityPolicy = this.priorityPolicy;
            c.notificationTimeoutSeconds = this.notificationTimeoutSeconds;
            c.maxDispatchAttempts = this.maxDispatchAttempts;
            c.autoEscalateToAdmin = this.autoEscalateToAdmin;
            return c;
        }
    }
}
