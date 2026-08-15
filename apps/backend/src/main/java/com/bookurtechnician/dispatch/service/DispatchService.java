package com.bookurtechnician.dispatch.service;

import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class DispatchService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public TechnicianProfile autoAssignNearbyTechnician(Booking booking) {
        if (booking.getAddress().getCoordinates() == null) {
            log.warn("Booking {} address coordinates are null. Skipping PostGIS radius dispatch.", booking.getBookingCode());
            return null;
        }

        double lat = booking.getAddress().getCoordinates().getY();
        double lng = booking.getAddress().getCoordinates().getX();
        double radiusMeters = 5000.0; // 5.0 KM

        List<TechnicianProfile> candidates = technicianProfileRepository.findNearbyAvailableTechnicians(
                lat, lng, radiusMeters, 1
        );

        if (!candidates.isEmpty()) {
            TechnicianProfile assignedTech = candidates.get(0);
            log.info("Auto-assigned booking {} to nearby technician {}", booking.getBookingCode(), assignedTech.getTechnicianCode());

            // Broadcast job proposal to assigned technician WebSocket channel
            try {
                messagingTemplate.convertAndSend("/topic/technician/" + assignedTech.getId() + "/jobs", booking.getBookingCode());
            } catch (Exception ex) {
                log.warn("WebSocket dispatch broadcast notification failed: {}", ex.getMessage());
            }

            return assignedTech;
        }

        log.info("No online verified technicians found within 5km radius for booking {}", booking.getBookingCode());
        return null;
    }
}
