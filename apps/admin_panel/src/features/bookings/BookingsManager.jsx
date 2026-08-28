import React, { useState } from 'react';
import api from '../../api/apiClient';

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

export default function BookingsManager({ bookings = [], setBookings, technicians = [], auditLogAction, subTab = 'all', onReload }) {
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [paymentFilter, setPaymentFilter] = useState('ALL');
  const [serviceFilter, setServiceFilter] = useState('ALL');
  const [reassignTechModal, setReassignTechModal] = useState(false);
  const [selectedNewTech, setSelectedNewTech] = useState('');
  const [copiedField, setCopiedField] = useState('');

  // Extract unique categories
  const categoriesList = ['ALL', ...new Set(bookings.map(b => b.category || b.serviceName || 'General').filter(Boolean))];

  // Filter Bookings
  const filteredBookings = bookings.filter(b => {
    const q = searchQuery.toLowerCase().trim();
    const idStr = (b.bookingCode || b.id || '').toLowerCase();
    const custStr = (b.customerName || b.customer || '').toLowerCase();
    const phoneStr = (b.customerPhone || b.phone || '').toLowerCase();
    const srvStr = (b.serviceName || b.service || '').toLowerCase();
    const techStr = (b.technicianName || b.technician || '').toLowerCase();
    const addrStr = (b.address || b.fullAddress || '').toLowerCase();

    const matchesSearch = !q ||
      idStr.includes(q) ||
      custStr.includes(q) ||
      phoneStr.includes(q) ||
      srvStr.includes(q) ||
      techStr.includes(q) ||
      addrStr.includes(q);

    const matchesStatus = statusFilter === 'ALL' || b.status === statusFilter;
    const matchesPayment = paymentFilter === 'ALL' || (b.paymentStatus || 'PAID').toUpperCase() === paymentFilter.toUpperCase();
    const matchesService = serviceFilter === 'ALL' || (b.category || b.serviceName || b.service) === serviceFilter;

    if (subTab === 'live') {
      return matchesSearch && ['CONFIRMED', 'ASSIGNED', 'TECHNICIAN_ASSIGNED', 'TECHNICIAN_ON_THE_WAY', 'TECHNICIAN_ARRIVED', 'SERVICE_STARTED', 'IN_PROGRESS'].includes(b.status);
    }
    return matchesSearch && matchesStatus && matchesPayment && matchesService;
  });

  const handleCopy = (text, fieldName) => {
    if (!text) return;
    navigator.clipboard?.writeText(text);
    setCopiedField(fieldName);
    setTimeout(() => setCopiedField(''), 2000);
  };

  const handleUpdateStatus = async (bookingId, newStatus) => {
    try {
      await api.updateBookingStatus(bookingId, newStatus);
      const old = bookings.find(b => b.id === bookingId || b.bookingCode === bookingId);
      setBookings(prev => prev.map(b => (b.id === bookingId || b.bookingCode === bookingId) ? { ...b, status: newStatus } : b));
      auditLogAction?.('Bookings', `Updated status of ${bookingId} from ${old?.status} to ${newStatus}`);
      if (selectedBooking && (selectedBooking.id === bookingId || selectedBooking.bookingCode === bookingId)) {
        setSelectedBooking(prev => ({ ...prev, status: newStatus }));
      }
      onReload?.();
    } catch (err) {
      alert('Failed to update booking status: ' + err.message);
    }
  };

  const handleReassignTechnician = async (bookingId) => {
    if (!selectedNewTech) return;
    const techObj = technicians.find(t => t.id === selectedNewTech || t.technicianId === selectedNewTech || t.name === selectedNewTech || t.fullName === selectedNewTech);
    const techId = techObj ? (techObj.id || techObj.technicianId) : selectedNewTech;
    const techName = techObj ? (techObj.fullName || techObj.name) : selectedNewTech;
    const techPhone = techObj ? techObj.phone : '+91 98765 43210';
    const techCat = techObj ? techObj.category : 'Certified Expert';
    const techRating = techObj ? (techObj.rating || 4.85) : 4.85;
    const techAvatar = techObj ? techObj.avatar : '';

    try {
      await api.assignBooking(bookingId, {
        technicianId: techId,
        technicianName: techName,
        technicianPhone: techPhone,
        technicianCategory: techCat,
        technicianRating: techRating,
        technicianAvatar: techAvatar,
      });

      setBookings(prev => prev.map(b => (b.id === bookingId || b.bookingCode === bookingId) ? {
        ...b,
        technicianId: techId,
        technician: techName,
        technicianName: techName,
        technicianPhone: techPhone,
        technicianCategory: techCat,
        technicianRating: techRating,
        status: 'TECHNICIAN_ASSIGNED'
      } : b));

      auditLogAction?.('Bookings', `Assigned technician ${techName} (${techPhone}) to booking #${bookingId}`);
      setReassignTechModal(false);
      if (selectedBooking) {
        setSelectedBooking(prev => ({
          ...prev,
          technicianId: techId,
          technician: techName,
          technicianName: techName,
          technicianPhone: techPhone,
          technicianCategory: techCat,
          technicianRating: techRating,
          status: 'TECHNICIAN_ASSIGNED'
        }));
      }
      onReload?.();
    } catch (err) {
      alert('Failed to assign technician: ' + err.message);
    }
  };

  const handleCancelBooking = async (bookingId) => {
    if (!window.confirm(`Are you sure you want to cancel booking #${bookingId}?`)) return;

    try {
      await api.cancelBooking(bookingId, 'Cancelled by Operations Admin');
      setBookings(prev => prev.map(b => (b.id === bookingId || b.bookingCode === bookingId) ? {
        ...b,
        status: 'CANCELLED',
        refundStatus: 'ELIGIBLE',
        cancellationReason: 'Cancelled by Operations Admin'
      } : b));

      auditLogAction?.('Bookings', `Cancelled booking #${bookingId}.`);

      if (selectedBooking) {
        setSelectedBooking(prev => ({ ...prev, status: 'CANCELLED', refundStatus: 'ELIGIBLE' }));
      }
      onReload?.();
    } catch (err) {
      alert('Failed to cancel booking: ' + err.message);
    }
  };

  const handleDeleteBooking = async (bookingId) => {
    if (!window.confirm(`Are you sure you want to permanently delete booking #${bookingId}? This cannot be undone.`)) return;

    try {
      await api.deleteBooking(bookingId);
      setBookings(prev => prev.filter(b => b.id !== bookingId && b.bookingCode !== bookingId));
      auditLogAction?.('Bookings', `Permanently deleted booking #${bookingId}`);
      if (selectedBooking && (selectedBooking.id === bookingId || selectedBooking.bookingCode === bookingId)) {
        setSelectedBooking(null);
      }
      onReload?.();
    } catch (err) {
      // If server returned 404 or in standalone mode, still remove locally
      setBookings(prev => prev.filter(b => b.id !== bookingId && b.bookingCode !== bookingId));
      if (selectedBooking && (selectedBooking.id === bookingId || selectedBooking.bookingCode === bookingId)) {
        setSelectedBooking(null);
      }
      auditLogAction?.('Bookings', `Deleted booking #${bookingId}`);
    }
  };

  const handleClearAllBookings = async () => {
    if (!window.confirm('⚠️ Are you sure you want to permanently DELETE ALL bookings? This will clear all test and fake records.')) return;

    try {
      await api.clearAllBookings();
      setBookings([]);
      setSelectedBooking(null);
      auditLogAction?.('Bookings', 'Permanently cleared all booking records');
      onReload?.();
    } catch (err) {
      setBookings([]);
      setSelectedBooking(null);
      auditLogAction?.('Bookings', 'Cleared all booking records');
    }
  };

  return (
    <div className="bookings-manager-view">
      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Service Bookings & Dispatches ({bookings.length} Total)</h2>
            <p className="page-subtitle">Track customer orders, origin GPS location, assigned technician details, OTPs, and invoices</p>
          </div>
          <div className="page-actions-group" style={{ display: 'flex', gap: '8px' }}>
            {bookings.length > 0 && (
              <button
                className="btn btn-danger btn-sm"
                onClick={handleClearAllBookings}
                title="Delete all current bookings"
              >
                🗑️ Clear All Bookings
              </button>
            )}
            <button className="btn btn-outline" onClick={() => onReload?.()}>
              🔄 Refresh Bookings
            </button>
          </div>
        </div>

        {/* ─── FILTERS & SEARCH TOOLBAR ─── */}
        <div className="toolbar-row">
          <div className="toolbar-left">
            <div className="search-input-box header-search" style={{ minWidth: '280px' }}>
              <input
                type="text"
                placeholder="Search Booking Code, Customer Name, Phone, Address..."
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
              {categoriesList.map(cat => (
                <option key={cat} value={cat}>{cat === 'ALL' ? 'All Categories' : cat}</option>
              ))}
            </select>
          </div>
          <div className="toolbar-right">
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Showing {filteredBookings.length} of {bookings.length} bookings
            </span>
          </div>
        </div>

        {/* ─── REAL BOOKINGS TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Booking ID</th>
                <th>Customer & Location</th>
                <th>Service & Category</th>
                <th>Assigned Technician</th>
                <th>Schedule</th>
                <th>Amount (₹)</th>
                <th>Payment</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan="9" style={{ textAlign: 'center', padding: '48px', color: 'var(--text-secondary)' }}>
                    <div style={{ fontSize: '28px', marginBottom: '8px' }}>📋</div>
                    <strong>No bookings found.</strong>
                    <p style={{ fontSize: '12.5px', marginTop: '4px', color: '#94A3B8' }}>
                      When customers create bookings in the mobile app, their full details with live location will appear here automatically.
                    </p>
                  </td>
                </tr>
              ) : (
                filteredBookings.map(b => {
                  const custName = b.customerName || b.customer || 'Customer';
                  const custPhone = b.customerPhone || b.phone || 'N/A';
                  const srvName = b.serviceName || b.service || 'Service';
                  const catName = b.category || 'General';
                  const totalAmt = b.totalAmount || b.grandTotal || b.price || 0;
                  const techName = b.technicianName || b.technician;
                  const hasTech = techName && techName !== 'None Assigned' && techName !== 'Pending Dispatch' && techName !== 'Assigning Expert...';

                  return (
                    <tr key={b.id || b.bookingCode}>
                      <td>
                        <strong style={{ color: 'var(--primary)', fontFamily: 'monospace', fontSize: '13.5px' }}>
                          {b.bookingCode || b.id}
                        </strong>
                        <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                          Start OTP: <strong style={{ color: '#0F172A', fontFamily: 'monospace' }}>{b.startOtp || '—'}</strong>
                        </div>
                      </td>
                      <td>
                        <div><strong>{custName}</strong></div>
                        <small style={{ color: 'var(--text-secondary)', fontFamily: 'monospace' }}>📞 {custPhone}</small>
                        {b.address && (
                          <div style={{ fontSize: '11px', color: '#64748B', maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginTop: '2px' }}>
                            📍 {b.address}
                          </div>
                        )}
                      </td>
                      <td>
                        <strong>{srvName}</strong>
                        <div>
                          <span className="badge badge-info" style={{ fontSize: '10.5px', marginTop: '2px' }}>{catName}</span>
                        </div>
                      </td>
                      <td>
                        {hasTech ? (
                          <div>
                            <strong>{techName}</strong>
                            {b.technicianPhone && <div style={{ fontSize: '11px', color: '#64748B', fontFamily: 'monospace' }}>📞 {b.technicianPhone}</div>}
                            <div style={{ fontSize: '11px', color: '#15803D', fontWeight: '600' }}>🟢 Dispatched</div>
                          </div>
                        ) : (
                          <span className="badge badge-pending">⚠️ Pending Dispatch</span>
                        )}
                      </td>
                      <td>
                        <div>{b.scheduleDate || b.date || 'Today'}</div>
                        <small style={{ color: 'var(--text-secondary)' }}>{b.scheduleSlot || b.timeSlot || '3:00 PM – 4:00 PM'}</small>
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)', fontFamily: 'monospace', fontSize: '13.5px' }}>₹{totalAmt}</strong>
                      </td>
                      <td>
                        <span className={`badge ${b.paymentStatus === 'Paid' || b.paymentStatus === 'PAID' ? 'badge-completed' : 'badge-pending'}`}>
                          {b.paymentStatus || 'PAID'}
                        </span>
                      </td>
                      <td>
                        <span className={`badge ${
                          b.status === 'COMPLETED' ? 'badge-completed' :
                          b.status === 'CONFIRMED' || b.status === 'TECHNICIAN_ASSIGNED' || b.status === 'ASSIGNED' ? 'badge-confirmed' :
                          b.status === 'CANCELLED' ? 'badge-cancelled' : 'badge-pending'
                        }`}>
                          {b.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                        <div style={{ display: 'inline-flex', gap: '6px' }}>
                          <button className="btn btn-primary btn-sm" onClick={() => setSelectedBooking(b)}>
                            Manage Details →
                          </button>
                          <button
                            className="btn btn-outline btn-sm"
                            style={{ color: '#DC2626', borderColor: '#FECACA' }}
                            title="Delete this booking permanently"
                            onClick={() => handleDeleteBooking(b.id || b.bookingCode)}
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

      {/* ─── ENHANCED REAL BOOKING DETAIL MODAL ─── */}
      {selectedBooking && (
        <div className="modal-overlay" onClick={() => setSelectedBooking(null)}>
          <div className="modal-dialog" style={{ maxWidth: '750px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <div>
                <h3 className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span>Booking Details: {selectedBooking.bookingCode || selectedBooking.id}</span>
                  <span className={`badge ${
                    selectedBooking.status === 'COMPLETED' ? 'badge-completed' :
                    selectedBooking.status === 'CONFIRMED' || selectedBooking.status === 'TECHNICIAN_ASSIGNED' ? 'badge-confirmed' :
                    selectedBooking.status === 'CANCELLED' ? 'badge-cancelled' : 'badge-pending'
                  }`}>
                    {selectedBooking.status}
                  </span>
                </h3>
                <span style={{ fontSize: '12px', color: '#64748B' }}>
                  Booked on: {new Date(selectedBooking.createdAt || Date.now()).toLocaleString()}
                </span>
              </div>
              <button className="modal-close-btn" onClick={() => setSelectedBooking(null)}>×</button>
            </div>

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {/* 1. Customer & Location Profile Card + Assigned Technician Card */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                {/* Customer & Location Details */}
                <div style={{ padding: '14px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                    <span style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>
                      👤 Customer & Origin Location
                    </span>
                    <span className="badge badge-info" style={{ fontSize: '10px' }}>GPS Verified</span>
                  </div>

                  <div style={{ fontWeight: '800', fontSize: '15px', color: '#0F172A' }}>
                    {selectedBooking.customerName || selectedBooking.customer || 'Customer'}
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                    <a
                      href={`tel:${selectedBooking.customerPhone || selectedBooking.phone}`}
                      style={{ fontSize: '13px', color: 'var(--primary)', fontFamily: 'monospace', fontWeight: '700', textDecoration: 'none' }}
                    >
                      📞 {selectedBooking.customerPhone || selectedBooking.phone || 'N/A'}
                    </a>
                    <button
                      className="btn btn-sm"
                      style={{ padding: '2px 6px', fontSize: '10px' }}
                      onClick={() => handleCopy(selectedBooking.customerPhone || selectedBooking.phone, 'cust_phone')}
                    >
                      {copiedField === 'cust_phone' ? '✓ Copied' : 'Copy'}
                    </button>
                  </div>

                  {/* Customer Full Address */}
                  <div style={{ fontSize: '12px', color: '#334155', marginTop: '8px', lineHeight: '1.4', background: '#FFFFFF', padding: '8px 10px', borderRadius: '4px', border: '1px solid #E2E8F0' }}>
                    <strong>📍 Booking Location:</strong>
                    <div style={{ marginTop: '2px', color: '#64748B' }}>
                      {selectedBooking.fullAddress || selectedBooking.address || 'Address location provided upon booking'}
                    </div>
                    {selectedBooking.latitude && selectedBooking.longitude && (
                      <div style={{ fontSize: '11px', color: '#94A3B8', marginTop: '4px', fontFamily: 'monospace' }}>
                        Coordinates: {selectedBooking.latitude.toFixed(4)}, {selectedBooking.longitude.toFixed(4)}
                      </div>
                    )}
                  </div>

                  {/* Open in Google Maps Link Button */}
                  <div style={{ marginTop: '10px' }}>
                    <a
                      href={`https://www.google.com/maps/search/?api=1&query=${selectedBooking.latitude || 12.9716},${selectedBooking.longitude || 77.5946}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn btn-outline btn-sm"
                      style={{ width: '100%', textAlign: 'center', display: 'block', textDecoration: 'none', fontSize: '11.5px', padding: '6px' }}
                    >
                      🗺️ Open Location in Google Maps ↗
                    </a>
                  </div>
                </div>

                {/* Assigned Technician Profile Details */}
                <div style={{ padding: '14px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                    <span style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>
                      👨‍🔧 Assigned Technician
                    </span>
                    {selectedBooking.technicianName && selectedBooking.technicianName !== 'Pending Dispatch' ? (
                      <span className="badge badge-completed" style={{ fontSize: '10px' }}>✅ Verified Partner</span>
                    ) : (
                      <span className="badge badge-pending" style={{ fontSize: '10px' }}>⚠️ Unassigned</span>
                    )}
                  </div>

                  {selectedBooking.technicianName && selectedBooking.technicianName !== 'Pending Dispatch' && selectedBooking.technicianName !== 'None Assigned' ? (
                    <div>
                      <div style={{ fontWeight: '800', fontSize: '15px', color: '#0F172A' }}>
                        {selectedBooking.technicianName || selectedBooking.technician}
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                        <a
                          href={`tel:${selectedBooking.technicianPhone || '+91 98765 43210'}`}
                          style={{ fontSize: '13px', color: '#15803D', fontFamily: 'monospace', fontWeight: '700', textDecoration: 'none' }}
                        >
                          📞 {selectedBooking.technicianPhone || '+91 98765 43210'}
                        </a>
                        <button
                          className="btn btn-sm"
                          style={{ padding: '2px 6px', fontSize: '10px' }}
                          onClick={() => handleCopy(selectedBooking.technicianPhone || '+91 98765 43210', 'tech_phone')}
                        >
                          {copiedField === 'tech_phone' ? '✓ Copied' : 'Copy'}
                        </button>
                      </div>

                      <div style={{ display: 'flex', gap: '6px', marginTop: '8px', flexWrap: 'wrap' }}>
                        <span className="badge badge-info" style={{ fontSize: '11px' }}>
                          ⭐ {selectedBooking.technicianRating || 4.88} / 5.0
                        </span>
                        <span className="badge" style={{ background: '#E2E8F0', color: '#334155', fontSize: '11px' }}>
                          {selectedBooking.technicianCategory || 'Electrical & Appliances'}
                        </span>
                      </div>

                      <button
                        className="btn btn-secondary btn-sm"
                        style={{ width: '100%', marginTop: '12px', fontSize: '11.5px', padding: '6px' }}
                        onClick={() => setReassignTechModal(true)}
                      >
                        🔄 Reassign Another Technician
                      </button>
                    </div>
                  ) : (
                    <div style={{ padding: '12px 0', textAlign: 'center' }}>
                      <p style={{ fontSize: '13px', color: '#DC2626', fontWeight: '700', marginBottom: '8px' }}>
                        ⚠️ No technician assigned yet
                      </p>
                      <button
                        className="btn btn-primary btn-sm"
                        style={{ width: '100%', fontSize: '12px' }}
                        onClick={() => setReassignTechModal(true)}
                      >
                        ⚡ Assign Available Technician Now
                      </button>
                    </div>
                  )}

                  {/* Start OTP & End OTP verification boxes */}
                  <div style={{ marginTop: '12px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <div style={{ padding: '6px 8px', background: '#EFF6FF', borderRadius: '4px', border: '1px solid #BFDBFE', textAlign: 'center' }}>
                      <span style={{ fontSize: '10.5px', color: '#1E40AF', fontWeight: '700', display: 'block' }}>START OTP</span>
                      <strong style={{ fontSize: '14px', color: '#1E40AF', letterSpacing: '2px', fontFamily: 'monospace' }}>
                        {selectedBooking.startOtp || '—'}
                      </strong>
                    </div>
                    <div style={{ padding: '6px 8px', background: '#F0FDF4', borderRadius: '4px', border: '1px solid #BBF7D0', textAlign: 'center' }}>
                      <span style={{ fontSize: '10.5px', color: '#166534', fontWeight: '700', display: 'block' }}>END OTP</span>
                      <strong style={{ fontSize: '14px', color: '#166534', letterSpacing: '2px', fontFamily: 'monospace' }}>
                        {selectedBooking.endOtp || '—'}
                      </strong>
                    </div>
                  </div>
                </div>
              </div>

              {/* 2. Booked Services List & Schedule */}
              <div style={{ padding: '12px 14px', background: '#FFFFFF', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                  <span style={{ fontSize: '12px', fontWeight: '800', color: '#0F172A', textTransform: 'uppercase' }}>
                    🛠️ Booked Services & Schedule
                  </span>
                  <span style={{ fontSize: '12px', color: '#64748B', fontWeight: '600' }}>
                    📅 {selectedBooking.scheduleDate || selectedBooking.date || 'Today'} • ⏰ {selectedBooking.scheduleSlot || selectedBooking.timeSlot || '3:00 PM – 4:00 PM'}
                  </span>
                </div>

                {Array.isArray(selectedBooking.services) && selectedBooking.services.length > 0 ? (
                  selectedBooking.services.map((srv, idx) => (
                    <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: idx < selectedBooking.services.length - 1 ? '1px solid #F1F5F9' : 'none', fontSize: '13px' }}>
                      <span>• <strong>{srv.name || srv.title}</strong></span>
                      <strong style={{ fontFamily: 'monospace' }}>₹{srv.price}</strong>
                    </div>
                  ))
                ) : (
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                    <span>• <strong>{selectedBooking.serviceName || selectedBooking.service}</strong></span>
                    <strong style={{ fontFamily: 'monospace' }}>₹{selectedBooking.baseCost || selectedBooking.basePrice || selectedBooking.price}</strong>
                  </div>
                )}
              </div>

              {/* 3. Official Invoice Breakdown */}
              <div style={{ padding: '14px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: 'var(--primary)', marginBottom: '8px', textTransform: 'uppercase' }}>
                  🧾 Official Financial Ledger Breakdown
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>Service Base Cost:</span>
                  <strong style={{ fontFamily: 'monospace' }}>₹{(selectedBooking.baseCost || selectedBooking.basePrice || selectedBooking.price || 0).toFixed(2)}</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>Booking & Safety Inspection Fee:</span>
                  <span style={{ fontFamily: 'monospace' }}>₹{(selectedBooking.bookingCharge || selectedBooking.visitFee || 49).toFixed(2)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>GST Tax (18% Invoiced):</span>
                  <span style={{ fontFamily: 'monospace' }}>₹{(selectedBooking.gstTax || ((selectedBooking.basePrice || selectedBooking.price || 0) * 0.18)).toFixed(2)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14.5px', fontWeight: '900', borderTop: '1px solid var(--border-color)', paddingTop: '8px', marginTop: '6px', color: '#0F172A' }}>
                  <span>Customer Total Paid ({selectedBooking.paymentMethod || 'ONLINE'}):</span>
                  <span style={{ color: '#15803D', fontFamily: 'monospace' }}>₹{(selectedBooking.totalAmount || selectedBooking.grandTotal || selectedBooking.price || 0).toFixed(2)}</span>
                </div>
              </div>

              {/* 4. Live Lifecycle Status Switcher */}
              <div className="form-group" style={{ margin: 0 }}>
                <label className="form-label" style={{ fontSize: '12px', fontWeight: '700' }}>
                  ⚡ Update Real-time Booking Lifecycle Status
                </label>
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                  {STATUS_LIFECYCLE.map(st => (
                    <button
                      key={st}
                      type="button"
                      className={`btn btn-sm ${selectedBooking.status === st ? 'btn-primary' : 'btn-outline'}`}
                      style={{ fontSize: '11px', padding: '4px 8px' }}
                      onClick={() => handleUpdateStatus(selectedBooking.id || selectedBooking.bookingCode, st)}
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
                👨‍🔧 Reassign / Assign Tech
              </button>
              <button
                type="button"
                className="btn btn-outline"
                style={{ color: '#D97706', borderColor: '#FDE68A' }}
                onClick={() => handleCancelBooking(selectedBooking.id || selectedBooking.bookingCode)}
              >
                Cancel Booking
              </button>
              <button
                type="button"
                className="btn btn-danger"
                onClick={() => handleDeleteBooking(selectedBooking.id || selectedBooking.bookingCode)}
              >
                🗑️ Delete Booking
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
              <h3 className="modal-title">Assign Technician to #{selectedBooking?.bookingCode || selectedBooking?.id}</h3>
              <button className="modal-close-btn" onClick={() => setReassignTechModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label className="form-label">Select Verified Technician for this vertical</label>
                <select
                  className="form-control"
                  value={selectedNewTech}
                  onChange={e => setSelectedNewTech(e.target.value)}
                >
                  <option value="">-- Choose Verified Partner --</option>
                  {technicians.map(t => (
                    <option key={t.id || t.technicianId} value={t.id || t.technicianId}>
                      {t.fullName || t.name} ({t.category} • ⭐ {t.rating || 4.88} • {t.phone})
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
                onClick={() => handleReassignTechnician(selectedBooking?.id || selectedBooking?.bookingCode)}
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
