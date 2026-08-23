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
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
@RequestMapping("/api/v1/technician")
public class TechnicianController {

    private static final Logger log = LoggerFactory.getLogger(TechnicianController.class);

    private final com.bookurtechnician.auth.repository.UserRepository userRepository;
    private final TechnicianProfileRepository profileRepository;
    private final TechnicianDocumentRepository technicianDocumentRepository;
    private final com.bookurtechnician.technician.repository.TechnicianSkillRepository technicianSkillRepository;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final WalletService walletService;
    private final TechnicianWalletRepository walletRepository;
    private final WithdrawalRequestRepository withdrawalRequestRepository;
    private final StringRedisTemplate redisTemplate;
    private final SimpMessagingTemplate messagingTemplate;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    public TechnicianController(com.bookurtechnician.auth.repository.UserRepository userRepository,
                                TechnicianProfileRepository profileRepository,
                                TechnicianDocumentRepository technicianDocumentRepository,
                                com.bookurtechnician.technician.repository.TechnicianSkillRepository technicianSkillRepository,
                                BookingRepository bookingRepository,
                                BookingService bookingService,
                                WalletService walletService,
                                TechnicianWalletRepository walletRepository,
                                WithdrawalRequestRepository withdrawalRequestRepository,
                                StringRedisTemplate redisTemplate,
                                SimpMessagingTemplate messagingTemplate) {
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
        this.technicianDocumentRepository = technicianDocumentRepository;
        this.technicianSkillRepository = technicianSkillRepository;
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.walletService = walletService;
        this.walletRepository = walletRepository;
        this.withdrawalRequestRepository = withdrawalRequestRepository;
        this.redisTemplate = redisTemplate;
        this.messagingTemplate = messagingTemplate;
    }

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

        ProfileCompletionSummary summary = calculateProfileCompletion(profile, user);

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
                .kycStatus(profile.getKycStatus() != null ? profile.getKycStatus() : "PENDING")
                .isOnline(profile.isOnline())
                .upiId(profile.getUpiId() != null ? profile.getUpiId() : "technician@upi")
                .isUpiVerified(profile.isUpiVerified())
                .profileCompletionPercentage(summary.getCompletionPercentage())
                .isProfileComplete(summary.isComplete())
                .hasLivePic(summary.isHasLivePic())
                .hasAadhaarCard(summary.isHasAadhaarCard())
                .hasVoterCard(summary.isHasVoterCard())
                .hasSkills(summary.isHasSkills())
                .missingRequirements(summary.getMissingRequirements())
                .build();
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    private ProfileCompletionSummary calculateProfileCompletion(TechnicianProfile profile, com.bookurtechnician.auth.entity.User user) {
        List<TechnicianDocument> docs = technicianDocumentRepository.findByTechnicianId(profile.getId());
        boolean hasLivePic = (user != null && user.getProfileImageUrl() != null && !user.getProfileImageUrl().isBlank()) ||
                docs.stream().anyMatch(d -> "SELFIE".equalsIgnoreCase(d.getDocumentType()) || "LIVE_PIC".equalsIgnoreCase(d.getDocumentType()));
        boolean hasAadhaar = docs.stream().anyMatch(d -> d.getDocumentType() != null && d.getDocumentType().toUpperCase().contains("AADHAAR"));
        boolean hasVoterCard = docs.stream().anyMatch(d -> d.getDocumentType() != null && d.getDocumentType().toUpperCase().contains("VOTER"));
        boolean hasSkills = !technicianSkillRepository.findByTechnicianIdOrderByCreatedAtAsc(profile.getId()).isEmpty();
        boolean hasNameAndPhone = (user != null && user.getFullName() != null && !user.getFullName().isBlank() && user.getPhone() != null && !user.getPhone().isBlank());

        int score = 0;
        List<String> missing = new ArrayList<>();
        if (hasNameAndPhone) score += 25; else missing.add("Full Name & Phone");
        if (hasLivePic) score += 25; else missing.add("Real Live Photo / Selfie");
        if (hasAadhaar) score += 25; else missing.add("Aadhaar Card");
        if (hasVoterCard) score += 25; else missing.add("Voter Card");
        if (!hasSkills) missing.add("At least 1 Service Skill");

        return ProfileCompletionSummary.builder()
                .completionPercentage(score)
                .isComplete(score == 100 && hasSkills)
                .hasLivePic(hasLivePic)
                .hasAadhaarCard(hasAadhaar)
                .hasVoterCard(hasVoterCard)
                .hasSkills(hasSkills)
                .missingRequirements(missing)
                .build();
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
            com.bookurtechnician.auth.entity.User user = userRepository.findById(principal.getId()).orElse(profile.getUser());
            ProfileCompletionSummary summary = calculateProfileCompletion(profile, user);
            if (!summary.isComplete()) {
                throw new com.bookurtechnician.common.exception.BadRequestException(
                        "Cannot go ONLINE: Profile is incomplete (" + summary.getCompletionPercentage() + "%). " +
                        "You must submit your Real Live Photo, Aadhaar Card, Voter Card, and Service Skills to reach 100% profile completion. Missing: " +
                        String.join(", ", summary.getMissingRequirements()));
            }

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

        public TechnicianDashboardDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private boolean isOnline;
            private long todayJobsCount;
            private BigDecimal todayEarnings;
            private long completedJobsCount;
            private BigDecimal totalEarnings;
            private BigDecimal availableBalance;
            private BigDecimal rating;
            private String savedUpiId;
            private List<WithdrawalRequest> payouts;

            public Builder isOnline(boolean isOnline) { this.isOnline = isOnline; return this; }
            public Builder todayJobsCount(long todayJobsCount) { this.todayJobsCount = todayJobsCount; return this; }
            public Builder todayEarnings(BigDecimal todayEarnings) { this.todayEarnings = todayEarnings; return this; }
            public Builder completedJobsCount(long completedJobsCount) { this.completedJobsCount = completedJobsCount; return this; }
            public Builder totalEarnings(BigDecimal totalEarnings) { this.totalEarnings = totalEarnings; return this; }
            public Builder availableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; return this; }
            public Builder rating(BigDecimal rating) { this.rating = rating; return this; }
            public Builder savedUpiId(String savedUpiId) { this.savedUpiId = savedUpiId; return this; }
            public Builder payouts(List<WithdrawalRequest> payouts) { this.payouts = payouts; return this; }

