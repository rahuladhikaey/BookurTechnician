import React, { useState } from 'react';

export default function DispatchManager({ bookings, setBookings, technicians, auditLogAction }) {
  const [selectedBookingId, setSelectedBookingId] = useState(null);
  const [autoMatchEnabled, setAutoMatchEnabled] = useState(true);

  const unassignedBookings = bookings.filter(b => b.technician === 'None Assigned' || !b.technician || b.status === 'PENDING' || b.status === 'SEARCHING_TECHNICIAN');
  const activeTechnicians = technicians.filter(t => t.status === 'Approved' && t.onlineStatus === 'Online');

  const handleManualAssign = (techName) => {
    if (!selectedBookingId) {
      alert("Please select an unassigned booking first from the left panel.");
      return;
    }
    
    setBookings(prev => prev.map(b => {
      if (b.id === selectedBookingId) {
        return {
          ...b,
          technician: techName,
          status: 'TECHNICIAN_ASSIGNED'
        };
      }
      return b;
    }));

    auditLogAction('Manual Dispatch', `Manually assigned technician ${techName} to Booking ${selectedBookingId}`);
    alert(`Technician ${techName} successfully assigned to booking ${selectedBookingId}!`);
    setSelectedBookingId(null);
  };

  const handleForceUnassign = (bookingId) => {
    setBookings(prev => prev.map(b => {
      if (b.id === bookingId) {
        return {
          ...b,
          technician: 'None Assigned',
          status: 'PENDING'
        };
      }
      return b;
    }));
    auditLogAction('Manual Dispatch', `Force unassigned booking ${bookingId}`);
  };

  return (
    <div className="dispatch-manager">
      <div className="flex-between m-b-20" style={{ background: 'rgba(255,255,255,0.02)', padding: '12px 20px', borderRadius: '12px', border: '1px solid var(--border-glass)' }}>
        <div>
          <h3 style={{ fontSize: '16px' }}>Dispatch Central Routing Control</h3>
          <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>Override auto-assignment protocols or dispatch emergency jobs manually.</p>
        </div>
        <div className="flex-gap">
          <span style={{ fontSize: '12px', fontWeight: 'bold' }}>Auto-Assignment Matching Engine:</span>
          <button className={`action-btn ${autoMatchEnabled ? '' : 'action-btn-danger'}`} onClick={() => {
            setAutoMatchEnabled(!autoMatchEnabled);
            auditLogAction('Dispatch Config', `Set Auto-Assignment Matching Engine to ${!autoMatchEnabled}`);
          }}>
            {autoMatchEnabled ? 'ACTIVE (AUTO)' : 'DISABLED (MANUAL OVERRIDE)'}
          </button>
        </div>
      </div>

      <div className="dispatch-grid">
        {/* Left Side: Unassigned Bookings */}
        <div className="dispatch-panel">
          <h4 style={{ fontSize: '14px', borderBottom: '1px solid var(--border-glass)', paddingBottom: '8px' }}>
            Unassigned Bookings ({unassignedBookings.length})
          </h4>
          <div className="dispatch-list">
            {unassignedBookings.map(b => (
              <div
                key={b.id}
                className={`dispatch-item ${selectedBookingId === b.id ? 'selected' : ''}`}
                onClick={() => setSelectedBookingId(b.id)}
              >
                <div className="flex-between">
                  <span style={{ fontWeight: '700', fontSize: '13px' }}>{b.id}</span>
                  <span className="badge badge-warning" style={{ fontSize: '9px' }}>{b.status}</span>
                </div>
                <div style={{ fontSize: '12px', marginTop: '6px' }}><strong>Service:</strong> {b.service}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}><strong>Customer:</strong> {b.customer}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>Address: Flat 402, Royal Palms Residency, Kolkata</div>
              </div>
            ))}

            {unassignedBookings.length === 0 && (
              <div style={{ textAlign: 'center', color: 'var(--text-muted)', paddingTop: '40px', fontSize: '12.5px' }}>
                All bookings currently have technicians assigned.
              </div>
            )}
          </div>
        </div>

        {/* Right Side: Available Technicians nearby */}
        <div className="dispatch-panel">
          <h4 style={{ fontSize: '14px', borderBottom: '1px solid var(--border-glass)', paddingBottom: '8px' }}>
            Available Online Technicians ({activeTechnicians.length})
          </h4>
          
          {selectedBookingId ? (
            <p style={{ fontSize: '11.5px', color: 'var(--secondary)', margin: '10px 0', fontWeight: 'bold' }}>
              👉 Select a partner below to manually dispatch them to Booking {selectedBookingId}
            </p>
          ) : (
            <p style={{ fontSize: '11.5px', color: 'var(--text-muted)', margin: '10px 0' }}>
              Select an unassigned booking on the left to enable assignment buttons.
            </p>
          )}

          <div className="dispatch-list">
            {activeTechnicians.map(t => {
              // Mock details
              const distance = (Math.random() * 5 + 0.5).toFixed(1);
              const eta = Math.round(distance * 4);
              const workload = Math.round(Math.random() * 2);
              return (
                <div key={t.id} className="dispatch-item" style={{ cursor: 'default' }}>
                  <div className="flex-between">
                    <div className="flex-gap">
                      <img src={t.photo} alt="" style={{ width: '28px', height: '28px', borderRadius: '50%', objectFit: 'cover' }} />
                      <span style={{ fontWeight: '700', fontSize: '13px' }}>{t.name}</span>
                    </div>
                    <span className="badge badge-success" style={{ fontSize: '9px' }}>Online</span>
                  </div>
                  
                  <div className="grid-2" style={{ fontSize: '11.5px', marginTop: '8px', color: 'var(--text-secondary)' }}>
                    <div>Skill: <strong>{t.category}</strong></div>
                    <div>Area: {t.location}</div>
                    <div>Distance: {distance} km (ETA: {eta} mins)</div>
                    <div>Workload Today: {workload} active jobs</div>
                  </div>

                  <div style={{ marginTop: '12px', textAlign: 'right' }}>
                    <button
                      className="action-btn"
                      disabled={!selectedBookingId}
                      style={{ padding: '4px 12px', fontSize: '11px', opacity: selectedBookingId ? 1 : 0.4 }}
                      onClick={() => handleManualAssign(t.name)}
                    >
                      Assign Partner
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      <div className="chart-card m-t-20">
        <h4>All Currently Assigned Bookings (Active Reassignment Console)</h4>
        <p style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginBottom: '16px' }}>Force unassign or shift partners for active bookings below.</p>
        
        <div className="table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Booking ID</th>
                <th>Client</th>
                <th>Assigned Technician</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {bookings.filter(b => b.technician !== 'None Assigned' && b.technician && !['COMPLETED', 'CANCELLED', 'REFUNDED'].includes(b.status)).map(b => (
                <tr key={b.id}>
                  <td><code>{b.id}</code></td>
                  <td>{b.customer}</td>
                  <td style={{ fontWeight: '700', color: 'var(--secondary)' }}>{b.technician}</td>
                  <td>
                    <span className="badge badge-info">{b.status}</span>
                  </td>
                  <td>
                    <button className="action-btn action-btn-danger" style={{ padding: '4px 10px', fontSize: '11px' }} onClick={() => handleForceUnassign(b.id)}>
                      Force Unassign
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
