package com.bookurtechnician.technician.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.technician.dto.TechnicianSkillDtos;
import com.bookurtechnician.technician.service.TechnicianSkillService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/technician/skills")
public class TechnicianSkillController {

    private final TechnicianSkillService skillService;

    public TechnicianSkillController(TechnicianSkillService skillService) {
        this.skillService = skillService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<TechnicianSkillDtos.TechnicianSkillProfileResponse>> getMySkillProfile(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.success(skillService.getTechnicianSkillProfile(principal.getId())));
    }

    @GetMapping("/technician/{technicianId}")
    public ResponseEntity<ApiResponse<TechnicianSkillDtos.TechnicianSkillProfileResponse>> getTechnicianSkills(
            @PathVariable UUID technicianId) {
        return ResponseEntity.ok(ApiResponse.success(skillService.getTechnicianSkillProfileByTechId(technicianId)));
    }

    @PostMapping("/bulk")
    public ResponseEntity<ApiResponse<TechnicianSkillDtos.TechnicianSkillProfileResponse>> bulkSaveSkills(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody TechnicianSkillDtos.BulkSaveSkillsRequest req) {
        return ResponseEntity.ok(ApiResponse.success(
                skillService.bulkSaveSkills(principal.getId(), req),
                "Skills configured successfully"));
    }

    @PatchMapping("/{technicianSkillId}/toggle")
    public ResponseEntity<ApiResponse<TechnicianSkillDtos.TechnicianSkillDto>> toggleSkill(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID technicianSkillId) {
        return ResponseEntity.ok(ApiResponse.success(
                skillService.toggleSkillEnabled(principal.getId(), technicianSkillId),
                "Skill active status updated"));
    }

    @PostMapping("/admin/{technicianSkillId}/verify")
    public ResponseEntity<ApiResponse<TechnicianSkillDtos.TechnicianSkillDto>> verifySkillAdmin(
            @PathVariable UUID technicianSkillId,
            @RequestBody TechnicianSkillDtos.VerifySkillAdminRequest req) {
        return ResponseEntity.ok(ApiResponse.success(
                skillService.verifySkillAdmin(technicianSkillId, req),
                "Skill verification status updated"));
    }
}
