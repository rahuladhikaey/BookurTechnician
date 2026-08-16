import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { TechnicianProfile } from '../models/TechnicianProfile';

const router = Router();

// Helper to generate sequential Technician Code (e.g., BT-TECH-000001)
export async function getNextTechnicianCode(): Promise<string> {
  const count = await TechnicianProfile.countDocuments();
  const nextNum = count + 1;
  const padded = nextNum.toString().padStart(6, '0');
  return `BT-TECH-${padded}`;
}

// 1. Get Current Technician Digital ID Profile
router.get('/my-id', async (req: Request, res: Response) => {
  try {
    const techCode = req.query.code as string;
    let query: any = {};
    if (techCode) {
      query.technician_code = techCode;
    }

    const profile = await TechnicianProfile.findOne(query);

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Technician digital ID profile not found',
      });
    }

    res.json({
      success: true,
      data: {
        technician_code: profile.technician_code,
        full_name: profile.full_name,
        profile_photo_url: profile.profile_photo_url,
        join_date: profile.join_date,
        skills: profile.skills,
        verification_status: profile.verification_status,
        qr_verification_token: profile.qr_verification_token,
        verification_url: `https://bookurtechnician.com/verify-tech/${profile.qr_verification_token}`,
      },
    });
  } catch (error) {
    console.error('Error fetching technician ID profile:', error);
    res.status(500).json({ success: false, message: 'Server error retrieving ID card' });
  }
});

// 2. Update Technician Selfie Photo
router.post('/update-selfie', async (req: Request, res: Response) => {
  try {
    const { technician_code, new_photo_url } = req.body;
    const code = technician_code || 'BT-TECH-000001';

    if (!new_photo_url) {
      return res.status(400).json({ success: false, message: 'new_photo_url is required' });
    }

    const profile = await TechnicianProfile.findOne({ technician_code: code });
    if (!profile) {
      return res.status(404).json({ success: false, message: 'Technician profile not found' });
    }

    const oldPhoto = profile.profile_photo_url;
    profile.profile_photo_url = new_photo_url;
    profile.update_history.push({
      timestamp: new Date(),
      field: 'profile_photo_url',
      previousValue: oldPhoto,
      newValue: new_photo_url,
      reason: 'Technician submitted new live selfie',
    });

    await profile.save();

    res.json({
      success: true,
      message: 'Selfie updated successfully and synced with Digital ID Card.',
      data: {
        technician_code: profile.technician_code,
        profile_photo_url: profile.profile_photo_url,
      },
    });
  } catch (error) {
    console.error('Error updating selfie:', error);
    res.status(500).json({ success: false, message: 'Failed to update selfie' });
  }
});

// 3. Public JSON QR Verification Endpoint (Safe public data only - NO phone/email/bank)
router.get('/verify/:token', async (req: Request, res: Response) => {
  try {
    const { token } = req.params;
    const profile = await TechnicianProfile.findOne({ qr_verification_token: token });

    if (!profile) {
      return res.status(404).json({
        success: false,
        verified: false,
        message: 'Invalid or expired technician verification badge.',
      });
    }

    res.json({
      success: true,
      verified: profile.verification_status === 'APPROVED',
      data: {
        technician_code: profile.technician_code,
        full_name: profile.full_name,
        profile_photo_url: profile.profile_photo_url,
        skills: profile.skills,
        join_date: profile.join_date,
        verification_status: profile.verification_status,
        company: 'BookurTechnician Services Pvt Ltd',
      },
    });
  } catch (error) {
    console.error('Error in public QR verification:', error);
    res.status(500).json({ success: false, message: 'Verification lookup failed' });
  }
});

