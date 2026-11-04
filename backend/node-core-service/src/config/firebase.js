const admin = require('firebase-admin');
const fs = require('fs');

const path = require('path');
let isFirebaseInitialized = false;

const initFirebase = () => {
  try {
    let serviceAccount = null;

    // Option 1: Direct JSON string in environment variable (Ideal for Render / Cloud)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    } 
    // Option 2: File path on disk
    else {
      let serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './firebase-service-account.json';
      if (serviceAccountPath && !path.isAbsolute(serviceAccountPath)) {
        serviceAccountPath = path.resolve(__dirname, '../../', serviceAccountPath);
      }
      if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
        serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
      }
    }

    const projectId = process.env.FIREBASE_PROJECT_ID || (serviceAccount && serviceAccount.project_id) || 'bookmytechnician-53d94';
    const storageBucket = process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`;

    if (serviceAccount) {
      if (admin.apps.length === 0) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId,
          storageBucket,
        });
      }
      isFirebaseInitialized = true;
      console.log(`✅ [Firebase] Initialized with Service Account Credentials (${projectId})`);
      return;
    }

    // Option 3: Application Default Credentials / Project ID initialization
    if (admin.apps.length === 0) {
      admin.initializeApp({
        projectId,
        storageBucket,
      });
    }
    isFirebaseInitialized = true;
    console.log(`✅ [Firebase] Initialized with Project ID (${projectId})`);
    return;
  } catch (err) {
    console.warn('⚠️ [Firebase FCM] Failed to load credentials, falling back to simulator:', err.message);
  }
  console.log('ℹ️ [Firebase FCM] Running in Simulated Push Mode ($0 MVP Mode - Live alerts log to console & WebSockets)');
};

/**
 * Get Cloud Firestore Database Instance
 */
const getFirestoreDb = () => {
  if (isFirebaseInitialized || admin.apps.length > 0) {
    try {
      return admin.firestore();
    } catch (e) {
      return null;
    }
  }
  return null;
};

/**
 * Verify Firebase ID Token for Production Authentication
 * @param {string} idToken - Client JWT from Firebase Auth
 */
const verifyFirebaseIdToken = async (idToken) => {
  if (!idToken) return null;
  if (isFirebaseInitialized) {
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      return decoded;
    } catch (err) {
      console.warn('⚠️ [Firebase Auth] Token verification failed:', err.message);
      return null;
    }
  } else {
    return null;
  }
};

/**
 * Send standard push notification to a device FCM token
 * @param {string} fcmToken - Target device registration token
 * @param {object} payload - { title, body, data }
 */
const sendPushNotification = async (fcmToken, { title, body, data = {} }) => {
  if (!fcmToken) return { success: false, reason: 'No FCM token provided' };

  if (isFirebaseInitialized) {
    try {
      const message = {
        token: fcmToken,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'bookurtechnician_general',
          },
        },
      };
      const response = await admin.messaging().send(message);
      return { success: true, messageId: response };
    } catch (error) {
      console.warn(`⚠️ [Firebase FCM] Failed to send push to ${fcmToken}:`, error.message);
      return { success: false, error: error.message };
    }
  } else {
    // Simulator Mode
    console.log(`📱 [Simulated FCM Push] -> Target: ${fcmToken.substring(0, 15)}... | Title: "${title}" | Body: "${body}"`);
    return { success: true, simulated: true };
  }
};

/**
 * High-Priority Siren Dispatch Alert for Technicians
 * Android 12+ compliant with custom siren channel and full-screen intent data
 */
const sendHighPriorityTechnicianAlert = async (fcmToken, { title, body, data = {} }) => {
  if (!fcmToken) return { success: false, reason: 'No FCM token provided' };

  if (isFirebaseInitialized) {
    try {
      const message = {
        token: fcmToken,
        notification: { title, body },
        data: {
          ...Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ),
          isUrgentDispatch: 'true',
          alarmLoop: 'true',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          ttl: 45 * 1000, // 45 seconds TTL
          notification: {
            channelId: 'technician_emergency_channel',
            sound: 'siren_alarm',
            priority: 'max',
            visibility: 'public',
          },
        },
      };
      const response = await admin.messaging().send(message);
      console.log(`🚨 [Firebase FCM] Sent High-Priority Technician Siren Alert to ${fcmToken.substring(0, 15)}...`);
      return { success: true, messageId: response };
    } catch (error) {
      console.warn(`⚠️ [Firebase FCM Alert Warning]:`, error.message);
      return { success: false, error: error.message };
    }
  } else {
    console.log(`🚨 [Simulated Technician Siren Alert] -> ${fcmToken.substring(0, 15)}... | "${title}" - "${body}"`);
    return { success: true, simulated: true };
  }
};

/**
 * Send push to multiple device tokens (multi-device support)
 */
const sendMulticastPushNotification = async (fcmTokens, { title, body, data = {} }) => {
  if (!Array.isArray(fcmTokens) || fcmTokens.length === 0) return { success: false };

  const validTokens = fcmTokens.filter(t => typeof t === 'string' && t.trim().length > 10);
  if (validTokens.length === 0) return { success: false };

  if (isFirebaseInitialized) {
    try {
      const message = {
        tokens: validTokens,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
      };
      const response = await admin.messaging().sendEachForMulticast(message);
      return { success: true, successCount: response.successCount, failureCount: response.failureCount };
    } catch (err) {
      console.warn('⚠️ [Firebase FCM Multicast Error]:', err.message);
      return { success: false, error: err.message };
    }
  } else {
    console.log(`📱 [Simulated Multicast Push] -> ${validTokens.length} devices | "${title}"`);
    return { success: true, simulated: true };
  }
};

/**
 * Get Firebase Storage Bucket
 */
const getStorageBucket = () => {
  if (isFirebaseInitialized) {
    return admin.storage().bucket();
  }
  return null;
};

module.exports = {
  initFirebase,
  verifyFirebaseIdToken,
  sendPushNotification,
  sendHighPriorityTechnicianAlert,
  sendMulticastPushNotification,
  getStorageBucket,
  getFirestoreDb,
  admin,
};
