package com.bookurtechnician.admin.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Controller to handle SPA (Single Page Application) routing for the React Admin Panel.
 * Supports both custom domain (admin.bookurtechnician.online) and sub-path routing (/admin/**).
 * Forwards non-API and non-static requests to /admin/index.html.
 */
@Controller
public class AdminSpaController {

    @GetMapping(value = {
            "/",
            "/admin",
            "/admin/**",
            "/{path:[^\\.]*}"
    })
    public String forwardAdminSpa() {
        return "forward:/admin/index.html";
    }
}
