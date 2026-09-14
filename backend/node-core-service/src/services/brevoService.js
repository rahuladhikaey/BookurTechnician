const axios = require('axios');

const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';

/**
 * Send Transactional Email using Brevo REST API
 * @param {Object} params
 * @param {string} params.to - Recipient email address
 * @param {string} [params.name] - Recipient name
 * @param {string} params.subject - Email subject
 * @param {string} params.htmlContent - HTML body content
 */
async function sendTransactionalEmail({ to, name, subject, htmlContent }) {
  const apiKey = process.env.BREVO_API_KEY;
  const senderEmail = process.env.BREVO_SENDER_EMAIL || 'noreply@asaliswad.com';
  const senderName = process.env.BREVO_SENDER_NAME || 'BookurTechnician';

  if (!apiKey) {
    console.warn('⚠️ [BrevoService] BREVO_API_KEY is not configured in environment. Skipping email delivery.');
    return { success: false, error: 'BREVO_API_KEY not configured' };
  }

  try {
    const payload = {
      sender: {
        name: senderName,
        email: senderEmail,
      },
      to: [
        {
          email: to,
          name: name || 'Valued User',
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

    console.log(`📧 [BrevoService] Email successfully sent to ${to}. MessageId:`, response.data?.messageId);
    return { success: true, messageId: response.data?.messageId };
  } catch (error) {
    const errorDetails = error.response?.data || error.message;
    console.error(`❌ [BrevoService] Failed to send email to ${to}:`, errorDetails);
    return { success: false, error: errorDetails };
  }
}

/**
 * Send OTP Verification Email
 * @param {string} email - Destination email
 * @param {string} otp - 6-digit OTP code
 * @param {string} role - USER / CUSTOMER / TECHNICIAN / ADMIN
 * @param {string} [name] - User name
 */
async function sendOtpEmail(email, otp, role = 'CUSTOMER', name = '') {
  const subject = `[BookurTechnician] Your ${role} Login Verification Code: ${otp}`;
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Verification Code</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f4f6f9; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b;">
      <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed;">
        <tr>
          <td align="center" style="padding: 40px 15px;">
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.08), 0 8px 10px -6px rgba(0, 0, 0, 0.04); border: 1px solid #e2e8f0;">
              
              <!-- Header -->
              <tr>
                <td style="background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); padding: 32px 30px; text-align: center;">
                  <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">
                    🔧 BookurTechnician
                  </h1>
                  <p style="margin: 6px 0 0 0; color: #bfdbfe; font-size: 14px;">Instant On-Demand Expert Services</p>
                </td>
              </tr>

              <!-- Body -->
              <tr>
                <td style="padding: 36px 32px 28px 32px;">
                  <h2 style="margin: 0 0 12px 0; color: #0f172a; font-size: 20px; font-weight: 600;">Verification Code</h2>
                  <p style="margin: 0 0 24px 0; color: #475569; font-size: 15px; line-height: 1.6;">
                    Hello ${name ? `<strong>${name}</strong>` : 'there'},<br>
                    Use the verification code below to securely sign in to your <strong>${role}</strong> account.
                  </p>

                  <!-- OTP Box -->
                  <div style="background-color: #f8fafc; border: 2px dashed #93c5fd; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px;">
                    <span style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #1d4ed8; display: inline-block;">
                      ${otp}
                    </span>
                    <p style="margin: 8px 0 0 0; font-size: 13px; color: #64748b;">Valid for <strong>5 minutes</strong> only</p>
                  </div>

                  <p style="margin: 0 0 8px 0; color: #64748b; font-size: 13px; line-height: 1.5;">
                    🔒 If you didn't request this code, you can safely ignore this email. Never share this code with anyone.
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="background-color: #f8fafc; padding: 20px 32px; border-top: 1px solid #e2e8f0; text-align: center;">
                  <p style="margin: 0; color: #94a3b8; font-size: 12px;">
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
    name: name,
    subject: subject,
    htmlContent: htmlContent,
  });
}

module.exports = {
  sendTransactionalEmail,
  sendOtpEmail,
};
