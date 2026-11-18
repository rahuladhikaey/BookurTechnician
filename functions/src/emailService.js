const EMAILJS_API_URL = 'https://api.emailjs.com/api/v1.0/email/send';
const DEFAULT_ORIGIN = 'https://bookmytechnician-53d94.web.app';

/**
 * Derive a clean display name from an email address.
 */
function deriveNameFromEmail(email) {
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    return 'Valued User';
  }
  try {
    const prefix = email.split('@')[0];
    if (!prefix) return 'Valued User';
    const cleaned = prefix.replace(/\d+$/, '').replace(/[._\-+]/g, ' ').trim();
    if (!cleaned) {
      return prefix.charAt(0).toUpperCase() + prefix.slice(1);
    }
    return cleaned
      .split(/\s+/)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(' ');
  } catch (_) {
    return 'Valued User';
  }
}

function readEmailJsConfig() {
  const publicKey = (process.env.EMAILJS_PUBLIC_KEY || '').trim();
  const privateKey = (process.env.EMAILJS_PRIVATE_KEY || '').trim();
  const serviceId = (process.env.EMAILJS_SERVICE_ID || '').trim();
  const templateId = (process.env.EMAILJS_TEMPLATE_ID || '').trim();
  const fallbackTemplateId = (process.env.EMAILJS_FALLBACK_TEMPLATE_ID || '').trim();
  const origin = (process.env.EMAILJS_ORIGIN || DEFAULT_ORIGIN).trim();

  const configured = Boolean(publicKey && privateKey && serviceId && templateId);

  return {
    configured,
    publicKey,
    privateKey,
    serviceId,
    templateId,
    fallbackTemplateId,
    origin,
  };
}

function getEmailJsStatus() {
  const cfg = readEmailJsConfig();
  return {
    configured: cfg.configured,
    serviceConfigured: Boolean(cfg.serviceId),
    templateConfigured: Boolean(cfg.templateId),
    publicKeyConfigured: Boolean(cfg.publicKey),
    privateKeyConfigured: Boolean(cfg.privateKey),
  };
}

async function postEmailJsPayload(payload, origin, fetchImpl, timeoutMs = 4500) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetchImpl(EMAILJS_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: origin,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    const text = await res.text();
    if (!res.ok) {
      const err = new Error(`EmailJS responded with HTTP ${res.status}`);
      err.status = res.status;
      err.responseText = text;
      throw err;
    }
    return text || 'OK';
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Send transactional email via EmailJS REST API using Render environment credentials.
 */
async function sendEmailJsEmail(
  { to, name, subject, otp, role = 'CUSTOMER', htmlContent },
  { fetchImpl = globalThis.fetch } = {}
) {
  const cfg = readEmailJsConfig();
  if (!cfg.configured) {
    return {
      success: false,
      configured: false,
      code: 'EMAILJS_NOT_CONFIGURED',
      error: 'EmailJS credentials are not configured in server environment variables',
    };
  }

  if (typeof fetchImpl !== 'function') {
    return {
      success: false,
      configured: true,
      code: 'FETCH_UNAVAILABLE',
      error: 'HTTP client not available for EmailJS dispatch',
    };
  }

  const normalizedEmail = String(to || '').trim().toLowerCase();
  const resolvedRecipientName = name && String(name).trim().length > 0
    ? String(name).trim()
    : deriveNameFromEmail(normalizedEmail);

  const upperRole = String(role || 'CUSTOMER').toUpperCase();
  const roleTitle = upperRole === 'TECHNICIAN'
    ? 'Captain Partner'
    : (upperRole === 'ADMIN' ? 'Admin Portal' : 'Customer');

  const templateParams = {
    to_email: normalizedEmail,
    email: normalizedEmail,
    user_email: normalizedEmail,
    recipient_email: normalizedEmail,
    to_name: resolvedRecipientName,
    name: resolvedRecipientName,
    user_name: resolvedRecipientName,
    otp: otp || '',
    code: otp || '',
    verification_code: otp || '',
    passcode: otp || '',
    role: roleTitle,
    subject: subject || `[BookurTechnician] Your ${roleTitle} Verification Code: ${otp}`,
    message: `Your single-use verification OTP for BookurTechnician (${roleTitle}) is: ${otp}. Valid for 10 minutes.`,
    html_content: htmlContent || '',
    app_name: 'BookurTechnician',
  };

  const payload = {
    service_id: cfg.serviceId,
    template_id: cfg.templateId,
    user_id: cfg.publicKey,
    accessToken: cfg.privateKey,
    template_params: templateParams,
  };

  try {
    const response = await postEmailJsPayload(payload, cfg.origin, fetchImpl, 4500);
    return { success: true, configured: true, response };
  } catch (primaryErr) {
    if (cfg.fallbackTemplateId) {
      try {
        const fbRes = await postEmailJsPayload(
          { ...payload, template_id: cfg.fallbackTemplateId },
          cfg.origin,
          fetchImpl,
          3000
        );
        return { success: true, configured: true, response: fbRes, usedFallbackTemplate: true };
      } catch (_) {}
    }

    return {
      success: false,
      configured: true,
      code: 'EMAILJS_DISPATCH_FAILED',
      error: primaryErr.message || 'Failed to send email via EmailJS',
    };
  }
}

async function sendOtpEmail(email, otp, role = 'CUSTOMER', name = '', options = {}) {
  const resolvedName = name && String(name).trim().length > 0
    ? String(name).trim()
    : deriveNameFromEmail(email);

  const upperRole = String(role || 'CUSTOMER').toUpperCase();
  const roleTitle = upperRole === 'TECHNICIAN'
    ? 'Captain Partner'
    : (upperRole === 'ADMIN' ? 'Admin Portal' : 'Customer');

  const subject = `[BookurTechnician] Your ${roleTitle} Verification Code: ${otp}`;

  return sendEmailJsEmail(
    {
      to: email,
      name: resolvedName,
      subject,
      otp,
      role,
    },
    options
  );
}

module.exports = {
  deriveNameFromEmail,
  getEmailJsStatus,
  sendEmailJsEmail,
  sendOtpEmail,
};
