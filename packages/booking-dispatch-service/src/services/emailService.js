const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp-relay.brevo.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: false,
  auth: {
    user: process.env.SMTP_USER || 'sample@asaliswad.com',
    pass: process.env.SMTP_PASS || 'sample_pass',
  },
});

async function sendEndServiceOtpEmail(customerEmail, customerName, bookingCode, endOtp) {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px; }
        .card { max-width: 520px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; border: 1px solid #E2E8F0; padding: 32px; box-shadow: 0 4px 14px rgba(0,0,0,0.05); }
        .header { text-align: center; border-bottom: 2px solid #ECFDF5; padding-bottom: 20px; }
        .brand-title { color: #1E3A8A; font-size: 22px; font-weight: 800; margin: 0; }
        .brand-sub { color: #059669; font-size: 13px; font-weight: 700; margin-top: 4px; }
        .badge { display: inline-block; background: #FEF3C7; color: #92400E; font-size: 12px; font-weight: 800; padding: 4px 12px; border-radius: 20px; margin-top: 12px; }
        .otp-box { background: #F0FDF4; border: 2px dashed #16A34A; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
        .otp-code { font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #166534; font-family: monospace; }
        .disclaimer { background: #FEF2F2; border-left: 4px solid #EF4444; padding: 12px 16px; border-radius: 6px; font-size: 12.5px; color: #991B1B; margin-top: 18px; line-height: 1.5; }
        .footer { text-align: center; margin-top: 28px; font-size: 12px; color: #94A3B8; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <h1 class="brand-title">BOOKURTECHNICIAN</h1>
          <p class="brand-sub">Service in Progress • Booking #${bookingCode}</p>
          <span class="badge">Valid for 24 Hours</span>
        </div>
        <p style="font-size: 15px; color: #1E293B; margin-top: 24px;">Hello <strong>${customerName || 'Valued Customer'}</strong>,</p>
        <p style="color: #475569; font-size: 13.5px; line-height: 1.6;">Your technician has started work on your service booking. Once the work is fully finished and inspected to your satisfaction, please share this <strong>4-digit Completion OTP</strong> with the technician to mark the job complete:</p>
        <div class="otp-box">
          <div class="otp-code">${endOtp}</div>
        </div>
        <div class="disclaimer">
          <strong>Safety Disclaimer:</strong> Please share this completion code ONLY after the service has been satisfactorily inspected. Do not share this code in advance.
        </div>
        <div class="footer">
          © 2026 BookurTechnician India. All rights reserved.
        </div>
      </div>
    </body>
    </html>
  `;

  try {
    await transporter.sendMail({
      from: '"BookurTechnician" <noreply@bookurtechnician.online>',
      to: customerEmail,
      subject: `Service Completion Code (${bookingCode}): ${endOtp}`,
      html,
    });
    console.log(`📧 End OTP email sent to ${customerEmail} for booking ${bookingCode}`);
  } catch (err) {
    console.warn(`⚠️ End OTP email send warning (Dev/Fallback mode): ${err.message}`);
  }
}

module.exports = {
  sendEndServiceOtpEmail,
};
