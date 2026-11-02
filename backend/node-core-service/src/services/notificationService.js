'use strict';

/**
 * Notification Service
 * Orchestrates real Firebase Cloud Messaging and Socket.io delivery.
 * Automatically resolves and cleans invalid tokens, strictly banning synthetic tokens.
 */

const firebase = require('../config/firebase');
const postgres = require('../config/postgres');

/**
 * Send real push notification to a user by User ID
 * @param {string} userId - User or Technician ID
 * @param {object} payload - { title, body, data, isUrgentAlert }
 */
async function sendToUser(userId, { title, body, data = {}, isUrgentAlert = false }) {
  if (!userId) return { success: false, reason: 'Missing userId' };

  let fcmToken = null;
  let deviceTokens = [];

  if (postgres.isPgHealthy()) {
    try {
      const res = await postgres.query('SELECT fcm_token, device_tokens FROM users WHERE id = $1', [userId]);
      if (res.rows.length > 0) {
        fcmToken = res.rows[0].fcm_token;
        deviceTokens = Array.isArray(res.rows[0].device_tokens) ? res.rows[0].device_tokens : [];
      }
    } catch (err) {
      console.warn(`[NotificationService] Error querying tokens for ${userId}:`, err.message);
    }
  }

  // Collect unique valid tokens, strictly filtering out synthetic placeholders
  const candidateTokens = new Set();
  if (fcmToken) candidateTokens.add(fcmToken);
  for (const t of deviceTokens) {
    if (t) candidateTokens.add(t);
  }

  const validTokens = [...candidateTokens].filter(t => 
    typeof t === 'string' &&
    t.length > 20 &&
    !t.startsWith('cust_fcm_') &&
    !t.startsWith('tech_fcm_') &&
    !t.startsWith('fcm_')
  );

  if (validTokens.length === 0) {
    return {
      success: false,
      reason: 'No registered device tokens found for user (User must register FCM token)',
      userId,
    };
  }

  const results = [];
  for (const token of validTokens) {
    try {
      let sendResult;
      if (isUrgentAlert) {
        sendResult = await firebase.sendHighPriorityTechnicianAlert(token, { title, body, data });
      } else {
        sendResult = await firebase.sendPushNotification(token, { title, body, data });
      }

      results.push(sendResult);

      // Handle invalid / unregistered / expired tokens: Auto-cleanup from DB
      if (!sendResult.success && sendResult.error) {
        const errLower = sendResult.error.toLowerCase();
        if (
          errLower.includes('not-registered') ||
          errLower.includes('registration-token-not-registered') ||
          errLower.includes('invalid-argument') ||
          errLower.includes('invalid registration token')
        ) {
          console.warn(`🧹 [NotificationService] Pruning expired/invalid FCM token for user ${userId}`);
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

  return {
    success: results.some(r => r.success),
    dispatchedCount: results.length,
    results,
  };
}

module.exports = {
  sendToUser,
};
