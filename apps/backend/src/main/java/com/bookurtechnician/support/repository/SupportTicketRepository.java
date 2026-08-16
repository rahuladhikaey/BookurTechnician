package com.bookurtechnician.support.repository;

import com.bookurtechnician.support.entity.SupportTicket;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SupportTicketRepository extends JpaRepository<SupportTicket, UUID> {
    Optional<SupportTicket> findByTicketNumber(String ticketNumber);
    List<SupportTicket> findByStatus(String status);
    List<SupportTicket> findByUserId(UUID userId);
    long countByStatus(String status);
}
