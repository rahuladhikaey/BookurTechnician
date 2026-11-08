import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function DispatchManager({ bookings = [], setBookings, technicians = [], auditLogAction }) {
  const [selectedBookingId, setSelectedBookingId] = useState(null);
  const [liveDispatchData, setLiveDispatchData] = useState(null);
  const [selectedHistory, setSelectedHistory] = useState(null);
  const [config, setConfig] = useState({
    radiiKm: [3, 5, 10, 15],
    offerTimeoutSeconds: 20,
    maxRetriesPerRadius: 1,
    maxTotalAttempts: 12,
    autoDispatchEnabled: true,
    rankingWeights: {
      etaDistance: 0.35,
      skillMatch: 0.25,
      availability: 0.20,
      rating: 0.10,
      reliability: 0.10,
    },
  });
  const [radiiInput, setRadiiInput] = useState('3, 5, 10, 15');
  const [savingConfig, setSavingConfig] = useState(false);

  const loadLiveDispatch = useCallback(async () => {
    try {
      const res = await api.getLiveDispatch();
      if (res) {
        setLiveDispatchData(res);
        if (res.config) {
          setConfig(res.config);
          if (Array.isArray(res.config.radiiKm)) {
            setRadiiInput(res.config.radiiKm.join(', '));
          }
        }
      }
    } catch (_) {}
  }, []);

  useEffect(() => {
    loadLiveDispatch();
    const timer = setInterval(loadLiveDispatch, 6000);
    return () => clearInterval(timer);
  }, [loadLiveDispatch]);

  useEffect(() => {
    if (!selectedBookingId) {
      setSelectedHistory(null);
      return;
    }
    api.getDispatchHistory(selectedBookingId)
      .then(res => setSelectedHistory(res?.data || res))
      .catch(() => setSelectedHistory(null));
  }, [selectedBookingId]);

  const unassignedOrSearchingBookings = (bookings || []).filter(b =>
    !b.technician ||
    b.technician === 'None Assigned' ||
    b.technician === 'Pending Dispatch' ||
    ['PENDING', 'REQUESTED', 'CONFIRMED', 'SEARCHING_TECHNICIAN', 'NO_TECHNICIAN_AVAILABLE'].includes(b.status)
  );

  const assignedBookings = (bookings || []).filter(b =>
    b.technicianId && ['ASSIGNED', 'TECHNICIAN_ASSIGNED', 'ACCEPTED', 'ARRIVED', 'IN_PROGRESS'].includes(b.status)
  );

  const activeTechnicians = (technicians || []).filter(t =>
    (t.kycStatus === 'VERIFIED' || t.kycStatus === 'Approved') && (t.isOnline || t.online)
  );

  const handleSaveConfig = async () => {
    setSavingConfig(true);
    try {
      const parsedRadii = radiiInput
        .split(',')
        .map(s => parseFloat(s.trim()))
        .filter(n => !Number.isNaN(n) && n > 0);

      const payload = {
        ...config,
        radiiKm: parsedRadii.length > 0 ? parsedRadii : [3, 5, 10, 15],
      };
      const res = await api.updateDispatchConfig(payload);
      if (res?.config) {
        setConfig(res.config);
      }
      auditLogAction?.('Dispatch Config', `Updated dispatch engine settings (radii: ${payload.radiiKm.join('/')} km, timeout: ${payload.offerTimeoutSeconds}s)`);
    } catch (err) {
      alert('Failed to update dispatch config: ' + err.message);
    } finally {
      setSavingConfig(false);
    }
  };

  const handleManualAssign = async (tech) => {
    if (!selectedBookingId) {
      alert('Please select a booking first from the left panel.');
      return;
    }

    try {
      await api.manualAssignDispatch(selectedBookingId, tech.id || tech.technicianId, 'ADMIN_MANUAL_ASSIGNMENT');
      await api.assignBooking(selectedBookingId, { technicianId: tech.id || tech.technicianId, technicianName: tech.name });

      if (setBookings) {
        setBookings(prev => prev.map(b => {
          if (b.id === selectedBookingId) {
            return {
              ...b,
              technicianId: tech.id || tech.technicianId,
              technician: tech.name,
              technicianName: tech.name,
              status: 'ASSIGNED',
            };
          }
          return b;
        }));
      }

      auditLogAction?.('Manual Dispatch', `Manually assigned technician ${tech.name} (${tech.code || tech.id}) to Booking ${selectedBookingId}`);
      loadLiveDispatch();
    } catch (err) {
      alert('Failed to assign technician: ' + err.message);
    }
  };

  const handleRetryDispatch = async (bookingId) => {
    try {
      await api.retryBookingDispatch(bookingId);
      auditLogAction?.('Dispatch Retry', `Triggered sequential dispatch retry for booking ${bookingId}`);
      loadLiveDispatch();
    } catch (err) {
      alert('Retry dispatch failed: ' + err.message);
    }
  };

  return (
    <div className="dispatch-manager">
      {/* Top Dispatch Engine Configuration & Auto-Dispatch Bar */}
      <div className="panel m-b-20" style={{ padding: '16px 20px' }}>
        <div className="flex-between" style={{ flexWrap: 'wrap', gap: '12px', marginBottom: '14px' }}>
          <div>
            <h3 style={{ fontSize: '16px', margin: 0 }}>Automatic Sequential Dispatch Engine Control</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
              PostGIS Radial Search (3 km → 5 km → 10 km → 15 km), Multi-Factor AI Ranking & Sequential Offer Cascade
            </p>
          </div>
          <div className="flex-gap">
            <span style={{ fontSize: '12px', fontWeight: '700' }}>Auto-Dispatch Engine:</span>
            <button
              className={`btn btn-sm ${config.autoDispatchEnabled ? 'btn-primary' : 'btn-outline'}`}
              onClick={async () => {
                const nextState = !config.autoDispatchEnabled;
                setConfig(prev => ({ ...prev, autoDispatchEnabled: nextState }));
                try {
                  await api.updateDispatchConfig({ autoDispatchEnabled: nextState });
                  auditLogAction?.('Dispatch Config', `Set Auto-Dispatch to ${nextState}`);
                } catch (_) {}
              }}
            >
              {config.autoDispatchEnabled ? 'ACTIVE (SEQUENTIAL AUTO)' : 'PAUSED (MANUAL OVERRIDE)'}
            </button>
          </div>
        </div>

        {/* Configurable Radii, Offer Timeout & Max Attempts */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', alignItems: 'end' }}>
          <div>
            <label style={{ fontSize: '11px', fontWeight: '700', display: 'block', marginBottom: '4px' }}>
              Search Radii Tiers (km)
            </label>
            <input
              type="text"
              className="form-control"
              value={radiiInput}
              onChange={e => setRadiiInput(e.target.value)}
              placeholder="3, 5, 10, 15"
            />
          </div>
          <div>
            <label style={{ fontSize: '11px', fontWeight: '700', display: 'block', marginBottom: '4px' }}>
              Offer Timeout (15–20 sec)
            </label>
            <input
              type="number"
              className="form-control"
              min={5}
              max={60}
              value={config.offerTimeoutSeconds}
              onChange={e => setConfig(prev => ({ ...prev, offerTimeoutSeconds: Number(e.target.value) }))}
            />
          </div>
          <div>
            <label style={{ fontSize: '11px', fontWeight: '700', display: 'block', marginBottom: '4px' }}>
              Max Dispatch Attempts
            </label>
            <input
              type="number"
              className="form-control"
              min={1}
              max={30}
              value={config.maxTotalAttempts}
              onChange={e => setConfig(prev => ({ ...prev, maxTotalAttempts: Number(e.target.value) }))}
            />
          </div>
          <div>
            <button className="btn btn-primary btn-sm" onClick={handleSaveConfig} disabled={savingConfig}>
              {savingConfig ? 'Saving...' : 'Save Dispatch Config'}
            </button>
          </div>
        </div>
      </div>

      <div className="dispatch-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
        {/* Left Side: Unassigned / Searching / Assigned Bookings */}
        <div className="dispatch-panel panel" style={{ margin: 0 }}>
          <h4 style={{ fontSize: '14px', borderBottom: '1px solid var(--border-glass)', paddingBottom: '8px' }}>
            Searching & Unassigned Bookings ({unassignedOrSearchingBookings.length}) | Assigned ({assignedBookings.length})
          </h4>
          <div className="dispatch-list" style={{ maxHeight: '420px', overflowY: 'auto' }}>
            {[...unassignedOrSearchingBookings, ...assignedBookings].map(b => (
              <div
                key={b.id}
                className={`dispatch-item ${selectedBookingId === b.id ? 'selected' : ''}`}
                onClick={() => setSelectedBookingId(b.id)}
                style={{
                  padding: '12px',
                  marginBottom: '8px',
                  borderRadius: '8px',
                  border: selectedBookingId === b.id ? '2px solid #F46B12' : '1px solid #EEE8E2',
                  cursor: 'pointer',
                }}
              >
                <div className="flex-between">
                  <span style={{ fontWeight: '700', fontSize: '13px' }}>{b.bookingCode || b.id}</span>
                  <span className="badge badge-warning" style={{ fontSize: '10px' }}>{b.status}</span>
                </div>
                <div style={{ fontSize: '12px', marginTop: '6px' }}>
                  <strong>Service:</strong> {b.service?.name || b.serviceName || b.service || 'Service Request'}
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  <strong>Customer:</strong> {b.customer?.fullName || b.customerName || b.customer || 'Customer'} | <strong>Tech:</strong> {b.technicianName || b.technician || 'Searching...'}
                </div>
                <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
                  <button
                    className="btn btn-outline btn-sm"
                    style={{ fontSize: '11px', padding: '3px 8px' }}
                    onClick={(e) => {
                      e.stopPropagation();
                      handleRetryDispatch(b.id);
                    }}
                  >
                    🔄 Retry Auto-Dispatch
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Selected Booking Offer & Audit History */}
          {selectedHistory && (
            <div style={{ marginTop: '16px', paddingTop: '12px', borderTop: '1px solid #EEE8E2' }}>
              <h5 style={{ fontSize: '13px', margin: '0 0 8px' }}>
                Offer & Rejection History for {selectedBookingId} ({selectedHistory.offers?.length || 0} offers)
              </h5>
              {(selectedHistory.offers || []).map(off => (
                <div key={off.id} style={{ fontSize: '11px', padding: '6px 8px', background: '#FCF9F6', borderRadius: '6px', marginBottom: '4px' }}>
                  <strong>#{off.attemptNumber}</strong> Tech: <code>{off.technicianId}</code> • Radius: {off.radiusKm}km • Dist: {off.distanceKm}km • Score: {off.rankingScore} • Status: <strong>{off.status}</strong> {off.rejectionReason ? `(${off.rejectionReason})` : ''}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right Side: Available Verified Technicians for Manual Assign / Reassign */}
        <div className="dispatch-panel panel" style={{ margin: 0 }}>
          <h4 style={{ fontSize: '14px', borderBottom: '1px solid var(--border-glass)', paddingBottom: '8px' }}>
            Verified Online Technicians ({activeTechnicians.length})
          </h4>
          <div className="dispatch-list" style={{ maxHeight: '420px', overflowY: 'auto' }}>
            {activeTechnicians.map(t => (
              <div key={t.id} className="dispatch-item" style={{ padding: '12px', marginBottom: '8px', borderRadius: '8px', border: '1px solid #EEE8E2' }}>
                <div className="flex-between">
                  <span style={{ fontWeight: '700', fontSize: '13px' }}>{t.name || t.fullName}</span>
                  <span className="badge badge-success" style={{ fontSize: '10px' }}>Online GPS</span>
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  Code: <strong>{t.code || t.technicianCode || t.id}</strong> | Skill: {t.category || 'General'}
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                  Rating: ★ {t.rating || 4.9} | Phone: {t.phone}
                </div>
                <div style={{ marginTop: '8px', textAlign: 'right' }}>
                  <button
                    className="btn btn-primary btn-sm"
                    disabled={!selectedBookingId}
                    onClick={() => handleManualAssign(t)}
                  >
                    Assign / Reassign Selected Booking →
                  </button>
                </div>
              </div>
            ))}

            {activeTechnicians.length === 0 && (
              <div style={{ textAlign: 'center', color: 'var(--text-muted)', paddingTop: '40px', fontSize: '12.5px' }}>
                No technicians are currently online and verified.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
