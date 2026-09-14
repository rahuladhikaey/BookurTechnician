const Redis = require('ioredis');

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

redis.on('connect', () => console.log('✅ Redis connected for 15km GEO discovery'));
redis.on('error', (err) => console.warn('⚠️ Redis error:', err.message));

const GEO_KEY_PREFIX = 'partners:geo';
const HEARTBEAT_TTL = 90; // 90 seconds TTL for active technicians

async function updateTechnicianLocation(category, technicianId, longitude, latitude) {
  const geoKey = `${GEO_KEY_PREFIX}:${category.toLowerCase()}`;
  
  // Add to Redis GEO index
  await redis.geoadd(geoKey, longitude, latitude, technicianId);

  // Set heartbeat TTL key
  const heartbeatKey = `tech:heartbeat:${technicianId}`;
  await redis.set(heartbeatKey, '1', 'EX', HEARTBEAT_TTL);
}

async function findNearbyTechnicians(category, longitude, latitude, radiusKm = 15) {
  const geoKey = `${GEO_KEY_PREFIX}:${category.toLowerCase()}`;

  try {
    // Redis GEOSEARCH radius query within 15 km with distance and coordinates
    const results = await redis.geosearch(
      geoKey,
      'FROMLONLAT',
      longitude,
      latitude,
      'BYRADIUS',
      radiusKm,
      'km',
      'WITHDIST',
      'WITHCOORD',
      'ASC'
    );

    const activeTechnicians = [];
    for (const item of results) {
      const [techId, distStr, coords] = item;
      const isAlive = await redis.exists(`tech:heartbeat:${techId}`);
      if (isAlive) {
        activeTechnicians.push({
          technicianId: techId,
          distanceKm: parseFloat(distStr),
          longitude: parseFloat(coords[0]),
          latitude: parseFloat(coords[1]),
        });
      }
    }

    return activeTechnicians;
  } catch (err) {
    console.warn('Redis GEO query fallback:', err.message);
    return [];
  }
}

async function removeTechnician(category, technicianId) {
  const geoKey = `${GEO_KEY_PREFIX}:${category.toLowerCase()}`;
  await redis.zrem(geoKey, technicianId);
  await redis.del(`tech:heartbeat:${technicianId}`);
}

module.exports = {
  redis,
  updateTechnicianLocation,
  findNearbyTechnicians,
  removeTechnician,
};
