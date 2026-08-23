package com.bookurtechnician.wallet.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.wallet.entity.TechnicianWallet;
import com.bookurtechnician.wallet.entity.WalletLedger;
import com.bookurtechnician.wallet.entity.WithdrawalRequest;
import com.bookurtechnician.wallet.repository.TechnicianWalletRepository;
import com.bookurtechnician.wallet.service.WalletService;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/v1/wallet")
public class WalletController {

    private final WalletService walletService;
    private final TechnicianProfileRepository technicianProfileRepository;
    private final TechnicianWalletRepository walletRepository;

    public WalletController(WalletService walletService,
                            TechnicianProfileRepository technicianProfileRepository,
                            TechnicianWalletRepository walletRepository) {
        this.walletService = walletService;
        this.technicianProfileRepository = technicianProfileRepository;
        this.walletRepository = walletRepository;
    }

    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<WalletSummaryDto>> getSummary(@AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile tech = technicianProfileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        TechnicianWallet wallet = walletRepository.findByTechnician(tech)
                .orElseGet(() -> walletRepository.save(TechnicianWallet.builder()
                        .technician(tech)
                        .availableBalance(BigDecimal.ZERO)
                        .totalWithdrawn(BigDecimal.ZERO)
                        .build()));

        WalletSummaryDto summary = WalletSummaryDto.builder()
                .availableBalance(wallet.getAvailableBalance())
                .totalWithdrawn(wallet.getTotalWithdrawn())
                .savedUpiId(tech.getUpiId())
                .isUpiVerified(tech.isUpiVerified())
                .build();

        return ResponseEntity.ok(ApiResponse.success(summary));
    }

    @PostMapping("/withdraw")
    public ResponseEntity<ApiResponse<WithdrawalRequest>> withdraw(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody WithdrawRequestDto dto) {
        TechnicianProfile tech = technicianProfileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        String upi = dto.getUpiId() != null && !dto.getUpiId().isBlank() ? dto.getUpiId() : tech.getUpiId();

        WithdrawalRequest result = walletService.requestUpiWithdrawal(tech.getId(), dto.getAmount(), upi);
        return ResponseEntity.ok(ApiResponse.success(result, "₹" + dto.getAmount() + " transferred instantly to " + upi));
    }

    @GetMapping("/ledger")
    public ResponseEntity<ApiResponse<List<WalletLedger>>> getLedger(@AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile tech = technicianProfileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        List<WalletLedger> ledger = walletService.getLedgerHistory(tech.getId());
        return ResponseEntity.ok(ApiResponse.success(ledger));
    }

    @GetMapping("/payouts")
    public ResponseEntity<ApiResponse<List<WithdrawalRequest>>> getPayouts(@AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile tech = technicianProfileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician not found"));

        List<WithdrawalRequest> payouts = walletService.getPayoutHistory(tech.getId());
        return ResponseEntity.ok(ApiResponse.success(payouts));
    }

    public static class WalletSummaryDto {
        private BigDecimal availableBalance;
        private BigDecimal totalWithdrawn;
        private String savedUpiId;
        private boolean isUpiVerified;

        public WalletSummaryDto() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private BigDecimal availableBalance;
            private BigDecimal totalWithdrawn;
            private String savedUpiId;
            private boolean isUpiVerified;

            public Builder availableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; return this; }
            public Builder totalWithdrawn(BigDecimal totalWithdrawn) { this.totalWithdrawn = totalWithdrawn; return this; }
            public Builder savedUpiId(String savedUpiId) { this.savedUpiId = savedUpiId; return this; }
            public Builder isUpiVerified(boolean isUpiVerified) { this.isUpiVerified = isUpiVerified; return this; }

            public WalletSummaryDto build() {
                WalletSummaryDto dto = new WalletSummaryDto();
                dto.availableBalance = this.availableBalance;
                dto.totalWithdrawn = this.totalWithdrawn;
                dto.savedUpiId = this.savedUpiId;
                dto.isUpiVerified = this.isUpiVerified;
                return dto;
            }
        }

        public BigDecimal getAvailableBalance() { return availableBalance; }
        public void setAvailableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; }
        public BigDecimal getTotalWithdrawn() { return totalWithdrawn; }
        public void setTotalWithdrawn(BigDecimal totalWithdrawn) { this.totalWithdrawn = totalWithdrawn; }
        public String getSavedUpiId() { return savedUpiId; }
        public void setSavedUpiId(String savedUpiId) { this.savedUpiId = savedUpiId; }
        public boolean isUpiVerified() { return isUpiVerified; }
        public void setUpiVerified(boolean upiVerified) { isUpiVerified = upiVerified; }
    }

    public static class WithdrawRequestDto {
        @NotNull
        @DecimalMin("1.00")
        private BigDecimal amount;
        private String upiId;

        public WithdrawRequestDto() {}

        public BigDecimal getAmount() { return amount; }
        public void setAmount(BigDecimal amount) { this.amount = amount; }
        public String getUpiId() { return upiId; }
        public void setUpiId(String upiId) { this.upiId = upiId; }
    }
}
