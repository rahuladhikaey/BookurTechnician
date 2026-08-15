package com.bookurtechnician.wallet.service;

import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.wallet.entity.TechnicianWallet;
import com.bookurtechnician.wallet.entity.WalletLedger;
import com.bookurtechnician.wallet.entity.WithdrawalRequest;
import com.bookurtechnician.wallet.repository.TechnicianWalletRepository;
import com.bookurtechnician.wallet.repository.WalletLedgerRepository;
import com.bookurtechnician.wallet.repository.WithdrawalRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WalletService {

    private final TechnicianWalletRepository walletRepository;
    private final WalletLedgerRepository ledgerRepository;
    private final WithdrawalRequestRepository withdrawalRequestRepository;
    private final TechnicianProfileRepository technicianProfileRepository;

    @Transactional
    public void creditTechnicianEarning(TechnicianProfile technician, BigDecimal amount, String bookingCode) {
        TechnicianWallet wallet = walletRepository.findByTechnician(technician)
                .orElseGet(() -> walletRepository.save(TechnicianWallet.builder()
                        .technician(technician)
                        .availableBalance(BigDecimal.ZERO)
                        .totalWithdrawn(BigDecimal.ZERO)
                        .build()));

        BigDecimal before = wallet.getAvailableBalance();
        BigDecimal after = before.add(amount);
        wallet.setAvailableBalance(after);
        walletRepository.save(wallet);

        // Record immutable ledger entry
        WalletLedger ledger = WalletLedger.builder()
                .wallet(wallet)
                .entryType("CREDIT")
                .amount(amount)
                .balanceBefore(before)
                .balanceAfter(after)
                .referenceType("BOOKING_EARNING")
                .referenceId(bookingCode)
                .description("Earnings credited for booking " + bookingCode)
                .build();
        ledgerRepository.save(ledger);

        log.info("Credited ₹{} to technician {} wallet for booking {}", amount, technician.getTechnicianCode(), bookingCode);
    }

    @Transactional
    public WithdrawalRequest requestUpiWithdrawal(UUID technicianId, BigDecimal amount, String upiId) {
        TechnicianProfile technician = technicianProfileRepository.findById(technicianId)
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        TechnicianWallet wallet = walletRepository.findByTechnician(technician)
                .orElseThrow(() -> new ResourceNotFoundException("Wallet not found"));

        if (wallet.getAvailableBalance().compareTo(amount) < 0) {
            throw new BadRequestException("Insufficient wallet balance for withdrawal.");
        }

        BigDecimal before = wallet.getAvailableBalance();
        BigDecimal after = before.subtract(amount);
        wallet.setAvailableBalance(after);
        wallet.setTotalWithdrawn(wallet.getTotalWithdrawn().add(amount));
        walletRepository.save(wallet);

        String requestCode = "WDR-" + (System.currentTimeMillis() % 1000000);

        // Record immutable ledger debit
        WalletLedger ledger = WalletLedger.builder()
                .wallet(wallet)
                .entryType("DEBIT")
                .amount(amount)
                .balanceBefore(before)
                .balanceAfter(after)
                .referenceType("UPI_WITHDRAWAL")
                .referenceId(requestCode)
                .description("Instant UPI withdrawal to " + upiId)
                .build();
        ledgerRepository.save(ledger);

        // Create settled withdrawal record
        WithdrawalRequest request = WithdrawalRequest.builder()
                .requestCode(requestCode)
                .technician(technician)
                .amount(amount)
                .destinationUpiId(upiId)
                .status("SETTLED")
                .razorpayxPayoutId("pout_" + UUID.randomUUID().toString().substring(0, 12))
                .utrNumber("UTR" + (System.currentTimeMillis() % 1000000000000L))
                .settledAt(Instant.now())
                .build();

        return withdrawalRequestRepository.save(request);
    }

    public List<WalletLedger> getLedgerHistory(UUID technicianId) {
        TechnicianWallet wallet = walletRepository.findByTechnicianId(technicianId)
                .orElseThrow(() -> new ResourceNotFoundException("Wallet not found"));
        return ledgerRepository.findByWalletIdOrderByCreatedAtDesc(wallet.getId());
    }

    public List<WithdrawalRequest> getPayoutHistory(UUID technicianId) {
        return withdrawalRequestRepository.findByTechnicianIdOrderByCreatedAtDesc(technicianId);
    }
}
