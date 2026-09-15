const { v4: uuidv4 } = require('uuid');
const postgres = require('../config/postgres');
const bookingsStore = require('../config/bookingsStore');

/**
 * GET /api/v1/customer/profile
 */
const getProfile = async (req, res) => {
  try {
    const userId = req.user?.id || req.query.userId || req.headers['x-user-id'];
    
    let userObj = null;
    let addressesList = [];

    if (userId && postgres.isPgHealthy()) {
      try {
        const uRes = await postgres.query(
          'SELECT id, phone, email, full_name as "fullName", role, created_at as "createdAt" FROM users WHERE id = $1',
          [userId]
        );
        if (uRes.rows.length > 0) {
          userObj = uRes.rows[0];
        }

        const aRes = await postgres.query(
          `SELECT id, user_id as "customerId", address_type as "addressType", house_flat as "houseFlat", 
                  street, landmark, area, city, state, postal_code as "postalCode", latitude, longitude, is_primary as "isPrimary" 
           FROM customer_addresses WHERE user_id = $1 ORDER BY is_primary DESC, created_at DESC`,
          [userId]
        );
        addressesList = aRes.rows || [];
      } catch (dbErr) {
        console.warn('⚠️ [CustomerController] Profile PG warning:', dbErr.message);
      }
    }

    // Fallback to bookingsStore if PG not available or user missing
    if (!userObj && userId) {
      const storeCust = bookingsStore.getAllCustomers().find(c => c.id === userId || c.customerId === userId);
      if (storeCust) {
        userObj = {
          id: storeCust.id,
          fullName: storeCust.fullName || storeCust.name,
          phone: storeCust.phone,
          email: storeCust.email,
        };
      }
    }

    if (!userObj) {
      return res.status(404).json({ success: false, error: 'Customer profile not found' });
    }

    const primaryAddress = addressesList.find(a => a.isPrimary) || addressesList[0] || null;

    return res.json({
      success: true,
      data: {
        user: userObj,
        profile: {
          customerId: userObj.id,
          userId: userObj.id,
          fullName: userObj.fullName,
          phone: userObj.phone,
          email: userObj.email || `${userObj.phone || userObj.id}@user.bookurtechnician.com`,
          isPhoneVerified: true,
          isEmailVerified: true,
          addresses: addressesList,
          primaryAddress,
        }
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * PUT /api/v1/customer/profile
 */
const updateProfile = async (req, res) => {
  try {
    const userId = req.user?.id || req.body.userId || req.body.customerId || req.headers['x-user-id'];
    const { fullName, email, phone } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }

    let updatedUser = null;

    if (postgres.isPgHealthy()) {
      try {
        const uRes = await postgres.query(
          `UPDATE users 
           SET full_name = COALESCE(NULLIF($1, ''), full_name),
               email = COALESCE(NULLIF($2, ''), email),
               phone = COALESCE(NULLIF($3, ''), phone)
           WHERE id = $4
           RETURNING id, full_name as "fullName", phone, email`,
          [fullName ? fullName.trim() : null, email ? email.trim() : null, phone ? phone.trim() : null, userId]
        );

        if (uRes.rows.length > 0) {
          updatedUser = uRes.rows[0];
        }
      } catch (dbErr) {
        console.warn('⚠️ [CustomerController] Update Profile PG warning:', dbErr.message);
      }
    }

    // Update in live bookings store
    const storeUpdated = bookingsStore.registerCustomer({
      id: userId,
      customerId: userId,
      fullName: fullName || updatedUser?.fullName,
      name: fullName || updatedUser?.fullName,
      email: email || updatedUser?.email,
      phone: phone || updatedUser?.phone,
    });

    const finalUser = updatedUser || {
      id: userId,
      fullName: storeUpdated.fullName,
      phone: storeUpdated.phone,
      email: storeUpdated.email,
    };

    if (global.io) {
      global.io.emit('admin:customer_updated', {
        id: userId,
        customerId: userId,
        fullName: finalUser.fullName,
        name: finalUser.fullName,
        phone: finalUser.phone,
        email: finalUser.email,
        updatedAt: new Date().toISOString(),
      });
    }

    return res.json({
      success: true,
      message: 'Profile updated successfully',
      data: finalUser,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET /api/v1/customer/addresses
 */
const getAddresses = async (req, res) => {
  try {
    const userId = req.user?.id || req.query.userId || req.headers['x-user-id'];
    if (!userId) {
      return res.json({ success: true, data: [] });
    }

    let addresses = [];
    if (postgres.isPgHealthy()) {
      try {
        const resDb = await postgres.query(
          `SELECT id, user_id as "customerId", address_type as "addressType", house_flat as "houseFlat",
                  street, landmark, area, city, state, postal_code as "postalCode", latitude, longitude, is_primary as "primary"
           FROM customer_addresses WHERE user_id = $1 ORDER BY is_primary DESC, created_at DESC`,
          [userId]
        );
        addresses = resDb.rows || [];
      } catch (e) {
        console.warn('⚠️ [CustomerController] Get addresses warning:', e.message);
      }
    }

    return res.json({ success: true, data: addresses, count: addresses.length });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/customer/addresses
 */
const addAddress = async (req, res) => {
  try {
    const userId = req.user?.id || req.body.userId || req.body.customerId || req.headers['x-user-id'];
    const {
      houseFlat = '',
      street = '',
      area = '',
      city = 'Kolkata',
      state = 'West Bengal',
      postalCode = '',
      landmark = '',
      addressType = 'HOME',
      latitude = 22.5726,
      longitude = 88.3639,
      primary = true,
    } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required to add address' });
    }

    const addrId = `addr_${uuidv4().slice(0, 8)}`;
    const formattedStr = [houseFlat, street, area, city, state, postalCode].filter(Boolean).join(', ');

    if (postgres.isPgHealthy()) {
      try {
        if (primary) {
          await postgres.query('UPDATE customer_addresses SET is_primary = false WHERE user_id = $1', [userId]);
        }

        await postgres.query(
          `INSERT INTO customer_addresses (
            id, user_id, address_type, house_flat, street, landmark, area, city, state, postal_code, latitude, longitude, is_primary
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
          [addrId, userId, addressType, houseFlat, street, landmark, area, city, state, postalCode, latitude, longitude, primary]
        );
      } catch (dbErr) {
        console.warn('⚠️ [CustomerController] Add address PG warning:', dbErr.message);
      }
    }

    // Update in bookingsStore live customers
    bookingsStore.registerCustomer({
      id: userId,
      customerId: userId,
      address: formattedStr,
    });

    if (global.io) {
      global.io.emit('admin:customer_updated', {
        id: userId,
        customerId: userId,
        address: formattedStr,
        updatedAt: new Date().toISOString(),
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Address added successfully',
      data: {
        id: addrId,
        customerId: userId,
        addressType,
        houseFlat,
        street,
        area,
        city,
        state,
        postalCode,
        landmark,
        latitude,
        longitude,
        primary,
        formattedAddress: formattedStr,
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * PUT /api/v1/customer/addresses/:id
 */
const updateAddress = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id || req.body.userId || req.body.customerId || req.headers['x-user-id'];

    const {
      houseFlat,
      street,
      area,
      city,
      state,
      postalCode,
      landmark,
      addressType,
      latitude,
      longitude,
      primary,
    } = req.body;

    if (postgres.isPgHealthy() && id) {
      try {
        if (primary && userId) {
          await postgres.query('UPDATE customer_addresses SET is_primary = false WHERE user_id = $1', [userId]);
        }

        await postgres.query(
          `UPDATE customer_addresses
           SET house_flat = COALESCE($1, house_flat),
               street = COALESCE($2, street),
               area = COALESCE($3, area),
               city = COALESCE($4, city),
               state = COALESCE($5, state),
               postal_code = COALESCE($6, postal_code),
               landmark = COALESCE($7, landmark),
               address_type = COALESCE($8, address_type),
               latitude = COALESCE($9, latitude),
               longitude = COALESCE($10, longitude),
               is_primary = COALESCE($11, is_primary)
           WHERE id = $12`,
          [houseFlat, street, area, city, state, postalCode, landmark, addressType, latitude, longitude, primary, id]
        );
      } catch (dbErr) {
        console.warn('⚠️ [CustomerController] Update address PG warning:', dbErr.message);
      }
    }

    const formattedStr = [houseFlat, street, area, city, state, postalCode].filter(Boolean).join(', ');
    if (userId && formattedStr) {
      bookingsStore.registerCustomer({ id: userId, address: formattedStr });
      if (global.io) {
        global.io.emit('admin:customer_updated', { id: userId, address: formattedStr, updatedAt: new Date().toISOString() });
      }
    }

    return res.json({ success: true, message: 'Address updated successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * DELETE /api/v1/customer/addresses/:id
 */
const deleteAddress = async (req, res) => {
  try {
    const { id } = req.params;
    if (postgres.isPgHealthy() && id) {
      try {
        await postgres.query('DELETE FROM customer_addresses WHERE id = $1', [id]);
      } catch (e) {}
    }
    return res.json({ success: true, message: 'Address deleted successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST /api/v1/customer/location
 * Update live GPS location and primary address for customer
 */
const updateLocation = async (req, res) => {
  try {
    const userId = req.user?.id || req.body.userId || req.body.customerId || req.headers['x-user-id'];
    const { latitude, longitude, address, houseFlat, street, area, city, state, postalCode } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }

    const fullAddrStr = address || [houseFlat, street, area, city, state, postalCode].filter(Boolean).join(', ') || 'Current GPS Location';

    if (postgres.isPgHealthy()) {
      try {
        const checkAddr = await postgres.query(
          'SELECT id FROM customer_addresses WHERE user_id = $1 ORDER BY is_primary DESC LIMIT 1',
          [userId]
        );

        if (checkAddr.rows.length > 0) {
          const existingId = checkAddr.rows[0].id;
          await postgres.query(
            `UPDATE customer_addresses 
             SET latitude = $1, longitude = $2, street = COALESCE(NULLIF($3, ''), street), is_primary = true 
             WHERE id = $4`,
            [latitude, longitude, fullAddrStr, existingId]
          );
        } else {
          const newId = `addr_gps_${uuidv4().slice(0, 8)}`;
          await postgres.query(
            `INSERT INTO customer_addresses (id, user_id, address_type, street, city, state, latitude, longitude, is_primary)
             VALUES ($1, $2, 'HOME', $3, COALESCE($4, 'Kolkata'), COALESCE($5, 'West Bengal'), $6, $7, true)`,
            [newId, userId, fullAddrStr, city || 'Kolkata', state || 'West Bengal', latitude, longitude]
          );
        }
      } catch (dbErr) {
        console.warn('⚠️ [CustomerController] Location update PG warning:', dbErr.message);
      }
    }

    // Update in live store
    bookingsStore.registerCustomer({
      id: userId,
      customerId: userId,
      address: fullAddrStr,
    });

    if (global.io) {
      global.io.emit('admin:customer_updated', {
        id: userId,
        customerId: userId,
        address: fullAddrStr,
        latitude,
        longitude,
        updatedAt: new Date().toISOString(),
      });
    }

    return res.json({
      success: true,
      message: 'Location and address synced successfully',
      data: {
        userId,
        address: fullAddrStr,
        latitude,
        longitude,
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  getProfile,
  updateProfile,
  getAddresses,
  addAddress,
  updateAddress,
  deleteAddress,
  updateLocation,
};
