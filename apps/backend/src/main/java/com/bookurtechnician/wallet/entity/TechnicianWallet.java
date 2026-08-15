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
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TechnicianWallet {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false, unique = true)
    private TechnicianProfile technician;

    @Builder.Default
    @Column(name = "available_balance", nullable = false, precision = 10, scale = 2)
    private BigDecimal availableBalance = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "total_withdrawn", nullable = false, precision = 10, scale = 2)
    private BigDecimal totalWithdrawn = BigDecimal.ZERO;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
