// ============================================================================
// BOOKURTECHNICIAN ADMIN PANEL — DIRECT CLOUD FIRESTORE ADAPTER
// Project: bookmytechnician-53d94 (asia-south1)
// Enables 100% Firebase Hosting operation even when Node backend is offline!
// ============================================================================

import { firebaseConfig } from '../config/firebaseConfig.js';

const PROJECT_ID = firebaseConfig.projectId || 'bookmytechnician-53d94';
const FIRESTORE_REST_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: String(val) };
    return { doubleValue: val };
  }
  if (typeof val === 'string') return { stringValue: val };
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      if (v !== undefined) {
        fields[k] = toFirestoreValue(v);
      }
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function fromFirestoreValue(valObj) {
  if (!valObj || typeof valObj !== 'object') return null;
  if ('stringValue' in valObj) return valObj.stringValue;
  if ('booleanValue' in valObj) return valObj.booleanValue;
  if ('integerValue' in valObj) return Number(valObj.integerValue);
  if ('doubleValue' in valObj) return Number(valObj.doubleValue);
  if ('nullValue' in valObj) return null;
  if ('timestampValue' in valObj) return valObj.timestampValue;
  if ('arrayValue' in valObj) {
    return (valObj.arrayValue.values || []).map(fromFirestoreValue);
  }
  if ('mapValue' in valObj) {
    const out = {};
    const fields = valObj.mapValue.fields || {};
    for (const [k, v] of Object.entries(fields)) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }
  return null;
}

function docToPlainObject(doc) {
  if (!doc || !doc.fields) return null;
  const out = {};
  for (const [k, v] of Object.entries(doc.fields)) {
    out[k] = fromFirestoreValue(v);
  }
  if (doc.name && !out.id) {
    const parts = doc.name.split('/');
    out.id = parts[parts.length - 1];
  }
  return out;
}

export async function firestoreList(collection, pageSize = 300) {
  try {
    const url = `${FIRESTORE_REST_BASE}/${encodeURIComponent(collection)}?pageSize=${pageSize}`;
    const res = await fetch(url);
    if (!res.ok) return [];
    const json = await res.json();
    return (json.documents || []).map(docToPlainObject).filter(Boolean);
  } catch (_) {
    return [];
  }
}

export async function firestoreUpsert(collection, docId, data) {
  // SECURITY: Direct client-side Firestore writes are strictly disabled.
  // All modifications must pass through authenticated backend endpoints.
  console.error('[Security] Direct client-side Firestore writes are disabled.');
  throw new Error('Direct client Firestore writes are disabled. All mutations must go through authenticated backend endpoints.');
}

export async function firestoreDelete(collection, docId) {
  // SECURITY: Direct client-side Firestore deletes are strictly disabled.
  console.error('[Security] Direct client-side Firestore deletes are disabled.');
  throw new Error('Direct client Firestore deletes are disabled. All deletions must go through authenticated backend endpoints.');
}

export async function firestoreClearCollection(collection) {
  console.error('[Security] Direct client-side Firestore clearing is disabled.');
  throw new Error('Direct client Firestore clearing is disabled.');
}

/**
 * Handle API endpoint directly via Cloud Firestore when backend server is unreachable
 * SECURITY: All administrative (/admin/*) and authentication (/auth/*) endpoints are STRICTLY FORBIDDEN.
 * Only public read-only catalog projections are served for offline viewing.
 */
export async function handleFirestoreFallback(endpoint, method = 'GET', body = null) {
  const cleanPath = endpoint.split('?')[0].replace(/^\/api\/v1/, '');
  const m = (method || 'GET').toUpperCase();

  // SECURITY RULE 1: Block all administrative and authentication requests in fallback mode
  // Admin access is impossible without authenticating through the backend server.
  if (cleanPath.startsWith('/admin') || cleanPath.startsWith('/auth')) {
    console.error(`🚨 [Security] Admin/Auth endpoint ${cleanPath} rejected in fallback mode - backend server required.`);
    return {
      success: false,
      error: 'Unauthorized: Backend server required for administrative operations. Offline admin bypass is forbidden.',
      code: 'ADMIN_FALLBACK_FORBIDDEN',
      statusCode: 401,
    };
  }

  // SECURITY RULE 2: Block all non-GET mutation methods in fallback mode
  if (m !== 'GET') {
    return {
      success: false,
      error: 'Backend server required for write operations. Mutations are disabled in offline projection mode.',
      code: 'WRITE_FALLBACK_DISABLED',
      statusCode: 503,
    };
  }

  // 1. Categories - READ-ONLY Public Projection
  if (cleanPath === '/catalog/categories' || cleanPath === '/categories') {
    const cats = await firestoreList('service_categories');
    cats.sort((a, b) => (a.displayOrder || 99) - (b.displayOrder || 99));
    return { success: true, data: cats, categories: cats };
  }

  // 2. Services - READ-ONLY Public Projection
  if (cleanPath === '/catalog/services' || cleanPath === '/services') {
    const srvs = await firestoreList('services');
    return { success: true, data: srvs, services: srvs };
  }

  // 3. Banners - READ-ONLY Public Projection
  if (cleanPath === '/catalog/banners' || cleanPath === '/banners') {
    const banners = await firestoreList('banners');
    return { success: true, data: banners, banners };
  }

  return {
    success: false,
    error: 'Backend server connection required for this endpoint.',
    code: 'BACKEND_REQUIRED',
    statusCode: 503,
  };
}

