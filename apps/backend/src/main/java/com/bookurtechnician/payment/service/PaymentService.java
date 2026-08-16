package com.bookurtechnician.payment.service;

import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.dispatch.service.DispatchService;
import com.bookurtechnician.payment.dto.PaymentDtos;
import com.bookurtechnician.payment.entity.Payment;
import com.bookurtechnician.payment.repository.PaymentRepository;
import com.razorpay.Order;
import com.razorpay.RazorpayClient;
import com.razorpay.RazorpayException;
import com.razorpay.Utils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final DispatchService dispatchService;

    @Value("${app.razorpay.key-id:}")
    private String keyId;

    @Value("${app.razorpay.key-secret:}")
    private String keySecret;

    @Value("${app.razorpay.webhook-secret:}")
    private String webhookSecret;

    @Transactional
    public PaymentDtos.CreateOrderResponse createOrder(UUID customerId, UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + bookingId));

        if (!booking.getCustomer().getId().equals(customerId)) {
            throw new BadRequestException("You are not authorized to pay for this booking.");
        }

        Payment existingPayment = paymentRepository.findByBookingId(bookingId).orElse(null);
        if (existingPayment != null && "PAID".equalsIgnoreCase(existingPayment.getStatus())) {
            throw new BadRequestException("This booking has already been paid for.");
        }

        // Amount must be strictly calculated server-side in paise (1 INR = 100 paise)
        BigDecimal amountInRupees = booking.getGrandTotal();
        long amountInPaise = amountInRupees.multiply(new BigDecimal("100")).longValue();

        String razorpayOrderId;

        if (keyId != null && !keyId.isBlank() && keySecret != null && !keySecret.isBlank()) {
            try {
                RazorpayClient client = new RazorpayClient(keyId, keySecret);
                JSONObject orderRequest = new JSONObject();
                orderRequest.put("amount", amountInPaise);
                orderRequest.put("currency", "INR");
                orderRequest.put("receipt", booking.getBookingCode());
                orderRequest.put("notes", new JSONObject().put("bookingId", booking.getId().toString()));

                Order order = client.orders.create(orderRequest);
                razorpayOrderId = order.get("id");
                log.info("Created Razorpay Order {} for booking {}", razorpayOrderId, booking.getBookingCode());
            } catch (RazorpayException e) {
                log.error("Razorpay order creation error: {}", e.getMessage(), e);
                throw new BadRequestException("Failed to initiate payment with payment gateway: " + e.getMessage());
            }
        } else {
            // If Razorpay credentials are not yet set in environment, log warning and generate deterministic pending order
            log.warn("RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET is missing. Set them in environment variables.");
            razorpayOrderId = "order_rzp_" + booking.getBookingCode();
        }

        Payment payment = existingPayment != null ? existingPayment : Payment.builder().booking(booking).build();
        payment.setRazorpayOrderId(razorpayOrderId);
        payment.setAmount(amountInRupees);
        payment.setCurrency("INR");
        payment.setStatus("PENDING");
        paymentRepository.save(payment);

        return PaymentDtos.CreateOrderResponse.builder()
                .razorpayOrderId(razorpayOrderId)
                .amount(amountInRupees)
                .currency("INR")
                .bookingCode(booking.getBookingCode())
                .keyId(keyId != null ? keyId : "")
                .build();
    }

    @Transactional
    public PaymentDtos.PaymentVerificationResponse verifySignature(UUID customerId, PaymentDtos.VerifySignatureRequest req) {
        Booking booking = bookingRepository.findById(req.getBookingId())
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found"));

        if (!booking.getCustomer().getId().equals(customerId)) {
            throw new BadRequestException("Unauthorized booking verification attempt.");
        }

        Payment payment = paymentRepository.findByRazorpayOrderId(req.getRazorpayOrderId())
                .orElseThrow(() -> new ResourceNotFoundException("Payment record not found for order: " + req.getRazorpayOrderId()));

        // Server-Side HMAC-SHA256 Signature Verification
        boolean isValid = verifyRazorpayHmac(req.getRazorpayOrderId(), req.getRazorpayPaymentId(), req.getRazorpaySignature());
        if (!isValid) {
            payment.setStatus("FAILED");
            paymentRepository.save(payment);
            throw new BadRequestException("Payment verification failed: Invalid digital signature.");
        }

        payment.setRazorpayPaymentId(req.getRazorpayPaymentId());
        payment.setRazorpaySignature(req.getRazorpaySignature());
        payment.setStatus("PAID");
        paymentRepository.save(payment);

        booking.setStatus("PAYMENT_VERIFIED");
        booking = bookingRepository.save(booking);

        log.info("Payment verified successfully for booking {}. Payment ID: {}. Starting 10-km sequential technician dispatch...", 
                booking.getBookingCode(), req.getRazorpayPaymentId());

        // Kick off 10-km PostGIS sequential dispatch engine
        dispatchService.startSequentialDispatch(booking.getId());

        return PaymentDtos.PaymentVerificationResponse.builder()
                .success(true)
                .message("Payment verified and booking confirmed successfully.")
                .bookingCode(booking.getBookingCode())
                .status("PAID")
                .build();
    }

    private boolean verifyRazorpayHmac(String orderId, String paymentId, String actualSignature) {
        if (keySecret == null || keySecret.isBlank()) {
            log.warn("RAZORPAY_KEY_SECRET is not configured. Falling back to non-empty validation.");
            return actualSignature != null && !actualSignature.isBlank();
        }

        try {
            String payload = orderId + "|" + paymentId;
            Mac sha256Hmac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKeySpec = new SecretKeySpec(keySecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            sha256Hmac.init(secretKeySpec);
            byte[] hash = sha256Hmac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString().equalsIgnoreCase(actualSignature);
        } catch (Exception e) {
            log.error("Signature verification error: {}", e.getMessage());
            return false;
        }
    }

    @Transactional
    public void processWebhook(String payload, String signature) {
        if (webhookSecret != null && !webhookSecret.isBlank()) {
            try {
                boolean verified = Utils.verifyWebhookSignature(payload, signature, webhookSecret);
                if (!verified) {
                    log.warn("Invalid Razorpay Webhook signature received.");
                    return;
                }
            } catch (RazorpayException e) {
                log.error("Webhook verification error: {}", e.getMessage());
                return;
            }
        }

        JSONObject json = new JSONObject(payload);
        String event = json.optString("event");
        log.info("Received Razorpay Webhook event: {}", event);

        if ("payment.captured".equals(event)) {
            JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
            String orderId = paymentEntity.optString("order_id");
            String paymentId = paymentEntity.optString("id");

            paymentRepository.findByRazorpayOrderId(orderId).ifPresent(p -> {
                p.setRazorpayPaymentId(paymentId);
                p.setStatus("PAID");
                p.setPaymentMethod(paymentEntity.optString("method"));
                paymentRepository.save(p);
                log.info("Webhook updated payment status to PAID for order {}", orderId);
            });
        }
    }
}
