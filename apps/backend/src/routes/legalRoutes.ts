import { Router, Request, Response } from 'express';

const router = Router();

const getHtmlTemplate = (title: string, contentHtml: string) => `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} | BookUrTechnician</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #1E3A8A;
      --primary-accent: #3B82F6;
      --text-dark: #0F172A;
      --text-muted: #475569;
      --bg-page: #F8FAFC;
      --bg-card: #FFFFFF;
      --border: #E2E8F0;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background-color: var(--bg-page);
      color: var(--text-dark);
      line-height: 1.7;
      padding: 0;
      margin: 0;
    }
    header {
      background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%);
      color: #FFFFFF;
      padding: 40px 24px;
      text-align: center;
    }
    .header-content {
      max-width: 800px;
      margin: 0 auto;
    }
    .brand {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: #FFFFFF;
      text-decoration: none;
      display: inline-block;
      margin-bottom: 12px;
    }
    .brand span {
      color: #60A5FA;
    }
    h1 {
      font-size: 32px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin-bottom: 8px;
    }
    .subtitle {
      color: #CBD5E1;
      font-size: 14px;
    }
    main {
      max-width: 860px;
      margin: -24px auto 60px;
      padding: 0 16px;
    }
    .content-card {
      background: var(--bg-card);
      border-radius: 16px;
      padding: 40px 36px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.01);
      border: 1px solid var(--border);
    }
    h2 {
      font-size: 20px;
      font-weight: 700;
      color: var(--primary);
      margin-top: 32px;
      margin-bottom: 14px;
      border-bottom: 2px solid #EFF6FF;
      padding-bottom: 8px;
    }
    h3 {
      font-size: 16px;
      font-weight: 600;
      color: var(--text-dark);
      margin-top: 20px;
      margin-bottom: 8px;
    }
    p {
      color: var(--text-muted);
      margin-bottom: 16px;
      font-size: 15px;
    }
    ul, ol {
      margin-left: 24px;
      margin-bottom: 20px;
      color: var(--text-muted);
      font-size: 15px;
    }
    li {
      margin-bottom: 8px;
    }
    strong {
      color: var(--text-dark);
    }
    .highlight-box {
      background-color: #EFF6FF;
      border-left: 4px solid var(--primary-accent);
      padding: 16px 20px;
      border-radius: 8px;
      margin: 20px 0;
      font-size: 14px;
      color: #1E40AF;
    }
    .table-wrapper {
      overflow-x: auto;
      margin: 20px 0;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
      text-align: left;
    }
    th, td {
      padding: 12px 16px;
      border: 1px solid var(--border);
    }
    th {
      background-color: #F1F5F9;
      color: var(--text-dark);
      font-weight: 700;
    }
    footer {
      text-align: center;
      padding: 30px 20px;
      font-size: 13px;
      color: #94A3B8;
      border-top: 1px solid var(--border);
      background-color: #FFFFFF;
    }
    footer a {
      color: var(--primary-accent);
      text-decoration: none;
      margin: 0 10px;
    }
    @media (max-width: 600px) {
      .content-card {
        padding: 24px 18px;
      }
      h1 {
        font-size: 24px;
      }
    }
  </style>
</head>
<body>
  <header>
    <div class="header-content">
      <a href="/" class="brand">bookur<span>technician</span></a>
      <h1>${title}</h1>
      <div class="subtitle">Effective Date: August 15, 2026 | Bengaluru, India</div>
    </div>
  </header>
  <main>
    <div class="content-card">
      ${contentHtml}
    </div>
  </main>
  <footer>
    <p>&copy; 2026 BookUrTechnician Technologies Pvt. Ltd. All rights reserved.</p>
    <div style="margin-top: 8px;">
      <a href="/privacy-policy">Privacy Policy</a> |
      <a href="/terms-and-conditions">Terms of Service</a> |
      <a href="/cancellation-policy">Cancellation & Refunds</a> |
      <a href="/partner-terms">Partner Terms</a>
    </div>
  </footer>
</body>
</html>
`;

