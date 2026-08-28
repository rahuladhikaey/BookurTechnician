import React, { useState } from 'react';

export default function Dashboard({ stats, bookings = [], technicians = [], customers = [], onNavigate }) {
  const [timeRange, setTimeRange] = useState('today');

  // Real-time dynamic KPI Calculations from live bookings & database
  const totalBookingsCount = stats?.totalBookings !== undefined ? stats.totalBookings : bookings.length;
  
  const totalRevenue = stats?.totalRevenue !== undefined
    ? stats.totalRevenue
    : bookings.filter(b => b.status !== 'CANCELLED').reduce((sum, b) => sum + (parseFloat(b.totalAmount || b.grandTotal || b.price) || 0), 0);

  const todayStr = new Date().toISOString().split('T')[0];
  const todayRevenue = stats?.todayRevenue !== undefined
    ? stats.todayRevenue
    : bookings.filter(b => b.status !== 'CANCELLED' && (b.createdAt || '').startsWith(todayStr)).reduce((sum, b) => sum + (parseFloat(b.totalAmount || b.grandTotal || b.price) || 0), 0);

  const totalCustomers = stats?.totalCustomers !== undefined ? stats.totalCustomers : (customers.length || new Set(bookings.map(b => b.customerId || b.customerPhone)).size);
  const verifiedTechnicians = stats?.verifiedTechnicians ?? technicians.filter(t => t.kycStatus === 'VERIFIED').length;
  const onlineTechnicians = stats?.onlineTechnicians ?? technicians.filter(t => t.isOnline).length;

  const activeBookingsCount = stats?.activeBookings !== undefined
    ? stats.activeBookings
    : bookings.filter(b => ['CONFIRMED', 'ASSIGNED', 'TECHNICIAN_ASSIGNED', 'TECHNICIAN_ON_THE_WAY', 'TECHNICIAN_ARRIVED', 'SERVICE_STARTED', 'IN_PROGRESS', 'SEARCHING'].includes(b.status)).length;

  const completedBookingsCount = stats?.completedBookings !== undefined
    ? stats.completedBookings
    : bookings.filter(b => b.status === 'COMPLETED').length;

  const cancelledBookingsCount = stats?.cancelledBookings !== undefined
    ? stats.cancelledBookings
    : bookings.filter(b => b.status === 'CANCELLED').length;

  const totalCalculated = completedBookingsCount + activeBookingsCount + cancelledBookingsCount;
  const completedPct = totalCalculated > 0 ? Math.round((completedBookingsCount / totalCalculated) * 100) : 0;
  const activePct = totalCalculated > 0 ? Math.round((activeBookingsCount / totalCalculated) * 100) : 0;
  const cancelledPct = totalCalculated > 0 ? Math.round((cancelledBookingsCount / totalCalculated) * 100) : 0;

  return (
    <div className="dashboard-view">
      {/* ─── PAGE HEADER ROW ─── */}
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Executive Operations Dashboard</h1>
          <p className="page-subtitle">Real-time overview of live bookings, customer orders, revenue, and active dispatches</p>
        </div>
        <div className="page-actions-group">
          <div className="toolbar-left">
            {['today', '7days', '30days'].map(range => (
              <button
                key={range}
                className={`btn btn-sm ${timeRange === range ? 'btn-primary' : 'btn-outline'}`}
                onClick={() => setTimeRange(range)}
              >
                {range === 'today' ? "Today" : range === '7days' ? 'Last 7 Days' : 'This Month'}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ─── TOP REAL STATISTICS CARDS ─── */}
      <div className="stats-grid">
        <div className="stat-card" onClick={() => onNavigate('bookings', 'all')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Total Live Bookings</span>
            <div className="stat-icon">📋</div>
          </div>
          <div className="stat-value">{totalBookingsCount.toLocaleString()}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">{activeBookingsCount} active</span> in-flight dispatches
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('payments', 'transactions')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Realized Revenue</span>
            <div className="stat-icon">₹</div>
          </div>
          <div className="stat-value">₹{Math.round(totalRevenue).toLocaleString()}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">₹{Math.round(todayRevenue).toLocaleString()}</span> today
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('customers', '')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Registered Customers</span>
            <div className="stat-icon">👥</div>
          </div>
          <div className="stat-value">{totalCustomers.toLocaleString()}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">{totalCustomers} registered</span> accounts
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('technicians', 'all')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Verified Technicians</span>
            <div className="stat-icon">👨‍🔧</div>
          </div>
          <div className="stat-value">{verifiedTechnicians}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">{onlineTechnicians} Online</span> ready for jobs
          </div>
        </div>
      </div>

      {/* ─── 2D CHARTS SECTION ─── */}
      <div className="charts-grid">
        {/* Booking Velocity Bar Chart */}
        <div className="flat-chart-box">
          <div className="flat-chart-header">
            <h3 className="flat-chart-title">Booking Status Ratio</h3>
            <span className="badge badge-info">Real-time Data</span>
          </div>

          <div className="bar-2d-row">
            <div className="bar-2d-label">
              <span>Total Orders Received</span>
              <strong>{totalBookingsCount} bookings</strong>
            </div>
            <div className="bar-2d-track">
              <div className="bar-2d-fill" style={{ width: totalBookingsCount > 0 ? '100%' : '0%' }}></div>
            </div>
          </div>

          <div className="bar-2d-row">
            <div className="bar-2d-label">
              <span>Successfully Completed</span>
              <strong style={{ color: '#15803D' }}>{completedBookingsCount} jobs ({completedPct}%)</strong>
            </div>
            <div className="bar-2d-track">
              <div className="bar-2d-fill success" style={{ width: `${completedPct}%` }}></div>
            </div>
          </div>

          <div className="bar-2d-row">
            <div className="bar-2d-label">
              <span>Ongoing In-Field / Active</span>
              <strong style={{ color: '#D97706' }}>{activeBookingsCount} jobs ({activePct}%)</strong>
            </div>
            <div className="bar-2d-track">
              <div className="bar-2d-fill warning" style={{ width: `${activePct}%` }}></div>
            </div>
          </div>

          <div className="bar-2d-row">
            <div className="bar-2d-label">
              <span>Cancelled</span>
              <strong style={{ color: '#DC2626' }}>{cancelledBookingsCount} jobs ({cancelledPct}%)</strong>
            </div>
            <div className="bar-2d-track">
              <div className="bar-2d-fill error" style={{ width: `${cancelledPct}%` }}></div>
            </div>
          </div>
        </div>

        {/* Real Revenue Breakdown */}
        <div className="flat-chart-box">
          <div className="flat-chart-header">
            <h3 className="flat-chart-title">Revenue Breakdown</h3>
            <span className="badge badge-info">Financial Metrics</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '6px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--primary-light)', borderRadius: '4px' }}>
              <span style={{ fontWeight: '600', color: 'var(--text-main)' }}>🔧 Service Base Revenue</span>
              <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>₹{(totalRevenue * 0.82).toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px' }}>
              <span style={{ color: 'var(--text-main)' }}>📍 Inspection / Booking Fee Volume</span>
              <strong style={{ fontFamily: 'monospace' }}>₹{(totalBookingsCount * 49).toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px' }}>
              <span style={{ color: 'var(--text-main)' }}>🏛️ GST Invoices (18% Applicable)</span>
              <strong style={{ fontFamily: 'monospace' }}>₹{(totalRevenue * 0.18).toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 12px', background: 'var(--bg-white)', border: '1.5px solid var(--primary)', borderRadius: '4px' }}>
              <span style={{ fontWeight: '800', color: 'var(--text-main)' }}>💎 Net Customer Paid Total</span>
              <strong style={{ color: '#15803D', fontSize: '15px', fontFamily: 'monospace' }}>₹{totalRevenue.toFixed(2)}</strong>
            </div>
          </div>
        </div>
      </div>

      {/* ─── RECENT LIVE BOOKINGS TABLE ─── */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Recent Live Booking Dispatches</h3>
          <button className="btn btn-secondary btn-sm" onClick={() => onNavigate('bookings', 'all')}>
            View All Bookings ({bookings.length}) →
          </button>
        </div>

        <div className="table-responsive">
          {bookings.length === 0 ? (
            <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>📋</div>
              <p style={{ fontSize: '14px', fontWeight: '700', color: '#0F172A', marginBottom: '4px' }}>No bookings created yet.</p>
              <span style={{ fontSize: '12.5px', color: '#64748B' }}>
                When any user books a service in the mobile app, their full details (Name, Phone, Address, OTP, Invoice) will appear here in real-time.
              </span>
            </div>
          ) : (
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Booking ID</th>
                  <th>Customer</th>
                  <th>Service</th>
                  <th>Technician</th>
                  <th>Amount</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Action</th>
                </tr>
              </thead>
              <tbody>
                {bookings.slice(0, 5).map(b => {
                  const custName = b.customerName || b.customer || 'Customer';
                  const custPhone = b.customerPhone || b.phone || 'N/A';
                  const srvName = b.serviceName || b.service || 'Service';
                  const catName = b.category || 'General';
                  const totalAmt = b.totalAmount || b.grandTotal || b.price || 0;
                  const techName = b.technicianName || b.technician || 'Pending Dispatch';

                  return (
                    <tr key={b.id || b.bookingCode}>
                      <td>
                        <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{b.bookingCode || b.id}</strong>
                        <div style={{ fontSize: '11px', color: '#64748B' }}>OTP: {b.startOtp || '—'}</div>
                      </td>
                      <td>
                        <div><strong>{custName}</strong></div>
                        <small style={{ color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{custPhone}</small>
                        {b.address && (
                          <div style={{ fontSize: '11px', color: '#64748B', maxWidth: '180px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            📍 {b.address}
                          </div>
                        )}
                      </td>
                      <td>
                        <div><strong>{srvName}</strong></div>
                        <span className="badge badge-info" style={{ fontSize: '10.5px', marginTop: '2px' }}>
                          {catName}
                        </span>
                      </td>
                      <td>
                        <strong>{techName}</strong>
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)', fontFamily: 'monospace' }}>₹{totalAmt}</strong>
                      </td>
                      <td>
                        <span className={`badge ${
                          b.status === 'COMPLETED' ? 'badge-completed' :
                          b.status === 'CONFIRMED' || b.status === 'ASSIGNED' || b.status === 'TECHNICIAN_ASSIGNED' ? 'badge-confirmed' :
                          b.status === 'CANCELLED' ? 'badge-cancelled' : 'badge-pending'
                        }`}>
                          {b.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => onNavigate('bookings', 'all')}>
                          View Details
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
