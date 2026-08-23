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

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getRequestCode() { return requestCode; }
    public void setRequestCode(String requestCode) { this.requestCode = requestCode; }

    public TechnicianProfile getTechnician() { return technician; }
    public void setTechnician(TechnicianProfile technician) { this.technician = technician; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getDestinationUpiId() { return destinationUpiId; }
    public void setDestinationUpiId(String destinationUpiId) { this.destinationUpiId = destinationUpiId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getRazorpayxPayoutId() { return razorpayxPayoutId; }
    public void setRazorpayxPayoutId(String razorpayxPayoutId) { this.razorpayxPayoutId = razorpayxPayoutId; }

    public String getUtrNumber() { return utrNumber; }
    public void setUtrNumber(String utrNumber) { this.utrNumber = utrNumber; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getSettledAt() { return settledAt; }
    public void setSettledAt(Instant settledAt) { this.settledAt = settledAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private String requestCode;
        private TechnicianProfile technician;
        private BigDecimal amount;
        private String destinationUpiId;
        private String status = "PROCESSING";
        private String razorpayxPayoutId;
        private String utrNumber;
        private Instant createdAt;
        private Instant settledAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder requestCode(String requestCode) { this.requestCode = requestCode; return this; }
        public Builder technician(TechnicianProfile technician) { this.technician = technician; return this; }
        public Builder amount(BigDecimal amount) { this.amount = amount; return this; }
        public Builder destinationUpiId(String destinationUpiId) { this.destinationUpiId = destinationUpiId; return this; }
        public Builder status(String status) { this.status = status; return this; }
        public Builder razorpayxPayoutId(String razorpayxPayoutId) { this.razorpayxPayoutId = razorpayxPayoutId; return this; }
        public Builder utrNumber(String utrNumber) { this.utrNumber = utrNumber; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder settledAt(Instant settledAt) { this.settledAt = settledAt; return this; }

        public WithdrawalRequest build() {
            WithdrawalRequest r = new WithdrawalRequest();
            r.id = this.id;
            r.requestCode = this.requestCode;
            r.technician = this.technician;
            r.amount = this.amount;
            r.destinationUpiId = this.destinationUpiId;
            r.status = this.status != null ? this.status : "PROCESSING";
            r.razorpayxPayoutId = this.razorpayxPayoutId;
            r.utrNumber = this.utrNumber;
            r.createdAt = this.createdAt;
            r.settledAt = this.settledAt;
            return r;
        }
    }
}
