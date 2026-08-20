require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const { Server } = require('socket.io');

const bookingRoutes = require('./routes/bookingRoutes');
const adminRoutes = require('./routes/adminRoutes');
const { updateTechnicianLocation, removeTechnician } = require('./services/redisGeoService');

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  },
});

global.io = io;

app.use(cors());
app.use(express.json());

// Attach io to app
app.set('io', io);

// Routes
app.use('/api/bookings', bookingRoutes);
app.use('/api/admin', adminRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'booking-dispatch-service', timestamp: new Date() });
});

// Socket.io Real-time Handlers
io.on('connection', (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);

  // Join technician room
  socket.on('technician:join', ({ technicianId, category }) => {
    socket.join(`tech_${technicianId}`);
    if (category) socket.join(`category_${category.toLowerCase()}`);
    console.log(`Technician ${technicianId} joined rooms.`);
  });

  // Join customer room
  socket.on('customer:join', ({ customerId }) => {
    socket.join(`cust_${customerId}`);
    console.log(`Customer ${customerId} joined room.`);
  });

  // Live Location Sync from Technician App
  socket.on('technician:location_sync', async ({ technicianId, category, longitude, latitude }) => {
    if (technicianId && category && longitude && latitude) {
      await updateTechnicianLocation(category, technicianId, longitude, latitude);
    }
  });

  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 4000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/bookurtechnician_dispatch';

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected with 2dsphere indexing ready');
    server.listen(PORT, () => {
      console.log(`🚀 Booking & Dual-OTP Service running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.warn('⚠️ MongoDB connection warning (Running with memory fallback):', err.message);
    server.listen(PORT, () => {
      console.log(`🚀 Booking Service running on port ${PORT}`);
    });
  });
