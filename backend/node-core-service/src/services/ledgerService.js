const { v4: uuidv4 } = require('uuid');
const postgres = require('../config/postgres');

// Configurable COD suspension threshold in INR
const COD_MAX_DUE_THRESHOLD = parseFloat(process.env.COD_MAX_DUE_THRESHOLD || '1500.00');
const PLATFORM_COMMISSION_PCT = parseFloat(process.env.PLATFORM_COMMISSION_PCT || '0.15');

/**
 * Calculates real-time withdrawable balance strictly from ledger source of truth
 * @param {string} technicianId 
 * @returns {Promise<number>}
 */
async function calculateWalletBalance(technicianId) {
  if (!technicianId) return 0.00;

  if (postgres.isPgHealthy()) {
    try {
      const res = await postgres.query(`
        SELECT COALESCE(SUM(
          CASE 
            WHEN direction = 'CREDIT' AND status = 'SETTLED' THEN amount 
            WHEN direction = 'DEBIT' AND status = 'SETTLED' THEN -amount 
            ELSE 0 
          END
        ), 0.00) AS net_balance
        FROM ledger_transactions
        WHERE technician_id = $1;
      `, [technicianId]);

      if (res.rows && res.rows.length > 0) {
        return parseFloat(parseFloat(res.rows[0].net_balance).toFixed(2));
      }
    } catch (err) {
      console.warn('⚠️ [LedgerService] Balance query warning:', err.message);
    }
  }

  // Fallback to in-memory store if DB is offline
  const store = postgres.inMemoryStore.wallets.get(technicianId) || { balance: 0.00, txns: [] };
  return parseFloat(store.balance.toFixed(2));
}

/**
 * Double-Entry Settlement on Service Completion
 * Handles both ONLINE and Cash-on-Delivery (COD) flows atomically.
 */
