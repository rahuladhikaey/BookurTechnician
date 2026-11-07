package com.bookurtechnician.service;

import com.bookurtechnician.dto.TechnicianLocationRequest;
import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.OffsetDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class TechnicianLocationService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final StringRedisTemplate redisTemplate;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @Value("${technician.location-stale-seconds:60}")
    private int staleSeconds;

    @Transactional
    public void updateLocation(String technicianId, TechnicianLocationRequest request) {
        if (technicianId == null || technicianId.trim().isEmpty()) {
            throw new IllegalArgumentException("Technician ID cannot be empty or null");
        }

        Double lat = request.getLatitude();
        Double lng = request.getLongitude();

        if (lat == null || lng == null) {
            throw new IllegalArgumentException("Latitude and Longitude are required");
        }

        // Validate boundary
        if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
            throw new IllegalArgumentException("Coordinates out of range: lat=" + lat + ", lng=" + lng);
        }

        // Reject impossible null island / test zeroes
        if (Math.abs(lat) < 0.0001 && Math.abs(lng) < 0.0001) {
            throw new IllegalArgumentException("Impossible coordinates (0, 0) rejected");
        }

        // Prevent spoofed future timestamps
        if (request.getTimestamp() != null && request.getTimestamp().isAfter(OffsetDateTime.now().plusMinutes(1))) {
            throw new IllegalArgumentException("Spoofed or future timestamp detected: " + request.getTimestamp());
        }

        OffsetDateTime now = OffsetDateTime.now();

        // 1. Fetch technician profile
        TechnicianProfile profile = technicianProfileRepository.findByTechnicianId(technicianId)
                .orElseThrow(() -> new IllegalArgumentException("Technician profile not found for ID: " + technicianId));

        // 2. Update durable PostgreSQL PostGIS entity
        profile.setCurrentLatitude(lat);
        profile.setCurrentLongitude(lng);
        profile.setLastLocationUpdate(now);

        Point point = geometryFactory.createPoint(new Coordinate(lng, lat));
        profile.setLocation(point);

        technicianProfileRepository.save(profile);

        // 3. Update Redis GEO ephemeral geospatial index
        try {
            redisTemplate.opsForGeo().add("technician:locations", new org.springframework.data.geo.Point(lng, lat), technicianId);
            redisTemplate.opsForValue().set(
                    "technician:heartbeat:" + technicianId,
                    now.toString(),
                    Duration.ofSeconds(staleSeconds)
            );
        } catch (Exception e) {
            log.warn("⚠️ [Redis GEO] Ephemeral location cache update failed: {}", e.getMessage());
        }

        log.info("📍 [GPS Update] Successfully updated coordinates for technician {} to [{}, {}]", technicianId, lat, lng);
    }
}
