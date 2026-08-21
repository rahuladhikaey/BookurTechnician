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
@Builder
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

    @Builder.Default
    @Column(name = "booking_charge", precision = 10, scale = 2)
    private BigDecimal bookingCharge = new BigDecimal("49.00");

    @Builder.Default
    @Column(name = "advance_prepayment_pct")
    private int advancePrepaymentPct = 30;

    @Column(name = "technician_payout_amount", precision = 10, scale = 2)
    private BigDecimal technicianPayoutAmount;

    @Builder.Default
    @Column(name = "duration_minutes")
    private int durationMinutes = 45;

    @Builder.Default
    @Column(name = "warranty_text", length = 100)
    private String warrantyText = "30-Day Service Warranty";

    private String description;

    @Column(name = "image_url")
    private String imageUrl;

    @Builder.Default
    @Column(name = "is_popular")
    private boolean popular = false;

    @Builder.Default
    @Column(name = "is_active")
    private boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
