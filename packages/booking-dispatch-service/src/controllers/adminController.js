const mongoose = require('mongoose');
const Booking = require('../models/Booking');
const Technician = require('../models/Technician');
const PayoutTransaction = require('../models/PayoutTransaction');
const AuditLog = require('../models/AuditLog');

/**
 * 1. LIVE BOOKING RADAR & PIPELINE MONITORING
 * GET /api/admin/bookings/live
 */
exports.getLiveBookings = async (req, res) => {
  try {
    const { status, category, search, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const query = {};
    if (status && status !== 'ALL') {
      query.status = status.toUpperCase();
    }
    if (category && category !== 'ALL') {
      query.serviceType = { $regex: new RegExp(category, 'i') };
    }
    if (search) {
      query.$or = [
        { bookingCode: { $regex: search, $options: 'i' } },
        { customerName: { $regex: search, $options: 'i' } },
        { customerPhone: { $regex: search, $options: 'i' } },
        { customerEmail: { $regex: search, $options: 'i' } },
        { serviceType: { $regex: search, $options: 'i' } },
      ];
    }

    const [bookings, totalCount, stageCounts] = await Promise.all([
      Booking.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      Booking.countDocuments(query),
      Booking.aggregate([
        {
          $group: {
            _id: '$status',
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    // Populate technician details
    const techIds = bookings.map((b) => b.technicianId).filter(Boolean);
    const technicians = await Technician.find({ _id: { $in: techIds } }).lean();
    const techMap = {};
    technicians.forEach((t) => {
      techMap[t._id.toString()] = t;
      techMap[t.technicianCode] = t;
    });

    const populatedBookings = bookings.map((b) => ({
      ...b,
      technician: b.technicianId ? (techMap[b.technicianId] || null) : null,
    }));

    // Convert aggregate stages to structured map
    const summary = {
      PENDING: 0,
      ACCEPTED: 0,
      ARRIVED: 0,
      IN_PROGRESS: 0,
      COMPLETED: 0,
      CANCELLED: 0,
      TOTAL: 0,
    };

    stageCounts.forEach((sc) => {
      if (summary[sc._id] !== undefined) {
        summary[sc._id] = sc.count;
      }
      summary.TOTAL += sc.count;
    });

    res.json({
      success: true,
      summary,
      total: totalCount,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(totalCount / parseInt(limit)),
      bookings: populatedBookings,
    });
  } catch (error) {
    console.error('Error fetching live bookings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 2. GET NEARBY ACTIVE TECHNICIANS WITHIN 15 KM
 * GET /api/admin/bookings/:bookingId/nearby-technicians
 */
exports.getNearbyActiveTechnicians = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    const [longitude, latitude] = booking.customerLocation.coordinates;

    // Search 15 km (15,000 meters)
    const technicians = await Technician.find({
      isOnline: true,
      kycStatus: { $ne: 'SUSPENDED' },
      currentCoords: {
        $nearSphere: {
          $geometry: {
            type: 'Point',
            coordinates: [longitude, latitude],
          },
          $maxDistance: 15000, // 15 km
        },
      },
    }).limit(20).lean();

    // Compute approximate distance for display
    const techniciansWithDistance = technicians.map((tech) => {
      const [techLng, techLat] = tech.currentCoords.coordinates;
      const dLat = (techLat - latitude) * (Math.PI / 180);
      const dLng = (techLng - longitude) * (Math.PI / 180);
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(latitude * (Math.PI / 180)) *
          Math.cos(techLat * (Math.PI / 180)) *
          Math.sin(dLng / 2) *
          Math.sin(dLng / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      const distanceKm = Math.round(6371 * c * 10) / 10;

      return {
        ...tech,
        distanceKm,
        isCurrentlyBusy: !!tech.activeBookingId,
      };
    });

    res.json({
      success: true,
      bookingId: booking._id,
      bookingCode: booking.bookingCode,
      customerAddress: booking.customerAddress,
      serviceType: booking.serviceType,
      technicians: techniciansWithDistance,
    });
  } catch (error) {
    console.error('Error finding nearby technicians:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 3. MANUAL DISPATCH OVERRIDE (FORCE-ASSIGN)
 * POST /api/admin/bookings/:bookingId/force-assign
 */
exports.forceAssignTechnician = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { bookingId } = req.params;
    const { technicianId, reason } = req.body;
    const admin = req.admin || { email: 'admin@bookurtechnician.com', role: 'SUPER_ADMIN', id: 'admin-001' };

    if (!technicianId) {
      await session.abortTransaction();
      return res.status(400).json({ success: false, message: 'Technician ID is strictly required for force assignment.' });
    }

    const [booking, technician] = await Promise.all([
      Booking.findById(bookingId).session(session),
      Technician.findById(technicianId).session(session),
    ]);

    if (!booking) {
      await session.abortTransaction();
      return res.status(404).json({ success: false, message: 'Booking not found.' });
    }

    if (!technician) {
      await session.abortTransaction();
      return res.status(404).json({ success: false, message: 'Target technician not found.' });
    }

    if (technician.kycStatus === 'SUSPENDED') {
      await session.abortTransaction();
      return res.status(400).json({ success: false, message: 'Cannot assign job to a suspended technician.' });
    }

    const previousStatus = booking.status;
    const previousTechId = booking.technicianId;

    // Apply Force Assign updates
    booking.technicianId = technician._id.toString();
    booking.status = 'ACCEPTED';
    booking.isForceAssigned = true;
    booking.forceAssignedBy = `${admin.name || admin.email} (${admin.role})`;
    booking.forceAssignedAt = new Date();
    await booking.save({ session });

    // Link booking to technician
    technician.activeBookingId = booking._id.toString();
    await technician.save({ session });

    // Record Immutable Audit Log
    const auditLog = new AuditLog({
      action: 'FORCE_ASSIGN_DISPATCH',
      targetType: 'BOOKING',
      targetId: booking._id.toString(),
      targetCode: booking.bookingCode,
      performedBy: {
        userId: admin.id,
        email: admin.email,
        role: admin.role,
        name: admin.name,
      },
      reason: reason || 'Manual dispatcher force-assign override triggered from Admin Control Tower',
      metadata: {
        previousStatus,
        previousTechId,
        assignedTechnicianId: technician._id.toString(),
        assignedTechnicianCode: technician.technicianCode,
        technicianName: technician.name,
      },
    });
    await auditLog.save({ session });

    await session.commitTransaction();

    // Broadcast High-Priority WebSocket & Alert Event
    if (global.io) {
      global.io.emit('job:force_assigned', {
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
        technicianId: technician._id,
        technicianCode: technician.technicianCode,
        technicianName: technician.name,
        serviceType: booking.serviceType,
        customerAddress: booking.customerAddress,
        status: 'ACCEPTED',
        isForceAssigned: true,
      });

      // Target specific room for technician
      global.io.to(`tech_${technician._id}`).emit('job:new_proposal', {
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
        serviceType: booking.serviceType,
        customerAddress: booking.customerAddress,
        payoutAmount: booking.payoutAmount,
        isForceAssigned: true,
        message: '⚡ High Priority Job Force-Assigned by Operations Control Tower',
      });
    }

    res.json({
      success: true,
      message: `Booking ${booking.bookingCode} successfully force-assigned to ${technician.name} (${technician.technicianCode}).`,
      booking,
      technician: {
        id: technician._id,
        name: technician.name,
        phone: technician.phone,
        code: technician.technicianCode,
      },
    });
  } catch (error) {
    await session.abortTransaction();
    console.error('Error during force assignment:', error);
    res.status(500).json({ success: false, message: error.message });
  } finally {
    session.endSession();
  }
};

/**
 * 4. FINANCIAL LEDGER & WALLET PAYOUT DISBURSEMENT (ATOMIC MONGODB TRANSACTION)
 * POST /api/admin/payouts/release
 */
exports.releasePayout = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { technicianId, amount, paymentMethod = 'UPI', utrReference, destinationUpi, notes } = req.body;
    const admin = req.admin || { email: 'admin@bookurtechnician.com', role: 'SUPER_ADMIN', id: 'admin-001' };

    if (!technicianId || !amount || !utrReference) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: 'Technician ID, Amount, and Bank UTR Reference are strictly mandatory.',
      });
    }

    const payoutAmt = parseFloat(amount);
    if (isNaN(payoutAmt) || payoutAmt <= 0) {
      await session.abortTransaction();
      return res.status(400).json({ success: false, message: 'Invalid payout disbursement amount.' });
    }

    // 1. Strict UTR Idempotency Check
    const existingUtr = await PayoutTransaction.findOne({ utrReference: utrReference.trim() }).session(session);
    if (existingUtr) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: `Duplicate UTR Reference! Payout ${existingUtr.payoutCode} has already been settled with UTR ${utrReference}.`,
      });
    }

    // 2. Technician Wallet Verification
    const technician = await Technician.findById(technicianId).session(session);
    if (!technician) {
      await session.abortTransaction();
      return res.status(404).json({ success: false, message: 'Technician profile not found.' });
    }

    if (technician.walletBalance < payoutAmt) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: `Insufficient wallet balance. Available balance: ₹${technician.walletBalance}, Requested payout: ₹${payoutAmt}`,
      });
    }

    // 3. Atomically Deduct Balance & Increment Withdrawn Total
    technician.walletBalance = Math.max(0, technician.walletBalance - payoutAmt);
    technician.totalWithdrawn = (technician.totalWithdrawn || 0) + payoutAmt;
    if (technician.pendingPayouts > 0) {
      technician.pendingPayouts = Math.max(0, technician.pendingPayouts - payoutAmt);
    }
    await technician.save({ session });

    // 4. Save Immutable Financial Payout Ledger Record
    const payoutRecord = new PayoutTransaction({
      technicianId: technician._id.toString(),
      technicianName: technician.name,
      technicianPhone: technician.phone,
      amount: payoutAmt,
      paymentMethod,
      utrReference: utrReference.trim(),
      destinationUpi: destinationUpi || technician.upiId || 'Direct Settlement',
      status: 'PROCESSED',
      processedBy: {
        adminId: admin.id,
        adminEmail: admin.email,
        adminRole: admin.role,
      },
      disbursedAt: new Date(),
      notes: notes || 'Admin wallet payout settled with bank reference',
    });
    await payoutRecord.save({ session });

    // 5. Save Audit Log
    const auditLog = new AuditLog({
      action: 'WALLET_PAYOUT_RELEASE',
      targetType: 'PAYOUT',
      targetId: payoutRecord._id.toString(),
      targetCode: payoutRecord.payoutCode,
      performedBy: {
        userId: admin.id,
        email: admin.email,
        role: admin.role,
        name: admin.name,
      },
      reason: `Payout of ₹${payoutAmt} successfully released via ${paymentMethod} (UTR: ${utrReference})`,
      metadata: {
        technicianId: technician._id.toString(),
        technicianCode: technician.technicianCode,
        amount: payoutAmt,
        remainingBalance: technician.walletBalance,
        utrReference: utrReference.trim(),
      },
    });
    await auditLog.save({ session });

    await session.commitTransaction();

    // Broadcast WebSocket event
    if (global.io) {
      global.io.emit('wallet:payout_released', {
        technicianId: technician._id,
        technicianCode: technician.technicianCode,
        amount: payoutAmt,
        payoutCode: payoutRecord.payoutCode,
        utrReference: payoutRecord.utrReference,
        newBalance: technician.walletBalance,
      });
    }

    res.json({
      success: true,
      message: `Payout of ₹${payoutAmt} disbursed successfully. Ledger Code: ${payoutRecord.payoutCode}`,
      payout: payoutRecord,
      updatedBalance: technician.walletBalance,
    });
  } catch (error) {
    await session.abortTransaction();
    console.error('Error releasing payout:', error);
    res.status(500).json({ success: false, message: error.message });
  } finally {
    session.endSession();
  }
};

