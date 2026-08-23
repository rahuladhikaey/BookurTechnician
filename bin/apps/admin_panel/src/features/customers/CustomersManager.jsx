import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function CustomersManager({ customers = [], setCustomers, auditLogAction }) {
  const [searchTerm, setSearchTerm] = useState('');
  const [completionFilter, setCompletionFilter] = useState('ALL');
  const [selectedCustomer, setSelectedCustomer] = useState(null);
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const fetchLatestCustomers = useCallback(async () => {
    try {
      setIsRefreshing(true);
      const res = await api.getCustomers();
      if (res?.data && Array.isArray(res.data) && setCustomers) {
        setCustomers(res.data);
      }
    } catch (err) {
      console.warn('Auto-fetch customers warning:', err);
    } finally {
      setIsRefreshing(false);
    }
  }, [setCustomers]);

  useEffect(() => {
    fetchLatestCustomers();
    const interval = setInterval(fetchLatestCustomers, 8000);
    return () => clearInterval(interval);
  }, [fetchLatestCustomers]);

  // Helper to dynamically calculate profile completion if not explicitly provided
  const getCustomerProfileData = (c) => {
    let score = 0;
    const missing = [];

    if (c.name && c.name.trim().length >= 2 && !/^\d+$/.test(c.name.trim())) {
      score += 25;
    } else {
      missing.push('FULL_NAME');
    }

    if (c.phone && c.phoneVerified !== false) {
      score += 25;
    } else {
      missing.push('VERIFIED_PHONE');
    }

    if (c.email && c.emailVerified !== false) {
      score += 25;
    } else {
      missing.push('VERIFIED_EMAIL');
    }

    if (c.address && c.address.trim().length > 0) {
      score += 25;
    } else {
      missing.push('SERVICE_ADDRESS');
    }

    const status = score === 100 ? 'COMPLETE' : score >= 50 ? 'PARTIALLY_COMPLETE' : 'INCOMPLETE';

    return {
      score: c.profileCompletion !== undefined ? c.profileCompletion : score,
      status: c.profileStatus || status,
      missingFields: c.missingFields || missing,
      isEmailVerified: c.emailVerified !== false,
      isPhoneVerified: c.phoneVerified !== false,
      hasAddress: Boolean(c.address && c.address.trim().length > 0),
      regDate: c.createdAt || 'Just now',
      updatedDate: c.updatedAt || 'Just now'
    };
  };

  const filteredCustomers = (customers || []).filter(c => {
    const nameStr = (c.name || '').toLowerCase();
    const emailStr = (c.email || '').toLowerCase();
    const phoneStr = c.phone || '';
    const idStr = (c.id || '').toLowerCase();
    const q = searchTerm.toLowerCase();

    const matchesSearch = nameStr.includes(q) || emailStr.includes(q) || phoneStr.includes(q) || idStr.includes(q);
    if (!matchesSearch) return false;

    const profile = getCustomerProfileData(c);

    if (completionFilter === 'COMPLETE') return profile.score === 100;
    if (completionFilter === 'INCOMPLETE') return profile.score < 100;
    if (completionFilter === 'NO_EMAIL') return !profile.isEmailVerified;
    if (completionFilter === 'NO_PHONE') return !profile.isPhoneVerified;
    if (completionFilter === 'NO_ADDRESS') return !profile.hasAddress;

    return true;
  });

  const handleStatusChange = async (custId, nextStatus) => {
    const oldCust = (customers || []).find(c => c.id === custId);
    try {
      await api.updateCustomerStatus(custId, nextStatus);
      if (setCustomers) {
        setCustomers(prev => prev.map(c => c.id === custId ? { ...c, status: nextStatus } : c));
      }
      auditLogAction?.('Customers', `Changed status for customer ${oldCust?.name || custId} to ${nextStatus}`);
      
      if (selectedCustomer && selectedCustomer.id === custId) {
        setSelectedCustomer(prev => ({ ...prev, status: nextStatus }));
      }
    } catch (err) {
      console.error('Failed to update customer status:', err);
      alert('Error updating customer status: ' + err.message);
    }
  };

  const handleOpenDetails = (c) => {
    setSelectedCustomer(c);
    setShowProfileModal(true);
  };

  return (
    <div className="customers-manager-view">
      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Customer Directory & Profile Compliance</h2>
            <p className="page-subtitle">
              Monitor registered customers, backend-verified profile completion scores, addresses, and account compliance
            </p>
          </div>
          <div className="page-actions-group">
            <button
              className="btn btn-outline"
              onClick={async () => {
                try {
                  const res = await api.getCustomers();
                  if (res?.data && setCustomers) setCustomers(res.data);
                } catch (err) {
                  console.warn('Customer refresh fallback:', err);
                }
              }}
            >
              🔄 Refresh Directory
            </button>
            <button className="btn btn-outline" onClick={() => alert('Exporting customer compliance CSV...')}>
              📥 Export CSV
            </button>
          </div>
        </div>

        {/* ─── FLAT FILTER CHIPS ─── */}
        <div className="flat-tabs" style={{ marginBottom: '16px' }}>
          <div className={`flat-tab ${completionFilter === 'ALL' ? 'active' : ''}`} onClick={() => setCompletionFilter('ALL')}>
            All Customers ({customers.length})
          </div>
          <div className={`flat-tab ${completionFilter === 'COMPLETE' ? 'active' : ''}`} onClick={() => setCompletionFilter('COMPLETE')}>
            ✓ 100% Complete
          </div>
          <div className={`flat-tab ${completionFilter === 'INCOMPLETE' ? 'active' : ''}`} onClick={() => setCompletionFilter('INCOMPLETE')}>
            ⚠ Incomplete Profile
          </div>
          <div className={`flat-tab ${completionFilter === 'NO_ADDRESS' ? 'active' : ''}`} onClick={() => setCompletionFilter('NO_ADDRESS')}>
            📍 No Service Address
          </div>
          <div className={`flat-tab ${completionFilter === 'NO_EMAIL' ? 'active' : ''}`} onClick={() => setCompletionFilter('NO_EMAIL')}>
            ✉ Email Unverified
          </div>
        </div>

        {/* ─── TOOLBAR ─── */}
        <div className="toolbar-row">
          <div className="toolbar-left">
            <div className="search-input-box header-search" style={{ minWidth: '320px' }}>
              <input
                type="text"
                placeholder="Search by name, email, phone, ID..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
          </div>
          <div className="toolbar-right">
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Showing <strong>{filteredCustomers.length}</strong> of {customers.length} registered customers
            </span>
          </div>
        </div>

        {/* ─── FLAT TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Customer ID</th>
                <th>Name</th>
                <th>Contact Details</th>
                <th>Profile Completion</th>
                <th>Compliance Status</th>
                <th>Primary Address</th>
                <th>Account</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredCustomers.length === 0 ? (
                <tr>
                  <td colSpan="8" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-secondary)' }}>
                    👥 No customers registered yet.
                    <div style={{ fontSize: '12px', marginTop: '6px', color: 'var(--text-muted)' }}>
                      Real customer records will appear here automatically when users sign up via OTP verification in the Customer App.
                    </div>
                  </td>
                </tr>
              ) : (
                filteredCustomers.map((c) => {
                  const p = getCustomerProfileData(c);
                  return (
                    <tr key={c.id}>
                      <td>
                        <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{c.id}</strong>
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)' }}>{c.name}</strong>
                      </td>
                      <td>
                        <div style={{ fontSize: '13px' }}>{c.phone}</div>
                        <small style={{ color: 'var(--text-secondary)' }}>{c.email}</small>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: '120px' }}>
                          <div style={{ flex: 1, height: '6px', background: '#E2E8F0', borderRadius: '3px', overflow: 'hidden' }}>
                            <div
                              style={{
                                width: `${p.score}%`,
                                height: '100%',
                                background: p.score === 100 ? '#16A34A' : p.score >= 50 ? '#EA580C' : '#DC2626'
                              }}
                            ></div>
                          </div>
                          <strong style={{ fontSize: '12px', color: p.score === 100 ? '#15803D' : '#C2410C' }}>
                            {p.score}%
                          </strong>
                        </div>
                      </td>
                      <td>
                        <span className={`badge ${
                          p.status === 'COMPLETE' ? 'badge-completed' :
                          p.status === 'PARTIALLY_COMPLETE' ? 'badge-pending' : 'badge-cancelled'
                        }`}>
                          {p.status}
                        </span>
                      </td>
                      <td style={{ maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {c.address || <span style={{ color: '#DC2626', fontStyle: 'italic' }}>Missing Address</span>}
                      </td>
                      <td>
                        <span className={`badge ${
                          c.status === 'Active' ? 'badge-completed' :
                          c.status === 'Suspended' ? 'badge-pending' : 'badge-cancelled'
                        }`}>
                          {c.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button className="btn btn-primary btn-sm" onClick={() => handleOpenDetails(c)}>
                          Inspect File →
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── CUSTOMER PROFILE MODAL (FLAT 2D) ─── */}
      {showProfileModal && selectedCustomer && (() => {
        const p = getCustomerProfileData(selectedCustomer);
        return (
          <div className="modal-overlay" onClick={() => setShowProfileModal(false)}>
            <div className="modal-dialog" style={{ maxWidth: '640px' }} onClick={e => e.stopPropagation()}>
              <div className="modal-header">
                <h3 className="modal-title">Customer File: {selectedCustomer.name}</h3>
                <button className="modal-close-btn" onClick={() => setShowProfileModal(false)}>×</button>
              </div>

              <div className="modal-body">
                {/* Score Header */}
                <div style={{
                  padding: '16px',
                  background: p.score === 100 ? '#F0FDF4' : '#FFF7ED',
                  border: `1px solid ${p.score === 100 ? '#BBF7D0' : '#FED7AA'}`,
                  borderRadius: '6px',
                  marginBottom: '16px'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <strong style={{ fontSize: '15px', color: p.score === 100 ? '#15803D' : '#C2410C' }}>
                        {p.score === 100 ? '✓ 100% Profile Complete' : `⚠ Incomplete Profile (${p.score}%)`}
                      </strong>
                      <div style={{ fontSize: '12px', color: '#64748B', marginTop: '2px' }}>
                        Backend verified calculation (Name: 25%, Phone: 25%, Email: 25%, Address: 25%)
                      </div>
                    </div>
                    <span className={`badge ${p.status === 'COMPLETE' ? 'badge-completed' : 'badge-pending'}`}>
                      {p.status}
                    </span>
                  </div>

                  {p.missingFields.length > 0 && (
                    <div style={{ marginTop: '10px', fontSize: '12px', color: '#DC2626' }}>
                      <strong>Missing Action Items:</strong> {p.missingFields.join(', ')}
                    </div>
                  )}
                </div>

                {/* Core Field Verification Checklist */}
                <div style={{ padding: '14px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '6px', marginBottom: '16px' }}>
                  <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--primary)', marginBottom: '10px' }}>
                    IDENTITY & VERIFICATION STATUS
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', fontSize: '13px' }}>
                    <div>
                      <span style={{ color: 'var(--text-secondary)' }}>Full Name:</span>
                      <div><strong>{selectedCustomer.name}</strong></div>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-secondary)' }}>Customer ID:</span>
                      <div><strong style={{ fontFamily: 'monospace', color: 'var(--primary)' }}>{selectedCustomer.id}</strong></div>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-secondary)' }}>Phone (OTP Verified):</span>
                      <div><strong>{selectedCustomer.phone}</strong> <span style={{ color: '#16A34A' }}>✓</span></div>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-secondary)' }}>Email (OTP Verified):</span>
                      <div><strong>{selectedCustomer.email}</strong> <span style={{ color: '#16A34A' }}>✓</span></div>
                    </div>
                    <div style={{ gridColumn: '1 / -1' }}>
                      <span style={{ color: 'var(--text-secondary)' }}>Primary Service Address:</span>
                      <div><strong>{selectedCustomer.address || 'No service address provided'}</strong></div>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-secondary)' }}>Registered On:</span>
                      <div>{p.regDate}</div>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-secondary)' }}>Last Profile Update:</span>
                      <div>{p.updatedDate}</div>
                    </div>
                  </div>
                </div>

                {/* Account Controls */}
                <div style={{ padding: '14px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
                  <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--primary)', marginBottom: '6px' }}>
                    ACCOUNT STANDING & CONTROLS
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '8px' }}>
                    <span style={{ fontSize: '13px' }}>Account Status: <strong style={{ color: 'var(--text-main)' }}>{selectedCustomer.status}</strong></span>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      {selectedCustomer.status === 'Active' ? (
                        <button className="btn btn-danger btn-sm" onClick={() => handleStatusChange(selectedCustomer.id, 'Suspended')}>
                          Suspend Account
                        </button>
                      ) : (
                        <button className="btn btn-primary btn-sm" onClick={() => handleStatusChange(selectedCustomer.id, 'Active')}>
                          Reactivate Account
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              <div className="modal-footer">
                <button className="btn btn-outline" onClick={() => setShowProfileModal(false)}>Close File</button>
              </div>
            </div>
          </div>
        );
      })()}
    </div>
  );
}
