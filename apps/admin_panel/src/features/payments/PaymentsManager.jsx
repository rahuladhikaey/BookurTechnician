import React, { useState } from 'react';

export default function PaymentsManager({ bookings = [], auditLogAction, subTab = 'transactions' }) {
  const [activeTab, setActiveTab] = useState(subTab);
  const [filterMode, setFilterMode] = useState('ALL');

  const transactionsPaid = bookings.filter(b => b.paymentStatus === 'Paid' || b.paymentStatus === 'PAID');
  const totalPaidRevenue = transactionsPaid.reduce((sum, b) => sum + (b.price || 1899), 0);
  const totalBookingFees = transactionsPaid.length * 99;
  const totalGstCollected = Math.round((totalPaidRevenue + totalBookingFees) * 0.18);
  const netGrossVolume = totalPaidRevenue + totalBookingFees + totalGstCollected;

  const mockTransactions = [
    { id: 'TXN-90812', bookingId: 'BT-BK-00001234', customer: 'Rahul Customer', amount: 2357.64, gateway: 'Razorpay UPI', refNo: 'pay_Nz38920194', status: 'SUCCESS', date: '15 Aug 2026, 03:15 PM' },
    { id: 'TXN-90811', bookingId: 'BT-BK-00001235', customer: 'Shreya Sharma', amount: 823.62, gateway: 'HDFC NetBanking', refNo: 'pay_Nz20194821', status: 'SUCCESS', date: '14 Aug 2026, 10:05 AM' },
    { id: 'TXN-90810', bookingId: 'BT-BK-00001236', customer: 'Vikas Kumar', amount: 1177.62, gateway: 'Razorpay Cards', refNo: 'pay_Nz10293847', status: 'SUCCESS', date: '15 Aug 2026, 05:20 PM' },
    { id: 'TXN-90809', bookingId: 'BT-BK-00001231', customer: 'Ananya Roy', amount: 469.64, gateway: 'PhonePe UPI', refNo: 'pay_Nz00918234', status: 'FAILED', date: '13 Aug 2026, 01:40 PM' }
  ];

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
                Showing {mockTransactions.length} recent transactions
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
                {mockTransactions.map(txn => (
                  <tr key={txn.id}>
                    <td>
                      <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{txn.id}</strong>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)', fontFamily: 'monospace' }}>{txn.bookingId}</strong>
                    </td>
                    <td>{txn.customer}</td>
                    <td>
                      <strong style={{ color: 'var(--text-main)' }}>₹{txn.amount.toFixed(2)}</strong>
                    </td>
                    <td>
                      <span className="badge badge-info">{txn.gateway}</span>
                    </td>
                    <td>
                      <span style={{ fontFamily: 'monospace', fontSize: '12px', color: 'var(--text-secondary)' }}>{txn.refNo}</span>
                    </td>
                    <td>
                      <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{txn.date}</span>
                    </td>
                    <td>
                      <span className={`badge ${txn.status === 'SUCCESS' ? 'badge-completed' : 'badge-cancelled'}`}>
                        {txn.status}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button className="btn btn-outline btn-sm" onClick={() => alert(`Viewing GST invoice receipt for ${txn.id}`)}>
                        View GST Invoice
                      </button>
                    </td>
                  </tr>
                ))}
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
