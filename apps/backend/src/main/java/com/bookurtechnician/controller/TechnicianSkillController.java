package com.bookurtechnician.controller;

import com.bookurtechnician.dto.TechnicianSkillDto;
import com.bookurtechnician.dto.TechnicianSkillsBulkRequest;
import com.bookurtechnician.dto.TechnicianSkillsResponse;
import com.bookurtechnician.service.TechnicianSkillService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
@Slf4j
public class TechnicianSkillController {

    private final TechnicianSkillService technicianSkillService;

    @GetMapping({"/api/v1/technicians/skills", "/api/v1/technician/skills"})
    public ResponseEntity<Map<String, Object>> getSkills(
            Authentication authentication,
            @RequestParam(value = "technicianId", required = false) String paramTechId
    ) {
        String techId = resolveTechnicianId(authentication, paramTechId, null);
        TechnicianSkillsResponse response = technicianSkillService.getSkills(techId);

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("data", response);
        result.put("profile", response);
        result.put("skills", response.getSkills());
        result.put("count", response.getTotalSkillsCount());

        return ResponseEntity.ok(result);
    }

    @GetMapping({"/api/v1/technicians/skills/{id}", "/api/v1/technician/skills/{id}"})
    public ResponseEntity<Map<String, Object>> getSkillsForId(@PathVariable("id") String techId) {
        TechnicianSkillsResponse response = technicianSkillService.getSkills(techId);

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("data", response);
        result.put("profile", response);
        result.put("skills", response.getSkills());
        result.put("count", response.getTotalSkillsCount());

        return ResponseEntity.ok(result);
    }

    @PostMapping({
            "/api/v1/technicians/skills/bulk",
            "/api/v1/technician/skills/bulk",
            "/api/v1/technicians/skills",
            "/api/v1/technician/skills"
    })
    public ResponseEntity<Map<String, Object>> saveSkillsBulk(
            Authentication authentication,
            @RequestBody(required = false) Map<String, Object> body
    ) {
        String bodyTechId = body != null ? (String) body.get("technicianId") : null;
        String techId = resolveTechnicianId(authentication, bodyTechId, null);

        List<TechnicianSkillDto> skillDtos = new ArrayList<>();

        if (body != null) {
            Object rawSkills = body.get("skills");
            if (rawSkills == null) {
                rawSkills = body.get("data");
            }

            if (rawSkills instanceof List<?> list) {
                for (Object item : list) {
                    if (item instanceof Map<?, ?> m) {
                        String sId = (String) m.get("skillId");
                        if (sId == null) sId = (String) m.get("id");
                        if (sId == null) sId = (String) m.get("name");

                        String name = (String) m.get("skillName");
                        if (name == null) name = (String) m.get("name");

                        String catId = (String) m.get("categoryId");
                        String catName = (String) m.get("categoryName");

                        Integer exp = 2;
                        if (m.get("experienceYears") instanceof Number n) {
                            exp = n.intValue();
                        }

                        skillDtos.add(TechnicianSkillDto.builder()
                                .skillId(sId)
                                .skillName(name != null ? name : sId)
                                .categoryId(catId)
                                .categoryName(catName)
                                .experienceYears(exp)
                                .enabled(true)
                                .build());
                    } else if (item instanceof String str) {
                        skillDtos.add(TechnicianSkillDto.builder()
                                .skillId(str)
                                .skillName(str)
                                .experienceYears(2)
                                .enabled(true)
                                .build());
                    }
                }
            }
        }

        TechnicianSkillsResponse response = technicianSkillService.saveSkills(techId, skillDtos);

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("message", "Skills saved successfully and synchronized for 15km availability");
        result.put("data", response);
        result.put("profile", response);
        result.put("skills", response.getSkills());
        result.put("count", response.getTotalSkillsCount());

        return ResponseEntity.ok(result);
    }

    @PutMapping({"/api/v1/technicians/skills", "/api/v1/technician/skills"})
    public ResponseEntity<Map<String, Object>> updateSkills(
            Authentication authentication,
            @RequestBody(required = false) Map<String, Object> body
    ) {
        return saveSkillsBulk(authentication, body);
    }

    @PatchMapping({"/api/v1/technicians/skills/{id}/toggle", "/api/v1/technician/skills/{id}/toggle"})
    public ResponseEntity<Map<String, Object>> toggleSkill(
            Authentication authentication,
            @PathVariable("id") String skillId
    ) {
        String techId = resolveTechnicianId(authentication, null, null);
        boolean success = technicianSkillService.toggleSkill(techId, skillId);

        return ResponseEntity.ok(Map.of(
                "success", success,
                "message", success ? "Skill toggled successfully" : "Skill toggle failed"
        ));
    }

    private String resolveTechnicianId(Authentication authentication, String explicitId, String fallback) {
        if (explicitId != null && !explicitId.trim().isEmpty()) {
            return explicitId.trim();
        }
        if (authentication != null && authentication.getName() != null && !authentication.getName().trim().isEmpty()) {
            return authentication.getName().trim();
        }
        return fallback != null ? fallback : "tech-001";
    }
}
