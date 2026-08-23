package com.bookurtechnician.servicecatalog.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "skill_service_compatibilities", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"skill_id", "service_item_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class SkillServiceCompatibility {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "skill_id", nullable = false)
    private ServiceSkill skill;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_item_id", nullable = false)
    private ServiceItem serviceItem;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public ServiceSkill getSkill() { return skill; }
    public void setSkill(ServiceSkill skill) { this.skill = skill; }

    public ServiceItem getServiceItem() { return serviceItem; }
    public void setServiceItem(ServiceItem serviceItem) { this.serviceItem = serviceItem; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private ServiceSkill skill;
        private ServiceItem serviceItem;
        private Instant createdAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder skill(ServiceSkill skill) { this.skill = skill; return this; }
        public Builder serviceItem(ServiceItem serviceItem) { this.serviceItem = serviceItem; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }

        public SkillServiceCompatibility build() {
            SkillServiceCompatibility c = new SkillServiceCompatibility();
            c.id = this.id;
            c.skill = this.skill;
            c.serviceItem = this.serviceItem;
            c.createdAt = this.createdAt;
            return c;
        }
    }
}
