import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';
import ForceAssignModal from './ForceAssignModal';
import OtpDisputeModal from '../support/OtpDisputeModal';

const STAGES = [
  { key: 'PENDING', label: 'Unassigned (Pending)', bg: '#FFFBEB', border: '#FDE68A', text: '#D97706', dot: '#D97706' },
  { key: 'ACCEPTED', label: 'Accepted / Dispatched', bg: '#EFF6FF', border: '#BFDBFE', text: '#1E40AF', dot: '#1E40AF' },
  { key: 'ARRIVED', label: 'Arrived at Doorstep', bg: '#FAF5FF', border: '#E9D5FF', text: '#7E22CE', dot: '#7E22CE' },
  { key: 'IN_PROGRESS', label: 'In Progress (Start OTP)', bg: '#EEF2FF', border: '#C7D2FE', text: '#4338CA', dot: '#4338CA' },
  { key: 'COMPLETED', label: 'Completed (Settled)', bg: '#ECFDF5', border: '#A7F3D0', text: '#15803D', dot: '#15803D' },
  { key: 'CANCELLED', label: 'Cancelled / Refunded', bg: '#FEF2F2', border: '#FCA5A5', text: '#DC2626', dot: '#DC2626' },
];

export default function LiveBookingRadar() {
  const [bookings, setBookings] = useState([]);
  const [summary, setSummary] = useState({ PENDING: 0, ACCEPTED: 0, ARRIVED: 0, IN_PROGRESS: 0, COMPLETED: 0, CANCELLED: 0, TOTAL: 0 });
  const [loading, setLoading] = useState(true);
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState('kanban'); // 'kanban' | 'table'
  const [autoRefresh, setAutoRefresh] = useState(true);

  // Modals state
  const [forceAssignTarget, setForceAssignTarget] = useState(null);
  const [otpDisputeTarget, setOtpDisputeTarget] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);

  const fetchLiveBookings = useCallback(async () => {
    try {
      const res = await api.getBookings({ status: selectedStatus !== 'ALL' ? selectedStatus : undefined });
      const list = res?.data || (Array.isArray(res) ? res : []);
      
      const newSummary = { PENDING: 0, ACCEPTED: 0, ARRIVED: 0, IN_PROGRESS: 0, COMPLETED: 0, CANCELLED: 0, TOTAL: list.length };
      list.forEach(b => {
        const s = (b.status || 'PENDING').toUpperCase();
        if (newSummary[s] !== undefined) newSummary[s]++;
      });

      setBookings(list);
      setSummary(newSummary);
    } catch (err) {
      console.warn('Live booking radar notice:', err);
    } finally {
      setLoading(false);
    }
  }, [selectedStatus]);

  useEffect(() => {
    fetchLiveBookings();
  }, [fetchLiveBookings]);

  // Auto-refresh interval every 8 seconds
  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(() => {
      fetchLiveBookings();
    }, 8000);
    return () => clearInterval(interval);
  }, [autoRefresh, fetchLiveBookings]);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const filteredBookings = bookings.filter(b => {
    const s = (b.status || 'PENDING').toUpperCase();
    const matchesStatus = selectedStatus === 'ALL' || s === selectedStatus;
    const query = searchQuery.toLowerCase().trim();
    if (!query) return matchesStatus;

    const code = (b.bookingCode || b.id || '').toLowerCase();
    const customer = (b.customer?.fullName || b.customerName || '').toLowerCase();
    const tech = (b.technician?.user?.fullName || b.technician?.name || '').toLowerCase();
    const service = (b.service?.name || b.serviceType || '').toLowerCase();

    return matchesStatus && (code.includes(query) || customer.includes(query) || tech.includes(query) || service.includes(query));
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {toastMessage && (
        <div style={{
          position: 'fixed',
          bottom: '24px',
          right: '24px',
          zIndex: 999,
          padding: '12px 18px',
          backgroundColor: '#0F172A',
          color: '#FFFFFF',
          borderRadius: '8px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.15)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          fontSize: '13px',
          fontWeight: '700'
        }}>
          <span>✓</span>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* ─── 1. TOP OPERATIONS HEADER BAR ─── */}
      <div className="panel" style={{ margin: 0, display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '8px',
            backgroundColor: '#0F172A',
            color: '#FFFFFF',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '20px'
          }}>
            📡
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h2 style={{ fontSize: '18px', fontWeight: '800', color: '#0F172A', margin: 0 }}>
                Live Operations Radar & Dispatch Tower
              </h2>
              <span className="live-badge" style={{ fontSize: '10px', padding: '2px 8px', borderRadius: '4px' }}>
                LIVE STREAM
              </span>
            </div>
            <p style={{ fontSize: '12.5px', color: '#64748B', margin: '2px 0 0' }}>
              Real-time pipeline monitoring, 15 km spatial force-assign, and dual-OTP dispute controls
            </p>
          </div>
        </div>

        {/* Action Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
          <button
            onClick={() => setAutoRefresh(!autoRefresh)}
            className="btn btn-outline btn-sm"
            style={{
              borderColor: autoRefresh ? '#10B981' : '#CBD5E1',
              color: autoRefresh ? '#047857' : '#64748B',
              backgroundColor: autoRefresh ? '#ECFDF5' : '#FFFFFF',
              fontWeight: '700'
            }}
          >
            <span>{autoRefresh ? '🔄 Auto-Sync: Active (8s)' : '⏸ Auto-Sync: Paused'}</span>
          </button>

          <button onClick={fetchLiveBookings} className="btn btn-outline btn-sm" title="Refresh Live Data">
            Refresh
          </button>

          <div style={{ display: 'flex', backgroundColor: '#F1F5F9', borderRadius: '6px', padding: '2px', border: '1px solid #E2E8F0' }}>
            <button
              onClick={() => setViewMode('kanban')}
              style={{
                padding: '5px 12px',
                borderRadius: '4px',
                border: 'none',
                backgroundColor: viewMode === 'kanban' ? '#0F172A' : 'transparent',
                color: viewMode === 'kanban' ? '#FFFFFF' : '#64748B',
                fontSize: '12px',
                fontWeight: '700',
                cursor: 'pointer'
              }}
            >
              Kanban Pipeline
            </button>
            <button
              onClick={() => setViewMode('table')}
              style={{
                padding: '5px 12px',
                borderRadius: '4px',
                border: 'none',
                backgroundColor: viewMode === 'table' ? '#0F172A' : 'transparent',
                color: viewMode === 'table' ? '#FFFFFF' : '#64748B',
                fontSize: '12px',
                fontWeight: '700',
                cursor: 'pointer'
              }}
            >
              Table View
            </button>
          </div>
        </div>
      </div>

      {/* ─── 2. STAGE SUMMARY STAT CARDS ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px' }}>
        {STAGES.map(stage => {
          const count = summary[stage.key] || 0;
          const isSelected = selectedStatus === stage.key;
          return (
            <div
              key={stage.key}
              onClick={() => setSelectedStatus(isSelected ? 'ALL' : stage.key)}
              style={{
                backgroundColor: isSelected ? stage.bg : '#FFFFFF',
                border: `1.5px solid ${isSelected ? '#0F172A' : stage.border}`,
                borderRadius: '8px',
                padding: '12px 14px',
                cursor: 'pointer',
                transition: 'all 0.15s ease'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <span style={{ fontSize: '11px', fontWeight: '800', color: stage.text, textTransform: 'uppercase' }}>
                  {stage.key}
                </span>
                <span style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: stage.dot }}></span>
              </div>
              <div style={{ fontSize: '22px', fontWeight: '900', color: '#0F172A' }}>{count}</div>
              <div style={{ fontSize: '11px', color: '#64748B', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {stage.label}
              </div>
            </div>
          );
        })}
      </div>

      {/* ─── 3. SEARCH & FILTER TOOLBAR ─── */}
      <div className="panel" style={{ margin: 0, padding: '12px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div style={{ position: 'relative', width: '100%', maxWidth: '360px' }}>
          <input
            type="text"
            className="form-control"
            placeholder="Search booking code, customer, technician, service..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{ paddingLeft: '34px', fontSize: '13px' }}
          />
          <span style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', opacity: 0.5 }}>
            🔍
          </span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', fontSize: '13px', color: '#64748B' }}>
          <span>
            Showing <strong style={{ color: '#0F172A' }}>{filteredBookings.length}</strong> active jobs
          </span>
          {selectedStatus !== 'ALL' && (
            <button
              onClick={() => setSelectedStatus('ALL')}
              className="btn btn-outline btn-sm"
              style={{ fontSize: '11px', padding: '2px 8px' }}
            >
              Clear Filter ({selectedStatus})
            </button>
          )}
        </div>
      </div>

      {/* ─── 4. MAIN PIPELINE VIEW ─── */}
      {viewMode === 'kanban' ? (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
          gap: '14px',
          alignItems: 'start'
        }}>
          {STAGES.map(stage => {
            const stageBookings = filteredBookings.filter(b => (b.status || 'PENDING').toUpperCase() === stage.key);
            return (
              <div
                key={stage.key}
                style={{
                  backgroundColor: '#FFFFFF',
                  border: '1px solid #E2E8F0',
                  borderRadius: '8px',
                  padding: '14px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px',
                  minHeight: '350px'
                }}
              >
                {/* Column Header */}
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  paddingBottom: '10px',
                  borderBottom: `2px solid ${stage.border}`
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: stage.dot }}></span>
                    <span style={{ fontWeight: '800', fontSize: '12.5px', color: '#0F172A' }}>{stage.key}</span>
                  </div>
                  <span style={{
                    fontSize: '11px',
                    fontWeight: '800',
                    backgroundColor: stage.bg,
                    color: stage.text,
                    padding: '2px 8px',
                    borderRadius: '4px',
                    border: `1px solid ${stage.border}`
                  }}>
                    {stageBookings.length}
                  </span>
                </div>

                {/* Column Cards */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '600px', overflowY: 'auto' }}>
                  {stageBookings.length === 0 ? (
                    <div style={{
                      padding: '30px 10px',
                      textAlign: 'center',
                      color: '#94A3B8',
                      fontSize: '12px',
                      border: '1px dashed #E2E8F0',
                      borderRadius: '6px'
                    }}>
                      No jobs in this stage
                    </div>
                  ) : (
                    stageBookings.map(b => {
                      const code = b.bookingCode || b.id;
                      const customer = b.customer?.fullName || b.customerName || 'Customer';
                      const tech = b.technician?.user?.fullName || b.technician?.name;
                      const service = b.service?.name || b.serviceType || 'Service Request';
                      const payout = b.technicianPayoutAmount || b.payoutAmount || b.basePrice || 450;
                      const address = b.address?.formattedAddress || b.customerAddress || 'Customer Premise';

                      return (
                        <div
                          key={b.id || b._id}
                          style={{
                            backgroundColor: '#FFFFFF',
                            border: '1px solid #E2E8F0',
                            borderRadius: '6px',
                            padding: '12px',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '8px',
                            transition: 'border-color 0.15s ease'
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ fontFamily: 'monospace', fontWeight: '800', fontSize: '12px', color: '#0F172A' }}>
                              {code}
                            </span>
                            <span style={{ fontSize: '12px', fontWeight: '800', color: '#15803D' }}>
                              ₹{payout}
                            </span>
                          </div>

                          <div>
                            <div style={{ fontSize: '13px', fontWeight: '800', color: '#0F172A' }}>
                              {service}
                            </div>
                            <div style={{ fontSize: '12px', color: '#64748B' }}>
                              {customer}
                            </div>
                          </div>

                          <div style={{
                            backgroundColor: '#F8FAFC',
                            padding: '6px 8px',
                            borderRadius: '4px',
                            fontSize: '11px',
                            color: '#64748B',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '3px'
                          }}>
                            <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              📍 {address}
                            </div>
                            {tech ? (
                              <div style={{ fontWeight: '700', color: '#0F172A' }}>
                                👨‍🔧 {tech}
                              </div>
                            ) : (
                              <div style={{ fontWeight: '700', color: '#D97706' }}>
                                ⏳ Searching 15km radar...
                              </div>
                            )}
                          </div>

                          {/* Quick Actions */}
                          <div style={{ display: 'flex', gap: '6px', marginTop: '2px' }}>
                            {stage.key === 'PENDING' && (
                              <button
                                onClick={() => setForceAssignTarget(b)}
                                className="btn btn-sm"
                                style={{
                                  width: '100%',
                                  backgroundColor: '#0F172A',
                                  color: '#FFFFFF',
                                  fontSize: '11px',
                                  padding: '5px 8px'
                                }}
                              >
                                ⚡ Force Assign
                              </button>
                            )}

                            {['ARRIVED', 'IN_PROGRESS'].includes(stage.key) && (
                              <button
                                onClick={() => setOtpDisputeTarget(b)}
                                className="btn btn-sm"
                                style={{
                                  width: '100%',
                                  backgroundColor: '#FEF2F2',
                                  color: '#DC2626',
                                  border: '1px solid #FCA5A5',
                                  fontSize: '11px',
                                  padding: '5px 8px'
                                }}
                              >
                                🔓 Bypass OTP
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* ─── TABLE VIEW ─── */
        <div className="panel" style={{ margin: 0, padding: 0, overflow: 'hidden' }}>
          <table className="data-table" style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ backgroundColor: '#F8FAFC', borderBottom: '1px solid #E2E8F0' }}>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Booking Code</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Customer</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Service</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Technician</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Status</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Payout</th>
                <th style={{ padding: '12px 16px', textAlign: 'right', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ padding: '32px', textAlign: 'center', color: '#94A3B8' }}>
                    No active bookings found matching criteria.
                  </td>
                </tr>
              ) : (
                filteredBookings.map(b => {
                  const code = b.bookingCode || b.id;
                  const customer = b.customer?.fullName || b.customerName || 'Customer';
                  const tech = b.technician?.user?.fullName || b.technician?.name;
                  const service = b.service?.name || b.serviceType || 'Service Request';
                  const payout = b.technicianPayoutAmount || b.payoutAmount || b.basePrice || 450;
                  const status = (b.status || 'PENDING').toUpperCase();

                  return (
                    <tr key={b.id || b._id} style={{ borderBottom: '1px solid #E2E8F0' }}>
                      <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '800', color: '#0F172A' }}>
                        {code}
                      </td>
                      <td style={{ padding: '12px 16px' }}>
                        <div style={{ fontWeight: '700', color: '#0F172A' }}>{customer}</div>
                        <div style={{ fontSize: '11px', color: '#64748B' }}>{b.customer?.phone || b.customerPhone || 'N/A'}</div>
                      </td>
                      <td style={{ padding: '12px 16px', color: '#334155' }}>{service}</td>
                      <td style={{ padding: '12px 16px' }}>
                        {tech ? (
                          <span style={{ fontWeight: '700', color: '#0F172A' }}>{tech}</span>
                        ) : (
                          <span style={{ color: '#D97706', fontSize: '12px', fontWeight: '700' }}>Awaiting Partner</span>
                        )}
                      </td>
                      <td style={{ padding: '12px 16px' }}>
                        <span className={`badge badge-${status.toLowerCase()}`} style={{ fontWeight: '800' }}>
                          {status}
                        </span>
                      </td>
                      <td style={{ padding: '12px 16px', fontWeight: '800', color: '#15803D' }}>
                        ₹{payout}
                      </td>
                      <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                        {status === 'PENDING' && (
                          <button
                            onClick={() => setForceAssignTarget(b)}
                            className="btn btn-sm"
                            style={{ backgroundColor: '#0F172A', color: '#FFFFFF' }}
                          >
                            Force Assign
                          </button>
                        )}
                        {['ARRIVED', 'IN_PROGRESS'].includes(status) && (
                          <button
                            onClick={() => setOtpDisputeTarget(b)}
                            className="btn btn-sm btn-danger"
                          >
                            Bypass OTP
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Force Assign Modal */}
      {forceAssignTarget && (
        <ForceAssignModal
          booking={forceAssignTarget}
          onClose={() => setForceAssignTarget(null)}
          onSuccess={(msg) => {
            showToast(msg);
            fetchLiveBookings();
          }}
        />
      )}

      {/* Emergency OTP Dispute Modal */}
      {otpDisputeTarget && (
        <OtpDisputeModal
          booking={otpDisputeTarget}
          onClose={() => setOtpDisputeTarget(null)}
          onSuccess={(msg) => {
            showToast(msg);
            fetchLiveBookings();
          }}
        />
      )}
    </div>
  );
}
