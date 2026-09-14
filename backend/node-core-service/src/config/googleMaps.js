const axios = require('axios');

/**
 * High-precision Haversine distance calculator between 2 GPS coordinates
 * @param {number} lat1 
 * @param {number} lon1 
 * @param {number} lat2 
 * @param {number} lon2 
 * @returns {number} Distance in kilometers
 */
const calculateHaversineDistance = (lat1, lon1, lat2, lon2) => {
  const toRad = (value) => (value * Math.PI) / 180;
  const R = 6371; // Earth radius in km

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distanceKm = R * c;

  return parseFloat(distanceKm.toFixed(2));
};

/**
 * Calculates ETA assuming average city speed of 25 km/h + 5 mins prep
 * @param {number} distanceKm 
 * @returns {number} ETA in minutes
 */
const estimateETA = (distanceKm) => {
  const avgSpeedKmh = 25;
  const travelMinutes = (distanceKm / avgSpeedKmh) * 60;
  return Math.max(5, Math.round(travelMinutes + 3));
};

/**
 * Get real-time distance and ETA via Google Distance Matrix API if key is present,
 * or fallback to Haversine calculation for $0 cost execution.
 */
const getDistanceAndETA = async (originLat, originLng, destLat, destLng) => {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;

  if (apiKey) {
    try {
      const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${originLat},${originLng}&destinations=${destLat},${destLng}&key=${apiKey}`;
      const response = await axios.get(url, { timeout: 3000 });
      const element = response.data?.rows?.[0]?.elements?.[0];

      if (element && element.status === 'OK') {
        return {
          distanceKm: parseFloat((element.distance.value / 1000).toFixed(2)),
          durationMinutes: Math.round(element.duration.value / 60),
          provider: 'google_maps',
        };
      }
    } catch (e) {
      console.warn('⚠️ [Google Maps] API request failed, falling back to Haversine:', e.message);
    }
  }

  // Built-in 0-cost Haversine calculation
  const distanceKm = calculateHaversineDistance(originLat, originLng, destLat, destLng);
  const durationMinutes = estimateETA(distanceKm);

  return {
    distanceKm,
    durationMinutes,
    provider: 'haversine_engine',
  };
};

module.exports = {
  calculateHaversineDistance,
  estimateETA,
  getDistanceAndETA,
};
