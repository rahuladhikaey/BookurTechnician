import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';
import ForceAssignModal from './ForceAssignModal';
import OtpDisputeModal from '../support/OtpDisputeModal';
import LiveTransitRadarModal from './LiveTransitRadarModal';

const STAGES = [
  { key: 'PENDING', label: 'Unassigned (Pending)', bg: '#FFF4E0', border: '#FBE4D5', text: '#E5A126', dot: '#E5A126' },
  { key: 'ACCEPTED', label: 'Accepted / Dispatched', bg: '#FBE4D5', border: '#FBE4D5', text: '#F46B12', dot: '#F46B12' },
  { key: 'ARRIVED', label: 'Arrived at Doorstep', bg: '#FBE4D5', border: '#FBE4D5', text: '#F46B12', dot: '#F46B12' },
  { key: 'IN_PROGRESS', label: 'In Progress (Start OTP)', bg: '#FBE4D5', border: '#FBE4D5', text: '#F46B12', dot: '#F46B12' },
  { key: 'COMPLETED', label: 'Completed (Settled)', bg: '#E8F5E9', border: '#E8F5E9', text: '#198754', dot: '#198754' },
  { key: 'CANCELLED', label: 'Cancelled / Refunded', bg: '#FDECEC', border: '#FDECEC', text: '#DC3545', dot: '#DC3545' },
];

