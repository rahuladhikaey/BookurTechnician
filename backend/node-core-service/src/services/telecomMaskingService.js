'use strict';

/**
 * Telecom Masking Service (Exotel & Twilio Voice Calling Provider)
 * Enables anonymous masked phone calls between customers and technicians.
 * If provider is unconfigured, returns TELECOM_PROVIDER_NOT_CONFIGURED rather than faking calls.
 */

const axios = require('axios');
const postgres = require('../config/postgres');
const { v4: uuidv4 } = require('uuid');

const EXOTEL_SID = process.env.EXOTEL_SID || process.env.EXOTEL_ACCOUNT_SID;
const EXOTEL_API_KEY = process.env.EXOTEL_API_KEY;
const EXOTEL_API_TOKEN = process.env.EXOTEL_API_TOKEN;
const EXOTEL_CALLER_ID = process.env.EXOTEL_CALLER_ID;
const EXOTEL_SUBDOMAIN = process.env.EXOTEL_SUBDOMAIN || 'api.exotel.com';

const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
const TWILIO_PHONE_NUMBER = process.env.TWILIO_PHONE_NUMBER;

function getActiveProvider() {
  if (EXOTEL_API_KEY && EXOTEL_API_TOKEN && EXOTEL_SID && EXOTEL_CALLER_ID) {
    return 'EXOTEL';
  }
  if (TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_PHONE_NUMBER) {
    return 'TWILIO';
  }
  return null;
}

/**
 * Initiate a masked call between Customer and Technician
 */
async function initiateMaskedCall({ bookingId, initiatorRole, customerPhone, technicianPhone }) {
  const provider = getActiveProvider();
  const callRequestId = `CALL-${uuidv4().slice(0, 10)}`;

  if (!provider) {
    // Fail closed: Never simulate a call when provider is unconfigured
    const unconfiguredResponse = {
      success: false,
      error: 'TELECOM_PROVIDER_NOT_CONFIGURED',
      message: 'Telecom masking provider is not configured. Masked calling is unavailable in this environment.',
      callRequestId,
      bookingId,
    };
    return { statusCode: 503, ...unconfiguredResponse };
  }

  // Determine direction
  const callerNumber = initiatorRole === 'CUSTOMER' ? customerPhone : technicianPhone;
  const receiverNumber = initiatorRole === 'CUSTOMER' ? technicianPhone : customerPhone;

  if (!callerNumber || !receiverNumber) {
    return {
      statusCode: 400,
      success: false,
      error: 'MISSING_PHONE_NUMBER',
      message: 'Both customer and technician phone numbers are required for telecom call bridging.',
    };
  }

  try {
    let providerResponse = null;
    let providerCallId = null;

    if (provider === 'EXOTEL') {
      const authHeader = 'Basic ' + Buffer.from(`${EXOTEL_API_KEY}:${EXOTEL_API_TOKEN}`).toString('base64');
      const exotelUrl = `https://${EXOTEL_SUBDOMAIN}/v1/Accounts/${EXOTEL_SID}/Calls/connect.json`;
      
      const params = new URLSearchParams();
      params.append('From', callerNumber);
      params.append('To', receiverNumber);
      params.append('CallerId', EXOTEL_CALLER_ID);
      params.append('TimeLimit', '1800'); // Max 30 minutes
      params.append('CustomField', bookingId);

      const resp = await axios.post(exotelUrl, params.toString(), {
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        timeout: 10000,
      });

      providerResponse = resp.data;
      providerCallId = resp.data?.Call?.Sid || resp.data?.Sid;
    } else if (provider === 'TWILIO') {
      const authHeader = 'Basic ' + Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64');
      const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls.json`;

      const params = new URLSearchParams();
      params.append('From', TWILIO_PHONE_NUMBER);
      params.append('To', callerNumber);
      // TwiML instruction to dial receiver
      const twiml = `<Response><Dial callerId="${TWILIO_PHONE_NUMBER}"><Number>${receiverNumber}</Number></Dial></Response>`;
      params.append('Twiml', twiml);

      const resp = await axios.post(twilioUrl, params.toString(), {
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        timeout: 10000,
      });

      providerResponse = resp.data;
      providerCallId = resp.data?.sid;
    }

    // Persist call log in PostgreSQL
    if (postgres.isPgHealthy()) {
      try {
        await postgres.query(`
          CREATE TABLE IF NOT EXISTS masked_call_logs (
            id VARCHAR(64) PRIMARY KEY,
            booking_id VARCHAR(64) NOT NULL,
            initiator_role VARCHAR(32) NOT NULL,
            provider VARCHAR(32) NOT NULL,
            provider_call_id VARCHAR(128),
            status VARCHAR(32) NOT NULL,
            provider_response JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );
        `);

        await postgres.query(`
          INSERT INTO masked_call_logs (id, booking_id, initiator_role, provider, provider_call_id, status, provider_response, created_at)
          VALUES ($1, $2, $3, $4, $5, 'INITIATED', $6, NOW())
        `, [callRequestId, bookingId, initiatorRole, provider, providerCallId, JSON.stringify(providerResponse)]);
      } catch (dbErr) {
        console.warn('Failed to insert masked_call_logs:', dbErr.message);
      }
    }

    return {
      statusCode: 200,
      success: true,
      message: 'Masked call successfully bridged via telecom provider.',
      callRequestId,
      provider,
      providerCallId,
      status: 'INITIATED',
    };
  } catch (providerErr) {
    const errorDetails = providerErr.response?.data || providerErr.message;
    console.error('❌ Telecom Provider Call Failed:', errorDetails);
    return {
      statusCode: 502,
      success: false,
      error: 'TELECOM_CALL_FAILED',
      message: 'Failed to initiate masked call through telecom provider.',
      details: errorDetails,
    };
  }
}

module.exports = {
  getActiveProvider,
  initiateMaskedCall,
};
