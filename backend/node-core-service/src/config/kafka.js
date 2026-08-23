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

  try {
    const kafka = new Kafka({
      clientId: process.env.KAFKA_CLIENT_ID || 'bookurtechnician-node-gateway',
      brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
      retry: { retries: 2 },
    });

    kafkaProducer = kafka.producer();
    await kafkaProducer.connect();
    isKafkaEnabled = true;
    console.log('✅ [Apache Kafka] Connected to broker cluster (Real-time Asynchronous Event Streaming active)');
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
