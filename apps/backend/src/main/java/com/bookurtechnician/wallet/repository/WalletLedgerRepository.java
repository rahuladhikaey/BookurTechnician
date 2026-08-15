package com.bookurtechnician.wallet.repository;

import com.bookurtechnician.wallet.entity.WalletLedger;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WalletLedgerRepository extends JpaRepository<WalletLedger, UUID> {
    List<WalletLedger> findByWalletIdOrderByCreatedAtDesc(UUID walletId);
}
