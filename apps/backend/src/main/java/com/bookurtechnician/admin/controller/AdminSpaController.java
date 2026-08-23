package com.bookurtechnician.admin.controller;

import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.io.IOException;

/**
 * Controller to directly serve the React Admin Single Page Application (SPA).
 * Streams index.html directly without requiring ViewResolvers to eliminate circular forward 500 errors.
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
    }, produces = MediaType.TEXT_HTML_VALUE)
    @ResponseBody
    public ResponseEntity<Resource> serveAdminSpa() throws IOException {
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
        return ResponseEntity.notFound().build();
    }
}
