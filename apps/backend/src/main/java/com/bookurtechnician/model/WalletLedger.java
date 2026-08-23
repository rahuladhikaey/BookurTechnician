package com.bookurtechnician.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "wallet_ledger")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WalletLedger {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "booking_id")
    private String bookingId;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "platform_commission", precision = 12, scale = 2)
    private BigDecimal platformCommission;

    @Column(name = "net_payout", precision = 12, scale = 2)
    private BigDecimal netPayout;

    @Column(name = "entry_type", nullable = false, length = 30)
    private String entryType; // CREDIT, DEBIT, COMMISSION, WITHDRAWAL

    @Column(length = 255)
    private String description;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (this.createdAt == null) {
            this.createdAt = LocalDateTime.now();
        }
    }
}
