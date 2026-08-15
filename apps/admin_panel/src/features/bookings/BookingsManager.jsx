import React, { useState } from 'react';

const STATUS_LIFECYCLE = [
  'PENDING',
  'CONFIRMED',
  'TECHNICIAN_ASSIGNED',
  'TECHNICIAN_ON_THE_WAY',
  'TECHNICIAN_ARRIVED',
  'SERVICE_STARTED',
  'SERVICE_COMPLETED',
  'COMPLETED'
];

export default function BookingsManager({ bookings, setBookings, technicians, auditLogAction, subTab = 'all' }) {
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [paymentFilter, setPaymentFilter] = useState('ALL');
  const [serviceFilter, setServiceFilter] = useState('ALL');
  const [reassignTechModal, setReassignTechModal] = useState(false);
  const [selectedNewTech, setSelectedNewTech] = useState('');

  // Filter Bookings
  const filteredBookings = bookings.filter(b => {
    const q = searchQuery.toLowerCase();
    const matchesSearch = !q ||
      b.id.toLowerCase().includes(q) ||
      (b.customer && b.customer.toLowerCase().includes(q)) ||
      (b.technician && b.technician.toLowerCase().includes(q)) ||
      (b.service && b.service.toLowerCase().includes(q));

    const matchesStatus = statusFilter === 'ALL' || b.status === statusFilter;
    const matchesPayment = paymentFilter === 'ALL' || (b.paymentStatus || 'Paid').toUpperCase() === paymentFilter.toUpperCase();
    const matchesService = serviceFilter === 'ALL' || (b.category || b.service) === serviceFilter;

    if (subTab === 'live') {
      return matchesSearch && ['CONFIRMED', 'TECHNICIAN_ASSIGNED', 'TECHNICIAN_ON_THE_WAY', 'TECHNICIAN_ARRIVED', 'SERVICE_STARTED'].includes(b.status);
    }
    return matchesSearch && matchesStatus && matchesPayment && matchesService;
  });

  const calculatePricing = (serviceCost = 1899) => {
    const cost = Number(serviceCost) || 1899;
    const bookingCharge = 99.0;
    const gst = (cost + bookingCharge) * 0.18;
    const grandTotal = cost + bookingCharge + gst;
    return {
      serviceCost: cost,
      bookingCharge,
      gst,
      grandTotal
    };
  };

  const handleUpdateStatus = (bookingId, newStatus) => {
    const old = bookings.find(b => b.id === bookingId);
    setBookings(prev => prev.map(b => b.id === bookingId ? { ...b, status: newStatus } : b));
    auditLogAction?.('Bookings', `Updated status of ${bookingId} from ${old?.status} to ${newStatus}`);
    if (selectedBooking && selectedBooking.id === bookingId) {
      setSelectedBooking(prev => ({ ...prev, status: newStatus }));
    }
  };

  const handleReassignTechnician = (bookingId) => {
    if (!selectedNewTech) return;
    const techObj = technicians.find(t => t.id === selectedNewTech || t.name === selectedNewTech);
    const techName = techObj ? techObj.name : selectedNewTech;

    setBookings(prev => prev.map(b => b.id === bookingId ? {
      ...b,
      technician: techName,
      status: 'TECHNICIAN_ASSIGNED'
    } : b));

    auditLogAction?.('Bookings', `Reassigned booking ${bookingId} to technician ${techName}`);
    setReassignTechModal(false);
    if (selectedBooking) {
      setSelectedBooking(prev => ({ ...prev, technician: techName, status: 'TECHNICIAN_ASSIGNED' }));
    }
  };

  const handleCancelBooking = (bookingId) => {
    const pricing = calculatePricing(selectedBooking?.price || 1899);
    const refundableAmount = pricing.serviceCost;
    
    setBookings(prev => prev.map(b => b.id === bookingId ? {
      ...b,
      status: 'CANCELLED',
      refundStatus: 'ELIGIBLE',
      refundableAmount,
      cancellationReason: 'Cancelled by Operations Admin'
    } : b));

    auditLogAction?.(
      'Bookings',
      `Cancelled booking ${bookingId}. Auto-computed eligible refund of ₹${refundableAmount.toFixed(2)}`
    );

    if (selectedBooking) {
      setSelectedBooking(prev => ({ ...prev, status: 'CANCELLED', refundStatus: 'ELIGIBLE' }));
    }
  };

  return (
    <div className="bookings-manager-view">
      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Service Bookings & Dispatches</h2>
            <p className="page-subtitle">Track end-to-end booking lifecycles, assignments, OTPs, and invoices</p>
          </div>
          <div className="page-actions-group">
            <button className="btn btn-outline" onClick={() => alert('Exporting bookings CSV report...')}>
              📥 Export CSV
            </button>
          </div>
        </div>

        {/* ─── FILTERS & SEARCH TOOLBAR ─── */}
        <div className="toolbar-row">
          <div className="toolbar-left">
            <div className="search-input-box header-search" style={{ minWidth: '280px' }}>
              <input
                type="text"
                placeholder="Search Booking ID, Customer, Tech..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
            </div>

            <select className="filter-select" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
              <option value="ALL">All Statuses</option>
              {STATUS_LIFECYCLE.map(s => (
                <option key={s} value={s}>{s}</option>
              ))}
              <option value="CANCELLED">CANCELLED</option>
            </select>

            <select className="filter-select" value={paymentFilter} onChange={e => setPaymentFilter(e.target.value)}>
              <option value="ALL">All Payments</option>
              <option value="PAID">Paid</option>
              <option value="PENDING">Pending</option>
            </select>

            <select className="filter-select" value={serviceFilter} onChange={e => setServiceFilter(e.target.value)}>
              <option value="ALL">All Services</option>
              <option value="AC Service">AC Service</option>
              <option value="Laptop Service">Laptop Service</option>
              <option value="Fan Service">Fan Service</option>
              <option value="Refrigerator Service">Refrigerator Service</option>
              <option value="Washing Machine Service">Washing Machine Service</option>
            </select>
          </div>
          <div className="toolbar-right">
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Showing {filteredBookings.length} bookings
            </span>
          </div>
        </div>

        {/* ─── FLAT BOOKINGS TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Booking ID</th>
                <th>Customer</th>
                <th>Service</th>
                <th>Technician</th>
                <th>Schedule</th>
                <th>Amount</th>
                <th>Payment</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan="9" style={{ textAlign: 'center', padding: '32px', color: 'var(--text-secondary)' }}>
                    No bookings found matching the current search & filters.
                  </td>
                </tr>
              ) : (
                filteredBookings.map(b => (
                  <tr key={b.id}>
                    <td>
                      <strong style={{ color: 'var(--primary)' }}>{b.id}</strong>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>OTP: {b.startOtp || '4821'}</div>
                    </td>
                    <td>
                      <div><strong>{b.customer || 'Rahul Customer'}</strong></div>
                      <small style={{ color: 'var(--text-secondary)' }}>{b.phone || '+91 99382-01938'}</small>
                    </td>
                    <td>
                      <span className="badge badge-info">{b.service || 'Keyboard Replacement'}</span>
                    </td>
                    <td>
                      {b.technician && b.technician !== 'None Assigned' ? (
                        <div>
                          <strong>{b.technician}</strong>
                          <div style={{ fontSize: '11px', color: '#15803D' }}>🟢 Dispatched</div>
                        </div>
                      ) : (
                        <span className="badge badge-pending">⚠️ Unassigned</span>
                      )}
                    </td>
                    <td>
                      <div>{b.date || '15 Aug 2026'}</div>
                      <small style={{ color: 'var(--text-secondary)' }}>{b.timeSlot || '3:00 PM – 4:00 PM'}</small>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)' }}>₹{b.price || 1899}</strong>
                    </td>
                    <td>
                      <span className={`badge ${b.paymentStatus === 'Paid' || b.paymentStatus === 'PAID' ? 'badge-completed' : 'badge-pending'}`}>
                        {b.paymentStatus || 'Paid'}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${
                        b.status === 'COMPLETED' ? 'badge-completed' :
                        b.status === 'CONFIRMED' || b.status === 'TECHNICIAN_ASSIGNED' ? 'badge-confirmed' :
                        b.status === 'CANCELLED' ? 'badge-cancelled' : 'badge-pending'
                      }`}>
                        {b.status}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button className="btn btn-primary btn-sm" onClick={() => setSelectedBooking(b)}>
                        Manage →
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── BOOKING DETAIL MODAL (FLAT 2D) ─── */}
      {selectedBooking && (
        <div className="modal-overlay" onClick={() => setSelectedBooking(null)}>
          <div className="modal-dialog" style={{ maxWidth: '650px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Booking Details: {selectedBooking.id}</h3>
              <button className="modal-close-btn" onClick={() => setSelectedBooking(null)}>×</button>
            </div>
            <div className="modal-body">
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
                <div style={{ padding: '12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px' }}>
                  <div style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Customer</div>
                  <div style={{ fontWeight: '700', fontSize: '14px', marginTop: '4px' }}>{selectedBooking.customer}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{selectedBooking.phone}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>Bengaluru, Karnataka</div>
                </div>

                <div style={{ padding: '12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px' }}>
                  <div style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Assigned Technician</div>
                  <div style={{ fontWeight: '700', fontSize: '14px', marginTop: '4px' }}>{selectedBooking.technician || 'None Assigned'}</div>
                  <div style={{ fontSize: '12px', color: 'var(--primary)', marginTop: '4px' }}>Start OTP: <strong style={{ letterSpacing: '1px' }}>{selectedBooking.startOtp}</strong></div>
                </div>
              </div>

              {/* Price Breakdown */}
              <div style={{ padding: '14px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '4px', marginBottom: '16px' }}>
                <div style={{ fontSize: '12.5px', fontWeight: '700', color: 'var(--primary)', marginBottom: '8px' }}>INVOICE BREAKDOWN</div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>Service Cost ({selectedBooking.service})</span>
                  <strong>₹{selectedBooking.price}</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>Booking Convenience Fee (Non-refundable)</span>
                  <span>₹99.00</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>GST Tax (18% Non-refundable)</span>
                  <span>₹{((selectedBooking.price + 99) * 0.18).toFixed(2)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px', fontWeight: '800', borderTop: '1px solid var(--border-color)', paddingTop: '6px', marginTop: '6px' }}>
                  <span>Total Paid by Customer</span>
                  <span style={{ color: 'var(--primary)' }}>₹{(selectedBooking.price + 99 + (selectedBooking.price + 99) * 0.18).toFixed(2)}</span>
                </div>
              </div>

              {/* Lifecycle status selector */}
              <div className="form-group">
                <label className="form-label">Update Booking Status</label>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {STATUS_LIFECYCLE.map(st => (
                    <button
                      key={st}
                      type="button"
                      className={`btn btn-sm ${selectedBooking.status === st ? 'btn-primary' : 'btn-outline'}`}
                      onClick={() => handleUpdateStatus(selectedBooking.id, st)}
                    >
                      {st}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="modal-footer">
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setReassignTechModal(true)}
              >
                Reassign Technician
              </button>
              <button
                type="button"
                className="btn btn-danger"
                onClick={() => handleCancelBooking(selectedBooking.id)}
              >
                Cancel Booking
              </button>
              <button type="button" className="btn btn-outline" onClick={() => setSelectedBooking(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* ─── REASSIGN TECH MODAL ─── */}
      {reassignTechModal && (
        <div className="modal-overlay" onClick={() => setReassignTechModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Reassign Technician</h3>
              <button className="modal-close-btn" onClick={() => setReassignTechModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label className="form-label">Select Active Technician</label>
                <select
                  className="form-control"
                  value={selectedNewTech}
                  onChange={e => setSelectedNewTech(e.target.value)}
                >
                  <option value="">-- Choose Verified Technician --</option>
                  {technicians.map(t => (
                    <option key={t.id} value={t.id}>
                      {t.name} ({t.category} • ⭐ {t.rating} • {t.onlineStatus})
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-outline" onClick={() => setReassignTechModal(false)}>Cancel</button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => handleReassignTechnician(selectedBooking.id)}
              >
                Confirm Dispatch
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
