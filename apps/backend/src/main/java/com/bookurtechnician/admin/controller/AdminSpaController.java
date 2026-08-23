package com.bookurtechnician.admin.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.io.IOException;
import java.util.Map;

/**
 * Controller to handle Domain-Based Routing:
 * - admin.bookurtechnician.online -> Serves full React Enterprise Admin UI
 * - api.bookurtechnician.online -> Serves secure API Gateway status (Admin UI is completely hidden)
 */
@Controller
public class AdminSpaController {

    private final Resource adminIndexHtml = new ClassPathResource("static/admin/index.html");
    private final Resource rootIndexHtml = new ClassPathResource("static/index.html");

    @GetMapping(value = {
            "/",
            "/admin",
            "/admin/**",
            "/{path:[^\\.]*}"
    })
    @ResponseBody
    public ResponseEntity<?> serveSpaOrApiGateway(HttpServletRequest request) throws IOException {
        String host = request.getHeader("X-Forwarded-Host");
        if (host == null || host.isBlank()) {
            host = request.getHeader("Host");
        }
        if (host == null) {
            host = request.getServerName();
        }
        host = host.toLowerCase();

        // 1. If accessed via api.bookurtechnician.online, protect Admin UI and show only API gateway status
        if (host.startsWith("api.bookurtechnician.online") || host.startsWith("api.")) {
            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                            "service", "BookurTechnician API Gateway",
                            "status", "ACTIVE",
                            "environment", "production",
                            "message", "This endpoint is reserved exclusively for Mobile App APIs and WebSockets."
                    ));
        }

        // 2. For admin.bookurtechnician.online, localhost, or direct render host -> serve Admin Panel SPA
        if (adminIndexHtml.exists()) {
            return ResponseEntity.ok()
                    .contentType(MediaType.TEXT_HTML)
                    .body(adminIndexHtml);
        }
        if (rootIndexHtml.exists()) {
            return ResponseEntity.ok()
                    .contentType(MediaType.TEXT_HTML)
                    .body(rootIndexHtml);
        }

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Admin UI assets not found.");
    }
}
