import React, { useState, useEffect } from 'react';

export default function RefundsManager({ auditLogAction }) {
  const [refunds, setRefunds] = useState([]);
  const [activeTab, setActiveTab] = useState('ALL');

  useEffect(() => {
    const token = localStorage.getItem('bt_admin_token');
    const headers = token ? { 'Authorization': `Bearer ${token}` } : {};

    fetch('/api/v1/admin/refunds', { headers })
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (data?.data && Array.isArray(data.data)) {
          setRefunds(data.data);
        }
      })
      .catch(() => {});
  }, []);

  const filteredRefunds = refunds.filter(r => {
    if (activeTab === 'ALL') return true;
    return (r.status || '').toUpperCase() === activeTab;
  });

  const handleUpdateRefundStatus = (refundId, nextStatus) => {
    const r = refunds.find(x => x.id === refundId);
    setRefunds(prev => prev.map(x => x.id === refundId ? { ...x, status: nextStatus } : x));
    auditLogAction?.(
      'Refunds',
      `Updated refund ${refundId} for booking ${r?.bookingId} to ${nextStatus}. Eligible Amount: ₹${r?.eligibleRefund}`
    );
  };

  return (
    <div className="refunds-manager-view">
      {/* ─── FLAT TABS ─── */}
      <div className="flat-tabs">
        {['ALL', 'PENDING', 'APPROVED', 'COMPLETED', 'REJECTED'].map(tab => (
          <div
            key={tab}
            className={`flat-tab ${activeTab === tab ? 'active' : ''}`}
            onClick={() => setActiveTab(tab)}
          >
            {tab === 'ALL' ? `All Requests (${refunds.length})` :
             tab === 'PENDING' ? `Pending Approval (${refunds.filter(r => r.status === 'Pending').length})` :
             tab === 'APPROVED' ? `Approved / In Queue (${refunds.filter(r => r.status === 'Approved').length})` :
             tab === 'COMPLETED' ? 'Completed' : 'Rejected'}
          </div>
        ))}
      </div>

      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Refund Management & 48-Hour SLA Processing</h2>
            <p className="page-subtitle">
              Statutory Policy: Booking Charge (₹99) and GST (18%) are retained. Only eligible base service fee is refunded.
            </p>
          </div>
        </div>

        {/* ─── FLAT TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Refund ID</th>
                <th>Booking ID</th>
                <th>Customer</th>
                <th>Customer Paid</th>
                <th>Base Service (Refundable)</th>
                <th>Retained Fees (Chg + GST)</th>
                <th>Eligible Refund</th>
                <th>48h SLA Status</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredRefunds.map(r => (
                <tr key={r.id}>
                  <td>
                    <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{r.id}</strong>
                  </td>
                  <td>
                    <strong style={{ color: 'var(--text-main)', fontFamily: 'monospace' }}>{r.bookingId}</strong>
                  </td>
                  <td>{r.customer}</td>
                  <td>₹{r.originalAmount.toFixed(2)}</td>
                  <td>
                    <strong>₹{r.serviceCost.toFixed(2)}</strong>
                  </td>
                  <td>
                    <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      ₹{(r.bookingCharge + r.gst).toFixed(2)}
                    </span>
                  </td>
                  <td>
                    <strong style={{ color: '#15803D' }}>₹{r.eligibleRefund.toFixed(2)}</strong>
                  </td>
                  <td>
                    {r.status === 'Completed' ? (
                      <span className="badge badge-completed">✓ Settled</span>
                    ) : (
                      <span className="badge badge-pending">⏳ {r.slaHoursRemaining}h SLA</span>
                    )}
                  </td>
                  <td>
                    <span className={`badge ${
                      r.status === 'Completed' ? 'badge-completed' :
                      r.status === 'Approved' ? 'badge-confirmed' :
                      r.status === 'Rejected' ? 'badge-cancelled' : 'badge-pending'
                    }`}>
                      {r.status}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                      {r.status === 'Pending' && (
                        <>
                          <button
                            className="btn btn-primary btn-sm"
                            onClick={() => handleUpdateRefundStatus(r.id, 'Approved')}
                          >
                            Approve Refund
                          </button>
                          <button
                            className="btn btn-danger btn-sm"
                            onClick={() => handleUpdateRefundStatus(r.id, 'Rejected')}
                          >
                            Reject
                          </button>
                        </>
                      )}
                      {r.status === 'Approved' && (
                        <button
                          className="btn btn-primary btn-sm"
                          onClick={() => handleUpdateRefundStatus(r.id, 'Completed')}
                        >
                          Mark Settled via Gateway
                        </button>
                      )}
                      {r.status === 'Completed' && (
                        <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Settlement Complete</span>
                      )}
                    </div>
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
