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
@Builder
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

    @Builder.Default
    @Column(name = "profile_completion_percentage")
    private int profileCompletionPercentage = 25;

    @Builder.Default
    @Column(name = "compliance_status", length = 30)
    private String complianceStatus = "INCOMPLETE";

    @Builder.Default
    @Column(name = "has_valid_name")
    private boolean hasValidName = false;

    @Builder.Default
    @Column(name = "has_verified_phone")
    private boolean hasVerifiedPhone = true;

    @Builder.Default
    @Column(name = "has_verified_email")
    private boolean hasVerifiedEmail = false;

    @Builder.Default
    @Column(name = "has_service_address")
    private boolean hasServiceAddress = false;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

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
}
