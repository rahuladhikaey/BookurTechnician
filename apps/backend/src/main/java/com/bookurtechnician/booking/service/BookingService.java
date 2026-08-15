package com.bookurtechnician.booking.service;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
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
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.wallet.service.WalletService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
    private final DispatchService dispatchService;
    private final WalletService walletService;
    private final PaymentRepository paymentRepository;
    private final RefundRepository refundRepository;
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
                .status("CONFIRMED")
                .build();

        // Auto dispatch nearby technician
        TechnicianProfile assignedTech = dispatchService.autoAssignNearbyTechnician(booking);
        if (assignedTech != null) {
            booking.setTechnician(assignedTech);
            booking.setStatus("ASSIGNED");
        }

        booking = bookingRepository.save(booking);

        return mapToResponse(booking);
    }

    @Transactional
    public BookingDtos.BookingResponse updateBookingStatus(UUID bookingId, BookingDtos.UpdateBookingStatusRequest req) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found"));

        String newStatus = req.getStatus().toUpperCase();

        if ("IN_PROGRESS".equals(newStatus)) {
            if (req.getStartOtp() == null || !req.getStartOtp().trim().equals(booking.getStartServiceOtp())) {
                throw new BadRequestException("Invalid Start Service OTP. Please ask the customer for the correct 4-digit code.");
            }
        } else if ("COMPLETED".equals(newStatus)) {
            if (booking.getTechnician() != null) {
                walletService.creditTechnicianEarning(
                        booking.getTechnician(),
                        booking.getTechnicianPayoutAmount(),
                        booking.getBookingCode()
                );
            }
        } else if ("CANCELLED".equals(newStatus)) {
            booking.setCancellationReason(req.getCancellationReason() != null ? req.getCancellationReason() : "Customer cancelled");
            booking.setCancelledBy("CUSTOMER");

            // Process refund calculation
            processCancellationRefund(booking);
        }

        booking.setStatus(newStatus);
        booking = bookingRepository.save(booking);

        return mapToResponse(booking);
    }

    private void processCancellationRefund(Booking booking) {
        Instant now = Instant.now();
        Duration elapsed = Duration.between(booking.getCreatedAt(), now);

        if (elapsed.toHours() <= 1) {
            // Eligible for refund minus non-refundable platform/safety fee (₹49)
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
        return BookingDtos.BookingResponse.builder()
                .id(b.getId())
                .bookingCode(b.getBookingCode())
                .serviceName(b.getService().getName())
                .status(b.getStatus())
                .scheduleDate(b.getScheduleDate())
                .scheduleSlot(b.getScheduleSlot())
                .grandTotal(b.getGrandTotal())
                .startServiceOtp(b.getStartServiceOtp())
                .technicianName(b.getTechnician() != null ? b.getTechnician().getUser().getFullName() : "Assigning nearby partner...")
                .technicianPhone(b.getTechnician() != null ? b.getTechnician().getUser().getPhone() : "")
                .technicianCode(b.getTechnician() != null ? b.getTechnician().getTechnicianCode() : "")
                .fullAddress(b.getAddress().getHouseFlat() + ", " + b.getAddress().getStreet() + ", " + b.getAddress().getCity())
                .build();
    }
}
