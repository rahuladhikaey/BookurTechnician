import express, { Request, Response } from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { connectDB } from './config/db';
import bookingRoutes from './routes/bookingRoutes';
import spotlightRoutes from './routes/spotlightRoutes';
import heroRoutes from './routes/heroRoutes';
import legalRoutes from './routes/legalRoutes';
import technicianBannerRoutes from './routes/technicianBannerRoutes';
import technicianIdRoutes, { renderPublicVerificationHtml } from './routes/technicianIdRoutes';
import { configureSockets } from './sockets/telemetrySocket';
import { TechnicianProfile } from './models/TechnicianProfile';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(express.json());

// Enable custom CORS headers for HTTP requests
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.header('Access-Control-Allow-Methods', 'PUT, POST, PATCH, DELETE, GET');
    return res.status(200).json({});
  }
  next();
});

// Routes
app.use('/', legalRoutes);
app.use('/api', technicianBannerRoutes);
app.use('/api/technicians', technicianIdRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api', spotlightRoutes);
app.use('/api', heroRoutes);

// Public Standalone QR Verification Webpage
app.get('/verify-tech/:token', async (req: Request, res: Response) => {
  try {
    const { token } = req.params;
    const profile = await TechnicianProfile.findOne({ qr_verification_token: token });
    const html = renderPublicVerificationHtml(token, profile);
    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  } catch (error) {
    res.status(500).send('<h1>Verification Error</h1>');
  }
});

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', service: 'hyperlocal-telemetry-backend' });
});

// Connect to DB and start
const PORT = process.env.PORT || 3000;
connectDB().then(async () => {
  configureSockets(io);

  httpServer.listen(PORT, () => {
    console.log(`Hyperlocal Dispatch Server running on port ${PORT}`);
  });
});
