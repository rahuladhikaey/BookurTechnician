package com.bookurtechnician.booking.service;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.auth.service.BrevoEmailService;
import com.bookurtechnician.booking.dto.BookingDtos;
import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.customer.entity.CustomerAddress;
import com.bookurtechnician.customer.repository.CustomerAddressRepository;
import com.bookurtechnician.dispatch.service.DispatchService;
import com.bookurtechnician.payment.entity.Payment;
import com.bookurtechnician.payment.entity.Refund;
import com.bookurtechnician.payment.repository.PaymentRepository;
import com.bookurtechnician.payment.repository.RefundRepository;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.servicecatalog.repository.ServiceItemRepository;
import com.bookurtechnician.wallet.service.WalletService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingService {

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final CustomerAddressRepository addressRepository;
    private final ServiceItemRepository serviceItemRepository;
    private final WalletService walletService;
    private final PaymentRepository paymentRepository;
    private final RefundRepository refundRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final BrevoEmailService brevoEmailService;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public BookingDtos.BookingResponse createBooking(UUID customerId, BookingDtos.CreateBookingRequest req) {
        User customer = userRepository.findById(customerId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer not found"));

        CustomerAddress address = addressRepository.findById(req.getAddressId())
                .orElseThrow(() -> new ResourceNotFoundException("Address not found"));

        ServiceItem service = serviceItemRepository.findById(req.getServiceId())
                .orElseThrow(() -> new ResourceNotFoundException("Service item not found"));

        BigDecimal basePrice = service.getPrice();
        BigDecimal safetyFee = new BigDecimal("49.00");
        BigDecimal gst = basePrice.multiply(new BigDecimal("0.18")).setScale(2, RoundingMode.HALF_UP);
        BigDecimal grandTotal = basePrice.add(safetyFee).add(gst);

        // 10% Platform commission, 90% Technician payout
        BigDecimal platformCommission = basePrice.multiply(new BigDecimal("0.10")).setScale(2, RoundingMode.HALF_UP);
        BigDecimal technicianPayout = basePrice.subtract(platformCommission);

        String bookingCode = "BT-" + (System.currentTimeMillis() % 100000000L);
        String startOtp = String.valueOf(1000 + secureRandom.nextInt(9000));
        Instant startOtpExpiresAt = Instant.now().plus(Duration.ofHours(3)); // 3-Hour Validity

        Booking booking = Booking.builder()
                .bookingCode(bookingCode)
                .customer(customer)
                .address(address)
                .service(service)
                .scheduleDate(req.getScheduleDate())
                .scheduleSlot(req.getScheduleSlot())
                .basePrice(basePrice)
                .safetyFee(safetyFee)
                .gstAmount(gst)
                .grandTotal(grandTotal)
                .platformCommissionAmount(platformCommission)
                .technicianPayoutAmount(technicianPayout)
                .startServiceOtp(startOtp)
                .startOtpExpiresAt(startOtpExpiresAt)
                .failedOtpAttempts(0)
                .status("PAYMENT_PENDING")
                .build();

        booking = bookingRepository.save(booking);
        log.info("Created booking {} with 3-hr Start OTP. Amount: ₹{}", booking.getBookingCode(), grandTotal);

        return mapToResponse(booking);
    }

    @Transactional
    public BookingDtos.BookingResponse updateBookingStatus(UUID bookingId, BookingDtos.UpdateBookingStatusRequest req) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found"));

        String currentStatus = booking.getStatus();
        String targetStatus = req.getStatus().toUpperCase();

        log.info("Transitioning booking {} from {} -> {}", booking.getBookingCode(), currentStatus, targetStatus);

        switch (targetStatus) {
            case "ON_THE_WAY" -> {
                if (!"ASSIGNED".equals(currentStatus) && !"CONFIRMED".equals(currentStatus)) {
                    throw new BadRequestException("Cannot start journey. Booking status is " + currentStatus);
                }
                booking.setStatus("ON_THE_WAY");
            }
            case "ARRIVED" -> {
                if (!"ON_THE_WAY".equals(currentStatus)) {
                    throw new BadRequestException("Cannot mark arrived. Booking status is " + currentStatus);
                }
                booking.setStatus("ARRIVED");
            }
            case "IN_PROGRESS" -> {
                if (!"ARRIVED".equals(currentStatus)) {
                    throw new BadRequestException("Technician must mark ARRIVED before starting the service.");
                }

                // ─── STAGE 2: START OTP VERIFICATION (3-HOUR EXPIRATION) ───
                if (booking.getStartOtpExpiresAt() != null && Instant.now().isAfter(booking.getStartOtpExpiresAt())) {
                    throw new BadRequestException("Start Service OTP has expired (validity was 3 hours). Please contact support.");
                }

                if (req.getStartOtp() == null || !req.getStartOtp().trim().equals(booking.getStartServiceOtp())) {
                    throw new BadRequestException("Invalid Start Service OTP. Please ask customer for the correct 4-digit code displayed on their app.");
                }

                // Generate fresh 4-digit End Service OTP with 24-hour validity
                String endOtp = String.valueOf(1000 + secureRandom.nextInt(9000));
                Instant endOtpExpiresAt = Instant.now().plus(Duration.ofHours(24));

                booking.setEndServiceOtp(endOtp);
                booking.setEndOtpExpiresAt(endOtpExpiresAt);
                booking.setFailedOtpAttempts(0);
                booking.setStatus("IN_PROGRESS");

                // Dispatch styled HTML email to customer's registered email address
                User customer = booking.getCustomer();
                if (customer != null && customer.getEmail() != null && !customer.getEmail().isBlank()) {
                    brevoEmailService.sendEndServiceOtpEmail(
                            customer.getEmail(),
                            customer.getFullName(),
                            booking.getBookingCode(),
                            endOtp
                    );
                }
            }
            case "COMPLETED" -> {
                if (!"IN_PROGRESS".equals(currentStatus)) {
                    throw new BadRequestException("Cannot complete service before it is in progress.");
                }

                // ─── STAGE 3: END OTP VERIFICATION (24-HOUR EXPIRATION & MAX 3 ATTEMPTS) ───
                if (booking.getFailedOtpAttempts() >= 3) {
                    throw new BadRequestException("Maximum OTP verification attempts exceeded (3 failed attempts). Account temporarily locked for safety.");
                }

                if (booking.getEndOtpExpiresAt() != null && Instant.now().isAfter(booking.getEndOtpExpiresAt())) {
                    throw new BadRequestException("End Service OTP has expired (validity was 24 hours). Please request an email resend.");
                }

                if (req.getEndOtp() == null || !req.getEndOtp().trim().equals(booking.getEndServiceOtp())) {
                    booking.setFailedOtpAttempts(booking.getFailedOtpAttempts() + 1);
                    bookingRepository.save(booking);
                    int remaining = 3 - booking.getFailedOtpAttempts();
                    throw new BadRequestException("Invalid Completion OTP. " + (remaining > 0 ? "Remaining attempts: " + remaining : "Verification locked."));
                }

                booking.setStatus("COMPLETED");

                // Execute PostgreSQL transactional wallet credit and ledger entry
                if (booking.getTechnician() != null) {
                    walletService.creditTechnicianEarning(
                            booking.getTechnician(),
                            booking.getTechnicianPayoutAmount(),
                            booking.getBookingCode()
                    );
                    log.info("Credited ₹{} to technician {} wallet for booking {}",
                            booking.getTechnicianPayoutAmount(), booking.getTechnician().getTechnicianCode(), booking.getBookingCode());
                }
            }
            case "CANCELLED" -> {
                if ("IN_PROGRESS".equals(currentStatus) || "COMPLETED".equals(currentStatus)) {
                    throw new BadRequestException("Cannot cancel an active or completed service.");
                }
                booking.setStatus("CANCELLED");
                booking.setCancellationReason(req.getCancellationReason() != null ? req.getCancellationReason() : "Customer cancelled");
                booking.setCancelledBy("CUSTOMER");
                processCancellationRefund(booking);
            }
            default -> throw new BadRequestException("Unknown booking status: " + targetStatus);
        }

        booking = bookingRepository.save(booking);

        // Broadcast real-time status update to customer & technician WebSocket topics
        try {
            DispatchService.DispatchStatusEvent event = DispatchService.DispatchStatusEvent.builder()
                    .bookingId(booking.getId())
                    .bookingCode(booking.getBookingCode())
                    .status(booking.getStatus())
                    .message("Status updated to " + booking.getStatus())
                    .technicianName(booking.getTechnician() != null ? booking.getTechnician().getUser().getFullName() : null)
                    .technicianPhone(booking.getTechnician() != null ? booking.getTechnician().getUser().getPhone() : null)
                    .technicianCode(booking.getTechnician() != null ? booking.getTechnician().getTechnicianCode() : null)
                    .startServiceOtp(booking.getStartServiceOtp())
                    .timestamp(Instant.now())
                    .build();

            messagingTemplate.convertAndSend("/topic/booking/" + booking.getId(), event);
        } catch (Exception ex) {
            log.warn("WebSocket status broadcast warning: {}", ex.getMessage());
        }

        return mapToResponse(booking);
    }

    @Transactional
    public void resendEndOtpEmail(UUID bookingId, UUID customerId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found"));

        if (!"IN_PROGRESS".equals(booking.getStatus())) {
            throw new BadRequestException("Completion OTP email can only be resent when service is IN_PROGRESS.");
        }

        if (booking.getEndServiceOtp() == null) {
            throw new BadRequestException("Completion OTP has not been generated yet.");
        }

        User customer = booking.getCustomer();
        if (customer != null && customer.getEmail() != null && !customer.getEmail().isBlank()) {
            brevoEmailService.sendEndServiceOtpEmail(
                    customer.getEmail(),
                    customer.getFullName(),
                    booking.getBookingCode(),
                    booking.getEndServiceOtp()
            );
            log.info("Resent End Service OTP email for booking {}", booking.getBookingCode());
        }
    }

    private void processCancellationRefund(Booking booking) {
        Instant now = Instant.now();
        Duration elapsed = Duration.between(booking.getCreatedAt(), now);

        if (elapsed.toHours() <= 1) {
            BigDecimal requestedAmount = booking.getGrandTotal();
            BigDecimal nonRefundable = booking.getSafetyFee();
            BigDecimal refundable = requestedAmount.subtract(nonRefundable).max(BigDecimal.ZERO);

            Payment payment = paymentRepository.findByBookingId(booking.getId()).orElse(null);

            Refund refund = Refund.builder()
                    .refundCode("REF-" + (System.currentTimeMillis() % 1000000))
                    .booking(booking)
                    .payment(payment)
                    .requestedAmount(requestedAmount)
                    .nonRefundableAmount(nonRefundable)
                    .refundableAmount(refundable)
                    .status("SETTLED")
                    .cancellationTime(now)
                    .reason(booking.getCancellationReason())
                    .settledAt(now)
                    .build();

            refundRepository.save(refund);
            log.info("Processed refund {} for booking {}: Refundable ₹{}", refund.getRefundCode(), booking.getBookingCode(), refundable);
        }
    }

    public List<BookingDtos.BookingResponse> getCustomerBookings(UUID customerId) {
        return bookingRepository.findByCustomerIdOrderByCreatedAtDesc(customerId).stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<BookingDtos.BookingResponse> getTechnicianBookings(UUID technicianId) {
        return bookingRepository.findByTechnicianIdOrderByCreatedAtDesc(technicianId).stream()
                .map(this::mapToResponse)
                .toList();
    }

    private BookingDtos.BookingResponse mapToResponse(Booking b) {
        Double techLat = null;
        Double techLng = null;
        Double custLat = null;
        Double custLng = null;

        if (b.getAddress() != null && b.getAddress().getCoordinates() != null) {
            custLat = b.getAddress().getCoordinates().getY();
            custLng = b.getAddress().getCoordinates().getX();
        }

        if (b.getTechnician() != null && b.getTechnician().getCurrentLocation() != null) {
            techLat = b.getTechnician().getCurrentLocation().getY();
            techLng = b.getTechnician().getCurrentLocation().getX();
        }

        Double distanceKm = null;
        if (techLat != null && techLng != null && custLat != null && custLng != null) {
            distanceKm = calculateHaversineKm(custLat, custLng, techLat, techLng);
        }

        return BookingDtos.BookingResponse.builder()
                .id(b.getId())
                .bookingCode(b.getBookingCode())
                .serviceName(b.getService().getName())
                .status(b.getStatus())
                .scheduleDate(b.getScheduleDate())
                .scheduleSlot(b.getScheduleSlot())
                .grandTotal(b.getGrandTotal())
                .startServiceOtp(b.getStartServiceOtp())
                .startOtpExpiresAt(b.getStartOtpExpiresAt())
                .endOtpExpiresAt(b.getEndOtpExpiresAt())
                .technicianName(b.getTechnician() != null ? b.getTechnician().getUser().getFullName() : "Finding nearest technician...")
                .technicianPhone(b.getTechnician() != null ? b.getTechnician().getUser().getPhone() : "")
                .technicianCode(b.getTechnician() != null ? b.getTechnician().getTechnicianCode() : "")
                .technicianLatitude(techLat)
                .technicianLongitude(techLng)
                .customerLatitude(custLat)
                .customerLongitude(custLng)
                .distanceKm(distanceKm)
                .fullAddress(b.getAddress().getHouseFlat() + ", " + b.getAddress().getStreet() + ", " + b.getAddress().getCity())
                .build();
    }

    private double calculateHaversineKm(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Earth radius in km
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Math.round(R * c * 10.0) / 10.0;
    }
}
