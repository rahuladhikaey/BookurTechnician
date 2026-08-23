package com.bookurtechnician.dispatch.entity;

import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "booking_proposals")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class BookingProposal {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false)
    private TechnicianProfile technician;

    @Column(name = "distance_meters", nullable = false, precision = 10, scale = 2)
    private BigDecimal distanceMeters;

    @Column(name = "estimated_earnings", nullable = false, precision = 10, scale = 2)
    private BigDecimal estimatedEarnings;

    @Column(nullable = false, length = 30)
    private String status = "PENDING"; // PENDING, ACCEPTED, REJECTED, EXPIRED, CANCELLED

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Booking getBooking() { return booking; }
    public void setBooking(Booking booking) { this.booking = booking; }

    public TechnicianProfile getTechnician() { return technician; }
    public void setTechnician(TechnicianProfile technician) { this.technician = technician; }

    public BigDecimal getDistanceMeters() { return distanceMeters; }
    public void setDistanceMeters(BigDecimal distanceMeters) { this.distanceMeters = distanceMeters; }

    public BigDecimal getEstimatedEarnings() { return estimatedEarnings; }
    public void setEstimatedEarnings(BigDecimal estimatedEarnings) { this.estimatedEarnings = estimatedEarnings; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }

    public Instant getRespondedAt() { return respondedAt; }
    public void setRespondedAt(Instant respondedAt) { this.respondedAt = respondedAt; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private Booking booking;
        private TechnicianProfile technician;
        private BigDecimal distanceMeters;
        private BigDecimal estimatedEarnings;
        private String status = "PENDING";
        private Instant expiresAt;
        private Instant respondedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder booking(Booking booking) { this.booking = booking; return this; }
        public Builder technician(TechnicianProfile technician) { this.technician = technician; return this; }
        public Builder distanceMeters(BigDecimal distanceMeters) { this.distanceMeters = distanceMeters; return this; }
        public Builder estimatedEarnings(BigDecimal estimatedEarnings) { this.estimatedEarnings = estimatedEarnings; return this; }
        public Builder status(String status) { this.status = status; return this; }
        public Builder expiresAt(Instant expiresAt) { this.expiresAt = expiresAt; return this; }
        public Builder respondedAt(Instant respondedAt) { this.respondedAt = respondedAt; return this; }

        public BookingProposal build() {
            BookingProposal p = new BookingProposal();
            p.id = this.id;
            p.booking = this.booking;
            p.technician = this.technician;
            p.distanceMeters = this.distanceMeters;
            p.estimatedEarnings = this.estimatedEarnings;
            p.status = this.status != null ? this.status : "PENDING";
            p.expiresAt = this.expiresAt;
            p.respondedAt = this.respondedAt;
            return p;
        }
    }
}