// HTML - Privacy Policy
router.get('/privacy-policy', (req: Request, res: Response) => {
  const content = `
    <div class="highlight-box">
      <strong>Transparency Notice:</strong> BookUrTechnician is committed to protecting your privacy in accordance with the Digital Personal Data Protection Act (DPDP Act, 2023) and IT Act 2000.
    </div>

    <h2>1. Overview & Data Controller</h2>
    <p>BookUrTechnician Technologies Private Limited ("BookUrTechnician", "we", "us", or "our") operates an on-demand hyperlocal home services platform connecting consumers with qualified technician partners. This policy outlines how we collect, use, and protect your information across our apps, websites, and APIs.</p>

    <h2>2. Data We Collect</h2>
    <ul>
      <li><strong>Account & Contact Info:</strong> Full Name, Mobile Number, Email Address, and saved Delivery Addresses.</li>
      <li><strong>Live Geolocation:</strong> Precise GPS coordinates (when permitted) for technician routing, distance computation, and live telemetry tracking.</li>
      <li><strong>Appliance & Service Details:</strong> Machine brand/model, issue description, diagnostics photos/audio notes.</li>
      <li><strong>Payment Tokens:</strong> Encrypted transaction reference IDs from authorized gateways (Razorpay/Stripe). We never store raw card numbers or CVV codes.</li>
      <li><strong>Masked Calling Logs:</strong> Anonymized timestamps and bridge durations when calling technicians via our privacy relay.</li>
    </ul>

    <h2>3. How Your Data is Used</h2>
    <ol>
      <li>Matching and dispatching certified local technicians to your exact doorstep.</li>
      <li>Providing live on-map tracking and estimated arrival times (ETA).</li>
      <li>Safeguarding personal telephone numbers using cloud telephony masking.</li>
      <li>Generating GST-compliant tax invoices and managing 30-day service warranties.</li>
      <li>Preventing platform abuse, fraud, and conducting safety investigations.</li>
    </ol>

    <h2>4. Third-Party Sharing & Safeguards</h2>
    <p>We do not sell personal data to third parties. Data is shared strictly on a need-to-know basis with:</p>
    <ul>
      <li><strong>Assigned Technicians:</strong> Name, address, and issue details required to fulfill your booked service.</li>
      <li><strong>Infrastructure & Gateways:</strong> AWS/Google Cloud (Secure hosting), Razorpay (Payments), Brevo (OTP email delivery), Mapbox/Google Maps (Location routing).</li>
      <li><strong>Law Enforcement:</strong> Solely when mandated by valid legal warrants or statutory inquiries.</li>
    </ul>

    <h2>5. Your Rights (DPDP Act 2023)</h2>
    <p>You have the right to inspect your saved data, update incorrect information, or request permanent deletion of your account via <strong>Profile > Settings > Delete Account</strong> or by emailing <code>privacy@bookurtechnician.com</code>.</p>

    <h2>6. Grievance Redressal Officer</h2>
    <p><strong>Grievance & Data Protection Officer:</strong></p>
    <p>BookUrTechnician Technologies Pvt. Ltd.<br>
    HSR Layout, Sector 7, Bengaluru, Karnataka, 560102, India<br>
    Email: <code>privacy@bookurtechnician.com</code> | Phone: +91 98765 43210</p>
  `;
  res.send(getHtmlTemplate('Privacy Policy', content));
});

// HTML - Terms of Service
router.get('/terms-and-conditions', (req: Request, res: Response) => {
  const content = `
    <div class="highlight-box">
      <strong>Important Legal Contract:</strong> Please review these Terms carefully before using the BookUrTechnician platform or booking home repair services.
    </div>

    <h2>1. Acceptance of Terms</h2>
    <p>By registering, accessing, or placing a booking on BookUrTechnician, you enter into a legally binding contract with BookUrTechnician Technologies Private Limited governed by the laws of India.</p>

    <h2>2. Platform Role & Intermediary Status</h2>
    <p>BookUrTechnician provides a digital marketplace connecting users with independent service technicians. While we perform stringent background verification and quality audits, technicians perform services as independent contractors.</p>

    <h2>3. Diagnostic Visiting Fees & Standard Quotations</h2>
    <ul>
      <li>A standardized diagnostic/visiting fee is charged for technician doorstep visits and fault inspection.</li>
      <li>If you approve the repair quotation, the visiting fee is adjusted into the final labor invoice.</li>
      <li>If you decline repairs after on-site inspection, the visiting fee compensates the technician for travel and diagnostic time.</li>
      <li>All spare parts are billed transparently according to standardized in-app rate cards.</li>
    </ul>

    <h2>4. 30-Day Workmanship Guarantee</h2>
    <p>BookUrTechnician offers a complimentary <strong>30-Day Service Guarantee</strong> for qualifying repairs. If the exact same issue recurs within 30 calendar days, we provide a free technician re-visit and rework at zero labor cost.</p>

    <h2>5. Customer Code of Conduct</h2>
    <p>Customers must provide a safe working environment, ensure an adult (18+) is present during the visit, and treat service partners with respect. Verbal harassment, physical threats, or intoxication will result in immediate cancellation and account suspension.</p>

    <h2>6. Limitation of Liability</h2>
    <p>To the fullest extent permitted by law, BookUrTechnician's total aggregate liability for any booking claim shall not exceed the amount paid for that specific service booking or ₹5,000, whichever is lower.</p>

    <h2>7. Governing Law & Jurisdiction</h2>
    <p>These terms are governed by the laws of India. Any unresolved disputes shall be subject to the exclusive jurisdiction of the civil courts in Bengaluru, Karnataka, India.</p>
  `;
  res.send(getHtmlTemplate('Terms and Conditions', content));
});

