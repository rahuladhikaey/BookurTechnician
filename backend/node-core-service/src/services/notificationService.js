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

async function notifyCustomerBookingSubmitted(customerId, bookingId, serviceName) {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:submitted', { bookingId, serviceName, timestamp: Date.now() });
  }
  return sendToUser(customerId, {
    title: '📋 Booking Request Submitted',
    body: `Your request for ${serviceName || 'service'} (${bookingId}) is submitted. Searching for the nearest top technician...`,
    data: {
      type: 'BOOKING_SUBMITTED',
      bookingId: String(bookingId),
      serviceName: String(serviceName || ''),
    },
  });
}

async function notifyCustomerTechnicianAssigned(customerId, bookingId, technicianName, etaText = '15 mins') {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:technician:assigned', { bookingId, technicianName, etaText, timestamp: Date.now() });
    global.io.to(`booking_${bookingId}`).emit('booking:technician:assigned', { bookingId, technicianName, etaText, timestamp: Date.now() });
  }
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

async function notifyCustomerTechnicianAccepted(customerId, bookingId, technicianName) {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:technician:accepted', { bookingId, technicianName, timestamp: Date.now() });
  }
  return sendToUser(customerId, {
    title: '👍 Technician Confirmed',
    body: `${technicianName} has confirmed your booking and is preparing for transit.`,
    data: {
      type: 'TECHNICIAN_ACCEPTED',
      bookingId: String(bookingId),
      technicianName: String(technicianName),
    },
  });
}

async function notifyCustomerTechnicianEnRoute(customerId, bookingId, technicianName, etaMinutes = 15) {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:technician:en_route', { bookingId, technicianName, etaMinutes, timestamp: Date.now() });
  }
  return sendToUser(customerId, {
    title: '🚗 Technician En Route',
    body: `${technicianName} is heading towards your location (ETA ~${etaMinutes} min). Track live in your app.`,
    data: {
      type: 'TECHNICIAN_EN_ROUTE',
      bookingId: String(bookingId),
      eta: String(etaMinutes),
    },
  });
}

async function notifyCustomerTechnicianArrived(customerId, bookingId, technicianName) {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:technician:arrived', { bookingId, technicianName, timestamp: Date.now() });
  }
  return sendToUser(customerId, {
    title: '📍 Technician Arrived',
    body: `${technicianName} has arrived at your location. Share the Start OTP to begin service.`,
    data: {
      type: 'TECHNICIAN_ARRIVED',
      bookingId: String(bookingId),
    },
  });
}

async function notifyCustomerServiceStarted(customerId, bookingId) {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:started', { bookingId, timestamp: Date.now() });
  }
  return sendToUser(customerId, {
    title: '⚡ Service Started',
    body: `Service has officially begun for booking ${bookingId}. Track real-time progress in app.`,
    data: {
      type: 'SERVICE_STARTED',
      bookingId: String(bookingId),
    },
  });
}

async function notifyCustomerServiceCompleted(customerId, bookingId, amount) {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:completed', { bookingId, amount, timestamp: Date.now() });
  }
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

async function notifyCustomerBookingCancelledOrExpired(customerId, bookingId, reason = 'No technician available') {
  if (global.io) {
    global.io.to(`cust_${customerId}`).emit('booking:cancelled', { bookingId, reason, timestamp: Date.now() });
  }
  return sendToUser(customerId, {
    title: '⚠️ Booking Notice',
    body: `Booking ${bookingId} status update: ${reason}. Tap to view details or retry search.`,
    data: {
      type: 'BOOKING_CANCELLED',
      bookingId: String(bookingId),
      reason: String(reason),
    },
  });
}

// ─── TECHNICIAN LIFECYCLE NOTIFICATIONS ──────────────────────────────────────

async function notifyTechnicianNewRequest(technicianId, offer = {}) {
  const offerId = offer.id || offer.offerId;
  const bookingId = offer.bookingId;
  const serviceName = offer.serviceName || 'Electrical Service';
  const payout = offer.technicianPayoutAmount || offer.payout || 399;

  if (global.io) {
    global.io.to(`tech_${technicianId}`).emit('dispatch:offer:new', offer);
  }

  return sendToUser(technicianId, {
    title: '🚨 New Booking Request!',
    body: `${serviceName} • Earn ₹${payout}. Tap immediately to view and accept.`,
    isUrgentAlert: true,
    data: {
      type: 'DISPATCH_OFFER_NEW',
      offerId: String(offerId || ''),
      bookingId: String(bookingId || ''),
      payout: String(payout),
      serviceName: String(serviceName),
    },
  });
}

async function notifyTechnicianAcceptedElsewhere(technicianId, bookingId) {
  if (global.io) {
    global.io.to(`tech_${technicianId}`).emit('dispatch:offer:cancelled', { bookingId, reason: 'CLAIMED_BY_ANOTHER_TECHNICIAN' });
    global.io.to(`tech_${technicianId}`).emit('booking:claimed', { bookingId });
  }
  return sendToUser(technicianId, {
    title: 'ℹ️ Booking Accepted Elsewhere',
    body: `Booking ${bookingId} was accepted by another partner. Staying alert for next job!`,
    data: {
      type: 'OFFER_CLAIMED_ELSEWHERE',
      bookingId: String(bookingId),
    },
  });
}

async function notifyTechnicianOfferExpired(technicianId, bookingId, offerId) {
  if (global.io) {
    global.io.to(`tech_${technicianId}`).emit('dispatch:offer:expired', { bookingId, offerId });
  }
  return sendToUser(technicianId, {
    title: '⏳ Request Expired',
    body: `Booking offer ${bookingId} timed out and has been routed to the next available technician.`,
    data: {
      type: 'DISPATCH_OFFER_EXPIRED',
      bookingId: String(bookingId),
      offerId: String(offerId || ''),
    },
  });
}

async function notifyTechnicianBookingCancelled(technicianId, bookingId, reason = 'Customer cancelled') {
  if (global.io) {
    global.io.to(`tech_${technicianId}`).emit('booking:cancelled', { bookingId, reason });
  }
  return sendToUser(technicianId, {
    title: '🚫 Booking Cancelled',
    body: `Booking ${bookingId} has been cancelled (${reason}).`,
    data: {
      type: 'BOOKING_CANCELLED',
      bookingId: String(bookingId),
      reason: String(reason),
    },
  });
}

async function notifyTechnicianBookingUpdate(technicianId, bookingId, updates = {}) {
  if (global.io) {
    global.io.to(`tech_${technicianId}`).emit('booking:updated', { bookingId, updates });
  }
  return sendToUser(technicianId, {
    title: '📝 Booking Updated',
    body: `Booking ${bookingId} details have been updated by customer/support.`,
    data: {
      type: 'BOOKING_UPDATED',
      bookingId: String(bookingId),
    },
  });
}

module.exports = {
  deviceTokens,
  registerToken,
  sendToUser,
  // Customer lifecycle
  notifyCustomerBookingSubmitted,
  notifyCustomerTechnicianAssigned,
  notifyCustomerTechnicianAccepted,
  notifyCustomerTechnicianEnRoute,
  notifyCustomerTechnicianArrived,
  notifyCustomerServiceStarted,
  notifyCustomerServiceCompleted,
  notifyCustomerBookingCancelledOrExpired,
  // Technician lifecycle
  notifyTechnicianNewRequest,
  notifyTechnicianAcceptedElsewhere,
  notifyTechnicianOfferExpired,
  notifyTechnicianBookingCancelled,
  notifyTechnicianBookingUpdate,
};
