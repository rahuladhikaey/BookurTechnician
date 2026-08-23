package com.bookurtechnician.servicecatalog.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "service_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ServiceItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    private ServiceCategory category;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(nullable = false, unique = true, length = 200)
    private String slug;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(name = "booking_charge", precision = 10, scale = 2)
    private BigDecimal bookingCharge = new BigDecimal("49.00");

    @Column(name = "advance_prepayment_pct")
    private int advancePrepaymentPct = 30;

    @Column(name = "technician_payout_amount", precision = 10, scale = 2)
    private BigDecimal technicianPayoutAmount;

    @Column(name = "duration_minutes")
    private int durationMinutes = 45;

    @Column(name = "warranty_text", length = 100)
    private String warrantyText = "30-Day Service Warranty";

    private String description;

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @Column(name = "is_popular")
    private boolean popular = false;

    @Column(name = "is_active")
    private boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public ServiceCategory getCategory() { return category; }
    public void setCategory(ServiceCategory category) { this.category = category; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getSlug() { return slug; }
    public void setSlug(String slug) { this.slug = slug; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public BigDecimal getBookingCharge() { return bookingCharge; }
    public void setBookingCharge(BigDecimal bookingCharge) { this.bookingCharge = bookingCharge; }

    public int getAdvancePrepaymentPct() { return advancePrepaymentPct; }
    public void setAdvancePrepaymentPct(int advancePrepaymentPct) { this.advancePrepaymentPct = advancePrepaymentPct; }

    public BigDecimal getTechnicianPayoutAmount() { return technicianPayoutAmount; }
    public void setTechnicianPayoutAmount(BigDecimal technicianPayoutAmount) { this.technicianPayoutAmount = technicianPayoutAmount; }

    public int getDurationMinutes() { return durationMinutes; }
    public void setDurationMinutes(int durationMinutes) { this.durationMinutes = durationMinutes; }

    public String getWarrantyText() { return warrantyText; }
    public void setWarrantyText(String warrantyText) { this.warrantyText = warrantyText; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public boolean isPopular() { return popular; }
    public void setPopular(boolean popular) { this.popular = popular; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private ServiceCategory category;
        private String name;
        private String slug;
        private BigDecimal price;
        private BigDecimal bookingCharge = new BigDecimal("49.00");
        private int advancePrepaymentPct = 30;
        private BigDecimal technicianPayoutAmount;
        private int durationMinutes = 45;
        private String warrantyText = "30-Day Service Warranty";
        private String description;
        private String imageUrl;
        private boolean popular = false;
        private boolean active = true;
        private Instant createdAt;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder category(ServiceCategory category) { this.category = category; return this; }
        public Builder name(String name) { this.name = name; return this; }
        public Builder slug(String slug) { this.slug = slug; return this; }
        public Builder price(BigDecimal price) { this.price = price; return this; }
        public Builder bookingCharge(BigDecimal bookingCharge) { this.bookingCharge = bookingCharge; return this; }
        public Builder advancePrepaymentPct(int advancePrepaymentPct) { this.advancePrepaymentPct = advancePrepaymentPct; return this; }
        public Builder technicianPayoutAmount(BigDecimal technicianPayoutAmount) { this.technicianPayoutAmount = technicianPayoutAmount; return this; }
        public Builder durationMinutes(int durationMinutes) { this.durationMinutes = durationMinutes; return this; }
        public Builder warrantyText(String warrantyText) { this.warrantyText = warrantyText; return this; }
        public Builder description(String description) { this.description = description; return this; }
        public Builder imageUrl(String imageUrl) { this.imageUrl = imageUrl; return this; }
        public Builder popular(boolean popular) { this.popular = popular; return this; }
        public Builder active(boolean active) { this.active = active; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public ServiceItem build() {
            ServiceItem si = new ServiceItem();
            si.id = this.id;
            si.category = this.category;
            si.name = this.name;
            si.slug = this.slug;
            si.price = this.price;
            si.bookingCharge = this.bookingCharge != null ? this.bookingCharge : new BigDecimal("49.00");
            si.advancePrepaymentPct = this.advancePrepaymentPct;
            si.technicianPayoutAmount = this.technicianPayoutAmount;
            si.durationMinutes = this.durationMinutes;
            si.warrantyText = this.warrantyText != null ? this.warrantyText : "30-Day Service Warranty";
            si.description = this.description;
            si.imageUrl = this.imageUrl;
            si.popular = this.popular;
            si.active = this.active;
            si.createdAt = this.createdAt;
            si.updatedAt = this.updatedAt;
            return si;
        }
    }
}
