import React, { useState } from 'react';

export default function TechnicianIdCardManager({ technicians, setTechnicians, auditLogAction }) {
  const [selectedTech, setSelectedTech] = useState(technicians[0] || null);
  const [qrModalOpen, setQrModalOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const filteredTechs = technicians.filter(t =>
    t.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.category.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleToggleVerification = (techId, currentStatus) => {
    const nextStatus = currentStatus === 'Approved' ? 'Suspended' : 'Approved';
    setTechnicians(prev => prev.map(t => t.id === techId ? { ...t, status: nextStatus, kycStatus: nextStatus } : t));
    auditLogAction('Technician ID Verification', `Toggled verification status for ${techId} to ${nextStatus}`);
    if (selectedTech && selectedTech.id === techId) {
      setSelectedTech(prev => ({ ...prev, status: nextStatus, kycStatus: nextStatus }));
    }
  };

  const handleRegenerateQr = (techId) => {
    const newToken = `verify_${techId.toLowerCase()}_${Date.now()}`;
    auditLogAction('Technician ID Verification', `Regenerated secure public QR token for ${techId}: ${newToken}`);
    alert(`Public verification QR Token regenerated successfully for ${techId}!`);
  };

  const handleDownloadId = (tech) => {
    alert(`Downloading high-resolution Printable Digital ID Badge for ${tech.name} (${tech.id})...`);
  };

  return (
    <div className="id-card-manager-view">
      <div className="section-header">
        <div>
          <h2>Technician Digital ID Card Registry</h2>
          <p style={{ fontSize: '13px', color: '#64748B' }}>
            Permanent sequential ID auto-generation (BT-TECH-XXXXXX), live QR verification tokens, and compliance status.
          </p>
        </div>
      </div>

      <div className="id-card-layout-grid">
        {/* ─── LEFT: TECHNICIAN SELECTOR LIST ─── */}
        <div className="tech-selector-panel">
          <div className="search-box" style={{ marginBottom: '12px' }}>
            <input
              type="text"
              placeholder="Search technician name, ID..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>

          <div className="tech-cards-list">
            {filteredTechs.map(t => {
              const isSelected = selectedTech && selectedTech.id === t.id;
              const isApproved = t.status === 'Approved';
              return (
                <div
                  key={t.id}
                  className={`tech-select-card ${isSelected ? 'active' : ''}`}
                  onClick={() => setSelectedTech(t)}
                >
                  <div style={{
                    width: '36px',
                    height: '36px',
                    borderRadius: '50%',
                    backgroundColor: '#1E3A8A',
                    color: '#FFFFFF',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '800',
                    fontSize: '14px',
                    flexShrink: 0
                  }}>
                    {(t.name || 'T')[0].toUpperCase()}
                  </div>
                  <div className="tech-info">
                    <strong>{t.name}</strong>
                    <div style={{ fontSize: '11px', color: '#17399A', fontFamily: 'monospace' }}>
                      {t.id.startsWith('BT-TECH') ? t.id : `BT-TECH-00000${t.id.replace(/\D/g, '') || '1'}`}
                    </div>
                    <div style={{ fontSize: '11px', color: '#64748B' }}>{t.category}</div>
                  </div>
                  <span className={`badge ${isApproved ? 'success' : 'warning'}`}>
                    {isApproved ? 'Verified' : 'Pending'}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* ─── RIGHT: PREVIEW DIGITAL ID CARD & ACTIONS ─── */}
        {selectedTech && (
          <div className="id-card-preview-panel">
            <div className="digital-id-card-mockup">
              {/* Top Solid Header Bar */}
              <div className="id-header-bar">
                <div className="brand-badge-row">
                  <div className="brand-logo-circle">🛠️</div>
                  <span className="brand-title">BookurTechnician</span>
                </div>
                <div className="member-pill">TECHNICIAN MEMBER</div>
              </div>

              {/* Card Body */}
              <div className="id-card-body">
                <div className="avatar-frame-wrap">
                  <div style={{
                    width: '84px',
                    height: '84px',
                    borderRadius: '50%',
                    background: 'linear-gradient(135deg, #0B1F63 0%, #17399A 100%)',
                    border: '3px solid #38BDF8',
                    color: '#FFFFFF',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '900',
                    fontSize: '32px',
                    boxShadow: '0 4px 12px rgba(23,57,154,0.25)'
                  }}>
                    {(selectedTech.name || 'T')[0].toUpperCase()}
                  </div>
                  {selectedTech.status === 'Approved' && (
                    <div className="verified-check-bubble">✓</div>
                  )}
                </div>

                <h3 className="id-tech-name">{selectedTech.name}</h3>
                <p className="id-tech-role">Certified Field Technician</p>

                <div className="id-meta-box">
                  <div className="id-meta-row">
                    <span>Technician ID</span>
                    <strong style={{ color: '#17399A', fontFamily: 'monospace' }}>
                      {selectedTech.id.startsWith('BT-TECH') ? selectedTech.id : `BT-TECH-00000${selectedTech.id.replace(/\D/g, '') || '1'}`}
                    </strong>
                  </div>
                  <div className="id-meta-row">
                    <span>Joined Date</span>
                    <strong>15 August 2026</strong>
                  </div>
                  <div className="id-meta-row">
                    <span>Service Skills</span>
                    <strong>{selectedTech.category} • Handyman • Diagnostics</strong>
                  </div>
                </div>

                <div className={`id-status-badge ${selectedTech.status === 'Approved' ? 'approved' : 'pending'}`}>
                  {selectedTech.status === 'Approved' ? '✓ VERIFIED TECHNICIAN' : '⏳ VERIFICATION PENDING'}
                </div>

                {/* QR Code Trigger */}
                <div className="id-qr-trigger-box" onClick={() => setQrModalOpen(true)}>
                  <div className="qr-preview-icon">🔲</div>
                  <div style={{ textAlign: 'left' }}>
                    <div style={{ fontWeight: 'bold', fontSize: '12px' }}>Public QR Verification</div>
                    <div style={{ fontSize: '11px', color: '#64748B' }}>Tap to view safe public badge link</div>
                  </div>
                  <span style={{ fontSize: '12px', color: '#17399A' }}>🔍 Expand</span>
                </div>
              </div>
            </div>

            {/* Actions Bar */}
            <div className="id-card-actions-grid">
              <button className="btn primary" onClick={() => handleDownloadId(selectedTech)}>
                📥 Download ID Card (PNG)
              </button>
              <button className="btn outline" onClick={() => handleRegenerateQr(selectedTech.id)}>
                🔄 Regenerate QR Token
              </button>
              <button
                className={`btn ${selectedTech.status === 'Approved' ? 'danger' : 'success'}`}
                onClick={() => handleToggleVerification(selectedTech.id, selectedTech.status)}
              >
                {selectedTech.status === 'Approved' ? '🚫 Suspend ID Verification' : '✓ Re-activate Verification'}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ─── QR MODAL ─── */}
      {qrModalOpen && selectedTech && (
        <div className="modal-overlay" style={{ zIndex: 1200 }}>
          <div className="modal-card" style={{ maxWidth: '420px', textAlign: 'center' }}>
            <h3>Public QR Verification Badge</h3>
            <p style={{ fontSize: '12px', color: '#64748B', margin: '8px 0 16px' }}>
              Customers or building security scan this QR code. Only public certification data is displayed without sensitive personal info.
            </p>

            <div style={{ margin: '16px auto', padding: '16px', background: '#FFFFFF', border: '2px solid #E2E8F0', borderRadius: '16px', display: 'inline-block' }}>
              <div style={{ width: '160px', height: '160px', background: '#0F172A', color: '#FFF', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '8px', fontSize: '48px' }}>
                🔲
              </div>
            </div>

            <div style={{ background: '#F1F5F9', padding: '10px', borderRadius: '8px', fontSize: '11.5px', color: '#334155', fontFamily: 'monospace' }}>
              https://bookurtechnician.com/verify-tech/verify_{selectedTech.id.toLowerCase()}_token
            </div>

            <div className="modal-actions" style={{ marginTop: '20px' }}>
              <button className="btn primary" style={{ width: '100%' }} onClick={() => setQrModalOpen(false)}>
                Close Preview
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
