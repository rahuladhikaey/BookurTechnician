package com.bookurtechnician.banner.entity;

import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "banners")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Banner {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String subtitle;

    @Column(name = "image_url", nullable = false, columnDefinition = "TEXT")
    private String imageUrl;

    @Builder.Default
    @Column(name = "banner_type", length = 30)
    private String bannerType = "HERO"; // HERO, SPOTLIGHT, RUNNING

    @Column(name = "badge_text", length = 50)
    private String badgeText;

    @Builder.Default
    @Column(name = "cta_text", length = 50)
    private String ctaText = "Book Now";

    @Column(name = "target_type", length = 50)
    private String targetType; // CATEGORY, SERVICE, EXTERNAL_URL, IN_APP_PAGE

    @Column(name = "target_payload", columnDefinition = "TEXT")
    private String targetPayload;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private ServiceCategory category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_id")
    private ServiceItem service;

    @Builder.Default
    @Column(name = "display_order")
    private Integer displayOrder = 0;

    @Builder.Default
    @Column(name = "is_active")
    private boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}
