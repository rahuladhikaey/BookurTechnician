// ============================================================================
// BOOKURTECHNICIAN — SEED MASTER CATALOG TO CLOUD FIRESTORE
// Project: bookmytechnician-53d94 (asia-south1)
// ============================================================================

const { initFirebase } = require('../src/config/firebase');
const { syncCatalogToFirestore, upsertDocument } = require('../src/config/firestoreSync');

async function main() {
  console.log('🚀 Starting Firebase Cloud Firestore Master Seed for bookmytechnician-53d94...');
  initFirebase();

  const { syncedCats, syncedServices } = await syncCatalogToFirestore();

  // Seed default Promotional Banners
  const banners = [
    {
      id: 'ban-01',
      title: '50% OFF on AC Deep Cleaning',
      subtitle: 'Beat the heat with certified AC experts',
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800',
      targetCategory: 'cat_ac',
      active: true,
      updatedAt: new Date().toISOString(),
    },
    {
      id: 'ban-02',
      title: 'Certified Electrician & Wiring',
      subtitle: 'Fast 15-min arrival with 30-day warranty',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=800',
      targetCategory: 'cat_electrical',
      active: true,
      updatedAt: new Date().toISOString(),
    },
  ];

  for (const ban of banners) {
    await upsertDocument('banners', ban.id, ban);
  }

  console.log(`✅ Seed Completed! Categories: ${syncedCats}, Services: ${syncedServices}, Banners: ${banners.length}`);
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Seed Error:', err);
  process.exit(1);
});

