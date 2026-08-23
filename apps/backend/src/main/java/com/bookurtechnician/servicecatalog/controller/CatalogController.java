package com.bookurtechnician.servicecatalog.controller;

import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.servicecatalog.dto.CatalogDtos;
import com.bookurtechnician.servicecatalog.service.CatalogService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/catalog")
public class CatalogController {

    private final CatalogService catalogService;

    public CatalogController(CatalogService catalogService) {
        this.catalogService = catalogService;
    }

    @GetMapping("/hierarchy")
    public ResponseEntity<ApiResponse<List<CatalogDtos.CategoryHierarchyDto>>> getHierarchy() {
        return ResponseEntity.ok(ApiResponse.success(catalogService.getFullHierarchy()));
    }

    @GetMapping("/skills")
    public ResponseEntity<ApiResponse<List<CatalogDtos.SkillDto>>> getSkills() {
        return ResponseEntity.ok(ApiResponse.success(catalogService.getAllActiveSkills()));
    }

    @PostMapping("/admin/skills")
    public ResponseEntity<ApiResponse<CatalogDtos.SkillDto>> createSkill(@RequestBody CatalogDtos.CreateSkillRequest req) {
        return ResponseEntity.ok(ApiResponse.success(catalogService.createSkill(req), "Skill created successfully"));
    }

    @PutMapping("/admin/skills/{skillId}")
    public ResponseEntity<ApiResponse<CatalogDtos.SkillDto>> updateSkill(
            @PathVariable UUID skillId,
            @RequestBody CatalogDtos.UpdateSkillRequest req) {
        return ResponseEntity.ok(ApiResponse.success(catalogService.updateSkill(skillId, req), "Skill updated successfully"));
    }

    @DeleteMapping("/admin/skills/{skillId}")
    public ResponseEntity<ApiResponse<Void>> deleteSkill(@PathVariable UUID skillId) {
        catalogService.deleteSkill(skillId);
        return ResponseEntity.ok(ApiResponse.success(null, "Skill deactivated successfully"));
    }

    @GetMapping("/admin/skills/{skillId}/compatibility")
    public ResponseEntity<ApiResponse<CatalogDtos.SkillCompatibilityDto>> getSkillCompatibility(@PathVariable UUID skillId) {
        return ResponseEntity.ok(ApiResponse.success(catalogService.getSkillCompatibility(skillId)));
    }

    @PutMapping("/admin/skills/{skillId}/compatibility")
    public ResponseEntity<ApiResponse<CatalogDtos.SkillCompatibilityDto>> updateSkillCompatibility(
            @PathVariable UUID skillId,
            @RequestBody CatalogDtos.UpdateSkillCompatibilityRequest req) {
        return ResponseEntity.ok(ApiResponse.success(
                catalogService.updateSkillCompatibility(skillId, req),
                "Skill service compatibility updated successfully"));
    }

    @GetMapping("/admin/matching-rules")
    public ResponseEntity<ApiResponse<CatalogDtos.DispatchMatchingConfigDto>> getMatchingRules() {
        return ResponseEntity.ok(ApiResponse.success(catalogService.getOrCreateDispatchConfig()));
    }

    @PutMapping("/admin/matching-rules")
    public ResponseEntity<ApiResponse<CatalogDtos.DispatchMatchingConfigDto>> updateMatchingRules(
            @RequestBody CatalogDtos.DispatchMatchingConfigDto req,
            @org.springframework.security.core.annotation.AuthenticationPrincipal com.bookurtechnician.auth.security.UserPrincipal principal) {
        String email = principal != null ? principal.getEmail() : "admin";
        return ResponseEntity.ok(ApiResponse.success(
                catalogService.updateDispatchConfig(req, email),
                "Intelligent dispatch matching rules updated successfully"));
    }
}
