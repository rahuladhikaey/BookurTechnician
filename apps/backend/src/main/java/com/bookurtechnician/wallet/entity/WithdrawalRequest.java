package com.bookurtechnician.wallet.entity;

import com.bookurtechnician.technician.entity.TechnicianProfile;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "withdrawal_requests")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WithdrawalRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "request_code", unique = true, nullable = false, length = 50)
    private String requestCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false)
    private TechnicianProfile technician;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "destination_upi_id", nullable = false, length = 100)
    private String destinationUpiId;

    @Builder.Default
    @Column(length = 30)
    private String status = "PROCESSING"; // PROCESSING, SETTLED, REJECTED

    @Column(name = "razorpayx_payout_id", length = 100)
    private String razorpayxPayoutId;

    @Column(name = "utr_number", length = 100)
    private String utrNumber;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @Column(name = "settled_at")
    private Instant settledAt;
}
