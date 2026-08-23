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

    @Column(nullable = false, length = 30)
    private String status = "REQUESTED"; // REQUESTED, CONFIRMED, ASSIGNED, ON_THE_WAY, ARRIVED, IN_PROGRESS, COMPLETED, CANCELLED

    @Column(name = "schedule_date", nullable = false)
    private LocalDate scheduleDate;

    @Column(name = "schedule_slot", nullable = false, length = 50)
    private String scheduleSlot;

    @Column(name = "base_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal basePrice;

    @Column(name = "safety_fee", nullable = false, precision = 10, scale = 2)
    private BigDecimal safetyFee = new BigDecimal("49.00");

    @Column(name = "gst_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal gstAmount = BigDecimal.ZERO;

    @Column(name = "grand_total", nullable = false, precision = 10, scale = 2)
    private BigDecimal grandTotal;

    @Column(name = "platform_commission_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal platformCommissionAmount = BigDecimal.ZERO;

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

    @Column(name = "failed_otp_attempts")
    private int failedOtpAttempts = 0;

    @Column(name = "cancellation_reason")
    private String cancellationReason;

    @Column(name = "cancelled_by", length = 30)
    private String cancelledBy;

    @Column(name = "is_force_assigned")
    private boolean isForceAssigned = false;

    @Column(name = "force_assigned_by", length = 100)
    private String forceAssignedBy;

    @Column(name = "force_assigned_at")
    private Instant forceAssignedAt;

    @Column(name = "start_otp_bypassed")
    private boolean startOtpBypassed = false;

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

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getBookingCode() { return bookingCode; }
    public void setBookingCode(String bookingCode) { this.bookingCode = bookingCode; }

    public User getCustomer() { return customer; }
    public void setCustomer(User customer) { this.customer = customer; }

    public TechnicianProfile getTechnician() { return technician; }
    public void setTechnician(TechnicianProfile technician) { this.technician = technician; }

    public CustomerAddress getAddress() { return address; }
    public void setAddress(CustomerAddress address) { this.address = address; }

    public ServiceItem getService() { return service; }
    public void setService(ServiceItem service) { this.service = service; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDate getScheduleDate() { return scheduleDate; }
    public void setScheduleDate(LocalDate scheduleDate) { this.scheduleDate = scheduleDate; }

    public String getScheduleSlot() { return scheduleSlot; }
    public void setScheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; }

    public BigDecimal getBasePrice() { return basePrice; }
    public void setBasePrice(BigDecimal basePrice) { this.basePrice = basePrice; }

    public BigDecimal getSafetyFee() { return safetyFee; }
    public void setSafetyFee(BigDecimal safetyFee) { this.safetyFee = safetyFee; }

    public BigDecimal getGstAmount() { return gstAmount; }
    public void setGstAmount(BigDecimal gstAmount) { this.gstAmount = gstAmount; }

    public BigDecimal getGrandTotal() { return grandTotal; }
    public void setGrandTotal(BigDecimal grandTotal) { this.grandTotal = grandTotal; }

    public BigDecimal getPlatformCommissionAmount() { return platformCommissionAmount; }
    public void setPlatformCommissionAmount(BigDecimal platformCommissionAmount) { this.platformCommissionAmount = platformCommissionAmount; }

    public BigDecimal getTechnicianPayoutAmount() { return technicianPayoutAmount; }
    public void setTechnicianPayoutAmount(BigDecimal technicianPayoutAmount) { this.technicianPayoutAmount = technicianPayoutAmount; }

    public String getStartServiceOtp() { return startServiceOtp; }
    public void setStartServiceOtp(String startServiceOtp) { this.startServiceOtp = startServiceOtp; }

    public Instant getStartOtpExpiresAt() { return startOtpExpiresAt; }
    public void setStartOtpExpiresAt(Instant startOtpExpiresAt) { this.startOtpExpiresAt = startOtpExpiresAt; }

    public String getEndServiceOtp() { return endServiceOtp; }
    public void setEndServiceOtp(String endServiceOtp) { this.endServiceOtp = endServiceOtp; }

    public Instant getEndOtpExpiresAt() { return endOtpExpiresAt; }
    public void setEndOtpExpiresAt(Instant endOtpExpiresAt) { this.endOtpExpiresAt = endOtpExpiresAt; }

    public int getFailedOtpAttempts() { return failedOtpAttempts; }
    public void setFailedOtpAttempts(int failedOtpAttempts) { this.failedOtpAttempts = failedOtpAttempts; }

    public String getCancellationReason() { return cancellationReason; }
    public void setCancellationReason(String cancellationReason) { this.cancellationReason = cancellationReason; }

    public String getCancelledBy() { return cancelledBy; }
    public void setCancelledBy(String cancelledBy) { this.cancelledBy = cancelledBy; }

    public boolean isForceAssigned() { return isForceAssigned; }
    public void setForceAssigned(boolean isForceAssigned) { this.isForceAssigned = isForceAssigned; }

    public String getForceAssignedBy() { return forceAssignedBy; }
    public void setForceAssignedBy(String forceAssignedBy) { this.forceAssignedBy = forceAssignedBy; }

    public Instant getForceAssignedAt() { return forceAssignedAt; }
    public void setForceAssignedAt(Instant forceAssignedAt) { this.forceAssignedAt = forceAssignedAt; }

    public boolean isStartOtpBypassed() { return startOtpBypassed; }
    public void setStartOtpBypassed(boolean startOtpBypassed) { this.startOtpBypassed = startOtpBypassed; }

    public boolean isEndOtpBypassed() { return endOtpBypassed; }
    public void setEndOtpBypassed(boolean endOtpBypassed) { this.endOtpBypassed = endOtpBypassed; }

    public String getOtpBypassedBy() { return otpBypassedBy; }
    public void setOtpBypassedBy(String otpBypassedBy) { this.otpBypassedBy = otpBypassedBy; }

    public Instant getOtpBypassedAt() { return otpBypassedAt; }
    public void setOtpBypassedAt(Instant otpBypassedAt) { this.otpBypassedAt = otpBypassedAt; }

    public String getOtpBypassReason() { return otpBypassReason; }
    public void setOtpBypassReason(String otpBypassReason) { this.otpBypassReason = otpBypassReason; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private String bookingCode;
        private User customer;
        private TechnicianProfile technician;
        private CustomerAddress address;
        private ServiceItem service;
        private String status = "REQUESTED";
        private LocalDate scheduleDate;
        private String scheduleSlot;
        private BigDecimal basePrice;
        private BigDecimal safetyFee = new BigDecimal("49.00");
        private BigDecimal gstAmount = BigDecimal.ZERO;
        private BigDecimal grandTotal;
        private BigDecimal platformCommissionAmount = BigDecimal.ZERO;
        private BigDecimal technicianPayoutAmount = BigDecimal.ZERO;
        private String startServiceOtp;
        private Instant startOtpExpiresAt;
        private String endServiceOtp;
        private Instant endOtpExpiresAt;
        private int failedOtpAttempts = 0;
        private String cancellationReason;
        private String cancelledBy;
        private boolean isForceAssigned = false;
        private String forceAssignedBy;
        private Instant forceAssignedAt;
        private boolean startOtpBypassed = false;
        private boolean endOtpBypassed = false;
        private String otpBypassedBy;
        private Instant otpBypassedAt;
        private String otpBypassReason;
        private Instant createdAt;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder bookingCode(String bookingCode) { this.bookingCode = bookingCode; return this; }
        public Builder customer(User customer) { this.customer = customer; return this; }
        public Builder technician(TechnicianProfile technician) { this.technician = technician; return this; }
        public Builder address(CustomerAddress address) { this.address = address; return this; }
        public Builder service(ServiceItem service) { this.service = service; return this; }
        public Builder status(String status) { this.status = status; return this; }
        public Builder scheduleDate(LocalDate scheduleDate) { this.scheduleDate = scheduleDate; return this; }
        public Builder scheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; return this; }
        public Builder basePrice(BigDecimal basePrice) { this.basePrice = basePrice; return this; }
        public Builder safetyFee(BigDecimal safetyFee) { this.safetyFee = safetyFee; return this; }
        public Builder gstAmount(BigDecimal gstAmount) { this.gstAmount = gstAmount; return this; }
        public Builder grandTotal(BigDecimal grandTotal) { this.grandTotal = grandTotal; return this; }
        public Builder platformCommissionAmount(BigDecimal platformCommissionAmount) { this.platformCommissionAmount = platformCommissionAmount; return this; }
        public Builder technicianPayoutAmount(BigDecimal technicianPayoutAmount) { this.technicianPayoutAmount = technicianPayoutAmount; return this; }
        public Builder startServiceOtp(String startServiceOtp) { this.startServiceOtp = startServiceOtp; return this; }
        public Builder startOtpExpiresAt(Instant startOtpExpiresAt) { this.startOtpExpiresAt = startOtpExpiresAt; return this; }
        public Builder endServiceOtp(String endServiceOtp) { this.endServiceOtp = endServiceOtp; return this; }
        public Builder endOtpExpiresAt(Instant endOtpExpiresAt) { this.endOtpExpiresAt = endOtpExpiresAt; return this; }
        public Builder failedOtpAttempts(int failedOtpAttempts) { this.failedOtpAttempts = failedOtpAttempts; return this; }
        public Builder cancellationReason(String cancellationReason) { this.cancellationReason = cancellationReason; return this; }
        public Builder cancelledBy(String cancelledBy) { this.cancelledBy = cancelledBy; return this; }
        public Builder isForceAssigned(boolean isForceAssigned) { this.isForceAssigned = isForceAssigned; return this; }
        public Builder forceAssignedBy(String forceAssignedBy) { this.forceAssignedBy = forceAssignedBy; return this; }
        public Builder forceAssignedAt(Instant forceAssignedAt) { this.forceAssignedAt = forceAssignedAt; return this; }
        public Builder startOtpBypassed(boolean startOtpBypassed) { this.startOtpBypassed = startOtpBypassed; return this; }
        public Builder endOtpBypassed(boolean endOtpBypassed) { this.endOtpBypassed = endOtpBypassed; return this; }
        public Builder otpBypassedBy(String otpBypassedBy) { this.otpBypassedBy = otpBypassedBy; return this; }
        public Builder otpBypassedAt(Instant otpBypassedAt) { this.otpBypassedAt = otpBypassedAt; return this; }
        public Builder otpBypassReason(String otpBypassReason) { this.otpBypassReason = otpBypassReason; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public Booking build() {
            Booking b = new Booking();
            b.id = this.id;
            b.bookingCode = this.bookingCode;
            b.customer = this.customer;
            b.technician = this.technician;
            b.address = this.address;
            b.service = this.service;
            b.status = this.status != null ? this.status : "REQUESTED";
            b.scheduleDate = this.scheduleDate;
            b.scheduleSlot = this.scheduleSlot;
            b.basePrice = this.basePrice;
            b.safetyFee = this.safetyFee != null ? this.safetyFee : new BigDecimal("49.00");
            b.gstAmount = this.gstAmount != null ? this.gstAmount : BigDecimal.ZERO;
            b.grandTotal = this.grandTotal;
            b.platformCommissionAmount = this.platformCommissionAmount != null ? this.platformCommissionAmount : BigDecimal.ZERO;
            b.technicianPayoutAmount = this.technicianPayoutAmount != null ? this.technicianPayoutAmount : BigDecimal.ZERO;
            b.startServiceOtp = this.startServiceOtp;
            b.startOtpExpiresAt = this.startOtpExpiresAt;
            b.endServiceOtp = this.endServiceOtp;
            b.endOtpExpiresAt = this.endOtpExpiresAt;
            b.failedOtpAttempts = this.failedOtpAttempts;
            b.cancellationReason = this.cancellationReason;
            b.cancelledBy = this.cancelledBy;
            b.isForceAssigned = this.isForceAssigned;
            b.forceAssignedBy = this.forceAssignedBy;
            b.forceAssignedAt = this.forceAssignedAt;
            b.startOtpBypassed = this.startOtpBypassed;
            b.endOtpBypassed = this.endOtpBypassed;
            b.otpBypassedBy = this.otpBypassedBy;
            b.otpBypassedAt = this.otpBypassedAt;
            b.otpBypassReason = this.otpBypassReason;
            b.createdAt = this.createdAt;
            b.updatedAt = this.updatedAt;
            return b;
        }
    }
}