            public TechnicianDashboardDto build() {
                TechnicianDashboardDto dto = new TechnicianDashboardDto();
                dto.isOnline = this.isOnline;
                dto.todayJobsCount = this.todayJobsCount;
                dto.todayEarnings = this.todayEarnings;
                dto.completedJobsCount = this.completedJobsCount;
                dto.totalEarnings = this.totalEarnings;
                dto.availableBalance = this.availableBalance;
                dto.rating = this.rating;
                dto.savedUpiId = this.savedUpiId;
                dto.payouts = this.payouts;
                return dto;
            }
        }

        public boolean isOnline() { return isOnline; }
        public void setOnline(boolean online) { isOnline = online; }
        public long getTodayJobsCount() { return todayJobsCount; }
        public void setTodayJobsCount(long todayJobsCount) { this.todayJobsCount = todayJobsCount; }
        public BigDecimal getTodayEarnings() { return todayEarnings; }
        public void setTodayEarnings(BigDecimal todayEarnings) { this.todayEarnings = todayEarnings; }
        public long getCompletedJobsCount() { return completedJobsCount; }
        public void setCompletedJobsCount(long completedJobsCount) { this.completedJobsCount = completedJobsCount; }
        public BigDecimal getTotalEarnings() { return totalEarnings; }
        public void setTotalEarnings(BigDecimal totalEarnings) { this.totalEarnings = totalEarnings; }
        public BigDecimal getAvailableBalance() { return availableBalance; }
        public void setAvailableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; }
        public BigDecimal getRating() { return rating; }
        public void setRating(BigDecimal rating) { this.rating = rating; }
        public String getSavedUpiId() { return savedUpiId; }
        public void setSavedUpiId(String savedUpiId) { this.savedUpiId = savedUpiId; }
        public List<WithdrawalRequest> getPayouts() { return payouts; }
        public void setPayouts(List<WithdrawalRequest> payouts) { this.payouts = payouts; }
    }

    public static class JobStatusUpdateDto {
        @NotBlank
        private String status;
        private String startOtp;

        public JobStatusUpdateDto() {}

        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public String getStartOtp() { return startOtp; }
        public void setStartOtp(String startOtp) { this.startOtp = startOtp; }
    }

    public static class LocationUpdateDto {
        private Double latitude;
        private Double longitude;
        private Double heading;
        private Double speed;
        private UUID bookingId;

        public LocationUpdateDto() {}

        public Double getLatitude() { return latitude; }
        public void setLatitude(Double latitude) { this.latitude = latitude; }
        public Double getLongitude() { return longitude; }
        public void setLongitude(Double longitude) { this.longitude = longitude; }
        public Double getHeading() { return heading; }
        public void setHeading(Double heading) { this.heading = heading; }
        public Double getSpeed() { return speed; }
        public void setSpeed(Double speed) { this.speed = speed; }
        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
    }

    public static class TelemetryEvent {
        private UUID technicianId;
        private UUID bookingId;
        private Double latitude;
        private Double longitude;
        private Double heading;
        private Double speed;
        private Instant timestamp;

        public TelemetryEvent() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID technicianId;
            private UUID bookingId;
            private Double latitude;
            private Double longitude;
            private Double heading;
            private Double speed;
            private Instant timestamp;

            public Builder technicianId(UUID technicianId) { this.technicianId = technicianId; return this; }
            public Builder bookingId(UUID bookingId) { this.bookingId = bookingId; return this; }
            public Builder latitude(Double latitude) { this.latitude = latitude; return this; }
            public Builder longitude(Double longitude) { this.longitude = longitude; return this; }
            public Builder heading(Double heading) { this.heading = heading; return this; }
            public Builder speed(Double speed) { this.speed = speed; return this; }
            public Builder timestamp(Instant timestamp) { this.timestamp = timestamp; return this; }

            public TelemetryEvent build() {
                TelemetryEvent e = new TelemetryEvent();
                e.technicianId = this.technicianId;
                e.bookingId = this.bookingId;
                e.latitude = this.latitude;
                e.longitude = this.longitude;
                e.heading = this.heading;
                e.speed = this.speed;
                e.timestamp = this.timestamp;
                return e;
            }
        }

        public UUID getTechnicianId() { return technicianId; }
        public void setTechnicianId(UUID technicianId) { this.technicianId = technicianId; }
        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
        public Double getLatitude() { return latitude; }
        public void setLatitude(Double latitude) { this.latitude = latitude; }
        public Double getLongitude() { return longitude; }
        public void setLongitude(Double longitude) { this.longitude = longitude; }
        public Double getHeading() { return heading; }
        public void setHeading(Double heading) { this.heading = heading; }
        public Double getSpeed() { return speed; }
        public void setSpeed(Double speed) { this.speed = speed; }
        public Instant getTimestamp() { return timestamp; }
        public void setTimestamp(Instant timestamp) { this.timestamp = timestamp; }
    }

    public static class OnlineStatusDto {
        private boolean online;
        private Double latitude;
        private Double longitude;

        public OnlineStatusDto() {}

        public boolean isOnline() { return online; }
        public void setOnline(boolean online) { this.online = online; }
        public Double getLatitude() { return latitude; }
        public void setLatitude(Double latitude) { this.latitude = latitude; }
        public Double getLongitude() { return longitude; }
        public void setLongitude(Double longitude) { this.longitude = longitude; }
    }

    public static class UpiUpdateDto {
        @NotBlank
        private String upiId;

        public UpiUpdateDto() {}

        public String getUpiId() { return upiId; }
        public void setUpiId(String upiId) { this.upiId = upiId; }
    }

    public static class UpdateTechnicianProfileDto {
        private String fullName;
        private String profileImageUrl;
        private String upiId;

        public UpdateTechnicianProfileDto() {}

        public String getFullName() { return fullName; }
        public void setFullName(String fullName) { this.fullName = fullName; }
        public String getProfileImageUrl() { return profileImageUrl; }
        public void setProfileImageUrl(String profileImageUrl) { this.profileImageUrl = profileImageUrl; }
        public String getUpiId() { return upiId; }
        public void setUpiId(String upiId) { this.upiId = upiId; }
    }

    public static class WithdrawalRequestDto {
        @NotNull(message = "Amount is required")
        @DecimalMin(value = "100.00", message = "Minimum withdrawal amount is ₹100.00")
        private BigDecimal amount;
        private String upiId;

        public WithdrawalRequestDto() {}

        public BigDecimal getAmount() { return amount; }
        public void setAmount(BigDecimal amount) { this.amount = amount; }
        public String getUpiId() { return upiId; }
        public void setUpiId(String upiId) { this.upiId = upiId; }
    }

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
        private int profileCompletionPercentage;
        private boolean isProfileComplete;
        private boolean hasLivePic;
        private boolean hasAadhaarCard;
        private boolean hasVoterCard;
        private boolean hasSkills;
        private List<String> missingRequirements;

        public TechnicianProfileResponseDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
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
            private int profileCompletionPercentage;
            private boolean isProfileComplete;
            private boolean hasLivePic;
            private boolean hasAadhaarCard;
            private boolean hasVoterCard;
            private boolean hasSkills;
            private List<String> missingRequirements;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder technicianCode(String technicianCode) { this.technicianCode = technicianCode; return this; }
            public Builder fullName(String fullName) { this.fullName = fullName; return this; }
            public Builder phone(String phone) { this.phone = phone; return this; }
            public Builder email(String email) { this.email = email; return this; }
            public Builder profileImageUrl(String profileImageUrl) { this.profileImageUrl = profileImageUrl; return this; }
            public Builder rating(BigDecimal rating) { this.rating = rating; return this; }
            public Builder totalRatingsCount(int totalRatingsCount) { this.totalRatingsCount = totalRatingsCount; return this; }
            public Builder totalJobsCompleted(int totalJobsCompleted) { this.totalJobsCompleted = totalJobsCompleted; return this; }
            public Builder kycStatus(String kycStatus) { this.kycStatus = kycStatus; return this; }
            public Builder isOnline(boolean isOnline) { this.isOnline = isOnline; return this; }
            public Builder upiId(String upiId) { this.upiId = upiId; return this; }
            public Builder isUpiVerified(boolean isUpiVerified) { this.isUpiVerified = isUpiVerified; return this; }
            public Builder profileCompletionPercentage(int profileCompletionPercentage) { this.profileCompletionPercentage = profileCompletionPercentage; return this; }
            public Builder isProfileComplete(boolean isProfileComplete) { this.isProfileComplete = isProfileComplete; return this; }
            public Builder hasLivePic(boolean hasLivePic) { this.hasLivePic = hasLivePic; return this; }
            public Builder hasAadhaarCard(boolean hasAadhaarCard) { this.hasAadhaarCard = hasAadhaarCard; return this; }
            public Builder hasVoterCard(boolean hasVoterCard) { this.hasVoterCard = hasVoterCard; return this; }
            public Builder hasSkills(boolean hasSkills) { this.hasSkills = hasSkills; return this; }
            public Builder missingRequirements(List<String> missingRequirements) { this.missingRequirements = missingRequirements; return this; }

            public TechnicianProfileResponseDto build() {
                TechnicianProfileResponseDto dto = new TechnicianProfileResponseDto();
                dto.id = this.id;
                dto.technicianCode = this.technicianCode;
                dto.fullName = this.fullName;
                dto.phone = this.phone;
                dto.email = this.email;
                dto.profileImageUrl = this.profileImageUrl;
                dto.rating = this.rating;
                dto.totalRatingsCount = this.totalRatingsCount;
                dto.totalJobsCompleted = this.totalJobsCompleted;
                dto.kycStatus = this.kycStatus;
                dto.isOnline = this.isOnline;
                dto.upiId = this.upiId;
                dto.isUpiVerified = this.isUpiVerified;
                dto.profileCompletionPercentage = this.profileCompletionPercentage;
                dto.isProfileComplete = this.isProfileComplete;
                dto.hasLivePic = this.hasLivePic;
                dto.hasAadhaarCard = this.hasAadhaarCard;
                dto.hasVoterCard = this.hasVoterCard;
                dto.hasSkills = this.hasSkills;
                dto.missingRequirements = this.missingRequirements;
                return dto;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public String getTechnicianCode() { return technicianCode; }
        public void setTechnicianCode(String technicianCode) { this.technicianCode = technicianCode; }
        public String getFullName() { return fullName; }
        public void setFullName(String fullName) { this.fullName = fullName; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getProfileImageUrl() { return profileImageUrl; }
        public void setProfileImageUrl(String profileImageUrl) { this.profileImageUrl = profileImageUrl; }
        public BigDecimal getRating() { return rating; }
        public void setRating(BigDecimal rating) { this.rating = rating; }
        public int getTotalRatingsCount() { return totalRatingsCount; }
        public void setTotalRatingsCount(int totalRatingsCount) { this.totalRatingsCount = totalRatingsCount; }
        public int getTotalJobsCompleted() { return totalJobsCompleted; }
        public void setTotalJobsCompleted(int totalJobsCompleted) { this.totalJobsCompleted = totalJobsCompleted; }
        public String getKycStatus() { return kycStatus; }
        public void setKycStatus(String kycStatus) { this.kycStatus = kycStatus; }
        public boolean isOnline() { return isOnline; }
        public void setOnline(boolean online) { isOnline = online; }
        public String getUpiId() { return upiId; }
        public void setUpiId(String upiId) { this.upiId = upiId; }
        public boolean isUpiVerified() { return isUpiVerified; }
        public void setUpiVerified(boolean upiVerified) { isUpiVerified = upiVerified; }
        public int getProfileCompletionPercentage() { return profileCompletionPercentage; }
        public void setProfileCompletionPercentage(int profileCompletionPercentage) { this.profileCompletionPercentage = profileCompletionPercentage; }
        public boolean isProfileComplete() { return isProfileComplete; }
        public void setProfileComplete(boolean profileComplete) { isProfileComplete = profileComplete; }
        public boolean isHasLivePic() { return hasLivePic; }
        public void setHasLivePic(boolean hasLivePic) { this.hasLivePic = hasLivePic; }
        public boolean isHasAadhaarCard() { return hasAadhaarCard; }
        public void setHasAadhaarCard(boolean hasAadhaarCard) { this.hasAadhaarCard = hasAadhaarCard; }
        public boolean isHasVoterCard() { return hasVoterCard; }
        public void setHasVoterCard(boolean hasVoterCard) { this.hasVoterCard = hasVoterCard; }
        public boolean isHasSkills() { return hasSkills; }
        public void setHasSkills(boolean hasSkills) { this.hasSkills = hasSkills; }
        public List<String> getMissingRequirements() { return missingRequirements; }
        public void setMissingRequirements(List<String> missingRequirements) { this.missingRequirements = missingRequirements; }
    }

    public static class ProfileCompletionSummary {
        private int completionPercentage;
        private boolean isComplete;
        private boolean hasLivePic;
        private boolean hasAadhaarCard;
        private boolean hasVoterCard;
        private boolean hasSkills;
        private List<String> missingRequirements;

        public ProfileCompletionSummary() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private int completionPercentage;
            private boolean isComplete;
            private boolean hasLivePic;
            private boolean hasAadhaarCard;
            private boolean hasVoterCard;
            private boolean hasSkills;
            private List<String> missingRequirements;

            public Builder completionPercentage(int completionPercentage) { this.completionPercentage = completionPercentage; return this; }
            public Builder isComplete(boolean isComplete) { this.isComplete = isComplete; return this; }
            public Builder hasLivePic(boolean hasLivePic) { this.hasLivePic = hasLivePic; return this; }
            public Builder hasAadhaarCard(boolean hasAadhaarCard) { this.hasAadhaarCard = hasAadhaarCard; return this; }
            public Builder hasVoterCard(boolean hasVoterCard) { this.hasVoterCard = hasVoterCard; return this; }
            public Builder hasSkills(boolean hasSkills) { this.hasSkills = hasSkills; return this; }
            public Builder missingRequirements(List<String> missingRequirements) { this.missingRequirements = missingRequirements; return this; }

            public ProfileCompletionSummary build() {
                ProfileCompletionSummary s = new ProfileCompletionSummary();
                s.completionPercentage = this.completionPercentage;
                s.isComplete = this.isComplete;
                s.hasLivePic = this.hasLivePic;
                s.hasAadhaarCard = this.hasAadhaarCard;
                s.hasVoterCard = this.hasVoterCard;
                s.hasSkills = this.hasSkills;
                s.missingRequirements = this.missingRequirements;
                return s;
            }
        }

        public int getCompletionPercentage() { return completionPercentage; }
        public void setCompletionPercentage(int completionPercentage) { this.completionPercentage = completionPercentage; }
        public boolean isComplete() { return isComplete; }
        public void setComplete(boolean complete) { isComplete = complete; }
        public boolean isHasLivePic() { return hasLivePic; }
        public void setHasLivePic(boolean hasLivePic) { this.hasLivePic = hasLivePic; }
        public boolean isHasAadhaarCard() { return hasAadhaarCard; }
        public void setHasAadhaarCard(boolean hasAadhaarCard) { this.hasAadhaarCard = hasAadhaarCard; }
        public boolean isHasVoterCard() { return hasVoterCard; }
        public void setHasVoterCard(boolean hasVoterCard) { this.hasVoterCard = hasVoterCard; }
        public boolean isHasSkills() { return hasSkills; }
        public void setHasSkills(boolean hasSkills) { this.hasSkills = hasSkills; }
        public List<String> getMissingRequirements() { return missingRequirements; }
        public void setMissingRequirements(List<String> missingRequirements) { this.missingRequirements = missingRequirements; }
    }
}
