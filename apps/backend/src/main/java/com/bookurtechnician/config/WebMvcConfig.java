package com.bookurtechnician.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.concurrent.TimeUnit;
import org.springframework.http.CacheControl;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Serve assets under /assets/**
        registry.addResourceHandler("/assets/**")
                .addResourceLocations("classpath:/static/admin/assets/", "classpath:/static/assets/")
                .setCacheControl(CacheControl.maxAge(1, TimeUnit.HOURS).mustRevalidate());

        // Serve admin assets under /admin/**
        registry.addResourceHandler("/admin/**")
                .addResourceLocations("classpath:/static/admin/")
                .setCacheControl(CacheControl.maxAge(1, TimeUnit.HOURS).mustRevalidate());

        // Serve static resources from classpath:/static/admin/ and classpath:/static/
        registry.addResourceHandler("/**")
                .addResourceLocations("classpath:/static/admin/", "classpath:/static/", "classpath:/public/")
                .setCacheControl(CacheControl.maxAge(1, TimeUnit.HOURS).mustRevalidate());
    }
}
