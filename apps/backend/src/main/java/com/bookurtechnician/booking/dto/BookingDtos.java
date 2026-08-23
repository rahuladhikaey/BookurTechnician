package com.bookurtechnician.booking.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public class BookingDtos {

    public static class CreateBookingRequest {
        @NotNull(message = "Service ID is required")
        private UUID serviceId;

        @NotNull(message = "Address ID is required")
        private UUID addressId;

        @NotNull(message = "Schedule date is required")
        private LocalDate scheduleDate;

        @NotNull(message = "Schedule slot is required")
        private String scheduleSlot;

        public CreateBookingRequest() {}

        public UUID getServiceId() { return serviceId; }
        public void setServiceId(UUID serviceId) { this.serviceId = serviceId; }

        public UUID getAddressId() { return addressId; }
        public void setAddressId(UUID addressId) { this.addressId = addressId; }

        public LocalDate getScheduleDate() { return scheduleDate; }
        public void setScheduleDate(LocalDate scheduleDate) { this.scheduleDate = scheduleDate; }

        public String getScheduleSlot() { return scheduleSlot; }
        public void setScheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; }
    }

    public static class BookingResponse {
        private UUID id;
        private String bookingCode;
        private String serviceName;
        private String status;
        private LocalDate scheduleDate;
        private String scheduleSlot;
        private BigDecimal grandTotal;
        private String startServiceOtp;
        private Instant startOtpExpiresAt;
        private Instant endOtpExpiresAt;
        private String technicianName;
        private String technicianPhone;
        private String technicianCode;
        private Double technicianLatitude;
        private Double technicianLongitude;
        private Double customerLatitude;
        private Double customerLongitude;
        private Double distanceKm;
        private String fullAddress;

        public BookingResponse() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private String bookingCode;
            private String serviceName;
            private String status;
            private LocalDate scheduleDate;
            private String scheduleSlot;
            private BigDecimal grandTotal;
            private String startServiceOtp;
            private Instant startOtpExpiresAt;
            private Instant endOtpExpiresAt;
            private String technicianName;
            private String technicianPhone;
            private String technicianCode;
            private Double technicianLatitude;
            private Double technicianLongitude;
            private Double customerLatitude;
            private Double customerLongitude;
            private Double distanceKm;
            private String fullAddress;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder bookingCode(String bookingCode) { this.bookingCode = bookingCode; return this; }
            public Builder serviceName(String serviceName) { this.serviceName = serviceName; return this; }
            public Builder status(String status) { this.status = status; return this; }
            public Builder scheduleDate(LocalDate scheduleDate) { this.scheduleDate = scheduleDate; return this; }
            public Builder scheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; return this; }
            public Builder grandTotal(BigDecimal grandTotal) { this.grandTotal = grandTotal; return this; }
            public Builder startServiceOtp(String startServiceOtp) { this.startServiceOtp = startServiceOtp; return this; }
            public Builder startOtpExpiresAt(Instant startOtpExpiresAt) { this.startOtpExpiresAt = startOtpExpiresAt; return this; }
            public Builder endOtpExpiresAt(Instant endOtpExpiresAt) { this.endOtpExpiresAt = endOtpExpiresAt; return this; }
            public Builder technicianName(String technicianName) { this.technicianName = technicianName; return this; }
            public Builder technicianPhone(String technicianPhone) { this.technicianPhone = technicianPhone; return this; }
            public Builder technicianCode(String technicianCode) { this.technicianCode = technicianCode; return this; }
            public Builder technicianLatitude(Double technicianLatitude) { this.technicianLatitude = technicianLatitude; return this; }
            public Builder technicianLongitude(Double technicianLongitude) { this.technicianLongitude = technicianLongitude; return this; }
            public Builder customerLatitude(Double customerLatitude) { this.customerLatitude = customerLatitude; return this; }
            public Builder customerLongitude(Double customerLongitude) { this.customerLongitude = customerLongitude; return this; }
            public Builder distanceKm(Double distanceKm) { this.distanceKm = distanceKm; return this; }
            public Builder fullAddress(String fullAddress) { this.fullAddress = fullAddress; return this; }

            public BookingResponse build() {
                BookingResponse res = new BookingResponse();
                res.id = this.id;
                res.bookingCode = this.bookingCode;
                res.serviceName = this.serviceName;
                res.status = this.status;
                res.scheduleDate = this.scheduleDate;
                res.scheduleSlot = this.scheduleSlot;
                res.grandTotal = this.grandTotal;
                res.startServiceOtp = this.startServiceOtp;
                res.startOtpExpiresAt = this.startOtpExpiresAt;
                res.endOtpExpiresAt = this.endOtpExpiresAt;
                res.technicianName = this.technicianName;
                res.technicianPhone = this.technicianPhone;
                res.technicianCode = this.technicianCode;
                res.technicianLatitude = this.technicianLatitude;
                res.technicianLongitude = this.technicianLongitude;
                res.customerLatitude = this.customerLatitude;
                res.customerLongitude = this.customerLongitude;
                res.distanceKm = this.distanceKm;
                res.fullAddress = this.fullAddress;
                return res;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public String getBookingCode() { return bookingCode; }
        public void setBookingCode(String bookingCode) { this.bookingCode = bookingCode; }
        public String getServiceName() { return serviceName; }
        public void setServiceName(String serviceName) { this.serviceName = serviceName; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public LocalDate getScheduleDate() { return scheduleDate; }
        public void setScheduleDate(LocalDate scheduleDate) { this.scheduleDate = scheduleDate; }
        public String getScheduleSlot() { return scheduleSlot; }
        public void setScheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; }
        public BigDecimal getGrandTotal() { return grandTotal; }
        public void setGrandTotal(BigDecimal grandTotal) { this.grandTotal = grandTotal; }
        public String getStartServiceOtp() { return startServiceOtp; }
        public void setStartServiceOtp(String startServiceOtp) { this.startServiceOtp = startServiceOtp; }
        public Instant getStartOtpExpiresAt() { return startOtpExpiresAt; }
        public void setStartOtpExpiresAt(Instant startOtpExpiresAt) { this.startOtpExpiresAt = startOtpExpiresAt; }
        public Instant getEndOtpExpiresAt() { return endOtpExpiresAt; }
        public void setEndOtpExpiresAt(Instant endOtpExpiresAt) { this.endOtpExpiresAt = endOtpExpiresAt; }
        public String getTechnicianName() { return technicianName; }
        public void setTechnicianName(String technicianName) { this.technicianName = technicianName; }
        public String getTechnicianPhone() { return technicianPhone; }
        public void setTechnicianPhone(String technicianPhone) { this.technicianPhone = technicianPhone; }
        public String getTechnicianCode() { return technicianCode; }
        public void setTechnicianCode(String technicianCode) { this.technicianCode = technicianCode; }
        public Double getTechnicianLatitude() { return technicianLatitude; }
        public void setTechnicianLatitude(Double technicianLatitude) { this.technicianLatitude = technicianLatitude; }
        public Double getTechnicianLongitude() { return technicianLongitude; }
        public void setTechnicianLongitude(Double technicianLongitude) { this.technicianLongitude = technicianLongitude; }
        public Double getCustomerLatitude() { return customerLatitude; }
        public void setCustomerLatitude(Double customerLatitude) { this.customerLatitude = customerLatitude; }
        public Double getCustomerLongitude() { return customerLongitude; }
        public void setCustomerLongitude(Double customerLongitude) { this.customerLongitude = customerLongitude; }
        public Double getDistanceKm() { return distanceKm; }
        public void setDistanceKm(Double distanceKm) { this.distanceKm = distanceKm; }
        public String getFullAddress() { return fullAddress; }
        public void setFullAddress(String fullAddress) { this.fullAddress = fullAddress; }
    }

    public static class UpdateBookingStatusRequest {
        @NotNull(message = "Status is required")
        private String status;
        private String startOtp;
        private String endOtp;
        private String cancellationReason;

        public UpdateBookingStatusRequest() {}

        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public String getStartOtp() { return startOtp; }
        public void setStartOtp(String startOtp) { this.startOtp = startOtp; }
        public String getEndOtp() { return endOtp; }
        public void setEndOtp(String endOtp) { this.endOtp = endOtp; }
        public String getCancellationReason() { return cancellationReason; }
        public void setCancellationReason(String cancellationReason) { this.cancellationReason = cancellationReason; }
    }
}
