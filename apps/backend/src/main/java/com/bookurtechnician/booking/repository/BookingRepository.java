package com.bookurtechnician.booking.repository;

import com.bookurtechnician.booking.entity.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingRepository extends JpaRepository<Booking, UUID> {
    List<Booking> findByCustomerIdOrderByCreatedAtDesc(UUID customerId);
    List<Booking> findByTechnicianIdOrderByCreatedAtDesc(UUID technicianId);
    Optional<Booking> findByBookingCode(String bookingCode);
    long countByStatus(String status);
}
