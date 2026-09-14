import React, { useState, useCallback } from 'react';

export default function TechnicianIdCardManager({ technicians = [], setTechnicians, auditLogAction, onReload, isSyncing = false }) {
  const safeTechs = Array.isArray(technicians) ? technicians : [];
  const [selectedTech, setSelectedTech] = useState(safeTechs[0] || null);
  const [qrModalOpen, setQrModalOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [localRefreshing, setLocalRefreshing] = useState(false);

  const isSpinning = isSyncing || localRefreshing || loading;

  const handleRefreshTechs = useCallback(async () => {
    setLocalRefreshing(true);
    setLoading(true);
    try {
      if (onReload) {
        await onReload();
      }
    } catch (err) {
      console.error('Error refreshing technician credentials:', err);
    } finally {
      setLoading(false);
      setTimeout(() => setLocalRefreshing(false), 300);
    }
  }, [onReload]);

  const filteredTechs = safeTechs.filter(t => {
    const name = (t.name || t.fullName || '').toLowerCase();
    const id = (t.id || t.code || '').toLowerCase();
    const cat = (t.category || '').toLowerCase();
    const query = searchQuery.toLowerCase();
    return name.includes(query) || id.includes(query) || cat.includes(query);
  });

  const handleToggleVerification = (techId, currentStatus) => {
    const nextStatus = currentStatus === 'Approved' || currentStatus === 'VERIFIED' ? 'Suspended' : 'Approved';
    if (setTechnicians) {
      setTechnicians(prev => prev.map(t => t.id === techId ? { ...t, status: nextStatus, kycStatus: nextStatus } : t));
    }
    auditLogAction?.('Technician ID Verification', `Toggled verification status for ${techId} to ${nextStatus}`);
    if (selectedTech && selectedTech.id === techId) {
      setSelectedTech(prev => ({ ...prev, status: nextStatus, kycStatus: nextStatus }));
    }
  };

  const handleRegenerateQr = (techId) => {
    const newToken = `verify_${String(techId).toLowerCase()}_${Date.now()}`;
    auditLogAction?.('Technician ID Verification', `Regenerated secure public QR token for ${techId}: ${newToken}`);
    alert(`Public verification QR Token regenerated successfully for ${techId}!`);
  };

  const handleDownloadId = (tech) => {
    alert(`Downloading high-resolution Printable Digital ID Badge for ${tech?.name || tech?.fullName || 'Technician'} (${tech?.id || 'ID'})...`);
  };

  const techToDisplay = selectedTech || safeTechs[0];

  return (
    <div className="id-card-manager-view" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1 className="page-title">Technician Digital Credential & ID Registry</h1>
          <p className="page-subtitle">
            Enterprise ID generator (BT-TECH-XXXXXX), cryptographic QR verification tokens, and compliance security badges.
          </p>
        </div>
        <div className="page-actions-group">
          <button 
            className="btn btn-outline btn-sm" 
            onClick={handleRefreshTechs} 
            disabled={isSpinning}
            title="Refresh technician directory"
          >
            <span className={isSpinning ? 'spin-icon' : ''}>🔄</span> {isSpinning ? 'Refreshing...' : 'Refresh Credentials'}
          </button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(300px, 360px) 1fr', gap: '24px', alignItems: 'start' }}>
        {/* ─── LEFT: TECHNICIAN SELECTOR LIST ─── */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">
              <span>👨‍🔧</span>
              <span>Select Technician</span>
            </h3>
            <span className="badge badge-royal">{filteredTechs.length} Total</span>
          </div>

          <div className="card-body" style={{ padding: '16px' }}>
            <div style={{ marginBottom: '14px' }}>
              <input
                type="text"
                className="form-control"
                placeholder="Search by name, ID, skill..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '520px', overflowY: 'auto' }}>
              {filteredTechs.length === 0 ? (
                <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '13px' }}>
                  No technicians match your search query.
                </div>
              ) : (
                filteredTechs.map(t => {
                  const isSelected = techToDisplay && (techToDisplay.id === t.id);
                  const isApproved = t.status === 'Approved' || t.kycStatus === 'VERIFIED' || t.kycStatus === 'APPROVED';
                  const name = t.name || t.fullName || 'Technician';
                  const displayId = t.id?.startsWith('BT-TECH') ? t.id : `BT-TECH-00000${String(t.id).replace(/\D/g, '') || '1'}`;

                  return (
                    <div
                      key={t.id}
                      onClick={() => setSelectedTech(t)}
                      style={{
                        padding: '12px 14px',
                        borderRadius: 'var(--radius-md)',
                        border: isSelected ? '1.5px solid var(--royal-blue)' : '1px solid var(--border-color)',
                        backgroundColor: isSelected ? 'var(--royal-blue-light)' : '#FFFFFF',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '12px',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <div style={{
                        width: '38px',
                        height: '38px',
                        borderRadius: 'var(--radius-full)',
                        backgroundColor: 'var(--bg-sidebar)',
                        color: '#FFFFFF',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontWeight: '800',
                        fontSize: '14px',
                        flexShrink: 0
                      }}>
                        {name[0].toUpperCase()}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: '700', fontSize: '13.5px', color: 'var(--text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {name}
                        </div>
                        <div style={{ fontSize: '11px', color: 'var(--royal-blue)', fontFamily: 'monospace', fontWeight: '700' }}>
                          {displayId}
                        </div>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {t.category || 'Certified Expert'}
                        </div>
                      </div>
                      <span className={`badge ${isApproved ? 'badge-success' : 'badge-warning'}`} style={{ fontSize: '10px' }}>
                        {isApproved ? 'Verified' : 'Pending'}
                      </span>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>

        {/* ─── RIGHT: PREVIEW DIGITAL ID CARD & ACTIONS ─── */}
        {techToDisplay ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div className="card" style={{ maxWidth: '460px', margin: '0 auto', width: '100%', boxShadow: 'var(--shadow-lg)' }}>
              {/* Top Obsidian Black & Royal Blue Header Banner */}
              <div style={{
                background: 'linear-gradient(135deg, #080C16 0%, #172554 100%)',
                padding: '20px 24px',
                borderBottom: '3px solid var(--royal-blue)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                color: '#FFFFFF'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{
                    width: '36px',
                    height: '36px',
                    background: 'var(--royal-blue)',
                    borderRadius: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '18px'
                  }}>
                    🛠️
                  </div>
                  <div>
                    <div style={{ fontWeight: '900', fontSize: '15px', letterSpacing: '0.5px' }}>BookurTechnician</div>
                    <div style={{ fontSize: '9.5px', color: '#93C5FD', fontWeight: '800', letterSpacing: '1px' }}>OFFICIAL VERIFIED BADGE</div>
                  </div>
                </div>
                <div style={{
                  background: 'rgba(37, 99, 235, 0.25)',
                  border: '1px solid var(--royal-blue)',
                  color: '#93C5FD',
                  padding: '3px 8px',
                  borderRadius: '12px',
                  fontSize: '9.5px',
                  fontWeight: '800'
                }}>
                  FIELD PARTNER
                </div>
              </div>

              {/* Card Body */}
              <div style={{ padding: '24px', textAlign: 'center', backgroundColor: '#FFFFFF' }}>
                <div style={{ position: 'relative', display: 'inline-block', marginBottom: '14px' }}>
                  <div style={{
                    width: '90px',
                    height: '90px',
                    borderRadius: 'var(--radius-full)',
                    background: 'linear-gradient(135deg, #080C16 0%, #1E40AF 100%)',
                    border: '3px solid var(--royal-blue)',
                    color: '#FFFFFF',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '900',
                    fontSize: '34px',
                    boxShadow: '0 4px 14px rgba(37,99,235,0.3)',
                    margin: '0 auto'
                  }}>
                    {(techToDisplay.name || techToDisplay.fullName || 'T')[0].toUpperCase()}
                  </div>
                  {(techToDisplay.status === 'Approved' || techToDisplay.kycStatus === 'VERIFIED') && (
                    <div style={{
                      position: 'absolute',
                      bottom: '2px',
                      right: '2px',
                      width: '26px',
                      height: '26px',
                      borderRadius: 'var(--radius-full)',
                      background: 'var(--status-green)',
                      color: '#FFFFFF',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontWeight: '900',
                      fontSize: '14px',
                      border: '2px solid #FFFFFF'
                    }}>
                      ✓
                    </div>
                  )}
                </div>

                <h3 style={{ fontSize: '18px', fontWeight: '900', color: 'var(--text-main)', margin: '0 0 4px' }}>
                  {techToDisplay.name || techToDisplay.fullName}
                </h3>
                <p style={{ fontSize: '12.5px', color: 'var(--text-secondary)', margin: '0 0 16px', fontWeight: '600' }}>
                  Certified Field Technician
                </p>

                {/* Metadata Box */}
                <div style={{
                  background: '#F8FAFC',
                  border: '1px solid var(--border-color)',
                  borderRadius: 'var(--radius-md)',
                  padding: '14px',
                  marginBottom: '16px',
                  textAlign: 'left',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px' }}>
                    <span style={{ color: 'var(--text-muted)' }}>Technician ID</span>
                    <strong style={{ color: 'var(--royal-blue)', fontFamily: 'monospace' }}>
                      {techToDisplay.id?.startsWith('BT-TECH') ? techToDisplay.id : `BT-TECH-00000${String(techToDisplay.id).replace(/\D/g, '') || '1'}`}
                    </strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px' }}>
                    <span style={{ color: 'var(--text-muted)' }}>Primary Domain</span>
                    <strong>{techToDisplay.category || 'All Round Expert'}</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px' }}>
                    <span style={{ color: 'var(--text-muted)' }}>Verification Status</span>
                    <span className={`badge ${techToDisplay.status === 'Approved' || techToDisplay.kycStatus === 'VERIFIED' ? 'badge-success' : 'badge-warning'}`} style={{ fontSize: '10px' }}>
                      {techToDisplay.status === 'Approved' || techToDisplay.kycStatus === 'VERIFIED' ? '✓ VERIFIED' : '⏳ PENDING'}
                    </span>
                  </div>
                </div>

                {/* QR Code Trigger Button */}
                <div
                  onClick={() => setQrModalOpen(true)}
                  style={{
                    padding: '12px 16px',
                    border: '1px dashed var(--royal-border)',
                    borderRadius: 'var(--radius-md)',
                    background: 'var(--royal-blue-light)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    cursor: 'pointer'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontSize: '20px' }}>🔲</span>
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontWeight: '700', fontSize: '12.5px', color: 'var(--royal-blue-dark)' }}>Public QR Verification</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Tap to inspect security token badge</div>
                    </div>
                  </div>
                  <span style={{ fontSize: '12px', fontWeight: '700', color: 'var(--royal-blue)' }}>Expand ↗</span>
                </div>
              </div>
            </div>

            {/* Action Buttons Toolbar */}
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', flexWrap: 'wrap' }}>
              <button className="btn btn-royal" onClick={() => handleDownloadId(techToDisplay)}>
                <span>📥</span>
                <span>Download Printable ID</span>
              </button>
              <button className="btn btn-outline" onClick={() => handleRegenerateQr(techToDisplay.id)}>
                <span>🔄</span>
                <span>Regenerate QR Token</span>
              </button>
              <button
                className={`btn ${techToDisplay.status === 'Approved' || techToDisplay.kycStatus === 'VERIFIED' ? 'btn-dark' : 'btn-royal'}`}
                onClick={() => handleToggleVerification(techToDisplay.id, techToDisplay.status || techToDisplay.kycStatus)}
              >
                {techToDisplay.status === 'Approved' || techToDisplay.kycStatus === 'VERIFIED' ? '🚫 Suspend Verification' : '✓ Approve & Issue Badge'}
              </button>
            </div>
          </div>
        ) : (
          <div className="card" style={{ padding: '60px 20px', textAlign: 'center' }}>
            <div style={{ fontSize: '36px', marginBottom: '12px' }}>🪪</div>
            <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-main)' }}>No Technician Selected</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Select a technician from the directory list on the left to view their digital identity card.
            </p>
          </div>
        )}
      </div>

      {/* ─── QR MODAL ─── */}
      {qrModalOpen && techToDisplay && (
        <div className="modal-overlay" onClick={() => setQrModalOpen(false)}>
          <div className="modal-content" style={{ maxWidth: '420px', textAlign: 'center' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Public Cryptographic QR Badge</h3>
              <button
                onClick={() => setQrModalOpen(false)}
                style={{ background: 'none', border: 'none', fontSize: '20px', cursor: 'pointer', color: 'var(--text-muted)' }}
              >
                ✕
              </button>
            </div>

            <div className="modal-body">
              <p style={{ fontSize: '12.5px', color: 'var(--text-secondary)', margin: '0 0 16px' }}>
                Customer app or gate security scans this badge to verify certified technician identity in real time.
              </p>

              <div style={{ margin: '0 auto 16px', padding: '20px', background: '#FFFFFF', border: '2px solid var(--border-color)', borderRadius: 'var(--radius-lg)', display: 'inline-block' }}>
                <div style={{ width: '160px', height: '160px', background: 'var(--bg-sidebar)', color: '#FFF', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '8px', fontSize: '64px' }}>
                  🔲
                </div>
              </div>

              <div style={{ background: 'var(--bg-canvas)', padding: '10px', borderRadius: 'var(--radius-sm)', fontSize: '11.5px', color: 'var(--text-secondary)', fontFamily: 'monospace', wordBreak: 'break-all', border: '1px solid var(--border-color)' }}>
                https://bookurtechnician.com/verify-tech/verify_{String(techToDisplay.id).toLowerCase()}_token
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn btn-royal" style={{ width: '100%' }} onClick={() => setQrModalOpen(false)}>
                Close Preview
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
