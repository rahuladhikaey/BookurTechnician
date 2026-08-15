import React, { useState } from 'react';

export default function TechniciansManager({ technicians, setTechnicians, auditLogAction, subTab = 'list', onNavigateToIdCard }) {
  const [filterTab, setFilterTab] = useState(subTab === 'kyc' ? 'PENDING' : 'ALL');
  const [selectedTech, setSelectedTech] = useState(null);
  const [showKycModal, setShowKycModal] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const [newTechForm, setNewTechForm] = useState({
    name: '',
    category: 'AC Service',
    phone: '',
    location: 'Bengaluru, Hebbal',
    experience: '3 years',
    photo: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400'
  });

  // Filter technicians
  const filteredTechnicians = technicians.filter(t => {
    const q = searchQuery.toLowerCase();
    const matchesSearch = !q ||
      t.name.toLowerCase().includes(q) ||
      t.id.toLowerCase().includes(q) ||
      (t.category && t.category.toLowerCase().includes(q)) ||
      (t.phone && t.phone.toLowerCase().includes(q));

    if (filterTab === 'ALL') return matchesSearch;
    if (filterTab === 'PENDING') return matchesSearch && (t.kycStatus === 'Pending' || t.status === 'Pending');
    if (filterTab === 'APPROVED') return matchesSearch && (t.status === 'Approved');
    if (filterTab === 'ONLINE') return matchesSearch && (t.onlineStatus === 'Online' || t.status === 'Approved');
    if (filterTab === 'OFFLINE') return matchesSearch && (t.onlineStatus === 'Offline');
    if (filterTab === 'SUSPENDED') return matchesSearch && (t.status === 'Suspended');
    return matchesSearch;
  });

  // KYC Verification Workflow Actions
  const handleApproveTech = (tech) => {
    const permanentId = tech.id.startsWith('BT-TECH') ? tech.id : `BT-TECH-00000${tech.id.replace(/\D/g, '') || '1'}`;
    setTechnicians(prev => prev.map(t => t.id === tech.id ? {
      ...t,
      id: permanentId,
      status: 'Approved',
      kycStatus: 'Approved',
      onlineStatus: 'Online',
      verifiedAt: '15 Aug 2026'
    } : t));

    auditLogAction?.(
      'Technicians',
      `Approved technician ${tech.name}. Generated permanent ID: ${permanentId} with ID badge tokens.`
    );

    setShowKycModal(false);
    alert(`Technician ${tech.name} successfully Approved!`);
  };

  const handleRejectTech = (tech) => {
    setTechnicians(prev => prev.map(t => t.id === tech.id ? {
      ...t,
      status: 'Rejected',
      kycStatus: 'Rejected'
    } : t));

    auditLogAction?.(
      'Technicians',
      `Rejected technician registration for ${tech.name} (${tech.id}).`
    );

    setShowKycModal(false);
  };

  const handleSuspendTech = (tech) => {
    const nextState = tech.status === 'Suspended' ? 'Approved' : 'Suspended';
    setTechnicians(prev => prev.map(t => t.id === tech.id ? {
      ...t,
      status: nextState
    } : t));

    auditLogAction?.(
      'Technicians',
      `Changed account status of ${tech.name} (${tech.id}) to ${nextState}`
    );
  };

  const handleCreateTechnician = (e) => {
    e.preventDefault();
    const newId = `BT-TECH-00000${technicians.length + 1}`;
    const newT = {
      id: newId,
      name: newTechForm.name,
      category: newTechForm.category,
      phone: newTechForm.phone,
      location: newTechForm.location,
      experience: newTechForm.experience,
      photo: newTechForm.photo,
      status: 'Approved',
      kycStatus: 'Approved',
      onlineStatus: 'Online',
      rating: 5.0,
      completedJobs: 0,
      earnings: 0
    };
    setTechnicians(prev => [...prev, newT]);
    auditLogAction?.('Technicians', `Manually registered technician ${newT.name} (${newId})`);
    setShowAddModal(false);
  };

  return (
    <div className="technicians-manager-view">
      {/* ─── FLAT TABS ─── */}
      <div className="flat-tabs">
        {['ALL', 'PENDING', 'APPROVED', 'ONLINE', 'OFFLINE', 'SUSPENDED'].map(tab => (
          <div
            key={tab}
            className={`flat-tab ${filterTab === tab ? 'active' : ''}`}
            onClick={() => setFilterTab(tab)}
          >
            {tab === 'ALL' ? `All Technicians (${technicians.length})` :
             tab === 'PENDING' ? `Pending Verification (${technicians.filter(t => t.kycStatus === 'Pending' || t.status === 'Pending').length})` :
             tab === 'APPROVED' ? `Approved (${technicians.filter(t => t.status === 'Approved').length})` :
             tab === 'ONLINE' ? `🟢 Online Fleet (${technicians.filter(t => t.onlineStatus === 'Online' || t.status === 'Approved').length})` :
             tab === 'OFFLINE' ? 'Offline' : 'Suspended'}
          </div>
        ))}
      </div>

      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Technician Fleet & Verification</h2>
            <p className="page-subtitle">Review selfie submissions, verify KYC documents, manage ID badges and availability</p>
          </div>
          <div className="page-actions-group">
            <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
              + Add Technician
            </button>
          </div>
        </div>

        {/* ─── TOOLBAR ─── */}
        <div className="toolbar-row">
          <div className="toolbar-left">
            <div className="search-input-box header-search" style={{ minWidth: '300px' }}>
              <input
                type="text"
                placeholder="Search technician by name, ID, phone, category..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
            </div>
          </div>
          <div className="toolbar-right">
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Showing {filteredTechnicians.length} technicians
            </span>
          </div>
        </div>

        {/* ─── FLAT TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Technician</th>
                <th>Technician ID</th>
                <th>Category</th>
                <th>Contact</th>
                <th>Rating & Jobs</th>
                <th>Hub Location</th>
                <th>KYC Status</th>
                <th>Fleet State</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTechnicians.map(t => (
                <tr key={t.id}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <img
                        src={t.photo || 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=100'}
                        alt={t.name}
                        style={{ width: '40px', height: '40px', borderRadius: '4px', objectFit: 'cover', border: '1px solid var(--border-color)' }}
                      />
                      <div>
                        <strong style={{ color: 'var(--text-main)' }}>{t.name}</strong>
                        <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Exp: {t.experience || '4 years'}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>
                      {t.id.startsWith('BT-TECH') ? t.id : `BT-TECH-00000${t.id.replace(/\D/g, '') || '1'}`}
                    </strong>
                  </td>
                  <td><span className="badge badge-info">{t.category}</span></td>
                  <td>{t.phone}</td>
                  <td>
                    <div>⭐ {t.rating || '4.8'}</div>
                    <small style={{ color: 'var(--text-secondary)' }}>{t.completedJobs || 18} jobs</small>
                  </td>
                  <td>{t.location || 'Bengaluru Central'}</td>
                  <td>
                    <span className={`badge ${t.status === 'Approved' ? 'badge-completed' : t.status === 'Rejected' ? 'badge-cancelled' : 'badge-pending'}`}>
                      {t.status === 'Approved' ? 'Verified' : t.status === 'Rejected' ? 'Rejected' : 'Pending'}
                    </span>
                  </td>
                  <td>
                    <span className={`badge ${t.onlineStatus === 'Online' || t.status === 'Approved' ? 'badge-completed' : 'badge-cancelled'}`}>
                      {t.onlineStatus === 'Online' || t.status === 'Approved' ? '🟢 Online' : '⚪ Offline'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                      {(t.kycStatus === 'Pending' || t.status === 'Pending') ? (
                        <button
                          className="btn btn-primary btn-sm"
                          onClick={() => {
                            setSelectedTech(t);
                            setShowKycModal(true);
                          }}
                        >
                          Review KYC →
                        </button>
                      ) : (
                        <>
                          <button
                            className="btn btn-outline btn-sm"
                            onClick={() => {
                              setSelectedTech(t);
                              setShowKycModal(true);
                            }}
                          >
                            Details
                          </button>
                          <button
                            className={`btn btn-sm ${t.status === 'Suspended' ? 'btn-primary' : 'btn-danger'}`}
                            onClick={() => handleSuspendTech(t)}
                          >
                            {t.status === 'Suspended' ? 'Reactivate' : 'Suspend'}
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── KYC VERIFICATION MODAL ─── */}
      {showKycModal && selectedTech && (
        <div className="modal-overlay" onClick={() => setShowKycModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '640px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Technician Profile: {selectedTech.name}</h3>
              <button className="modal-close-btn" onClick={() => setShowKycModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: '16px', marginBottom: '16px' }}>
                <img
                  src={selectedTech.photo}
                  alt={selectedTech.name}
                  style={{ width: '120px', height: '120px', borderRadius: '4px', objectFit: 'cover', border: '1px solid var(--border-color)' }}
                />
                <div>
                  <h3 style={{ margin: '0 0 4px', color: 'var(--text-main)' }}>{selectedTech.name}</h3>
                  <div style={{ color: 'var(--primary)', fontWeight: '700', fontSize: '13px' }}>ID: {selectedTech.id}</div>
                  <div style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '4px' }}>Phone: {selectedTech.phone}</div>
                  <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Skill Vertical: {selectedTech.category}</div>
                  <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>PAN Card: {selectedTech.panCard || 'BPRPK9028L'}</div>
                </div>
              </div>

              <div style={{ padding: '14px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '4px', marginBottom: '16px' }}>
                <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--primary)', marginBottom: '4px' }}>DIGITAL ID STATUS</div>
                <div style={{ fontSize: '13px', color: 'var(--text-main)' }}>
                  Certified ID Card QR Token: <strong>{selectedTech.id}-VERIFIED-2026</strong>
                </div>
              </div>
            </div>

            <div className="modal-footer">
              {selectedTech.status === 'Pending' && (
                <>
                  <button className="btn btn-danger" onClick={() => handleRejectTech(selectedTech)}>
                    Reject Application
                  </button>
                  <button className="btn btn-primary" onClick={() => handleApproveTech(selectedTech)}>
                    Approve & Issue ID Card
                  </button>
                </>
              )}
              <button className="btn btn-outline" onClick={() => setShowKycModal(false)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* ─── ADD TECHNICIAN MODAL ─── */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Register New Technician</h3>
              <button className="modal-close-btn" onClick={() => setShowAddModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateTechnician}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Full Name</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Rahul Adhikary"
                    value={newTechForm.name}
                    onChange={e => setNewTechForm({ ...newTechForm, name: e.target.value })}
                  />
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Skill Category</label>
                    <input
                      type="text"
                      className="form-control"
                      value={newTechForm.category}
                      onChange={e => setNewTechForm({ ...newTechForm, category: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Mobile Number</label>
                    <input
                      type="text"
                      required
                      className="form-control"
                      placeholder="+91 98302-93821"
                      value={newTechForm.phone}
                      onChange={e => setNewTechForm({ ...newTechForm, phone: e.target.value })}
                    />
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Hub Location</label>
                    <input
                      type="text"
                      className="form-control"
                      value={newTechForm.location}
                      onChange={e => setNewTechForm({ ...newTechForm, location: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Experience</label>
                    <input
                      type="text"
                      className="form-control"
                      value={newTechForm.experience}
                      onChange={e => setNewTechForm({ ...newTechForm, experience: e.target.value })}
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Profile Photo URL</label>
                  <input
                    type="url"
                    className="form-control"
                    value={newTechForm.photo}
                    onChange={e => setNewTechForm({ ...newTechForm, photo: e.target.value })}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Create Technician</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
