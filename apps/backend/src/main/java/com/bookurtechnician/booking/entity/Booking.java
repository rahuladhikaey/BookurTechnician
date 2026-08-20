package com.bookurtechnician.booking.entity;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.customer.entity.CustomerAddress;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "bookings")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Booking {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "booking_code", unique = true, nullable = false, length = 30)
    private String bookingCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id")
    private TechnicianProfile technician;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "address_id", nullable = false)
    private CustomerAddress address;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_id", nullable = false)
    private ServiceItem service;

    @Builder.Default
    @Column(nullable = false, length = 30)
    private String status = "REQUESTED"; // REQUESTED, CONFIRMED, ASSIGNED, ON_THE_WAY, ARRIVED, IN_PROGRESS, COMPLETED, CANCELLED

    @Column(name = "schedule_date", nullable = false)
    private LocalDate scheduleDate;

    @Column(name = "schedule_slot", nullable = false, length = 50)
    private String scheduleSlot;

    @Column(name = "base_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal basePrice;

    @Builder.Default
    @Column(name = "safety_fee", nullable = false, precision = 10, scale = 2)
    private BigDecimal safetyFee = new BigDecimal("49.00");

    @Builder.Default
    @Column(name = "gst_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal gstAmount = BigDecimal.ZERO;

    @Column(name = "grand_total", nullable = false, precision = 10, scale = 2)
    private BigDecimal grandTotal;

    @Builder.Default
    @Column(name = "platform_commission_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal platformCommissionAmount = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "technician_payout_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal technicianPayoutAmount = BigDecimal.ZERO;

    @Column(name = "start_service_otp", length = 6)
    private String startServiceOtp;

    @Column(name = "start_otp_expires_at")
    private Instant startOtpExpiresAt;

    @Column(name = "end_service_otp", length = 6)
    private String endServiceOtp;

    @Column(name = "end_otp_expires_at")
    private Instant endOtpExpiresAt;

    @Builder.Default
    @Column(name = "failed_otp_attempts")
    private int failedOtpAttempts = 0;

    @Column(name = "cancellation_reason")
    private String cancellationReason;

    @Column(name = "cancelled_by", length = 30)
    private String cancelledBy;

    @Builder.Default
    @Column(name = "is_force_assigned")
    private boolean isForceAssigned = false;

    @Column(name = "force_assigned_by", length = 100)
    private String forceAssignedBy;

    @Column(name = "force_assigned_at")
    private Instant forceAssignedAt;

    @Builder.Default
    @Column(name = "start_otp_bypassed")
    private boolean startOtpBypassed = false;

    @Builder.Default
    @Column(name = "end_otp_bypassed")
    private boolean endOtpBypassed = false;

    @Column(name = "otp_bypassed_by", length = 100)
    private String otpBypassedBy;

    @Column(name = "otp_bypassed_at")
    private Instant otpBypassedAt;

    @Column(name = "otp_bypass_reason")
    private String otpBypassReason;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
