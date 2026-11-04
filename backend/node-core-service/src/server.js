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
const firestoreSync = require('./config/firestoreSync');
const bookingsStore = require('./config/bookingsStore');
const { hydrateTechniciansFromFirestore } = require('./config/inMemoryTechStore');

// Routes
const authRoutes = require('./routes/authRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const technicianRoutes = require('./routes/technicianRoutes');
const adminRoutes = require('./routes/adminRoutes');
const catalogRoutes = require('./routes/catalogRoutes');
const aiRoutes = require('./routes/aiRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const dispatchRoutes = require('./routes/dispatchRoutes');
const customerRoutes = require('./routes/customerRoutes');

const app = express();
const server = http.createServer(app);

// Socket.io initialization with CORS & production resilience
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
    credentials: true,
  },
  pingInterval: 25000,
  pingTimeout: 20000,
  connectTimeout: 45000,
  allowEIO3: true,
  transports: ['websocket', 'polling'],
});

global.io = io;
const corsOptions = {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With', 'x-custom-header'],
  credentials: true,
  optionsSuccessStatus: 200,
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));
app.use(express.urlencoded({
  extended: true,
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));

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
app.use('/api/v1/customer', customerRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/technicians', technicianRoutes);
app.use('/api/v1/technician', technicianRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/catalog', catalogRoutes);
app.use('/api/v1/services', catalogRoutes);
app.use('/api/v1/ai', aiRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/dispatch', dispatchRoutes);

// Fallback compatible route alias
app.use('/api/customer', customerRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/services', catalogRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/technicians', technicianRoutes);
app.use('/api/technician', technicianRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/dispatch', dispatchRoutes);

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

const { resolveUserFromToken } = require('./middleware/authMiddleware');
const automaticDispatchEngine = require('./services/automaticDispatchEngine');

// Socket.io Real-Time Event Handlers with Authenticated Room Ownership (Section 18 & 21)
io.use(async (socket, next) => {
  try {
    const rawToken =
      socket.handshake?.auth?.token ||
      (socket.handshake?.headers?.authorization || '').replace(/^Bearer\s+/i, '') ||
      socket.handshake?.query?.token;

    if (rawToken) {
      const resolved = await resolveUserFromToken(rawToken, { headers: socket.handshake?.headers || {} });
      if (resolved && !resolved.error) {
        socket.user = resolved;
      }
    }
  } catch (_) {}
  next();
});

function isAuthorizedToJoinRoom(socket, roomName) {
  if (!roomName || typeof roomName !== 'string') return false;
  const user = socket.user;
  const role = String(user?.role || '').toUpperCase();

  if (roomName === 'admin_dispatch') {
    return role === 'ADMIN' || role === 'SUPER_ADMIN';
  }
  if (roomName.startsWith('tech_')) {
    const targetTechId = roomName.replace(/^tech_/, '');
    if (user) {
      if (role === 'ADMIN' || role === 'SUPER_ADMIN') return true;
      if (role !== 'TECHNICIAN') return false;
      return String(user.id) === String(targetTechId) || String(user.phone) === String(targetTechId);
    }
    return true;
  }
  if (roomName.startsWith('cust_')) {
    const targetCustId = roomName.replace(/^cust_/, '');
    if (user) {
      if (role === 'ADMIN' || role === 'SUPER_ADMIN') return true;
      if (role !== 'CUSTOMER') return false;
      return String(user.id) === String(targetCustId);
    }
    return true;
  }
  if (roomName.startsWith('booking_') || roomName.startsWith('job_')) {
    const bookingId = roomName.replace(/^(booking_|job_)/, '');
    if (user && role !== 'ADMIN' && role !== 'SUPER_ADMIN') {
      const booking = bookingsStore.getBookingById(bookingId);
      if (booking) {
        if (role === 'CUSTOMER' && booking.customerId && String(booking.customerId) !== String(user.id)) {
          return false;
        }
        if (role === 'TECHNICIAN' && booking.technicianId && String(booking.technicianId) !== String(user.id)) {
          return false;
        }
      }
    }
    return true;
  }
  return true;
}

io.on('connection', (socket) => {
  console.log(`🔌 [Socket.io] Client connected: ${socket.id}`);

  // Generic room joining with authorization check
  socket.on('join:room', (room, ack) => {
    if (room) {
      if (!isAuthorizedToJoinRoom(socket, room)) {
        const errPayload = { success: false, error: `Forbidden: Unauthorized to join room ${room}` };
        socket.emit('auth_error', errPayload);
        if (typeof ack === 'function') ack(errPayload);
        return;
      }
      if (String(room).startsWith('tech_')) {
        socket.joinedTechnicianId = String(room).replace(/^tech_/, '');
      }
      socket.join(room);
      if (typeof ack === 'function') ack({ success: true, room });
      console.log(`📡 [Socket.io] Client ${socket.id} joined room: ${room}`);
    }
  });

  // Technician joins category and personal rooms
  socket.on('technician:join', ({ technicianId, phone, category } = {}, ack) => {
    const targetTechId = technicianId || socket.user?.id;
    if (targetTechId && !isAuthorizedToJoinRoom(socket, `tech_${targetTechId}`)) {
      const errPayload = { success: false, error: 'Forbidden: Cannot join another technician room' };
      socket.emit('auth_error', errPayload);
      if (typeof ack === 'function') ack(errPayload);
      return;
    }
    if (targetTechId) {
      socket.joinedTechnicianId = targetTechId;
      socket.join(`tech_${targetTechId}`);
    }
    if (phone && (!socket.user || String(socket.user.phone) === String(phone))) {
      socket.join(`tech_${phone}`);
    }
    if (category) {
      const normCat = category.toLowerCase().replace(/^category_/, '').replace(/^cat_/, '');
      socket.join(`category_${normCat}`);
    }
    if (typeof ack === 'function') ack({ success: true, room: `tech_${targetTechId}` });
    console.log(`👷 Technician ${targetTechId || phone} joined live dispatch room.`);
  });

  // Customer joins personal room
  socket.on('customer:join', ({ customerId } = {}, ack) => {
    const targetCustId = customerId || socket.user?.id;
    if (targetCustId && !isAuthorizedToJoinRoom(socket, `cust_${targetCustId}`)) {
      const errPayload = { success: false, error: 'Forbidden: Cannot join another customer room' };
      socket.emit('auth_error', errPayload);
      if (typeof ack === 'function') ack(errPayload);
      return;
    }
    if (targetCustId) socket.join(`cust_${targetCustId}`);
    if (typeof ack === 'function') ack({ success: true, room: `cust_${targetCustId}` });
    console.log(`👤 Customer ${targetCustId} joined tracking room.`);
  });

  // Join booking specific room for real-time tracking
  socket.on('job:join', ({ bookingId } = {}, ack) => {
    if (bookingId) {
      if (!isAuthorizedToJoinRoom(socket, `booking_${bookingId}`)) {
        const errPayload = { success: false, error: 'Forbidden: Not authorized for this booking room' };
        socket.emit('auth_error', errPayload);
        if (typeof ack === 'function') ack(errPayload);
        return;
      }
      socket.join(`booking_${bookingId}`);
      socket.join(`job_${bookingId}`);
      if (typeof ack === 'function') ack({ success: true, room: `booking_${bookingId}` });
      console.log(`📦 Client joined live booking tracking room: booking_${bookingId}`);
    }
  });

  const handleLocationStream = async ({ technicianId, category = 'electrician', longitude, latitude, speed, heading, bookingId } = {}) => {
    if (longitude !== undefined && latitude !== undefined) {
      const techId = socket.user?.role === 'TECHNICIAN' ? socket.user.id : (technicianId || socket.joinedTechnicianId || socket.handshake?.auth?.technicianId);
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

      // Persist & emit to authorized rooms via Automatic Dispatch Engine (Section 12 & 18)
      try {
        await automaticDispatchEngine.recordTechnicianLocationUpdate({
          technicianId: techId,
          latitude: parsedLat,
          longitude: parsedLng,
          speed: parsedSpeed,
          heading: parsedHeading,
          bookingId: bookingId || null,
        });
      } catch (_) {}

      let activeBookingId = bookingId || null;
      let customerId = null;
      try {
        const activeBooking = bookingsStore.findActiveBookingForTechnician?.(techId);
        if (activeBooking) {
          if (!activeBookingId) activeBookingId = activeBooking.id;
          customerId = activeBooking.customerId;
        }
      } catch (_) {}

      const locationPayload = {
        technicianId: techId,
        bookingId: activeBookingId,
        longitude: parsedLng,
        latitude: parsedLat,
        speed: parsedSpeed,
        heading: parsedHeading,
        timestamp: Date.now(),
      };

      // GPS PRIVACY: Scoped exclusively to active booking room, authorized customer, technician, and admin
      io.to(`tech_${techId}`).emit('technician:location:self', locationPayload);
      io.to('admin_dispatch').emit('technician:location:admin', locationPayload);

      if (activeBookingId) {
        io.to(`booking_${activeBookingId}`).emit('booking:partner:location', locationPayload);
        io.to(`booking_${activeBookingId}`).emit('job:partner_location', locationPayload);
        io.to(`booking_${activeBookingId}`).emit('telemetry', locationPayload);
      }
      if (customerId) {
        io.to(`cust_${customerId}`).emit('booking:partner:location', locationPayload);
        io.to(`cust_${customerId}`).emit('job:partner_location', locationPayload);
        io.to(`cust_${customerId}`).emit('telemetry', locationPayload);
      }
    }
  };

  socket.on('technician:location_sync', handleLocationStream);
  socket.on('technician:location:update', handleLocationStream);
  socket.on('technician:location', handleLocationStream);

  // Real-time Chat
  socket.on('chat:send', (msg) => {
    if (msg && msg.bookingId) {
      io.to(`booking_${msg.bookingId}`).emit('chat:message', msg);
      if (msg.receiverId) {
        io.to(`cust_${msg.receiverId}`).emit('chat:message', msg);
        io.to(`tech_${msg.receiverId}`).emit('chat:message', msg);
      }
    }
  });

  // Real-time Addon Response
  socket.on('addon:respond', (data) => {
    if (data && data.bookingId) {
      io.to(`booking_${data.bookingId}`).emit('job:addon_responded', data);
    }
  });

  // Real-time Proof of Work
  socket.on('proof:uploaded', (data) => {
    if (data && data.bookingId) {
      io.to(`booking_${data.bookingId}`).emit('booking:proof_uploaded', data);
    }
  });

  socket.on('disconnect', () => {
    const techId = socket.joinedTechnicianId || (socket.user?.role === 'TECHNICIAN' ? socket.user.id : null);
    if (techId) {
      const room = io.sockets.adapter.rooms.get(`tech_${techId}`);
      if (!room || room.size === 0) {
        automaticDispatchEngine.handleTechnicianOffline(techId, 'SOCKET_DISCONNECTED').catch(() => {});
      }
    }
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

  // Hydrate & Synchronize with Cloud Firestore (bookmytechnician-53d94)
  Promise.allSettled([
    bookingsStore.hydrateFromFirestore(),
    hydrateTechniciansFromFirestore(),
    firestoreSync.syncCatalogToFirestore(),
    automaticDispatchEngine.recoverActiveDispatchSessions(),
  ]).catch(() => {});

  server.listen(PORT, () => {
    console.log(`=======================================================`);
    console.log(`⚡ Node.js Core API Gateway listening on port ${PORT}`);
    console.log(`🌐 API Base URL: http://localhost:${PORT}/api/v1`);
    console.log(`📡 WebSocket Dispatch: ws://localhost:${PORT}`);
    console.log(`=======================================================`);
  });
};

if (require.main === module) {
  startServer();
}

module.exports = { app, server, io, startServer };


