const admin = require('firebase-admin');

/**
 * Technician Presence & GPS Heartbeat Tracking Service
 * Enforces strict bounds checking and separates heartbeats from coordinate updates.
 */

async function updateTechnicianPresence(db, { callerUid, latitude, longitude, heading, speed, accuracy, isOnline }) {
  if (!callerUid) {
    const err = new Error('Authenticated technician UID required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const onlineState = isOnline !== false && isOnline !== 'false';
  const hasCoords = latitude !== undefined && latitude !== null && longitude !== undefined && longitude !== null;
  const lat = Number(latitude);
  const lng = Number(longitude);

  if (onlineState || hasCoords) {
    if (!hasCoords || Number.isNaN(lat) || lat < -90 || lat > 90 || lat === 0) {
      const err = new Error(`Invalid latitude value: ${latitude}. Must be between -90 and 90`);
      err.status = 400;
      err.code = 'INVALID_COORDINATES';
      throw err;
    }

    if (Number.isNaN(lng) || lng < -180 || lng > 180 || lng === 0) {
      const err = new Error(`Invalid longitude value: ${longitude}. Must be between -180 and 180`);
      err.status = 400;
      err.code = 'INVALID_COORDINATES';
      throw err;
    }
  }

  const nowIso = new Date().toISOString();
  const techRef = db.collection('technician_profiles').doc(callerUid);
  const presenceRef = db.collection('presence').doc(callerUid);

  const existingSnap = await techRef.get();
  const existingData = existingSnap.exists ? existingSnap.data() : {};
  const isBusy = existingData && (existingData.availabilityStatus === 'BUSY' || Boolean(existingData.activeBookingId));
  const nextAvailabilityStatus = !onlineState
    ? 'OFFLINE'
    : (isBusy ? 'BUSY' : 'AVAILABLE');

  const profileUpdate = {
    isOnline: onlineState,
    online: onlineState,
    availabilityStatus: nextAvailabilityStatus,
    lastPresenceHeartbeat: nowIso,
    updatedAt: nowIso,
  };

  const presenceUpdate = {
    uid: callerUid,
    status: onlineState ? (isBusy ? 'BUSY' : 'ONLINE') : 'OFFLINE',
    lastHeartbeat: nowIso,
    updatedAt: nowIso,
  };

  if (hasCoords) {
    let geoPoint = null;
    try {
      geoPoint = new admin.firestore.GeoPoint(lat, lng);
    } catch (e) {
      geoPoint = { latitude: lat, longitude: lng };
    }
    profileUpdate.latitude = lat;
    profileUpdate.longitude = lng;
    profileUpdate.currentLatitude = lat;
    profileUpdate.currentLongitude = lng;
    profileUpdate.location = geoPoint;
    profileUpdate.heading = Number(heading) || 0;
    profileUpdate.speed = Number(speed) || 0;
    profileUpdate.accuracy = Number(accuracy) || 10;
    profileUpdate.lastLocationUpdate = nowIso;

    presenceUpdate.latitude = lat;
    presenceUpdate.longitude = lng;
  }

  const batch = db.batch();
  batch.set(techRef, profileUpdate, { merge: true });
  batch.set(presenceRef, presenceUpdate, { merge: true });

  await batch.commit();

  return {
    success: true,
    message: onlineState
      ? 'Technician presence and coordinates recorded'
      : 'Technician marked offline',
    data: {
      technicianId: callerUid,
      isOnline: onlineState,
      availabilityStatus: nextAvailabilityStatus,
      ...(hasCoords ? { latitude: lat, longitude: lng } : {}),
      lastPresenceHeartbeat: nowIso,
    },
  };
}

module.exports = {
  updateTechnicianPresence,
};

