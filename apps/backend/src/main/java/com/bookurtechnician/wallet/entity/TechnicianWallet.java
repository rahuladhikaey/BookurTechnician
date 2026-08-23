package com.bookurtechnician.wallet.entity;

import com.bookurtechnician.technician.entity.TechnicianProfile;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "technician_wallets")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TechnicianWallet {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false, unique = true)
    private TechnicianProfile technician;

    @Column(name = "available_balance", nullable = false, precision = 10, scale = 2)
    private BigDecimal availableBalance = BigDecimal.ZERO;

    @Column(name = "total_withdrawn", nullable = false, precision = 10, scale = 2)
    private BigDecimal totalWithdrawn = BigDecimal.ZERO;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public TechnicianProfile getTechnician() { return technician; }
    public void setTechnician(TechnicianProfile technician) { this.technician = technician; }

    public BigDecimal getAvailableBalance() { return availableBalance; }
    public void setAvailableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; }

    public BigDecimal getTotalWithdrawn() { return totalWithdrawn; }
    public void setTotalWithdrawn(BigDecimal totalWithdrawn) { this.totalWithdrawn = totalWithdrawn; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private TechnicianProfile technician;
        private BigDecimal availableBalance = BigDecimal.ZERO;
        private BigDecimal totalWithdrawn = BigDecimal.ZERO;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder technician(TechnicianProfile technician) { this.technician = technician; return this; }
        public Builder availableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; return this; }
        public Builder totalWithdrawn(BigDecimal totalWithdrawn) { this.totalWithdrawn = totalWithdrawn; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public TechnicianWallet build() {
            TechnicianWallet w = new TechnicianWallet();
            w.id = this.id;
            w.technician = this.technician;
            w.availableBalance = this.availableBalance != null ? this.availableBalance : BigDecimal.ZERO;
            w.totalWithdrawn = this.totalWithdrawn != null ? this.totalWithdrawn : BigDecimal.ZERO;
            w.updatedAt = this.updatedAt;
            return w;
        }
    }
}
