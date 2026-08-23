package com.bookurtechnician.payment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public class PaymentDtos {

    public static class CreateOrderRequest {
        @NotNull(message = "Booking ID is required")
        private UUID bookingId;

        public CreateOrderRequest() {}
        public CreateOrderRequest(UUID bookingId) { this.bookingId = bookingId; }

        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
    }

    public static class CreateOrderResponse {
        private String razorpayOrderId;
        private BigDecimal amount;
        private String currency;
        private String bookingCode;
        private String keyId;

        public CreateOrderResponse() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private String razorpayOrderId;
            private BigDecimal amount;
            private String currency;
            private String bookingCode;
            private String keyId;

            public Builder razorpayOrderId(String razorpayOrderId) { this.razorpayOrderId = razorpayOrderId; return this; }
            public Builder amount(BigDecimal amount) { this.amount = amount; return this; }
            public Builder currency(String currency) { this.currency = currency; return this; }
            public Builder bookingCode(String bookingCode) { this.bookingCode = bookingCode; return this; }
            public Builder keyId(String keyId) { this.keyId = keyId; return this; }

            public CreateOrderResponse build() {
                CreateOrderResponse r = new CreateOrderResponse();
                r.razorpayOrderId = this.razorpayOrderId;
                r.amount = this.amount;
                r.currency = this.currency;
                r.bookingCode = this.bookingCode;
                r.keyId = this.keyId;
                return r;
            }
        }

        public String getRazorpayOrderId() { return razorpayOrderId; }
        public void setRazorpayOrderId(String razorpayOrderId) { this.razorpayOrderId = razorpayOrderId; }
        public BigDecimal getAmount() { return amount; }
        public void setAmount(BigDecimal amount) { this.amount = amount; }
        public String getCurrency() { return currency; }
        public void setCurrency(String currency) { this.currency = currency; }
        public String getBookingCode() { return bookingCode; }
        public void setBookingCode(String bookingCode) { this.bookingCode = bookingCode; }
        public String getKeyId() { return keyId; }
        public void setKeyId(String keyId) { this.keyId = keyId; }
    }

    public static class VerifySignatureRequest {
        @NotNull(message = "Booking ID is required")
        private UUID bookingId;

        @NotBlank(message = "Razorpay Order ID is required")
        private String razorpayOrderId;

        @NotBlank(message = "Razorpay Payment ID is required")
        private String razorpayPaymentId;

        @NotBlank(message = "Razorpay Signature is required")
        private String razorpaySignature;

        public VerifySignatureRequest() {}

        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
        public String getRazorpayOrderId() { return razorpayOrderId; }
        public void setRazorpayOrderId(String razorpayOrderId) { this.razorpayOrderId = razorpayOrderId; }
        public String getRazorpayPaymentId() { return razorpayPaymentId; }
        public void setRazorpayPaymentId(String razorpayPaymentId) { this.razorpayPaymentId = razorpayPaymentId; }
        public String getRazorpaySignature() { return razorpaySignature; }
        public void setRazorpaySignature(String razorpaySignature) { this.razorpaySignature = razorpaySignature; }
    }

    public static class PaymentVerificationResponse {
        private boolean success;
        private String message;
        private String bookingCode;
        private String status;

        public PaymentVerificationResponse() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private boolean success;
            private String message;
            private String bookingCode;
            private String status;

            public Builder success(boolean success) { this.success = success; return this; }
            public Builder message(String message) { this.message = message; return this; }
            public Builder bookingCode(String bookingCode) { this.bookingCode = bookingCode; return this; }
            public Builder status(String status) { this.status = status; return this; }

            public PaymentVerificationResponse build() {
                PaymentVerificationResponse res = new PaymentVerificationResponse();
                res.success = this.success;
                res.message = this.message;
                res.bookingCode = this.bookingCode;
                res.status = this.status;
                return res;
            }
        }

        public boolean isSuccess() { return success; }
        public void setSuccess(boolean success) { this.success = success; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
        public String getBookingCode() { return bookingCode; }
        public void setBookingCode(String bookingCode) { this.bookingCode = bookingCode; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
    }
}
