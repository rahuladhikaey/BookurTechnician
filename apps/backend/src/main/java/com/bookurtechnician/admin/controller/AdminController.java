package com.bookurtechnician.admin.controller;

import com.bookurtechnician.ai.entity.AiFaq;
import com.bookurtechnician.ai.entity.AiKnowledgeDocument;
import com.bookurtechnician.ai.repository.AiFaqRepository;
import com.bookurtechnician.ai.repository.AiKnowledgeDocumentRepository;
import com.bookurtechnician.audit.entity.AuditLog;
import com.bookurtechnician.audit.repository.AuditLogRepository;
import com.bookurtechnician.auth.entity.Role;
import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.customer.entity.CustomerAddress;
import com.bookurtechnician.customer.repository.CustomerAddressRepository;
import com.bookurtechnician.notification.entity.Notification;
import com.bookurtechnician.notification.repository.NotificationRepository;
import com.bookurtechnician.payment.entity.Payment;
import com.bookurtechnician.payment.entity.Refund;
import com.bookurtechnician.payment.repository.PaymentRepository;
import com.bookurtechnician.payment.repository.RefundRepository;

import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.servicecatalog.repository.ServiceCategoryRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceItemRepository;
import com.bookurtechnician.support.entity.SupportTicket;
import com.bookurtechnician.support.repository.SupportTicketRepository;
import com.bookurtechnician.technician.entity.TechnicianDocument;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianDocumentRepository;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.wallet.entity.TechnicianWallet;
import com.bookurtechnician.wallet.entity.WithdrawalRequest;
import com.bookurtechnician.wallet.repository.TechnicianWalletRepository;
import com.bookurtechnician.wallet.repository.WithdrawalRequestRepository;
import lombok.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN', 'FINANCE_ADMIN')")
public class AdminController {

    private final UserRepository userRepository;
    private final CustomerAddressRepository customerAddressRepository;
    private final TechnicianProfileRepository technicianRepository;
    private final TechnicianDocumentRepository technicianDocumentRepository;
    private final TechnicianWalletRepository technicianWalletRepository;
    private final BookingRepository bookingRepository;
    private final PaymentRepository paymentRepository;
    private final RefundRepository refundRepository;
    private final WithdrawalRequestRepository withdrawalRequestRepository;
    private final ServiceCategoryRepository serviceCategoryRepository;
    private final ServiceItemRepository serviceItemRepository;
    private final SupportTicketRepository supportTicketRepository;
    private final NotificationRepository notificationRepository;
    private final AiKnowledgeDocumentRepository aiKnowledgeDocumentRepository;
    private final AiFaqRepository aiFaqRepository;
    private final AuditLogRepository auditLogRepository;

    // ─── 1. CURRENT ADMIN PROFILE ─────────────────────────────────────────────
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getAdminMe(@AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found"));
        Map<String, Object> map = new HashMap<>();
        map.put("id", user.getId());
        map.put("phone", user.getPhone());
        map.put("email", user.getEmail());
        map.put("fullName", user.getFullName());
        map.put("role", user.getRole().name());
        map.put("profileImageUrl", user.getProfileImageUrl());
        return ResponseEntity.ok(ApiResponse.success(map));
    }

