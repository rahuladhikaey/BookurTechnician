package com.bookurtechnician.technician.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.booking.dto.BookingDtos;
import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.booking.service.BookingService;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.wallet.entity.TechnicianWallet;
import com.bookurtechnician.wallet.entity.WithdrawalRequest;
import com.bookurtechnician.wallet.repository.TechnicianWalletRepository;
import com.bookurtechnician.wallet.repository.WithdrawalRequestRepository;
import com.bookurtechnician.wallet.service.WalletService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.Map;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.bookurtechnician.technician.entity.TechnicianDocument;
import com.bookurtechnician.technician.repository.TechnicianDocumentRepository;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/technician")
@RequiredArgsConstructor
@Slf4j
public class TechnicianController {

    private final com.bookurtechnician.auth.repository.UserRepository userRepository;
    private final TechnicianProfileRepository profileRepository;
    private final TechnicianDocumentRepository technicianDocumentRepository;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final WalletService walletService;
    private final TechnicianWalletRepository walletRepository;
    private final WithdrawalRequestRepository withdrawalRequestRepository;
    private final StringRedisTemplate redisTemplate;
    private final SimpMessagingTemplate messagingTemplate;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @GetMapping("/documents")
    public ResponseEntity<ApiResponse<List<TechnicianDocument>>> getMyDocuments(
            @AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));
        List<TechnicianDocument> docs = technicianDocumentRepository.findByTechnicianId(profile.getId());
        return ResponseEntity.ok(ApiResponse.success(docs));
    }

    @PostMapping("/documents")
    public ResponseEntity<ApiResponse<TechnicianDocument>> submitDocument(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody Map<String, String> request) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        String docType = request.getOrDefault("documentType", "SELFIE");
        String fileUrl = request.getOrDefault("fileUrl", "");
        String maskedNumber = request.getOrDefault("maskedNumber", "");

        List<TechnicianDocument> existing = technicianDocumentRepository.findByTechnicianId(profile.getId());
        TechnicianDocument doc = existing.stream()
                .filter(d -> docType.equalsIgnoreCase(d.getDocumentType()))
                .findFirst()
                .orElseGet(() -> TechnicianDocument.builder()
                        .technician(profile)
                        .documentType(docType.toUpperCase())
                        .build());

        doc.setSecureCloudinaryUrl(fileUrl);
        if (!maskedNumber.isBlank()) {
            doc.setMaskedNumber(maskedNumber);
        }
        doc.setVerificationStatus("APPROVED");
        doc.setReviewedAt(Instant.now());
        doc = technicianDocumentRepository.save(doc);

        if ("SELFIE".equalsIgnoreCase(docType) && !fileUrl.isBlank()) {
            userRepository.findById(principal.getId()).ifPresent(user -> {
                user.setProfileImageUrl(fileUrl);
                userRepository.save(user);
            });
        }

        return ResponseEntity.ok(ApiResponse.success(doc, docType + " document submitted successfully"));
    }

    @PostMapping("/profile/photo")
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadProfilePhoto(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody Map<String, String> request) {
        String photoUrl = request.get("photoUrl");
        if (photoUrl == null || photoUrl.isBlank()) {
            throw new BadRequestException("photoUrl is required");
        }

        userRepository.findById(principal.getId()).ifPresent(user -> {
            user.setProfileImageUrl(photoUrl.trim());
            userRepository.save(user);
        });

        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        List<TechnicianDocument> existing = technicianDocumentRepository.findByTechnicianId(profile.getId());
        TechnicianDocument selfieDoc = existing.stream()
                .filter(d -> "SELFIE".equalsIgnoreCase(d.getDocumentType()))
                .findFirst()
                .orElseGet(() -> TechnicianDocument.builder()
                        .technician(profile)
                        .documentType("SELFIE")
                        .build());
        selfieDoc.setSecureCloudinaryUrl(photoUrl.trim());
        selfieDoc.setVerificationStatus("APPROVED");
        selfieDoc.setReviewedAt(Instant.now());
        technicianDocumentRepository.save(selfieDoc);

        return ResponseEntity.ok(ApiResponse.success(Map.of("photoUrl", photoUrl), "Profile selfie updated and verified"));
    }

    @PostMapping("/fcm-token")
    public ResponseEntity<ApiResponse<Void>> updateFcmToken(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody Map<String, String> request) {
        String token = request.get("fcmToken");
        if (token != null && !token.trim().isEmpty()) {
            userRepository.findById(principal.getId()).ifPresent(user -> {
                user.setFcmToken(token.trim());
                userRepository.save(user);
                log.info("Updated FCM token for technician user: {}", user.getId());
            });
        }
        return ResponseEntity.ok(ApiResponse.success(null, "FCM token updated successfully"));
    }

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<TechnicianProfileResponseDto>> getProfile(@AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));
        com.bookurtechnician.auth.entity.User user = userRepository.findById(principal.getId())
                .orElse(profile.getUser());

        TechnicianProfileResponseDto dto = TechnicianProfileResponseDto.builder()
                .id(profile.getId())
                .technicianCode(profile.getTechnicianCode())
                .fullName(user != null && user.getFullName() != null && !user.getFullName().isBlank() ? user.getFullName() : "Partner Technician")
                .phone(user != null ? user.getPhone() : "")
                .email(user != null ? user.getEmail() : "")
                .profileImageUrl(user != null ? user.getProfileImageUrl() : "")
                .rating(profile.getRating() != null ? profile.getRating() : new BigDecimal("5.0"))
                .totalRatingsCount(profile.getTotalRatingsCount())
                .totalJobsCompleted(profile.getTotalJobsCompleted())
                .kycStatus(profile.getKycStatus() != null ? profile.getKycStatus() : "VERIFIED")
                .isOnline(profile.isOnline())
                .upiId(profile.getUpiId() != null ? profile.getUpiId() : "technician@upi")
                .isUpiVerified(profile.isUpiVerified())
                .build();
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    @PutMapping("/profile")
    public ResponseEntity<ApiResponse<TechnicianProfileResponseDto>> updateProfile(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody UpdateTechnicianProfileDto dto) {
        com.bookurtechnician.auth.entity.User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician user not found"));

        if (dto.getFullName() != null && !dto.getFullName().isBlank()) {
            user.setFullName(dto.getFullName().trim());
        }
        if (dto.getProfileImageUrl() != null && !dto.getProfileImageUrl().isBlank()) {
            user.setProfileImageUrl(dto.getProfileImageUrl().trim());
        }
        userRepository.save(user);

        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        if (dto.getUpiId() != null && !dto.getUpiId().isBlank()) {
            profile.setUpiId(dto.getUpiId().trim());
            profile.setUpiVerified(true);
        }
        profile = profileRepository.save(profile);

        TechnicianProfileResponseDto responseDto = TechnicianProfileResponseDto.builder()
                .id(profile.getId())
                .technicianCode(profile.getTechnicianCode())
                .fullName(user.getFullName())
                .phone(user.getPhone())
                .email(user.getEmail())
                .profileImageUrl(user.getProfileImageUrl())
                .rating(profile.getRating() != null ? profile.getRating() : new BigDecimal("5.0"))
                .totalRatingsCount(profile.getTotalRatingsCount())
                .totalJobsCompleted(profile.getTotalJobsCompleted())
                .kycStatus(profile.getKycStatus() != null ? profile.getKycStatus() : "VERIFIED")
                .isOnline(profile.isOnline())
                .upiId(profile.getUpiId())
                .isUpiVerified(profile.isUpiVerified())
                .build();

        return ResponseEntity.ok(ApiResponse.success(responseDto, "Technician profile updated successfully"));
    }

    @PostMapping("/incident")
    public ResponseEntity<ApiResponse<Map<String, Object>>> reportIncident(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody Map<String, String> request) {
        String category = request.getOrDefault("category", "Customer Dispute");
        String description = request.getOrDefault("description", "");
        String incidentId = "INC-" + (System.currentTimeMillis() % 100000);
        log.warn("🚨 Incident Reported by Technician {}: Category: {}, Desc: {}", principal.getId(), category, description);
        return ResponseEntity.ok(ApiResponse.success(Map.of("incidentId", incidentId, "status", "REPORTED"), "Incident report submitted to Safety Cell! ID: " + incidentId));
    }

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<TechnicianDashboardDto>> getDashboard(@AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        List<Booking> allJobs = bookingRepository.findByTechnicianIdOrderByCreatedAtDesc(profile.getId());
        LocalDate today = LocalDate.now();

        long todayJobsCount = allJobs.stream().filter(b -> today.equals(b.getScheduleDate())).count();
        long completedJobsCount = allJobs.stream().filter(b -> "COMPLETED".equalsIgnoreCase(b.getStatus())).count();

        BigDecimal todayEarnings = allJobs.stream()
                .filter(b -> today.equals(b.getScheduleDate()) && "COMPLETED".equalsIgnoreCase(b.getStatus()))
                .map(b -> b.getTechnicianPayoutAmount() != null ? b.getTechnicianPayoutAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, (a, b) -> a.add(b));

        BigDecimal totalEarnings = allJobs.stream()
                .filter(b -> "COMPLETED".equalsIgnoreCase(b.getStatus()))
                .map(b -> b.getTechnicianPayoutAmount() != null ? b.getTechnicianPayoutAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, (a, b) -> a.add(b));

        TechnicianWallet wallet = walletRepository.findByTechnician(profile).orElse(null);
        BigDecimal availableBalance = wallet != null ? wallet.getAvailableBalance() : BigDecimal.ZERO;

        List<WithdrawalRequest> payouts = withdrawalRequestRepository.findByTechnicianIdOrderByCreatedAtDesc(profile.getId());

        TechnicianDashboardDto dto = TechnicianDashboardDto.builder()
                .isOnline(profile.isOnline())
                .todayJobsCount(todayJobsCount)
                .todayEarnings(todayEarnings)
                .completedJobsCount(completedJobsCount)
                .totalEarnings(totalEarnings)
                .availableBalance(availableBalance)
                .rating(profile.getRating() != null ? profile.getRating() : BigDecimal.ZERO)
                .savedUpiId(profile.getUpiId())
                .payouts(payouts)
                .build();

        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    @GetMapping("/jobs")
    public ResponseEntity<ApiResponse<List<BookingDtos.BookingResponse>>> getJobs(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) String status) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        List<BookingDtos.BookingResponse> jobs = bookingService.getTechnicianBookings(profile.getId());
        if (status != null && !status.isBlank()) {
            jobs = jobs.stream().filter(j -> status.equalsIgnoreCase(j.getStatus())).toList();
        }
        return ResponseEntity.ok(ApiResponse.success(jobs));
    }

    @PatchMapping("/jobs/{bookingId}/status")
    public ResponseEntity<ApiResponse<BookingDtos.BookingResponse>> updateJobStatus(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID bookingId,
            @RequestBody JobStatusUpdateDto dto) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found"));

        if (booking.getTechnician() == null || !profile.getId().equals(booking.getTechnician().getId())) {
            throw new BadRequestException("This booking is not assigned to you.");
        }

        BookingDtos.UpdateBookingStatusRequest req = new BookingDtos.UpdateBookingStatusRequest();
        req.setStatus(dto.getStatus());
        req.setStartOtp(dto.getStartOtp());

        BookingDtos.BookingResponse response = bookingService.updateBookingStatus(bookingId, req);
        return ResponseEntity.ok(ApiResponse.success(response, "Booking status updated to " + dto.getStatus()));
    }

    @PostMapping("/location")
    public ResponseEntity<ApiResponse<Void>> streamLocation(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody LocationUpdateDto dto) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        if (dto.getLatitude() != null && dto.getLongitude() != null) {
            validateCoordinates(dto.getLatitude(), dto.getLongitude());

            Point point = geometryFactory.createPoint(new Coordinate(dto.getLongitude(), dto.getLatitude()));
            profile.setCurrentLocation(point);
            profile.setLocationUpdatedAt(Instant.now());
            profileRepository.save(profile);

            // Sync with Redis GEO index if online
            if (profile.isOnline()) {
                try {
                    redisTemplate.opsForGeo().add(
                            "tech:locations",
                            new org.springframework.data.geo.Point(dto.getLongitude(), dto.getLatitude()),
                            profile.getId().toString()
                    );
                } catch (Exception ex) {
                    log.warn("Redis GEO live sync warning: {}", ex.getMessage());
                }
            }

            // Broadcast real GPS coordinate to customer live tracking screen
            if (dto.getBookingId() != null) {
                try {
                    TelemetryEvent telemetry = TelemetryEvent.builder()
                            .technicianId(profile.getId())
                            .bookingId(dto.getBookingId())
                            .latitude(dto.getLatitude())
                            .longitude(dto.getLongitude())
                            .heading(dto.getHeading() != null ? dto.getHeading() : 0.0)
                            .speed(dto.getSpeed() != null ? dto.getSpeed() : 0.0)
                            .timestamp(Instant.now())
                            .build();

                    messagingTemplate.convertAndSend("/topic/booking/" + dto.getBookingId() + "/telemetry", telemetry);
                } catch (Exception ex) {
                    log.warn("Telemetry WebSocket broadcast warning: {}", ex.getMessage());
                }
            }
        }

        return ResponseEntity.ok(ApiResponse.success(null, "Location updated"));
    }

    @PostMapping("/online-status")
    public ResponseEntity<ApiResponse<TechnicianProfile>> toggleOnline(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody OnlineStatusDto dto) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        if (dto.isOnline()) {
            if (dto.getLatitude() == null || dto.getLongitude() == null) {
                throw new com.bookurtechnician.common.exception.BadRequestException("Valid GPS coordinates are strictly required to go ONLINE.");
            }
            validateCoordinates(dto.getLatitude(), dto.getLongitude());

            Point point = geometryFactory.createPoint(new Coordinate(dto.getLongitude(), dto.getLatitude()));
            profile.setCurrentLocation(point);
            profile.setLocationUpdatedAt(Instant.now());
            profile.setOnline(true);

            // Cache ephemeral coordinate in Redis GEO
            try {
                redisTemplate.opsForGeo().add(
                        "tech:locations",
                        new org.springframework.data.geo.Point(dto.getLongitude(), dto.getLatitude()),
                        profile.getId().toString()
                );
            } catch (Exception ex) {
                log.warn("Redis GEO coordinate caching warning: {}", ex.getMessage());
            }
        } else {
            profile.setOnline(false);
            try {
                redisTemplate.opsForZSet().remove("tech:locations", profile.getId().toString());
            } catch (Exception ex) {
                log.warn("Redis GEO removal warning: {}", ex.getMessage());
            }
        }

        profile = profileRepository.save(profile);
        return ResponseEntity.ok(ApiResponse.success(profile, dto.isOnline() ? "You are now ONLINE" : "You are now OFFLINE"));
    }

    private void validateCoordinates(Double latitude, Double longitude) {
        if (latitude != null) {
            if (latitude.isNaN() || latitude.isInfinite() || latitude < -90.0 || latitude > 90.0) {
                throw new com.bookurtechnician.common.exception.BadRequestException("Invalid latitude: must be between -90.0 and +90.0");
            }
        }
        if (longitude != null) {
            if (longitude.isNaN() || longitude.isInfinite() || longitude < -180.0 || longitude > 180.0) {
                throw new com.bookurtechnician.common.exception.BadRequestException("Invalid longitude: must be between -180.0 and +180.0");
            }
        }
    }

    @PostMapping("/upi-settings")
    public ResponseEntity<ApiResponse<TechnicianProfile>> updateUpi(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody UpiUpdateDto dto) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        profile.setUpiId(dto.getUpiId().trim());
        profile.setUpiVerified(true);
        profile = profileRepository.save(profile);

        return ResponseEntity.ok(ApiResponse.success(profile, "UPI Payout ID updated to " + dto.getUpiId()));
    }

    @PostMapping("/withdraw")
    public ResponseEntity<ApiResponse<WithdrawalRequest>> requestWithdrawal(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody WithdrawalRequestDto dto) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        String destinationUpi = dto.getUpiId() != null && !dto.getUpiId().isBlank() 
                ? dto.getUpiId().trim() 
                : profile.getUpiId();

        if (destinationUpi == null || destinationUpi.isBlank()) {
            throw new BadRequestException("Please provide or configure a valid UPI ID for payout.");
        }

        WithdrawalRequest request = walletService.requestUpiWithdrawal(profile.getId(), dto.getAmount(), destinationUpi);
        return ResponseEntity.ok(ApiResponse.success(request, "Withdrawal request of ₹" + dto.getAmount() + " processed successfully."));
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TechnicianDashboardDto {
        private boolean isOnline;
        private long todayJobsCount;
        private BigDecimal todayEarnings;
        private long completedJobsCount;
        private BigDecimal totalEarnings;
        private BigDecimal availableBalance;
        private BigDecimal rating;
        private String savedUpiId;
        private List<WithdrawalRequest> payouts;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class JobStatusUpdateDto {
        @NotBlank
        private String status;
        private String startOtp;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class LocationUpdateDto {
        private Double latitude;
        private Double longitude;
        private Double heading;
        private Double speed;
        private UUID bookingId;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TelemetryEvent {
        private UUID technicianId;
        private UUID bookingId;
        private Double latitude;
        private Double longitude;
        private Double heading;
        private Double speed;
        private Instant timestamp;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OnlineStatusDto {
        private boolean online;
        private Double latitude;
        private Double longitude;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpiUpdateDto {
        @NotBlank
        private String upiId;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateTechnicianProfileDto {
        private String fullName;
        private String profileImageUrl;
        private String upiId;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class WithdrawalRequestDto {
        @NotNull(message = "Amount is required")
        @DecimalMin(value = "100.00", message = "Minimum withdrawal amount is ₹100.00")
        private BigDecimal amount;
        private String upiId;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TechnicianProfileResponseDto {
        private UUID id;
        private String technicianCode;
        private String fullName;
        private String phone;
        private String email;
        private String profileImageUrl;
        private BigDecimal rating;
        private int totalRatingsCount;
        private int totalJobsCompleted;
        private String kycStatus;
        private boolean isOnline;
        private String upiId;
        private boolean isUpiVerified;
    }
}
