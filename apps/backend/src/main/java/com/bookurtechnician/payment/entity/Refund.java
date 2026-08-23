package com.bookurtechnician.payment.entity;

import com.bookurtechnician.booking.entity.Booking;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "refunds")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Refund {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "refund_code", unique = true, nullable = false, length = 50)
    private String refundCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    @Column(name = "requested_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal requestedAmount;

    @Column(name = "non_refundable_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal nonRefundableAmount = new BigDecimal("49.00");

    @Column(name = "refundable_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal refundableAmount;

    @Column(nullable = false, length = 30)
    private String status = "INITIATED"; // INITIATED, PROCESSING, SETTLED, FAILED

    @Column(name = "razorpay_refund_id", length = 100)
    private String razorpayRefundId;

    @Column(name = "cancellation_time", nullable = false)
    private Instant cancellationTime;

    private String reason;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @Column(name = "settled_at")
    private Instant settledAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getRefundCode() { return refundCode; }
    public void setRefundCode(String refundCode) { this.refundCode = refundCode; }

    public Booking getBooking() { return booking; }
    public void setBooking(Booking booking) { this.booking = booking; }

    public Payment getPayment() { return payment; }
    public void setPayment(Payment payment) { this.payment = payment; }

    public BigDecimal getRequestedAmount() { return requestedAmount; }
    public void setRequestedAmount(BigDecimal requestedAmount) { this.requestedAmount = requestedAmount; }

    public BigDecimal getNonRefundableAmount() { return nonRefundableAmount; }
    public void setNonRefundableAmount(BigDecimal nonRefundableAmount) { this.nonRefundableAmount = nonRefundableAmount; }

    public BigDecimal getRefundableAmount() { return refundableAmount; }
    public void setRefundableAmount(BigDecimal refundableAmount) { this.refundableAmount = refundableAmount; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getRazorpayRefundId() { return razorpayRefundId; }
    public void setRazorpayRefundId(String razorpayRefundId) { this.razorpayRefundId = razorpayRefundId; }

    public Instant getCancellationTime() { return cancellationTime; }
    public void setCancellationTime(Instant cancellationTime) { this.cancellationTime = cancellationTime; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getSettledAt() { return settledAt; }
    public void setSettledAt(Instant settledAt) { this.settledAt = settledAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private String refundCode;
        private Booking booking;
        private Payment payment;
        private BigDecimal requestedAmount;
        private BigDecimal nonRefundableAmount = new BigDecimal("49.00");
        private BigDecimal refundableAmount;
        private String status = "INITIATED";
        private String razorpayRefundId;
        private Instant cancellationTime;
        private String reason;
        private Instant createdAt;
        private Instant settledAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder refundCode(String refundCode) { this.refundCode = refundCode; return this; }
        public Builder booking(Booking booking) { this.booking = booking; return this; }
        public Builder payment(Payment payment) { this.payment = payment; return this; }
        public Builder requestedAmount(BigDecimal requestedAmount) { this.requestedAmount = requestedAmount; return this; }
        public Builder nonRefundableAmount(BigDecimal nonRefundableAmount) { this.nonRefundableAmount = nonRefundableAmount; return this; }
        public Builder refundableAmount(BigDecimal refundableAmount) { this.refundableAmount = refundableAmount; return this; }
        public Builder status(String status) { this.status = status; return this; }
        public Builder razorpayRefundId(String razorpayRefundId) { this.razorpayRefundId = razorpayRefundId; return this; }
        public Builder cancellationTime(Instant cancellationTime) { this.cancellationTime = cancellationTime; return this; }
        public Builder reason(String reason) { this.reason = reason; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder settledAt(Instant settledAt) { this.settledAt = settledAt; return this; }

        public Refund build() {
            Refund r = new Refund();
            r.id = this.id;
            r.refundCode = this.refundCode;
            r.booking = this.booking;
            r.payment = this.payment;
            r.requestedAmount = this.requestedAmount;
            r.nonRefundableAmount = this.nonRefundableAmount != null ? this.nonRefundableAmount : new BigDecimal("49.00");
            r.refundableAmount = this.refundableAmount;
            r.status = this.status != null ? this.status : "INITIATED";
            r.razorpayRefundId = this.razorpayRefundId;
            r.cancellationTime = this.cancellationTime;
            r.reason = this.reason;
            r.createdAt = this.createdAt;
            r.settledAt = this.settledAt;
            return r;
        }
    }
}
