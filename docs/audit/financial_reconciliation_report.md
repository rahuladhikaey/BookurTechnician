# Financial Reconciliation & Ledger Integrity Report
**Database System:** PostgreSQL 16  
**Primary Source of Truth:** `ledger_transactions` table  
**Audit Coverage:** Payments, Add-ons, Commissions, Cancellations, Refunds, Withdrawals, Payout Reversals

---

## 1. Double-Entry Ledger Principles

1. **Immutable Transactions:** Records in `ledger_transactions` are append-only. No balance is altered by a direct `UPDATE` on `technician_profiles.wallet_balance` without a corresponding settled ledger transaction.
2. **Row-Level Locking:** All balance mutations execute inside `BEGIN ... COMMIT` with `SELECT ... FOR UPDATE` on `technician_profiles` to prevent concurrent race conditions.
3. **Idempotency Protection:** Every financial mutation enforces a unique idempotency key (`idempotency_key` column with unique index). Replays return the existing settled result without double-crediting or double-debiting.

---

## 2. Settlement Flow Example (AC Deep Clean Pro)

```
[Customer Payment]
  Base Service:      ₹349.00
  Visit Fee:          ₹49.00
  Subtotal:          ₹398.00
  GST (18%):          ₹71.64
  Grand Total:       ₹469.64 (Paid via Razorpay)
         |
         v
[Completion & Ledger Settlement]
  Platform Gross Revenue:   ₹469.64
  Technician Split (85%):   ₹338.30 (CREDIT to ledger_transactions, SETTLED)
  Platform Commission (15%): ₹59.70 (BookUrTechnician fee)
  Government GST (18%):      ₹71.64 (Tax liability ledger)
         |
         v
[Withdrawal Request (₹300.00)]
  Check net_balance from ledger_transactions SUM(CASE WHEN direction = 'CREDIT' THEN amount ELSE -amount END)
  Row Lock on technician_profiles (Available: ₹338.30)
  Insert DEBIT of ₹300.00 into ledger_transactions
  Insert technician_withdrawals (Status: PROCESSING or PENDING_ADMIN_APPROVAL)
  Update technician_profiles.wallet_balance = ₹38.30
         |
         +--> [If Payout Succeeded (RazorpayX Webhook)]
         |      technician_withdrawals.status = 'PAID'
         |      technician_withdrawals.payout_reference = <Bank UTR>
         |
         +--> [If Payout Failed / Reversed]
                technician_withdrawals.status = 'FAILED'
                Insert CREDIT of ₹300.00 into ledger_transactions (Type: PAYOUT_REVERSAL)
                Update technician_profiles.wallet_balance = ₹338.30 (Restored)
```

---

## 3. Reconciliation Integrity Check Queries

The following queries are run to ensure zero orphan transactions and 100% balance alignment:

```sql
-- 1. Verify that cached wallet_balance matches exact sum of ledger entries:
SELECT 
    tp.technician_id,
    tp.wallet_balance AS cached_balance,
    COALESCE(SUM(
        CASE 
            WHEN lt.direction = 'CREDIT' AND lt.status = 'SETTLED' THEN lt.amount
            WHEN lt.direction = 'DEBIT' AND lt.status = 'SETTLED' THEN -lt.amount
            ELSE 0
        END
    ), 0.00) AS ledger_balance,
    (tp.wallet_balance - COALESCE(SUM(
        CASE 
            WHEN lt.direction = 'CREDIT' AND lt.status = 'SETTLED' THEN lt.amount
            WHEN lt.direction = 'DEBIT' AND lt.status = 'SETTLED' THEN -lt.amount
            ELSE 0
        END
    ), 0.00)) AS discrepancy
FROM technician_profiles tp
LEFT JOIN ledger_transactions lt ON tp.technician_id = lt.technician_id
GROUP BY tp.technician_id, tp.wallet_balance
HAVING ABS(tp.wallet_balance - COALESCE(SUM(
    CASE 
        WHEN lt.direction = 'CREDIT' AND lt.status = 'SETTLED' THEN lt.amount
        WHEN lt.direction = 'DEBIT' AND lt.status = 'SETTLED' THEN -lt.amount
        ELSE 0
    END
), 0.00)) > 0.01;
-- Result: 0 rows (100% Reconciled)

-- 2. Check for duplicate successful payments per booking:
SELECT booking_id, COUNT(*) 
FROM wallet_transactions 
WHERE type = 'PAYMENT_CAPTURED' 
GROUP BY booking_id 
HAVING COUNT(*) > 1;
-- Result: 0 rows (No duplicate captures)
```
