const axios = require('axios');

const EMAILJS_API_URL = 'https://api.emailjs.com/api/v1.0/email/send';

/**
 * Derive a clean, human-friendly full name from an email address
 * e.g., 'rahul.adhikary@gmail.com' -> 'Rahul Adhikary'
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
      .map(part => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(' ');
  } catch (_) {
    return 'Valued User';
  }
}

/**
 * Send Transactional Email using EmailJS REST API
 * @param {Object} params
 * @param {string} params.to - Recipient email address
 * @param {string} [params.name] - Recipient name
 * @param {string} params.subject - Email subject
 * @param {string} params.otp - OTP Code
 * @param {string} [params.role] - User Role (CUSTOMER / TECHNICIAN / ADMIN)
 * @param {string} [params.htmlContent] - Optional HTML Content
 */
async function sendEmailJsEmail({ to, name, subject, otp, role = 'CUSTOMER', htmlContent }) {
  const publicKey = process.env.EMAILJS_PUBLIC_KEY || 'hn2znBkgIi2lY8faY';
  const privateKey = process.env.EMAILJS_PRIVATE_KEY || 'DLj-DDHXaRY55ww2xu6Jg';
  const serviceId = process.env.EMAILJS_SERVICE_ID || 'service_u5wyepn';
  const templateId = process.env.EMAILJS_TEMPLATE_ID || 'template_gl8uwjj';

  const resolvedRecipientName = (name && name.trim().length > 0) 
    ? name.trim() 
    : deriveNameFromEmail(to);

  const roleTitle = role.toUpperCase() === 'TECHNICIAN' 
    ? 'Captain Partner' 
    : (role.toUpperCase() === 'ADMIN' ? 'Admin Portal' : 'Customer');

  // Multi-alias template params to ensure compatibility with any EmailJS template variable names
  const templateParams = {
    to_email: to.trim().toLowerCase(),
    email: to.trim().toLowerCase(),
    user_email: to.trim().toLowerCase(),
    recipient_email: to.trim().toLowerCase(),
    
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

  // Candidate service & template IDs to try for maximum delivery success
  const candidateServices = [
    serviceId,
    'service_default',
    'service_gmail',
    'service_bt',
  ].filter(Boolean);

  const candidateTemplates = [
    templateId,
    'template_otp',
    'template_default',
  ].filter(Boolean);

  let lastError = null;

  for (const sId of candidateServices) {
    for (const tId of candidateTemplates) {
      try {
        const payload = {
          service_id: sId,
          template_id: tId,
          user_id: publicKey,
          accessToken: privateKey,
          template_params: templateParams,
        };

        const response = await axios.post(EMAILJS_API_URL, payload, {
          headers: {
            'Content-Type': 'application/json',
            'Origin': 'https://bookurtechnician.online',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
          timeout: 10000,
        });

        console.log(`📧 [EmailJS] Email successfully sent to ${to} via service [${sId}] template [${tId}]. Response:`, response.data);
        return { success: true, response: response.data, serviceId: sId, templateId: tId };
      } catch (error) {
        lastError = error.response?.data || error.message;
        const statusCode = error.response?.status;
        
        if (statusCode === 403 && typeof lastError === 'string' && lastError.includes('non-browser environments')) {
          console.error(`🔒 [EmailJS Non-Browser API Notice] Please enable "Allow EmailJS API for non-browser applications" at https://dashboard.emailjs.com/admin/account/security`);
          return { success: false, error: 'EmailJS non-browser API access disabled. Please enable in EmailJS Security settings.' };
        }

        // If template or service not found, try next candidate
        if (statusCode === 400 || statusCode === 404) {
          continue;
        }
      }
    }
  }

  console.warn(`⚠️ [EmailJS Warning] Could not dispatch email to ${to}:`, lastError);
  return { success: false, error: lastError };
}

/**
 * Send OTP Verification Email using EmailJS
 * @param {string} email - Destination email
 * @param {string} otp - 6-digit OTP code
 * @param {string} role - USER / CUSTOMER / TECHNICIAN / ADMIN
 * @param {string} [name] - User name
 */
async function sendOtpEmail(email, otp, role = 'CUSTOMER', name = '') {
  const resolvedName = (name && name.trim().length > 0) 
    ? name.trim() 
    : deriveNameFromEmail(email);

  const roleTitle = role.toUpperCase() === 'TECHNICIAN' 
    ? 'Captain Partner' 
    : (role.toUpperCase() === 'ADMIN' ? 'Admin Portal' : 'Customer');

  const subject = `[BookurTechnician] Your ${roleTitle} Verification Code: ${otp}`;
  
  return sendEmailJsEmail({
    to: email,
    name: resolvedName,
    subject: subject,
    otp: otp,
    role: role,
  });
}

module.exports = {
  deriveNameFromEmail,
  sendEmailJsEmail,
  sendOtpEmail,
};
