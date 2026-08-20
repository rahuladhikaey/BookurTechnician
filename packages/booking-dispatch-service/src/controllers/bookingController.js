const crypto = require('crypto');
const Booking = require('../models/Booking');
const Technician = require('../models/Technician');
const { findNearbyTechnicians } = require('../services/redisGeoService');
const { sendEndServiceOtpEmail } = require('../services/emailService');

function generate4DigitOtp() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

// ─── 1. POST /api/bookings/create ───────────────────────────────────────────
async function createBooking(req, res) {
  try {
    const {
      customerId,
      customerEmail,
      customerName,
      customerPhone,
      customerAddress,
      latitude,
      longitude,
      serviceType,
    } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({ success: false, message: 'Valid GPS coordinates required' });
    }

    const bookingCode = 'BT-' + Date.now().toString().slice(-7);
    const startOtpCode = generate4DigitOtp();
    const startOtpExpiresAt = new Date(Date.now() + 3 * 60 * 60 * 1000); // 3-Hour Validity

    // Query Redis GEO for online technicians within 15 km
    const nearbyTechs = await findNearbyTechnicians(serviceType, longitude, latitude, 15);
    console.log(`Found ${nearbyTechs.length} technicians within 15km for ${serviceType}`);

    const booking = new Booking({
      bookingCode,
      customerId: customerId || 'guest_user',
      customerEmail,
      customerName,
      customerPhone,
      customerAddress,
      customerLocation: {
        type: 'Point',
        coordinates: [longitude, latitude],
      },
      serviceType,
      scheduledSlot: '1 Hour Window',
      status: 'PENDING',
      startOtp: {
        code: startOtpCode,
        expiresAt: startOtpExpiresAt,
        isVerified: false,
      },
    });

    await booking.save();

    // Emit Socket.io lead alert with 45-second countdown to target technicians
    const io = req.app.get('io');
    if (io) {
      const alertPayload = {
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
        serviceType: booking.serviceType,
        customerAddress: booking.customerAddress,
        customerLatitude: latitude,
        customerLongitude: longitude,
        payoutAmount: booking.payoutAmount,
        countdownSeconds: 45,
        scheduledSlot: '1 Hour Window',
      };

      if (nearbyTechs.length > 0) {
        nearbyTechs.forEach((t) => {
          io.to(`tech_${t.technicianId}`).emit('lead:new_request', {
            ...alertPayload,
            distanceKm: t.distanceKm,
          });
        });
      } else {
        // Broadcast to general category room
        io.to(`category_${serviceType.toLowerCase()}`).emit('lead:new_request', alertPayload);
      }
    }

    return res.status(201).json({
      success: true,
      message: 'Booking created with 3-hour Start OTP. Scanning for nearby partners.',
      data: booking,
    });
  } catch (err) {
    console.error('Create booking error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

// ─── 2. POST /api/bookings/accept ───────────────────────────────────────────
async function acceptBooking(req, res) {
  try {
    const { bookingId, technicianId } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    if (booking.status !== 'PENDING') {
      return res.status(400).json({ success: false, message: 'Booking is already accepted or cancelled' });
    }

    const technician = await Technician.findById(technicianId);
    if (!technician) {
      return res.status(404).json({ success: false, message: 'Technician profile not found' });
    }

    booking.technicianId = technicianId;
    booking.status = 'ACCEPTED';
    await booking.save();

    technician.activeBookingId = booking._id;
    await technician.save();

    // Notify customer via Socket.io
    const io = req.app.get('io');
    if (io) {
      io.to(`cust_${booking.customerId}`).emit('booking:accepted', {
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
        status: 'ACCEPTED',
        technicianName: technician.name,
        technicianPhone: technician.phone,
        technicianRating: technician.rating,
        technicianLatitude: technician.currentCoords.coordinates[1],
        technicianLongitude: technician.currentCoords.coordinates[0],
        customerLatitude: booking.customerLocation.coordinates[1],
        customerLongitude: booking.customerLocation.coordinates[0],
        distanceKm: booking.distanceKm,
        startOtp: booking.startOtp.code,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Booking accepted successfully',
      data: booking,
    });
  } catch (err) {
    console.error('Accept booking error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

// ─── 3. POST /api/bookings/verify-start-otp ────────────────────────────────
async function verifyStartOtp(req, res) {
  try {
    const { bookingId, startOtp } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    // Check 3-hour expiry
    if (new Date() > new Date(booking.startOtp.expiresAt)) {
      return res.status(400).json({
        success: false,
        message: 'Start Service OTP has expired (validity was 3 hours). Please contact support.',
      });
    }

    if (booking.startOtp.code !== startOtp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Start Service OTP. Please check customer screen.',
      });
    }

    const endOtpCode = generate4DigitOtp();
    const endOtpExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 Hours

    booking.startOtp.isVerified = true;
    booking.startOtp.verifiedAt = new Date();
    booking.status = 'IN_PROGRESS';
    booking.endOtp = {
      code: endOtpCode,
      expiresAt: endOtpExpiresAt,
      isVerified: false,
    };
    booking.failedAttempts = 0;

    await booking.save();

    // Dispatch styled HTML email to customer
    if (booking.customerEmail) {
      await sendEndServiceOtpEmail(
        booking.customerEmail,
        booking.customerName,
        booking.bookingCode,
        endOtpCode
      );
    }

    // Notify customer via Socket.io
    const io = req.app.get('io');
    if (io) {
      io.to(`cust_${booking.customerId}`).emit('booking:in_progress', {
        bookingId: booking._id,
        status: 'IN_PROGRESS',
        message: 'Service is now in progress. 24-Hour Completion OTP sent to your email.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Service initiated. 24-Hour Completion OTP dispatched to customer email.',
      data: booking,
    });
  } catch (err) {
    console.error('Verify start OTP error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

// ─── 4. POST /api/bookings/resend-end-email ────────────────────────────────
async function resendEndEmail(req, res) {
  try {
    const { bookingId } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    if (booking.status !== 'IN_PROGRESS' || !booking.endOtp?.code) {
      return res.status(400).json({
        success: false,
        message: 'Completion OTP email can only be resent when service is IN_PROGRESS.',
      });
    }

    await sendEndServiceOtpEmail(
      booking.customerEmail,
      booking.customerName,
      booking.bookingCode,
      booking.endOtp.code
    );

    return res.status(200).json({
      success: true,
      message: 'Completion OTP email has been resent to your registered inbox.',
    });
  } catch (err) {
    console.error('Resend email error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

// ─── 5. POST /api/bookings/verify-end-otp ──────────────────────────────────
async function verifyEndOtp(req, res) {
  try {
    const { bookingId, endOtp } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    if (booking.failedAttempts >= 3) {
      return res.status(403).json({
        success: false,
        message: 'Maximum OTP verification attempts exceeded (3 failed attempts). Account temporarily locked.',
      });
    }

    if (new Date() > new Date(booking.endOtp.expiresAt)) {
      return res.status(400).json({
        success: false,
        message: 'End Service OTP has expired (validity was 24 hours). Please request an email resend.',
      });
    }

    if (booking.endOtp.code !== endOtp.trim()) {
      booking.failedAttempts += 1;
      await booking.save();
      const remaining = 3 - booking.failedAttempts;
      return res.status(400).json({
        success: false,
        message: `Invalid Completion OTP. Remaining attempts: ${remaining > 0 ? remaining : 0}`,
      });
    }

    booking.endOtp.isVerified = true;
    booking.endOtp.verifiedAt = new Date();
    booking.status = 'COMPLETED';
    await booking.save();

    // Release technician active booking
    if (booking.technicianId) {
      await Technician.findByIdAndUpdate(booking.technicianId, { activeBookingId: null });
    }

    // Notify customer & technician via Socket.io
    const io = req.app.get('io');
    if (io) {
      io.to(`cust_${booking.customerId}`).emit('booking:completed', {
        bookingId: booking._id,
        status: 'COMPLETED',
        message: 'Service completed successfully! Thank you for using BookurTechnician.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Service successfully verified and completed. Payout unlocked.',
      data: booking,
    });
  } catch (err) {
    console.error('Verify end OTP error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  createBooking,
  acceptBooking,
  verifyStartOtp,
  resendEndEmail,
  verifyEndOtp,
};
