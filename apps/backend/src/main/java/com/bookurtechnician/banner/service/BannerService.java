package com.bookurtechnician.banner.service;

import com.bookurtechnician.banner.dto.BannerDtos;
import com.bookurtechnician.banner.entity.Banner;
import com.bookurtechnician.banner.repository.BannerRepository;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.servicecatalog.repository.ServiceCategoryRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BannerService {

    private final BannerRepository bannerRepository;
    private final ServiceCategoryRepository categoryRepository;
    private final ServiceItemRepository serviceItemRepository;

    public List<BannerDtos.BannerResponse> getActiveBannersByType(String bannerType) {
        return bannerRepository.findByBannerTypeAndActiveTrueOrderByDisplayOrderAsc(bannerType.toUpperCase()).stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<BannerDtos.BannerResponse> getAllBannersForAdmin() {
        return bannerRepository.findAllByOrderByDisplayOrderAsc().stream()
                .map(this::mapToResponse)
                .toList();
    }

    @Transactional
    public BannerDtos.BannerResponse createBanner(BannerDtos.CreateBannerRequest req) {
        ServiceCategory category = null;
        if (req.getCategoryId() != null) {
            category = categoryRepository.findById(req.getCategoryId()).orElse(null);
        }

        ServiceItem service = null;
        if (req.getServiceId() != null) {
            service = serviceItemRepository.findById(req.getServiceId()).orElse(null);
        }

        Banner banner = Banner.builder()
                .title(req.getTitle().trim())
                .subtitle(req.getSubtitle())
                .imageUrl(req.getImageUrl().trim())
                .bannerType(req.getBannerType() != null ? req.getBannerType().toUpperCase() : "HERO")
                .badgeText(req.getBadgeText())
                .ctaText(req.getCtaText() != null ? req.getCtaText() : "Book Now")
                .targetType(req.getTargetType() != null ? req.getTargetType() : "CATEGORY")
                .targetPayload(req.getTargetPayload())
                .category(category)
                .service(service)
                .displayOrder(req.getDisplayOrder() != null ? req.getDisplayOrder() : 0)
                .active(req.isActive())
                .build();

        banner = bannerRepository.save(banner);
        log.info("Created promotional banner {}: {}", banner.getId(), banner.getTitle());
        return mapToResponse(banner);
    }

    @Transactional
    public BannerDtos.BannerResponse updateBanner(UUID bannerId, BannerDtos.UpdateBannerRequest req) {
        Banner banner = bannerRepository.findById(bannerId)
                .orElseThrow(() -> new ResourceNotFoundException("Banner not found: " + bannerId));

        if (req.getTitle() != null) banner.setTitle(req.getTitle().trim());
        if (req.getSubtitle() != null) banner.setSubtitle(req.getSubtitle());
        if (req.getImageUrl() != null) banner.setImageUrl(req.getImageUrl().trim());
        if (req.getBannerType() != null) banner.setBannerType(req.getBannerType().toUpperCase());
        if (req.getBadgeText() != null) banner.setBadgeText(req.getBadgeText());
        if (req.getCtaText() != null) banner.setCtaText(req.getCtaText());
        if (req.getTargetType() != null) banner.setTargetType(req.getTargetType());
        if (req.getTargetPayload() != null) banner.setTargetPayload(req.getTargetPayload());
        if (req.getDisplayOrder() != null) banner.setDisplayOrder(req.getDisplayOrder());
        if (req.getActive() != null) banner.setActive(req.getActive());

        if (req.getCategoryId() != null) {
            banner.setCategory(categoryRepository.findById(req.getCategoryId()).orElse(null));
        }
        if (req.getServiceId() != null) {
            banner.setService(serviceItemRepository.findById(req.getServiceId()).orElse(null));
        }

        banner = bannerRepository.save(banner);
        return mapToResponse(banner);
    }

    @Transactional
    public void deleteBanner(UUID bannerId) {
        if (!bannerRepository.existsById(bannerId)) {
            throw new ResourceNotFoundException("Banner not found: " + bannerId);
        }
        bannerRepository.deleteById(bannerId);
        log.info("Deleted banner {}", bannerId);
    }

    private BannerDtos.BannerResponse mapToResponse(Banner b) {
        return BannerDtos.BannerResponse.builder()
                .id(b.getId())
                .title(b.getTitle())
                .subtitle(b.getSubtitle())
                .imageUrl(b.getImageUrl())
                .bannerType(b.getBannerType())
                .badgeText(b.getBadgeText())
                .ctaText(b.getCtaText())
                .targetType(b.getTargetType())
                .targetPayload(b.getTargetPayload())
                .categoryId(b.getCategory() != null ? b.getCategory().getId() : null)
                .serviceId(b.getService() != null ? b.getService().getId() : null)
                .displayOrder(b.getDisplayOrder())
                .active(b.isActive())
                .build();
    }
}
