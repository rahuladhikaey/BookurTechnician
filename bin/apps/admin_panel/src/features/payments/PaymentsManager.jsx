import React, { useState, useEffect } from 'react';

export default function PaymentsManager({ bookings = [], auditLogAction, subTab = 'transactions' }) {
  const [activeTab, setActiveTab] = useState(subTab);
  const [filterMode, setFilterMode] = useState('ALL');
  const [transactions, setTransactions] = useState([]);

  useEffect(() => {
    const token = localStorage.getItem('bt_admin_token');
    const headers = token ? { 'Authorization': `Bearer ${token}` } : {};

    fetch('/api/v1/admin/payments', { headers })
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (data?.data && Array.isArray(data.data)) {
          setTransactions(data.data);
        }
      })
      .catch(() => {});
  }, []);

  const transactionsPaid = bookings.filter(b => b.paymentStatus === 'Paid' || b.paymentStatus === 'PAID');
  const totalPaidRevenue = transactionsPaid.reduce((sum, b) => sum + (b.price || 0), 0);
  const totalBookingFees = transactionsPaid.length * 99;
  const totalGstCollected = Math.round((totalPaidRevenue + totalBookingFees) * 0.18);
  const netGrossVolume = totalPaidRevenue + totalBookingFees + totalGstCollected;

  return (
    <div className="payments-manager-view">
      {/* ─── FLAT TABS ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${activeTab === 'transactions' ? 'active' : ''}`} onClick={() => setActiveTab('transactions')}>
          💳 Transactions Ledger
        </div>
        <div className={`flat-tab ${activeTab === 'summary' ? 'active' : ''}`} onClick={() => setActiveTab('summary')}>
          📊 Revenue & Tax Settlement
        </div>
      </div>

      {activeTab === 'transactions' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Payment Gateway Transactions</h2>
              <p className="page-subtitle">Real-time payment logs, webhook reconciliation, and transaction IDs</p>
            </div>
            <div className="page-actions-group">
              <button className="btn btn-outline" onClick={() => alert('Exporting payment ledger CSV...')}>
                📥 Export Ledger
              </button>
            </div>
          </div>

          <div className="toolbar-row">
            <div className="toolbar-left">
              <select className="filter-select" value={filterMode} onChange={e => setFilterMode(e.target.value)}>
                <option value="ALL">All Gateways</option>
                <option value="UPI">UPI Payments</option>
                <option value="Cards">Card Payments</option>
                <option value="NetBanking">Net Banking</option>
              </select>
            </div>
            <div className="toolbar-right">
              <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                Showing {transactions.length} transactions
              </span>
            </div>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Transaction ID</th>
                  <th>Booking ID</th>
                  <th>Customer</th>
                  <th>Amount (Incl. GST)</th>
                  <th>Payment Gateway</th>
                  <th>Gateway Ref</th>
                  <th>Timestamp</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Receipt</th>
                </tr>
              </thead>
              <tbody>
                {transactions.length === 0 ? (
                  <tr>
                    <td colSpan="9" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                      💳 No transactions yet
                    </td>
                  </tr>
                ) : (
                  transactions.map(txn => (
                    <tr key={txn.id}>
                      <td>
                        <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{txn.id}</strong>
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)', fontFamily: 'monospace' }}>{txn.bookingId}</strong>
                      </td>
                      <td>{txn.customer || txn.customerEmail || 'Customer'}</td>
                      <td>
                        <strong style={{ color: 'var(--text-main)' }}>₹{(txn.amount || 0).toFixed(2)}</strong>
                      </td>
                      <td>
                        <span className="badge badge-info">{txn.gateway || txn.paymentMethod || 'Razorpay'}</span>
                      </td>
                      <td>
                        <span style={{ fontFamily: 'monospace', fontSize: '12px', color: 'var(--text-secondary)' }}>{txn.refNo || txn.razorpayPaymentId || '-'}</span>
                      </td>
                      <td>
                        <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{txn.date || txn.createdAt || '-'}</span>
                      </td>
                      <td>
                        <span className={`badge ${txn.status === 'SUCCESS' || txn.status === 'CAPTURED' ? 'badge-completed' : 'badge-cancelled'}`}>
                          {txn.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => alert(`Viewing GST invoice receipt for ${txn.id}`)}>
                          View GST Invoice
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'summary' && (
        <div>
          <div className="stats-grid">
            <div className="stat-card">
              <div className="stat-card-header">
                <span className="stat-title">Gross Volume</span>
                <div className="stat-icon">₹</div>
              </div>
              <div className="stat-value">₹{netGrossVolume.toLocaleString()}</div>
              <div className="stat-subtext">Total payments cleared</div>
            </div>

            <div className="stat-card">
              <div className="stat-card-header">
                <span className="stat-title">Platform Convenience Fees</span>
                <div className="stat-icon">📍</div>
              </div>
              <div className="stat-value">₹{totalBookingFees.toLocaleString()}</div>
              <div className="stat-subtext">₹99 per confirmed dispatch</div>
            </div>

            <div className="stat-card">
              <div className="stat-card-header">
                <span className="stat-title">18% GST Invoices</span>
                <div className="stat-icon">🏛️</div>
              </div>
              <div className="stat-value">₹{totalGstCollected.toLocaleString()}</div>
              <div className="stat-subtext">Govt tax collected</div>
            </div>
          </div>

          <div className="panel">
            <div className="panel-header">
              <h3 className="panel-title">Weekly Payout Settlements to Technicians</h3>
            </div>
            <div className="table-responsive">
              <table className="flat-table">
                <thead>
                  <tr>
                    <th>Settlement Batch</th>
                    <th>Date Released</th>
                    <th>Active Technicians</th>
                    <th>Net Amount Distributed</th>
                    <th>Payout Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td><strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>SETTLE-2026-W33</strong></td>
                    <td>12 Aug 2026</td>
                    <td>48 Technicians</td>
                    <td><strong>₹1,84,500.00</strong></td>
                    <td><span className="badge badge-completed">Settled via NEFT</span></td>
                  </tr>
                  <tr>
                    <td><strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>SETTLE-2026-W32</strong></td>
                    <td>05 Aug 2026</td>
                    <td>42 Technicians</td>
                    <td><strong>₹1,62,800.00</strong></td>
                    <td><span className="badge badge-completed">Settled via NEFT</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
