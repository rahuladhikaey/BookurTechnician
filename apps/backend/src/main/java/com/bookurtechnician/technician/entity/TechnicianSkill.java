package com.bookurtechnician.technician.entity;

import com.bookurtechnician.servicecatalog.entity.ServiceSkill;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "technician_skills", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"technician_id", "skill_id"})
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TechnicianSkill {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false)
    private TechnicianProfile technician;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "skill_id", nullable = false)
    private ServiceSkill skill;

    @Builder.Default
    @Column(name = "experience_years")
    private int experienceYears = 1;

    @Builder.Default
    @Column(name = "verification_status", length = 30)
    private String verificationStatus = "PENDING"; // PENDING, VERIFIED, REJECTED

    @Builder.Default
    @Column(name = "is_enabled")
    private boolean enabled = true;

    @Column(name = "certificate_url")
    private String certificateUrl;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