/**
 * 5. GET PAYOUT TRANSACTION HISTORY
 * GET /api/admin/payouts/history/:technicianId?
 */
exports.getPayoutHistory = async (req, res) => {
  try {
    const { technicianId } = req.params;
    const { page = 1, limit = 50 } = req.query;

    const query = {};
    if (technicianId && technicianId !== 'all') {
      query.technicianId = technicianId;
    }

    const [transactions, total, aggregateStats] = await Promise.all([
      PayoutTransaction.find(query)
        .sort({ disbursedAt: -1 })
        .skip((parseInt(page) - 1) * parseInt(limit))
        .limit(parseInt(limit))
        .lean(),
      PayoutTransaction.countDocuments(query),
      PayoutTransaction.aggregate([
        {
          $group: {
            _id: null,
            totalDisbursed: { $sum: '$amount' },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    res.json({
      success: true,
      total,
      totalDisbursedAmount: aggregateStats[0]?.totalDisbursed || 0,
      page: parseInt(page),
      limit: parseInt(limit),
      transactions,
    });
  } catch (error) {
    console.error('Error fetching payout history:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 6. PARTNER GOVERNANCE & KYC VERIFICATION
 * PATCH /api/admin/partners/:partnerId/status
 */
exports.updatePartnerStatus = async (req, res) => {
  try {
    const { partnerId } = req.params;
    const { kycStatus, rejectionReason, suspensionReason } = req.body;
    const admin = req.admin || { email: 'admin@bookurtechnician.com', role: 'SUPER_ADMIN', id: 'admin-001' };

    if (!['PENDING_APPROVAL', 'ACTIVE', 'SUSPENDED', 'REJECTED'].includes(kycStatus)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Allowed values: PENDING_APPROVAL, ACTIVE, SUSPENDED, REJECTED',
      });
    }

    const technician = await Technician.findById(partnerId);
    if (!technician) {
      return res.status(404).json({ success: false, message: 'Technician not found.' });
    }

    const previousStatus = technician.kycStatus;
    technician.kycStatus = kycStatus;

    if (kycStatus === 'ACTIVE') {
      technician.kycDocuments = {
        ...(technician.kycDocuments || {}),
        reviewedAt: new Date(),
        reviewedBy: admin.email,
        rejectionReason: null,
      };
      technician.suspensionReason = null;
    } else if (kycStatus === 'REJECTED') {
      technician.kycDocuments = {
        ...(technician.kycDocuments || {}),
        rejectionReason: rejectionReason || 'KYC Documents failed verification standard.',
        reviewedAt: new Date(),
        reviewedBy: admin.email,
      };
      technician.isOnline = false;
    } else if (kycStatus === 'SUSPENDED') {
      technician.suspensionReason = suspensionReason || 'Account suspended for platform compliance violations.';
      technician.suspendedAt = new Date();
      technician.isOnline = false;
    }

    await technician.save();

    // Record Audit Log
    const auditLog = new AuditLog({
      action: kycStatus === 'ACTIVE' ? 'KYC_APPROVE' : kycStatus === 'REJECTED' ? 'KYC_REJECT' : 'PARTNER_STATUS_SUSPEND',
      targetType: 'TECHNICIAN',
      targetId: technician._id.toString(),
      targetCode: technician.technicianCode,
      performedBy: {
        userId: admin.id,
        email: admin.email,
        role: admin.role,
        name: admin.name,
      },
      reason: rejectionReason || suspensionReason || `Partner KYC status transitioned to ${kycStatus}`,
      metadata: {
        previousStatus,
        newStatus: kycStatus,
        technicianName: technician.name,
      },
    });
    await auditLog.save();

    res.json({
      success: true,
      message: `Partner ${technician.name} status updated to ${kycStatus}`,
      technician,
    });
  } catch (error) {
    console.error('Error updating partner status:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 7. DISPUTE RESOLUTION & EMERGENCY OTP BYPASS
 * POST /api/admin/bookings/:bookingId/bypass-otp
 */
exports.bypassOtp = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { otpType, reason } = req.body; // otpType: 'START' | 'END'
    const admin = req.admin || { email: 'admin@bookurtechnician.com', role: 'SUPER_ADMIN', id: 'admin-001' };

    if (!['START', 'END'].includes(otpType)) {
      return res.status(400).json({
        success: false,
        message: "Invalid otpType. Must be 'START' (3-Hour Start OTP) or 'END' (24-Hour Completion OTP).",
      });
    }

    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({
        success: false,
        message: 'A clear dispute justification reason (min 5 characters) is strictly mandatory for OTP bypass.',
      });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found.' });
    }

    const auditAction = otpType === 'START' ? 'START_OTP_BYPASS' : 'END_OTP_BYPASS';

    if (otpType === 'START') {
      if (booking.status !== 'ARRIVED' && booking.status !== 'ACCEPTED') {
        return res.status(400).json({
          success: false,
          message: `Cannot bypass Start OTP when booking status is ${booking.status}. Status must be ARRIVED or ACCEPTED.`,
        });
      }

      booking.startOtp.isVerified = true;
      booking.startOtp.verifiedAt = new Date();
      booking.status = 'IN_PROGRESS';
      booking.otpBypassed.startOtpBypassed = true;
      booking.otpBypassed.bypassedBy = `${admin.name || admin.email} (${admin.role})`;
      booking.otpBypassed.bypassedAt = new Date();
      booking.otpBypassed.reason = reason;

      // Generate End OTP for completion stage
      if (!booking.endOtp || !booking.endOtp.code) {
        booking.endOtp = {
          code: String(Math.floor(1000 + Math.random() * 9000)),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 Hours
          isVerified: false,
        };
      }
    } else if (otpType === 'END') {
      if (booking.status !== 'IN_PROGRESS') {
        return res.status(400).json({
          success: false,
          message: `Cannot bypass End Completion OTP when booking status is ${booking.status}. Status must be IN_PROGRESS.`,
        });
      }

      booking.endOtp.isVerified = true;
      booking.endOtp.verifiedAt = new Date();
      booking.status = 'COMPLETED';
      booking.otpBypassed.endOtpBypassed = true;
      booking.otpBypassed.bypassedBy = `${admin.name || admin.email} (${admin.role})`;
      booking.otpBypassed.bypassedAt = new Date();
      booking.otpBypassed.reason = reason;

      // Credit technician wallet balance upon emergency completion
      if (booking.technicianId) {
        const technician = await Technician.findById(booking.technicianId);
        if (technician) {
          technician.walletBalance = (technician.walletBalance || 0) + (booking.payoutAmount || 450);
          technician.activeBookingId = null;
          await technician.save();
        }
      }
    }

    await booking.save();

    // Record Immutable Audit Log
    const auditLog = new AuditLog({
      action: auditAction,
      targetType: 'BOOKING',
      targetId: booking._id.toString(),
      targetCode: booking.bookingCode,
      performedBy: {
        userId: admin.id,
        email: admin.email,
        role: admin.role,
        name: admin.name,
      },
      reason: reason,
      metadata: {
        otpType,
        bookingCode: booking.bookingCode,
        newStatus: booking.status,
        customerName: booking.customerName,
      },
    });
    await auditLog.save();

    // Broadcast Real-time Status Update
    if (global.io) {
      global.io.emit('booking:status_updated', {
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
        status: booking.status,
        isBypassed: true,
        bypassedType: otpType,
      });
    }

    res.json({
      success: true,
      message: `Successfully bypassed ${otpType} OTP for booking ${booking.bookingCode}. Booking status updated to ${booking.status}.`,
      booking,
    });
  } catch (error) {
    console.error('Error bypassing OTP:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 8. GET ADMIN OVERVIEW DASHBOARD METRICS
 * GET /api/admin/stats/overview
 */
exports.getAdminOverviewStats = async (req, res) => {
  try {
    const [
      totalBookings,
      activeJobs,
      completedJobs,
      cancelledJobs,
      totalTechnicians,
      onlineTechnicians,
      pendingKycCount,
      payoutAggregates,
      revenueAggregates,
    ] = await Promise.all([
      Booking.countDocuments(),
      Booking.countDocuments({ status: { $in: ['PENDING', 'ACCEPTED', 'ARRIVED', 'IN_PROGRESS'] } }),
      Booking.countDocuments({ status: 'COMPLETED' }),
      Booking.countDocuments({ status: 'CANCELLED' }),
      Technician.countDocuments(),
      Technician.countDocuments({ isOnline: true }),
      Technician.countDocuments({ kycStatus: 'PENDING_APPROVAL' }),
      PayoutTransaction.aggregate([
        { $group: { _id: null, totalDisbursed: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
      Booking.aggregate([
        { $match: { status: 'COMPLETED' } },
        { $group: { _id: null, grossGmv: { $sum: '$payoutAmount' } } },
      ]),
    ]);

    const grossGmv = revenueAggregates[0]?.grossGmv ? revenueAggregates[0].grossGmv / 0.9 : 0;
    const platformCommission = grossGmv * 0.1;

    res.json({
      success: true,
      stats: {
        totalBookings,
        activeJobs,
        completedJobs,
        cancelledJobs,
        totalTechnicians,
        onlineTechnicians,
        pendingKycCount,
        totalDisbursedPayouts: payoutAggregates[0]?.totalDisbursed || 0,
        grossGmv: Math.round(grossGmv),
        platformCommission: Math.round(platformCommission),
      },
    });
  } catch (error) {
    console.error('Error getting admin stats:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};
