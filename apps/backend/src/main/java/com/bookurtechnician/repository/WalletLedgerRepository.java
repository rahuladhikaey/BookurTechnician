package com.bookurtechnician.repository;

import com.bookurtechnician.model.WalletLedger;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

@Repository
public interface WalletLedgerRepository extends JpaRepository<WalletLedger, String> {

    List<WalletLedger> findByUserIdOrderByCreatedAtDesc(String userId);

    @Query("SELECT COALESCE(SUM(CASE WHEN w.entryType = 'CREDIT' THEN w.netPayout ELSE -w.amount END), 0) FROM WalletLedger w WHERE w.userId = :userId")
    BigDecimal calculateUserBalance(@Param("userId") String userId);
}
