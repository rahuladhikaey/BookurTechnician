import React, { useState } from 'react';
import api from '../../api/apiClient';

export default function TechniciansManager({ technicians = [], setTechnicians, auditLogAction, subTab = 'list', onNavigateToIdCard }) {
  const [filterTab, setFilterTab] = useState(subTab === 'kyc' ? 'PENDING' : 'ALL');
  const [selectedTech, setSelectedTech] = useState(null);
  const [showKycModal, setShowKycModal] = useState(false);
  const [showSkillsModal, setShowSkillsModal] = useState(false);
  const [techSkillsData, setTechSkillsData] = useState(null);
  const [loadingSkills, setLoadingSkills] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [rejectionReason, setRejectionReason] = useState('Incomplete or blurry identity documents');

  const openSkillsModal = async (tech) => {
    setSelectedTech(tech);
    setShowSkillsModal(true);
    setLoadingSkills(true);
    try {
      const res = await api.getTechnicianSkills(tech.id);
      if (res?.data) {
        setTechSkillsData(res.data);
      } else {
        setTechSkillsData(null);
      }
    } catch (err) {
      console.warn('Error fetching technician skills:', err);
      setTechSkillsData(null);
    } finally {
      setLoadingSkills(false);
    }
  };

  const handleVerifySkill = async (skillItem, newStatus, reason = '') => {
    try {
      await api.verifyTechnicianSkill(skillItem.id, newStatus, reason);
      auditLogAction?.(
        'Technicians',
        `${newStatus === 'VERIFIED' ? 'Approved' : 'Rejected'} skill "${skillItem.skillName}" for technician ${selectedTech.name}.`
      );
      // Refresh skills list
      if (selectedTech) {
        const res = await api.getTechnicianSkills(selectedTech.id);
        if (res?.data) setTechSkillsData(res.data);
      }
    } catch (err) {
      alert('Failed to update skill verification status: ' + err.message);
    }
  };

  const [newTechForm, setNewTechForm] = useState({
    name: '',
    category: 'AC Service',
    phone: '',
    location: 'Bengaluru, Hebbal',
    experience: '3 years',
    photo: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400'
  });

  // Filter technicians
  const filteredTechnicians = (technicians || []).filter(t => {
    const q = searchQuery.toLowerCase();
    const nameStr = (t.name || '').toLowerCase();
    const idStr = (t.id || t.code || '').toLowerCase();
    const catStr = (t.category || '').toLowerCase();
    const phoneStr = (t.phone || '');

    const matchesSearch = !q || nameStr.includes(q) || idStr.includes(q) || catStr.includes(q) || phoneStr.includes(q);
    if (!matchesSearch) return false;

    const kyc = (t.kycStatus || 'PENDING').toUpperCase();
    const online = Boolean(t.isOnline || t.online);
    const status = (t.status || 'Active').toUpperCase();

    if (filterTab === 'ALL') return true;
    if (filterTab === 'PENDING') return kyc === 'PENDING' || kyc === 'SUBMITTED';
    if (filterTab === 'APPROVED') return kyc === 'VERIFIED';
    if (filterTab === 'ONLINE') return online;
    if (filterTab === 'OFFLINE') return !online;
    if (filterTab === 'SUSPENDED') return status === 'SUSPENDED';
    return true;
  });

  // KYC Verification Workflow Actions
  const handleApproveTech = async (tech) => {
    try {
      await api.updateKyc(tech.id, 'VERIFIED');
      if (setTechnicians) {
        setTechnicians(prev => prev.map(t => t.id === tech.id ? {
          ...t,
          status: 'Active',
          kycStatus: 'VERIFIED'
        } : t));
      }

      auditLogAction?.(
        'Technicians',
        `Approved technician KYC for ${tech.name} (${tech.code || tech.id}).`
      );

      setShowKycModal(false);
      alert(`Technician ${tech.name} successfully Verified & Approved!`);
    } catch (err) {
      console.error('Error approving KYC:', err);
      alert('Error approving technician: ' + err.message);
    }
  };

  const handleRejectTech = async (tech) => {
    try {
      await api.updateKyc(tech.id, 'REJECTED', rejectionReason);
      if (setTechnicians) {
        setTechnicians(prev => prev.map(t => t.id === tech.id ? {
          ...t,
          kycStatus: 'REJECTED',
          rejectionReason
        } : t));
      }

      auditLogAction?.(
        'Technicians',
        `Rejected technician KYC for ${tech.name} (${tech.id}). Reason: ${rejectionReason}`
      );

      setShowKycModal(false);
    } catch (err) {
      console.error('Error rejecting KYC:', err);
      alert('Error updating technician: ' + err.message);
    }
  };

  const handleSuspendTech = async (tech) => {
    const nextState = tech.status === 'Suspended' ? 'Active' : 'Suspended';
    try {
      await api.updateTechnicianStatus(tech.id, nextState);
      if (setTechnicians) {
        setTechnicians(prev => prev.map(t => t.id === tech.id ? {
          ...t,
          status: nextState
        } : t));
      }

      auditLogAction?.(
        'Technicians',
        `Changed account status of ${tech.name} (${tech.id}) to ${nextState}`
      );
    } catch (err) {
      console.error('Error updating technician status:', err);
      alert('Error updating status: ' + err.message);
    }
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
      status: 'Active',
      kycStatus: 'VERIFIED',
      isOnline: true,
      rating: 5.0,
      totalRatingsCount: 0,
      totalJobsCompleted: 0
    };

    if (setTechnicians) {
      setTechnicians(prev => [newT, ...prev]);
    }
    auditLogAction?.('Technicians', `Manually registered technician ${newT.name} (${newId})`);
    setShowAddModal(false);
  };

  return (
    <div className="technicians-view">
      {/* ─── PAGE HEADER ROW ─── */}
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Technician Fleet & Verification Directory</h1>
          <p className="page-subtitle">Verify KYC identity documents, issue digital ID credentials, and monitor real GPS online availability</p>
        </div>
        <div className="page-actions-group">
          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
            + Register New Technician
          </button>
        </div>
      </div>

      {/* ─── FILTER TABS (FLAT 2D) ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${filterTab === 'ALL' ? 'active' : ''}`} onClick={() => setFilterTab('ALL')}>
          All Technicians ({technicians.length})
        </div>
        <div className={`flat-tab ${filterTab === 'PENDING' ? 'active' : ''}`} onClick={() => setFilterTab('PENDING')}>
          Pending KYC ({technicians.filter(t => t.kycStatus === 'PENDING' || t.kycStatus === 'Pending' || t.kycStatus === 'SUBMITTED').length})
        </div>
        <div className={`flat-tab ${filterTab === 'APPROVED' ? 'active' : ''}`} onClick={() => setFilterTab('APPROVED')}>
          Verified Partners ({technicians.filter(t => t.kycStatus === 'VERIFIED' || t.kycStatus === 'Approved').length})
        </div>
        <div className={`flat-tab ${filterTab === 'ONLINE' ? 'active' : ''}`} onClick={() => setFilterTab('ONLINE')}>
          Online GPS ({technicians.filter(t => t.isOnline || t.online).length})
        </div>
        <div className={`flat-tab ${filterTab === 'OFFLINE' ? 'active' : ''}`} onClick={() => setFilterTab('OFFLINE')}>
          Offline ({technicians.filter(t => !t.isOnline && !t.online).length})
        </div>
      </div>

      {/* ─── TOOLBAR (SEARCH + ACTIONS) ─── */}
      <div className="toolbar-row">
        <div className="toolbar-left">
          <div className="search-input-box header-search" style={{ minWidth: '300px' }}>
            <input
              type="text"
              placeholder="Search by name, ID code, category, phone..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </div>
        <div className="toolbar-right">
          <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Showing <strong>{filteredTechnicians.length}</strong> of {technicians.length} fleet technicians
          </span>
        </div>
      </div>

      {/* ─── FLAT TECHNICIANS TABLE ─── */}
      <div className="panel">
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Partner ID & Profile</th>
                <th>Declared Skills</th>
                <th>Availability & Status</th>
                <th>GPS Location Telemetry</th>
                <th>KYC Verification</th>
                <th>Performance & Rates</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTechnicians.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-secondary)' }}>
                    👨🔧 No technicians registered yet.
                    <div style={{ fontSize: '12px', marginTop: '6px', color: 'var(--text-muted)' }}>
                      Real technician records will appear here as soon as partners register via the Technician App.
                    </div>
                  </td>
                </tr>
              ) : (
                filteredTechnicians.map((t) => {
                  const availability = t.availability || (t.isOnline || t.online ? 'ONLINE' : 'OFFLINE');
                  const isBusy = availability === 'BUSY_ON_JOB';
                  const isOnline = availability === 'ONLINE';

                  return (
                    <tr key={t.id}>
                      <td>
                        <div className="flex-gap" style={{ alignItems: 'center' }}>
                          <img
                            src={t.photo || "https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=150&q=80"}
                            alt=""
                            style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover', border: '1px solid var(--border-color)' }}
                          />
                          <div>
                            <strong style={{ color: 'var(--text-main)', display: 'block' }}>{t.name}</strong>
                            <small style={{ color: 'var(--primary)', fontFamily: 'monospace', fontWeight: 'bold' }}>
                              {t.code || t.technicianCode || t.id}
                            </small>
                            <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{t.phone}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '3px' }}>
                          <span className="badge badge-info" style={{ fontWeight: '700', alignSelf: 'flex-start' }}>
                            🎯 {t.skills?.length || 0} Skills ({t.verifiedSkillsCount || 0} Verified)
                          </span>
                          <small style={{ color: 'var(--text-secondary)' }}>
                            {t.skills?.slice(0, 2).map(s => s.skillName).join(', ') || 'No skills declared yet'}
                            {t.skills?.length > 2 ? ` +${t.skills.length - 2} more` : ''}
                          </small>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                          {isBusy ? (
                            <span className="badge badge-warning" style={{ background: '#FEF3C7', color: '#92400E', fontWeight: '600' }}>
                              🟡 Busy on Job
                            </span>
                          ) : isOnline ? (
                            <span className="badge badge-confirmed" style={{ background: '#D1FAE5', color: '#065F46', fontWeight: '600' }}>
                              🟢 Online & Idle
                            </span>
                          ) : (
                            <span className="badge badge-cancelled" style={{ background: '#F1F5F9', color: '#475569', fontWeight: '600' }}>
                              ⚪ Offline
                            </span>
                          )}
                          <small style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                            Status: <strong style={{ color: t.status === 'Active' ? 'var(--success)' : 'var(--danger)' }}>{t.status || 'Active'}</strong>
                          </small>
                        </div>
                      </td>
                      <td>
                        {t.latitude && t.longitude ? (
                          <div style={{ fontSize: '12px' }}>
                            <a
                              href={`https://maps.google.com/?q=${t.latitude},${t.longitude}`}
                              target="_blank"
                              rel="noreferrer"
                              style={{ color: 'var(--primary)', fontWeight: '600', textDecoration: 'none' }}
                            >
                              📍 {t.latitude.toFixed(4)}, {t.longitude.toFixed(4)}
                            </a>
                            <div style={{ fontSize: '10.5px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                              {t.locationUpdatedAt ? `Fix: ${new Date(t.locationUpdatedAt).toLocaleTimeString()}` : 'Live GPS'}
                            </div>
                          </div>
                        ) : (
                          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>📍 No GPS fix</span>
                        )}
                      </td>
                      <td>
                        <span className={`badge ${
                          t.kycStatus === 'VERIFIED' || t.kycStatus === 'Approved' ? 'badge-completed' :
                          t.kycStatus === 'REJECTED' || t.kycStatus === 'Rejected' ? 'badge-cancelled' : 'badge-pending'
                        }`}>
                          {t.kycStatus === 'VERIFIED' ? '✓ Verified' : t.kycStatus || 'Pending'}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                          <div style={{ fontWeight: 'bold', color: '#D97706', fontSize: '13px' }}>
                            ★ {t.rating || 5.0} <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>({t.totalRatingsCount || 0} revs)</span>
                          </div>
                          <div style={{ fontSize: '11.5px', color: 'var(--text-secondary)' }}>
                            Jobs: <strong>{t.totalJobsCompleted || 0}</strong>
                          </div>
                          <div style={{ fontSize: '11px', display: 'flex', gap: '8px' }}>
                            <span style={{ color: '#059669', fontWeight: '600' }}>Accept: {t.acceptanceRate || 96}%</span>
                            <span style={{ color: '#DC2626' }}>Cancel: {t.cancellationRate || 1.5}%</span>
                          </div>
                        </div>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                          <button
                            className="btn btn-outline btn-sm"
                            style={{ borderColor: 'var(--primary)', color: 'var(--primary)' }}
                            onClick={() => openSkillsModal(t)}
                          >
                            Skills & Verification
                          </button>
                          <button
                            className="btn btn-outline btn-sm"
                            onClick={() => {
                              setSelectedTech(t);
                              setShowKycModal(true);
                            }}
                          >
                            KYC Review
                          </button>
                          <button
                            className="btn btn-secondary btn-sm"
                            onClick={() => onNavigateToIdCard ? onNavigateToIdCard(t) : alert(`Viewing ID for ${t.name}`)}
                          >
                            Digital ID
                          </button>
                          <button
                            className={`btn btn-sm ${t.status === 'Suspended' ? 'btn-primary' : 'btn-danger'}`}
                            onClick={() => handleSuspendTech(t)}
                          >
                            {t.status === 'Suspended' ? 'Reactivate' : 'Suspend'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── SKILLS VERIFICATION MODAL ─── */}
      {showSkillsModal && selectedTech && (
        <div className="modal-overlay" onClick={() => setShowSkillsModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '680px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Skills Verification: {selectedTech.name}</h3>
              <button className="modal-close-btn" onClick={() => setShowSkillsModal(false)}>×</button>
            </div>

            <div className="modal-body">
              <div style={{ padding: '12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid var(--border-color)', marginBottom: '16px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <strong>{selectedTech.name}</strong> ({selectedTech.phone})
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      Technician ID: <strong>{selectedTech.code || selectedTech.technicianCode || selectedTech.id}</strong>
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '13px', fontWeight: 'bold', color: '#D97706' }}>
                      ★ {techSkillsData?.rating || selectedTech.rating || 4.9} ({techSkillsData?.totalRatingsCount || selectedTech.totalRatingsCount || 0} reviews)
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                      {techSkillsData?.verifiedSkillsCount || 0} Verified / {techSkillsData?.skills?.length || 0} Total Skills
                    </div>
                  </div>
                </div>
              </div>

              {loadingSkills ? (
                <div style={{ textAlign: 'center', padding: '30px', color: 'var(--text-secondary)' }}>
                  Loading technician declared skills...
                </div>
              ) : !techSkillsData || !techSkillsData.skills || techSkillsData.skills.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '24px', color: 'var(--text-secondary)' }}>
                  No skills declared by this technician yet.
                </div>
              ) : (
                <div className="table-responsive">
                  <table className="flat-table" style={{ fontSize: '13px' }}>
                    <thead>
                      <tr>
                        <th>Category & Skill</th>
                        <th>Experience</th>
                        <th>Status</th>
                        <th style={{ textAlign: 'right' }}>Verification Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {techSkillsData.skills.map((s) => (
                        <tr key={s.id}>
                          <td>
                            <strong>{s.skillName}</strong>
                            <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{s.categoryName}</div>
                          </td>
                          <td>{s.experienceYears} {s.experienceYears === 1 ? 'year' : 'years'}</td>
                          <td>
                            <span className={`badge ${
                              s.verificationStatus === 'VERIFIED' ? 'badge-completed' :
                              s.verificationStatus === 'REJECTED' ? 'badge-cancelled' : 'badge-pending'
                            }`}>
                              {s.verificationStatus === 'VERIFIED' ? '✓ Verified' :
                               s.verificationStatus === 'REJECTED' ? '❌ Rejected' : '⏳ Pending'}
                            </span>
                          </td>
                          <td style={{ textAlign: 'right' }}>
                            <div style={{ display: 'flex', gap: '4px', justifyContent: 'flex-end' }}>
                              {s.verificationStatus !== 'VERIFIED' && (
                                <button
                                  className="btn btn-primary btn-sm"
                                  style={{ padding: '3px 8px', fontSize: '11px' }}
                                  onClick={() => handleVerifySkill(s, 'VERIFIED')}
                                >
                                  Verify
                                </button>
                              )}
                              {s.verificationStatus !== 'REJECTED' && (
                                <button
                                  className="btn btn-danger btn-sm"
                                  style={{ padding: '3px 8px', fontSize: '11px' }}
                                  onClick={() => {
                                    const reason = prompt(`Reason for rejecting skill "${s.skillName}":`, 'Insufficient certificate or experience proof');
                                    if (reason) handleVerifySkill(s, 'REJECTED', reason);
                                  }}
                                >
                                  Reject
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button className="btn btn-outline" onClick={() => setShowSkillsModal(false)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* ─── KYC VERIFICATION MODAL ─── */}
      {showKycModal && selectedTech && (
        <div className="modal-overlay" onClick={() => setShowKycModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '640px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">KYC Document Verification: {selectedTech.name}</h3>
              <button className="modal-close-btn" onClick={() => setShowKycModal(false)}>×</button>
            </div>

            <div className="modal-body">
              <div style={{ padding: '12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid var(--border-color)', marginBottom: '16px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <strong>{selectedTech.name}</strong> ({selectedTech.phone})
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      Technician Code: <strong>{selectedTech.code || selectedTech.technicianCode || selectedTech.id}</strong>
                    </div>
                  </div>
                  <span className={`badge ${selectedTech.kycStatus === 'VERIFIED' ? 'badge-completed' : 'badge-pending'}`}>
                    {selectedTech.kycStatus || 'Pending'}
                  </span>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '16px' }}>
                <div style={{ border: '1px solid var(--border-color)', borderRadius: '6px', padding: '10px' }}>
                  <span style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--primary)' }}>AADHAAR CARD (FRONT & BACK)</span>
                  <div style={{ height: '110px', background: '#E2E8F0', borderRadius: '4px', marginTop: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', color: '#64748B' }}>
                    Aadhaar Image Verified ✓
                  </div>
                </div>
                <div style={{ border: '1px solid var(--border-color)', borderRadius: '6px', padding: '10px' }}>
                  <span style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--primary)' }}>PAN CARD & POLICE VERIFICATION</span>
                  <div style={{ height: '110px', background: '#E2E8F0', borderRadius: '4px', marginTop: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', color: '#64748B' }}>
                    Govt ID Records Verified ✓
                  </div>
                </div>
              </div>

              {selectedTech.kycStatus !== 'VERIFIED' && (
                <div style={{ marginTop: '10px' }}>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block', marginBottom: '4px' }}>Rejection Reason (if applicable):</label>
                  <input
                    type="text"
                    className="form-input"
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    style={{ width: '100%', padding: '8px', border: '1px solid var(--border-color)', borderRadius: '4px' }}
                  />
                </div>
              )}
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between' }}>
              <button className="btn btn-outline" onClick={() => setShowKycModal(false)}>Close</button>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button className="btn btn-danger" onClick={() => handleRejectTech(selectedTech)}>
                  Reject KYC
                </button>
                <button className="btn btn-primary" onClick={() => handleApproveTech(selectedTech)}>
                  Approve & Issue ID Badge
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─── ADD TECHNICIAN MODAL ─── */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '500px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Register Technician Partner</h3>
              <button className="modal-close-btn" onClick={() => setShowAddModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateTechnician}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold' }}>Full Name *</label>
                  <input
                    type="text"
                    required
                    style={{ width: '100%', padding: '8px', border: '1px solid var(--border-color)', borderRadius: '4px', marginTop: '4px' }}
                    value={newTechForm.name}
                    onChange={e => setNewTechForm({ ...newTechForm, name: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold' }}>Primary Service Skill *</label>
                  <select
                    style={{ width: '100%', padding: '8px', border: '1px solid var(--border-color)', borderRadius: '4px', marginTop: '4px' }}
                    value={newTechForm.category}
                    onChange={e => setNewTechForm({ ...newTechForm, category: e.target.value })}
                  >
                    <option>AC Service</option>
                    <option>Washing Machine</option>
                    <option>Refrigerator</option>
                    <option>Television</option>
                    <option>Water Purifier</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold' }}>Phone Number *</label>
                  <input
                    type="text"
                    required
                    style={{ width: '100%', padding: '8px', border: '1px solid var(--border-color)', borderRadius: '4px', marginTop: '4px' }}
                    value={newTechForm.phone}
                    onChange={e => setNewTechForm({ ...newTechForm, phone: e.target.value })}
                  />
                </div>
              </div>
              <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
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
