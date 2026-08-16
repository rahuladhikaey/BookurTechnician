package com.bookurtechnician.payment.repository;

import com.bookurtechnician.payment.entity.Refund;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RefundRepository extends JpaRepository<Refund, UUID> {
    Optional<Refund> findByBookingId(UUID bookingId);
    Optional<Refund> findByRefundCode(String refundCode);
    List<Refund> findByStatus(String status);
    long countByStatus(String status);
}
