package com.bookurtechnician.service;

import com.bookurtechnician.dto.TechnicianSkillDto;
import com.bookurtechnician.dto.TechnicianSkillsResponse;
import com.bookurtechnician.model.ServiceEntity;
import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.model.TechnicianServiceEntity;
import com.bookurtechnician.repository.ServiceRepository;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import com.bookurtechnician.repository.TechnicianServiceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class TechnicianSkillService {

    private final TechnicianProfileRepository technicianProfileRepository;
    private final TechnicianServiceRepository technicianServiceRepository;
    private final ServiceRepository serviceRepository;

    @Transactional
    public TechnicianSkillsResponse saveSkills(String technicianId, List<TechnicianSkillDto> skillsList) {
        if (technicianId == null || technicianId.trim().isEmpty()) {
            throw new IllegalArgumentException("Technician ID is required to save skills");
        }

        String cleanTechId = technicianId.trim();
        log.info("🛠️ [Skills Save] Saving {} skills for technician: {}", 
                skillsList != null ? skillsList.size() : 0, cleanTechId);

        // 1. Fetch or create technician profile
        TechnicianProfile profile = technicianProfileRepository.findByTechnicianId(cleanTechId)
                .orElseGet(() -> {
                    String code = "BT-TECH-" + cleanTechId.replace("tech-", "").replace("usr_", "").toUpperCase();
                    if (code.length() > 25) code = code.substring(0, 25);
                    TechnicianProfile newProf = TechnicianProfile.builder()
                            .id(UUID.randomUUID().toString())
                            .technicianId(cleanTechId)
                            .technicianCode(code)
                            .fullName("Partner Technician")
                            .phone("+919000000000")
                            .category("ELECTRICIAN")
                            .experienceYears(2)
                            .kycStatus("VERIFIED")
                            .isOnline(true)
                            .availabilityStatus("AVAILABLE")
                            .createdAt(OffsetDateTime.now())
                            .updatedAt(OffsetDateTime.now())
                            .build();
                    return technicianProfileRepository.save(newProf);
                });

        // 2. Remove existing service mappings for clean re-sync
        technicianServiceRepository.deleteByTechnicianId(cleanTechId);

        List<TechnicianSkillDto> savedSkills = new ArrayList<>();
        Map<String, ServiceEntity> activeServicesMap = new HashMap<>();
        try {
            for (ServiceEntity s : serviceRepository.findAll()) {
                activeServicesMap.put(s.getId(), s);
                if (s.getSlug() != null) {
                    activeServicesMap.put(s.getSlug(), s);
                }
            }
        } catch (Exception e) {
            log.warn("Could not cache active services: {}", e.getMessage());
        }

        if (skillsList != null && !skillsList.isEmpty()) {
            Set<String> processedServiceIds = new HashSet<>();

            for (int i = 0; i < skillsList.size(); i++) {
                TechnicianSkillDto skill = skillsList.get(i);
                if (skill == null) continue;

                String rawSkillId = skill.getSkillId() != null ? skill.getSkillId().trim() : ("sk_" + i);
                String matchedServiceId = rawSkillId;

                // Match with database service if exists
                if (activeServicesMap.containsKey(rawSkillId)) {
                    matchedServiceId = activeServicesMap.get(rawSkillId).getId();
                }

                if (!processedServiceIds.contains(matchedServiceId)) {
                    processedServiceIds.add(matchedServiceId);

                    TechnicianServiceEntity serviceEntity = TechnicianServiceEntity.builder()
                            .id(UUID.randomUUID().toString())
                            .technicianId(cleanTechId)
                            .serviceId(matchedServiceId)
                            .active(Boolean.TRUE.equals(skill.getEnabled()) || skill.getEnabled() == null)
                            .createdAt(OffsetDateTime.now())
                            .build();

                    technicianServiceRepository.save(serviceEntity);

                    savedSkills.add(TechnicianSkillDto.builder()
                            .id(serviceEntity.getId())
                            .skillId(matchedServiceId)
                            .skillName(skill.getSkillName() != null ? skill.getSkillName() : matchedServiceId)
                            .categoryId(skill.getCategoryId() != null ? skill.getCategoryId() : "cat_general")
                            .categoryName(skill.getCategoryName() != null ? skill.getCategoryName() : "General")
                            .experienceYears(skill.getExperienceYears() != null ? skill.getExperienceYears() : 2)
                            .verificationStatus("VERIFIED")
                            .enabled(serviceEntity.getActive())
                            .build());
                }
            }
        }

        // 3. Update Technician Profile category & auto-verify for instant 15km availability
        if (!savedSkills.isEmpty()) {
            String primaryCategory = savedSkills.get(0).getCategoryId();
            if (primaryCategory != null) {
                profile.setCategory(primaryCategory.replace("cat_", "").toUpperCase());
            }
        }
        if (profile.getKycStatus() == null || "PENDING".equalsIgnoreCase(profile.getKycStatus())) {
            profile.setKycStatus("VERIFIED");
        }
        profile.setUpdatedAt(OffsetDateTime.now());
        technicianProfileRepository.save(profile);

        log.info("✅ [Skills Saved] Successfully mapped {} services for technician {}", 
                savedSkills.size(), cleanTechId);

        return buildResponse(profile, savedSkills);
    }

    @Transactional(readOnly = true)
    public TechnicianSkillsResponse getSkills(String technicianId) {
        if (technicianId == null || technicianId.trim().isEmpty()) {
            throw new IllegalArgumentException("Technician ID is required to retrieve skills");
        }

        String cleanTechId = technicianId.trim();
        TechnicianProfile profile = technicianProfileRepository.findByTechnicianId(cleanTechId).orElse(null);

        List<TechnicianServiceEntity> entities = technicianServiceRepository.findByTechnicianId(cleanTechId);
        List<TechnicianSkillDto> dtoList = new ArrayList<>();

        Map<String, ServiceEntity> servicesMap = new HashMap<>();
        try {
            for (ServiceEntity s : serviceRepository.findAll()) {
                servicesMap.put(s.getId(), s);
            }
        } catch (Exception ignored) {}

        for (TechnicianServiceEntity e : entities) {
            ServiceEntity s = servicesMap.get(e.getServiceId());
            dtoList.add(TechnicianSkillDto.builder()
                    .id(e.getId())
                    .skillId(e.getServiceId())
                    .skillName(s != null ? s.getName() : e.getServiceId())
                    .categoryId(s != null ? s.getCategoryId() : "cat_general")
                    .categoryName(s != null ? s.getCategoryId() : "General")
                    .experienceYears(2)
                    .verificationStatus("VERIFIED")
                    .enabled(Boolean.TRUE.equals(e.getActive()))
                    .build());
        }

        return buildResponse(profile != null ? profile : TechnicianProfile.builder()
                .technicianId(cleanTechId)
                .technicianCode("BT-TECH-" + cleanTechId.replace("tech-", "").toUpperCase())
                .fullName("Partner Technician")
                .build(), dtoList);
    }

    @Transactional
    public boolean toggleSkill(String technicianId, String skillOrEntityId) {
        if (skillOrEntityId == null || skillOrEntityId.trim().isEmpty()) return false;
        
        Optional<TechnicianServiceEntity> byId = technicianServiceRepository.findById(skillOrEntityId);
        if (byId.isPresent()) {
            TechnicianServiceEntity entity = byId.get();
            entity.setActive(!Boolean.TRUE.equals(entity.getActive()));
            technicianServiceRepository.save(entity);
            return true;
        }

        if (technicianId != null) {
            Optional<TechnicianServiceEntity> byTechAndSrv = 
                    technicianServiceRepository.findByTechnicianIdAndServiceId(technicianId, skillOrEntityId);
            if (byTechAndSrv.isPresent()) {
                TechnicianServiceEntity entity = byTechAndSrv.get();
                entity.setActive(!Boolean.TRUE.equals(entity.getActive()));
                technicianServiceRepository.save(entity);
                return true;
            }
        }

        return false;
    }

    private TechnicianSkillsResponse buildResponse(TechnicianProfile profile, List<TechnicianSkillDto> skills) {
        return TechnicianSkillsResponse.builder()
                .technicianId(profile.getTechnicianId())
                .technicianCode(profile.getTechnicianCode())
                .fullName(profile.getFullName() != null ? profile.getFullName() : "Partner Technician")
                .rating(profile.getRating() != null ? profile.getRating().doubleValue() : 4.85)
                .totalRatingsCount(profile.getTotalRatingsCount() != null ? profile.getTotalRatingsCount() : 0)
                .totalJobsCompleted(profile.getTotalJobsCompleted() != null ? profile.getTotalJobsCompleted() : 0)
                .skills(skills)
                .totalSkillsCount(skills.size())
                .verifiedSkillsCount(skills.size())
                .pendingSkillsCount(0)
                .build();
    }
}
