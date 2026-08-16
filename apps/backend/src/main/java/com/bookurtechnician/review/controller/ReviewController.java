package com.bookurtechnician.review.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.review.dto.ReviewDtos;
import com.bookurtechnician.review.service.ReviewService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;

    @PostMapping("/reviews")
    public ResponseEntity<ApiResponse<ReviewDtos.ReviewResponse>> submitReview(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody ReviewDtos.CreateReviewRequest request) {
        ReviewDtos.ReviewResponse response = reviewService.submitReview(principal.getId(), request);
        return ResponseEntity.ok(ApiResponse.success(response, "Thank you! Your review has been submitted successfully."));
    }

    @GetMapping("/reviews/technician/{technicianId}")
    public ResponseEntity<ApiResponse<List<ReviewDtos.ReviewResponse>>> getTechnicianReviews(
            @PathVariable UUID technicianId) {
        List<ReviewDtos.ReviewResponse> reviews = reviewService.getPublicReviewsForTechnician(technicianId);
        return ResponseEntity.ok(ApiResponse.success(reviews));
    }

    @GetMapping("/admin/reviews")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<ReviewDtos.ReviewResponse>>> getAllReviewsForAdmin() {
        List<ReviewDtos.ReviewResponse> reviews = reviewService.getAllReviewsForAdmin();
        return ResponseEntity.ok(ApiResponse.success(reviews));
    }

    @PatchMapping("/admin/reviews/{reviewId}/hide")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<ReviewDtos.ReviewResponse>> toggleReviewVisibility(
            @PathVariable UUID reviewId) {
        ReviewDtos.ReviewResponse response = reviewService.toggleReviewVisibility(reviewId);
        return ResponseEntity.ok(ApiResponse.success(response, "Review visibility status updated"));
    }
}
