package com.bookurtechnician.wallet.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "wallet_ledger")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class WalletLedger {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wallet_id", nullable = false)
    private TechnicianWallet wallet;

    @Column(name = "entry_type", nullable = false, length = 20)
    private String entryType; // CREDIT, DEBIT

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "balance_before", nullable = false, precision = 10, scale = 2)
    private BigDecimal balanceBefore;

    @Column(name = "balance_after", nullable = false, precision = 10, scale = 2)
    private BigDecimal balanceAfter;

    @Column(name = "reference_type", nullable = false, length = 50)
    private String referenceType; // BOOKING_EARNING, INCENTIVE_BONUS, UPI_WITHDRAWAL, ADMIN_ADJUSTMENT

    @Column(name = "reference_id", nullable = false, length = 100)
    private String referenceId;

    private String description;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public TechnicianWallet getWallet() { return wallet; }
    public void setWallet(TechnicianWallet wallet) { this.wallet = wallet; }

    public String getEntryType() { return entryType; }
    public void setEntryType(String entryType) { this.entryType = entryType; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public BigDecimal getBalanceBefore() { return balanceBefore; }
    public void setBalanceBefore(BigDecimal balanceBefore) { this.balanceBefore = balanceBefore; }

    public BigDecimal getBalanceAfter() { return balanceAfter; }
    public void setBalanceAfter(BigDecimal balanceAfter) { this.balanceAfter = balanceAfter; }

    public String getReferenceType() { return referenceType; }
    public void setReferenceType(String referenceType) { this.referenceType = referenceType; }

    public String getReferenceId() { return referenceId; }
    public void setReferenceId(String referenceId) { this.referenceId = referenceId; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private TechnicianWallet wallet;
        private String entryType;
        private BigDecimal amount;
        private BigDecimal balanceBefore;
        private BigDecimal balanceAfter;
        private String referenceType;
        private String referenceId;
        private String description;
        private Instant createdAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder wallet(TechnicianWallet wallet) { this.wallet = wallet; return this; }
        public Builder entryType(String entryType) { this.entryType = entryType; return this; }
        public Builder amount(BigDecimal amount) { this.amount = amount; return this; }
        public Builder balanceBefore(BigDecimal balanceBefore) { this.balanceBefore = balanceBefore; return this; }
        public Builder balanceAfter(BigDecimal balanceAfter) { this.balanceAfter = balanceAfter; return this; }
        public Builder referenceType(String referenceType) { this.referenceType = referenceType; return this; }
        public Builder referenceId(String referenceId) { this.referenceId = referenceId; return this; }
        public Builder description(String description) { this.description = description; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }

        public WalletLedger build() {
            WalletLedger wl = new WalletLedger();
            wl.id = this.id;
            wl.wallet = this.wallet;
            wl.entryType = this.entryType;
            wl.amount = this.amount;
            wl.balanceBefore = this.balanceBefore;
            wl.balanceAfter = this.balanceAfter;
            wl.referenceType = this.referenceType;
            wl.referenceId = this.referenceId;
            wl.description = this.description;
            wl.createdAt = this.createdAt;
            return wl;
        }
    }
}
