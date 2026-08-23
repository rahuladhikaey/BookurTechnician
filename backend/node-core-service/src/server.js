require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');

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

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/technicians', technicianRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/catalog', catalogRoutes);
app.use('/api/v1/ai', aiRoutes);

// Fallback compatible route alias
app.use('/api/bookings', bookingRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/auth', authRoutes);

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

  // Technician live GPS sync stream
  socket.on('technician:location_sync', async ({ technicianId, category, longitude, latitude }) => {
    if (technicianId && category && longitude !== undefined && latitude !== undefined) {
      const geoKey = `tech_geo:${category.toLowerCase()}`;
      await geoAdd(geoKey, parseFloat(longitude), parseFloat(latitude), technicianId);

      // Broadcast location to customers tracking this technician
      io.emit(`tech:location:${technicianId}`, {
        technicianId,
        longitude: parseFloat(longitude),
        latitude: parseFloat(latitude),
        timestamp: Date.now(),
      });
    }
  });

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
