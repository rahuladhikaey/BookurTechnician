const axios = require('axios');

async function uploadDocBadge(name, title, color) {
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' width='600' height='380' viewBox='0 0 600 380'>
    <defs>
      <linearGradient id='grad' x1='0%' y1='0%' x2='100%' y2='100%'>
        <stop offset='0%' style='stop-color:${color};stop-opacity:1' />
        <stop offset='100%' style='stop-color:#0f172a;stop-opacity:1' />
      </linearGradient>
    </defs>
    <rect width='600' height='380' rx='16' fill='url(#grad)' />
    <rect x='16' y='16' width='568' height='348' rx='12' fill='#ffffff' fill-opacity='0.96' stroke='#e2e8f0' stroke-width='2'/>
    <rect x='36' y='36' width='80' height='80' rx='40' fill='${color}' fill-opacity='0.15'/>
    <text x='76' y='85' font-family='Arial, sans-serif' font-size='32' text-anchor='middle' fill='${color}'>✓</text>
    <text x='136' y='65' font-family='Arial, sans-serif' font-size='20' font-weight='bold' fill='#0f172a'>${title}</text>
    <text x='136' y='90' font-family='Arial, sans-serif' font-size='13' fill='#64748b'>GOVERNMENT OF INDIA / UIDAI COMPLIANT KYC</text>
    <line x1='36' y1='136' x2='564' y2='136' stroke='#e2e8f0' stroke-width='1.5'/>
    <text x='36' y='175' font-family='Arial, sans-serif' font-size='14' font-weight='bold' fill='#334155'>Partner Name: <tspan fill='#0f172a'>Technician Partner</tspan></text>
    <text x='36' y='210' font-family='Arial, sans-serif' font-size='14' font-weight='bold' fill='#334155'>Document Type: <tspan fill='${color}'>${name}</tspan></text>
    <text x='36' y='245' font-family='Arial, sans-serif' font-size='14' font-weight='bold' fill='#334155'>Status: <tspan fill='#059669'>VERIFIED ✓ (100% Complete)</tspan></text>
    <text x='36' y='280' font-family='Arial, sans-serif' font-size='13' fill='#64748b'>Digital Masked Document ID: •••• •••• 307a</text>
    <rect x='36' y='310' width='528' height='36' rx='6' fill='#f1f5f9'/>
    <text x='300' y='333' font-family='Arial, sans-serif' font-size='12' text-anchor='middle' font-weight='bold' fill='#475569'>🔒 100% Encrypted &amp; Authenticated Partner Document</text>
  </svg>`;

  try {
    const base64 = 'data:image/svg+xml;base64,' + Buffer.from(svg).toString('base64');
    const res = await axios.post('https://api.cloudinary.com/v1_1/p1ish280/image/upload', {
      file: base64,
      upload_preset: 'asaliswad_products'
    });
    console.log(name, '->', res.data.secure_url);
    return res.data.secure_url;
  } catch (err) {
    console.error('Error for', name, err.response ? err.response.data : err.message);
  }
}

async function main() {
  await uploadDocBadge('AADHAAR_CARD', 'AADHAAR CARD VERIFICATION', '#1e40af');
  await uploadDocBadge('VOTER_CARD', 'VOTER IDENTITY CARD (EPIC)', '#4338ca');
  await uploadDocBadge('LIVE_SELFIE', 'LIVE PARTNER SELFIE PHOTO', '#059669');
}

main();
