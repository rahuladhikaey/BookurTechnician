package com.bookurtechnician.model;

import jakarta.persistence.*;
import lombok.*;
import org.locationtech.jts.geom.Point;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "technician_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TechnicianProfile {

    @Id
    @Column(length = 64)
    private String id;

    @Column(name = "technician_id", length = 64, unique = true, nullable = false)
    private String technicianId;

    @Column(name = "technician_code", length = 30, unique = true)
    private String technicianCode;

    @Column(name = "full_name", length = 100, nullable = false)
    private String fullName;

    @Column(length = 20, nullable = false)
    private String phone;

    @Column(length = 50)
    private String category;

    @Column(name = "experience_years")
    private Integer experienceYears;

    @Column(name = "kyc_status", length = 30)
    private String kycStatus; // PENDING, VERIFIED, REJECTED

    @Column(name = "is_online")
    private Boolean isOnline;

    @Column(name = "current_latitude")
    private Double currentLatitude;

    @Column(name = "current_longitude")
    private Double currentLongitude;

    @Column(name = "location", columnDefinition = "geography(Point, 4326)")
    private Point location;

    @Column(name = "last_location_update")
    private OffsetDateTime lastLocationUpdate;

    @Column(name = "availability_status", length = 30)
    private String availabilityStatus; // AVAILABLE, BUSY, OFFLINE

    @Column(precision = 3, scale = 2)
    private BigDecimal rating;

    @Column(name = "total_ratings_count")
    private Integer totalRatingsCount;

    @Column(name = "total_jobs_completed")
    private Integer totalJobsCompleted;

    @Column(name = "acceptance_rate", precision = 5, scale = 2)
    private BigDecimal acceptanceRate;

    @Column(name = "wallet_balance", precision = 10, scale = 2)
    private BigDecimal walletBalance;

    @Column(name = "upi_id", length = 100)
    private String upiId;

    @Column(name = "upi_number", length = 20)
    private String upiNumber;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
