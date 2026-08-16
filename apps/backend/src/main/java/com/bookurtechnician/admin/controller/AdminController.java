package com.bookurtechnician.admin.controller;

import com.bookurtechnician.auth.entity.Role;
import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.wallet.entity.WithdrawalRequest;
import com.bookurtechnician.wallet.repository.WithdrawalRequestRepository;
import com.bookurtechnician.payment.entity.Payment;
import com.bookurtechnician.payment.repository.PaymentRepository;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN', 'FINANCE_ADMIN')")
public class AdminController {

    private final UserRepository userRepository;
    private final TechnicianProfileRepository technicianRepository;
    private final BookingRepository bookingRepository;
    private final WithdrawalRequestRepository withdrawalRequestRepository;
    private final PaymentRepository paymentRepository;
    private final com.bookurtechnician.payment.repository.RefundRepository refundRepository;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<AdminStatsDto>> getDashboardStats() {
        long totalCustomers = userRepository.countByRole(Role.CUSTOMER);
        long totalTechnicians = technicianRepository.count();
        long verifiedTechnicians = technicianRepository.countByKycStatus("VERIFIED");
        long onlineTechnicians = technicianRepository.countByOnlineTrue();
        long totalBookings = bookingRepository.count();
        long pendingPayouts = withdrawalRequestRepository.countByStatus("PROCESSING");

        AdminStatsDto stats = AdminStatsDto.builder()
                .totalCustomers(totalCustomers)
                .totalTechnicians(totalTechnicians)
                .verifiedTechnicians(verifiedTechnicians)
                .onlineTechnicians(onlineTechnicians)
                .totalBookings(totalBookings)
                .pendingPayouts(pendingPayouts)
                .build();

        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @GetMapping("/technicians")
    public ResponseEntity<ApiResponse<List<TechnicianProfile>>> getTechnicians(
            @RequestParam(required = false) String kycStatus) {
        List<TechnicianProfile> list = technicianRepository.findAll();
        if (kycStatus != null && !kycStatus.isBlank()) {
            list = list.stream().filter(t -> kycStatus.equalsIgnoreCase(t.getKycStatus())).toList();
        }
        return ResponseEntity.ok(ApiResponse.success(list));
    }

    @PatchMapping("/technicians/{technicianId}/kyc")
    public ResponseEntity<ApiResponse<TechnicianProfile>> updateKyc(
            @PathVariable UUID technicianId,
            @RequestBody KycDecisionDto dto) {
        TechnicianProfile tech = technicianRepository.findById(technicianId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        tech.setKycStatus(dto.getStatus().toUpperCase());
        tech.setRejectionReason(dto.getReason());
        tech = technicianRepository.save(tech);

        return ResponseEntity.ok(ApiResponse.success(tech, "Technician KYC status updated to " + dto.getStatus()));
    }

    @GetMapping("/bookings")
    public ResponseEntity<ApiResponse<List<Booking>>> getBookings() {
        List<Booking> bookings = bookingRepository.findAll();
        return ResponseEntity.ok(ApiResponse.success(bookings));
    }

    @GetMapping("/customers")
    public ResponseEntity<ApiResponse<List<User>>> getCustomers() {
        List<User> customers = userRepository.findByRole(Role.CUSTOMER);
        return ResponseEntity.ok(ApiResponse.success(customers));
    }

    @GetMapping("/payments")
    public ResponseEntity<ApiResponse<List<Payment>>> getPayments() {
        List<Payment> payments = paymentRepository.findAll();
        return ResponseEntity.ok(ApiResponse.success(payments));
    }

    @GetMapping("/refunds")
    public ResponseEntity<ApiResponse<List<com.bookurtechnician.payment.entity.Refund>>> getRefunds() {
        List<com.bookurtechnician.payment.entity.Refund> refunds = refundRepository.findAll();
        return ResponseEntity.ok(ApiResponse.success(refunds));
    }

    @PatchMapping("/refunds/{refundId}/status")
    public ResponseEntity<ApiResponse<com.bookurtechnician.payment.entity.Refund>> updateRefundStatus(
            @PathVariable UUID refundId,
            @RequestBody RefundStatusUpdateDto dto) {
        com.bookurtechnician.payment.entity.Refund refund = refundRepository.findById(refundId)
                .orElseThrow(() -> new ResourceNotFoundException("Refund record not found: " + refundId));

        refund.setStatus(dto.getStatus().toUpperCase());
        if ("SETTLED".equalsIgnoreCase(dto.getStatus())) {
            refund.setSettledAt(java.time.Instant.now());
        }
        refund = refundRepository.save(refund);

        return ResponseEntity.ok(ApiResponse.success(refund, "Refund status updated to " + dto.getStatus()));
    }

    @GetMapping("/payouts")
    public ResponseEntity<ApiResponse<List<WithdrawalRequest>>> getPayouts() {
        List<WithdrawalRequest> payouts = withdrawalRequestRepository.findAll();
        return ResponseEntity.ok(ApiResponse.success(payouts));
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AdminStatsDto {
        private long totalCustomers;
        private long totalTechnicians;
        private long verifiedTechnicians;
        private long onlineTechnicians;
        private long totalBookings;
        private long pendingPayouts;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class KycDecisionDto {
        private String status; // VERIFIED, REJECTED
        private String reason;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RefundStatusUpdateDto {
        private String status; // SETTLED, PROCESSING, FAILED
    }
}
