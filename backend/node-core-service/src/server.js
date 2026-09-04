require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');

const fs = require('fs');
const path = require('path');

// Database & Integrations
const { connectMongo, isMongoHealthy } = require('./config/mongo');
const { initPostgres, isPgHealthy } = require('./config/postgres');
const { initRedis, isRedisHealthy, geoAdd } = require('./config/redis');
const { initFirebase } = require('./config/firebase');
const { initKafka } = require('./config/kafka');

// Routes
const authRoutes = require('./routes/authRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const technicianRoutes = require('./routes/technicianRoutes');
const adminRoutes = require('./routes/adminRoutes');
const catalogRoutes = require('./routes/catalogRoutes');
const aiRoutes = require('./routes/aiRoutes');

const app = express();
const server = http.createServer(app);

// Socket.io initialization with CORS
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  },
});

global.io = io;
app.set('io', io);

app.use(cors());
app.use(express.json());

// Serve Static Admin Web Panel if built
const potentialPaths = [
  path.join(__dirname, '../../../apps/admin_panel/dist'),
  path.join(__dirname, '../../apps/admin_panel/dist'),
  path.join(__dirname, '../admin_dist'),
  path.join(__dirname, './public/admin'),
];
const resolvedAdminPath = potentialPaths.find(p => fs.existsSync(p));

if (resolvedAdminPath) {
  app.use('/admin', express.static(resolvedAdminPath));
  app.use(express.static(resolvedAdminPath));
  app.get(['/admin', '/admin/*', '/'], (req, res) => {
    res.sendFile(path.join(resolvedAdminPath, 'index.html'));
  });
  console.log(`💻 [Admin UI] Serving production dashboard from ${resolvedAdminPath}`);
}

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/technicians', technicianRoutes);
app.use('/api/v1/technician', technicianRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/catalog', catalogRoutes);
app.use('/api/v1/ai', aiRoutes);

// Fallback compatible route alias
app.use('/api/bookings', bookingRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/technicians', technicianRoutes);
app.use('/api/technician', technicianRoutes);

// Comprehensive Health Check
app.get('/health', (req, res) => {
  res.json({
    status: 'HEALTHY',
    service: 'bookurtechnician-node-core-service',
    timestamp: new Date(),
    architecture: {
      mongoDb: isMongoHealthy() ? 'CONNECTED' : 'STANDALONE_FALLBACK',
      postgreSql: isPgHealthy() ? 'CONNECTED' : 'STANDALONE_FALLBACK',
      redis: isRedisHealthy() ? 'CONNECTED' : 'STANDALONE_FALLBACK',
    },
    version: '1.0.0-MVP',
  });
});

// Socket.io Real-Time Event Handlers
io.on('connection', (socket) => {
  console.log(`🔌 [Socket.io] Client connected: ${socket.id}`);

  // Technician joins category and personal room
  socket.on('technician:join', ({ technicianId, category }) => {
    socket.join(`tech_${technicianId}`);
    if (category) socket.join(`category_${category.toLowerCase()}`);
    console.log(`👷 Technician ${technicianId} joined live dispatch room.`);
  });

  // Customer joins personal room
  socket.on('customer:join', ({ customerId }) => {
    socket.join(`cust_${customerId}`);
    console.log(`👤 Customer ${customerId} joined tracking room.`);
  });

  // Join booking specific room for real-time tracking
  socket.on('job:join', ({ bookingId }) => {
    if (bookingId) {
      socket.join(`booking_${bookingId}`);
      console.log(`📦 Client joined live booking tracking room: booking_${bookingId}`);
    }
  });

  const handleLocationStream = async ({ technicianId, category = 'electrician', longitude, latitude, speed, heading, bookingId }) => {
    if (longitude !== undefined && latitude !== undefined) {
      const techId = technicianId || socket.handshake?.auth?.technicianId;
      if (!techId) return;
      const normCat = String(category || 'electrician').toLowerCase().replace(/^cat_/, '');
      const parsedLng = parseFloat(longitude);
      const parsedLat = parseFloat(latitude);
      const parsedSpeed = parseFloat(speed) || 0;
      const parsedHeading = parseFloat(heading) || 0;

      try {
        await geoAdd(`tech_geo:${normCat}`, parsedLng, parsedLat, techId);
        await geoAdd('tech_geo:all', parsedLng, parsedLat, techId);
      } catch (_) {}

      // Update in centralized live bookings store
      try {
        bookingsStore.updateTechnicianLocation(techId, parsedLat, parsedLng, parsedSpeed, parsedHeading);
      } catch (_) {}

      const locationPayload = {
        technicianId: techId,
        bookingId: bookingId || null,
        longitude: parsedLng,
        latitude: parsedLat,
        speed: parsedSpeed,
        heading: parsedHeading,
        timestamp: Date.now(),
      };

      // Broadcast location to customers tracking this technician
      io.emit(`tech:location:${techId}`, locationPayload);
      io.emit('technician:location:broadcast', locationPayload);
      io.emit('job:partner_location', locationPayload);
      io.emit('telemetry', locationPayload);

      if (bookingId) {
        io.to(`booking_${bookingId}`).emit('job:partner_location', locationPayload);
      }
    }
  };

  socket.on('technician:location_sync', handleLocationStream);
  socket.on('technician:location:update', handleLocationStream);
  socket.on('technician:location', handleLocationStream);

  socket.on('disconnect', () => {
    console.log(`🔌 [Socket.io] Client disconnected: ${socket.id}`);
  });
});

// Start Connections and Server
const PORT = process.env.PORT || 4000;

const startServer = async () => {
  console.log('🚀 Initializing BookurTechnician Polyglot Backend Services...');
  
  await connectMongo();
  await initPostgres();
  initRedis();
  initFirebase();
  await initKafka();

  server.listen(PORT, () => {
    console.log(`=======================================================`);
    console.log(`⚡ Node.js Core API Gateway listening on port ${PORT}`);
    console.log(`🌐 API Base URL: http://localhost:${PORT}/api/v1`);
    console.log(`📡 WebSocket Dispatch: ws://localhost:${PORT}`);
    console.log(`=======================================================`);
  });
};
startServer();


