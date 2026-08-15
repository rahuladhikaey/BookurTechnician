package com.bookurtechnician.servicecatalog.controller;

import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.servicecatalog.repository.ServiceCategoryRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/catalog")
@RequiredArgsConstructor
public class ServiceCatalogController {

    private final ServiceCategoryRepository categoryRepository;
    private final ServiceItemRepository itemRepository;

    @GetMapping("/categories")
    public ResponseEntity<ApiResponse<List<ServiceCategory>>> getCategories() {
        List<ServiceCategory> categories = categoryRepository.findByActiveTrueOrderByDisplayOrderAsc();
        return ResponseEntity.ok(ApiResponse.success(categories));
    }

    @GetMapping("/categories/{categoryId}/services")
    public ResponseEntity<ApiResponse<List<ServiceItem>>> getServicesByCategory(@PathVariable UUID categoryId) {
        List<ServiceItem> items = itemRepository.findByCategoryIdAndActiveTrue(categoryId);
        return ResponseEntity.ok(ApiResponse.success(items));
    }

    @GetMapping("/services/popular")
    public ResponseEntity<ApiResponse<List<ServiceItem>>> getPopularServices() {
        List<ServiceItem> popular = itemRepository.findByPopularTrueAndActiveTrue();
        return ResponseEntity.ok(ApiResponse.success(popular));
    }
}
