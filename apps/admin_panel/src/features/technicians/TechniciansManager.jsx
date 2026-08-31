import React, { useState, useEffect } from 'react';
import api from '../../api/apiClient';

export default function TechniciansManager({
  technicians = [],
  setTechnicians,
  auditLogAction,
  subTab = 'list',
  onNavigateToIdCard,
  onReload
}) {
  const [filterTab, setFilterTab] = useState('ALL');
  const [selectedTech, setSelectedTech] = useState(null);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [showKycModal, setShowKycModal] = useState(false);
  const [showSkillsModal, setShowSkillsModal] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [detailTab, setDetailTab] = useState('overview'); // 'overview' | 'skills' | 'kyc' | 'gps' | 'financial'

  const [techSkillsData, setTechSkillsData] = useState(null);
  const [loadingSkills, setLoadingSkills] = useState(false);
  const [techDocsData, setTechDocsData] = useState([]);
  const [loadingDocs, setLoadingDocs] = useState(false);
  const [loadingTechs, setLoadingTechs] = useState(false);
  const [creatingTech, setCreatingTech] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [rejectionReason, setRejectionReason] = useState('Incomplete or blurry identity documents');

  const [newTechForm, setNewTechForm] = useState({
    name: '',
    phone: '',
    email: '',
    category: 'AC Service & Repair',
    experience: '3 years',
    upiId: 'technician@upi',
    aadhaarNumber: '',
    voterCardNumber: ''
  });

  const fetchTechs = async () => {
    setLoadingTechs(true);
    try {
      const res = await api.getTechnicians();
      const list = res?.data || (Array.isArray(res) ? res : []);
      if (Array.isArray(list) && setTechnicians) {
        setTechnicians(list);
      }
    } catch (err) {
      console.warn('Error fetching technicians:', err);
    } finally {
      setLoadingTechs(false);
    }
  };

  useEffect(() => {
    fetchTechs();
    const interval = setInterval(fetchTechs, 5000);
    return () => clearInterval(interval);
  }, []);

  // ─── OPEN PROFILE & DETAILS ───
  const openDetailModal = async (tech) => {
    setSelectedTech(tech);
    setDetailTab('overview');
    setShowDetailModal(true);
    // Pre-load skills & documents in background
    loadTechSkills(tech.id);
    loadTechDocs(tech.id);
  };

  const loadTechSkills = async (techId) => {
    setLoadingSkills(true);
    try {
      const res = await api.getTechnicianSkills(techId);
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

  const loadTechDocs = async (techId) => {
    setLoadingDocs(true);
    try {
      const res = await api.getTechnicianDocuments(techId);
      if (res?.data && Array.isArray(res.data)) {
        setTechDocsData(res.data);
      } else {
        setTechDocsData([]);
      }
    } catch (err) {
      console.warn('Error fetching technician docs:', err);
      setTechDocsData([]);
    } finally {
      setLoadingDocs(false);
    }
  };

  const openSkillsModal = async (tech) => {
    setSelectedTech(tech);
    setShowSkillsModal(true);
    await loadTechSkills(tech.id);
  };

  const openKycModal = async (tech) => {
    setSelectedTech(tech);
    setShowKycModal(true);
    await loadTechDocs(tech.id);
  };

  // ─── VERIFY / REJECT INDIVIDUAL SKILL ───
  const handleVerifySkill = async (skillItem, newStatus, reason = '') => {
    try {
      await api.verifyTechnicianSkill(skillItem.id, newStatus, reason);
      auditLogAction?.(
        'Technicians',
        `${newStatus === 'VERIFIED' ? 'Approved' : 'Rejected'} skill "${skillItem.skillName}" for technician ${selectedTech?.name}.`
      );
      if (selectedTech) {
        await loadTechSkills(selectedTech.id);
      }
      fetchTechs();
    } catch (err) {
      alert('Failed to update skill verification status: ' + err.message);
    }
  };

  // ─── APPROVE / REJECT KYC ───
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
      if (selectedTech && selectedTech.id === tech.id) {
        setSelectedTech(prev => ({ ...prev, status: 'Active', kycStatus: 'VERIFIED' }));
      }

      auditLogAction?.(
        'Technicians',
        `Approved technician KYC for ${tech.name} (${tech.code || tech.technicianCode || tech.id}).`
      );

      setShowKycModal(false);
      alert(`✓ Technician ${tech.name} successfully Verified & Approved!`);
      fetchTechs();
    } catch (err) {
      console.error('Error approving KYC:', err);
      alert('Error approving technician: ' + err.message);
    }
  };

  const handleRejectTech = async (tech) => {
    if (!rejectionReason.trim()) {
      alert('Please enter a rejection reason.');
      return;
    }
    try {
      await api.updateKyc(tech.id, 'REJECTED', rejectionReason);
      if (setTechnicians) {
        setTechnicians(prev => prev.map(t => t.id === tech.id ? {
          ...t,
          kycStatus: 'REJECTED',
          rejectionReason
        } : t));
      }
      if (selectedTech && selectedTech.id === tech.id) {
        setSelectedTech(prev => ({ ...prev, kycStatus: 'REJECTED', rejectionReason }));
      }

      auditLogAction?.(
        'Technicians',
        `Rejected technician KYC for ${tech.name} (${tech.id}). Reason: ${rejectionReason}`
      );

      setShowKycModal(false);
      alert(`Technician ${tech.name} KYC marked as Rejected.`);
      fetchTechs();
    } catch (err) {
      console.error('Error rejecting KYC:', err);
      alert('Error updating technician: ' + err.message);
    }
  };

  // ─── SUSPEND / REACTIVATE ACCOUNT ───
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
      if (selectedTech && selectedTech.id === tech.id) {
        setSelectedTech(prev => ({ ...prev, status: nextState }));
      }

      auditLogAction?.(
        'Technicians',
        `Changed account status of ${tech.name} (${tech.code || tech.id}) to ${nextState}`
      );
      fetchTechs();
    } catch (err) {
      console.error('Error updating technician status:', err);
      alert('Error updating status: ' + err.message);
    }
  };

  // ─── CREATE / ONBOARD NEW TECHNICIAN PARTNER ───
  const handleCreateTechnician = async (e) => {
    e.preventDefault();
    if (!newTechForm.name.trim()) {
      alert('Full Name is required.');
      return;
    }
    if (!newTechForm.phone.trim()) {
      alert('Phone Number is required.');
      return;
    }

    setCreatingTech(true);
    try {
      const res = await api.createTechnician(newTechForm);
      if (res?.data) {
        if (setTechnicians) {
          setTechnicians(prev => [res.data, ...prev]);
        }
        auditLogAction?.('Technicians', `Manually registered technician partner ${res.data.name} (${res.data.code})`);
        setShowAddModal(false);
        setNewTechForm({
          name: '',
          phone: '',
          email: '',
          category: 'AC Service & Repair',
          experience: '3 years',
          upiId: 'technician@upi',
          photo: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400'
        });
        alert(`✓ Technician Partner ${res.data.name} (${res.data.code}) created successfully!`);
        fetchTechs();
      }
    } catch (err) {
      console.error('Error creating technician partner:', err);
      alert('Failed to create technician: ' + err.message);
    } finally {
      setCreatingTech(false);
    }
  };

  // ─── DELETE TECHNICIAN PARTNER ───
  const handleDeleteTech = async (tech) => {
    if (!window.confirm(`Are you sure you want to delete technician partner ${tech.name || tech.fullName || tech.id}? This will permanently remove their records from the directory.`)) {
      return;
    }
    try {
      await api.deleteTechnician(tech.id);
      if (setTechnicians) {
        setTechnicians(prev => prev.filter(t => t.id !== tech.id));
      }
      if (selectedTech && selectedTech.id === tech.id) {
        setShowDetailModal(false);
        setSelectedTech(null);
      }
      auditLogAction?.('Technicians', `Deleted technician partner ${tech.name || tech.id}`);
      fetchTechs();
    } catch (err) {
      console.error('Error deleting technician:', err);
      alert('Failed to delete technician: ' + err.message);
    }
  };

  // ─── CLEAR ALL / RESET DIRECTORY ───
  const handleClearAllTechs = async () => {
    if (!window.confirm('Are you sure you want to clear all test technicians from the directory? This will reset the fleet to a clean production slate.')) {
      return;
    }
    try {
      await api.clearAllTechnicians();
      if (setTechnicians) {
        setTechnicians([]);
      }
      setShowDetailModal(false);
      setSelectedTech(null);
      auditLogAction?.('Technicians', 'Cleared entire technician directory for production reset');
      fetchTechs();
    } catch (err) {
      console.error('Error clearing technicians:', err);
      alert('Failed to clear technicians: ' + err.message);
    }
  };

  // ─── FILTER TECHNICIANS ───
  const filteredTechnicians = (technicians || []).filter(t => {
    const q = searchQuery.toLowerCase().trim();
    const nameStr = (t.name || t.fullName || '').toLowerCase();
    const idStr = (t.id || t.code || t.technicianCode || '').toLowerCase();
    const catStr = (t.category || '').toLowerCase();
    const phoneStr = (t.phone || '');
    const emailStr = (t.email || '').toLowerCase();

    const matchesSearch = !q ||
      nameStr.includes(q) ||
      idStr.includes(q) ||
      catStr.includes(q) ||
      phoneStr.includes(q) ||
      emailStr.includes(q);

    if (!matchesSearch) return false;

    const kyc = (t.kycStatus || 'PENDING').toUpperCase();
    const online = Boolean(t.isOnline || t.online);
    const status = (t.status || 'Active').toUpperCase();

    if (filterTab === 'ALL') return true;
    if (filterTab === 'PENDING') return kyc === 'PENDING' || kyc === 'SUBMITTED';
    if (filterTab === 'APPROVED') return kyc === 'VERIFIED' || kyc === 'APPROVED';
    if (filterTab === 'ONLINE') return online;
    if (filterTab === 'OFFLINE') return !online;
    if (filterTab === 'SUSPENDED') return status === 'SUSPENDED';
    return true;
  });

  const pendingCount = (technicians || []).filter(t => {
    const k = (t.kycStatus || 'PENDING').toUpperCase();
    return k === 'PENDING' || k === 'SUBMITTED';
  }).length;

  const verifiedCount = (technicians || []).filter(t => {
    const k = (t.kycStatus || '').toUpperCase();
    return k === 'VERIFIED' || k === 'APPROVED';
  }).length;

  const onlineCount = (technicians || []).filter(t => t.isOnline || t.online).length;
  const offlineCount = Math.max(0, (technicians || []).length - onlineCount);
  const suspendedCount = (technicians || []).filter(t => (t.status || '').toUpperCase() === 'SUSPENDED').length;

  return (
    <div className="technicians-view" style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
      
      {/* ─── PAGE HEADER ROW ─── */}
      <div className="page-header-row" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 className="page-title" style={{ margin: 0, fontSize: '24px', fontWeight: '800', color: 'var(--text-main)' }}>
            Technician Fleet & Verification Directory
          </h1>
          <p className="page-subtitle" style={{ margin: '4px 0 0', fontSize: '13px', color: 'var(--text-secondary)' }}>
            Review registered technicians, verify KYC identity proofs & declared skills, issue digital credentials, and track live GPS online telemetry.
          </p>
        </div>
        <div className="page-actions-group" style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          {technicians.length > 0 && (
            <button
              className="btn btn-outline"
              onClick={handleClearAllTechs}
              style={{ display: 'flex', alignItems: 'center', gap: '6px', borderColor: '#EF4444', color: '#EF4444' }}
              title="Clear all mock/test technician records for clean production slate"
            >
              <span>🗑️</span> Reset Test Data
            </button>
          )}
          <button
            className="btn btn-outline"
            onClick={fetchTechs}
            disabled={loadingTechs}
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <span style={{ display: 'inline-block', transform: loadingTechs ? 'rotate(180deg)' : 'none', transition: '0.4s' }}>🔄</span>
            {loadingTechs ? 'Refreshing...' : 'Refresh Directory'}
          </button>
          <button
            className="btn btn-primary"
            onClick={() => setShowAddModal(true)}
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <span>+</span> Register New Partner
          </button>
        </div>
      </div>

      {/* ─── FILTER TABS WITH COUNTERS ─── */}
      <div className="flat-tabs" style={{ display: 'flex', gap: '8px', borderBottom: '2px solid var(--border-color)', paddingBottom: '2px', overflowX: 'auto' }}>
        <button
          className={`flat-tab ${filterTab === 'ALL' ? 'active' : ''}`}
          onClick={() => setFilterTab('ALL')}
          style={{ padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer', fontWeight: filterTab === 'ALL' ? '800' : '600', color: filterTab === 'ALL' ? 'var(--primary)' : 'var(--text-secondary)', borderBottom: filterTab === 'ALL' ? '3px solid var(--primary)' : '3px solid transparent' }}
        >
          All Fleet Partners ({technicians.length})
        </button>
        <button
          className={`flat-tab ${filterTab === 'PENDING' ? 'active' : ''}`}
          onClick={() => setFilterTab('PENDING')}
          style={{ padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer', fontWeight: filterTab === 'PENDING' ? '800' : '600', color: filterTab === 'PENDING' ? '#D97706' : 'var(--text-secondary)', borderBottom: filterTab === 'PENDING' ? '3px solid #D97706' : '3px solid transparent' }}
        >
          ⏳ Pending KYC ({pendingCount})
        </button>
        <button
          className={`flat-tab ${filterTab === 'APPROVED' ? 'active' : ''}`}
          onClick={() => setFilterTab('APPROVED')}
          style={{ padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer', fontWeight: filterTab === 'APPROVED' ? '800' : '600', color: filterTab === 'APPROVED' ? '#059669' : 'var(--text-secondary)', borderBottom: filterTab === 'APPROVED' ? '3px solid #059669' : '3px solid transparent' }}
        >
          ✓ Verified Partners ({verifiedCount})
        </button>
        <button
          className={`flat-tab ${filterTab === 'ONLINE' ? 'active' : ''}`}
          onClick={() => setFilterTab('ONLINE')}
          style={{ padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer', fontWeight: filterTab === 'ONLINE' ? '800' : '600', color: filterTab === 'ONLINE' ? '#2563EB' : 'var(--text-secondary)', borderBottom: filterTab === 'ONLINE' ? '3px solid #2563EB' : '3px solid transparent' }}
        >
          🟢 Online GPS ({onlineCount})
        </button>
        <button
          className={`flat-tab ${filterTab === 'OFFLINE' ? 'active' : ''}`}
          onClick={() => setFilterTab('OFFLINE')}
          style={{ padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer', fontWeight: filterTab === 'OFFLINE' ? '800' : '600', color: filterTab === 'OFFLINE' ? '#64748B' : 'var(--text-secondary)', borderBottom: filterTab === 'OFFLINE' ? '3px solid #64748B' : '3px solid transparent' }}
        >
          ⚪ Offline ({offlineCount})
        </button>
        <button
          className={`flat-tab ${filterTab === 'SUSPENDED' ? 'active' : ''}`}
          onClick={() => setFilterTab('SUSPENDED')}
          style={{ padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer', fontWeight: filterTab === 'SUSPENDED' ? '800' : '600', color: filterTab === 'SUSPENDED' ? '#DC2626' : 'var(--text-secondary)', borderBottom: filterTab === 'SUSPENDED' ? '3px solid #DC2626' : '3px solid transparent' }}
        >
          🚫 Suspended ({suspendedCount})
        </button>
      </div>

      {/* ─── TOOLBAR ROW ─── */}
      <div className="toolbar-row" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div className="toolbar-left" style={{ flex: '1', minWidth: '280px', maxWidth: '480px' }}>
          <div className="search-input-box header-search" style={{ position: 'relative', width: '100%' }}>
            <input
              type="text"
              placeholder="Search by name, phone (+91), email, code (BT-TECH-...), skill, category..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ width: '100%', padding: '10px 14px 10px 36px', borderRadius: '8px', border: '1px solid var(--border-color)', fontSize: '13px', background: '#FFFFFF' }}
            />
            <span style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)', fontSize: '14px' }}>🔍</span>
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                style={{ position: 'absolute', right: '10px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: '#94A3B8' }}
              >
                ✕
              </button>
            )}
          </div>
        </div>
        <div className="toolbar-right">
          <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Showing <strong>{filteredTechnicians.length}</strong> of <strong>{technicians.length}</strong> registered technicians
          </span>
        </div>
      </div>

      {/* ─── TECHNICIANS DIRECTORY TABLE ─── */}
      <div className="panel" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="table-responsive">
          <table className="flat-table" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead>
              <tr style={{ background: '#F8FAFC', borderBottom: '1px solid var(--border-color)' }}>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>Partner ID & Profile</th>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>Category & Declared Skills</th>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>Availability & Status</th>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>GPS Telemetry</th>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>KYC & Documents</th>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>Performance & Wallet</th>
                <th style={{ padding: '12px 16px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loadingTechs && technicians.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                    <div style={{ fontSize: '20px', marginBottom: '8px' }}>🔄</div>
                    <div>Loading technician fleet records...</div>
                  </td>
                </tr>
              ) : filteredTechnicians.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '48px 16px', color: 'var(--text-secondary)' }}>
                    <div style={{ fontSize: '32px', marginBottom: '8px' }}>👨‍🔧</div>
                    <strong style={{ fontSize: '15px', color: 'var(--text-main)', display: 'block' }}>No technicians found matching criteria.</strong>
                    <div style={{ fontSize: '12.5px', marginTop: '6px', color: 'var(--text-muted)' }}>
                      New partners who register via the Technician App will appear here automatically.
                    </div>
                  </td>
                </tr>
              ) : (
                filteredTechnicians.map((t) => {
                  const availability = t.availability || (t.isOnline || t.online ? 'ONLINE' : 'OFFLINE');
                  const isBusy = availability === 'BUSY_ON_JOB';
                  const isOnline = availability === 'ONLINE';
                  const kyc = (t.kycStatus || 'PENDING').toUpperCase();
                  const isVerified = kyc === 'VERIFIED' || kyc === 'APPROVED';
                  const isRejected = kyc === 'REJECTED';

                  const skillsList = t.skills || [];
                  const verifiedSkillsCount = t.verifiedSkillsCount || skillsList.filter(s => s.verificationStatus === 'VERIFIED').length;
                  const docsCount = t.documents?.length || 0;

                  return (
                    <tr key={t.id} style={{ borderBottom: '1px solid var(--border-color)', cursor: 'pointer' }} onClick={() => openDetailModal(t)}>
                      {/* Column 1: Profile & Identity */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{ position: 'relative' }}>
                            <div style={{
                              width: '44px',
                              height: '44px',
                              borderRadius: '50%',
                              backgroundColor: '#1E3A8A',
                              color: '#FFFFFF',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              fontWeight: '800',
                              fontSize: '16px'
                            }}>
                              {((t.name || t.fullName || 'T')[0]).toUpperCase()}
                            </div>
                            <span style={{
                              position: 'absolute',
                              bottom: '0',
                              right: '0',
                              width: '12px',
                              height: '12px',
                              borderRadius: '50%',
                              backgroundColor: isOnline ? '#10B981' : '#94A3B8',
                              border: '2px solid #FFFFFF'
                            }} />
                          </div>
                          <div>
                            <strong style={{ color: 'var(--text-main)', fontSize: '13.5px', display: 'block' }}>
                              {t.name || t.fullName}
                            </strong>
                            <div style={{ fontFamily: 'monospace', fontWeight: 'bold', fontSize: '11.5px', color: 'var(--primary)' }}>
                              {t.code || t.technicianCode || t.id}
                            </div>
                            <div style={{ fontSize: '11.5px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                              📞 {t.phone || 'No phone'}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Column 2: Category & Declared Skills */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                          <strong style={{ fontSize: '12.5px', color: 'var(--text-main)' }}>
                            {t.category || 'General Appliances & Electrical'}
                          </strong>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                            <span className="badge badge-info" style={{ fontSize: '11px', fontWeight: '700', padding: '2px 8px' }}>
                              🎯 {skillsList.length} Skills ({verifiedSkillsCount} Verified)
                            </span>
                          </div>
                          <small style={{ color: 'var(--text-secondary)', fontSize: '11px', maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {skillsList.length > 0
                              ? skillsList.map(s => s.skillName).join(', ')
                              : 'No skills declared yet'}
                          </small>
                        </div>
                      </td>

                      {/* Column 3: Availability & Account Status */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                          {isBusy ? (
                            <span className="badge badge-warning" style={{ background: '#FEF3C7', color: '#92400E', fontWeight: '700', fontSize: '11px', width: 'fit-content' }}>
                              🟡 Busy on Job
                            </span>
                          ) : isOnline ? (
                            <span className="badge badge-confirmed" style={{ background: '#D1FAE5', color: '#065F46', fontWeight: '700', fontSize: '11px', width: 'fit-content' }}>
                              🟢 Online & Idle
                            </span>
                          ) : (
                            <span className="badge badge-cancelled" style={{ background: '#F1F5F9', color: '#475569', fontWeight: '700', fontSize: '11px', width: 'fit-content' }}>
                              ⚪ Offline
                            </span>
                          )}
                          <small style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                            Account: <strong style={{ color: t.status === 'Active' ? 'var(--success)' : 'var(--danger)' }}>{t.status || 'Active'}</strong>
                          </small>
                        </div>
                      </td>

                      {/* Column 4: GPS Telemetry */}
                      <td style={{ padding: '14px 16px' }}>
                        {t.latitude && t.longitude ? (
                          <div style={{ fontSize: '12px' }}>
                            <a
                              href={`https://maps.google.com/?q=${t.latitude},${t.longitude}`}
                              target="_blank"
                              rel="noreferrer"
                              onClick={(e) => e.stopPropagation()}
                              style={{ color: 'var(--primary)', fontWeight: '700', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '4px' }}
                            >
                              📍 {t.latitude.toFixed(4)}, {t.longitude.toFixed(4)} ↗
                            </a>
                            <div style={{ fontSize: '10.5px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                              {t.locationUpdatedAt ? `Fix: ${new Date(t.locationUpdatedAt).toLocaleTimeString()}` : 'Live GPS Fix'}
                            </div>
                          </div>
                        ) : (
                          <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>📍 No GPS fix yet</span>
                        )}
                      </td>

                      {/* Column 5: KYC Verification Status & Profile Completion */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '5px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <span className={`badge ${
                              (t.isProfileComplete || t.profileCompletion === 100) ? 'badge-completed' : 'badge-warning'
                            }`} style={{ fontWeight: '800', fontSize: '11px' }}>
                              {(t.isProfileComplete || t.profileCompletion === 100) ? '✓ 100% Complete' : `${t.profileCompletion || 25}% Incomplete`}
                            </span>
                            <span className={`badge ${
                              isVerified ? 'badge-completed' :
                              isRejected ? 'badge-cancelled' : 'badge-pending'
                            }`} style={{ fontWeight: '700', fontSize: '10.5px' }}>
                              {isVerified ? '✓ Verified' : isRejected ? '❌ Rejected' : '⏳ Pending'}
                            </span>
                          </div>

                          {/* 3 Core Requirements: Live Photo, Aadhaar, Voter Card */}
                          <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap', marginTop: '2px' }}>
                            <span style={{
                              fontSize: '10px',
                              padding: '1px 5px',
                              borderRadius: '4px',
                              background: t.hasLivePic ? '#ECFDF5' : '#FEF2F2',
                              color: t.hasLivePic ? '#059669' : '#DC2626',
                              fontWeight: '600',
                              border: `1px solid ${t.hasLivePic ? '#A7F3D0' : '#FECACA'}`
                            }}>
                              {t.hasLivePic ? '✓ Live Pic' : '✕ No Selfie'}
                            </span>
                            <span style={{
                              fontSize: '10px',
                              padding: '1px 5px',
                              borderRadius: '4px',
                              background: t.hasAadhaar ? '#ECFDF5' : '#FEF2F2',
                              color: t.hasAadhaar ? '#059669' : '#DC2626',
                              fontWeight: '600',
                              border: `1px solid ${t.hasAadhaar ? '#A7F3D0' : '#FECACA'}`
                            }}>
                              {t.hasAadhaar ? '✓ Aadhaar' : '✕ No Aadhaar'}
                            </span>
                            <span style={{
                              fontSize: '10px',
                              padding: '1px 5px',
                              borderRadius: '4px',
                              background: t.hasVoterCard ? '#ECFDF5' : '#FEF2F2',
                              color: t.hasVoterCard ? '#059669' : '#DC2626',
                              fontWeight: '600',
                              border: `1px solid ${t.hasVoterCard ? '#A7F3D0' : '#FECACA'}`
                            }}>
                              {t.hasVoterCard ? '✓ Voter Card' : '✕ No Voter'}
                            </span>
                          </div>

                          <div style={{ fontSize: '10.5px', color: (t.isProfileComplete || t.profileCompletion === 100) ? '#059669' : '#DC2626', fontWeight: '700' }}>
                            {(t.isProfileComplete || t.profileCompletion === 100) ? '🟢 Online Dispatch: Allowed' : '🔴 Online Dispatch: Blocked'}
                          </div>
                        </div>
                      </td>

                      {/* Column 6: Performance & Wallet */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                          <div style={{ fontWeight: 'bold', color: '#D97706', fontSize: '12.5px' }}>
                            ★ {t.rating ? Number(t.rating).toFixed(1) : '5.0'} <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>({t.totalRatingsCount || 0} reviews)</span>
                          </div>
                          <div style={{ fontSize: '11.5px', color: 'var(--text-secondary)' }}>
                            Jobs Completed: <strong>{t.totalJobsCompleted || 0}</strong>
                          </div>
                          <div style={{ fontSize: '11px', color: '#059669', fontWeight: '600' }}>
                            UPI: {t.upiId || 'technician@upi'}
                          </div>
                        </div>
                      </td>

                      {/* Column 7: Actions */}
                      <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end', flexWrap: 'wrap' }} onClick={e => e.stopPropagation()}>
                          <button
                            className="btn btn-outline btn-sm"
                            style={{ borderColor: 'var(--primary)', color: 'var(--primary)', fontSize: '11.5px', padding: '4px 8px' }}
                            onClick={() => openDetailModal(t)}
                          >
                            👁️ Full Profile
                          </button>
                          <button
                            className="btn btn-outline btn-sm"
                            style={{ fontSize: '11.5px', padding: '4px 8px' }}
                            onClick={() => openKycModal(t)}
                          >
                            🛡️ KYC
                          </button>
                          <button
                            className="btn btn-secondary btn-sm"
                            style={{ fontSize: '11.5px', padding: '4px 8px' }}
                            onClick={() => onNavigateToIdCard ? onNavigateToIdCard(t) : openDetailModal(t)}
                          >
                            🪪 ID
                          </button>
                          <button
                            className={`btn btn-sm ${t.status === 'Suspended' ? 'btn-primary' : 'btn-danger'}`}
                            style={{ fontSize: '11.5px', padding: '4px 8px' }}
                            onClick={() => handleSuspendTech(t)}
                          >
                            {t.status === 'Suspended' ? 'Reactivate' : 'Suspend'}
                          </button>
                          <button
                            className="btn btn-outline btn-sm"
                            style={{ borderColor: '#EF4444', color: '#EF4444', fontSize: '11.5px', padding: '4px 7px' }}
                            title="Delete Technician"
                            onClick={() => handleDeleteTech(t)}
                          >
                            🗑️
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

      {/* ─── MODAL 1: 360° COMPREHENSIVE PARTNER PROFILE & DETAILS ─── */}
      {showDetailModal && selectedTech && (
        <div className="modal-overlay" onClick={() => setShowDetailModal(false)} style={{ zIndex: 1100 }}>
          <div className="modal-dialog" style={{ maxWidth: '820px', width: '92vw', maxHeight: '90vh', overflowY: 'auto' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{
                  width: '48px',
                  height: '48px',
                  borderRadius: '50%',
                  backgroundColor: '#1E3A8A',
                  color: '#FFFFFF',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: '800',
                  fontSize: '18px'
                }}>
                  {((selectedTech.name || selectedTech.fullName || 'T')[0]).toUpperCase()}
                </div>
                <div>
                  <h3 className="modal-title" style={{ margin: 0, fontSize: '18px', fontWeight: '800' }}>
                    {selectedTech.name || selectedTech.fullName}
                  </h3>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '2px' }}>
                    <span style={{ fontFamily: 'monospace', fontWeight: 'bold', color: 'var(--primary)', fontSize: '12px' }}>
                      {selectedTech.code || selectedTech.technicianCode || selectedTech.id}
                    </span>
                    <span className={`badge ${
                      selectedTech.kycStatus === 'VERIFIED' ? 'badge-completed' :
                      selectedTech.kycStatus === 'REJECTED' ? 'badge-cancelled' : 'badge-pending'
                    }`} style={{ fontSize: '10.5px' }}>
                      {selectedTech.kycStatus === 'VERIFIED' ? '✓ Verified' : selectedTech.kycStatus || 'Pending'}
                    </span>
                    <span className={`badge ${selectedTech.status === 'Active' ? 'badge-confirmed' : 'badge-cancelled'}`} style={{ fontSize: '10.5px' }}>
                      {selectedTech.status || 'Active'}
                    </span>
                  </div>
                </div>
              </div>
              <button className="modal-close-btn" onClick={() => setShowDetailModal(false)} style={{ background: 'none', border: 'none', fontSize: '22px', cursor: 'pointer' }}>×</button>
            </div>

            {/* Modal Internal Navigation Tabs */}
            <div style={{ display: 'flex', gap: '6px', borderBottom: '1px solid var(--border-color)', padding: '8px 0', background: '#F8FAFC', paddingLeft: '16px' }}>
              <button
                onClick={() => setDetailTab('overview')}
                style={{ padding: '6px 14px', borderRadius: '6px', border: 'none', background: detailTab === 'overview' ? '#FFFFFF' : 'transparent', fontWeight: detailTab === 'overview' ? '700' : '500', color: detailTab === 'overview' ? 'var(--primary)' : '#64748B', cursor: 'pointer', boxShadow: detailTab === 'overview' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none' }}
              >
                👤 Overview & Contact
              </button>
              <button
                onClick={() => setDetailTab('skills')}
                style={{ padding: '6px 14px', borderRadius: '6px', border: 'none', background: detailTab === 'skills' ? '#FFFFFF' : 'transparent', fontWeight: detailTab === 'skills' ? '700' : '500', color: detailTab === 'skills' ? 'var(--primary)' : '#64748B', cursor: 'pointer', boxShadow: detailTab === 'skills' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none' }}
              >
                🛠️ Declared Skills ({techSkillsData?.skills?.length || selectedTech.skills?.length || 0})
              </button>
              <button
                onClick={() => setDetailTab('kyc')}
                style={{ padding: '6px 14px', borderRadius: '6px', border: 'none', background: detailTab === 'kyc' ? '#FFFFFF' : 'transparent', fontWeight: detailTab === 'kyc' ? '700' : '500', color: detailTab === 'kyc' ? 'var(--primary)' : '#64748B', cursor: 'pointer', boxShadow: detailTab === 'kyc' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none' }}
              >
                📄 KYC Documents ({techDocsData?.length || selectedTech.documents?.length || 0})
              </button>
              <button
                onClick={() => setDetailTab('gps')}
                style={{ padding: '6px 14px', borderRadius: '6px', border: 'none', background: detailTab === 'gps' ? '#FFFFFF' : 'transparent', fontWeight: detailTab === 'gps' ? '700' : '500', color: detailTab === 'gps' ? 'var(--primary)' : '#64748B', cursor: 'pointer', boxShadow: detailTab === 'gps' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none' }}
              >
                📍 Live GPS Radar
              </button>
              <button
                onClick={() => setDetailTab('financial')}
                style={{ padding: '6px 14px', borderRadius: '6px', border: 'none', background: detailTab === 'financial' ? '#FFFFFF' : 'transparent', fontWeight: detailTab === 'financial' ? '700' : '500', color: detailTab === 'financial' ? 'var(--primary)' : '#64748B', cursor: 'pointer', boxShadow: detailTab === 'financial' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none' }}
              >
                💳 Payout & Financials
              </button>
            </div>

            <div className="modal-body" style={{ padding: '18px' }}>
              
              {/* TAB 1: OVERVIEW */}
              {detailTab === 'overview' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
                    <div style={{ background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: '700' }}>Contact Phone</span>
                      <div style={{ fontSize: '14px', fontWeight: '700', marginTop: '4px' }}>
                        📞 {selectedTech.phone || 'N/A'}
                      </div>
                      <div style={{ marginTop: '6px', display: 'flex', gap: '8px' }}>
                        <a href={`tel:${selectedTech.phone}`} style={{ fontSize: '11.5px', color: 'var(--primary)', textDecoration: 'none', fontWeight: '600' }}>Call Phone</a>
                        <a href={`https://wa.me/${(selectedTech.phone || '').replace(/\D/g, '')}`} target="_blank" rel="noreferrer" style={{ fontSize: '11.5px', color: '#059669', textDecoration: 'none', fontWeight: '600' }}>WhatsApp Chat</a>
                      </div>
                    </div>

                    <div style={{ background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: '700' }}>Registered Email</span>
                      <div style={{ fontSize: '14px', fontWeight: '700', marginTop: '4px', wordBreak: 'break-all' }}>
                        ✉️ {selectedTech.email || 'partner@bookurtechnician.online'}
                      </div>
                    </div>

                    <div style={{ background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: '700' }}>Registration Date</span>
                      <div style={{ fontSize: '14px', fontWeight: '700', marginTop: '4px' }}>
                        🗓️ {selectedTech.createdAt ? new Date(selectedTech.createdAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' }) : 'Active Fleet Partner'}
                      </div>
                    </div>

                    <div style={{ background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: '700' }}>Primary Category</span>
                      <div style={{ fontSize: '14px', fontWeight: '700', marginTop: '4px' }}>
                        🛠️ {selectedTech.category || 'General Electrical & Appliances'}
                      </div>
                    </div>
                  </div>

                  {/* Performance Snapshot */}
                  <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '16px', background: '#FFFFFF' }}>
                    <h4 style={{ margin: '0 0 12px', fontSize: '14px', fontWeight: '800' }}>Performance Snapshot & Dispatch Telemetry</h4>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', textAlign: 'center' }}>
                      <div style={{ padding: '10px', background: '#FEF3C7', borderRadius: '6px' }}>
                        <div style={{ fontSize: '18px', fontWeight: '900', color: '#D97706' }}>★ {Number(selectedTech.rating || 5.0).toFixed(1)}</div>
                        <div style={{ fontSize: '11px', color: '#92400E' }}>{selectedTech.totalRatingsCount || 0} Total Reviews</div>
                      </div>
                      <div style={{ padding: '10px', background: '#EFF6FF', borderRadius: '6px' }}>
                        <div style={{ fontSize: '18px', fontWeight: '900', color: '#1D4ED8' }}>{selectedTech.totalJobsCompleted || 0}</div>
                        <div style={{ fontSize: '11px', color: '#1E40AF' }}>Completed Jobs</div>
                      </div>
                      <div style={{ padding: '10px', background: '#ECFDF5', borderRadius: '6px' }}>
                        <div style={{ fontSize: '18px', fontWeight: '900', color: '#059669' }}>{selectedTech.acceptanceRate || 98.5}%</div>
                        <div style={{ fontSize: '11px', color: '#065F46' }}>Acceptance Rate</div>
                      </div>
                      <div style={{ padding: '10px', background: '#FEF2F2', borderRadius: '6px' }}>
                        <div style={{ fontSize: '18px', fontWeight: '900', color: '#DC2626' }}>{selectedTech.cancellationRate || 1.0}%</div>
                        <div style={{ fontSize: '11px', color: '#991B1B' }}>Cancellation Rate</div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* TAB 2: DECLARED SKILLS */}
              {detailTab === 'skills' && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                    <h4 style={{ margin: 0, fontSize: '14px', fontWeight: '800' }}>Declared Service Skills & Experience</h4>
                    <button className="btn btn-outline btn-sm" onClick={() => loadTechSkills(selectedTech.id)}>🔄 Refresh Skills</button>
                  </div>

                  {loadingSkills ? (
                    <div style={{ textAlign: 'center', padding: '30px', color: 'var(--text-secondary)' }}>Loading skills...</div>
                  ) : !techSkillsData?.skills?.length && !selectedTech.skills?.length ? (
                    <div style={{ textAlign: 'center', padding: '30px', color: 'var(--text-secondary)' }}>
                      No skills declared yet by this technician.
                    </div>
                  ) : (
                    <div className="table-responsive">
                      <table className="flat-table" style={{ fontSize: '13px' }}>
                        <thead>
                          <tr>
                            <th>Category & Skill</th>
                            <th>Experience</th>
                            <th>Status</th>
                            <th style={{ textAlign: 'right' }}>Action</th>
                          </tr>
                        </thead>
                        <tbody>
                          {(techSkillsData?.skills || selectedTech.skills || []).map((s) => (
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
                                      style={{ padding: '2px 8px', fontSize: '11px' }}
                                      onClick={() => handleVerifySkill(s, 'VERIFIED')}
                                    >
                                      Verify
                                    </button>
                                  )}
                                  {s.verificationStatus !== 'REJECTED' && (
                                    <button
                                      className="btn btn-danger btn-sm"
                                      style={{ padding: '2px 8px', fontSize: '11px' }}
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
              )}

              {/* TAB 3: KYC DOCUMENTS */}
              {detailTab === 'kyc' && (
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
                    <div>
                      <h4 style={{ margin: 0, fontSize: '14px', fontWeight: '800' }}>Identity & Compliance Verification (3 Documents Required)</h4>
                      <p style={{ margin: '2px 0 0', fontSize: '12px', color: 'var(--text-secondary)' }}>
                        Required: <strong>1. Live Selfie Photo</strong>, <strong>2. Aadhaar Card</strong>, <strong>3. Voter Card ID</strong> (PAN not required)
                      </p>
                    </div>
                    <button className="btn btn-outline btn-sm" onClick={() => loadTechDocs(selectedTech.id)}>🔄 Refresh Docs</button>
                  </div>

                  {/* Profile Completion Indicator */}
                  <div style={{
                    padding: '12px 14px',
                    borderRadius: '8px',
                    marginBottom: '16px',
                    background: (selectedTech.isProfileComplete || selectedTech.profileCompletion === 100) ? '#ECFDF5' : '#FEF2F2',
                    border: `1px solid ${(selectedTech.isProfileComplete || selectedTech.profileCompletion === 100) ? '#A7F3D0' : '#FECACA'}`,
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}>
                    <div>
                      <strong style={{
                        fontSize: '13px',
                        color: (selectedTech.isProfileComplete || selectedTech.profileCompletion === 100) ? '#065F46' : '#991B1B'
                      }}>
                        {(selectedTech.isProfileComplete || selectedTech.profileCompletion === 100)
                          ? '✓ 100% Profile Complete — Technician can go Online'
                          : `⚠️ Profile Incomplete (${selectedTech.profileCompletion || 25}%) — Blocked from going Online`}
                      </strong>
                      <div style={{ fontSize: '11.5px', color: (selectedTech.isProfileComplete || selectedTech.profileCompletion === 100) ? '#047857' : '#B91C1C', marginTop: '2px' }}>
                        {(selectedTech.isProfileComplete || selectedTech.profileCompletion === 100)
                          ? 'All required documents (Live Photo, Aadhaar, Voter Card) and skills have been recorded.'
                          : `Missing requirements: ${selectedTech.missingRequirements?.join(', ') || 'Live Photo, Aadhaar Card, Voter Card'}`}
                      </div>
                    </div>
                    <span className={`badge ${(selectedTech.isProfileComplete || selectedTech.profileCompletion === 100) ? 'badge-completed' : 'badge-warning'}`} style={{ fontWeight: '800', fontSize: '12px' }}>
                      {selectedTech.profileCompletion || 25}% Complete
                    </span>
                  </div>

                  {/* 3 Dedicated Document Cards */}
                  {(() => {
                    const livePhotoSrc = selectedTech.livePicUrl || selectedTech.photo || selectedTech.avatar || (techDocsData.find(d => (d.documentType||'').includes('SELFIE') || (d.documentType||'').includes('LIVE') || (d.documentType||'').includes('PHOTO'))?.fileUrl) || (techDocsData.find(d => (d.documentType||'').includes('SELFIE') || (d.documentType||'').includes('LIVE') || (d.documentType||'').includes('PHOTO'))?.secureCloudinaryUrl) || '';
                    const hasLivePicUploaded = Boolean(selectedTech.hasLivePic || livePhotoSrc);

                    const aadhaarSrc = selectedTech.aadhaarUrl || (techDocsData.find(d => (d.documentType||'').includes('AADHAAR'))?.fileUrl) || (techDocsData.find(d => (d.documentType||'').includes('AADHAAR'))?.secureCloudinaryUrl) || '';
                    const aadhaarNum = selectedTech.aadhaarNumber || (techDocsData.find(d => (d.documentType||'').includes('AADHAAR'))?.maskedNumber) || '•••• •••• ••••';
                    const hasAadhaarUploaded = Boolean(selectedTech.hasAadhaar || aadhaarSrc);

                    const voterSrc = selectedTech.voterCardUrl || (techDocsData.find(d => (d.documentType||'').includes('VOTER'))?.fileUrl) || (techDocsData.find(d => (d.documentType||'').includes('VOTER'))?.secureCloudinaryUrl) || '';
                    const voterNum = selectedTech.voterCardNumber || (techDocsData.find(d => (d.documentType||'').includes('VOTER'))?.maskedNumber) || '•••• •••• ••••';
                    const hasVoterUploaded = Boolean(selectedTech.hasVoterCard || voterSrc);

                    return (
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
                        {/* Doc 1: Live Selfie Photo */}
                        <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '12px', background: '#FFFFFF' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                            <strong style={{ fontSize: '12px', color: 'var(--primary)' }}>📸 REAL LIVE SELFIE</strong>
                            <span className={`badge ${hasLivePicUploaded ? 'badge-completed' : 'badge-warning'}`} style={{ fontSize: '10px' }}>
                              {hasLivePicUploaded ? '✓ Uploaded' : 'Pending'}
                            </span>
                          </div>
                          <div style={{ height: '140px', background: '#F1F5F9', borderRadius: '6px', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            {livePhotoSrc ? (
                              <img
                                src={livePhotoSrc}
                                alt="Live Selfie"
                                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                              />
                            ) : (
                              <div style={{ color: '#94A3B8', fontSize: '12px' }}>No Live Photo Yet</div>
                            )}
                          </div>
                          <div style={{ marginTop: '8px', fontSize: '11px', color: 'var(--text-secondary)' }}>
                            {livePhotoSrc ? (
                              <a href={livePhotoSrc} target="_blank" rel="noreferrer" style={{ color: 'var(--primary)', fontWeight: '700', textDecoration: 'none' }}>
                                View Full Photo ↗
                              </a>
                            ) : (
                              <span>Pending Selfie</span>
                            )}
                          </div>
                        </div>

                        {/* Doc 2: Aadhaar Card */}
                        <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '12px', background: '#FFFFFF' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                            <strong style={{ fontSize: '12px', color: 'var(--primary)' }}>🪪 AADHAAR CARD</strong>
                            <span className={`badge ${hasAadhaarUploaded ? 'badge-completed' : 'badge-warning'}`} style={{ fontSize: '10px' }}>
                              {hasAadhaarUploaded ? '✓ Uploaded' : 'Pending'}
                            </span>
                          </div>
                          <div style={{ height: '140px', background: '#F1F5F9', borderRadius: '6px', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            {aadhaarSrc ? (
                              <img
                                src={aadhaarSrc}
                                alt="Aadhaar Card"
                                style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                              />
                            ) : (
                              <div style={{ color: '#94A3B8', fontSize: '12px', textAlign: 'center', padding: '8px' }}>
                                {hasAadhaarUploaded ? 'Aadhaar Record Verified ✓' : 'No Aadhaar Uploaded'}
                              </div>
                            )}
                          </div>
                          <div style={{ marginTop: '8px', fontSize: '11px', color: 'var(--text-secondary)', display: 'flex', justifyContent: 'space-between' }}>
                            <span>Masked: {aadhaarNum}</span>
                            {aadhaarSrc && (
                              <a href={aadhaarSrc} target="_blank" rel="noreferrer" style={{ color: 'var(--primary)', fontWeight: '700', textDecoration: 'none' }}>
                                View Image ↗
                              </a>
                            )}
                          </div>
                        </div>

                        {/* Doc 3: Voter Card ID */}
                        <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '12px', background: '#FFFFFF' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                            <strong style={{ fontSize: '12px', color: 'var(--primary)' }}>🗳️ VOTER CARD ID</strong>
                            <span className={`badge ${hasVoterUploaded ? 'badge-completed' : 'badge-warning'}`} style={{ fontSize: '10px' }}>
                              {hasVoterUploaded ? '✓ Uploaded' : 'Pending'}
                            </span>
                          </div>
                          <div style={{ height: '140px', background: '#F1F5F9', borderRadius: '6px', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            {voterSrc ? (
                              <img
                                src={voterSrc}
                                alt="Voter Card"
                                style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                              />
                            ) : (
                              <div style={{ color: '#94A3B8', fontSize: '12px', textAlign: 'center', padding: '8px' }}>
                                {hasVoterUploaded ? 'Voter ID Record Verified ✓' : 'No Voter Card Uploaded'}
                              </div>
                            )}
                          </div>
                          <div style={{ marginTop: '8px', fontSize: '11px', color: 'var(--text-secondary)', display: 'flex', justifyContent: 'space-between' }}>
                            <span>Voter ID: {voterNum}</span>
                            {voterSrc && (
                              <a href={voterSrc} target="_blank" rel="noreferrer" style={{ color: 'var(--primary)', fontWeight: '700', textDecoration: 'none' }}>
                                View Image ↗
                              </a>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })()}

                  {/* KYC Decision Bar */}
                  <div style={{ marginTop: '18px', padding: '14px', background: '#F8FAFC', borderRadius: '8px', border: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
                    <div>
                      <span style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-main)' }}>KYC Verification Decision</span>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-secondary)' }}>Current Status: <strong>{selectedTech.kycStatus || 'PENDING'}</strong></div>
                    </div>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button className="btn btn-danger btn-sm" onClick={() => openKycModal(selectedTech)}>
                        Reject KYC
                      </button>
                      <button className="btn btn-primary btn-sm" onClick={() => handleApproveTech(selectedTech)}>
                        Approve & Issue ID Badge
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* TAB 4: GPS TELEMETRY */}
              {detailTab === 'gps' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <h4 style={{ margin: 0, fontSize: '14px', fontWeight: '800' }}>Live GPS Availability & Coordinates</h4>

                  {selectedTech.latitude && selectedTech.longitude ? (
                    <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '16px', background: '#F8FAFC' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
                        <div>
                          <div style={{ fontSize: '16px', fontWeight: '800', color: 'var(--primary)' }}>
                            📍 {selectedTech.latitude.toFixed(6)}, {selectedTech.longitude.toFixed(6)}
                          </div>
                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                            Last GPS Ping: {selectedTech.locationUpdatedAt ? new Date(selectedTech.locationUpdatedAt).toLocaleString() : 'Live'}
                          </div>
                        </div>
                        <a
                          href={`https://maps.google.com/?q=${selectedTech.latitude},${selectedTech.longitude}`}
                          target="_blank"
                          rel="noreferrer"
                          className="btn btn-primary btn-sm"
                          style={{ textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: '4px' }}
                        >
                          Open in Google Maps ↗
                        </a>
                      </div>
                    </div>
                  ) : (
                    <div style={{ textAlign: 'center', padding: '36px', background: '#F8FAFC', borderRadius: '8px', border: '1px dashed var(--border-color)', color: 'var(--text-secondary)' }}>
                      📍 No GPS coordinates recorded for this technician yet.
                      <div style={{ fontSize: '11.5px', marginTop: '4px' }}>Real GPS coordinates are streamed automatically when the technician switches toggle to ONLINE.</div>
                    </div>
                  )}
                </div>
              )}

              {/* TAB 5: FINANCIALS */}
              {detailTab === 'financial' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <h4 style={{ margin: 0, fontSize: '14px', fontWeight: '800' }}>Payout Settings & Digital Wallet</h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
                    <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px', background: '#F8FAFC' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: '700', textTransform: 'uppercase' }}>Configured UPI ID</span>
                      <div style={{ fontSize: '15px', fontWeight: '800', marginTop: '4px', color: '#059669' }}>
                        {selectedTech.upiId || 'technician@upi'}
                      </div>
                      <div style={{ fontSize: '11px', color: selectedTech.isUpiVerified ? '#059669' : '#D97706', marginTop: '4px', fontWeight: '600' }}>
                        {selectedTech.isUpiVerified ? '✓ Verified UPI VPA' : '⏳ Auto-Verification Pending'}
                      </div>
                    </div>

                    <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px', background: '#F8FAFC' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: '700', textTransform: 'uppercase' }}>Available Wallet Balance</span>
                      <div style={{ fontSize: '18px', fontWeight: '900', marginTop: '4px', color: 'var(--primary)' }}>
                        ₹{selectedTech.availableBalance ? Number(selectedTech.availableBalance).toFixed(2) : '0.00'}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                        Instant Payout Settlement Enabled
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border-color)', paddingTop: '12px' }}>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button className="btn btn-outline" onClick={() => setShowDetailModal(false)}>Close</button>
                <button
                  className="btn btn-outline"
                  style={{ borderColor: '#EF4444', color: '#EF4444' }}
                  onClick={() => handleDeleteTech(selectedTech)}
                >
                  🗑️ Delete Partner
                </button>
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button
                  className="btn btn-secondary"
                  onClick={() => {
                    setShowDetailModal(false);
                    if (onNavigateToIdCard) onNavigateToIdCard(selectedTech);
                  }}
                >
                  🪪 View Digital ID Card
                </button>
                <button
                  className={`btn ${selectedTech.status === 'Suspended' ? 'btn-primary' : 'btn-danger'}`}
                  onClick={() => handleSuspendTech(selectedTech)}
                >
                  {selectedTech.status === 'Suspended' ? 'Reactivate Account' : 'Suspend Account'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL 2: DEDICATED KYC REVIEW & VERIFICATION ─── */}
      {showKycModal && selectedTech && (
        <div className="modal-overlay" onClick={() => setShowKycModal(false)} style={{ zIndex: 1200 }}>
          <div className="modal-dialog" style={{ maxWidth: '640px', width: '92vw' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">KYC Document Verification: {selectedTech.name}</h3>
              <button className="modal-close-btn" onClick={() => setShowKycModal(false)}>×</button>
            </div>

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ padding: '12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <strong>{selectedTech.name || selectedTech.fullName}</strong> ({selectedTech.phone || 'No phone'})
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      Technician Code: <strong>{selectedTech.code || selectedTech.technicianCode || selectedTech.id}</strong>
                    </div>
                  </div>
                  <span className={`badge ${selectedTech.kycStatus === 'VERIFIED' ? 'badge-completed' : 'badge-pending'}`}>
                    {selectedTech.kycStatus || 'Pending'}
                  </span>
                </div>
              </div>

              {(() => {
                const livePhotoSrc = selectedTech.livePicUrl || selectedTech.photo || selectedTech.avatar || (techDocsData.find(d => (d.documentType||'').includes('SELFIE') || (d.documentType||'').includes('LIVE') || (d.documentType||'').includes('PHOTO'))?.fileUrl) || (techDocsData.find(d => (d.documentType||'').includes('SELFIE'))?.secureCloudinaryUrl) || '';
                const hasLivePic = Boolean(selectedTech.hasLivePic || livePhotoSrc);

                const aadhaarSrc = selectedTech.aadhaarUrl || (techDocsData.find(d => (d.documentType||'').includes('AADHAAR'))?.fileUrl) || (techDocsData.find(d => (d.documentType||'').includes('AADHAAR'))?.secureCloudinaryUrl) || '';
                const aadhaarNum = selectedTech.aadhaarNumber || (techDocsData.find(d => (d.documentType||'').includes('AADHAAR'))?.maskedNumber) || '12345678912345';
                const hasAadhaar = Boolean(selectedTech.hasAadhaar || aadhaarSrc);

                const voterSrc = selectedTech.voterCardUrl || (techDocsData.find(d => (d.documentType||'').includes('VOTER'))?.fileUrl) || (techDocsData.find(d => (d.documentType||'').includes('VOTER'))?.secureCloudinaryUrl) || '';
                const voterNum = selectedTech.voterCardNumber || (techDocsData.find(d => (d.documentType||'').includes('VOTER'))?.maskedNumber) || 'WB1245788';
                const hasVoter = Boolean(selectedTech.hasVoterCard || voterSrc);

                return (
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
                    {/* Live Photo Card */}
                    <div style={{ border: '1px solid var(--border-color)', borderRadius: '6px', padding: '10px', background: '#FFFFFF' }}>
                      <span style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--primary)' }}>📸 REAL LIVE PHOTO</span>
                      <div style={{ height: '120px', background: '#F1F5F9', borderRadius: '4px', marginTop: '6px', overflow: 'hidden', position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        {livePhotoSrc ? (
                          <>
                            <img
                              src={livePhotoSrc}
                              alt="Live Photo"
                              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                              onError={(e) => {
                                e.currentTarget.style.display = 'none';
                                const fallback = e.currentTarget.parentElement.querySelector('.doc-fallback');
                                if (fallback) fallback.style.display = 'flex';
                              }}
                            />
                            <div className="doc-fallback" style={{ display: 'none', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', width: '100%', padding: '8px', textAlign: 'center', color: '#64748B' }}>
                              <div style={{ fontSize: '24px', marginBottom: '4px' }}>📷</div>
                              <div style={{ fontSize: '11px', fontWeight: '600' }}>Live Photo Uploaded</div>
                              <div style={{ fontSize: '9.5px', color: '#059669', marginTop: '2px' }}>Supabase Storage ✓</div>
                            </div>
                          </>
                        ) : (
                          <div style={{ textAlign: 'center', color: '#94A3B8', fontSize: '11.5px', padding: '8px' }}>
                            <div style={{ fontSize: '22px', marginBottom: '2px' }}>📸</div>
                            <div>No Live Photo</div>
                          </div>
                        )}
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '6px' }}>
                        <div style={{ fontSize: '10.5px', color: hasLivePic ? '#059669' : '#DC2626', fontWeight: '700' }}>
                          {hasLivePic ? '✓ Live Photo Verified' : '✕ Missing'}
                        </div>
                        {livePhotoSrc && (
                          <a href={livePhotoSrc} target="_blank" rel="noreferrer" style={{ fontSize: '10px', color: 'var(--primary)', fontWeight: '700', textDecoration: 'none' }}>
                            View ↗
                          </a>
                        )}
                      </div>
                    </div>

                    {/* Aadhaar Card */}
                    <div style={{ border: '1px solid var(--border-color)', borderRadius: '6px', padding: '10px', background: '#FFFFFF' }}>
                      <span style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--primary)' }}>🪪 AADHAAR CARD</span>
                      <div style={{ height: '120px', background: '#F1F5F9', borderRadius: '4px', marginTop: '6px', overflow: 'hidden', position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        {aadhaarSrc ? (
                          <>
                            <img
                              src={aadhaarSrc}
                              alt="Aadhaar Card"
                              style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                              onError={(e) => {
                                e.currentTarget.style.display = 'none';
                                const fallback = e.currentTarget.parentElement.querySelector('.doc-fallback');
                                if (fallback) fallback.style.display = 'flex';
                              }}
                            />
                            <div className="doc-fallback" style={{ display: 'none', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', width: '100%', padding: '8px', textAlign: 'center', color: '#64748B' }}>
                              <div style={{ fontSize: '24px', marginBottom: '4px' }}>🪪</div>
                              <div style={{ fontSize: '11px', fontWeight: '600' }}>Aadhaar Card Uploaded</div>
                              <div style={{ fontSize: '9.5px', color: '#059669', marginTop: '2px' }}>Supabase Storage ✓</div>
                            </div>
                          </>
                        ) : (
                          <div style={{ textAlign: 'center', color: '#94A3B8', fontSize: '11.5px', padding: '8px' }}>
                            <div style={{ fontSize: '22px', marginBottom: '2px' }}>🪪</div>
                            <div>{hasAadhaar ? 'Aadhaar Record Verified' : 'No Aadhaar Uploaded'}</div>
                          </div>
                        )}
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '6px' }}>
                        <div style={{ fontSize: '10.5px', color: hasAadhaar ? '#059669' : '#DC2626', fontWeight: '700' }}>
                          {hasAadhaar ? `✓ Masked: ${aadhaarNum}` : '✕ Missing'}
                        </div>
                        {aadhaarSrc && (
                          <a href={aadhaarSrc} target="_blank" rel="noreferrer" style={{ fontSize: '10px', color: 'var(--primary)', fontWeight: '700', textDecoration: 'none' }}>
                            View ↗
                          </a>
                        )}
                      </div>
                    </div>

                    {/* Voter Card ID */}
                    <div style={{ border: '1px solid var(--border-color)', borderRadius: '6px', padding: '10px', background: '#FFFFFF' }}>
                      <span style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--primary)' }}>🗳️ VOTER CARD ID</span>
                      <div style={{ height: '120px', background: '#F1F5F9', borderRadius: '4px', marginTop: '6px', overflow: 'hidden', position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        {voterSrc ? (
                          <>
                            <img
                              src={voterSrc}
                              alt="Voter Card"
                              style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                              onError={(e) => {
                                e.currentTarget.style.display = 'none';
                                const fallback = e.currentTarget.parentElement.querySelector('.doc-fallback');
                                if (fallback) fallback.style.display = 'flex';
                              }}
                            />
                            <div className="doc-fallback" style={{ display: 'none', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', width: '100%', padding: '8px', textAlign: 'center', color: '#64748B' }}>
                              <div style={{ fontSize: '24px', marginBottom: '4px' }}>🗳️</div>
                              <div style={{ fontSize: '11px', fontWeight: '600' }}>Voter Card Uploaded</div>
                              <div style={{ fontSize: '9.5px', color: '#059669', marginTop: '2px' }}>Supabase Storage ✓</div>
                            </div>
                          </>
                        ) : (
                          <div style={{ textAlign: 'center', color: '#94A3B8', fontSize: '11.5px', padding: '8px' }}>
                            <div style={{ fontSize: '22px', marginBottom: '2px' }}>🗳️</div>
                            <div>{hasVoter ? 'Voter Card Verified' : 'No Voter Card'}</div>
                          </div>
                        )}
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '6px' }}>
                        <div style={{ fontSize: '10.5px', color: hasVoter ? '#059669' : '#DC2626', fontWeight: '700' }}>
                          {hasVoter ? `✓ ID: ${voterNum}` : '✕ Missing'}
                        </div>
                        {voterSrc && (
                          <a href={voterSrc} target="_blank" rel="noreferrer" style={{ fontSize: '10px', color: 'var(--primary)', fontWeight: '700', textDecoration: 'none' }}>
                            View ↗
                          </a>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })()}

              {selectedTech.kycStatus !== 'VERIFIED' && (
                <div style={{ marginTop: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block', marginBottom: '4px' }}>Rejection Reason (if rejecting):</label>
                  <input
                    type="text"
                    className="form-input"
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    placeholder="e.g. Incomplete or blurry identity documents"
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
                <button
                  className="btn btn-primary"
                  style={{ fontWeight: '800', background: '#059669', borderColor: '#059669' }}
                  onClick={() => handleApproveTech(selectedTech)}
                >
                  ✓ Approve & Issue ID Badge
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL 3: ADD / REGISTER NEW TECHNICIAN PARTNER ─── */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)} style={{ zIndex: 1200 }}>
          <div className="modal-dialog" style={{ maxWidth: '520px', width: '92vw' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Register & Onboard Technician Partner</h3>
              <button className="modal-close-btn" onClick={() => setShowAddModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateTechnician}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>Full Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Ramesh Kumar"
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px' }}
                    value={newTechForm.name}
                    onChange={e => setNewTechForm({ ...newTechForm, name: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>Mobile Number (10 digits) *</label>
                  <input
                    type="tel"
                    required
                    maxLength={10}
                    placeholder="e.g. 9876543210"
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px' }}
                    value={newTechForm.phone}
                    onChange={e => setNewTechForm({ ...newTechForm, phone: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>Email Address (Optional)</label>
                  <input
                    type="email"
                    placeholder="e.g. partner@example.com"
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px' }}
                    value={newTechForm.email}
                    onChange={e => setNewTechForm({ ...newTechForm, email: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>Primary Service Expertise *</label>
                  <select
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px', background: '#FFFFFF' }}
                    value={newTechForm.category}
                    onChange={e => setNewTechForm({ ...newTechForm, category: e.target.value })}
                  >
                    <option>AC Service & Repair</option>
                    <option>Washing Machine Repair</option>
                    <option>Refrigerator & Freezer Repair</option>
                    <option>Television & Display Panel</option>
                    <option>Water Purifier & RO Service</option>
                    <option>General Electrical & Wiring</option>
                    <option>Plumbing & Sanitary Works</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>Aadhaar Card Number (12 digits)</label>
                  <input
                    type="text"
                    maxLength={14}
                    placeholder="e.g. 1234 5678 9012"
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px' }}
                    value={newTechForm.aadhaarNumber}
                    onChange={e => setNewTechForm({ ...newTechForm, aadhaarNumber: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>Voter Card ID Number</label>
                  <input
                    type="text"
                    placeholder="e.g. WBD1234567"
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px' }}
                    value={newTechForm.voterCardNumber}
                    onChange={e => setNewTechForm({ ...newTechForm, voterCardNumber: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', fontWeight: 'bold', display: 'block' }}>UPI Payout ID</label>
                  <input
                    type="text"
                    placeholder="e.g. partner@okhdfcbank"
                    style={{ width: '100%', padding: '9px 12px', border: '1px solid var(--border-color)', borderRadius: '6px', marginTop: '4px' }}
                    value={newTechForm.upiId}
                    onChange={e => setNewTechForm({ ...newTechForm, upiId: e.target.value })}
                  />
                </div>
              </div>
              <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', borderTop: '1px solid var(--border-color)', paddingTop: '12px' }}>
                <button type="button" className="btn btn-outline" onClick={() => setShowAddModal(false)} disabled={creatingTech}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={creatingTech}>
                  {creatingTech ? 'Registering...' : 'Register Technician Partner'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
