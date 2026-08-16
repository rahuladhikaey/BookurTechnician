import React, { useState } from 'react';
import api from '../../api/apiClient';

export default function DispatchManager({ bookings = [], setBookings, technicians = [], auditLogAction }) {
  const [selectedBookingId, setSelectedBookingId] = useState(null);
  const [autoMatchEnabled, setAutoMatchEnabled] = useState(true);

  const unassignedBookings = (bookings || []).filter(b => 
    !b.technician || b.technician === 'None Assigned' || ['PENDING', 'REQUESTED', 'SEARCHING_TECHNICIAN'].includes(b.status)
  );
  
  const activeTechnicians = (technicians || []).filter(t => 
    (t.kycStatus === 'VERIFIED' || t.kycStatus === 'Approved') && (t.isOnline || t.online)
  );

  const handleManualAssign = async (tech) => {
    if (!selectedBookingId) {
      alert("Please select an unassigned booking first from the left panel.");
      return;
    }
    
    try {
      await api.assignBooking(selectedBookingId, tech.id);
      
      if (setBookings) {
        setBookings(prev => prev.map(b => {
          if (b.id === selectedBookingId) {
            return {
              ...b,
              technician: tech.name,
              status: 'ASSIGNED'
            };
          }
          return b;
        }));
      }

      auditLogAction?.('Manual Dispatch', `Manually assigned technician ${tech.name} (${tech.code || tech.id}) to Booking ${selectedBookingId}`);
      alert(`Technician ${tech.name} successfully assigned to booking ${selectedBookingId}!`);
      setSelectedBookingId(null);
    } catch (err) {
      console.error('Error assigning technician:', err);
      alert('Failed to assign technician: ' + err.message);
    }
  };

  const handleForceUnassign = async (bookingId) => {
    try {
      await api.updateBookingStatus(bookingId, 'SEARCHING_TECHNICIAN');
      if (setBookings) {
        setBookings(prev => prev.map(b => {
          if (b.id === bookingId) {
            return {
              ...b,
              technician: 'None Assigned',
              status: 'SEARCHING_TECHNICIAN'
            };
          }
          return b;
        }));
      }
      auditLogAction?.('Manual Dispatch', `Force unassigned booking ${bookingId}`);
    } catch (err) {
      console.error('Error unassigning booking:', err);
      alert('Failed to unassign: ' + err.message);
    }
  };

  return (
    <div className="dispatch-manager">
      <div className="flex-between m-b-20" style={{ background: 'rgba(255,255,255,0.02)', padding: '12px 20px', borderRadius: '12px', border: '1px solid var(--border-glass)' }}>
        <div>
          <h3 style={{ fontSize: '16px' }}>Dispatch Central Routing Control</h3>
          <p style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
            Override auto-assignment protocols, monitor 10 KM radial dispatch, and assign emergency jobs manually.
          </p>
        </div>
        <div className="flex-gap">
          <span style={{ fontSize: '12px', fontWeight: 'bold' }}>Auto-Assignment Matching Engine:</span>
          <button className={`action-btn ${autoMatchEnabled ? '' : 'action-btn-danger'}`} onClick={() => {
            setAutoMatchEnabled(!autoMatchEnabled);
            auditLogAction?.('Dispatch Config', `Set Auto-Assignment Matching Engine to ${!autoMatchEnabled}`);
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
                  <span style={{ fontWeight: '700', fontSize: '13px' }}>{b.bookingCode || b.id}</span>
                  <span className="badge badge-warning" style={{ fontSize: '9px' }}>{b.status}</span>
                </div>
                <div style={{ fontSize: '12px', marginTop: '6px' }}><strong>Service:</strong> {b.service?.name || b.service || 'Service Request'}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}><strong>Customer:</strong> {b.customer?.fullName || b.customer || 'Customer'}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>
                  <strong>Address:</strong> {b.address || 'Service Location'}
                </div>
              </div>
            ))}

            {unassignedBookings.length === 0 && (
              <div style={{ textAlign: 'center', color: 'var(--text-muted)', paddingTop: '40px', fontSize: '12.5px' }}>
                All bookings currently have technicians assigned or database has zero pending jobs.
              </div>
            )}
          </div>
        </div>

        {/* Right Side: Available Technicians nearby */}
        <div className="dispatch-panel">
          <h4 style={{ fontSize: '14px', borderBottom: '1px solid var(--border-glass)', paddingBottom: '8px' }}>
            Available Online Technicians ({activeTechnicians.length})
          </h4>
          <div className="dispatch-list">
            {activeTechnicians.map(t => (
              <div key={t.id} className="dispatch-item" style={{ cursor: 'default' }}>
                <div className="flex-between">
                  <span style={{ fontWeight: '700', fontSize: '13px' }}>{t.name}</span>
                  <span className="badge badge-success" style={{ fontSize: '9px' }}>Online GPS</span>
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  Code: <strong>{t.code || t.technicianCode || t.id}</strong> | Skill: {t.category || 'General'}
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                  Rating: ★ {t.rating || 5.0} | Phone: {t.phone}
                </div>
                <div style={{ marginTop: '8px', textAlign: 'right' }}>
                  <button
                    className="btn btn-primary btn-sm"
                    disabled={!selectedBookingId}
                    onClick={() => handleManualAssign(t)}
                  >
                    Assign Selected Booking →
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