    // ─── 2. REAL POSTGRESQL AGGREGATED STATS ──────────────────────────────────
    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<AdminStatsDto>> getDashboardStats() {
        long totalCustomers = userRepository.countByRole(Role.CUSTOMER);
        long totalTechnicians = technicianRepository.count();
        long verifiedTechnicians = technicianRepository.countByKycStatus("VERIFIED");
        long onlineTechnicians = technicianRepository.countByOnlineTrue();
        long pendingKyc = technicianRepository.countByKycStatus("PENDING") + technicianRepository.countByKycStatus("SUBMITTED");
        long totalBookings = bookingRepository.count();
        
        List<String> activeStatuses = List.of("CONFIRMED", "SEARCHING_TECHNICIAN", "TECHNICIAN_NOTIFIED", "ASSIGNED", "ON_THE_WAY", "ARRIVED", "IN_PROGRESS");
        long activeBookings = bookingRepository.countByStatusIn(activeStatuses);
        long completedBookings = bookingRepository.countByStatus("COMPLETED");
        long cancelledBookings = bookingRepository.countByStatus("CANCELLED");
        
        Instant startOfDay = Instant.now().truncatedTo(ChronoUnit.DAYS);
        long todayBookings = bookingRepository.countByCreatedAtAfter(startOfDay);
        BigDecimal todayRevenue = bookingRepository.sumRevenueSince(startOfDay);
        BigDecimal totalRevenue = bookingRepository.sumCompletedRevenue();
        long pendingPayouts = withdrawalRequestRepository.countByStatus("PROCESSING");
        long pendingRefunds = refundRepository.countByStatus("INITIATED") + refundRepository.countByStatus("PROCESSING");

        AdminStatsDto stats = AdminStatsDto.builder()
                .customers(totalCustomers)
                .totalCustomers(totalCustomers)
                .activeCustomers(totalCustomers)
                .technicians(totalTechnicians)
                .totalTechnicians(totalTechnicians)
                .verifiedTechnicians(verifiedTechnicians)
                .onlineTechnicians(onlineTechnicians)
                .offlineTechnicians(Math.max(0, totalTechnicians - onlineTechnicians))
                .pendingKyc(pendingKyc)
                .totalBookings(totalBookings)
                .activeBookings(activeBookings)
                .completedBookings(completedBookings)
                .cancelledBookings(cancelledBookings)
                .todayBookings(todayBookings)
                .todayRevenue(todayRevenue != null ? todayRevenue.doubleValue() : 0.0)
                .totalRevenue(totalRevenue != null ? totalRevenue.doubleValue() : 0.0)
                .pendingPayouts(pendingPayouts)
                .pendingWithdrawals(pendingPayouts)
                .pendingRefunds(pendingRefunds)
                .build();

        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    // ─── 3. CUSTOMERS MANAGER ─────────────────────────────────────────────────
    @GetMapping("/customers")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getCustomers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String status) {
        List<User> users = userRepository.findByRole(Role.CUSTOMER);
        
        List<Map<String, Object>> result = new ArrayList<>();
        for (User u : users) {
            if (search != null && !search.isBlank()) {
                String q = search.toLowerCase();
                boolean match = (u.getFullName() != null && u.getFullName().toLowerCase().contains(q)) ||
                                (u.getEmail() != null && u.getEmail().toLowerCase().contains(q)) ||
                                (u.getPhone() != null && u.getPhone().contains(q)) ||
                                (u.getId().toString().toLowerCase().contains(q));
                if (!match) continue;
            }
            if (status != null && !status.isBlank()) {
                String uStatus = u.isActive() ? "Active" : "Suspended";
                if (!uStatus.equalsIgnoreCase(status)) continue;
            }

            List<CustomerAddress> addresses = customerAddressRepository.findByCustomerId(u.getId());
            String primaryAddress = addresses.stream()
                    .filter(a -> a != null && a.isPrimary())
                    .map(a -> a.getHouseFlat() + ", " + a.getArea() + ", " + a.getCity())
                    .findFirst()
                    .orElse(addresses.isEmpty() ? null : addresses.get(0).getHouseFlat() + ", " + addresses.get(0).getArea() + ", " + addresses.get(0).getCity());

            int score = 0;
            List<String> missing = new ArrayList<>();
            if (u.getFullName() != null && u.getFullName().trim().length() >= 2 && !u.getFullName().trim().matches("^\\d+$")) score += 25;
            else missing.add("FULL_NAME");
            if (u.isPhoneVerified()) score += 25;
            else missing.add("VERIFIED_PHONE");
            if (u.isEmailVerified()) score += 25;
            else missing.add("VERIFIED_EMAIL");
            if (primaryAddress != null && !primaryAddress.isBlank()) score += 25;
            else missing.add("SERVICE_ADDRESS");

            Map<String, Object> map = new HashMap<>();
            map.put("id", u.getId().toString());
            map.put("name", u.getFullName() != null && !u.getFullName().isBlank() ? u.getFullName() : "User " + u.getPhone().substring(Math.max(0, u.getPhone().length() - 4)));
            map.put("phone", u.getPhone());
            map.put("email", u.getEmail() != null ? u.getEmail() : "unverified@bookurtechnician.online");
            map.put("status", u.isActive() ? "Active" : "Suspended");
            map.put("profileCompletion", score);
            map.put("profileStatus", score == 100 ? "COMPLETE" : score >= 50 ? "PARTIALLY_COMPLETE" : "INCOMPLETE");
            map.put("missingFields", missing);
            map.put("phoneVerified", u.isPhoneVerified());
            map.put("emailVerified", u.isEmailVerified());
            map.put("address", primaryAddress);
            map.put("createdAt", u.getCreatedAt() != null ? u.getCreatedAt().toString() : Instant.now().toString());
            map.put("updatedAt", u.getUpdatedAt() != null ? u.getUpdatedAt().toString() : Instant.now().toString());
            result.add(map);
        }

        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/customers/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getCustomerDetails(@PathVariable UUID id) {
        User u = userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Customer not found"));
        List<CustomerAddress> addresses = customerAddressRepository.findByCustomerId(id);
        List<Booking> bookings = bookingRepository.findByCustomerIdOrderByCreatedAtDesc(id);

        Map<String, Object> map = new HashMap<>();
        map.put("customer", u);
        map.put("addresses", addresses);
        map.put("bookingsCount", bookings.size());
        map.put("bookings", bookings);
        return ResponseEntity.ok(ApiResponse.success(map));
    }

    @PatchMapping("/customers/{id}/status")
    public ResponseEntity<ApiResponse<User>> updateCustomerStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        User u = userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Customer not found"));
        String status = body.getOrDefault("status", "Active");
        u.setActive("Active".equalsIgnoreCase(status));
        u = userRepository.save(u);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_CUSTOMER_STATUS", "Customer", id.toString(), "Status set to " + status);

        return ResponseEntity.ok(ApiResponse.success(u, "Customer status updated to " + status));
    }

