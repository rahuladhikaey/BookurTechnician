package com.bookurtechnician.technician.entity;

import com.bookurtechnician.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.locationtech.jts.geom.Point;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "technician_profiles")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TechnicianProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "technician_code", unique = true, nullable = false, length = 30)
    private String technicianCode;

    @Column(name = "primary_category_id")
    private UUID primaryCategoryId;

    @Builder.Default
    @Column(name = "is_online")
    private boolean online = false;

    @Column(name = "current_location", columnDefinition = "geometry(Point, 4326)")
    private Point currentLocation;

    @Column(name = "location_updated_at")
    private Instant locationUpdatedAt;

    @Builder.Default
    @Column(name = "kyc_status", length = 30)
    private String kycStatus = "PENDING"; // PENDING, SUBMITTED, VERIFIED, REJECTED

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Builder.Default
    @Column(precision = 2, scale = 1)
    private BigDecimal rating = new BigDecimal("5.0");

    @Builder.Default
    @Column(name = "total_ratings_count")
    private int totalRatingsCount = 0;

    @Builder.Default
    @Column(name = "total_jobs_completed")
    private int totalJobsCompleted = 0;

    @Builder.Default
    @Column(name = "upi_id", length = 100)
    private String upiId = "technician@upi";

    @Builder.Default
    @Column(name = "is_upi_verified")
    private boolean upiVerified = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
