const { Kafka } = require('kafkajs');
const EventEmitter = require('events');

class InternalEventBus extends EventEmitter {}
const internalBus = new InternalEventBus();

let kafkaProducer = null;
let isKafkaEnabled = false;

const initKafka = async () => {
  const shouldEnable = process.env.ENABLE_KAFKA === 'true';
  if (!shouldEnable) {
    console.log('ℹ️ [Event Streaming] Using In-Memory Event Streaming Bus ($0 MVP Mode - Kafka disabled)');
    return;
  }

  const rawBrokers = process.env.KAFKA_BROKERS || '';
  if (!rawBrokers) {
    console.log('ℹ️ [Event Streaming] No KAFKA_BROKERS provided; using Internal Event Bus');
    return;
  }

  const brokers = rawBrokers.split(',').map(b => b.trim()).filter(Boolean);
  const useSsl = process.env.KAFKA_SSL === 'true' || rawBrokers.includes('upstash.io') || rawBrokers.includes('confluent.cloud');

  let sasl = undefined;
  if (process.env.KAFKA_SASL_USERNAME && process.env.KAFKA_SASL_PASSWORD) {
    const mech = (process.env.KAFKA_SASL_MECHANISM || 'scram-sha-256').toLowerCase();
    sasl = {
      mechanism: mech,
      username: process.env.KAFKA_SASL_USERNAME,
      password: process.env.KAFKA_SASL_PASSWORD,
    };
  }

  try {
    const kafka = new Kafka({
      clientId: process.env.KAFKA_CLIENT_ID || 'bookurtechnician-node-gateway',
      brokers,
      ssl: useSsl ? { rejectUnauthorized: true } : false,
      sasl,
      connectionTimeout: 8000,
      authenticationTimeout: 8000,
      retry: {
        initialRetryTime: 300,
        retries: 3,
      },
    });

    kafkaProducer = kafka.producer();
    await kafkaProducer.connect();
    isKafkaEnabled = true;
    console.log(`✅ [Apache Kafka] Connected to cloud broker cluster (${brokers.join(', ')}) [SSL: ${useSsl}, SASL: ${sasl ? sasl.mechanism : 'None'}]`);
  } catch (err) {
    console.warn('⚠️ [Apache Kafka] Connection warning, falling back to internal event bus:', err.message);
    isKafkaEnabled = false;
  }
};

/**
 * Publish an event to Kafka or internal bus
 * @param {string} topic - e.g. 'booking.created', 'booking.otp_verified'
 * @param {object} payload - event payload
 */
const publishEvent = async (topic, payload) => {
  const eventMessage = {
    topic,
    timestamp: new Date().toISOString(),
    payload,
  };

  if (isKafkaEnabled && kafkaProducer) {
    try {
      await kafkaProducer.send({
        topic,
        messages: [{ value: JSON.stringify(eventMessage) }],
      });
      return { published: true, broker: 'kafka' };
    } catch (e) {
      console.warn(`⚠️ [Kafka] Publish failed for ${topic}:`, e.message);
    }
  }

  // Fallback to internal in-memory event bus
  internalBus.emit(topic, eventMessage);
  return { published: true, broker: 'internal_bus' };
};

const subscribeEvent = (topic, handler) => {
  internalBus.on(topic, handler);
};

module.exports = { initKafka, publishEvent, subscribeEvent };
