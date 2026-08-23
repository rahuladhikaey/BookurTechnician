package com.bookurtechnician.dispatch.service;

import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.dispatch.entity.BookingProposal;
import com.bookurtechnician.dispatch.entity.DispatchMatchingConfig;
import com.bookurtechnician.dispatch.repository.BookingProposalRepository;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.technician.repository.TechnicianSkillRepository;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class DispatchService {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(DispatchService.class);

    private final TechnicianProfileRepository technicianProfileRepository;
    private final TechnicianSkillRepository technicianSkillRepository;
    private final BookingProposalRepository proposalRepository;
    private final BookingRepository bookingRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final com.bookurtechnician.notification.service.FcmNotificationService fcmNotificationService;
    private final com.bookurtechnician.dispatch.repository.DispatchMatchingConfigRepository matchingConfigRepository;
    private final com.bookurtechnician.servicecatalog.repository.SkillServiceCompatibilityRepository compatibilityRepository;

    public DispatchService(TechnicianProfileRepository technicianProfileRepository,
                           TechnicianSkillRepository technicianSkillRepository,
                           BookingProposalRepository proposalRepository,
                           BookingRepository bookingRepository,
                           SimpMessagingTemplate messagingTemplate,
                           com.bookurtechnician.notification.service.FcmNotificationService fcmNotificationService,
                           com.bookurtechnician.dispatch.repository.DispatchMatchingConfigRepository matchingConfigRepository,
                           com.bookurtechnician.servicecatalog.repository.SkillServiceCompatibilityRepository compatibilityRepository) {
        this.technicianProfileRepository = technicianProfileRepository;
        this.technicianSkillRepository = technicianSkillRepository;
        this.proposalRepository = proposalRepository;
        this.bookingRepository = bookingRepository;
        this.messagingTemplate = messagingTemplate;
        this.fcmNotificationService = fcmNotificationService;
        this.matchingConfigRepository = matchingConfigRepository;
        this.compatibilityRepository = compatibilityRepository;
    }

    @Transactional
    public void startSequentialDispatch(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + bookingId));

        if (booking.getAddress() == null || booking.getAddress().getCoordinates() == null) {
            log.warn("Booking {} has no valid GPS coordinates. Cannot perform spatial search.", booking.getBookingCode());
            booking.setStatus("NO_TECHNICIAN_AVAILABLE");
            bookingRepository.save(booking);
            broadcastBookingUpdate(booking, "Location coordinates missing for dispatch.");
            return;
        }

        DispatchMatchingConfig config = getEffectiveConfig();
        booking.setStatus("SEARCHING_TECHNICIAN");
        bookingRepository.save(booking);
        broadcastBookingUpdate(booking, "Searching for verified technicians within " + config.getSearchRadiusKm() + " km...");

        dispatchNextNearestTechnician(booking);
    }

    @Transactional
    public void dispatchNextNearestTechnician(Booking booking) {
        if (!"SEARCHING_TECHNICIAN".equals(booking.getStatus()) && !"TECHNICIAN_NOTIFIED".equals(booking.getStatus())) {
            log.info("Booking {} is already in status {}. Aborting next dispatch step.", booking.getBookingCode(), booking.getStatus());
            return;
        }

        DispatchMatchingConfig config = getEffectiveConfig();
        double radiusMeters = config.getSearchRadiusKm() * 1000.0;
        int timeoutSeconds = config.getNotificationTimeoutSeconds();

        double lat = booking.getAddress().getCoordinates().getY();
        double lng = booking.getAddress().getCoordinates().getX();

        // Query PostGIS for all online technicians within 15-km radius
        java.time.Instant freshnessCutoff = Instant.now().minus(java.time.Duration.ofHours(24));
        List<TechnicianProfile> nearbyTechnicians = technicianProfileRepository.findNearbyAvailableTechnicians(
                lat, lng, radiusMeters, freshnessCutoff, 25
        );

        UUID serviceCategoryId = (booking.getService() != null && booking.getService().getCategory() != null)
                ? booking.getService().getCategory().getId()
                : null;
        UUID serviceItemId = booking.getService() != null ? booking.getService().getId() : null;

        // Check if dispatch proposals have exceeded max attempts
        long priorAttempts = proposalRepository.findAll().stream()
                .filter(p -> p.getBooking() != null && p.getBooking().getId().equals(booking.getId()))
                .count();

        if (priorAttempts >= config.getMaxDispatchAttempts()) {
            log.info("Booking {} reached max dispatch attempts ({}). Escalating to Admin.", booking.getBookingCode(), priorAttempts);
            if (config.isAutoEscalateToAdmin()) {
                booking.setStatus("ADMIN_ESCALATION_REQUIRED");
                bookingRepository.save(booking);
                broadcastBookingUpdate(booking, "All nearest partners busy. Escalated to BookurTechnician Priority Operations Team.");
                return;
            }
        }

        // Find the first closest technician who has verified & compatible skills & hasn't been sent a proposal
        TechnicianProfile candidate = null;
        Double candidateDistance = null;

        for (TechnicianProfile tech : nearbyTechnicians) {
            boolean alreadyContacted = proposalRepository.existsByBookingIdAndTechnicianId(booking.getId(), tech.getId());
            if (!alreadyContacted) {
                // Intelligent Skill Match: Verify technician has active & verified skills for this service category or mapped compatibility
                boolean hasMatchingSkill = technicianSkillRepository.hasVerifiedSkillForCategoryOrSkill(
                        tech.getId(), serviceItemId, serviceCategoryId
                );

                // Check Skill Compatibility Matrix
                if (!hasMatchingSkill && serviceItemId != null) {
                    var techSkills = technicianSkillRepository.findByTechnicianIdOrderByCreatedAtAsc(tech.getId());
                    for (var ts : techSkills) {
                        if ("VERIFIED".equalsIgnoreCase(ts.getVerificationStatus()) && ts.isEnabled()) {
                            if (compatibilityRepository.existsBySkillIdAndServiceItemId(ts.getSkill().getId(), serviceItemId)) {
                                hasMatchingSkill = true;
                                break;
                            }
                        }
                    }
                }
                
                // Fallback for profiles without configured skills
                if (!hasMatchingSkill && !config.isStrictSkillMatching()) {
                    if (technicianSkillRepository.findByTechnicianIdOrderByCreatedAtAsc(tech.getId()).isEmpty()) {
                        hasMatchingSkill = true;
                    }
                }

                if (hasMatchingSkill) {
                    candidate = tech;
                    candidateDistance = technicianProfileRepository.calculateDistanceMeters(tech.getId(), lat, lng);
                    break;
                }
            }
        }

        if (candidate == null) {
            log.info("No more eligible online technicians within {} km for booking {}.", config.getSearchRadiusKm(), booking.getBookingCode());
            booking.setStatus("NO_TECHNICIAN_AVAILABLE");
            bookingRepository.save(booking);
            broadcastBookingUpdate(booking, "No technicians currently available within " + config.getSearchRadiusKm() + " km. Please try again shortly.");
            return;
        }

        double distanceMeters = candidateDistance != null ? candidateDistance : 1000.0;
        BigDecimal distanceKm = BigDecimal.valueOf(distanceMeters / 1000.0).setScale(1, RoundingMode.HALF_UP);
        BigDecimal earnings = booking.getTechnicianPayoutAmount() != null ? booking.getTechnicianPayoutAmount() : booking.getBasePrice().multiply(new BigDecimal("0.90"));

        Instant now = Instant.now();
        Instant expiresAt = now.plusSeconds(timeoutSeconds);

        BookingProposal proposal = BookingProposal.builder()
                .booking(booking)
                .technician(candidate)
                .distanceMeters(BigDecimal.valueOf(distanceMeters).setScale(2, RoundingMode.HALF_UP))
                .estimatedEarnings(earnings)
                .status("PENDING")
                .expiresAt(expiresAt)
                .build();

        proposal = proposalRepository.save(proposal);

        booking.setStatus("TECHNICIAN_NOTIFIED");
        bookingRepository.save(booking);

        log.info("Dispatched proposal {} for booking {} to closest technician {} ({} km away, timeout {}s)",
                proposal.getId(), booking.getBookingCode(), candidate.getTechnicianCode(), distanceKm, timeoutSeconds);

        // Build WebSocket payload for the notified technician
        JobProposalDto proposalDto = JobProposalDto.builder()
                .proposalId(proposal.getId())
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .serviceName(booking.getService().getName())
                .customerArea(booking.getAddress().getArea() + ", " + booking.getAddress().getCity())
                .distanceKm(distanceKm)
                .estimatedEarnings(earnings)
                .scheduleSlot(booking.getScheduleDate() + " (" + booking.getScheduleSlot() + ")")
                .expiresAt(expiresAt)
                .timeoutSeconds(timeoutSeconds)
                .build();

        try {
            messagingTemplate.convertAndSend("/topic/technician/" + candidate.getId() + "/proposals", proposalDto);
            messagingTemplate.convertAndSend("/topic/technician/" + candidate.getUser().getId() + "/proposals", proposalDto);
        } catch (Exception ex) {
            log.warn("WebSocket proposal notification warning: {}", ex.getMessage());
        }

        // Dispatch High-Priority Loud FCM Alert with Custom Ringtone
        try {
            String fcmToken = candidate.getUser() != null ? candidate.getUser().getFcmToken() : null;
            String customerName = booking.getCustomer() != null ? booking.getCustomer().getFullName() : "Customer";
            String customerAddress = booking.getAddress() != null 
                    ? (booking.getAddress().getArea() + ", " + booking.getAddress().getCity()) : "Nearby Location";

            fcmNotificationService.sendJobAlert(
                    fcmToken,
                    proposal.getId().toString(),
                    booking.getId().toString(),
                    booking.getService() != null ? booking.getService().getName() : "Service Request",
                    customerName,
                    customerAddress,
                    distanceKm.toString(),
                    earnings.toBigInteger().toString(),
                    timeoutSeconds
            );
        } catch (Exception ex) {
            log.error("Failed to send FCM Job Alert to candidate {}: {}", candidate.getTechnicianCode(), ex.getMessage());
        }

        broadcastBookingUpdate(booking, "Notified nearest partner (" + distanceKm + " km away). Awaiting acceptance...");
    }

    private DispatchMatchingConfig getEffectiveConfig() {
        return matchingConfigRepository.findFirstByOrderByCreatedAtAsc()
                .orElse(DispatchMatchingConfig.builder()
                        .searchRadiusKm(15.0)
                        .strictSkillMatching(true)
                        .notificationTimeoutSeconds(30)
                        .maxDispatchAttempts(5)
                        .autoEscalateToAdmin(true)
                        .build());
    }

    @Transactional
    public BookingProposal acceptProposal(UUID technicianUserId, UUID proposalId) {
        BookingProposal proposal = proposalRepository.findById(proposalId)
                .orElseThrow(() -> new ResourceNotFoundException("Proposal not found: " + proposalId));

        if (!proposal.getTechnician().getUser().getId().equals(technicianUserId)) {
            throw new BadRequestException("This proposal was not assigned to you.");
        }

        if (!"PENDING".equalsIgnoreCase(proposal.getStatus())) {
            throw new BadRequestException("Proposal is no longer valid (Status: " + proposal.getStatus() + ").");
        }

        if (Instant.now().isAfter(proposal.getExpiresAt())) {
            proposal.setStatus("EXPIRED");
            proposalRepository.save(proposal);
            throw new BadRequestException("Proposal has expired. Please wait for the next job request.");
        }

        Booking booking = proposal.getBooking();

        // Atomically lock and verify booking is still unassigned
        if ("ASSIGNED".equalsIgnoreCase(booking.getStatus()) || booking.getTechnician() != null) {
            proposal.setStatus("CANCELLED");
            proposalRepository.save(proposal);
            throw new BadRequestException("This booking was already assigned to another technician.");
        }

        // Mark accepted
        proposal.setStatus("ACCEPTED");
        proposal.setRespondedAt(Instant.now());
        proposalRepository.save(proposal);

        booking.setTechnician(proposal.getTechnician());
        booking.setStatus("ASSIGNED");
        bookingRepository.save(booking);

        log.info("Technician {} ACCEPTED booking {}. Proposal ID: {}",
                proposal.getTechnician().getTechnicianCode(), booking.getBookingCode(), proposal.getId());

        // Notify Customer in real-time
        broadcastBookingUpdate(booking, "Technician " + proposal.getTechnician().getUser().getFullName() + " accepted your booking!");

        return proposal;
    }

    @Transactional
    public void rejectProposal(UUID technicianUserId, UUID proposalId, String reason) {
        BookingProposal proposal = proposalRepository.findById(proposalId)
                .orElseThrow(() -> new ResourceNotFoundException("Proposal not found: " + proposalId));

        if (!proposal.getTechnician().getUser().getId().equals(technicianUserId)) {
            throw new BadRequestException("Unauthorized proposal rejection.");
        }

        if ("PENDING".equalsIgnoreCase(proposal.getStatus())) {
            proposal.setStatus("REJECTED");
            proposal.setRespondedAt(Instant.now());
            proposalRepository.save(proposal);

            log.info("Technician {} REJECTED proposal for booking {}. Proceeding to next nearest candidate.",
                    proposal.getTechnician().getTechnicianCode(), proposal.getBooking().getBookingCode());

            Booking booking = proposal.getBooking();
            booking.setStatus("SEARCHING_TECHNICIAN");
            bookingRepository.save(booking);

            dispatchNextNearestTechnician(booking);
        }
    }

    @Scheduled(fixedRate = 2000) // Scan for expired proposals every 2 seconds
    @Transactional
    public void processExpiredProposals() {
        List<BookingProposal> expired = proposalRepository.findExpiredPendingProposals(Instant.now());
        for (BookingProposal p : expired) {
            p.setStatus("EXPIRED");
            p.setRespondedAt(Instant.now());
            proposalRepository.save(p);

            log.info("Proposal {} for booking {} EXPIRED. Advancing to next nearest technician.",
                    p.getId(), p.getBooking().getBookingCode());

            Booking booking = p.getBooking();
            if ("TECHNICIAN_NOTIFIED".equalsIgnoreCase(booking.getStatus()) || "SEARCHING_TECHNICIAN".equalsIgnoreCase(booking.getStatus())) {
                booking.setStatus("SEARCHING_TECHNICIAN");
                bookingRepository.save(booking);
                dispatchNextNearestTechnician(booking);
            }
        }
    }

    private void broadcastBookingUpdate(Booking booking, String message) {
        try {
            DispatchStatusEvent event = DispatchStatusEvent.builder()
                    .bookingId(booking.getId())
                    .bookingCode(booking.getBookingCode())
                    .status(booking.getStatus())
                    .message(message)
                    .technicianName(booking.getTechnician() != null ? booking.getTechnician().getUser().getFullName() : null)
                    .technicianPhone(booking.getTechnician() != null ? booking.getTechnician().getUser().getPhone() : null)
                    .technicianCode(booking.getTechnician() != null ? booking.getTechnician().getTechnicianCode() : null)
                    .startServiceOtp(booking.getStartServiceOtp())
                    .timestamp(Instant.now())
                    .build();

            messagingTemplate.convertAndSend("/topic/booking/" + booking.getId(), event);
            messagingTemplate.convertAndSend("/topic/customer/" + booking.getCustomer().getId(), event);
        } catch (Exception ex) {
            log.warn("WebSocket dispatch broadcast error: {}", ex.getMessage());
        }
    }

    public static class JobProposalDto {
        private UUID proposalId;
        private UUID bookingId;
        private String bookingCode;
        private String serviceName;
        private String customerArea;
        private BigDecimal distanceKm;
        private BigDecimal estimatedEarnings;
        private String scheduleSlot;
        private Instant expiresAt;
        private int timeoutSeconds;

        public JobProposalDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID proposalId;
            private UUID bookingId;
            private String bookingCode;
            private String serviceName;
            private String customerArea;
            private BigDecimal distanceKm;
            private BigDecimal estimatedEarnings;
            private String scheduleSlot;
            private Instant expiresAt;
            private int timeoutSeconds;

            public Builder proposalId(UUID proposalId) { this.proposalId = proposalId; return this; }
            public Builder bookingId(UUID bookingId) { this.bookingId = bookingId; return this; }
            public Builder bookingCode(String bookingCode) { this.bookingCode = bookingCode; return this; }
            public Builder serviceName(String serviceName) { this.serviceName = serviceName; return this; }
            public Builder customerArea(String customerArea) { this.customerArea = customerArea; return this; }
            public Builder distanceKm(BigDecimal distanceKm) { this.distanceKm = distanceKm; return this; }
            public Builder estimatedEarnings(BigDecimal estimatedEarnings) { this.estimatedEarnings = estimatedEarnings; return this; }
            public Builder scheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; return this; }
            public Builder expiresAt(Instant expiresAt) { this.expiresAt = expiresAt; return this; }
            public Builder timeoutSeconds(int timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; return this; }

            public JobProposalDto build() {
                JobProposalDto dto = new JobProposalDto();
                dto.proposalId = this.proposalId;
                dto.bookingId = this.bookingId;
                dto.bookingCode = this.bookingCode;
                dto.serviceName = this.serviceName;
                dto.customerArea = this.customerArea;
                dto.distanceKm = this.distanceKm;
                dto.estimatedEarnings = this.estimatedEarnings;
                dto.scheduleSlot = this.scheduleSlot;
                dto.expiresAt = this.expiresAt;
                dto.timeoutSeconds = this.timeoutSeconds;
                return dto;
            }
        }

        public UUID getProposalId() { return proposalId; }
        public void setProposalId(UUID proposalId) { this.proposalId = proposalId; }
        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
        public String getBookingCode() { return bookingCode; }
        public void setBookingCode(String bookingCode) { this.bookingCode = bookingCode; }
        public String getServiceName() { return serviceName; }
        public void setServiceName(String serviceName) { this.serviceName = serviceName; }
        public String getCustomerArea() { return customerArea; }
        public void setCustomerArea(String customerArea) { this.customerArea = customerArea; }
        public BigDecimal getDistanceKm() { return distanceKm; }
        public void setDistanceKm(BigDecimal distanceKm) { this.distanceKm = distanceKm; }
        public BigDecimal getEstimatedEarnings() { return estimatedEarnings; }
        public void setEstimatedEarnings(BigDecimal estimatedEarnings) { this.estimatedEarnings = estimatedEarnings; }
        public String getScheduleSlot() { return scheduleSlot; }
        public void setScheduleSlot(String scheduleSlot) { this.scheduleSlot = scheduleSlot; }
        public Instant getExpiresAt() { return expiresAt; }
        public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
        public int getTimeoutSeconds() { return timeoutSeconds; }
        public void setTimeoutSeconds(int timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; }
    }

    public static class DispatchStatusEvent {
        private UUID bookingId;
        private String bookingCode;
        private String status;
        private String message;
        private String technicianName;
        private String technicianPhone;
        private String technicianCode;
        private String startServiceOtp;
        private Instant timestamp;

        public DispatchStatusEvent() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID bookingId;
            private String bookingCode;
            private String status;
            private String message;
            private String technicianName;
            private String technicianPhone;
            private String technicianCode;
            private String startServiceOtp;
            private Instant timestamp;

            public Builder bookingId(UUID bookingId) { this.bookingId = bookingId; return this; }
            public Builder bookingCode(String bookingCode) { this.bookingCode = bookingCode; return this; }
            public Builder status(String status) { this.status = status; return this; }
            public Builder message(String message) { this.message = message; return this; }
            public Builder technicianName(String technicianName) { this.technicianName = technicianName; return this; }
            public Builder technicianPhone(String technicianPhone) { this.technicianPhone = technicianPhone; return this; }
            public Builder technicianCode(String technicianCode) { this.technicianCode = technicianCode; return this; }
            public Builder startServiceOtp(String startServiceOtp) { this.startServiceOtp = startServiceOtp; return this; }
            public Builder timestamp(Instant timestamp) { this.timestamp = timestamp; return this; }

            public DispatchStatusEvent build() {
                DispatchStatusEvent ev = new DispatchStatusEvent();
                ev.bookingId = this.bookingId;
                ev.bookingCode = this.bookingCode;
                ev.status = this.status;
                ev.message = this.message;
                ev.technicianName = this.technicianName;
                ev.technicianPhone = this.technicianPhone;
                ev.technicianCode = this.technicianCode;
                ev.startServiceOtp = this.startServiceOtp;
                ev.timestamp = this.timestamp;
                return ev;
            }
        }

        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
        public String getBookingCode() { return bookingCode; }
        public void setBookingCode(String bookingCode) { this.bookingCode = bookingCode; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
        public String getTechnicianName() { return technicianName; }
        public void setTechnicianName(String technicianName) { this.technicianName = technicianName; }
        public String getTechnicianPhone() { return technicianPhone; }
        public void setTechnicianPhone(String technicianPhone) { this.technicianPhone = technicianPhone; }
        public String getTechnicianCode() { return technicianCode; }
        public void setTechnicianCode(String technicianCode) { this.technicianCode = technicianCode; }
        public String getStartServiceOtp() { return startServiceOtp; }
        public void setStartServiceOtp(String startServiceOtp) { this.startServiceOtp = startServiceOtp; }
        public Instant getTimestamp() { return timestamp; }
        public void setTimestamp(Instant timestamp) { this.timestamp = timestamp; }
    }
}
