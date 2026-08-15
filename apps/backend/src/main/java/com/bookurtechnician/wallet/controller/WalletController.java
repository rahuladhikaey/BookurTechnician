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
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/v1/wallet")
@RequiredArgsConstructor
public class WalletController {

    private final WalletService walletService;
    private final TechnicianProfileRepository technicianProfileRepository;
    private final TechnicianWalletRepository walletRepository;

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

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class WalletSummaryDto {
        private BigDecimal availableBalance;
        private BigDecimal totalWithdrawn;
        private String savedUpiId;
        private boolean isUpiVerified;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class WithdrawRequestDto {
        @NotNull
        @DecimalMin("1.00")
        private BigDecimal amount;
        private String upiId;
    }
}
