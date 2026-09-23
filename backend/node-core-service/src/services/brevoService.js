const axios = require('axios');

const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';

/**
 * Derive a clean, human-friendly full name from an email address
 * e.g., 'rahul.adhikary@gmail.com' -> 'Rahul Adhikary'
 * e.g., 'alex_turner99@domain.com' -> 'Alex Turner'
 */
function deriveNameFromEmail(email) {
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    return 'Valued User';
  }
  try {
    const prefix = email.split('@')[0];
    if (!prefix) return 'Valued User';
    
    // Remove trailing digits and clean special characters
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
 * Send Transactional Email using Brevo REST API with automatic sender fallbacks
 * @param {Object} params
 * @param {string} params.to - Recipient email address
 * @param {string} [params.name] - Recipient name
 * @param {string} params.subject - Email subject
 * @param {string} params.htmlContent - HTML body content
 */
async function sendTransactionalEmail({ to, name, subject, htmlContent }) {
  const apiKey = process.env.BREVO_API_KEY;
  const primarySenderEmail = process.env.BREVO_SENDER_EMAIL || 'noreply@asaliswad.com';
  const senderName = process.env.BREVO_SENDER_NAME || 'BookurTechnician Support';

  if (!apiKey) {
    console.warn('⚠️ [BrevoService] BREVO_API_KEY is not configured in environment. Skipping remote email dispatch.');
    return { success: false, error: 'BREVO_API_KEY not configured' };
  }

  const resolvedRecipientName = (name && name.trim().length > 0) 
    ? name.trim() 
    : deriveNameFromEmail(to);

  // Candidate senders for high resilience
  const candidateSenders = [
    { name: senderName, email: primarySenderEmail },
    { name: senderName, email: 'noreply@bookurtechnician.com' },
    { name: senderName, email: 'support@bookurtechnician.com' },
  ];

  let lastError = null;

  for (const sender of candidateSenders) {
    try {
      const payload = {
        sender: sender,
        to: [
          {
            email: to.trim().toLowerCase(),
            name: resolvedRecipientName,
          },
        ],
        subject: subject,
        htmlContent: htmlContent,
      };

      const response = await axios.post(BREVO_API_URL, payload, {
        headers: {
          'api-key': apiKey,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        timeout: 10000,
      });

      console.log(`📧 [BrevoService] Email successfully sent to ${to} via ${sender.email}. MessageId:`, response.data?.messageId);
      return { success: true, messageId: response.data?.messageId };
    } catch (error) {
      lastError = error.response?.data || error.message;
      console.warn(`⚠️ [BrevoService] Attempt with sender ${sender.email} failed:`, lastError);
      
      // If error is not sender-related (e.g., unauthorized API key), don't retry other senders
      if (error.response?.status === 401) {
        break;
      }
    }
  }

  console.error(`❌ [BrevoService] All Brevo sender attempts failed for ${to}:`, lastError);
  return { success: false, error: lastError };
}

/**
 * Send OTP Verification Email with modern high-contrast styling
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
  
  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Verification Code</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #0B0F19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #F8FAFC;">
      <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #0B0F19;">
        <tr>
          <td align="center" style="padding: 36px 16px;">
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #111827; border-radius: 20px; overflow: hidden; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7); border: 1px solid #1F2937;">
              
              <!-- Header -->
              <tr>
                <td style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); padding: 32px 28px; text-align: center; border-bottom: 2px solid #FDB813;">
                  <div style="display: inline-block; background-color: #FDB813; color: #0F172A; font-weight: 900; font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; padding: 4px 12px; border-radius: 9999px; margin-bottom: 12px;">
                    ${roleTitle} Access
                  </div>
                  <h1 style="margin: 0; color: #FFFFFF; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">
                    ⚡ BookurTechnician
                  </h1>
                  <p style="margin: 6px 0 0 0; color: #94A3B8; font-size: 13px;">Instant On-Demand Expert Services</p>
                </td>
              </tr>

              <!-- Body -->
              <tr>
                <td style="padding: 36px 32px 28px 32px;">
                  <h2 style="margin: 0 0 12px 0; color: #F8FAFC; font-size: 20px; font-weight: 700;">
                    Hello ${resolvedName},
                  </h2>
                  <p style="margin: 0 0 24px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.6;">
                    Here is your single-use verification code to log in or register your <strong>${roleTitle}</strong> account on the BookurTechnician platform.
                  </p>

                  <!-- OTP Box -->
                  <div style="background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%); border: 2px dashed #FDB813; border-radius: 14px; padding: 24px 20px; text-align: center; margin-bottom: 24px;">
                    <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 2px; color: #FDB813; font-weight: 800; margin-bottom: 8px;">
                      Your OTP Code
                    </div>
                    <span style="font-family: 'SF Mono', Monaco, Consolas, 'Courier New', monospace; font-size: 38px; font-weight: 900; letter-spacing: 10px; color: #FFFFFF; display: inline-block;">
                      ${otp}
                    </span>
                    <p style="margin: 10px 0 0 0; font-size: 12.5px; color: #94A3B8;">
                      ⏱️ Valid for <strong style="color: #F8FAFC;">10 minutes</strong>
                    </p>
                  </div>

                  <p style="margin: 0 0 12px 0; color: #64748B; font-size: 12.5px; line-height: 1.5;">
                    🔒 <strong>Security Tip:</strong> Never share this OTP with anyone, including support executives or delivery partners. BookurTechnician staff will never ask for your code.
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="background-color: #0F172A; padding: 20px 32px; border-top: 1px solid #1F2937; text-align: center;">
                  <p style="margin: 0; color: #64748B; font-size: 11.5px;">
                    © ${new Date().getFullYear()} BookurTechnician Platform. All rights reserved.
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;

  return sendTransactionalEmail({
    to: email,
    name: resolvedName,
    subject: subject,
    htmlContent: htmlContent,
  });
}

module.exports = {
  deriveNameFromEmail,
  sendTransactionalEmail,
  sendOtpEmail,
};

