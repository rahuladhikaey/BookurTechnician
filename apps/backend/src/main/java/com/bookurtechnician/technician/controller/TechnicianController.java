package com.bookurtechnician.technician.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@RestController
@RequestMapping("/api/v1/technician")
@RequiredArgsConstructor
@Slf4j
public class TechnicianController {

    private final TechnicianProfileRepository profileRepository;
    private final StringRedisTemplate redisTemplate;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<TechnicianProfile>> getProfile(@AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));
        return ResponseEntity.ok(ApiResponse.success(profile));
    }

    @PostMapping("/online-status")
    public ResponseEntity<ApiResponse<TechnicianProfile>> toggleOnline(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody OnlineStatusDto dto) {
        TechnicianProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found"));

        profile.setOnline(dto.isOnline());

        if (dto.getLatitude() != null && dto.getLongitude() != null) {
            Point point = geometryFactory.createPoint(new Coordinate(dto.getLongitude(), dto.getLatitude()));
            profile.setCurrentLocation(point);
            profile.setLocationUpdatedAt(Instant.now());

            // Cache ephemeral coordinate in Redis GEO
            try {
                if (dto.isOnline()) {
                    redisTemplate.opsForGeo().add(
                            "tech:locations",
                            new org.springframework.data.geo.Point(dto.getLongitude(), dto.getLatitude()),
                            profile.getId().toString()
                    );
                } else {
                    redisTemplate.opsForZSet().remove("tech:locations", profile.getId().toString());
                }
            } catch (Exception ex) {
                log.warn("Redis GEO coordinate caching warning: {}", ex.getMessage());
            }
        }

        profile = profileRepository.save(profile);
        return ResponseEntity.ok(ApiResponse.success(profile, dto.isOnline() ? "You are now ONLINE" : "You are now OFFLINE"));
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

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OnlineStatusDto {
        private boolean online;
        private Double latitude;
        private Double longitude;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpiUpdateDto {
        @NotBlank
        private String upiId;
    }
}
