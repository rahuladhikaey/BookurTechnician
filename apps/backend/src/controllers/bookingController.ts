import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { Partner } from '../models/Partner';
import { Booking } from '../models/Booking';

export const dispatchBooking = async (req: Request, res: Response) => {
  try {
    const { longitude, latitude } = req.body;

    if (longitude === undefined || latitude === undefined) {
      return res.status(400).json({ error: 'Latitude and Longitude are required coordinates.' });
    }

    // Query partners within 5000 meters of customer GeoJSON point
    const partners = await Partner.find({
      isOnline: true,
      location: {
        $nearSphere: {
          $geometry: {
            type: 'Point',
            coordinates: [Number(longitude), Number(latitude)] // [longitude, latitude]
          },
          $maxDistance: 5000 // 5km radius
        }
      }
    });

    return res.status(200).json({
      success: true,
      count: partners.length,
      partners
    });
  } catch (error: any) {
    console.error('Dispatch Query Error:', error);
    return res.status(500).json({ error: error.message || 'Internal server error during dispatch query.' });
  }
};

export const createBooking = async (req: Request, res: Response) => {
  try {
    const { customerName, customerPhone, serviceTitle, price, longitude, latitude } = req.body;

    if (!customerName || !customerPhone || !serviceTitle || !price || longitude === undefined || latitude === undefined) {
      return res.status(400).json({ error: 'Missing required booking creation fields.' });
    }

    // Generate random 4-digit codes
    const startRaw = Math.floor(1000 + Math.random() * 9000).toString();
    const endRaw = Math.floor(1000 + Math.random() * 9000).toString();

    // Hash codes for secure database storage
    const startOtp = bcrypt.hashSync(startRaw, 8);
    const endOtp = bcrypt.hashSync(endRaw, 8);

    const booking = new Booking({
      customerName,
      customerPhone,
      serviceTitle,
      price: Number(price),
      status: 'ASSIGNED',
      customerLocation: {
        type: 'Point',
        coordinates: [Number(longitude), Number(latitude)]
      },
      startOtp,
      endOtp
    });

    await booking.save();

    // Respond with created booking AND the raw OTPs so customer app can display them
    return res.status(201).json({
      success: true,
      booking: {
        id: booking._id,
        customerName: booking.customerName,
        customerPhone: booking.customerPhone,
        serviceTitle: booking.serviceTitle,
        price: booking.price,
        status: booking.status,
        customerLocation: booking.customerLocation,
        createdAt: booking.createdAt
      },
      rawStartOtp: startRaw, // Share raw start OTP once to customer device
      rawEndOtp: endRaw     // Share raw end OTP once to customer device
    });
  } catch (error: any) {
    console.error('Booking Creation Error:', error);
    return res.status(500).json({ error: error.message || 'Internal server error creating booking.' });
  }
};

export const verifyStartOtp = async (req: Request, res: Response) => {
  try {
    const { bookingId, otp } = req.body;

    if (!bookingId || !otp) {
      return res.status(400).json({ error: 'bookingId and otp are required.' });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const isMatch = bcrypt.compareSync(otp, booking.startOtp);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Invalid verification OTP.' });
    }

    booking.status = 'IN_PROGRESS';
    await booking.save();

    return res.status(200).json({
      success: true,
      status: booking.status,
      message: 'Start OTP Verified. Work in progress.'
    });
  } catch (error: any) {
    console.error('OTP Start Verify Error:', error);
    return res.status(500).json({ error: error.message || 'Internal server error verifying OTP.' });
  }
};

export const verifyEndOtp = async (req: Request, res: Response) => {
  try {
    const { bookingId, otp } = req.body;

    if (!bookingId || !otp) {
      return res.status(400).json({ error: 'bookingId and otp are required.' });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const isMatch = bcrypt.compareSync(otp, booking.endOtp);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Invalid End-OTP code.' });
    }

    booking.status = 'COMPLETED';
    await booking.save();

    // Generate invoice breakdown
    const basePrice = booking.price;
    const visitFee = 99.0;
    const subtotal = basePrice + visitFee;
    const gstTax = subtotal * 0.18;
    const grandTotal = subtotal + gstTax;

    return res.status(200).json({
      success: true,
      status: booking.status,
      message: 'End OTP Verified. Booking completed.',
      invoice: {
        basePrice,
        visitFee,
        gstTax,
        grandTotal,
        currency: 'INR'
      }
    });
  } catch (error: any) {
    console.error('OTP End Verify Error:', error);
    return res.status(500).json({ error: error.message || 'Internal server error.' });
  }
};
