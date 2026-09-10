package com.bookurtechnician.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@CrossOrigin(origins = "*")
public class HealthController {

    private final Instant startTime = Instant.now();

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> healthCheck() {
        Map<String, Object> status = new HashMap<>();
        status.put("status", "HEALTHY");
        status.put("service", "bookurtechnician-java-ledger-service");
        status.put("runtime", "Java 21 Spring Boot 3");
        status.put("engine", "ACID Double-Entry Ledger & PostGIS Spatial Engine");
        status.put("uptimeSince", startTime.toString());
        return ResponseEntity.ok(status);
    }
}
