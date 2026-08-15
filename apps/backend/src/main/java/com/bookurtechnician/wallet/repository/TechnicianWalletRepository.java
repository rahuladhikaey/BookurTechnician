package com.bookurtechnician.wallet.repository;

import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.wallet.entity.TechnicianWallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface TechnicianWalletRepository extends JpaRepository<TechnicianWallet, UUID> {
    Optional<TechnicianWallet> findByTechnician(TechnicianProfile technician);
    Optional<TechnicianWallet> findByTechnicianId(UUID technicianId);
}
