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

    @Column(name = "is_online")
    private boolean online = false;

    @Column(name = "current_location", columnDefinition = "geometry(Point, 4326)")
    private Point currentLocation;

    @Column(name = "location_updated_at")
    private Instant locationUpdatedAt;

    @Column(name = "kyc_status", length = 30)
    private String kycStatus = "PENDING"; // PENDING, SUBMITTED, VERIFIED, REJECTED

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Column(precision = 2, scale = 1)
    private BigDecimal rating = new BigDecimal("5.0");

    @Column(name = "total_ratings_count")
    private int totalRatingsCount = 0;

    @Column(name = "total_jobs_completed")
    private int totalJobsCompleted = 0;

    @Column(name = "upi_id", length = 100)
    private String upiId = "technician@upi";

    @Column(name = "is_upi_verified")
    private boolean upiVerified = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public String getTechnicianCode() { return technicianCode; }
    public void setTechnicianCode(String technicianCode) { this.technicianCode = technicianCode; }

    public UUID getPrimaryCategoryId() { return primaryCategoryId; }
    public void setPrimaryCategoryId(UUID primaryCategoryId) { this.primaryCategoryId = primaryCategoryId; }

    public boolean isOnline() { return online; }
    public void setOnline(boolean online) { this.online = online; }

    public Point getCurrentLocation() { return currentLocation; }
    public void setCurrentLocation(Point currentLocation) { this.currentLocation = currentLocation; }

    public Instant getLocationUpdatedAt() { return locationUpdatedAt; }
    public void setLocationUpdatedAt(Instant locationUpdatedAt) { this.locationUpdatedAt = locationUpdatedAt; }

    public String getKycStatus() { return kycStatus; }
    public void setKycStatus(String kycStatus) { this.kycStatus = kycStatus; }

    public String getRejectionReason() { return rejectionReason; }
    public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }

    public BigDecimal getRating() { return rating; }
    public void setRating(BigDecimal rating) { this.rating = rating; }

    public int getTotalRatingsCount() { return totalRatingsCount; }
    public void setTotalRatingsCount(int totalRatingsCount) { this.totalRatingsCount = totalRatingsCount; }

    public int getTotalJobsCompleted() { return totalJobsCompleted; }
    public void setTotalJobsCompleted(int totalJobsCompleted) { this.totalJobsCompleted = totalJobsCompleted; }

    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }

    public boolean isUpiVerified() { return upiVerified; }
    public void setUpiVerified(boolean upiVerified) { this.upiVerified = upiVerified; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private User user;
        private String technicianCode;
        private UUID primaryCategoryId;
        private boolean online = false;
        private Point currentLocation;
        private Instant locationUpdatedAt;
        private String kycStatus = "PENDING";
        private String rejectionReason;
        private BigDecimal rating = new BigDecimal("5.0");
        private int totalRatingsCount = 0;
        private int totalJobsCompleted = 0;
        private String upiId;
        private boolean upiVerified = false;
        private Instant createdAt;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder user(User user) { this.user = user; return this; }
        public Builder technicianCode(String technicianCode) { this.technicianCode = technicianCode; return this; }
        public Builder primaryCategoryId(UUID primaryCategoryId) { this.primaryCategoryId = primaryCategoryId; return this; }
        public Builder online(boolean online) { this.online = online; return this; }
        public Builder currentLocation(Point currentLocation) { this.currentLocation = currentLocation; return this; }
        public Builder locationUpdatedAt(Instant locationUpdatedAt) { this.locationUpdatedAt = locationUpdatedAt; return this; }
        public Builder kycStatus(String kycStatus) { this.kycStatus = kycStatus; return this; }
        public Builder rejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; return this; }
        public Builder rating(BigDecimal rating) { this.rating = rating; return this; }
        public Builder totalRatingsCount(int totalRatingsCount) { this.totalRatingsCount = totalRatingsCount; return this; }
        public Builder totalJobsCompleted(int totalJobsCompleted) { this.totalJobsCompleted = totalJobsCompleted; return this; }
        public Builder upiId(String upiId) { this.upiId = upiId; return this; }
        public Builder upiVerified(boolean upiVerified) { this.upiVerified = upiVerified; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public TechnicianProfile build() {
            TechnicianProfile tp = new TechnicianProfile();
            tp.id = this.id;
            tp.user = this.user;
            tp.technicianCode = this.technicianCode;
            tp.primaryCategoryId = this.primaryCategoryId;
            tp.online = this.online;
            tp.currentLocation = this.currentLocation;
            tp.locationUpdatedAt = this.locationUpdatedAt;
            tp.kycStatus = this.kycStatus != null ? this.kycStatus : "PENDING";
            tp.rejectionReason = this.rejectionReason;
            tp.rating = this.rating != null ? this.rating : new BigDecimal("5.0");
            tp.totalRatingsCount = this.totalRatingsCount;
            tp.totalJobsCompleted = this.totalJobsCompleted;
            tp.upiId = this.upiId;
            tp.upiVerified = this.upiVerified;
            tp.createdAt = this.createdAt;
            tp.updatedAt = this.updatedAt;
            return tp;
        }
    }
}
