package com.bookurtechnician.payment.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.payment.dto.PaymentDtos;
import com.bookurtechnician.payment.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping("/create-order")
    public ResponseEntity<ApiResponse<PaymentDtos.CreateOrderResponse>> createOrder(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody PaymentDtos.CreateOrderRequest request) {
        PaymentDtos.CreateOrderResponse response = paymentService.createOrder(principal.getId(), request.getBookingId());
        return ResponseEntity.ok(ApiResponse.success(response, "Payment order created successfully"));
    }

    @PostMapping("/verify-signature")
    public ResponseEntity<ApiResponse<PaymentDtos.PaymentVerificationResponse>> verifySignature(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody PaymentDtos.VerifySignatureRequest request) {
        PaymentDtos.PaymentVerificationResponse response = paymentService.verifySignature(principal.getId(), request);
        return ResponseEntity.ok(ApiResponse.success(response, "Payment verified successfully"));
    }

    @PostMapping("/webhook")
    public ResponseEntity<String> handleWebhook(
            @RequestBody String payload,
            @RequestHeader(value = "X-Razorpay-Signature", required = false) String signature) {
        paymentService.processWebhook(payload, signature);
        return ResponseEntity.ok("Webhook processed");
    }
}
