package com.bookurtechnician.wallet.repository;

import com.bookurtechnician.wallet.entity.WithdrawalRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WithdrawalRequestRepository extends JpaRepository<WithdrawalRequest, UUID> {
    List<WithdrawalRequest> findByTechnicianIdOrderByCreatedAtDesc(UUID technicianId);
    Optional<WithdrawalRequest> findByRequestCode(String requestCode);
    boolean existsByUtrNumber(String utrNumber);
    long countByStatus(String status);
}
