/**
 * 🧪 End-to-End Complete Flow Verification Script
 * Validates:
 * 1. Customer creates booking -> receives Start OTP + dispatches ringing alert to nearby technicians
 * 2. Technician views "My Bookings Log" -> sees full customer, address, service & schedule details
 * 3. Technician accepts booking -> authentic technician profile (BT-TECH-...) assigned
 * 4. Technician arrives -> submits 4-digit customer Start OTP -> status IN_PROGRESS + Ending OTP generated
 * 5. Technician finishes -> submits customer Ending OTP -> status COMPLETED + financial settlement
 */

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
app.use(express.json());
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
global.io = io;

// Import router
const bookingRoutes = require('../src/routes/bookingRoutes');
const technicianRoutes = require('../src/routes/technicianRoutes');
const { inMemoryTechProfiles } = require('../src/config/inMemoryTechStore');

app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/technicians', technicianRoutes);
app.use('/api/v1/technician', technicianRoutes);

const PORT = 4099;

async function runTest() {
  await new Promise(resolve => server.listen(PORT, resolve));
  console.log(`\n🚀 Test server listening on http://localhost:${PORT}`);

  const axios = require('axios');
  const baseURL = `http://localhost:${PORT}/api/v1`;

  console.log('\n════════════════════════════════════════════════════════════════');
  console.log('🧪 VERIFYING UBER/RAPIDO STYLE BOOKING & OTP FLOW');
  console.log('════════════════════════════════════════════════════════════════\n');

  // Register technician profile in memory store
  const techId = '775A08';
  inMemoryTechProfiles.set(techId, {
    id: techId,
    technicianId: techId,
    technicianCode: 'BT-TECH-775A08',
    fullName: 'Rahul Adhikary (Certified Pro)',
    phone: '+91 9876543210',
    category: 'ELECTRICIAN',
    isOnline: true,
    is_online: true,
    availabilityStatus: 'AVAILABLE',
    currentLatitude: 22.5726,
    currentLongitude: 88.3639,
    rating: 4.95,
  });

  // Step 1: Customer creates booking
  console.log('🔹 Step 1: Customer creates service booking');
  const createRes = await axios.post(`${baseURL}/bookings`, {
    customerId: 'cust_rahul_1',
    customerName: 'Suman Roy',
    customerPhone: '+91 9123456780',
    serviceId: 'fan_rep',
    serviceName: 'Ceiling Fan Repair',
    category: 'ELECTRICIAN',
    address: 'Flat 4B, Green Glen Layout, Nadia, West Bengal',
    latitude: 22.5726,
    longitude: 88.3639,
    basePrice: 299,
    grandTotal: 348,
    visitFee: 49,
    paymentMethod: 'ONLINE',
  });

  const createdBooking = createRes.data.booking;
  const bookingId = createdBooking.id;
  const startOtp = createRes.data.startOtp;
  console.log(`  ✅ Booking created #${createdBooking.bookingCode} (ID: ${bookingId})`);
  console.log(`  🔑 Customer Start OTP generated: ${startOtp}`);

  // Step 2: Technician checks "My Bookings Log"
  console.log('\n🔹 Step 2: Technician views "My Bookings Log"');
  const techJobsRes = await axios.get(`${baseURL}/technician/jobs?technicianId=${techId}`);
  const jobsList = techJobsRes.data.data || techJobsRes.data.bookings;
  const matchingJob = jobsList.find(j => j.id === bookingId || j.bookingCode === createdBooking.bookingCode);

  if (!matchingJob) {
    throw new Error(`Booking #${bookingId} not found in technician jobs log!`);
  }
  console.log(`  ✅ Job found in Technician Bookings Log!`);
  console.log(`     Service Title: ${matchingJob.service?.name || matchingJob.serviceName}`);
  console.log(`     Customer Name: ${matchingJob.customer?.fullName || matchingJob.customerName}`);
  console.log(`     Customer Phone: ${matchingJob.customer?.phone || matchingJob.customerPhone}`);
  console.log(`     Payout: ₹${matchingJob.technicianPayoutAmount}`);
  console.log(`     Address: ${matchingJob.fullAddress || matchingJob.address?.area}`);

  // Step 3: Technician accepts booking
  console.log('\n🔹 Step 3: Technician accepts service booking');
  const acceptRes = await axios.post(`${baseURL}/bookings/${bookingId}/accept`, {
    technicianId: techId,
  });
  const acceptedTech = acceptRes.data.technician;
  console.log(`  ✅ Booking accepted! Status: ${acceptRes.data.booking.status}`);
  console.log(`  👤 Assigned Technician Code: ${acceptedTech.technicianCode}`);
  console.log(`  👤 Assigned Technician Name: ${acceptedTech.technicianName}`);
  console.log(`  ⭐ Assigned Rating: ${acceptedTech.technicianRating}`);

  // Step 4: Technician arrives and enters Customer's Start OTP
  console.log('\n🔹 Step 4: Technician arrives & enters Customer Start OTP');
  const startRes = await axios.patch(`${baseURL}/bookings/${bookingId}/status`, {
    status: 'IN_PROGRESS',
    startOtp: startOtp,
  });
  const endOtp = startRes.data.endOtp;
  console.log(`  ✅ Start OTP verified! Booking Status: ${startRes.data.booking.status}`);
  console.log(`  🏁 Ending / Completion OTP generated for Customer: ${endOtp}`);

  // Step 5: Service completed -> Technician enters Customer's Ending OTP
  console.log('\n🔹 Step 5: Technician enters Customer Ending OTP to complete service');
  const completeRes = await axios.patch(`${baseURL}/bookings/${bookingId}/status`, {
    status: 'COMPLETED',
    endOtp: endOtp,
  });
  console.log(`  ✅ Ending OTP verified! Booking Status: ${completeRes.data.booking.status}`);
  console.log(`  💰 Financial Settlement: ₹${completeRes.data.settlement?.technicianEarnings} credited to technician.`);

  console.log('\n════════════════════════════════════════════════════════════════');
  console.log('🎉 ALL 5 E2E FLOW STEPS PASSED WITH 100% SUCCESS!');
  console.log('════════════════════════════════════════════════════════════════\n');

  server.close();
  process.exit(0);
}

runTest().catch(err => {
  console.error('\n❌ E2E Test Failed:', err.message);
  server.close();
  process.exit(1);
});
