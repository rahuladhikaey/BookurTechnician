'use strict';

/**
 * Notification Service
 * Orchestrates real Firebase Cloud Messaging and Socket.io delivery.
 * Automatically resolves and cleans invalid tokens, strictly banning synthetic tokens.
 */

const firebase = require('../config/firebase');
const postgres = require('../config/postgres');
const { inMemoryTechProfiles } = require('../config/inMemoryTechStore');

const deviceTokens = new Map(); // userId -> Array<string>
const sentOfferNotificationsDedup = new Set(); // `${userId}:${offerId}`

function isValidDeviceToken(t) {
  return (
    typeof t === 'string' &&
    t.trim().length > 20 &&
    !t.startsWith('cust_fcm_') &&
    !t.startsWith('tech_fcm_') &&
    !t.startsWith('fcm_') &&
    !t.startsWith('fake_') &&
    !t.startsWith('mock_') &&
    !t.startsWith('dummy_') &&
    !t.startsWith('synthetic_')
  );
}

function registerToken(userId, token) {
  if (!userId || !isValidDeviceToken(token)) return false;
  const trimmed = token.trim();
  const list = deviceTokens.get(userId) || [];
  if (!list.includes(trimmed)) {
    list.push(trimmed);
    deviceTokens.set(userId, list);
  }
  return true;
}

/**
 * Send real push notification to a user by User ID
 * Supports both:
 *   sendToUser(userId, { title, body, data, isUrgentAlert })
 *   sendToUser(userId, title, body, data)
 */
