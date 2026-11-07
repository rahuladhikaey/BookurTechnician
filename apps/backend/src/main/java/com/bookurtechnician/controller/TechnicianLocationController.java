package com.bookurtechnician.controller;

import com.bookurtechnician.dto.OnlineStatusRequest;
import com.bookurtechnician.dto.TechnicianLocationRequest;
import com.bookurtechnician.service.TechnicianLocationService;
import com.bookurtechnician.service.TechnicianStatusService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/technician")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class TechnicianLocationController {

    private final TechnicianLocationService technicianLocationService;
    private final TechnicianStatusService technicianStatusService;

    /**
     * POST /api/v1/technician/location
     * Strictly authenticates technician identity via JWT Bearer token
     */
    @PostMapping("/location")
    public ResponseEntity<?> updateLocation(
            Authentication authentication,
            @Valid @RequestBody TechnicianLocationRequest request
    ) {
        if (authentication == null || authentication.getName() == null || authentication.getName().trim().isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "success", false,
                    "error", "Authentication required: valid technician JWT token required"
            ));
        }

        String technicianId = authentication.getName();
        technicianLocationService.updateLocation(technicianId, request);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Location updated successfully in PostGIS and Redis GEO",
                "technicianId", technicianId,
                "latitude", request.getLatitude(),
                "longitude", request.getLongitude()
        ));
    }

    /**
     * POST /api/v1/technician/online-status
     */
    @PostMapping("/online-status")
    public ResponseEntity<?> updateOnlineStatus(
            Authentication authentication,
            @Valid @RequestBody OnlineStatusRequest request
    ) {
        if (authentication == null || authentication.getName() == null || authentication.getName().trim().isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "success", false,
                    "error", "Authentication required: valid technician JWT token required"
            ));
        }

        String technicianId = authentication.getName();
        technicianStatusService.updateStatus(technicianId, request.getIsOnline(), request.getAvailabilityStatus());

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Online status updated successfully",
                "technicianId", technicianId,
                "isOnline", request.getIsOnline()
        ));
    }
}
