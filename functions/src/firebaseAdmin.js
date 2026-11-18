const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const DEFAULT_PROJECT_ID = 'bookmytechnician-53d94';

const runtimeState = {
  initialized: false,
  configured: false,
  hasServiceAccount: false,
  firestoreReady: false,
  credentialMode: 'UNCONFIGURED',
  projectId: DEFAULT_PROJECT_ID,
  lastCheckedAt: null,
  lastError: null,
};

function normalizePrivateKey(key) {
  if (typeof key !== 'string') return '';
  return key.replace(/\\n/g, '\n');
}

function parseServiceAccountFromEnv() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    if (parsed.private_key) {
      parsed.private_key = normalizePrivateKey(parsed.private_key);
    }
    return { serviceAccount: parsed, mode: 'ENV_JSON' };
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8');
    const parsed = JSON.parse(decoded);
    if (parsed.private_key) {
      parsed.private_key = normalizePrivateKey(parsed.private_key);
    }
    return { serviceAccount: parsed, mode: 'ENV_BASE64' };
  }

  const clientEmail = (process.env.FIREBASE_CLIENT_EMAIL || '').trim();
  const privateKey = normalizePrivateKey(process.env.FIREBASE_PRIVATE_KEY || '').trim();
  const projectId = (process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || DEFAULT_PROJECT_ID).trim();
  if (clientEmail && privateKey) {
    return {
      serviceAccount: {
        project_id: projectId,
        client_email: clientEmail,
        private_key: privateKey,
      },
      mode: 'ENV_SPLIT',
    };
  }

  const filePath = (process.env.FIREBASE_SERVICE_ACCOUNT_PATH || process.env.GOOGLE_APPLICATION_CREDENTIALS || '').trim();
  if (filePath) {
    const resolved = path.isAbsolute(filePath)
      ? filePath
      : path.resolve(process.cwd(), filePath);
    if (fs.existsSync(resolved)) {
      const parsed = JSON.parse(fs.readFileSync(resolved, 'utf8'));
      if (parsed.private_key) {
        parsed.private_key = normalizePrivateKey(parsed.private_key);
      }
      return { serviceAccount: parsed, mode: 'FILE_PATH' };
    }
    throw new Error('Configured Firebase credential file path does not exist on disk');
  }

  return null;
}

function isEmulatorOrGcpRuntime() {
  return Boolean(
    process.env.FIRESTORE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    process.env.FUNCTIONS_EMULATOR === 'true' ||
    process.env.K_SERVICE ||
    process.env.FUNCTION_TARGET
  );
}

/**
 * Initialize Firebase Admin SDK safely for Render, Cloud Functions, or Firebase Emulator.
 * Never logs or exposes private keys or raw credential JSON.
 */
function initFirebaseAdmin() {
  const envProjectId = (
    process.env.FIREBASE_PROJECT_ID ||
    process.env.GCLOUD_PROJECT ||
    DEFAULT_PROJECT_ID
  ).trim();

  if (admin.apps.length > 0) {
    runtimeState.initialized = true;
    runtimeState.configured = true;
    if (!runtimeState.projectId) {
      runtimeState.projectId = envProjectId;
    }
    return { ...runtimeState };
  }

  try {
    const parsed = parseServiceAccountFromEnv();
    if (parsed && parsed.serviceAccount) {
      const sa = parsed.serviceAccount;
      if (!sa.client_email || !sa.private_key) {
        throw new Error('Firebase service account is missing client_email or private_key');
      }
      const projectId = (sa.project_id || envProjectId).trim();
      admin.initializeApp({
        credential: admin.credential.cert(sa),
        projectId,
        storageBucket: process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`,
      });
      runtimeState.initialized = true;
      runtimeState.configured = true;
      runtimeState.hasServiceAccount = true;
      runtimeState.credentialMode = parsed.mode;
      runtimeState.projectId = projectId;
      runtimeState.lastError = null;
      return { ...runtimeState };
    }

    if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true' || process.env.NODE_ENV === 'test') {
      admin.initializeApp({ projectId: envProjectId });
      runtimeState.initialized = true;
      runtimeState.configured = true;
      runtimeState.hasServiceAccount = false;
      runtimeState.credentialMode = 'EMULATOR';
      runtimeState.projectId = envProjectId;
      runtimeState.lastError = null;
      return { ...runtimeState };
    }

    if (isEmulatorOrGcpRuntime()) {
      admin.initializeApp({ projectId: envProjectId });
      runtimeState.initialized = true;
      runtimeState.configured = true;
      runtimeState.hasServiceAccount = false;
      runtimeState.credentialMode = 'ADC';
      runtimeState.projectId = envProjectId;
      runtimeState.lastError = null;
      return { ...runtimeState };
    }

    runtimeState.initialized = false;
    runtimeState.configured = false;
    runtimeState.hasServiceAccount = false;
    runtimeState.firestoreReady = false;
    runtimeState.credentialMode = 'UNCONFIGURED';
    runtimeState.projectId = envProjectId;
    runtimeState.lastError = 'Firebase Admin credentials not configured in environment';
    return { ...runtimeState };
  } catch (err) {
    runtimeState.initialized = false;
    runtimeState.configured = false;
    runtimeState.hasServiceAccount = false;
    runtimeState.firestoreReady = false;
    runtimeState.credentialMode = 'ERROR';
    runtimeState.projectId = envProjectId;
    runtimeState.lastError = err.message || 'Firebase Admin initialization failed';
    return { ...runtimeState };
  }
}

function getFirestoreDb() {
  if (!runtimeState.initialized && admin.apps.length === 0) {
    return null;
  }
  try {
    return admin.firestore();
  } catch (_) {
    return null;
  }
}

async function verifyFirestoreConnection(db) {
  runtimeState.lastCheckedAt = new Date().toISOString();
  if (!db) {
    runtimeState.firestoreReady = false;
    return { connected: false, error: runtimeState.lastError || 'Firestore unavailable' };
  }
  try {
    // Lightweight single-document metadata query (1 read max) to verify Spark Firestore connectivity
    await db.collection('service_categories').limit(1).get();
    runtimeState.firestoreReady = true;
    runtimeState.lastError = null;
    return { connected: true, projectId: runtimeState.projectId };
  } catch (err) {
    runtimeState.firestoreReady = false;
    runtimeState.lastError = err.message || 'Firestore connection check failed';
    return { connected: false, error: runtimeState.lastError };
  }
}

function getFirebaseStatus() {
  return {
    initialized: runtimeState.initialized || admin.apps.length > 0,
    configured: runtimeState.configured || admin.apps.length > 0,
    hasServiceAccount: runtimeState.hasServiceAccount,
    firestoreReady: runtimeState.firestoreReady,
    credentialMode: runtimeState.credentialMode,
    projectId: runtimeState.projectId,
    plan: 'spark-free',
    emulator: Boolean(process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true'),
    lastCheckedAt: runtimeState.lastCheckedAt,
    lastError: runtimeState.lastError,
  };
}

module.exports = {
  initFirebaseAdmin,
  getFirestoreDb,
  verifyFirestoreConnection,
  getFirebaseStatus,
  normalizePrivateKey,
};
