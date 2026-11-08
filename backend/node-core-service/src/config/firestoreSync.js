// ============================================================================
// BOOKURTECHNICIAN — CLOUD FIRESTORE SYNCHRONIZATION ENGINE
// Project: bookmytechnician-53d94 (asia-south1)
// Automatically mirrors & restores Bookings, Customers, Technicians, Catalog & Banners
// ============================================================================

const { getFirestoreDb } = require('./firebase');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'bookmytechnician-53d94';
const FIRESTORE_REST_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

/**
 * Convert JS primitive/object into Firestore REST Value format
 */
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

/**
 * Convert Firestore REST Document into plain JS object
 */
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

/**
 * Upsert a document into Cloud Firestore (uses Admin SDK first, falls back to REST API).
 * Supports partial updates via updateMask (Spark-plan optimized field-level patching).
 */
async function upsertDocument(collection, docId, data, updateMask = null) {
  if (process.env.DISABLE_FIRESTORE_SYNC === 'true' || process.env.NODE_ENV === 'test') return false;
  if (!collection || !docId || !data) return false;
  const cleanId = String(docId).replace(/[^a-zA-Z0-9_-]/g, '_');

  // Try Admin SDK if credentials are configured
  const db = getFirestoreDb();
  if (db) {
    try {
      await db.collection(collection).doc(cleanId).set(
        JSON.parse(JSON.stringify(data)),
        { merge: true }
      );
      return true;
    } catch (_) {
      // Fallback to REST API below
    }
  }

  // Fallback to Firestore REST API with updateMask to preserve unrelated fields
  try {
    const fields = {};
    const fieldKeys = [];
    for (const [k, v] of Object.entries(data)) {
      if (v !== undefined) {
        fields[k] = toFirestoreValue(v);
        fieldKeys.push(k);
      }
    }
    const maskKeys = Array.isArray(updateMask) && updateMask.length > 0 ? updateMask : fieldKeys;
    const maskQuery = maskKeys
      .map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
      .join('&');
    const url = `${FIRESTORE_REST_BASE}/${encodeURIComponent(collection)}/${encodeURIComponent(cleanId)}${maskQuery ? '?' + maskQuery : ''}`;
    const res = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });
    return res.ok;
  } catch (err) {
    return false;
  }
}

/**
 * Delete a document from Cloud Firestore
 */
async function removeDocument(collection, docId) {
  if (process.env.DISABLE_FIRESTORE_SYNC === 'true' || process.env.NODE_ENV === 'test') return false;
  if (!collection || !docId) return false;
  const cleanId = String(docId).replace(/[^a-zA-Z0-9_-]/g, '_');

  const db = getFirestoreDb();
  if (db) {
    try {
      await db.collection(collection).doc(cleanId).delete();
      return true;
    } catch (_) {}
  }

  try {
    const url = `${FIRESTORE_REST_BASE}/${encodeURIComponent(collection)}/${encodeURIComponent(cleanId)}`;
    const res = await fetch(url, { method: 'DELETE' });
    return res.ok;
  } catch (_) {
    return false;
  }
}

/**
 * Fetch all documents in a collection from Cloud Firestore
 */
async function listDocuments(collection, pageSize = 300) {
  const db = getFirestoreDb();
  if (db) {
    try {
      const snap = await db.collection(collection).limit(pageSize).get();
      const items = [];
      snap.forEach(doc => items.push({ id: doc.id, ...doc.data() }));
      return items;
    } catch (_) {}
  }

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

/**
 * Seed & Sync full Master Catalog, Categories & Banners to Firestore
 */
async function syncCatalogToFirestore() {
  try {
    const { getMasterCatalog, getFlattenedServices, getCatalogVersion } = require('./masterCatalog');
    const categories = getMasterCatalog();
    const services = getFlattenedServices();
    const catalogVersion = getCatalogVersion();

    let syncedCats = 0;
    for (const cat of categories) {
      const isActive = cat.isActive !== undefined ? Boolean(cat.isActive) : (cat.active !== false);
      const ok = await upsertDocument('service_categories', cat.id || cat.categoryId, {
        id: cat.id || cat.categoryId,
        categoryId: cat.id || cat.categoryId,
        name: cat.name,
        slug: (cat.slug || cat.name || '').toLowerCase().replace(/[^a-z0-9]+/g, '-'),
        icon: cat.icon || 'build',
        imageUrl: cat.imageUrl || '',
        active: isActive,
        isActive,
        displayOrder: cat.displayOrder || 1,
        catalogVersion,
        subcategories: cat.subcategories || [],
        createdAt: cat.createdAt || '2026-01-01T00:00:00.000Z',
        updatedAt: cat.updatedAt || new Date().toISOString(),
      });
      if (ok) syncedCats++;
    }

    let syncedServices = 0;
    // Sync services in parallel batches of 15 for fast startup
    for (let i = 0; i < services.length; i += 15) {
      const batch = services.slice(i, i + 15);
      const results = await Promise.all(
        batch.map(srv => {
          const isActive = srv.isActive !== undefined ? Boolean(srv.isActive) : (srv.active !== false);
          return upsertDocument('services', srv.id, {
            ...srv,
            id: srv.id,
            canonicalServiceId: srv.canonicalServiceId || srv.id,
            isActive,
            active: isActive,
            catalogVersion,
            updatedAt: srv.updatedAt || new Date().toISOString(),
          });
        })
      );
      syncedServices += results.filter(Boolean).length;
    }

    console.log(`🔥 [Firebase Firestore] Synced ${syncedCats} categories and ${syncedServices} services (v${catalogVersion}) to project '${PROJECT_ID}'`);
    return { syncedCats, syncedServices, catalogVersion };
  } catch (err) {
    console.warn('⚠️ [Firebase Firestore] Catalog sync notice:', err.message);
    return { syncedCats: 0, syncedServices: 0, catalogVersion: 1 };
  }
}

/**
 * Delete all documents in a collection from Cloud Firestore
 */
async function clearCollection(collection) {
  if (process.env.DISABLE_FIRESTORE_SYNC === 'true' || process.env.NODE_ENV === 'test') return 0;
  if (!collection) return 0;
  try {
    const docs = await listDocuments(collection, 300);
    let deleted = 0;
    for (const d of docs) {
      const docId = d.id || d.bookingCode || d.customerId || d.technicianId || d.offerId;
      if (docId) {
        const ok = await removeDocument(collection, docId);
        if (ok) deleted++;
      }
    }
    return deleted;
  } catch (_) {
    return 0;
  }
}

module.exports = {
  PROJECT_ID,
  FIRESTORE_REST_BASE,
  upsertDocument,
  removeDocument,
  listDocuments,
  clearCollection,
  syncCatalogToFirestore,
};

