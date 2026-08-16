package com.bookurtechnician.dispatch.repository;

import com.bookurtechnician.dispatch.entity.BookingProposal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingProposalRepository extends JpaRepository<BookingProposal, UUID> {

    List<BookingProposal> findByBookingIdOrderByCreatedAtAsc(UUID bookingId);

    Optional<BookingProposal> findByBookingIdAndTechnicianIdAndStatus(UUID bookingId, UUID technicianId, String status);

    List<BookingProposal> findByTechnicianIdAndStatus(UUID technicianId, String status);

    @Query("SELECT bp FROM BookingProposal bp WHERE bp.status = 'PENDING' AND bp.expiresAt <= :now")
    List<BookingProposal> findExpiredPendingProposals(@Param("now") Instant now);

    boolean existsByBookingIdAndTechnicianId(UUID bookingId, UUID technicianId);
}
