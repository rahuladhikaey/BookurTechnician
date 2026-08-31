// ============================================================================
// BOOKURTECHNICIAN IN-MEMORY TECHNICIAN & KYC DOCUMENT STORE
// Shared fallback cache ensuring instantaneous sync between Technician App and Admin Panel
// ============================================================================

const inMemorySkills = new Map();
const inMemoryDocs = new Map();
const inMemoryTechProfiles = new Map();

// Initial Seed Partner Technicians for Seamless Development & Demo
const SEED_PARTNERS = [
  {
    id: 'tech-001',
    technicianId: 'tech-001',
    technicianCode: 'BT-TECH-1001',
    fullName: 'Rahul Adhikari (Verified Partner)',
    name: 'Rahul Adhikari (Verified Partner)',
    phone: '+91 9876543210',
    email: 'rahul.tech@bookurtechnician.com',
    category: 'Electrician',
    skills: ['Electrical & Wiring', 'AC Installation & Repair', 'Switchboard Repair'],
    kycStatus: 'PENDING',
    rating: 4.92,
    totalJobsCompleted: 148,
    isOnline: true,
    experienceYears: 4,
    walletBalance: 2450.00,
    upiId: 'rahul.tech@upi',
    upiNumber: '9876543210',
    avatar: '',
    livePicUrl: '',
    photo: '',
    aadhaarUrl: '',
    voterCardUrl: '',
    aadhaarNumber: '',
    voterCardNumber: '',
    latitude: 22.5726,
    longitude: 88.3639,
    joinedAt: new Date().toISOString(),
  },
  {
    id: 'tech-002',
    technicianId: 'tech-002',
    technicianCode: 'BT-TECH-1002',
    fullName: 'Amit Kumar Sharma',
    name: 'Amit Kumar Sharma',
    phone: '+91 9831122334',
    email: 'amit.sharma@bookurtechnician.com',
    category: 'AC Service & Repair',
    skills: ['AC Deep Cleaning', 'Gas Refilling', 'PCB Circuit Repair'],
    kycStatus: 'VERIFIED',
    rating: 4.88,
    totalJobsCompleted: 215,
    isOnline: true,
    experienceYears: 5,
    walletBalance: 4120.00,
    upiId: 'amit.sharma@okaxis',
    upiNumber: '9831122334',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    livePicUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    photo: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    aadhaarUrl: 'https://hgjvwddlwofzpdurvpzd.supabase.co/storage/v1/object/public/kyc-documents/kyc_aadhaar_sample.jpg',
    voterCardUrl: 'https://hgjvwddlwofzpdurvpzd.supabase.co/storage/v1/object/public/kyc-documents/kyc_voter_sample.jpg',
    aadhaarNumber: 'XXXX-XXXX-8821',
    voterCardNumber: 'WB/04/029/554123',
    latitude: 22.5850,
    longitude: 88.3750,
    joinedAt: new Date(Date.now() - 7 * 86400000).toISOString(),
  }
];

// Initialize seed data
for (const p of SEED_PARTNERS) {
  inMemoryTechProfiles.set(p.id, { ...p });
  inMemorySkills.set(p.id, p.skills);
}

module.exports = {
  inMemorySkills,
  inMemoryDocs,
  inMemoryTechProfiles,
  SEED_PARTNERS,
};
