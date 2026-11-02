'use strict';

/**
 * Payout Service (RazorpayX Integration & Webhook Reconciliation)
 * Authoritative provider-backed technician payouts.
 * Never fakes instant success or synthetic UTRs.
 */

const crypto = require('crypto');
const axios = require('axios');
const postgres = require('../config/postgres');
const { v4: uuidv4 } = require('uuid');

const RAZORPAYX_KEY_ID = process.env.RAZORPAYX_KEY_ID;
const RAZORPAYX_KEY_SECRET = process.env.RAZORPAYX_KEY_SECRET;
const RAZORPAYX_ACCOUNT_NUMBER = process.env.RAZORPAYX_ACCOUNT_NUMBER;
const RAZORPAYX_WEBHOOK_SECRET = process.env.RAZORPAYX_WEBHOOK_SECRET;

const isConfigured = () => {
  return Boolean(RAZORPAYX_KEY_ID && RAZORPAYX_KEY_SECRET && RAZORPAYX_ACCOUNT_NUMBER);
};

/**
 * Request real technician payout via RazorpayX
 */
async function initiatePayout({ withdrawalId, technicianId, amount, upiId }) {
  if (!isConfigured()) {
    // Fail safe: Do not fake success with synthetic UTRs
    return {
      status: 'PENDING_ADMIN_APPROVAL',
      providerReference: null,
      utr: null,
      message: 'RazorpayX credentials unconfigured. Queued for manual admin processing.',
    };
  }

  const authHeader = 'Basic ' + Buffer.from(`${RAZORPAYX_KEY_ID}:${RAZORPAYX_KEY_SECRET}`).toString('base64');
  const amountPaise = Math.round(parseFloat(amount) * 100);

  try {
    const payload = {
      account_number: RAZORPAYX_ACCOUNT_NUMBER,
      fund_account: {
        account_type: 'vpa',
        vpa: {
          address: upiId,
        },
        contact: {
          name: `Technician ${technicianId}`,
          type: 'vendor',
          reference_id: technicianId,
        },
      },
      amount: amountPaise,
      currency: 'INR',
      mode: 'UPI',
      purpose: 'payout',
      queue_if_low_balance: true,
      reference_id: withdrawalId,
      narration: `BookUrTech Payout ${withdrawalId.slice(-6)}`,
    };

    const response = await axios.post('https://api.razorpay.com/v1/payouts', payload, {
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    });

    const data = response.data;
    const providerStatus = (data.status || 'processing').toUpperCase();
    
    // Status mapping: queued, pending, processing -> PROCESSING; processed -> PAID; reversed, rejected, failed -> FAILED
    let normalizedStatus = 'PROCESSING';
    if (providerStatus === 'PROCESSED') normalizedStatus = 'PAID';
    if (['REVERSED', 'REJECTED', 'FAILED'].includes(providerStatus)) normalizedStatus = 'FAILED';

    return {
      status: normalizedStatus,
      providerReference: data.id,
      utr: data.utr || null,
      message: `RazorpayX payout initiated: ${data.id}`,
    };
  } catch (err) {
    const errorMsg = err.response?.data?.error?.description || err.message;
    console.error('❌ RazorpayX Payout Error:', errorMsg);
    throw new Error(`Payout provider error: ${errorMsg}`);
  }
}

/**
 * Handle RazorpayX Webhook for Payout Status Transitions
 */
async function handlePayoutWebhook(rawBody, signature) {
  if (!RAZORPAYX_WEBHOOK_SECRET) {
    throw new Error('RAZORPAYX_WEBHOOK_SECRET not configured');
  }

  const expectedSignature = crypto
    .createHmac('sha256', RAZORPAYX_WEBHOOK_SECRET)
    .update(rawBody)
    .digest('hex');

  const sigBuf = Buffer.from(signature || '', 'utf8');
  const expBuf = Buffer.from(expectedSignature, 'utf8');

  if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
    throw new Error('Invalid RazorpayX webhook signature');
  }

  const event = JSON.parse(rawBody.toString('utf8'));
  const eventType = event.event;
  const payout = event.payload?.payout?.entity;

  if (!payout || !payout.reference_id) {
    return { success: true, ignored: true, reason: 'No payout reference in webhook' };
  }

  const withdrawalId = payout.reference_id;
  const providerPayoutId = payout.id;
  const utr = payout.utr || null;

  if (!postgres.isPgHealthy()) {
    return { success: true, offline: true };
  }

  const client = await postgres.getPool().connect();
  try {
    await client.query('BEGIN');

    const wRes = await client.query('SELECT * FROM technician_withdrawals WHERE id = $1 FOR UPDATE', [withdrawalId]);
    if (wRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return { success: false, error: 'Withdrawal record not found' };
    }

    const withdrawal = wRes.rows[0];

    if (eventType === 'payout.processed') {
      await client.query(`
        UPDATE technician_withdrawals
        SET status = 'PAID',
            payout_reference = COALESCE($1, payout_reference),
            processed_at = NOW(),
            updated_at = NOW()
        WHERE id = $2
      `, [utr || providerPayoutId, withdrawalId]);

      await client.query(`
        UPDATE ledger_transactions
        SET status = 'SETTLED'
        WHERE reference_id = $1 AND type = 'WITHDRAWAL'
      `, [withdrawalId]);
    } else if (eventType === 'payout.reversed' || eventType === 'payout.failed' || eventType === 'payout.rejected') {
      await client.query(`
        UPDATE technician_withdrawals
        SET status = 'FAILED',
            failure_reason = $1,
            updated_at = NOW()
        WHERE id = $2
      `, [payout.failure_reason || eventType, withdrawalId]);

      // Reverse debit in ledger: restore funds to technician
      const reversalId = `LTX-REV-${uuidv4().slice(0, 8)}`;
      await client.query(`
        INSERT INTO ledger_transactions (id, technician_id, booking_id, type, amount, direction, status, reference_id, created_at)
        VALUES ($1, $2, NULL, 'PAYOUT_REVERSAL', $3, 'CREDIT', 'SETTLED', $4, NOW())
      `, [reversalId, withdrawal.technician_id, withdrawal.amount, withdrawalId]);

      await client.query(`
        UPDATE technician_profiles
        SET wallet_balance = wallet_balance + $1,
            updated_at = NOW()
        WHERE technician_id = $2 OR id = $2
      `, [withdrawal.amount, withdrawal.technician_id]);
    }

    await client.query('COMMIT');
    return { success: true, event: eventType, withdrawalId };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  isConfigured,
  initiatePayout,
  handlePayoutWebhook,
};
