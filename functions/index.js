const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { createApp } = require('./src/app');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const app = createApp(db);

/**
 * 2nd Generation Cloud Functions HTTP API
 * Region: asia-south1
 */
exports.api = onRequest(
  {
    region: 'asia-south1',
    cors: true,
    timeoutSeconds: 60,
    memory: '256MiB',
    minInstances: 0,
  },
  app
);