// HTML - Cancellation & Refund Policy
router.get('/cancellation-policy', (req: Request, res: Response) => {
  const content = `
    <h2>1. Cancellation Fee Structure</h2>
    <div class="table-wrapper">
      <table>
        <thead>
          <tr>
            <th>Cancellation Stage</th>
            <th>Applicable Fee</th>
            <th>Refund Amount</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>&gt; 2 Hours before slot</td>
            <td><strong>₹0 (Free)</strong></td>
            <td>100% Full Refund</td>
          </tr>
          <tr>
            <td>Within 2 Hours (Tech not en-route)</td>
            <td><strong>₹0 (Free)</strong></td>
            <td>100% Full Refund</td>
          </tr>
          <tr>
            <td>After Technician is En-Route</td>
            <td>₹50 - ₹100 Doorstep Travel Fee</td>
            <td>Prepaid balance refunded</td>
          </tr>
          <tr>
            <td>After Technician Arrives at Doorstep</td>
            <td>Standard Visiting Fee (₹99 - ₹199)</td>
            <td>Diagnostic fee retained</td>
          </tr>
          <tr>
            <td>Cancelled by BookUrTechnician</td>
            <td><strong>₹0 Fee + ₹50 Credit</strong></td>
            <td>100% Full Refund</td>
          </tr>
        </tbody>
      </table>
    </div>

    <h2>2. Refund Turnaround Times</h2>
    <ul>
      <li><strong>UPI / Instant Wallets:</strong> 1 to 2 business hours.</li>
      <li><strong>Debit Cards & Net Banking:</strong> 3 to 5 banking days.</li>
      <li><strong>Credit Cards:</strong> 5 to 7 billing cycle business days.</li>
    </ul>

    <h2>3. Rescheduling Bookings</h2>
    <p>You can reschedule your appointment free of charge up to 1 hour before the scheduled time slot directly within the App via <strong>Booking History > Reschedule</strong>.</p>
  `;
  res.send(getHtmlTemplate('Cancellation & Refund Policy', content));
});

// HTML - Partner Terms
router.get('/partner-terms', (req: Request, res: Response) => {
  const content = `
    <h2>1. Technician Partner Agreement</h2>
    <p>This agreement outlines the obligations, payout structures, code of conduct, and background verification standards for independent service partners on BookUrTechnician Pro.</p>

    <h2>2. Verification & Safety Standards</h2>
    <ul>
      <li>Mandatory Aadhaar, PAN, and Police Background verification before network activation.</li>
      <li>Mandatory adherence to electrical, HVAC, and mechanical safety protocols including PPE usage.</li>
      <li>Zero tolerance for overcharging, off-app private transactions, or unauthorized parts replacement.</li>
    </ul>

    <h2>3. Payouts & Settlement</h2>
    <p>Partner earnings and tips are settled every Tuesday directly into your registered bank account via automated bank transfer.</p>
  `;
  res.send(getHtmlTemplate('Partner Terms of Service', content));
});

// JSON API Endpoints
router.get('/api/legal/privacy', (req: Request, res: Response) => {
  res.json({
    status: 'success',
    title: 'Privacy Policy',
    version: '2026-08-15',
    dpo_email: 'privacy@bookurtechnician.com',
    governing_regulation: 'DPDP Act 2023 & IT Act 2000',
    web_url: 'https://bookurtechnician.com/privacy-policy',
  });
});

router.get('/api/legal/terms', (req: Request, res: Response) => {
  res.json({
    status: 'success',
    title: 'Terms of Service',
    version: '2026-08-15',
    warranty_period_days: 30,
    arbitration_city: 'Bengaluru, India',
    web_url: 'https://bookurtechnician.com/terms-and-conditions',
  });
});

export default router;
