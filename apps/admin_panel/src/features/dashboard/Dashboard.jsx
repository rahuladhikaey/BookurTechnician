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
      <div className="page-header">
        <div>
          <h1 className="page-title">Operations Command Dashboard</h1>
          <p className="page-subtitle">Real-time overview of live bookings, customer transactions, revenue, and fleet dispatches</p>
        </div>
        <div className="page-actions">
          {['today', '7days', '30days'].map(range => (
            <button
              key={range}
              className={`btn btn-sm ${timeRange === range ? 'btn-royal' : 'btn-outline'}`}
              onClick={() => setTimeRange(range)}
            >
              {range === 'today' ? "Today" : range === '7days' ? 'Last 7 Days' : 'This Month'}
            </button>
          ))}
        </div>
      </div>

      {/* ─── TOP REAL STATISTICS CARDS ─── */}
      <div className="stats-grid">
        <div className="stat-card" onClick={() => onNavigate('bookings', 'all')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-label">Total Live Bookings</span>
            <div className="stat-icon-wrapper stat-icon-royal">📋</div>
          </div>
          <div className="stat-value">{totalBookingsCount.toLocaleString()}</div>
          <div className="stat-trend">
            <span className="trend-up">● {activeBookingsCount} active</span>
            <span style={{ color: 'var(--text-muted)' }}>in-flight dispatches</span>
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('payments', 'transactions')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-label">Realized Revenue</span>
            <div className="stat-icon-wrapper stat-icon-dark">₹</div>
          </div>
          <div className="stat-value">₹{Math.round(totalRevenue).toLocaleString()}</div>
          <div className="stat-trend">
            <span className="trend-up">● ₹{Math.round(todayRevenue).toLocaleString()}</span>
            <span style={{ color: 'var(--text-muted)' }}>today's volume</span>
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('customers', '')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-label">Registered Customers</span>
            <div className="stat-icon-wrapper stat-icon-royal">👥</div>
          </div>
          <div className="stat-value">{totalCustomers.toLocaleString()}</div>
          <div className="stat-trend">
            <span className="trend-up">● {totalCustomers} registered</span>
            <span style={{ color: 'var(--text-muted)' }}>user accounts</span>
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('technicians', 'all')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-label">Verified Technicians</span>
            <div className="stat-icon-wrapper stat-icon-green">👨‍🔧</div>
          </div>
          <div className="stat-value">{verifiedTechnicians}</div>
          <div className="stat-trend">
            <span className="trend-up">● {onlineTechnicians} Online</span>
            <span style={{ color: 'var(--text-muted)' }}>ready for dispatch</span>
          </div>
        </div>
      </div>

      {/* ─── 2D CHARTS & BREAKDOWN SECTION ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '20px', marginBottom: '28px' }}>
        {/* Booking Velocity Bar Chart */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">
              <span>📊</span>
              <span>Booking Status Distribution</span>
            </h3>
            <span className="badge badge-royal">Real-time</span>
          </div>

          <div className="card-body">
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '13px' }}>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>Total Orders Received</span>
                  <strong>{totalBookingsCount} bookings</strong>
                </div>
                <div style={{ height: '8px', background: '#F1F5F9', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: totalBookingsCount > 0 ? '100%' : '0%', height: '100%', background: 'var(--royal-blue)', borderRadius: '4px' }}></div>
                </div>
              </div>

              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '13px' }}>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>Successfully Completed</span>
                  <strong style={{ color: 'var(--status-green)' }}>{completedBookingsCount} jobs ({completedPct}%)</strong>
                </div>
                <div style={{ height: '8px', background: '#F1F5F9', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${completedPct}%`, height: '100%', background: 'var(--status-green)', borderRadius: '4px' }}></div>
                </div>
              </div>

              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '13px' }}>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>Ongoing In-Field / Active</span>
                  <strong style={{ color: 'var(--royal-blue)' }}>{activeBookingsCount} jobs ({activePct}%)</strong>
                </div>
                <div style={{ height: '8px', background: '#F1F5F9', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${activePct}%`, height: '100%', background: 'var(--royal-blue)', borderRadius: '4px' }}></div>
                </div>
              </div>

              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '13px' }}>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>Cancelled Orders</span>
                  <strong style={{ color: 'var(--status-red)' }}>{cancelledBookingsCount} jobs ({cancelledPct}%)</strong>
                </div>
                <div style={{ height: '8px', background: '#F1F5F9', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${cancelledPct}%`, height: '100%', background: 'var(--status-red)', borderRadius: '4px' }}></div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Real Revenue Breakdown */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">
              <span>💳</span>
              <span>Financial Revenue Metrics</span>
            </h3>
            <span className="badge badge-royal">Audited</span>
          </div>

          <div className="card-body">
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 14px', background: 'var(--royal-blue-light)', borderRadius: '8px', border: '1px solid var(--royal-border)' }}>
                <span style={{ fontWeight: '700', color: 'var(--royal-blue-dark)' }}>🔧 Service Net Gross</span>
                <strong style={{ color: 'var(--royal-blue-dark)', fontFamily: 'monospace', fontSize: '14px' }}>₹{(totalRevenue * 0.82).toFixed(2)}</strong>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 14px', background: '#FFFFFF', border: '1px solid var(--border-color)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>📍 Platform Inspection Fees</span>
                <strong style={{ fontFamily: 'monospace', color: 'var(--text-main)' }}>₹{(totalBookingsCount * 49).toFixed(2)}</strong>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 14px', background: '#FFFFFF', border: '1px solid var(--border-color)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>🏛️ GST Invoices (18% Applicable)</span>
                <strong style={{ fontFamily: 'monospace', color: 'var(--text-main)' }}>₹{(totalRevenue * 0.18).toFixed(2)}</strong>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 14px', background: 'var(--bg-sidebar)', color: '#FFFFFF', borderRadius: '8px', marginTop: '4px' }}>
                <span style={{ fontWeight: '800' }}>💎 Net Processed Revenue</span>
                <strong style={{ color: '#60A5FA', fontSize: '16px', fontFamily: 'monospace' }}>₹{totalRevenue.toFixed(2)}</strong>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ─── RECENT LIVE BOOKINGS TABLE ─── */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">
            <span>📋</span>
            <span>Recent Live Booking Dispatches</span>
          </h3>
          <button className="btn btn-outline btn-sm" onClick={() => onNavigate('bookings', 'all')}>
            View All ({bookings.length}) →
          </button>
        </div>

        <div className="table-responsive">
          {bookings.length === 0 ? (
            <div style={{ padding: '48px', textAlign: 'center' }}>
              <div style={{ fontSize: '36px', marginBottom: '12px' }}>📋</div>
              <p style={{ fontSize: '15px', fontWeight: '800', color: 'var(--text-main)', marginBottom: '6px' }}>No bookings created yet</p>
              <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                When a user books a service in the mobile app, details appear here in real-time.
              </span>
            </div>
          ) : (
            <table className="custom-table">
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
                        <strong style={{ color: 'var(--royal-blue)', fontFamily: 'monospace' }}>{b.bookingCode || b.id}</strong>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>OTP: {b.startOtp || '—'}</div>
                      </td>
                      <td>
                        <div><strong>{custName}</strong></div>
                        <small style={{ color: 'var(--text-muted)', fontFamily: 'monospace' }}>{custPhone}</small>
                        {b.address && (
                          <div style={{ fontSize: '11px', color: 'var(--text-muted)', maxWidth: '180px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            📍 {b.address}
                          </div>
                        )}
                      </td>
                      <td>
                        <div><strong>{srvName}</strong></div>
                        <span className="badge badge-royal" style={{ fontSize: '10px', marginTop: '2px' }}>
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
                          b.status === 'COMPLETED' ? 'badge-success' :
                          b.status === 'CONFIRMED' || b.status === 'ASSIGNED' || b.status === 'TECHNICIAN_ASSIGNED' ? 'badge-royal' :
                          b.status === 'CANCELLED' ? 'badge-danger' : 'badge-warning'
                        }`}>
                          {b.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => onNavigate('bookings', 'all')}>
                          View
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
