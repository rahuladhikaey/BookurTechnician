package com.bookurtechnician.servicecatalog.service;

import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.servicecatalog.dto.CatalogDtos;
import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.servicecatalog.entity.ServiceSkill;
import com.bookurtechnician.servicecatalog.repository.ServiceCategoryRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceItemRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceSkillRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import com.bookurtechnician.dispatch.entity.DispatchMatchingConfig;
import com.bookurtechnician.dispatch.repository.DispatchMatchingConfigRepository;
import com.bookurtechnician.servicecatalog.entity.SkillServiceCompatibility;
import com.bookurtechnician.servicecatalog.repository.SkillServiceCompatibilityRepository;

@Service
@RequiredArgsConstructor
@Slf4j
public class CatalogService {

    private final ServiceCategoryRepository categoryRepository;
    private final ServiceItemRepository serviceItemRepository;
    private final ServiceSkillRepository skillRepository;
    private final SkillServiceCompatibilityRepository compatibilityRepository;
    private final DispatchMatchingConfigRepository matchingConfigRepository;

    @Transactional(readOnly = true)
    public List<CatalogDtos.CategoryHierarchyDto> getFullHierarchy() {
        List<ServiceCategory> categories = categoryRepository.findByActiveTrueOrderByDisplayOrderAsc();
        List<ServiceItem> allServices = serviceItemRepository.findByActiveTrueOrderByPriceAsc();
        List<ServiceSkill> allSkills = skillRepository.findByActiveTrueOrderByDisplayOrderAscNameAsc();

        return categories.stream().map(cat -> {
            List<ServiceItem> catServices = allServices.stream()
                    .filter(s -> s.getCategory().getId().equals(cat.getId()))
                    .toList();

            List<CatalogDtos.ServiceHierarchyDto> serviceDtos = catServices.stream().map(srv -> {
                List<CatalogDtos.SkillDto> srvSkills = allSkills.stream()
                        .filter(sk -> sk.getServiceItem() != null && sk.getServiceItem().getId().equals(srv.getId()))
                        .map(this::mapToSkillDto)
                        .toList();

                return CatalogDtos.ServiceHierarchyDto.builder()
                        .id(srv.getId())
                        .name(srv.getName())
                        .slug(srv.getSlug())
                        .price(srv.getPrice())
                        .description(srv.getDescription())
                        .skills(srvSkills)
                        .build();
            }).toList();

            List<CatalogDtos.SkillDto> directCatSkills = allSkills.stream()
                    .filter(sk -> sk.getCategory().getId().equals(cat.getId()))
                    .map(this::mapToSkillDto)
                    .toList();

            return CatalogDtos.CategoryHierarchyDto.builder()
                    .id(cat.getId())
                    .name(cat.getName())
                    .slug(cat.getSlug())
                    .iconUrl(cat.getIconUrl())
                    .displayOrder(cat.getDisplayOrder())
                    .services(serviceDtos)
                    .skills(directCatSkills)
                    .build();
        }).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CatalogDtos.SkillDto> getAllActiveSkills() {
        return skillRepository.findByActiveTrueOrderByDisplayOrderAscNameAsc().stream()
                .map(this::mapToSkillDto)
                .toList();
    }

    @Transactional
    public CatalogDtos.SkillDto createSkill(CatalogDtos.CreateSkillRequest req) {
        ServiceCategory category = categoryRepository.findById(req.getCategoryId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + req.getCategoryId()));

        ServiceItem serviceItem = null;
        if (req.getServiceItemId() != null) {
            serviceItem = serviceItemRepository.findById(req.getServiceItemId()).orElse(null);
        }

        String slug = generateSlug(req.getName());
        int count = 1;
        String uniqueSlug = slug;
        while (skillRepository.existsBySlug(uniqueSlug)) {
            uniqueSlug = slug + "-" + count++;
        }

        ServiceSkill skill = ServiceSkill.builder()
                .category(category)
                .serviceItem(serviceItem)
                .name(req.getName().trim())
                .slug(uniqueSlug)
                .description(req.getDescription())
                .displayOrder(req.getDisplayOrder())
                .active(true)
                .build();

        skill = skillRepository.save(skill);
        return mapToSkillDto(skill);
    }

    @Transactional
    public CatalogDtos.SkillDto updateSkill(UUID skillId, CatalogDtos.UpdateSkillRequest req) {
        ServiceSkill skill = skillRepository.findById(skillId)
                .orElseThrow(() -> new ResourceNotFoundException("Skill not found: " + skillId));

        if (req.getName() != null && !req.getName().isBlank()) {
            skill.setName(req.getName().trim());
        }
        if (req.getDescription() != null) {
            skill.setDescription(req.getDescription());
        }
        if (req.getDisplayOrder() > 0) {
            skill.setDisplayOrder(req.getDisplayOrder());
        }
        if (req.getActive() != null) {
            skill.setActive(req.getActive());
        }

        skill = skillRepository.save(skill);
        return mapToSkillDto(skill);
    }

    @Transactional
    public void deleteSkill(UUID skillId) {
        ServiceSkill skill = skillRepository.findById(skillId)
                .orElseThrow(() -> new ResourceNotFoundException("Skill not found: " + skillId));
        skill.setActive(false);
        skillRepository.save(skill);
    }

    public CatalogDtos.SkillDto mapToSkillDto(ServiceSkill skill) {
        return CatalogDtos.SkillDto.builder()
                .id(skill.getId())
                .categoryId(skill.getCategory().getId())
                .categoryName(skill.getCategory().getName())
                .serviceItemId(skill.getServiceItem() != null ? skill.getServiceItem().getId() : null)
                .serviceItemName(skill.getServiceItem() != null ? skill.getServiceItem().getName() : null)
                .name(skill.getName())
                .slug(skill.getSlug())
                .description(skill.getDescription())
                .displayOrder(skill.getDisplayOrder())
                .active(skill.isActive())
                .build();
    }

