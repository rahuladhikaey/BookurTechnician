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

    @Column(name = "banner_type", length = 30)
    private String bannerType = "HERO"; // HERO, SPOTLIGHT, RUNNING

    @Column(name = "badge_text", length = 50)
    private String badgeText;

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

    @Column(name = "display_order")
    private Integer displayOrder = 0;

    @Column(name = "is_active")
    private boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getSubtitle() { return subtitle; }
    public void setSubtitle(String subtitle) { this.subtitle = subtitle; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public String getBannerType() { return bannerType; }
    public void setBannerType(String bannerType) { this.bannerType = bannerType; }

    public String getBadgeText() { return badgeText; }
    public void setBadgeText(String badgeText) { this.badgeText = badgeText; }

    public String getCtaText() { return ctaText; }
    public void setCtaText(String ctaText) { this.ctaText = ctaText; }

    public String getTargetType() { return targetType; }
    public void setTargetType(String targetType) { this.targetType = targetType; }

    public String getTargetPayload() { return targetPayload; }
    public void setTargetPayload(String targetPayload) { this.targetPayload = targetPayload; }

    public ServiceCategory getCategory() { return category; }
    public void setCategory(ServiceCategory category) { this.category = category; }

    public ServiceItem getService() { return service; }
    public void setService(ServiceItem service) { this.service = service; }

    public Integer getDisplayOrder() { return displayOrder; }
    public void setDisplayOrder(Integer displayOrder) { this.displayOrder = displayOrder; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private String title;
        private String subtitle;
        private String imageUrl;
        private String bannerType = "HERO";
        private String badgeText;
        private String ctaText = "Book Now";
        private String targetType;
        private String targetPayload;
        private ServiceCategory category;
        private ServiceItem service;
        private Integer displayOrder = 0;
        private boolean active = true;
        private Instant createdAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder title(String title) { this.title = title; return this; }
        public Builder subtitle(String subtitle) { this.subtitle = subtitle; return this; }
        public Builder imageUrl(String imageUrl) { this.imageUrl = imageUrl; return this; }
        public Builder bannerType(String bannerType) { this.bannerType = bannerType; return this; }
        public Builder badgeText(String badgeText) { this.badgeText = badgeText; return this; }
        public Builder ctaText(String ctaText) { this.ctaText = ctaText; return this; }
        public Builder targetType(String targetType) { this.targetType = targetType; return this; }
        public Builder targetPayload(String targetPayload) { this.targetPayload = targetPayload; return this; }
        public Builder category(ServiceCategory category) { this.category = category; return this; }
        public Builder service(ServiceItem service) { this.service = service; return this; }
        public Builder displayOrder(Integer displayOrder) { this.displayOrder = displayOrder; return this; }
        public Builder active(boolean active) { this.active = active; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }

        public Banner build() {
            Banner b = new Banner();
            b.id = this.id;
            b.title = this.title;
            b.subtitle = this.subtitle;
            b.imageUrl = this.imageUrl;
            b.bannerType = this.bannerType != null ? this.bannerType : "HERO";
            b.badgeText = this.badgeText;
            b.ctaText = this.ctaText != null ? this.ctaText : "Book Now";
            b.targetType = this.targetType;
            b.targetPayload = this.targetPayload;
            b.category = this.category;
            b.service = this.service;
            b.displayOrder = this.displayOrder != null ? this.displayOrder : 0;
            b.active = this.active;
            b.createdAt = this.createdAt;
            return b;
        }
    }
}
