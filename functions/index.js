const { onRequest } = require('firebase-functions/v2/https');
const { initFirebaseAdmin, getFirestoreDb, getFirebaseStatus, verifyFirestoreConnection } = require('./src/firebaseAdmin');
const { createApp } = require('./src/app');

initFirebaseAdmin();
const db = getFirestoreDb();
const app = createApp(db, {
  getFirebaseStatus,
  verifyFirestoreConnection,
});

/**
 * 2nd Generation Cloud Functions HTTP API (kept compatible alongside standalone Render server.js)
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