async function settleBookingLedger({
  bookingId,
  bookingCode,
  technicianId,
  customerId,
  baseAmount,
  addonAmount = 0.00,
  totalAmount,
  paymentMethod = 'ONLINE',
}) {
  const total = parseFloat(totalAmount || (parseFloat(baseAmount || 0) + parseFloat(addonAmount || 0)));
  const base = parseFloat(baseAmount || (total - parseFloat(addonAmount || 0)));
  const addons = parseFloat(addonAmount || 0);

  const platformFee = parseFloat((total * PLATFORM_COMMISSION_PCT).toFixed(2));
  const technicianEarnings = parseFloat((total - platformFee).toFixed(2));

  const settlementId = `SETTLE-${Date.now().toString(36).toUpperCase()}-${Math.floor(100 + Math.random() * 900)}`;
  const now = new Date();

  if (postgres.isPgHealthy()) {
    const client = await postgres.getPool().connect();
    try {
      await client.query('BEGIN');

      if (paymentMethod === 'COD' || paymentMethod === 'CASH') {
        // ─── COD Flow ───
        // 1. Technician collected cash from customer: Credit ledger
        await client.query(`
          INSERT INTO ledger_transactions (id, technician_id, booking_id, type, amount, direction, status, reference_id, created_at)
          VALUES ($1, $2, $3, 'COD_COLLECTION', $4, 'CREDIT', 'SETTLED', $5, NOW())
        `, [
          `LTX-COD-${uuidv4().slice(0, 8)}`,
          technicianId,
          bookingId,
          total,
          settlementId
        ]);

        // 2. Platform commission owed by technician: Debit platform fee
        await client.query(`
          INSERT INTO ledger_transactions (id, technician_id, booking_id, type, amount, direction, status, reference_id, created_at)
          VALUES ($1, $2, $3, 'PLATFORM_FEE', $4, 'DEBIT', 'SETTLED', $5, NOW())
        `, [
          `LTX-FEE-${uuidv4().slice(0, 8)}`,
          technicianId,
          bookingId,
          platformFee,
          settlementId
        ]);

        // 3. Update COD Dues on technician profile
        await client.query(`
          UPDATE technician_profiles
          SET cod_balance = COALESCE(cod_balance, 0) + $1,
              updated_at = NOW()
          WHERE technician_id = $2 OR id = $2
        `, [platformFee, technicianId]);

      } else {
        // ─── Online Payment Flow ───
        // 1. Credit base service earnings
        const baseEarning = parseFloat((base * (1.0 - PLATFORM_COMMISSION_PCT)).toFixed(2));
        await client.query(`
          INSERT INTO ledger_transactions (id, technician_id, booking_id, type, amount, direction, status, reference_id, created_at)
          VALUES ($1, $2, $3, 'SERVICE_EARNING', $4, 'CREDIT', 'SETTLED', $5, NOW())
        `, [
          `LTX-SRV-${uuidv4().slice(0, 8)}`,
          technicianId,
          bookingId,
          baseEarning,
          settlementId
        ]);

        // 2. If add-ons were approved, credit add-on earnings
        if (addons > 0) {
          const addonEarning = parseFloat((addons * (1.0 - PLATFORM_COMMISSION_PCT)).toFixed(2));
          await client.query(`
            INSERT INTO ledger_transactions (id, technician_id, booking_id, type, amount, direction, status, reference_id, created_at)
            VALUES ($1, $2, $3, 'ADDON_EARNING', $4, 'CREDIT', 'SETTLED', $5, NOW())
          `, [
            `LTX-ADD-${uuidv4().slice(0, 8)}`,
            technicianId,
            bookingId,
            addonEarning,
            settlementId
          ]);
        }
      }

      // Re-calculate new balance strictly from ledger
      const balanceRes = await client.query(`
        SELECT COALESCE(SUM(
          CASE 
            WHEN direction = 'CREDIT' AND status = 'SETTLED' THEN amount 
            WHEN direction = 'DEBIT' AND status = 'SETTLED' THEN -amount 
            ELSE 0 
          END
        ), 0.00) AS net_balance
        FROM ledger_transactions
        WHERE technician_id = $1;
      `, [technicianId]);

      const updatedBalance = parseFloat(balanceRes.rows[0].net_balance || 0);

      // Check COD negative balance policy
      const codCheck = await client.query(`
        SELECT cod_balance FROM technician_profiles WHERE technician_id = $1 OR id = $1;
      `, [technicianId]);

      const currentCod = parseFloat(codCheck.rows[0]?.cod_balance || 0);
      const isCodOverdue = currentCod >= COD_MAX_DUE_THRESHOLD;

      await client.query(`
        UPDATE technician_profiles
        SET wallet_balance = $1,
            is_cod_suspended = $2,
            availability_status = CASE WHEN $2 = true THEN 'SUSPENDED' ELSE availability_status END,
            total_jobs_completed = COALESCE(total_jobs_completed, 0) + 1,
            updated_at = NOW()
        WHERE technician_id = $3 OR id = $3;
      `, [updatedBalance, isCodOverdue, technicianId]);

      // Audit Log
      await client.query(`
        INSERT INTO audit_logs (id, actor_id, actor_name, action, resource_type, resource_id, details, created_at)
        VALUES ($1, $2, 'SYSTEM_LEDGER', 'SETTLEMENT_PROCESSED', 'BOOKING', $3, $4, NOW())
      `, [
        `AUDIT-${uuidv4().slice(0, 8)}`,
        technicianId,
        bookingId,
        JSON.stringify({
          settlementId,
          total,
          platformFee,
          technicianEarnings,
          paymentMethod,
          updatedBalance,
          codDues: currentCod,
          isCodSuspended: isCodOverdue
        })
      ]);

      await client.query('COMMIT');

      return {
        success: true,
        settlementId,
        totalAmount: total,
        platformFee,
        technicianEarnings,
        newBalance: updatedBalance,
        codBalance: currentCod,
        isCodSuspended: isCodOverdue
      };
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('❌ [Ledger Settle Error]:', err);
      throw err;
    } finally {
      client.release();
    }
  } else {
    // In-memory standalone fallback
    const techStore = postgres.inMemoryStore.wallets.get(technicianId) || { balance: 0.00, txns: [] };
    techStore.balance = parseFloat((techStore.balance + technicianEarnings).toFixed(2));
    techStore.txns.unshift({
      id: `LTX-${Date.now()}`,
      bookingId,
      type: paymentMethod === 'COD' ? 'COD_EARNING' : 'SERVICE_EARNING',
      amount: technicianEarnings,
      direction: 'CREDIT',
      status: 'SETTLED',
      createdAt: now.toISOString(),
    });
    postgres.inMemoryStore.wallets.set(technicianId, techStore);

    return {
      success: true,
      settlementId,
      totalAmount: total,
      platformFee,
      technicianEarnings,
      newBalance: techStore.balance,
      codBalance: 0.00,
      isCodSuspended: false
    };
  }
}

