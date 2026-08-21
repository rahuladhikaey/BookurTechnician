package com.bookurtechnician.servicecatalog.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "service_categories")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ServiceCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, unique = true, length = 100)
    private String slug;

    @Column(name = "icon_url")
    private String iconUrl;

    @Column(name = "banner_url")
    private String bannerUrl;

    @Builder.Default
    @Column(name = "display_order")
    private int displayOrder = 0;

    @Builder.Default
    @Column(name = "is_active")
    private boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    public String getImageUrl() {
        return iconUrl != null && !iconUrl.isBlank() ? iconUrl : bannerUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.iconUrl = imageUrl;
        this.bannerUrl = imageUrl;
    }
}
