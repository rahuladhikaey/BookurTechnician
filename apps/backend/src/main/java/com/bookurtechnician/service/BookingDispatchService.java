package com.bookurtechnician.service;

import com.bookurtechnician.model.BookingEntity;
import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.repository.BookingRepository;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingDispatchService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final BookingRepository bookingRepository;

    @Value("${technician.search-radius-km:15}")
    private double defaultRadiusKm;

    @Value("${technician.location-stale-seconds:60}")
    private int staleSeconds;

    private static final Set<String> ACTIVE_BOOKING_STATUSES = Set.of(
            "ACCEPTED", "DISPATCHED", "TECHNICIAN_ARRIVED", "IN_PROGRESS"
    );

    @Transactional(readOnly = true)
    public List<TechnicianProfile> findEligibleTechnicians(String serviceId, double lat, double lon, Double radiusKm) {
        double radius = (radiusKm != null && radiusKm > 0) ? radiusKm : defaultRadiusKm;
        double radiusMeters = radius * 1000.0;

        List<TechnicianProfile> candidates = technicianProfileRepository.findEligibleTechniciansForService(
                serviceId, lat, lon, radiusMeters, staleSeconds
        );

        if (candidates.isEmpty()) {
            log.info("ℹ️ No eligible technicians found within {} km for serviceId={}", radius, serviceId);
        }

        return candidates;
    }

    /**
     * Concurrency-safe assignment with transactional validation preventing double-booking
     */
    @Transactional(isolation = Isolation.SERIALIZABLE)
    public void assignTechnicianToBooking(String bookingId, String technicianId) {
        BookingEntity booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new IllegalArgumentException("Booking not found: " + bookingId));

        TechnicianProfile profile = technicianProfileRepository.findByTechnicianId(technicianId)
                .orElseThrow(() -> new IllegalArgumentException("Technician not found: " + technicianId));

        // Revalidate eligibility
        if (!Boolean.TRUE.equals(profile.getIsOnline()) ||
                "BUSY".equalsIgnoreCase(profile.getAvailabilityStatus()) ||
                !"VERIFIED".equalsIgnoreCase(profile.getKycStatus())) {
            throw new IllegalStateException("Technician " + technicianId + " is no longer available for assignment");
        }

        boolean hasActiveBooking = bookingRepository.existsByTechnicianIdAndStatusIn(technicianId, ACTIVE_BOOKING_STATUSES);
        if (hasActiveBooking) {
            throw new IllegalStateException("Technician " + technicianId + " is currently engaged in another active booking");
        }

        // Lock technician
        profile.setAvailabilityStatus("BUSY");
        technicianProfileRepository.save(profile);

        // Assign to booking
        booking.setTechnicianId(technicianId);
        booking.setStatus("ACCEPTED");
        bookingRepository.save(booking);

        log.info("✅ Concurrency-safe assignment confirmed: Booking {} assigned to Technician {}", bookingId, technicianId);
    }
}
