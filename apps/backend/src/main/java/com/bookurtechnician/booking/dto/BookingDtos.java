package com.bookurtechnician.booking.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public class BookingDtos {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateBookingRequest {
        @NotNull(message = "Service ID is required")
        private UUID serviceId;

        @NotNull(message = "Address ID is required")
        private UUID addressId;

        @NotNull(message = "Schedule date is required")
        private LocalDate scheduleDate;

        @NotNull(message = "Schedule slot is required")
        private String scheduleSlot;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
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
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateBookingStatusRequest {
        @NotNull(message = "Status is required")
        private String status;
        private String startOtp;
        private String endOtp;
        private String cancellationReason;
    }
}