async function sendToUser(userId, titleOrPayload, bodyArg, dataArg = {}) {
  if (!userId) return { success: false, sent: false, reason: 'Missing userId' };

  let title = '';
  let body = '';
  let data = {};
  let isUrgentAlert = false;

  if (typeof titleOrPayload === 'object' && titleOrPayload !== null) {
    title = titleOrPayload.title || 'BookurTechnician Notification';
    body = titleOrPayload.body || '';
    data = titleOrPayload.data || {};
    isUrgentAlert = Boolean(titleOrPayload.isUrgentAlert);
  } else {
    title = String(titleOrPayload || 'BookurTechnician Notification');
    body = String(bodyArg || '');
    data = dataArg || {};
    isUrgentAlert = data.type === 'DISPATCH_OFFER_NEW';
  }

  // Deduplicate identical offer notifications for the same technician & offerId (Phase 5 & Phase 17 Test 24)
  const dedupOfferId = data?.offerId || data?.proposalId || data?.dedupKey;
  if (dedupOfferId) {
    const dedupKey = `${userId}:${dedupOfferId}`;
    if (sentOfferNotificationsDedup.has(dedupKey)) {
      return {
        success: true,
        sent: false,
        deduplicated: true,
        reason: 'DUPLICATE_OFFER_NOTIFICATION_SUPPRESSED',
        userId,
        offerId: dedupOfferId,
      };
    }
    sentOfferNotificationsDedup.add(dedupKey);
    if (sentOfferNotificationsDedup.size > 5000) {
      const [oldest] = sentOfferNotificationsDedup;
      sentOfferNotificationsDedup.delete(oldest);
    }
  }

  let fcmToken = null;
  let pgTokens = [];

  if (postgres.isPgHealthy()) {
    try {
      const res = await postgres.query('SELECT fcm_token, device_tokens FROM users WHERE id = $1', [userId]);
      if (res.rows.length > 0) {
        fcmToken = res.rows[0].fcm_token;
        pgTokens = Array.isArray(res.rows[0].device_tokens) ? res.rows[0].device_tokens : [];
      }
    } catch (err) {
      console.warn(`[NotificationService] Error querying tokens for ${userId}:`, err.message);
    }
  }

  const candidateTokens = new Set();
  if (fcmToken) candidateTokens.add(fcmToken);
  for (const t of pgTokens) {
    if (t) candidateTokens.add(t);
  }
  const memTokens = deviceTokens.get(userId) || [];
  for (const t of memTokens) {
    if (t) candidateTokens.add(t);
  }
  const techProf = inMemoryTechProfiles.get(userId);
  if (techProf) {
    if (techProf.fcmToken) candidateTokens.add(techProf.fcmToken);
    if (Array.isArray(techProf.deviceTokens)) {
      techProf.deviceTokens.forEach(t => candidateTokens.add(t));
    }
  }

  const validTokens = [...candidateTokens].filter(isValidDeviceToken);

  if (validTokens.length === 0) {
    return {
      success: false,
      sent: false,
      reason: 'No registered device tokens found for user (User must register FCM token)',
      userId,
    };
  }

  const results = [];
  for (const token of validTokens) {
    try {
      let sendResult;
      if (isUrgentAlert && typeof firebase.sendHighPriorityTechnicianAlert === 'function') {
        sendResult = await firebase.sendHighPriorityTechnicianAlert(token, { title, body, data });
      } else if (typeof firebase.sendPushNotification === 'function') {
        sendResult = await firebase.sendPushNotification(token, { title, body, data });
      } else {
        sendResult = { success: false, error: 'Firebase messaging helper not available' };
      }

      results.push(sendResult);

      // Handle invalid / unregistered / expired tokens: Auto-cleanup from DB & memory
      if (!sendResult.success && sendResult.error) {
        const errLower = String(sendResult.error).toLowerCase();
        if (
          errLower.includes('not-registered') ||
          errLower.includes('registration-token-not-registered') ||
          errLower.includes('invalid-argument') ||
          errLower.includes('invalid registration token')
        ) {
          console.warn(`🧹 [NotificationService] Pruning expired/invalid FCM token for user ${userId}`);
          const currentMem = deviceTokens.get(userId) || [];
          deviceTokens.set(userId, currentMem.filter(x => x !== token));
          if (postgres.isPgHealthy()) {
            await postgres.query(`
              UPDATE users
              SET fcm_token = CASE WHEN fcm_token = $1 THEN NULL ELSE fcm_token END,
                  device_tokens = array_remove(COALESCE(device_tokens, ARRAY[]::TEXT[]), $1),
                  updated_at = NOW()
              WHERE id = $2;
            `, [token, userId]).catch(() => {});
          }
        }
      }
    } catch (pushErr) {
      console.warn(`[NotificationService] Push delivery error:`, pushErr.message);
      results.push({ success: false, error: pushErr.message });
    }
  }

  const anySuccess = results.some(r => r && r.success);
  return {
    success: anySuccess,
    sent: anySuccess,
    messageId: results.find(r => r && r.messageId)?.messageId || null,
    dispatchedCount: results.length,
    results,
  };
}

async function notifyCustomerTechnicianAssigned(customerId, bookingId, technicianName, etaText = '15 mins') {
  return sendToUser(customerId, {
    title: '✅ Technician Assigned!',
    body: `${technicianName} has been assigned to your booking (${bookingId}) and will arrive in ~${etaText}.`,
    data: {
      type: 'TECHNICIAN_ASSIGNED',
      bookingId: String(bookingId),
      technicianName: String(technicianName),
      eta: String(etaText),
    },
  });
}

async function notifyCustomerTechnicianArrived(customerId, bookingId, technicianName) {
  return sendToUser(customerId, {
    title: '📍 Technician Arrived',
    body: `${technicianName} has arrived at your location. Share the Start OTP to begin service.`,
    data: {
      type: 'TECHNICIAN_ARRIVED',
      bookingId: String(bookingId),
    },
  });
}

async function notifyCustomerServiceCompleted(customerId, bookingId, amount) {
  return sendToUser(customerId, {
    title: '🎉 Service Completed',
    body: `Your booking ${bookingId} is complete (Total: ₹${amount}). Thank you for choosing BookurTechnician!`,
    data: {
      type: 'SERVICE_COMPLETED',
      bookingId: String(bookingId),
      amount: String(amount || ''),
    },
  });
}

module.exports = {
  deviceTokens,
  registerToken,
  sendToUser,
  notifyCustomerTechnicianAssigned,
  notifyCustomerTechnicianArrived,
  notifyCustomerServiceCompleted,
};
