package com.bookurtechnician.booking.repository;

import com.bookurtechnician.booking.entity.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingRepository extends JpaRepository<Booking, UUID> {
    List<Booking> findByCustomerIdOrderByCreatedAtDesc(UUID customerId);
    List<Booking> findByTechnicianIdOrderByCreatedAtDesc(UUID technicianId);
    List<Booking> findAllByOrderByCreatedAtDesc();
    List<Booking> findByStatusOrderByCreatedAtDesc(String status);
    Optional<Booking> findByBookingCode(String bookingCode);
    
    long countByStatus(String status);
    long countByStatusIn(List<String> statuses);
    long countByCreatedAtAfter(Instant since);

    @Query("SELECT COALESCE(SUM(b.grandTotal), 0) FROM Booking b WHERE b.status = 'COMPLETED'")
    BigDecimal sumCompletedRevenue();

    @Query("SELECT COALESCE(SUM(b.grandTotal), 0) FROM Booking b WHERE b.status = 'COMPLETED' AND b.createdAt >= :since")
    BigDecimal sumRevenueSince(@Param("since") Instant since);
}
