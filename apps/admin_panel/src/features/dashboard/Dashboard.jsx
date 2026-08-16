import React, { useState } from 'react';

export default function Dashboard({ stats, bookings = [], technicians = [], customers = [], onNavigate }) {
  const [timeRange, setTimeRange] = useState('today');

  // Real-time KPI Calculations from live backend PostgreSQL statistics
  const totalBookingsCount = stats?.totalBookings ?? bookings.length;
  const totalRevenue = stats?.totalRevenue ?? 0;
  const totalCustomers = stats?.totalCustomers ?? customers.length;
  const verifiedTechnicians = stats?.verifiedTechnicians ?? technicians.filter(t => t.kycStatus === 'VERIFIED').length;
  const onlineTechnicians = stats?.onlineTechnicians ?? technicians.filter(t => t.isOnline).length;
  const activeBookingsCount = stats?.activeBookings ?? bookings.filter(b => ['CONFIRMED', 'ASSIGNED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'].includes(b.status)).length;
  const completedBookingsCount = stats?.completedBookings ?? bookings.filter(b => b.status === 'COMPLETED').length;
  const cancelledBookingsCount = stats?.cancelledBookings ?? bookings.filter(b => b.status === 'CANCELLED').length;

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
          <p className="page-subtitle">Real-time overview of bookings, fleet capacity, revenues, and service operations</p>
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

      {/* ─── TOP STATISTICS CARDS (WHITE, 1PX BORDER, FLAT 2D) ─── */}
      <div className="stats-grid">
        <div className="stat-card" onClick={() => onNavigate('bookings', 'all')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Total Bookings</span>
            <div className="stat-icon">📋</div>
          </div>
          <div className="stat-value">{totalBookingsCount.toLocaleString()}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">{activeBookingsCount} active</span> currently in-flight
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('payments', 'transactions')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Total Revenue</span>
            <div className="stat-icon">₹</div>
          </div>
          <div className="stat-value">₹{totalRevenue.toLocaleString()}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">₹{(stats?.todayRevenue ?? 0).toLocaleString()}</span> today
          </div>
        </div>

        <div className="stat-card" onClick={() => onNavigate('customers', '')} style={{ cursor: 'pointer' }}>
          <div className="stat-card-header">
            <span className="stat-title">Total Customers</span>
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
            <div className="stat-icon">👨🔧</div>
          </div>
          <div className="stat-value">{verifiedTechnicians}</div>
          <div className="stat-subtext">
            <span className="stat-trend-positive">{onlineTechnicians} Online</span> in-field ready
          </div>
        </div>
      </div>

      {/* ─── 2D CHARTS SECTION ─── */}
      <div className="charts-grid">
        {/* 2D Booking Velocity Bar Chart */}
        <div className="flat-chart-box">
          <div className="flat-chart-header">
            <h3 className="flat-chart-title">Booking Velocity & Completion Ratio</h3>
            <span className="badge badge-info">PostgreSQL Live Data</span>
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
              <span>Ongoing In-Field / Dispatched</span>
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

        {/* 2D Revenue Breakdown */}
        <div className="flat-chart-box">
          <div className="flat-chart-header">
            <h3 className="flat-chart-title">Revenue Breakdown (Platform Settlement)</h3>
            <span className="badge badge-info">Live Financial Ledger</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '6px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--primary-light)', borderRadius: '4px' }}>
              <span style={{ fontWeight: '600', color: 'var(--text-main)' }}>🔧 Service Base Revenue</span>
              <strong style={{ color: 'var(--primary)' }}>₹{totalRevenue > 0 ? (totalRevenue * 0.82).toFixed(2) : '0.00'}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px' }}>
              <span style={{ color: 'var(--text-main)' }}>📍 Safety & Convenience Fee Volume</span>
              <strong>₹{(completedBookingsCount * 49).toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px' }}>
              <span style={{ color: 'var(--text-main)' }}>🏛️ GST Invoices (18% Collected)</span>
              <strong>₹{totalRevenue > 0 ? (totalRevenue * 0.18).toFixed(2) : '0.00'}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 12px', background: 'var(--bg-white)', border: '1.5px solid var(--primary)', borderRadius: '4px' }}>
              <span style={{ fontWeight: '800', color: 'var(--text-main)' }}>💎 Net Realized Platform Volume</span>
              <strong style={{ color: 'var(--primary)', fontSize: '15px' }}>₹{totalRevenue.toFixed(2)}</strong>
            </div>
          </div>
        </div>
      </div>

      {/* ─── RECENT BOOKINGS FLAT TABLE ─── */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Recent Live Booking Dispatches</h3>
          <button className="btn btn-secondary btn-sm" onClick={() => onNavigate('bookings', 'all')}>
            View All Bookings →
          </button>
        </div>

        <div className="table-responsive">
          {bookings.length === 0 ? (
            <div style={{ padding: '36px', textAlign: 'center', color: 'var(--text-secondary)' }}>
              <p style={{ fontSize: '14px', marginBottom: '8px' }}>📋 No bookings recorded in database yet.</p>
              <span style={{ fontSize: '12px' }}>Real bookings will appear automatically when customers place service requests.</span>
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
                {bookings.slice(0, 5).map(b => (
                  <tr key={b.id}>
                    <td>
                      <strong style={{ color: 'var(--primary)' }}>{b.bookingCode || b.id}</strong>
                    </td>
                    <td>
                      <div>{b.customer?.fullName || b.customer || 'Customer'}</div>
                      <small style={{ color: 'var(--text-secondary)' }}>{b.customer?.phone || b.phone || ''}</small>
                    </td>
                    <td>
                      <div>{b.service?.name || b.service || 'General Service'}</div>
                      <span className="badge badge-info" style={{ fontSize: '11px', marginTop: '2px' }}>
                        {b.service?.category?.name || b.category || 'Service'}
                      </span>
                    </td>
                    <td>
                      <strong>{b.technician?.user?.fullName || b.technician || 'Pending Dispatch'}</strong>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)' }}>₹{b.grandTotal || b.price || 0}</strong>
                    </td>
                    <td>
                      <span className={`badge ${
                        b.status === 'COMPLETED' ? 'badge-completed' :
                        b.status === 'CONFIRMED' || b.status === 'ASSIGNED' ? 'badge-confirmed' :
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
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
