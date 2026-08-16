package com.bookurtechnician.review.service;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.booking.repository.BookingRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.review.dto.ReviewDtos;
import com.bookurtechnician.review.entity.Review;
import com.bookurtechnician.review.repository.ReviewRepository;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final TechnicianProfileRepository technicianProfileRepository;

    @Transactional
    public ReviewDtos.ReviewResponse submitReview(UUID customerId, ReviewDtos.CreateReviewRequest req) {
        User customer = userRepository.findById(customerId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer not found"));

        Booking booking = bookingRepository.findById(req.getBookingId())
                .orElseThrow(() -> new ResourceNotFoundException("Booking not found: " + req.getBookingId()));

        if (!booking.getCustomer().getId().equals(customerId)) {
            throw new BadRequestException("You can only submit reviews for your own bookings.");
        }

        if (!"COMPLETED".equalsIgnoreCase(booking.getStatus())) {
            throw new BadRequestException("You can only review a booking after the service is COMPLETED.");
        }

        if (booking.getTechnician() == null) {
            throw new BadRequestException("No technician was assigned to this booking.");
        }

        if (reviewRepository.findByBookingId(booking.getId()).isPresent()) {
            throw new BadRequestException("A review has already been submitted for this booking.");
        }

        Review review = Review.builder()
                .booking(booking)
                .customer(customer)
                .technician(booking.getTechnician())
                .rating(req.getRating())
                .reviewText(req.getReviewText() != null ? req.getReviewText().trim() : "")
                .hidden(false)
                .flagged(false)
                .build();

        review = reviewRepository.save(review);

        // Recalculate technician rating dynamically from PostgreSQL
        TechnicianProfile technician = booking.getTechnician();
        Double avgRating = reviewRepository.getAverageRatingForTechnician(technician.getId());
        long totalRatings = reviewRepository.countReviewsForTechnician(technician.getId());

        if (avgRating != null) {
            technician.setRating(BigDecimal.valueOf(avgRating).setScale(1, RoundingMode.HALF_UP));
            technician.setTotalRatingsCount((int) totalRatings);
            technicianProfileRepository.save(technician);
        }

        log.info("Saved review {} for booking {}. New technician rating: {}", review.getId(), booking.getBookingCode(), technician.getRating());

        return mapToResponse(review);
    }

    public List<ReviewDtos.ReviewResponse> getAllReviewsForAdmin() {
        return reviewRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<ReviewDtos.ReviewResponse> getPublicReviewsForTechnician(UUID technicianId) {
        return reviewRepository.findByTechnicianIdAndHiddenFalseOrderByCreatedAtDesc(technicianId).stream()
                .map(this::mapToResponse)
                .toList();
    }

    @Transactional
    public ReviewDtos.ReviewResponse toggleReviewVisibility(UUID reviewId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found: " + reviewId));

        review.setHidden(!review.isHidden());
        review = reviewRepository.save(review);

        // Recalculate technician rating after hiding/unhiding
        TechnicianProfile technician = review.getTechnician();
        Double avgRating = reviewRepository.getAverageRatingForTechnician(technician.getId());
        long totalRatings = reviewRepository.countReviewsForTechnician(technician.getId());
        if (avgRating != null) {
            technician.setRating(BigDecimal.valueOf(avgRating).setScale(1, RoundingMode.HALF_UP));
            technician.setTotalRatingsCount((int) totalRatings);
            technicianProfileRepository.save(technician);
        }

        return mapToResponse(review);
    }

    private ReviewDtos.ReviewResponse mapToResponse(Review r) {
        return ReviewDtos.ReviewResponse.builder()
                .id(r.getId())
                .bookingId(r.getBooking().getId())
                .customerName(r.getCustomer().getFullName() != null ? r.getCustomer().getFullName() : "Customer")
                .technicianName(r.getTechnician().getUser().getFullName() != null ? r.getTechnician().getUser().getFullName() : "Technician")
                .technicianCode(r.getTechnician().getTechnicianCode())
                .serviceName(r.getBooking().getService().getName())
                .rating(r.getRating())
                .reviewText(r.getReviewText())
                .hidden(r.isHidden())
                .flagged(r.isFlagged())
                .createdAt(r.getCreatedAt())
                .build();
    }
}
