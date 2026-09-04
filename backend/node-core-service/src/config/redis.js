 Redis = require('ioredis');

let redisClient = null;
let isRedisConnected = false;

// In-Memory simulated Redis Geo & Key-Value store fallback
const memoryGeo = new Map(); // key -> [{ member, longitude, latitude }]
const memoryStore = new Map(); // key -> { value, expiry }

const initRedis = () => {
  const redisUrl = process.env.REDIS_URL;
  const host = process.env.REDIS_HOST || 'localhost';
  const port = parseInt(process.env.REDIS_PORT || '6379', 10);
  const password = process.env.REDIS_PASSWORD || undefined;

  try {
    if (redisUrl) {
      const isTls = redisUrl.startsWith('rediss://');
      redisClient = new Redis(redisUrl, {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        connectTimeout: 5000,
        tls: isTls ? { rejectUnauthorized: false } : undefined,
      });
    } else {
      redisClient = new Redis({
        host,
        port,
        password,
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        connectTimeout: 5000,
      });
    }

    redisClient.connect()
      .then(() => {
        isRedisConnected = true;
        const targetDesc = redisUrl ? 'Cloud Redis via REDIS_URL' : `${host}:${port}`;
        console.log(`✅ [Redis] Connected successfully to ${targetDesc} (Live Geospatial 15km Index & Fast OTP store)`);
      })
      .catch((err) => {
        console.warn('⚠️ [Redis] Connection warning (In-memory geospatial simulator active):', err.message);
        isRedisConnected = false;
      });

    redisClient.on('error', (err) => {
      isRedisConnected = false;
    });
  } catch (err) {
    console.warn('⚠️ [Redis] Init error:', err.message);
    isRedisConnected = false;
  }
};

// Geospatial Helpers
const geoAdd = async (key, longitude, latitude, member) => {
  if (isRedisConnected && redisClient) {
    try {
      await redisClient.geoadd(key, longitude, latitude, member);
      return;
    } catch (e) {
      // Fallback
    }
  }
  // Memory Geo Fallback
  if (!memoryGeo.has(key)) memoryGeo.set(key, []);
  const list = memoryGeo.get(key).filter(item => item.member !== member);
  list.push({ member, longitude: parseFloat(longitude), latitude: parseFloat(latitude) });
  memoryGeo.set(key, list);
};

const geoRadius = async (key, longitude, latitude, radiusKm = 15) => {
  if (isRedisConnected && redisClient) {
    try {
      const results = await redisClient.georadius(key, longitude, latitude, radiusKm, 'km', 'WITHDIST', 'WITHCOORD');
      return results.map(r => ({
        member: r[0],
        distanceKm: parseFloat(r[1]),
        longitude: parseFloat(r[2][0]),
        latitude: parseFloat(r[2][1]),
      }));
    } catch (e) {
      // Fallback
    }
  }

  // Memory Haversine Geo Search
  if (!memoryGeo.has(key)) return [];
  const candidates = memoryGeo.get(key);
  const results = [];

  const toRad = (v) => (v * Math.PI) / 180;
  const R = 6371; // Earth radius in km

  for (const c of candidates) {
    const dLat = toRad(c.latitude - latitude);
    const dLon = toRad(c.longitude - longitude);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(latitude)) * Math.cos(toRad(c.latitude)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const dist = R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
    if (dist <= radiusKm) {
      results.push({
        member: c.member,
        distanceKm: parseFloat(dist.toFixed(2)),
        longitude: c.longitude,
        latitude: c.latitude,
      });
    }
  }
  return results.sort((a, b) => a.distanceKm - b.distanceKm);
};

// Key-Value Helpers
const setWithExpiry = async (key, value, expirySeconds = 300) => {
  if (isRedisConnected && redisClient) {
    try {
      await redisClient.set(key, typeof value === 'string' ? value : JSON.stringify(value), 'EX', expirySeconds);
      return;
    } catch (e) {}
  }
  memoryStore.set(key, { value, expiry: Date.now() + expirySeconds * 1000 });
};

const get = async (key) => {
  if (isRedisConnected && redisClient) {
    try {
      const val = await redisClient.get(key);
      try { return JSON.parse(val); } catch { return val; }
    } catch (e) {}
  }
  const item = memoryStore.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) {
    memoryStore.delete(key);
    return null;
  }
  return item.value;
};

const del = async (key) => {
  if (isRedisConnected && redisClient) {
    try { await redisClient.del(key); return; } catch (e) {}
  }
  memoryStore.delete(key);
};

const geoRemove = async (key, member) => {
  if (isRedisConnected && redisClient) {
    try {
      await redisClient.zrem(key, member);
      return;
    } catch (e) {}
  }
  if (memoryGeo.has(key)) {
    const list = memoryGeo.get(key).filter(item => item.member !== member);
    memoryGeo.set(key, list);
  }
};

const setHeartbeat = async (technicianId, staleSeconds = 60) => {
  const key = `technician:heartbeat:${technicianId}`;
  await setWithExpiry(key, { timestamp: Date.now() }, staleSeconds);
};

const isTechnicianFresh = async (technicianId) => {
  const key = `technician:heartbeat:${technicianId}`;
  const hb = await get(key);
  return hb !== null;
};

const isRedisHealthy = () => isRedisConnected;

module.exports = {
  initRedis,
  geoAdd,
  geoRadius,
  geoRemove,
  setHeartbeat,
  isTechnicianFresh,
  setWithExpiry,
  get,
  del,
  isRedisHealthy,
};