export default function LiveBookingRadar({ onReload, isSyncing = false }) {
  const [bookings, setBookings] = useState([]);
  const [summary, setSummary] = useState({ PENDING: 0, ACCEPTED: 0, ARRIVED: 0, IN_PROGRESS: 0, COMPLETED: 0, CANCELLED: 0, TOTAL: 0 });
  const [loading, setLoading] = useState(true);
  const [localRefreshing, setLocalRefreshing] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState('kanban'); // 'kanban' | 'table'
  const [autoRefresh, setAutoRefresh] = useState(true);

  const isSpinning = isSyncing || localRefreshing || loading;

  // Modals state
  const [forceAssignTarget, setForceAssignTarget] = useState(null);
  const [otpDisputeTarget, setOtpDisputeTarget] = useState(null);
  const [liveTransitBooking, setLiveTransitBooking] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);

  const fetchLiveBookings = useCallback(async () => {
    setLocalRefreshing(true);
    try {
      if (onReload) {
        await onReload();
      }
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
      setTimeout(() => setLocalRefreshing(false), 300);
    }
  }, [selectedStatus, onReload]);

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
          backgroundColor: '#F46B12',
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
            backgroundColor: '#F46B12',
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
              <h2 style={{ fontSize: '18px', fontWeight: '800', color: '#222222', margin: 0 }}>
                Live Operations Radar & Dispatch Tower
              </h2>
              <span className="live-badge" style={{ fontSize: '10px', padding: '2px 8px', borderRadius: '4px' }}>
                LIVE STREAM
              </span>
            </div>
            <p style={{ fontSize: '12.5px', color: '#77716C', margin: '2px 0 0' }}>
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
              borderColor: autoRefresh ? '#198754' : '#EEE8E2',
              color: autoRefresh ? '#198754' : '#77716C',
              backgroundColor: autoRefresh ? '#E8F5E9' : '#FFFFFF',
              fontWeight: '700'
            }}
          >
            <span>{autoRefresh ? '🔄 Auto-Sync: Active (8s)' : '⏸ Auto-Sync: Paused'}</span>
          </button>

          <button 
            onClick={fetchLiveBookings} 
            disabled={isSpinning}
            className="btn btn-outline btn-sm" 
            title="Refresh Live Operations Radar"
          >
            <span className={isSpinning ? 'spin-icon' : ''}>🔄</span> {isSpinning ? 'Refreshing...' : 'Refresh Radar'}
          </button>

          <div style={{ display: 'flex', backgroundColor: '#FCF9F6', borderRadius: '6px', padding: '2px', border: '1px solid #EEE8E2' }}>
            <button
              onClick={() => setViewMode('kanban')}
              style={{
                padding: '5px 12px',
                borderRadius: '4px',
                border: 'none',
                backgroundColor: viewMode === 'kanban' ? '#F46B12' : 'transparent',
                color: viewMode === 'kanban' ? '#FFFFFF' : '#77716C',
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
                backgroundColor: viewMode === 'table' ? '#F46B12' : 'transparent',
                color: viewMode === 'table' ? '#FFFFFF' : '#77716C',
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
                border: `1.5px solid ${isSelected ? '#222222' : stage.border}`,
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
              <div style={{ fontSize: '22px', fontWeight: '900', color: '#222222' }}>{count}</div>
              <div style={{ fontSize: '11px', color: '#77716C', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
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

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', fontSize: '13px', color: '#77716C' }}>
          <span>
            Showing <strong style={{ color: '#222222' }}>{filteredBookings.length}</strong> active jobs
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
                  border: '1px solid #EEE8E2',
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
                    <span style={{ fontWeight: '800', fontSize: '12.5px', color: '#222222' }}>{stage.key}</span>
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
                      color: '#77716C',
                      fontSize: '12px',
                      border: '1px dashed #EEE8E2',
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
                            border: '1px solid #EEE8E2',
                            borderRadius: '6px',
                            padding: '12px',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '8px',
                            transition: 'border-color 0.15s ease'
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ fontFamily: 'monospace', fontWeight: '800', fontSize: '12px', color: '#222222' }}>
                              {code}
                            </span>
                            <span style={{ fontSize: '12px', fontWeight: '800', color: '#198754' }}>
                              ₹{payout}
                            </span>
                          </div>

                          <div>
                            <div style={{ fontSize: '13px', fontWeight: '800', color: '#222222' }}>
                              {service}
                            </div>
                            <div style={{ fontSize: '12px', color: '#77716C' }}>
                              {customer}
                            </div>
                          </div>

                          <div style={{
                            backgroundColor: '#FCF9F6',
                            padding: '6px 8px',
                            borderRadius: '4px',
                            fontSize: '11px',
                            color: '#77716C',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '3px'
                          }}>
                            <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              📍 {address}
                            </div>
                            {tech ? (
                              <div style={{ fontWeight: '700', color: '#222222' }}>
                                👨‍🔧 {tech}
                              </div>
                            ) : (
                              <div style={{ fontWeight: '700', color: '#E5A126' }}>
                                ⏳ Searching 15km radar...
                              </div>
                            )}
                          </div>

                          {/* Quick Actions */}
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '4px' }}>
                            <button
                              onClick={() => setLiveTransitBooking(b)}
                              className="btn btn-sm"
                              style={{
                                width: '100%',
                                backgroundColor: '#F46B12',
                                color: '#FFFFFF',
                                fontSize: '11px',
                                padding: '6px 8px',
                                fontWeight: '700',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                gap: '4px',
                              }}
                            >
                              <span>🛰️</span> Live GPS Radar (Zomato Map)
                            </button>

                            {stage.key === 'PENDING' && (
                              <div
                                style={{
                                  width: '100%',
                                  backgroundColor: '#FFF4E0',
                                  color: '#E5A126',
                                  border: '1px solid #FBE4D5',
                                  borderRadius: '4px',
                                  fontSize: '11px',
                                  padding: '5px 8px',
                                  textAlign: 'center',
                                  fontWeight: '700'
                                }}
                              >
                                📡 Auto-Dispatching Offers...
                              </div>
                            )}

                            {['ARRIVED', 'IN_PROGRESS'].includes(stage.key) && (
                              <button
                                onClick={() => setOtpDisputeTarget(b)}
                                className="btn btn-sm"
                                style={{
                                  width: '100%',
                                  backgroundColor: '#FDECEC',
                                  color: '#DC3545',
                                  border: '1px solid #FDECEC',
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
              <tr style={{ backgroundColor: '#FCF9F6', borderBottom: '1px solid #EEE8E2' }}>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Booking Code</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Customer</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Service</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Technician</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Status</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Payout</th>
                <th style={{ padding: '12px 16px', textAlign: 'right', fontSize: '12px', fontWeight: '800', color: '#222222' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ padding: '32px', textAlign: 'center', color: '#77716C' }}>
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
                    <tr key={b.id || b._id} style={{ borderBottom: '1px solid #EEE8E2' }}>
                      <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '800', color: '#222222' }}>
                        {code}
                      </td>
                      <td style={{ padding: '12px 16px' }}>
                        <div style={{ fontWeight: '700', color: '#222222' }}>{customer}</div>
                        <div style={{ fontSize: '11px', color: '#77716C' }}>{b.customer?.phone || b.customerPhone || 'N/A'}</div>
                      </td>
                      <td style={{ padding: '12px 16px', color: '#222222' }}>{service}</td>
                      <td style={{ padding: '12px 16px' }}>
                        {tech ? (
                          <span style={{ fontWeight: '700', color: '#222222' }}>{tech}</span>
                        ) : (
                          <span style={{ color: '#E5A126', fontSize: '12px', fontWeight: '700' }}>Awaiting Partner</span>
                        )}
                      </td>
                      <td style={{ padding: '12px 16px' }}>
                        <span className={`badge badge-${status.toLowerCase()}`} style={{ fontWeight: '800' }}>
                          {status}
                        </span>
                      </td>
                      <td style={{ padding: '12px 16px', fontWeight: '800', color: '#198754' }}>
                        ₹{payout}
                      </td>
                      <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                        {status === 'PENDING' && (
                          <span
                            style={{
                              backgroundColor: '#FFF4E0',
                              color: '#E5A126',
                              border: '1px solid #FBE4D5',
                              borderRadius: '4px',
                              fontSize: '11px',
                              padding: '4px 8px',
                              fontWeight: '700',
                              display: 'inline-block'
                            }}
                          >
                            📡 Auto-Dispatching
                          </span>
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

      {/* Real-time Live GPS Radar & Dispatch Tracking Modal (Zomato / Blinkit / Uber Mode) */}
      {liveTransitBooking && (
        <LiveTransitRadarModal
          booking={liveTransitBooking}
          onClose={() => setLiveTransitBooking(null)}
          onReassign={(b) => setForceAssignTarget(b)}
        />
      )}
    </div>
  );
}
