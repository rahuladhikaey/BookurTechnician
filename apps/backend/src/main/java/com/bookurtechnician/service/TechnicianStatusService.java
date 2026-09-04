package com.bookurtechnician.service;

import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class TechnicianStatusService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final StringRedisTemplate redisTemplate;

    @Transactional
    public void updateStatus(String technicianId, Boolean isOnline, String availabilityStatus) {
        if (technicianId == null || technicianId.trim().isEmpty()) {
            throw new IllegalArgumentException("Technician ID cannot be empty or null");
        }

        TechnicianProfile profile = technicianProfileRepository.findByTechnicianId(technicianId)
                .orElseThrow(() -> new IllegalArgumentException("Technician profile not found for ID: " + technicianId));

        if (Boolean.TRUE.equals(isOnline)) {
            // Validate KYC verification
            if (!"VERIFIED".equalsIgnoreCase(profile.getKycStatus())) {
                throw new IllegalStateException("Technician KYC is not VERIFIED (current status: " + profile.getKycStatus() + ")");
            }

            profile.setIsOnline(true);
            profile.setAvailabilityStatus((availabilityStatus != null && !availabilityStatus.equalsIgnoreCase("OFFLINE"))
                    ? availabilityStatus.toUpperCase()
                    : "AVAILABLE");
        } else {
            profile.setIsOnline(false);
            profile.setAvailabilityStatus("OFFLINE");

            // Clean up from Redis active GEO set
            try {
                redisTemplate.opsForZSet().remove("technician:locations", technicianId);
                redisTemplate.delete("technician:heartbeat:" + technicianId);
            } catch (Exception e) {
                log.warn("⚠️ [Redis Cleanup] Failed to remove offline technician from Redis GEO: {}", e.getMessage());
            }
        }

        technicianProfileRepository.save(profile);
        log.info("📶 [Status Update] Technician {} is now online={} status={}",
                technicianId, profile.getIsOnline(), profile.getAvailabilityStatus());
    }
}
