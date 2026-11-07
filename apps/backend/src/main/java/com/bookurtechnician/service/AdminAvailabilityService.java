package com.bookurtechnician.service;

import com.bookurtechnician.dto.AdminAvailabilityOverviewDto;
import com.bookurtechnician.dto.ServiceAvailabilityDto;
import com.bookurtechnician.repository.ServiceCountProjection;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminAvailabilityService {

    private final TechnicianProfileRepository technicianProfileRepository;

    @Value("${technician.search-radius-km:15}")
    private double defaultRadiusKm;

    @Value("${technician.location-stale-seconds:60}")
    private int staleSeconds;

    @Transactional(readOnly = true)
    public AdminAvailabilityOverviewDto getOverview(Double radiusKm) {
        double radius = (radiusKm != null && radiusKm > 0) ? radiusKm : defaultRadiusKm;

        long online = technicianProfileRepository.countByIsOnlineTrue();
        long available = technicianProfileRepository.countByIsOnlineTrueAndAvailabilityStatus("AVAILABLE");
        long busy = technicianProfileRepository.countByIsOnlineTrueAndAvailabilityStatus("BUSY");

        OffsetDateTime staleCutoff = OffsetDateTime.now().minusSeconds(staleSeconds);
        long stale = technicianProfileRepository.countStaleTechnicians(staleCutoff);

        // Standard central location reference (or default spatial scan)
        List<ServiceCountProjection> projections = technicianProfileRepository.findServiceAvailabilityWithinRadius(
                22.5726, 88.3639, radius * 1000.0, staleSeconds
        );

        List<ServiceAvailabilityDto> serviceDtos = new ArrayList<>();
        for (ServiceCountProjection p : projections) {
            serviceDtos.add(ServiceAvailabilityDto.builder()
                    .serviceId(p.getServiceId())
                    .serviceName(p.getServiceName())
                    .availableTechnicianCount(p.getTechnicianCount() != null ? p.getTechnicianCount() : 0L)
                    .build());
        }

        return AdminAvailabilityOverviewDto.builder()
                .totalOnlineTechnicians(online)
                .totalAvailableTechnicians(available)
                .totalBusyTechnicians(busy)
                .staleLocationTechnicians(stale)
                .radiusKm(radius)
                .updatedAt(OffsetDateTime.now())
                .serviceAvailability(serviceDtos)
                .build();
    }
}
