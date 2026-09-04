package com.bookurtechnician.controller;

import com.bookurtechnician.dto.AdminAvailabilityOverviewDto;
import com.bookurtechnician.service.AdminAvailabilityService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AdminAvailabilityController {

    private final AdminAvailabilityService adminAvailabilityService;

    @GetMapping("/availability-overview")
    public ResponseEntity<AdminAvailabilityOverviewDto> getAvailabilityOverview(
            @RequestParam(value = "radiusKm", required = false, defaultValue = "15") Double radiusKm
    ) {
        AdminAvailabilityOverviewDto overview = adminAvailabilityService.getOverview(radiusKm);
        return ResponseEntity.ok(overview);
    }
}