    @GetMapping("/customers/{id}/bookings")
    public ResponseEntity<ApiResponse<List<Booking>>> getCustomerBookings(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(bookingRepository.findByCustomerIdOrderByCreatedAtDesc(id)));
    }

    @GetMapping("/customers/{id}/addresses")
    public ResponseEntity<ApiResponse<List<CustomerAddress>>> getCustomerAddresses(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(customerAddressRepository.findByCustomerId(id)));
    }

    // ─── 4. TECHNICIANS MANAGER ───────────────────────────────────────────────
    @GetMapping("/technicians")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTechnicians(
            @RequestParam(required = false) String kycStatus,
            @RequestParam(required = false) Boolean isOnline) {
        List<TechnicianProfile> list = technicianRepository.findAll();
        List<Map<String, Object>> result = new ArrayList<>();

        for (TechnicianProfile t : list) {
            if (kycStatus != null && !kycStatus.isBlank() && !kycStatus.equalsIgnoreCase(t.getKycStatus())) continue;
            if (isOnline != null && t.isOnline() != isOnline) continue;

            Map<String, Object> map = new HashMap<>();
            map.put("id", t.getId().toString());
            map.put("name", t.getUser() != null && t.getUser().getFullName() != null ? t.getUser().getFullName() : "Technician " + t.getTechnicianCode());
            map.put("phone", t.getUser() != null ? t.getUser().getPhone() : "");
            map.put("email", t.getUser() != null && t.getUser().getEmail() != null ? t.getUser().getEmail() : "");
            map.put("code", t.getTechnicianCode());
            map.put("technicianCode", t.getTechnicianCode());
            map.put("kycStatus", t.getKycStatus());
            map.put("isOnline", t.isOnline());
            map.put("online", t.isOnline());
            map.put("rating", t.getRating() != null ? t.getRating() : 5.0);
            map.put("totalRatingsCount", t.getTotalRatingsCount());
            map.put("totalJobsCompleted", t.getTotalJobsCompleted());
            map.put("upiId", t.getUpiId());
            map.put("isUpiVerified", t.isUpiVerified());
            map.put("rejectionReason", t.getRejectionReason());
            map.put("photo", t.getUser() != null && t.getUser().getProfileImageUrl() != null ? t.getUser().getProfileImageUrl() : "https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=150&q=80");
            map.put("status", t.getUser() != null && t.getUser().isActive() ? "Active" : "Suspended");
            map.put("createdAt", t.getCreatedAt() != null ? t.getCreatedAt().toString() : Instant.now().toString());

            if (t.getCurrentLocation() != null) {
                map.put("latitude", t.getCurrentLocation().getY());
                map.put("longitude", t.getCurrentLocation().getX());
            }

            result.add(map);
        }

        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/technicians/online")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getOnlineTechnicians() {
        List<TechnicianProfile> list = technicianRepository.findAll().stream().filter(t -> t != null && t.isOnline()).toList();
        List<Map<String, Object>> result = new ArrayList<>();
        for (TechnicianProfile t : list) {
            Map<String, Object> map = new HashMap<>();
            map.put("id", t.getId().toString());
            map.put("name", t.getUser() != null ? t.getUser().getFullName() : t.getTechnicianCode());
            map.put("phone", t.getUser() != null ? t.getUser().getPhone() : "");
            map.put("technicianCode", t.getTechnicianCode());
            map.put("rating", t.getRating());
            map.put("isOnline", true);
            if (t.getCurrentLocation() != null) {
                map.put("lat", t.getCurrentLocation().getY());
                map.put("lng", t.getCurrentLocation().getX());
                map.put("latitude", t.getCurrentLocation().getY());
                map.put("longitude", t.getCurrentLocation().getX());
            }
            result.add(map);
        }
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/technicians/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getTechnicianDetails(@PathVariable UUID id) {
        TechnicianProfile tech = technicianRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));
        List<TechnicianDocument> docs = technicianDocumentRepository.findByTechnicianId(id);
        Optional<TechnicianWallet> wallet = technicianWalletRepository.findByTechnicianId(id);
        List<Booking> bookings = bookingRepository.findByTechnicianIdOrderByCreatedAtDesc(id);

        Map<String, Object> map = new HashMap<>();
        map.put("technician", tech);
        map.put("documents", docs);
        map.put("wallet", wallet.orElse(null));
        map.put("bookings", bookings);
        return ResponseEntity.ok(ApiResponse.success(map));
    }

    @PatchMapping("/technicians/{id}/kyc")
    public ResponseEntity<ApiResponse<TechnicianProfile>> updateKyc(
            @PathVariable UUID id,
            @RequestBody KycDecisionDto dto,
            @AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile tech = technicianRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        tech.setKycStatus(dto.getStatus().toUpperCase());
        tech.setRejectionReason(dto.getReason());
        tech = technicianRepository.save(tech);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_TECHNICIAN_KYC", "TechnicianProfile", id.toString(), "KYC status set to " + dto.getStatus() + " with reason: " + dto.getReason());

        return ResponseEntity.ok(ApiResponse.success(tech, "Technician KYC status updated to " + dto.getStatus()));
    }

    @PatchMapping("/technicians/{id}/status")
    public ResponseEntity<ApiResponse<TechnicianProfile>> updateTechnicianStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile tech = technicianRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));
        if (tech.getUser() != null) {
            String status = body.getOrDefault("status", "Active");
            tech.getUser().setActive("Active".equalsIgnoreCase(status));
            userRepository.save(tech.getUser());
            recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                    "UPDATE_TECHNICIAN_STATUS", "TechnicianProfile", id.toString(), "Account status set to " + status);
        }
        return ResponseEntity.ok(ApiResponse.success(tech, "Technician status updated"));
    }

    @GetMapping("/technicians/{id}/documents")
    public ResponseEntity<ApiResponse<List<TechnicianDocument>>> getTechnicianDocuments(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(technicianDocumentRepository.findByTechnicianId(id)));
    }

    @GetMapping("/technicians/{id}/earnings")
    public ResponseEntity<ApiResponse<TechnicianWallet>> getTechnicianEarnings(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(technicianWalletRepository.findByTechnicianId(id).orElse(null)));
    }

    // ─── 5. BOOKINGS & DISPATCH ───────────────────────────────────────────────
    @GetMapping("/bookings")
    public ResponseEntity<ApiResponse<List<Booking>>> getBookings(@RequestParam(required = false) String status) {
        List<Booking> bookings = (status != null && !status.isBlank())
                ? bookingRepository.findByStatusOrderByCreatedAtDesc(status.toUpperCase())
                : bookingRepository.findAllByOrderByCreatedAtDesc();
        return ResponseEntity.ok(ApiResponse.success(bookings));
    }

    @GetMapping("/bookings/{id}")
    public ResponseEntity<ApiResponse<Booking>> getBookingDetails(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(bookingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + id))));
    }

    @PostMapping("/bookings/{id}/assign")
    public ResponseEntity<ApiResponse<Booking>> assignTechnician(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Booking booking = bookingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + id));

        String techIdStr = body.get("technicianId");
        if (techIdStr == null || techIdStr.isBlank()) {
            throw new BadRequestException("technicianId is required");
        }
        TechnicianProfile tech = technicianRepository.findById(UUID.fromString(techIdStr))
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found: " + techIdStr));

        booking.setTechnician(tech);
        booking.setStatus("ASSIGNED");
        booking = bookingRepository.save(booking);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "MANUAL_DISPATCH_ASSIGN", "Booking", id.toString(), "Assigned to technician " + tech.getTechnicianCode());

        return ResponseEntity.ok(ApiResponse.success(booking, "Technician assigned successfully"));
    }

    @PatchMapping("/bookings/{id}/status")
    public ResponseEntity<ApiResponse<Booking>> updateBookingStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Booking booking = bookingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + id));

        String nextStatus = body.get("status");
        if (nextStatus == null || nextStatus.isBlank()) {
            throw new BadRequestException("status is required");
        }
        booking.setStatus(nextStatus.toUpperCase());
        booking = bookingRepository.save(booking);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_BOOKING_STATUS", "Booking", id.toString(), "Status set to " + nextStatus);

        return ResponseEntity.ok(ApiResponse.success(booking, "Booking status updated to " + nextStatus));
    }

    @PostMapping("/bookings/{id}/cancel")
    public ResponseEntity<ApiResponse<Booking>> cancelBooking(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Booking booking = bookingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + id));

        booking.setStatus("CANCELLED");
        booking.setCancellationReason(body.getOrDefault("reason", "Cancelled by Admin"));
        booking.setCancelledBy("ADMIN");
        booking = bookingRepository.save(booking);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "CANCEL_BOOKING", "Booking", id.toString(), "Cancelled by Admin with reason: " + booking.getCancellationReason());

        return ResponseEntity.ok(ApiResponse.success(booking, "Booking cancelled successfully"));
    }

    // ─── 6. PAYMENTS, REFUNDS & WITHDRAWALS ────────────────────────────────────
    @GetMapping("/payments")
    public ResponseEntity<ApiResponse<List<Payment>>> getPayments() {
        return ResponseEntity.ok(ApiResponse.success(paymentRepository.findAll()));
    }

    @GetMapping("/payments/{id}")
    public ResponseEntity<ApiResponse<Payment>> getPaymentDetails(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(paymentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found: " + id))));
    }

    @GetMapping("/refunds")
    public ResponseEntity<ApiResponse<List<Refund>>> getRefunds() {
        return ResponseEntity.ok(ApiResponse.success(refundRepository.findAll()));
    }

    @GetMapping("/refunds/{id}")
    public ResponseEntity<ApiResponse<Refund>> getRefundDetails(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(refundRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Refund not found: " + id))));
    }

    @PatchMapping("/refunds/{refundId}/status")
    public ResponseEntity<ApiResponse<Refund>> updateRefundStatus(
            @PathVariable UUID refundId,
            @RequestBody RefundStatusUpdateDto dto,
            @AuthenticationPrincipal UserPrincipal principal) {
        Refund refund = refundRepository.findById(refundId)
                .orElseThrow(() -> new ResourceNotFoundException("Refund record not found: " + refundId));

        refund.setStatus(dto.getStatus().toUpperCase());
        if ("SETTLED".equalsIgnoreCase(dto.getStatus())) {
            refund.setSettledAt(Instant.now());
        }
        refund = refundRepository.save(refund);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_REFUND_STATUS", "Refund", refundId.toString(), "Status set to " + dto.getStatus());

        return ResponseEntity.ok(ApiResponse.success(refund, "Refund status updated to " + dto.getStatus()));
    }

    @GetMapping("/withdrawals")
    public ResponseEntity<ApiResponse<List<WithdrawalRequest>>> getWithdrawals() {
        return ResponseEntity.ok(ApiResponse.success(withdrawalRequestRepository.findAll()));
    }

    @GetMapping("/payouts")
    public ResponseEntity<ApiResponse<List<WithdrawalRequest>>> getPayouts() {
        return ResponseEntity.ok(ApiResponse.success(withdrawalRequestRepository.findAll()));
    }

    @PatchMapping("/withdrawals/{id}/status")
    public ResponseEntity<ApiResponse<WithdrawalRequest>> updateWithdrawalStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        WithdrawalRequest req = withdrawalRequestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Withdrawal request not found: " + id));

        String status = body.getOrDefault("status", "SETTLED");
        req.setStatus(status.toUpperCase());
        if ("SETTLED".equalsIgnoreCase(status)) {
            req.setSettledAt(Instant.now());
            req.setUtrNumber(body.getOrDefault("utrNumber", "UTR-" + System.currentTimeMillis()));
        }
        req = withdrawalRequestRepository.save(req);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_WITHDRAWAL_STATUS", "WithdrawalRequest", id.toString(), "Status set to " + status);

        return ResponseEntity.ok(ApiResponse.success(req, "Withdrawal status updated to " + status));
    }



    // ─── 8. SUPPORT TICKETS ───────────────────────────────────────────────────
    @GetMapping("/support/tickets")
    public ResponseEntity<ApiResponse<List<SupportTicket>>> getSupportTickets(@RequestParam(required = false) String status) {
        List<SupportTicket> list = (status != null && !status.isBlank())
                ? supportTicketRepository.findByStatus(status.toUpperCase())
                : supportTicketRepository.findAll();
        return ResponseEntity.ok(ApiResponse.success(list));
    }

    @PatchMapping("/support/tickets/{id}/status")
    public ResponseEntity<ApiResponse<SupportTicket>> updateTicketStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        SupportTicket ticket = supportTicketRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket not found: " + id));
        String status = body.getOrDefault("status", "IN_PROGRESS");
        ticket.setStatus(status.toUpperCase());
        if (body.containsKey("resolutionNotes")) {
            ticket.setResolutionNotes(body.get("resolutionNotes"));
        }
        ticket = supportTicketRepository.save(ticket);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_SUPPORT_TICKET", "SupportTicket", id.toString(), "Status set to " + status);

        return ResponseEntity.ok(ApiResponse.success(ticket, "Ticket status updated"));
    }

    // ─── 9. NOTIFICATIONS & BROADCASTS ────────────────────────────────────────
    @GetMapping("/notifications/history")
    public ResponseEntity<ApiResponse<List<Notification>>> getNotificationsHistory() {
        return ResponseEntity.ok(ApiResponse.success(notificationRepository.findAllByOrderByCreatedAtDesc()));
    }

    @PostMapping("/notifications")
    public ResponseEntity<ApiResponse<Notification>> createNotification(
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Notification notif = Notification.builder()
                .title(body.getOrDefault("title", "Important Notification"))
                .body(body.getOrDefault("body", ""))
                .recipientType(body.getOrDefault("recipientType", "ALL").toUpperCase())
                .type(body.getOrDefault("type", "BROADCAST").toUpperCase())
                .build();
        notif = notificationRepository.save(notif);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "CREATE_NOTIFICATION", "Notification", notif.getId().toString(), "Broadcast: " + notif.getTitle());

        return ResponseEntity.ok(ApiResponse.success(notif, "Notification sent successfully"));
    }

    // ─── 10. AI ASSISTANT CMS ─────────────────────────────────────────────────
    @GetMapping("/ai/documents")
    public ResponseEntity<ApiResponse<List<AiKnowledgeDocument>>> getAiDocuments() {
        return ResponseEntity.ok(ApiResponse.success(aiKnowledgeDocumentRepository.findAll()));
    }

    @PostMapping("/ai/documents")
    public ResponseEntity<ApiResponse<AiKnowledgeDocument>> createAiDocument(
            @RequestBody AiKnowledgeDocument doc,
            @AuthenticationPrincipal UserPrincipal principal) {
        if (doc.getTokenCount() == null || doc.getTokenCount() == 0) {
            doc.setTokenCount(doc.getContent() != null ? doc.getContent().split("\\s+").length : 0);
        }
        doc = aiKnowledgeDocumentRepository.save(doc);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "CREATE_AI_DOC", "AiKnowledgeDocument", doc.getId().toString(), doc.getTitle());
        return ResponseEntity.ok(ApiResponse.success(doc, "Knowledge document saved"));
    }

    @DeleteMapping("/ai/documents/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteAiDocument(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        aiKnowledgeDocumentRepository.deleteById(id);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "DELETE_AI_DOC", "AiKnowledgeDocument", id.toString(), "Deleted");
        return ResponseEntity.ok(ApiResponse.success(null, "Document deleted"));
    }

    @GetMapping("/ai/faqs")
    public ResponseEntity<ApiResponse<List<AiFaq>>> getAiFaqs() {
        return ResponseEntity.ok(ApiResponse.success(aiFaqRepository.findAll()));
    }

    @PostMapping("/ai/faqs")
    public ResponseEntity<ApiResponse<AiFaq>> createAiFaq(
            @RequestBody AiFaq faq,
            @AuthenticationPrincipal UserPrincipal principal) {
        faq = aiFaqRepository.save(faq);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "CREATE_AI_FAQ", "AiFaq", faq.getId().toString(), faq.getQuestion());
        return ResponseEntity.ok(ApiResponse.success(faq, "FAQ saved"));
    }

    @DeleteMapping("/ai/faqs/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteAiFaq(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        aiFaqRepository.deleteById(id);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "DELETE_AI_FAQ", "AiFaq", id.toString(), "Deleted");
        return ResponseEntity.ok(ApiResponse.success(null, "FAQ deleted"));
    }

    // ─── 11. AUDIT LOGS ───────────────────────────────────────────────────────
    @GetMapping("/audit-logs")
    public ResponseEntity<ApiResponse<List<AuditLog>>> getAuditLogs() {
        return ResponseEntity.ok(ApiResponse.success(auditLogRepository.findAllByOrderByCreatedAtDesc()));
    }

    @PostMapping("/audit-logs")
    public ResponseEntity<ApiResponse<AuditLog>> createAuditLog(
            @RequestBody AuditLog log,
            @AuthenticationPrincipal UserPrincipal principal) {
        if (principal != null) {
            log.setActorId(principal.getId());
            log.setActorEmail(principal.getEmail());
        }
        log = auditLogRepository.save(log);
        return ResponseEntity.ok(ApiResponse.success(log));
    }

    // ─── 12. SERVICE CATALOG & PRICING CRUD ───────────────────────────────────
    @GetMapping("/categories")
    public ResponseEntity<ApiResponse<List<ServiceCategory>>> getCategories() {
        return ResponseEntity.ok(ApiResponse.success(serviceCategoryRepository.findAll()));
    }

    @PostMapping("/categories")
    public ResponseEntity<ApiResponse<ServiceCategory>> createCategory(
            @RequestBody ServiceCategory cat,
            @AuthenticationPrincipal UserPrincipal principal) {
        if (cat.getSlug() == null || cat.getSlug().isBlank()) {
            cat.setSlug(cat.getName().toLowerCase().replaceAll("[^a-z0-9]+", "-"));
        }
        cat = serviceCategoryRepository.save(cat);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "CREATE_CATEGORY", "ServiceCategory", cat.getId().toString(), cat.getName());
        return ResponseEntity.ok(ApiResponse.success(cat, "Category created successfully"));
    }

    @PutMapping("/categories/{id}")
    public ResponseEntity<ApiResponse<ServiceCategory>> updateCategory(
            @PathVariable UUID id,
            @RequestBody ServiceCategory updated,
            @AuthenticationPrincipal UserPrincipal principal) {
        ServiceCategory cat = serviceCategoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + id));
        cat.setName(updated.getName());
        cat.setIconUrl(updated.getIconUrl());
        cat.setBannerUrl(updated.getBannerUrl());
        cat.setActive(updated.isActive());
        cat = serviceCategoryRepository.save(cat);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_CATEGORY", "ServiceCategory", id.toString(), cat.getName());
        return ResponseEntity.ok(ApiResponse.success(cat, "Category updated"));
    }

    @DeleteMapping("/categories/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteCategory(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        serviceCategoryRepository.deleteById(id);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "DELETE_CATEGORY", "ServiceCategory", id.toString(), "Deleted");
        return ResponseEntity.ok(ApiResponse.success(null, "Category deleted"));
    }

    @GetMapping("/services")
    public ResponseEntity<ApiResponse<List<ServiceItem>>> getServices() {
        return ResponseEntity.ok(ApiResponse.success(serviceItemRepository.findAll()));
    }

    @PostMapping("/services")
    public ResponseEntity<ApiResponse<ServiceItem>> createService(
            @RequestBody ServiceItem item,
            @AuthenticationPrincipal UserPrincipal principal) {
        if (item.getSlug() == null || item.getSlug().isBlank()) {
            item.setSlug(item.getName().toLowerCase().replaceAll("[^a-z0-9]+", "-"));
        }
        item = serviceItemRepository.save(item);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "CREATE_SERVICE", "ServiceItem", item.getId().toString(), item.getName());
        return ResponseEntity.ok(ApiResponse.success(item, "Service item created"));
    }

    @PutMapping("/services/{id}")
    public ResponseEntity<ApiResponse<ServiceItem>> updateService(
            @PathVariable UUID id,
            @RequestBody ServiceItem updated,
            @AuthenticationPrincipal UserPrincipal principal) {
        ServiceItem item = serviceItemRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Service not found: " + id));
        item.setName(updated.getName());
        item.setPrice(updated.getPrice());
        item.setDescription(updated.getDescription());
        item.setDurationMinutes(updated.getDurationMinutes());
        item.setImageUrl(updated.getImageUrl());
        item.setPopular(updated.isPopular());
        item.setActive(updated.isActive());
        item = serviceItemRepository.save(item);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_SERVICE", "ServiceItem", id.toString(), item.getName());
        return ResponseEntity.ok(ApiResponse.success(item, "Service item updated"));
    }

    @DeleteMapping("/services/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteService(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        serviceItemRepository.deleteById(id);
        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "DELETE_SERVICE", "ServiceItem", id.toString(), "Deleted");
        return ResponseEntity.ok(ApiResponse.success(null, "Service item deleted"));
    }

    @GetMapping("/pricing")
    public ResponseEntity<ApiResponse<List<ServiceItem>>> getPricing() {
        return ResponseEntity.ok(ApiResponse.success(serviceItemRepository.findAll()));
    }

    @PutMapping("/pricing/{serviceId}")
    public ResponseEntity<ApiResponse<ServiceItem>> updatePricing(
            @PathVariable UUID serviceId,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        ServiceItem item = serviceItemRepository.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service not found: " + serviceId));

        if (body.containsKey("price")) {
            item.setPrice(new BigDecimal(body.get("price").toString()));
        }
        item = serviceItemRepository.save(item);

        recordAudit(principal != null ? principal.getId() : null, principal != null ? principal.getEmail() : "admin",
                "UPDATE_PRICING", "ServiceItem", serviceId.toString(), "Price updated to " + item.getPrice());
        return ResponseEntity.ok(ApiResponse.success(item, "Pricing updated"));
    }



    // ─── HELPER: RECORD AUDIT TRAIL ───────────────────────────────────────────
    private void recordAudit(UUID actorId, String email, String action, String entityType, String entityId, String changes) {
        try {
            AuditLog log = AuditLog.builder()
                    .actorId(actorId)
                    .actorEmail(email != null ? email : "admin@bookurtechnician.online")
                    .action(action)
                    .entityType(entityType)
                    .entityId(entityId)
                    .changesJson("{\"description\":\"" + changes.replace("\"", "\\\"") + "\"}")
                    .build();
            auditLogRepository.save(log);
        } catch (Exception ignored) {}
    }

    // ─── DTO DEFINITIONS ──────────────────────────────────────────────────────
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AdminStatsDto {
        private long customers;
        private long totalCustomers;
        private long activeCustomers;
        private long technicians;
        private long totalTechnicians;
        private long verifiedTechnicians;
        private long onlineTechnicians;
        private long offlineTechnicians;
        private long pendingKyc;
        private long totalBookings;
        private long activeBookings;
        private long completedBookings;
        private long cancelledBookings;
        private long todayBookings;
        private double todayRevenue;
        private double totalRevenue;
        private long pendingPayouts;
        private long pendingWithdrawals;
        private long pendingRefunds;
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
