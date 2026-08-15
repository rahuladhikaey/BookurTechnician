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
@Builder
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

    @Builder.Default
    @Column(name = "non_refundable_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal nonRefundableAmount = new BigDecimal("49.00");

    @Column(name = "refundable_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal refundableAmount;

    @Builder.Default
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
}
