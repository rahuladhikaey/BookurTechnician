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

    if (serviceAccount) {
      if (admin.apps.length === 0) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || 'bookmytechnician-53d94',
        });
      }
      isFirebaseInitialized = true;
      console.log(`✅ [Firebase FCM] Initialized with Service Account Credentials (${serviceAccount.project_id})`);
      return;
    }
  } catch (err) {
    console.warn('⚠️ [Firebase FCM] Failed to load credentials, falling back to simulator:', err.message);
  }
  console.log('ℹ️ [Firebase FCM] Running in Simulated Push Mode ($0 MVP Mode - Live alerts log to console & WebSockets)');
};

/**
 * Send push notification to a device FCM token
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

module.exports = { initFirebase, sendPushNotification };
