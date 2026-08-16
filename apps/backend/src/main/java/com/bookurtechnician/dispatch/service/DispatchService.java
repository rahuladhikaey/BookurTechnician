package com.bookurtechnician.dispatch.service;

import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.dispatch.entity.BookingProposal;
import com.bookurtechnician.dispatch.repository.BookingProposalRepository;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
@RequiredArgsConstructor
@Slf4j
public class DispatchService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final BookingProposalRepository proposalRepository;
    private final BookingRepository bookingRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public static final double DISPATCH_RADIUS_METERS = 10000.0; // 10.0 KM Max Radius
    public static final int PROPOSAL_TIMEOUT_SECONDS = 30; // 30s Countdown per candidate

    @Transactional
    public void startSequentialDispatch(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + bookingId));

        if (booking.getAddress() == null || booking.getAddress().getCoordinates() == null) {
            log.warn("Booking {} has no valid GPS coordinates. Cannot perform 10km spatial search.", booking.getBookingCode());
            booking.setStatus("NO_TECHNICIAN_AVAILABLE");
            bookingRepository.save(booking);
            broadcastBookingUpdate(booking, "Location coordinates missing for dispatch.");
            return;
        }

        booking.setStatus("SEARCHING_TECHNICIAN");
        bookingRepository.save(booking);
        broadcastBookingUpdate(booking, "Searching for nearest verified technicians within 10 km...");

        dispatchNextNearestTechnician(booking);
    }

    @Transactional
    public void dispatchNextNearestTechnician(Booking booking) {
        if (!"SEARCHING_TECHNICIAN".equals(booking.getStatus()) && !"TECHNICIAN_NOTIFIED".equals(booking.getStatus())) {
            log.info("Booking {} is already in status {}. Aborting next dispatch step.", booking.getBookingCode(), booking.getStatus());
            return;
        }

        double lat = booking.getAddress().getCoordinates().getY();
        double lng = booking.getAddress().getCoordinates().getX();

        // Query PostGIS for all online verified technicians within 10 KM, ordered by spatial distance ASC
        List<TechnicianProfile> nearbyTechnicians = technicianProfileRepository.findNearbyAvailableTechnicians(
                lat, lng, DISPATCH_RADIUS_METERS, 20
        );

        // Find the first closest technician who hasn't already been sent a proposal for this booking
        TechnicianProfile candidate = null;
        Double candidateDistance = null;

        for (TechnicianProfile tech : nearbyTechnicians) {
            boolean alreadyContacted = proposalRepository.existsByBookingIdAndTechnicianId(booking.getId(), tech.getId());
            if (!alreadyContacted) {
                candidate = tech;
                candidateDistance = technicianProfileRepository.calculateDistanceMeters(tech.getId(), lat, lng);
                break;
            }
        }

        if (candidate == null) {
            log.info("No more eligible online technicians within 10km for booking {}.", booking.getBookingCode());
            booking.setStatus("NO_TECHNICIAN_AVAILABLE");
            bookingRepository.save(booking);
            broadcastBookingUpdate(booking, "No technicians currently available within 10 km. Please try again shortly.");
            return;
        }

        double distanceMeters = candidateDistance != null ? candidateDistance : 1000.0;
        BigDecimal distanceKm = BigDecimal.valueOf(distanceMeters / 1000.0).setScale(1, RoundingMode.HALF_UP);
        BigDecimal earnings = booking.getTechnicianPayoutAmount() != null ? booking.getTechnicianPayoutAmount() : booking.getBasePrice().multiply(new BigDecimal("0.90"));

        Instant now = Instant.now();
        Instant expiresAt = now.plusSeconds(PROPOSAL_TIMEOUT_SECONDS);

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

        log.info("Dispatched proposal {} for booking {} to closest technician {} ({} km away)",
                proposal.getId(), booking.getBookingCode(), candidate.getTechnicianCode(), distanceKm);

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
                .timeoutSeconds(PROPOSAL_TIMEOUT_SECONDS)
                .build();

        try {
            messagingTemplate.convertAndSend("/topic/technician/" + candidate.getId() + "/proposals", proposalDto);
            messagingTemplate.convertAndSend("/topic/technician/" + candidate.getUser().getId() + "/proposals", proposalDto);
        } catch (Exception ex) {
            log.warn("WebSocket proposal notification warning: {}", ex.getMessage());
        }

        broadcastBookingUpdate(booking, "Notified nearest partner (" + distanceKm + " km away). Awaiting acceptance...");
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

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
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
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
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
    }
}