    @Transactional(readOnly = true)
    public CatalogDtos.SkillCompatibilityDto getSkillCompatibility(UUID skillId) {
        ServiceSkill skill = skillRepository.findById(skillId)
                .orElseThrow(() -> new ResourceNotFoundException("Skill not found: " + skillId));

        List<SkillServiceCompatibility> compatibilities = compatibilityRepository.findBySkillId(skillId);
        List<CatalogDtos.CompatibleServiceSummary> summaries = compatibilities.stream().map(c -> {
            ServiceItem s = c.getServiceItem();
            return CatalogDtos.CompatibleServiceSummary.builder()
                    .serviceId(s.getId())
                    .serviceName(s.getName())
                    .categoryName(s.getCategory() != null ? s.getCategory().getName() : "")
                    .price(s.getPrice())
                    .build();
        }).toList();

        return CatalogDtos.SkillCompatibilityDto.builder()
                .skillId(skill.getId())
                .skillName(skill.getName())
                .categoryName(skill.getCategory().getName())
                .compatibleServices(summaries)
                .build();
    }

    @Transactional
    public CatalogDtos.SkillCompatibilityDto updateSkillCompatibility(UUID skillId,
            CatalogDtos.UpdateSkillCompatibilityRequest req) {
        ServiceSkill skill = skillRepository.findById(skillId)
                .orElseThrow(() -> new ResourceNotFoundException("Skill not found: " + skillId));

        compatibilityRepository.deleteBySkillId(skillId);

        if (req.getServiceItemIds() != null) {
            for (UUID srvId : req.getServiceItemIds()) {
                ServiceItem item = serviceItemRepository.findById(srvId).orElse(null);
                if (item != null) {
                    compatibilityRepository.save(SkillServiceCompatibility.builder()
                            .skill(skill)
                            .serviceItem(item)
                            .build());
                }
            }
        }

        return getSkillCompatibility(skillId);
    }

    @Transactional
    public CatalogDtos.DispatchMatchingConfigDto getOrCreateDispatchConfig() {
        DispatchMatchingConfig config = matchingConfigRepository.findFirstByOrderByCreatedAtAsc()
                .orElseGet(() -> matchingConfigRepository.save(DispatchMatchingConfig.builder()
                        .searchRadiusKm(10.0)
                        .strictSkillMatching(true)
                        .scoreWeightDistance(0.40)
                        .scoreWeightRating(0.30)
                        .scoreWeightAcceptance(0.15)
                        .scoreWeightExperience(0.15)
                        .priorityPolicy("BALANCED")
                        .notificationTimeoutSeconds(30)
                        .maxDispatchAttempts(5)
                        .autoEscalateToAdmin(true)
                        .build()));

        return mapToConfigDto(config);
    }

    @Transactional
    public CatalogDtos.DispatchMatchingConfigDto updateDispatchConfig(CatalogDtos.DispatchMatchingConfigDto req,
            String adminEmail) {
        DispatchMatchingConfig config = matchingConfigRepository.findFirstByOrderByCreatedAtAsc()
                .orElseGet(() -> DispatchMatchingConfig.builder().build());

        if (req.getSearchRadiusKm() > 0)
            config.setSearchRadiusKm(req.getSearchRadiusKm());
        config.setStrictSkillMatching(req.isStrictSkillMatching());
        if (req.getScoreWeightDistance() >= 0)
            config.setScoreWeightDistance(req.getScoreWeightDistance());
        if (req.getScoreWeightRating() >= 0)
            config.setScoreWeightRating(req.getScoreWeightRating());
        if (req.getScoreWeightAcceptance() >= 0)
            config.setScoreWeightAcceptance(req.getScoreWeightAcceptance());
        if (req.getScoreWeightExperience() >= 0)
            config.setScoreWeightExperience(req.getScoreWeightExperience());
        if (req.getPriorityPolicy() != null)
            config.setPriorityPolicy(req.getPriorityPolicy());
        if (req.getNotificationTimeoutSeconds() > 0)
            config.setNotificationTimeoutSeconds(req.getNotificationTimeoutSeconds());
        if (req.getMaxDispatchAttempts() > 0)
            config.setMaxDispatchAttempts(req.getMaxDispatchAttempts());
        config.setAutoEscalateToAdmin(req.isAutoEscalateToAdmin());
        config.setUpdatedByEmail(adminEmail);

        config = matchingConfigRepository.save(config);
        return mapToConfigDto(config);
    }

    private CatalogDtos.DispatchMatchingConfigDto mapToConfigDto(DispatchMatchingConfig c) {
        return CatalogDtos.DispatchMatchingConfigDto.builder()
                .id(c.getId())
                .searchRadiusKm(c.getSearchRadiusKm())
                .strictSkillMatching(c.isStrictSkillMatching())
                .scoreWeightDistance(c.getScoreWeightDistance())
                .scoreWeightRating(c.getScoreWeightRating())
                .scoreWeightAcceptance(c.getScoreWeightAcceptance())
                .scoreWeightExperience(c.getScoreWeightExperience())
                .priorityPolicy(c.getPriorityPolicy())
                .notificationTimeoutSeconds(c.getNotificationTimeoutSeconds())
                .maxDispatchAttempts(c.getMaxDispatchAttempts())
                .autoEscalateToAdmin(c.isAutoEscalateToAdmin())
                .updatedByEmail(c.getUpdatedByEmail())
                .build();
    }

    private String generateSlug(String text) {
        return text.toLowerCase()
                .replaceAll("[^a-z0-9\\s-]", "")
                .replaceAll("\\s+", "-");
    }
}
