import { Server, Socket } from 'socket.io';
import { Partner } from '../models/Partner';
import { Booking } from '../models/Booking';

export const configureSockets = (io: Server) => {
  io.on('connection', (socket: Socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Join room for specific booking
    socket.on('job:join', (data: { bookingId: string }) => {
      if (data && data.bookingId) {
        socket.join(data.bookingId);
        console.log(`Socket ${socket.id} joined booking room: ${data.bookingId}`);
      }
    });

    // Partner updates location telemetry
    socket.on('partner:location_update', async (data: {
      partnerId: string;
      bookingId?: string;
      latitude: number;
      longitude: number;
    }) => {
      try {
        const { partnerId, bookingId, latitude, longitude } = data;
        if (!partnerId || latitude === undefined || longitude === undefined) return;

        // Update database location
        await Partner.findByIdAndUpdate(partnerId, {
          location: {
            type: 'Point',
            coordinates: [longitude, latitude] // [longitude, latitude]
          }
        });

        // If active booking, stream location updates to customer
        if (bookingId) {
          await Booking.findByIdAndUpdate(bookingId, {
            partnerLocation: {
              type: 'Point',
              coordinates: [longitude, latitude]
            }
          });

          io.to(bookingId).emit('job:partner_location', {
            bookingId,
            partnerId,
            latitude,
            longitude
          });
        }
      } catch (error) {
        console.error('Socket Partner Location Update Error:', error);
      }
    });

    // Broadcast job status change events
    socket.on('job:status_change', async (data: {
      bookingId: string;
      status: string;
    }) => {
      try {
        const { bookingId, status } = data;
        if (!bookingId || !status) return;

        await Booking.findByIdAndUpdate(bookingId, { status: status as any });

        // Broadcast to customer app
        io.to(bookingId).emit('job:status_update', {
          bookingId,
          status
        });
        console.log(`Broadcast status_update for ${bookingId} to ${status}`);
      } catch (error) {
        console.error('Socket Status Change Error:', error);
      }
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });
  });
};
