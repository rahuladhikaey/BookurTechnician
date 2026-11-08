/**
 * BOOKURTECHNICIAN — PHASE 5 IDEMPOTENT SERVICE CATALOG MIGRATION
 * Normalizes and migrates all 158 services across 8 categories & 21 subcategories
 * into the persistent store (data/catalog_store.json) and Cloud Firestore
 * (service_categories/{categoryId} and services/{serviceId}).
 */

const fs = require('fs');
const path = require('path');
const {
  getMasterCatalog,
  getFlattenedServices,
  getCatalogVersion,
  saveCatalogStore,
} = require('../src/config/masterCatalog');
const { syncCatalogToFirestore } = require('../src/config/firestoreSync');

async function runMigration() {
  console.log('===================================================================');
  console.log('BOOKURTECHNICIAN PHASE 5 — CENTRAL SERVICE CATALOG MIGRATION');
  console.log('===================================================================');

  const categories = getMasterCatalog();
  const flattened = getFlattenedServices();

  const categoryIds = new Set(categories.map(c => c.id));
  const subcategoryIds = new Set();
  categories.forEach(c => {
    (c.subcategories || []).forEach(sub => subcategoryIds.add(sub.id));
  });

  const seenServiceIds = new Set();
  const duplicateIds = [];
  const missingCategoryRefs = [];
  const failedItems = [];
  let migratedCount = 0;

  for (const srv of flattened) {
    if (!srv.id || !srv.name) {
      failedItems.push({ id: srv.id || 'UNKNOWN', reason: 'Missing id or name' });
      continue;
    }
    if (seenServiceIds.has(srv.id)) {
      duplicateIds.push(srv.id);
      continue;
    }
    if (!srv.categoryId || !categoryIds.has(srv.categoryId)) {
      missingCategoryRefs.push({ id: srv.id, categoryId: srv.categoryId });
      continue;
    }
    seenServiceIds.add(srv.id);
    migratedCount++;
  }

  // Persist to disk store idempotently
  saveCatalogStore();

  // Sync to Cloud Firestore (best-effort on Spark plan)
  const syncResult = await syncCatalogToFirestore();

  const report = {
    executedAt: new Date().toISOString(),
    catalogVersion: getCatalogVersion(),
    totalCategories: categories.length,
    totalSubcategories: subcategoryIds.size,
    totalOriginalServices: flattened.length,
    totalMigratedServices: migratedCount,
    duplicateIdsPrevented: duplicateIds.length,
    missingCategoryReferences: missingCategoryRefs.length,
    failedItemsCount: failedItems.length,
    firestoreSyncedCategories: syncResult.syncedCats,
    firestoreSyncedServices: syncResult.syncedServices,
    categoryBreakdown: categories.map(cat => {
      const catServices = (cat.subcategories || []).reduce((acc, sub) => acc + (sub.services || []).length, 0);
      return {
        categoryId: cat.id,
        categoryName: cat.name,
        subcategoryCount: (cat.subcategories || []).length,
        serviceCount: catServices,
      };
    }),
  };

  const reportFile = path.join(__dirname, '../data/phase5_migration_summary.json');
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 2), 'utf8');

  console.log(JSON.stringify(report, null, 2));
  return report;
}

if (require.main === module) {
  runMigration()
    .then(report => {
      if (report.totalMigratedServices !== 158 || report.failedItemsCount > 0 || report.missingCategoryReferences > 0) {
        process.exit(1);
      }
      process.exit(0);
    })
    .catch(err => {
      console.error('Migration failed:', err);
      process.exit(1);
    });
}

module.exports = { runMigration };

