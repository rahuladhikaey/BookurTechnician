package com.bookurtechnician.service;

import com.bookurtechnician.model.BookingEntity;
import com.bookurtechnician.model.DispatchAttemptEntity;
import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.repository.BookingRepository;
import com.bookurtechnician.repository.DispatchAttemptRepository;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingDispatchService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final BookingRepository bookingRepository;
    private final DispatchAttemptRepository dispatchAttemptRepository;

    @Value("${technician.search-radius-km:15}")
    private double defaultRadiusKm;

    @Value("${technician.location-stale-seconds:60}")
    private int staleSeconds;

    private static final Set<String> ACTIVE_BOOKING_STATUSES = Set.of(
            "ACCEPTED", "DISPATCHED", "TECHNICIAN_ON_THE_WAY", "TECHNICIAN_ARRIVED", "SERVICE_STARTED", "IN_PROGRESS"
    );

    @Transactional(readOnly = true)
    public List<TechnicianProfile> findEligibleTechnicians(String serviceId, double lat, double lon, Double radiusKm) {
        double radius = (radiusKm != null && radiusKm > 0) ? radiusKm : defaultRadiusKm;
        double radiusMeters = radius * 1000.0;

        List<TechnicianProfile> candidates = technicianProfileRepository.findEligibleTechniciansForService(
                serviceId, lat, lon, radiusMeters, staleSeconds
        );

        if (candidates.isEmpty()) {
            log.info("ℹ️ [Dispatch] No eligible technicians found within {} km for serviceId={}", radius, serviceId);
        }

        return candidates;
    }

    /**
     * Finds next nearest un-attempted eligible technician and registers dispatch attempt
     */
    @Transactional
    public Optional<TechnicianProfile> dispatchNextTechnician(String bookingId) {
        BookingEntity booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new IllegalArgumentException("Booking not found: " + bookingId));

        if (booking.getLatitude() == null || booking.getLongitude() == null) {
            log.warn("⚠️ [Dispatch] Booking {} has no GPS coordinates", bookingId);
            return Optional.empty();
        }

        List<TechnicianProfile> candidates = findEligibleTechnicians(
                booking.getServiceId(),
                booking.getLatitude(),
                booking.getLongitude(),
                defaultRadiusKm
        );

        List<DispatchAttemptEntity> existingAttempts = dispatchAttemptRepository.findByBookingIdOrderByAttemptNumberAsc(bookingId);
        Set<String> alreadyAttemptedTechIds = existingAttempts.stream()
                .map(DispatchAttemptEntity::getTechnicianId)
                .collect(java.util.stream.Collectors.toSet());

        // Find closest candidate not yet attempted
        Optional<TechnicianProfile> nextCandidate = candidates.stream()
                .filter(t -> !alreadyAttemptedTechIds.contains(t.getTechnicianId()))
                .findFirst();

        if (nextCandidate.isEmpty()) {
            log.warn("⚠️ [Dispatch] All eligible technicians exhausted within 15KM for booking {}. Marking DISPATCH_FAILED.", bookingId);
            booking.setStatus("DISPATCH_FAILED");
            booking.setUpdatedAt(OffsetDateTime.now());
            bookingRepository.save(booking);
            return Optional.empty();
        }

        TechnicianProfile targetTech = nextCandidate.get();
        int nextAttemptNumber = existingAttempts.size() + 1;

        double distanceKm = calculateDistance(
                booking.getLatitude(), booking.getLongitude(),
                targetTech.getCurrentLatitude(), targetTech.getCurrentLongitude()
        );

        DispatchAttemptEntity attempt = DispatchAttemptEntity.builder()
                .id("dsp_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16))
                .bookingId(bookingId)
                .technicianId(targetTech.getTechnicianId())
                .distanceKm(BigDecimal.valueOf(distanceKm))
                .attemptNumber(nextAttemptNumber)
                .status("PENDING")
                .sentAt(OffsetDateTime.now())
                .build();

        dispatchAttemptRepository.save(attempt);

        booking.setStatus("TECHNICIAN_REQUESTED");
        booking.setUpdatedAt(OffsetDateTime.now());
        bookingRepository.save(booking);

        log.info("🚀 [Dispatch] Attempt #{} dispatched: Booking {} -> Technician {} ({} KM away)",
                nextAttemptNumber, bookingId, targetTech.getTechnicianId(), distanceKm);

        return Optional.of(targetTech);
    }

    /**
     * Concurrency-safe atomic acceptance preventing double-booking
     */
    @Transactional(isolation = Isolation.SERIALIZABLE)
    public void acceptBooking(String bookingId, String technicianId) {
        BookingEntity booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new IllegalArgumentException("Booking not found: " + bookingId));

        if (!"TECHNICIAN_REQUESTED".equalsIgnoreCase(booking.getStatus()) &&
                !"SEARCHING_TECHNICIAN".equalsIgnoreCase(booking.getStatus()) &&
                !"PENDING".equalsIgnoreCase(booking.getStatus())) {
            throw new IllegalStateException("BOOKING_ALREADY_ASSIGNED: Status is " + booking.getStatus());
        }

        TechnicianProfile profile = technicianProfileRepository.findByTechnicianId(technicianId)
                .orElseThrow(() -> new IllegalArgumentException("Technician not found: " + technicianId));

        if (!Boolean.TRUE.equals(profile.getIsOnline()) || "BUSY".equalsIgnoreCase(profile.getAvailabilityStatus())) {
            throw new IllegalStateException("Technician is no longer available");
        }

        boolean hasActiveBooking = bookingRepository.existsByTechnicianIdAndStatusIn(technicianId, ACTIVE_BOOKING_STATUSES);
        if (hasActiveBooking) {
            throw new IllegalStateException("Technician is currently engaged in another active booking");
        }

        // Update dispatch attempt record
        Optional<DispatchAttemptEntity> attemptOpt = dispatchAttemptRepository.findFirstByBookingIdAndStatus(bookingId, "PENDING");
        attemptOpt.ifPresent(attempt -> {
            attempt.setStatus("ACCEPTED");
            attempt.setRespondedAt(OffsetDateTime.now());
            dispatchAttemptRepository.save(attempt);
        });

        // Assign
        profile.setAvailabilityStatus("BUSY");
        profile.setUpdatedAt(OffsetDateTime.now());
        technicianProfileRepository.save(profile);

        booking.setTechnicianId(technicianId);
        booking.setStatus("TECHNICIAN_ASSIGNED");
        booking.setUpdatedAt(OffsetDateTime.now());
        bookingRepository.save(booking);

        log.info("✅ [Dispatch] Booking {} successfully accepted by Technician {}", bookingId, technicianId);
    }

    /**
     * Rejection handler -> advances to next nearest candidate
     */
    @Transactional
    public void rejectBooking(String bookingId, String technicianId, String reason) {
        Optional<DispatchAttemptEntity> attemptOpt = dispatchAttemptRepository.findFirstByBookingIdAndStatus(bookingId, "PENDING");
        attemptOpt.ifPresent(attempt -> {
            attempt.setStatus("REJECTED");
            attempt.setRespondedAt(OffsetDateTime.now());
            attempt.setRejectionReason(reason);
            dispatchAttemptRepository.save(attempt);
        });

        log.info("❌ [Dispatch] Technician {} rejected booking {}. Finding next nearest candidate...", technicianId, bookingId);
        dispatchNextTechnician(bookingId);
    }

    /**
     * Timeout handler (30s elapsed) -> advances to next candidate
     */
    @Transactional
    public void timeoutBooking(String bookingId, String technicianId) {
        Optional<DispatchAttemptEntity> attemptOpt = dispatchAttemptRepository.findFirstByBookingIdAndStatus(bookingId, "PENDING");
        attemptOpt.ifPresent(attempt -> {
            attempt.setStatus("TIMEOUT");
            attempt.setRespondedAt(OffsetDateTime.now());
            dispatchAttemptRepository.save(attempt);
        });

        log.info("⏱️ [Dispatch] Timeout for Technician {} on booking {}. Finding next candidate...", technicianId, bookingId);
        dispatchNextTechnician(bookingId);
    }

    /**
     * Lifecycle Status Transitions
     */
    @Transactional
    public void updateBookingStatus(String bookingId, String newStatus) {
        BookingEntity booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new IllegalArgumentException("Booking not found: " + bookingId));

        booking.setStatus(newStatus);
        booking.setUpdatedAt(OffsetDateTime.now());

        if ("SERVICE_COMPLETED".equalsIgnoreCase(newStatus) || "COMPLETED".equalsIgnoreCase(newStatus) || "CANCELLED".equalsIgnoreCase(newStatus)) {
            if (booking.getTechnicianId() != null) {
                technicianProfileRepository.findByTechnicianId(booking.getTechnicianId()).ifPresent(profile -> {
                    profile.setAvailabilityStatus("AVAILABLE");
                    profile.setUpdatedAt(OffsetDateTime.now());
                    technicianProfileRepository.save(profile);
                });
            }
        }

        bookingRepository.save(booking);
        log.info("🔄 [Booking] Status transition: Booking {} -> {}", bookingId, newStatus);
    }

    private double calculateDistance(Double lat1, Double lon1, Double lat2, Double lon2) {
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return 0.0;
        double earthRadius = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                        Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Math.round(earthRadius * c * 100.0) / 100.0;
    }
}
