package com.bookurtechnician.technician.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "technician_documents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TechnicianDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false)
    private TechnicianProfile technician;

    @Column(name = "document_type", nullable = false, length = 50)
    private String documentType; // AADHAAR_FRONT, AADHAAR_BACK, PAN_CARD, POLICE_VERIFICATION, SELFIE

    @Column(name = "secure_cloudinary_url", nullable = false, columnDefinition = "TEXT")
    private String secureCloudinaryUrl;

    @Column(name = "masked_number", length = 50)
    private String maskedNumber;

    @Column(name = "verification_status", length = 30)
    private String verificationStatus = "PENDING"; // PENDING, APPROVED, REJECTED

    @Column(name = "reviewer_notes", columnDefinition = "TEXT")
    private String reviewerNotes;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public TechnicianProfile getTechnician() { return technician; }
    public void setTechnician(TechnicianProfile technician) { this.technician = technician; }

    public String getDocumentType() { return documentType; }
    public void setDocumentType(String documentType) { this.documentType = documentType; }

    public String getSecureCloudinaryUrl() { return secureCloudinaryUrl; }
    public void setSecureCloudinaryUrl(String secureCloudinaryUrl) { this.secureCloudinaryUrl = secureCloudinaryUrl; }

    public String getMaskedNumber() { return maskedNumber; }
    public void setMaskedNumber(String maskedNumber) { this.maskedNumber = maskedNumber; }

    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }

    public String getReviewerNotes() { return reviewerNotes; }
    public void setReviewerNotes(String reviewerNotes) { this.reviewerNotes = reviewerNotes; }

    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private TechnicianProfile technician;
        private String documentType;
        private String secureCloudinaryUrl;
        private String maskedNumber;
        private String verificationStatus = "PENDING";
        private String reviewerNotes;
        private Instant reviewedAt;
        private Instant createdAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder technician(TechnicianProfile technician) { this.technician = technician; return this; }
        public Builder documentType(String documentType) { this.documentType = documentType; return this; }
        public Builder secureCloudinaryUrl(String secureCloudinaryUrl) { this.secureCloudinaryUrl = secureCloudinaryUrl; return this; }
        public Builder maskedNumber(String maskedNumber) { this.maskedNumber = maskedNumber; return this; }
        public Builder verificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; return this; }
        public Builder reviewerNotes(String reviewerNotes) { this.reviewerNotes = reviewerNotes; return this; }
        public Builder reviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }

        public TechnicianDocument build() {
            TechnicianDocument d = new TechnicianDocument();
            d.id = this.id;
            d.technician = this.technician;
            d.documentType = this.documentType;
            d.secureCloudinaryUrl = this.secureCloudinaryUrl;
            d.maskedNumber = this.maskedNumber;
            d.verificationStatus = this.verificationStatus != null ? this.verificationStatus : "PENDING";
            d.reviewerNotes = this.reviewerNotes;
            d.reviewedAt = this.reviewedAt;
            d.createdAt = this.createdAt;
            return d;
        }
    }
}
