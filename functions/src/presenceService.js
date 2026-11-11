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

  const lat = Number(latitude);
  const lng = Number(longitude);

  if (isNaN(lat) || lat < -90 || lat > 90) {
    const err = new Error(`Invalid latitude value: ${latitude}. Must be between -90 and 90`);
    err.status = 400;
    err.code = 'INVALID_COORDINATES';
    throw err;
  }

  if (isNaN(lng) || lng < -180 || lng > 180) {
    const err = new Error(`Invalid longitude value: ${longitude}. Must be between -180 and 180`);
    err.status = 400;
    err.code = 'INVALID_COORDINATES';
    throw err;
  }

  const nowIso = new Date().toISOString();
  const techRef = db.collection('technician_profiles').doc(callerUid);
  const presenceRef = db.collection('presence').doc(callerUid);

  const onlineState = isOnline !== false && isOnline !== 'false';

  // Create GeoPoint if supported
  let geoPoint = null;
  try {
    geoPoint = new admin.firestore.GeoPoint(lat, lng);
  } catch (e) {
    geoPoint = { latitude: lat, longitude: lng };
  }

  const profileUpdate = {
    latitude: lat,
    longitude: lng,
    location: geoPoint,
    heading: Number(heading) || 0,
    speed: Number(speed) || 0,
    accuracy: Number(accuracy) || 10,
    isOnline: onlineState,
    lastPresenceHeartbeat: nowIso,
    lastLocationUpdate: nowIso,
    updatedAt: nowIso,
  };

  const presenceUpdate = {
    uid: callerUid,
    status: onlineState ? 'ONLINE' : 'OFFLINE',
    latitude: lat,
    longitude: lng,
    lastHeartbeat: nowIso,
    updatedAt: nowIso,
  };

  const batch = db.batch();
  batch.set(techRef, profileUpdate, { merge: true });
  batch.set(presenceRef, presenceUpdate, { merge: true });

  await batch.commit();

  return {
    success: true,
    message: 'Technician presence and coordinates recorded',
    data: {
      technicianId: callerUid,
      isOnline: onlineState,
      latitude: lat,
      longitude: lng,
      lastPresenceHeartbeat: nowIso,
    },
  };
}

module.exports = {
  updateTechnicianPresence,
};

