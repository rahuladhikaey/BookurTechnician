package com.bookurtechnician.payment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

public class PaymentDtos {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateOrderRequest {
        @NotNull(message = "Booking ID is required")
        private UUID bookingId;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateOrderResponse {
        private String razorpayOrderId;
        private BigDecimal amount;
        private String currency;
        private String bookingCode;
        private String keyId;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VerifySignatureRequest {
        @NotNull(message = "Booking ID is required")
        private UUID bookingId;

        @NotBlank(message = "Razorpay Order ID is required")
        private String razorpayOrderId;

        @NotBlank(message = "Razorpay Payment ID is required")
        private String razorpayPaymentId;

        @NotBlank(message = "Razorpay Signature is required")
        private String razorpaySignature;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PaymentVerificationResponse {
        private boolean success;
        private String message;
        private String bookingCode;
        private String status;
    }
}
