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
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DispatchMatchingConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Builder.Default
    @Column(name = "search_radius_km", nullable = false)
    private double searchRadiusKm = 10.0; // 10 KM Search Radius

    @Builder.Default
    @Column(name = "strict_skill_matching", nullable = false)
    private boolean strictSkillMatching = true;

    @Builder.Default
    @Column(name = "score_weight_distance", nullable = false)
    private double scoreWeightDistance = 0.40; // 40% Weight for distance

    @Builder.Default
    @Column(name = "score_weight_rating", nullable = false)
    private double scoreWeightRating = 0.30; // 30% Weight for rating

    @Builder.Default
    @Column(name = "score_weight_acceptance", nullable = false)
    private double scoreWeightAcceptance = 0.15; // 15% Weight for acceptance rate

    @Builder.Default
    @Column(name = "score_weight_experience", nullable = false)
    private double scoreWeightExperience = 0.15; // 15% Weight for experience years

    @Builder.Default
    @Column(name = "priority_policy", length = 50, nullable = false)
    private String priorityPolicy = "BALANCED"; // BALANCED, NEAREST_FIRST, HIGHEST_RATED, FAIR_SHARE

    @Builder.Default
    @Column(name = "notification_timeout_seconds", nullable = false)
    private int notificationTimeoutSeconds = 30; // 30s proposal timer

    @Builder.Default
    @Column(name = "max_dispatch_attempts", nullable = false)
    private int maxDispatchAttempts = 5; // Max 5 candidate attempts

    @Builder.Default
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
}
