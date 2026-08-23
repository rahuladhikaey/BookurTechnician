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

    @Column(name = "experience_years")
    private int experienceYears = 1;

    @Column(name = "verification_status", length = 30)
    private String verificationStatus = "PENDING"; // PENDING, VERIFIED, REJECTED

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

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public TechnicianProfile getTechnician() { return technician; }
    public void setTechnician(TechnicianProfile technician) { this.technician = technician; }

    public ServiceSkill getSkill() { return skill; }
    public void setSkill(ServiceSkill skill) { this.skill = skill; }

    public int getExperienceYears() { return experienceYears; }
    public void setExperienceYears(int experienceYears) { this.experienceYears = experienceYears; }

    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }

    public String getCertificateUrl() { return certificateUrl; }
    public void setCertificateUrl(String certificateUrl) { this.certificateUrl = certificateUrl; }

    public String getRejectionReason() { return rejectionReason; }
    public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }

    public Instant getVerifiedAt() { return verifiedAt; }
    public void setVerifiedAt(Instant verifiedAt) { this.verifiedAt = verifiedAt; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private TechnicianProfile technician;
        private ServiceSkill skill;
        private int experienceYears = 1;
        private String verificationStatus = "PENDING";
        private boolean enabled = true;
        private String certificateUrl;
        private String rejectionReason;
        private Instant verifiedAt;
        private Instant createdAt;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder technician(TechnicianProfile technician) { this.technician = technician; return this; }
        public Builder skill(ServiceSkill skill) { this.skill = skill; return this; }
        public Builder experienceYears(int experienceYears) { this.experienceYears = experienceYears; return this; }
        public Builder verificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; return this; }
        public Builder enabled(boolean enabled) { this.enabled = enabled; return this; }
        public Builder certificateUrl(String certificateUrl) { this.certificateUrl = certificateUrl; return this; }
        public Builder rejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; return this; }
        public Builder verifiedAt(Instant verifiedAt) { this.verifiedAt = verifiedAt; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public TechnicianSkill build() {
            TechnicianSkill ts = new TechnicianSkill();
            ts.id = this.id;
            ts.technician = this.technician;
            ts.skill = this.skill;
            ts.experienceYears = this.experienceYears;
            ts.verificationStatus = this.verificationStatus != null ? this.verificationStatus : "PENDING";
            ts.enabled = this.enabled;
            ts.certificateUrl = this.certificateUrl;
            ts.rejectionReason = this.rejectionReason;
            ts.verifiedAt = this.verifiedAt;
            ts.createdAt = this.createdAt;
            ts.updatedAt = this.updatedAt;
            return ts;
        }
    }
}
