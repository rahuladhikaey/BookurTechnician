const axios = require('axios');

const FAST2SMS_API_KEY = process.env.FAST2SMS_API_KEY || '';
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || '';
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || '';
const TWILIO_PHONE_NUMBER = process.env.TWILIO_PHONE_NUMBER || '';

/**
 * Clean and format 10-digit Indian mobile number
 */
const formatIndianPhoneNumber = (phone) => {
  if (!phone) return '';
  const digits = String(phone).replace(/\D/g, '');
  if (digits.length === 10) return digits;
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);
  if (digits.length > 10) return digits.slice(-10);
  return digits;
};

/**
 * Send OTP via Fast2SMS (Indian Mobile Gateways)
 */
const sendFast2SmsOtp = async (clean10DigitPhone, otp) => {
  if (!FAST2SMS_API_KEY) {
    return false;
  }

  try {
    const response = await axios.post(
      'https://www.fast2sms.com/dev/bulkV2',
      {
        variables_values: otp,
        route: 'otp',
        numbers: clean10DigitPhone,
      },
      {
        headers: {
          authorization: FAST2SMS_API_KEY,
          'Content-Type': 'application/json',
        },
        timeout: 6000,
      }
    );

    if (response.data && response.data.return === true) {
      console.log(`📱 [Fast2SMS] OTP sent successfully to +91 ${clean10DigitPhone}`);
      return true;
    } else {
      console.warn('⚠️ [Fast2SMS] Response error:', response.data?.message || response.data);
      return false;
    }
  } catch (err) {
    console.warn('⚠️ [Fast2SMS Network Warning]:', err.response?.data?.message || err.message);
    return false;
  }
};

/**
 * Send OTP via Twilio Gateway (International fallback)
 */
const sendTwilioSmsOtp = async (fullInternationalPhone, otp) => {
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
    return false;
  }

  try {
    const token = Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64');
    const params = new URLSearchParams();
    params.append('To', fullInternationalPhone.startsWith('+') ? fullInternationalPhone : `+91${fullInternationalPhone}`);
    params.append('From', TWILIO_PHONE_NUMBER);
    params.append('Body', `Your BookurTechnician verification code is ${otp}. Valid for 10 minutes.`);

    const response = await axios.post(
      `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`,
      params.toString(),
      {
        headers: {
          Authorization: `Basic ${token}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        timeout: 6000,
      }
    );

    if (response.data && response.data.sid) {
      console.log(`📱 [Twilio SMS] OTP dispatched to ${fullInternationalPhone} (SID: ${response.data.sid})`);
      return true;
    }
    return false;
  } catch (err) {
    console.warn('⚠️ [Twilio SMS Warning]:', err.response?.data?.message || err.message);
    return false;
  }
};

/**
 * Unified SMS Dispatcher:
 * Automatically formats phone number, attempts Fast2SMS first (for Indian users),
 * and falls back to Twilio if available.
 */
const sendOtpSms = async (rawPhone, otp, role = 'CUSTOMER') => {
  if (!rawPhone) return false;

  const cleanPhone = formatIndianPhoneNumber(rawPhone);
  if (cleanPhone.length !== 10) {
    console.warn(`⚠️ [SMS Gateway] Invalid phone length for: ${rawPhone}`);
    return false;
  }

  console.log(`📡 [SMS Gateway] Dispatching OTP [${otp}] to +91 ${cleanPhone} (${role})`);

  // 1. Attempt Fast2SMS
  if (FAST2SMS_API_KEY) {
    const fast2smsSuccess = await sendFast2SmsOtp(cleanPhone, otp);
    if (fast2smsSuccess) return true;
  }

  // 2. Attempt Twilio
  if (TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN) {
    const twilioSuccess = await sendTwilioSmsOtp(`+91${cleanPhone}`, otp);
    if (twilioSuccess) return true;
  }

  // If no external SMS gateway is configured yet in .env, log local console instructions
  console.log(`ℹ️ [SMS Sandbox Notice] To enable live telco SMS delivery on physical phones, add FAST2SMS_API_KEY or TWILIO credentials to .env.`);
  return true;
};

module.exports = {
  sendOtpSms,
  formatIndianPhoneNumber,
};
