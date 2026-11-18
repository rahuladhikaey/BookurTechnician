const { initFirebaseAdmin, getFirestoreDb, verifyFirestoreConnection, getFirebaseStatus } = require('./src/firebaseAdmin');
const { getEmailJsStatus } = require('./src/emailService');
const { createApp } = require('./src/app');

async function startServer() {
  const fbStatus = initFirebaseAdmin();
  const db = getFirestoreDb();

  if (db) {
    const conn = await verifyFirestoreConnection(db);
    if (conn.connected) {
      console.log(`[Firebase] Connected to Cloud Firestore (project: ${fbStatus.projectId}, mode: ${fbStatus.credentialMode})`);
    } else {
      console.warn(`[Firebase] Initialized in mode ${fbStatus.credentialMode}, but Firestore check failed: ${conn.error}`);
    }
  } else {
    console.warn(`[Firebase] Running without Firestore connection (${fbStatus.lastError || 'unconfigured'})`);
  }

  const emailStatus = getEmailJsStatus();
  if (emailStatus.configured) {
    console.log('[EmailJS] Configured cleanly from environment variables');
  } else {
    console.warn('[EmailJS] Credentials missing in environment variables; /auth/request-otp will return 503 until configured');
  }

  const app = createApp(db, {
    getFirebaseStatus,
    verifyFirestoreConnection,
  });

  const port = Number(process.env.PORT) || 3000;
  const host = '0.0.0.0';

  const server = app.listen(port, host, () => {
    console.log(`[BookurTechnician] Trusted backend listening on http://${host}:${port}`);
  });

  const shutdown = (signal) => {
    console.log(`[BookurTechnician] Received ${signal}, shutting down HTTP server gracefully...`);
    server.close(() => {
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  return { app, server };
}

if (require.main === module) {
  startServer().catch((err) => {
    console.error('[BookurTechnician] Fatal server startup error:', err.message);
    process.exit(1);
  });
}

module.exports = {
  startServer,
};
