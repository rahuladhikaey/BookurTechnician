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
@Builder
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
    @Builder.Default
    private String verificationStatus = "PENDING"; // PENDING, APPROVED, REJECTED

    @Column(name = "reviewer_notes", columnDefinition = "TEXT")
    private String reviewerNotes;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}
