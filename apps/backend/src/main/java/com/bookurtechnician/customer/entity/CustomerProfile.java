package com.bookurtechnician.customer.entity;

import com.bookurtechnician.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "customer_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CustomerProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "anniversary_date")
    private LocalDate anniversaryDate;

    private String gender;

    @Column(name = "profile_completion_percentage")
    private int profileCompletionPercentage = 25;

    @Column(name = "compliance_status", length = 30)
    private String complianceStatus = "INCOMPLETE";

    @Column(name = "has_valid_name")
    private boolean hasValidName = false;

    @Column(name = "has_verified_phone")
    private boolean hasVerifiedPhone = true;

    @Column(name = "has_verified_email")
    private boolean hasVerifiedEmail = false;

    @Column(name = "has_service_address")
    private boolean hasServiceAddress = false;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public LocalDate getDateOfBirth() { return dateOfBirth; }
    public void setDateOfBirth(LocalDate dateOfBirth) { this.dateOfBirth = dateOfBirth; }

    public LocalDate getAnniversaryDate() { return anniversaryDate; }
    public void setAnniversaryDate(LocalDate anniversaryDate) { this.anniversaryDate = anniversaryDate; }

    public String getGender() { return gender; }
    public void setGender(String gender) { this.gender = gender; }

    public int getProfileCompletionPercentage() { return profileCompletionPercentage; }
    public void setProfileCompletionPercentage(int profileCompletionPercentage) { this.profileCompletionPercentage = profileCompletionPercentage; }

    public String getComplianceStatus() { return complianceStatus; }
    public void setComplianceStatus(String complianceStatus) { this.complianceStatus = complianceStatus; }

    public boolean isHasValidName() { return hasValidName; }
    public void setHasValidName(boolean hasValidName) { this.hasValidName = hasValidName; }

    public boolean isHasVerifiedPhone() { return hasVerifiedPhone; }
    public void setHasVerifiedPhone(boolean hasVerifiedPhone) { this.hasVerifiedPhone = hasVerifiedPhone; }

    public boolean isHasVerifiedEmail() { return hasVerifiedEmail; }
    public void setHasVerifiedEmail(boolean hasVerifiedEmail) { this.hasVerifiedEmail = hasVerifiedEmail; }

    public boolean isHasServiceAddress() { return hasServiceAddress; }
    public void setHasServiceAddress(boolean hasServiceAddress) { this.hasServiceAddress = hasServiceAddress; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public void recalculateScore() {
        int score = 0;
        if (hasValidName) score += 25;
        if (hasVerifiedPhone) score += 25;
        if (hasVerifiedEmail) score += 25;
        if (hasServiceAddress) score += 25;

        this.profileCompletionPercentage = score;
        if (score == 100) {
            this.complianceStatus = "COMPLETE";
        } else if (score >= 50) {
            this.complianceStatus = "PARTIALLY_COMPLETE";
        } else {
            this.complianceStatus = "INCOMPLETE";
        }
    }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private User user;
        private LocalDate dateOfBirth;
        private LocalDate anniversaryDate;
        private String gender;
        private int profileCompletionPercentage = 25;
        private String complianceStatus = "INCOMPLETE";
        private boolean hasValidName = false;
        private boolean hasVerifiedPhone = true;
        private boolean hasVerifiedEmail = false;
        private boolean hasServiceAddress = false;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder user(User user) { this.user = user; return this; }
        public Builder dateOfBirth(LocalDate dateOfBirth) { this.dateOfBirth = dateOfBirth; return this; }
        public Builder anniversaryDate(LocalDate anniversaryDate) { this.anniversaryDate = anniversaryDate; return this; }
        public Builder gender(String gender) { this.gender = gender; return this; }
        public Builder profileCompletionPercentage(int profileCompletionPercentage) { this.profileCompletionPercentage = profileCompletionPercentage; return this; }
        public Builder complianceStatus(String complianceStatus) { this.complianceStatus = complianceStatus; return this; }
        public Builder hasValidName(boolean hasValidName) { this.hasValidName = hasValidName; return this; }
        public Builder hasVerifiedPhone(boolean hasVerifiedPhone) { this.hasVerifiedPhone = hasVerifiedPhone; return this; }
        public Builder hasVerifiedEmail(boolean hasVerifiedEmail) { this.hasVerifiedEmail = hasVerifiedEmail; return this; }
        public Builder hasServiceAddress(boolean hasServiceAddress) { this.hasServiceAddress = hasServiceAddress; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public CustomerProfile build() {
            CustomerProfile cp = new CustomerProfile();
            cp.id = this.id;
            cp.user = this.user;
            cp.dateOfBirth = this.dateOfBirth;
            cp.anniversaryDate = this.anniversaryDate;
            cp.gender = this.gender;
            cp.profileCompletionPercentage = this.profileCompletionPercentage;
            cp.complianceStatus = this.complianceStatus;
            cp.hasValidName = this.hasValidName;
            cp.hasVerifiedPhone = this.hasVerifiedPhone;
            cp.hasVerifiedEmail = this.hasVerifiedEmail;
            cp.hasServiceAddress = this.hasServiceAddress;
            cp.updatedAt = this.updatedAt;
            return cp;
        }
    }
}
