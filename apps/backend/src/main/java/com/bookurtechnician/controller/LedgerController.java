package com.bookurtechnician.controller;

import com.bookurtechnician.model.WalletLedger;
import com.bookurtechnician.service.LedgerService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/ledger")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class LedgerController {

    private final LedgerService ledgerService;

    @Data
    public static class SettleRequest {
        private String bookingId;
        private String technicianId;
        private String customerId;
        private BigDecimal totalAmount;
        private BigDecimal commissionAmount;
        private BigDecimal payoutAmount;
    }

    @PostMapping("/settle")
    public ResponseEntity<Map<String, Object>> settleBooking(@RequestBody SettleRequest req) {
        BigDecimal amount = req.getTotalAmount() != null ? req.getTotalAmount() : new BigDecimal("299.00");
        String techId = req.getTechnicianId() != null ? req.getTechnicianId() : "tech-001";

        WalletLedger ledger = ledgerService.settleBookingPayment(
                req.getBookingId(),
                techId,
                req.getCustomerId(),
                amount
        );

        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("ledgerId", ledger.getId());
        response.put("amount", ledger.getAmount());
        response.put("commission", ledger.getPlatformCommission());
        response.put("netPayout", ledger.getNetPayout());
        response.put("message", "ACID Settlement processed successfully");

        return ResponseEntity.ok(response);
    }

    @GetMapping("/wallet/{userId}")
    public ResponseEntity<Map<String, Object>> getWalletSummary(@PathVariable String userId) {
        BigDecimal balance = ledgerService.getUserBalance(userId);
        List<WalletLedger> history = ledgerService.getUserLedgerHistory(userId);

        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("userId", userId);
        response.put("currentBalance", balance);
        response.put("totalTransactions", history.size());
        response.put("transactions", history);

        return ResponseEntity.ok(response);
    }
}