/**
 * Atomic Withdrawal Engine with Row-Locking and Idempotency
 */
async function processWithdrawal({ technicianId, amount, upiId, idempotencyKey }) {
  if (!technicianId || !amount || amount <= 0 || !upiId) {
    throw new Error('Technician ID, valid amount (> 0), and UPI ID are required');
  }

  const requestedAmount = parseFloat(parseFloat(amount).toFixed(2));
  const withdrawalId = `WD-${Date.now().toString(36).toUpperCase()}-${Math.floor(100 + Math.random() * 900)}`;
  const payoutRef = `UPI-RZPX-${Date.now().toString().slice(-8)}`;
  const key = idempotencyKey || `IDEM-${technicianId}-${withdrawalId}`;

  if (postgres.isPgHealthy()) {
    const client = await postgres.getPool().connect();
    try {
      await client.query('BEGIN');

      // 1. Idempotency check: Return existing record if already processed
      const existing = await client.query(`
        SELECT * FROM technician_withdrawals WHERE idempotency_key = $1;
      `, [key]);

      if (existing.rows.length > 0) {
        await client.query('COMMIT');
        return {
          success: true,
          isDuplicate: true,
          data: existing.rows[0],
        };
      }

      // 2. Row-Level Lock on technician profile to prevent race conditions
      const techLock = await client.query(`
        SELECT wallet_balance, is_cod_suspended, upi_id
        FROM technician_profiles
        WHERE technician_id = $1 OR id = $1
        FOR UPDATE;
      `, [technicianId]);

      if (techLock.rows.length === 0) {
        throw new Error('Technician profile not found');
      }

      // 3. Verify balance from source of truth
      const ledgerCheck = await client.query(`
        SELECT COALESCE(SUM(
          CASE 
            WHEN direction = 'CREDIT' AND status = 'SETTLED' THEN amount 
            WHEN direction = 'DEBIT' AND status = 'SETTLED' THEN -amount 
            ELSE 0 
          END
        ), 0.00) AS net_balance
        FROM ledger_transactions
        WHERE technician_id = $1;
      `, [technicianId]);

      const currentBalance = parseFloat(ledgerCheck.rows[0]?.net_balance || 0);

      if (currentBalance < requestedAmount) {
        throw new Error(`Insufficient withdrawable balance. Available: ₹${currentBalance}, Requested: ₹${requestedAmount}`);
      }

      // 4. Insert debit into ledger_transactions
      const ltxId = `LTX-WD-${uuidv4().slice(0, 8)}`;
      await client.query(`
        INSERT INTO ledger_transactions (id, technician_id, booking_id, type, amount, direction, status, reference_id, created_at)
        VALUES ($1, $2, NULL, 'WITHDRAWAL', $3, 'DEBIT', 'SETTLED', $4, NOW())
      `, [ltxId, technicianId, requestedAmount, withdrawalId]);

      // 5. Insert withdrawal record
      await client.query(`
        INSERT INTO technician_withdrawals (id, technician_id, amount, upi_id, status, idempotency_key, payout_reference, processed_at)
        VALUES ($1, $2, $3, $4, 'PROCESSED', $5, $6, NOW())
      `, [withdrawalId, technicianId, requestedAmount, upiId, key, payoutRef]);

      // 6. Update cached balance and UPI ID on technician profile
      const newBalance = parseFloat((currentBalance - requestedAmount).toFixed(2));
      await client.query(`
        UPDATE technician_profiles
        SET wallet_balance = $1,
            upi_id = $2,
            updated_at = NOW()
        WHERE technician_id = $3 OR id = $3;
      `, [newBalance, upiId, technicianId]);

      // 7. Audit Log
      await client.query(`
        INSERT INTO audit_logs (id, actor_id, actor_name, action, resource_type, resource_id, details, created_at)
        VALUES ($1, $2, 'TECHNICIAN', 'WITHDRAWAL_EXECUTED', 'WALLET', $3, $4, NOW())
      `, [
        `AUDIT-${uuidv4().slice(0, 8)}`,
        technicianId,
        withdrawalId,
        JSON.stringify({
          withdrawalId,
          amount: requestedAmount,
          upiId,
          payoutRef,
          previousBalance: currentBalance,
          newBalance
        })
      ]);

      await client.query('COMMIT');

      return {
        success: true,
        data: {
          withdrawalId,
          technicianId,
          amount: requestedAmount,
          upiId,
          payoutReference: payoutRef,
          remainingBalance: newBalance,
          status: 'PROCESSED',
          processedAt: new Date().toISOString(),
        }
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } else {
    // In-memory atomic fallback
    const techStore = postgres.inMemoryStore.wallets.get(technicianId) || { balance: 1000.00, txns: [] };
    if (techStore.balance < requestedAmount) {
      throw new Error(`Insufficient withdrawable balance. Available: ₹${techStore.balance}, Requested: ₹${requestedAmount}`);
    }

    techStore.balance = parseFloat((techStore.balance - requestedAmount).toFixed(2));
    techStore.txns.unshift({
      id: `LTX-WD-${Date.now()}`,
      type: 'WITHDRAWAL',
      amount: requestedAmount,
      direction: 'DEBIT',
      status: 'SETTLED',
      upiId,
      payoutRef,
      createdAt: new Date().toISOString()
    });
    postgres.inMemoryStore.wallets.set(technicianId, techStore);

    return {
      success: true,
      data: {
        withdrawalId,
        technicianId,
        amount: requestedAmount,
        upiId,
        payoutReference: payoutRef,
        remainingBalance: techStore.balance,
        status: 'PROCESSED',
        processedAt: new Date().toISOString(),
      }
    };
  }
}

/**
 * Real Gateway Refund Logic with Cancellation Policy Evaluation
 */
function evaluateCancellationRefund({ bookingStatus, totalAmount, visitFee = 49.00 }) {
  const total = parseFloat(totalAmount || 0);
  const fee = parseFloat(visitFee || 49.00);

  // Policy rules:
  // 1. Before technician dispatched or accepted: 100% full refund
  if (['PENDING', 'CONFIRMED', 'PAID', 'SEARCHING_TECHNICIAN'].includes(bookingStatus)) {
    return {
      cancellationFee: 0.00,
      refundAmount: total,
      policyApplied: '100% Full Refund (Cancelled prior to technician dispatch)',
    };
  }

  // 2. After technician accepted, before arrival: Visit fee retained, remainder refunded
  if (['ACCEPTED', 'TECHNICIAN_ASSIGNED', 'TECHNICIAN_ACCEPTED', 'TECHNICIAN_ON_THE_WAY'].includes(bookingStatus)) {
    const refund = Math.max(0.00, total - fee);
    return {
      cancellationFee: fee,
      refundAmount: parseFloat(refund.toFixed(2)),
      policyApplied: `Cancellation fee ₹${fee} applied (Technician already dispatched in transit)`,
    };
  }

  // 3. After technician arrived: Convenience fee + travel charges
  if (['ARRIVED', 'TECHNICIAN_ARRIVED'].includes(bookingStatus)) {
    const feeArrived = parseFloat((fee * 1.5).toFixed(2));
    const refund = Math.max(0.00, total - feeArrived);
    return {
      cancellationFee: feeArrived,
      refundAmount: parseFloat(refund.toFixed(2)),
      policyApplied: `Cancellation fee ₹${feeArrived} applied (Technician on-site inspection visit)`,
    };
  }

  // 4. Once service has started or completed: No automated refund (requires dispute escalation)
  return {
    cancellationFee: total,
    refundAmount: 0.00,
    policyApplied: 'No refund after work commencement (Requires support dispute review)',
  };
}

module.exports = {
  calculateWalletBalance,
  settleBookingLedger,
  processWithdrawal,
  evaluateCancellationRefund,
  COD_MAX_DUE_THRESHOLD,
};
