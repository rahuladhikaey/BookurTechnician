package com.bookurtechnician.banner.controller;

import com.bookurtechnician.banner.dto.BannerDtos;
import com.bookurtechnician.banner.service.BannerService;
import com.bookurtechnician.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class BannerController {

    private final BannerService bannerService;

    @GetMapping("/banners/hero")
    public ResponseEntity<ApiResponse<List<BannerDtos.BannerResponse>>> getHeroBanners() {
        List<BannerDtos.BannerResponse> banners = bannerService.getActiveBannersByType("HERO");
        return ResponseEntity.ok(ApiResponse.success(banners));
    }

    @GetMapping("/banners/spotlight")
    public ResponseEntity<ApiResponse<List<BannerDtos.BannerResponse>>> getSpotlightBanners() {
        List<BannerDtos.BannerResponse> banners = bannerService.getActiveBannersByType("SPOTLIGHT");
        return ResponseEntity.ok(ApiResponse.success(banners));
    }

    @GetMapping("/banners/running")
    public ResponseEntity<ApiResponse<List<BannerDtos.BannerResponse>>> getRunningBanners() {
        List<BannerDtos.BannerResponse> banners = bannerService.getActiveBannersByType("RUNNING");
        return ResponseEntity.ok(ApiResponse.success(banners));
    }

    @GetMapping("/admin/banners")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<BannerDtos.BannerResponse>>> getAllBannersForAdmin() {
        List<BannerDtos.BannerResponse> banners = bannerService.getAllBannersForAdmin();
        return ResponseEntity.ok(ApiResponse.success(banners));
    }

    @PostMapping("/admin/banners")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<BannerDtos.BannerResponse>> createBanner(
            @Valid @RequestBody BannerDtos.CreateBannerRequest request) {
        BannerDtos.BannerResponse response = bannerService.createBanner(request);
        return ResponseEntity.ok(ApiResponse.success(response, "Banner created successfully"));
    }

    @PutMapping("/admin/banners/{bannerId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<BannerDtos.BannerResponse>> updateBanner(
            @PathVariable UUID bannerId,
            @RequestBody BannerDtos.UpdateBannerRequest request) {
        BannerDtos.BannerResponse response = bannerService.updateBanner(bannerId, request);
        return ResponseEntity.ok(ApiResponse.success(response, "Banner updated successfully"));
    }

    @DeleteMapping("/admin/banners/{bannerId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteBanner(@PathVariable UUID bannerId) {
        bannerService.deleteBanner(bannerId);
        return ResponseEntity.ok(ApiResponse.success(null, "Banner deleted successfully"));
    }
}