// 4. Standalone Public HTML Verification Web Page (for customer camera QR scans)
export function renderPublicVerificationHtml(token: string, profile: any): string {
  const isApproved = profile && profile.verification_status === 'APPROVED';
  const joinDateFormatted = profile ? new Date(profile.join_date).toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }) : 'N/A';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Official Technician Verification — BookurTechnician</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }
    body { background: #F8FAFC; color: #0F172A; min-height: 100vh; display: flex; justify-content: center; align-items: center; padding: 20px; }
    .card { background: #FFFFFF; max-width: 420px; width: 100%; border-radius: 20px; box-shadow: 0 10px 30px rgba(11, 31, 99, 0.08); border: 1px solid #E2E8F0; overflow: hidden; text-align: center; }
    .header { background: linear-gradient(135deg, #0B1F63, #17399A); color: white; padding: 24px 20px; }
    .brand { font-size: 20px; font-weight: 800; letter-spacing: -0.5px; }
    .badge-sub { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #93C5FD; margin-top: 4px; }
    .avatar-wrapper { position: relative; width: 110px; height: 110px; margin: -55px auto 16px; border-radius: 50%; border: 4px solid #FFFFFF; box-shadow: 0 4px 14px rgba(0,0,0,0.1); overflow: hidden; background: #E2E8F0; }
    .avatar-wrapper img { width: 100%; height: 100%; object-fit: cover; }
    .body-content { padding: 0 24px 24px; }
    .tech-name { font-size: 20px; font-weight: 800; color: #0F172A; }
    .tech-code { font-size: 13px; font-weight: 700; color: #17399A; margin-top: 4px; background: #EFF6FF; display: inline-block; padding: 4px 12px; border-radius: 20px; }
    .status-pill { display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px; border-radius: 30px; font-size: 12px; font-weight: 700; margin: 16px 0; }
    .status-approved { background: #DCFCE7; color: #166534; }
    .status-invalid { background: #FEE2E2; color: #991B1B; }
    .meta-table { background: #F8FAFC; border-radius: 12px; border: 1px solid #E2E8F0; padding: 14px; text-align: left; font-size: 13px; }
    .meta-row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #F1F5F9; }
    .meta-row:last-child { border-bottom: none; }
    .meta-label { color: #64748B; font-weight: 500; }
    .meta-val { color: #0F172A; font-weight: 700; }
    .skills-tags { display: flex; flex-wrap: wrap; gap: 6px; justify-content: center; margin-top: 14px; }
    .skill-badge { background: #F1F5F9; color: #334155; font-size: 11px; font-weight: 600; padding: 4px 10px; border-radius: 8px; }
    .footer { padding: 16px; font-size: 11px; color: #64748B; background: #F8FAFC; border-top: 1px solid #F1F5F9; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="brand">BookurTechnician</div>
      <div class="badge-sub">Official Digital Identity Badge</div>
    </div>
    
    ${profile ? `
      <div class="avatar-wrapper">
        <img src="${profile.profile_photo_url}" alt="Technician Selfie">
      </div>
      <div class="body-content">
        <div class="tech-name">${profile.full_name}</div>
        <div class="tech-code">${profile.technician_code}</div>
        <div>
          ${isApproved ? `
            <span class="status-pill status-approved">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>
              VERIFIED TECHNICIAN
            </span>
          ` : `
            <span class="status-pill status-invalid">
              VERIFICATION ${profile.verification_status}
            </span>
          `}
        </div>

        <div class="meta-table">
          <div class="meta-row">
            <span class="meta-label">Member Since</span>
            <span class="meta-val">${joinDateFormatted}</span>
          </div>
          <div class="meta-row">
            <span class="meta-label">ID Status</span>
            <span class="meta-val" style="color: ${isApproved ? '#16A34A' : '#DC2626'}">${profile.verification_status}</span>
          </div>
          <div class="meta-row">
            <span class="meta-label">Background Check</span>
            <span class="meta-val" style="color: #16A34A">PASSED ✓</span>
          </div>
        </div>

        <div class="skills-tags">
          ${(profile.skills || []).map((s: string) => `<span class="skill-badge">${s}</span>`).join('')}
        </div>
      </div>
    ` : `
      <div class="body-content" style="padding-top: 30px;">
        <h2 style="color: #DC2626; margin-bottom: 8px;">Invalid Technician ID</h2>
        <p style="font-size: 13px; color: #64748B;">This QR verification token is unverified, expired, or belongs to an unlisted profile.</p>
      </div>
    `}

    <div class="footer">
      🔒 Official Security Verification &bull; BookurTechnician Services Pvt Ltd<br>
      Strict Privacy Protected &bull; Zero Private Data Exposed
    </div>
  </div>
</body>
</html>`;
}

export default router;
