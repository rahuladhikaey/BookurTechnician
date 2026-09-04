package com.bookurtechnician.controller;

import com.bookurtechnician.dto.AvailabilityResponse;
import com.bookurtechnician.service.TechnicianAvailabilityService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/catalog")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class CatalogAvailabilityController {

    private final TechnicianAvailabilityService technicianAvailabilityService;

    /**
     * Real PostGIS 15 KM Nearby Technician Availability Endpoint
     * GET /api/v1/catalog/availability?latitude=22.5726&longitude=88.3639&radiusKm=15
     */
    @GetMapping("/availability")
    public ResponseEntity<AvailabilityResponse> getAvailability(
            @RequestParam("latitude") Double latitude,
            @RequestParam("longitude") Double longitude,
            @RequestParam(value = "radiusKm", required = false, defaultValue = "15") Double radiusKm
    ) {
        AvailabilityResponse response = technicianAvailabilityService.getAvailability(latitude, longitude, radiusKm);
        return ResponseEntity.ok(response);
    }
}
