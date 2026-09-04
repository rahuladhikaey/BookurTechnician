package com.bookurtechnician.service;

import com.bookurtechnician.dto.AvailabilityResponse;
import com.bookurtechnician.dto.ServiceAvailabilityDto;
import com.bookurtechnician.repository.ServiceCountProjection;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class TechnicianAvailabilityService {

    private final TechnicianProfileRepository technicianProfileRepository;

    @Value("${technician.search-radius-km:15}")
    private double defaultRadiusKm;

    @Value("${technician.location-stale-seconds:60}")
    private int staleSeconds;

    @Transactional(readOnly = true)
    public AvailabilityResponse getAvailability(Double latitude, Double longitude, Double radiusKm) {
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("Latitude and Longitude are mandatory for nearby availability lookup");
        }

        if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
            throw new IllegalArgumentException("Invalid GPS coordinates provided: lat=" + latitude + ", lon=" + longitude);
        }

        double searchRadiusKm = (radiusKm != null && radiusKm > 0) ? radiusKm : defaultRadiusKm;
        double radiusMeters = searchRadiusKm * 1000.0;

        log.info("🔍 [Availability] Scanning 15KM spatial availability around [lat={}, lon={}, radiusMeters={}] (stale threshold: {}s)",
                latitude, longitude, radiusMeters, staleSeconds);

        List<ServiceCountProjection> projections = technicianProfileRepository.findServiceAvailabilityWithinRadius(
                latitude, longitude, radiusMeters, staleSeconds
        );

        List<ServiceAvailabilityDto> serviceDtos = new ArrayList<>();
        for (ServiceCountProjection p : projections) {
            long count = p.getTechnicianCount() != null ? p.getTechnicianCount() : 0L;
            serviceDtos.add(ServiceAvailabilityDto.builder()
                    .serviceId(p.getServiceId())
                    .serviceName(p.getServiceName())
                    .availableTechnicianCount(count)
                    .build());
        }

        return AvailabilityResponse.builder()
                .latitude(latitude)
                .longitude(longitude)
                .radiusKm(searchRadiusKm)
                .updatedAt(OffsetDateTime.now())
                .services(serviceDtos)
                .build();
    }
}
