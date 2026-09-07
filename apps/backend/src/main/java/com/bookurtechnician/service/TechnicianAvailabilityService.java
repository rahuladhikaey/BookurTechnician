package com.bookurtechnician.service;

import com.bookurtechnician.dto.NearbyTechnicianDto;
import com.bookurtechnician.dto.NearbyTechniciansResponse;
import com.bookurtechnician.model.ServiceEntity;
import com.bookurtechnician.repository.NearbyTechnicianProjection;
import com.bookurtechnician.repository.ServiceCountProjection;
import com.bookurtechnician.repository.ServiceRepository;
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
    private final ServiceRepository serviceRepository;

    public TechnicianAvailabilityService(TechnicianProfileRepository technicianProfileRepository) {
        this.technicianProfileRepository = technicianProfileRepository;
        this.serviceRepository = null;
    }

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

    /**
     * Production PostGIS 15 KM Nearby Online Technicians for a Specific Service or Category
     * Calculates spherical geodesic distance and realistic ETA for each active technician.
     */
    @Transactional(readOnly = true)
    public NearbyTechniciansResponse getNearbyTechnicians(
            String serviceId,
            String categoryId,
            Double latitude,
            Double longitude,
            Double radiusKm
    ) {
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("Latitude and Longitude are mandatory for nearby technician discovery");
        }

        if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
            throw new IllegalArgumentException("Invalid GPS coordinates: lat=" + latitude + ", lon=" + longitude);
        }

        if ((serviceId == null || serviceId.trim().isEmpty()) && (categoryId == null || categoryId.trim().isEmpty())) {
            throw new IllegalArgumentException("Either serviceId or categoryId must be specified");
        }

        double searchRadiusKm = (radiusKm != null && radiusKm > 0) ? radiusKm : defaultRadiusKm;
        double radiusMeters = searchRadiusKm * 1000.0;

        String serviceName = null;
        List<NearbyTechnicianProjection> projections;

        if (serviceId != null && !serviceId.trim().isEmpty()) {
            serviceName = serviceRepository.findById(serviceId.trim())
                    .map(ServiceEntity::getName)
                    .orElse(serviceId);

            log.info("📍 [Geospatial Search] Finding online technicians within {}km for service: '{}' (lat={}, lon={})",
                    searchRadiusKm, serviceName, latitude, longitude);

            projections = technicianProfileRepository.findNearbyTechniciansByService(
                    serviceId.trim(), latitude, longitude, radiusMeters, staleSeconds
            );
        } else {
            log.info("📍 [Geospatial Search] Finding online technicians within {}km for category: '{}' (lat={}, lon={})",
                    searchRadiusKm, categoryId, latitude, longitude);

            projections = technicianProfileRepository.findNearbyTechniciansByCategory(
                    categoryId.trim(), latitude, longitude, radiusMeters, staleSeconds
            );
        }

        List<NearbyTechnicianDto> dtoList = new ArrayList<>();
        for (NearbyTechnicianProjection p : projections) {
            double distMeters = p.getDistanceMeters() != null ? p.getDistanceMeters() : 0.0;
            double distKm = Math.round((distMeters / 1000.0) * 10.0) / 10.0;

            // Realistic transit calculation: 20 km/h urban average speed (3 mins/km) + 5 mins initial buffer
            int etaMinutes = Math.max(5, (int) Math.round((distKm * 3.0) + 5.0));

            dtoList.add(NearbyTechnicianDto.builder()
                    .technicianId(p.getTechnicianId())
                    .technicianCode(p.getTechnicianCode())
                    .fullName(p.getFullName())
                    .phone(maskPhone(p.getPhone()))
                    .category(p.getCategory())
                    .profileImageUrl(p.getProfileImageUrl())
                    .experienceYears(p.getExperienceYears() != null ? p.getExperienceYears() : 1)
                    .rating(p.getRating() != null ? Math.round(p.getRating() * 10.0) / 10.0 : 4.8)
                    .totalRatingsCount(p.getTotalRatingsCount() != null ? p.getTotalRatingsCount() : 0)
                    .totalJobsCompleted(p.getTotalJobsCompleted() != null ? p.getTotalJobsCompleted() : 0)
                    .currentLatitude(p.getCurrentLatitude())
                    .currentLongitude(p.getCurrentLongitude())
                    .distanceMeters(distMeters)
                    .distanceKm(distKm)
                    .estimatedArrivalMinutes(etaMinutes)
                    .isOnline(Boolean.TRUE.equals(p.getIsOnline()))
                    .availabilityStatus(p.getAvailabilityStatus() != null ? p.getAvailabilityStatus() : "AVAILABLE")
                    .build());
        }

        return NearbyTechniciansResponse.builder()
                .serviceId(serviceId)
                .serviceName(serviceName)
                .categoryId(categoryId)
                .latitude(latitude)
                .longitude(longitude)
                .radiusKm(searchRadiusKm)
                .totalOnlineTechnicians(dtoList.size())
                .updatedAt(OffsetDateTime.now())
                .technicians(dtoList)
                .build();
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return phone;
        }
        int len = phone.length();
        return phone.substring(0, 3) + "****" + phone.substring(len - 3);
    }
}
