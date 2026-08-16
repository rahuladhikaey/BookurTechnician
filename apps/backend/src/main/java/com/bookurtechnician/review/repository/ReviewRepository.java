package com.bookurtechnician.review.repository;

import com.bookurtechnician.review.entity.Review;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReviewRepository extends JpaRepository<Review, UUID> {

    Optional<Review> findByBookingId(UUID bookingId);

    List<Review> findByTechnicianIdAndHiddenFalseOrderByCreatedAtDesc(UUID technicianId);

    List<Review> findAllByOrderByCreatedAtDesc();

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.technician.id = :technicianId AND r.hidden = false")
    Double getAverageRatingForTechnician(@Param("technicianId") UUID technicianId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.technician.id = :technicianId AND r.hidden = false")
    long countReviewsForTechnician(@Param("technicianId") UUID technicianId);
}
