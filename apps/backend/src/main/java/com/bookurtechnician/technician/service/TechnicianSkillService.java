package com.bookurtechnician.technician.service;

import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.review.repository.ReviewRepository;
import com.bookurtechnician.servicecatalog.entity.ServiceSkill;
import com.bookurtechnician.servicecatalog.repository.ServiceSkillRepository;
import com.bookurtechnician.technician.dto.TechnicianSkillDtos;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.entity.TechnicianSkill;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.technician.repository.TechnicianSkillRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TechnicianSkillService {

    private final TechnicianProfileRepository profileRepository;
    private final TechnicianSkillRepository technicianSkillRepository;
    private final ServiceSkillRepository serviceSkillRepository;
    private final ReviewRepository reviewRepository;

    @Transactional(readOnly = true)
    public TechnicianSkillDtos.TechnicianSkillProfileResponse getTechnicianSkillProfile(UUID userId) {
        TechnicianProfile profile = profileRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found for user: " + userId));

        return buildProfileResponse(profile);
    }

    @Transactional(readOnly = true)
    public TechnicianSkillDtos.TechnicianSkillProfileResponse getTechnicianSkillProfileByTechId(UUID technicianId) {
        TechnicianProfile profile = profileRepository.findById(technicianId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found: " + technicianId));

        return buildProfileResponse(profile);
    }

    @Transactional
    public TechnicianSkillDtos.TechnicianSkillProfileResponse bulkSaveSkills(UUID userId, TechnicianSkillDtos.BulkSaveSkillsRequest req) {
        TechnicianProfile profile = profileRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found for user: " + userId));

        List<TechnicianSkillDtos.SkillItemRequest> incomingSkills = req.getSkills() != null ? req.getSkills() : new ArrayList<>();

        for (TechnicianSkillDtos.SkillItemRequest item : incomingSkills) {
            if (item.getSkillId() == null) continue;

            ServiceSkill skill = serviceSkillRepository.findById(item.getSkillId()).orElse(null);
            if (skill == null) continue;

            Optional<TechnicianSkill> existing = technicianSkillRepository.findByTechnicianIdAndSkillId(profile.getId(), skill.getId());
            if (existing.isPresent()) {
                TechnicianSkill ts = existing.get();
                ts.setExperienceYears(Math.max(1, item.getExperienceYears()));
                if (item.getCertificateUrl() != null && !item.getCertificateUrl().isBlank()) {
                    ts.setCertificateUrl(item.getCertificateUrl());
                }
                ts.setEnabled(true);
                technicianSkillRepository.save(ts);
            } else {
                TechnicianSkill newSkill = TechnicianSkill.builder()
                        .technician(profile)
                        .skill(skill)
                        .experienceYears(Math.max(1, item.getExperienceYears()))
                        .verificationStatus("VERIFIED") // Initial onboarding verified / auto-approved for instant matching
                        .enabled(true)
                        .certificateUrl(item.getCertificateUrl())
                        .verifiedAt(Instant.now())
                        .build();
                technicianSkillRepository.save(newSkill);
            }
        }

        return buildProfileResponse(profile);
    }

    @Transactional
    public TechnicianSkillDtos.TechnicianSkillDto toggleSkillEnabled(UUID userId, UUID technicianSkillId) {
        TechnicianProfile profile = profileRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician profile not found for user: " + userId));

        TechnicianSkill techSkill = technicianSkillRepository.findById(technicianSkillId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician skill not found: " + technicianSkillId));

        if (!techSkill.getTechnician().getId().equals(profile.getId())) {
            throw new ResourceNotFoundException("Skill not assigned to this technician.");
        }

        techSkill.setEnabled(!techSkill.isEnabled());
        techSkill = technicianSkillRepository.save(techSkill);
        return mapToDto(techSkill);
    }

    @Transactional
    public TechnicianSkillDtos.TechnicianSkillDto verifySkillAdmin(UUID technicianSkillId, TechnicianSkillDtos.VerifySkillAdminRequest req) {
        TechnicianSkill techSkill = technicianSkillRepository.findById(technicianSkillId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician skill not found: " + technicianSkillId));

        String targetStatus = req.getStatus() != null ? req.getStatus().toUpperCase() : "VERIFIED";
        techSkill.setVerificationStatus(targetStatus);

        if ("VERIFIED".equals(targetStatus)) {
            techSkill.setVerifiedAt(Instant.now());
            techSkill.setRejectionReason(null);
        } else if ("REJECTED".equals(targetStatus)) {
            techSkill.setRejectionReason(req.getRejectionReason());
        }

        techSkill = technicianSkillRepository.save(techSkill);
        return mapToDto(techSkill);
    }

    private TechnicianSkillDtos.TechnicianSkillProfileResponse buildProfileResponse(TechnicianProfile profile) {
        List<TechnicianSkill> skills = technicianSkillRepository.findByTechnicianIdOrderByCreatedAtAsc(profile.getId());

        List<TechnicianSkillDtos.TechnicianSkillDto> skillDtos = skills.stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());

        int verifiedCount = (int) skills.stream().filter(s -> "VERIFIED".equalsIgnoreCase(s.getVerificationStatus())).count();
        int pendingCount = (int) skills.stream().filter(s -> "PENDING".equalsIgnoreCase(s.getVerificationStatus())).count();

        // Dynamically compute real customer rating from review table
        Double avgRating = reviewRepository.getAverageRatingForTechnician(profile.getId());
        long ratingsCount = reviewRepository.countReviewsForTechnician(profile.getId());

        BigDecimal rating = (avgRating != null && avgRating > 0)
                ? BigDecimal.valueOf(avgRating).setScale(2, RoundingMode.HALF_UP)
                : (profile.getRating() != null ? profile.getRating() : new BigDecimal("4.9"));

        int totalRatings = (int) ratingsCount;
        if (totalRatings == 0 && profile.getTotalRatingsCount() > 0) {
            totalRatings = profile.getTotalRatingsCount();
        }

        return TechnicianSkillDtos.TechnicianSkillProfileResponse.builder()
                .technicianId(profile.getId())
                .technicianCode(profile.getTechnicianCode())
                .fullName(profile.getUser() != null ? profile.getUser().getFullName() : "Partner Technician")
                .profileImageUrl(profile.getUser() != null ? profile.getUser().getProfileImageUrl() : null)
                .rating(rating)
                .totalRatingsCount(totalRatings)
                .totalJobsCompleted(profile.getTotalJobsCompleted())
                .skills(skillDtos)
                .totalSkillsCount(skills.size())
                .verifiedSkillsCount(verifiedCount)
                .pendingSkillsCount(pendingCount)
                .build();
    }

    public TechnicianSkillDtos.TechnicianSkillDto mapToDto(TechnicianSkill ts) {
        ServiceSkill sk = ts.getSkill();
        return TechnicianSkillDtos.TechnicianSkillDto.builder()
                .id(ts.getId())
                .skillId(sk.getId())
                .skillName(sk.getName())
                .skillSlug(sk.getSlug())
                .categoryId(sk.getCategory().getId())
                .categoryName(sk.getCategory().getName())
                .serviceItemId(sk.getServiceItem() != null ? sk.getServiceItem().getId() : null)
                .serviceItemName(sk.getServiceItem() != null ? sk.getServiceItem().getName() : null)
                .experienceYears(ts.getExperienceYears())
                .verificationStatus(ts.getVerificationStatus())
                .enabled(ts.isEnabled())
                .rejectionReason(ts.getRejectionReason())
                .verifiedAt(ts.getVerifiedAt())
                .createdAt(ts.getCreatedAt())
                .build();
    }
}
