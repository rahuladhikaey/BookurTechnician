import React, { useState } from 'react';

export default function SupportManager({
  supportTickets = [],
  setSupportTickets,
  auditLogAction
}) {
  const [selectedTicket, setSelectedTicket] = useState(null);
  
  const handleUpdateTicketStatus = (ticketId, nextStatus) => {
    setSupportTickets(prev => prev.map(t => t.id === ticketId ? { ...t, status: nextStatus } : t));
    auditLogAction?.('Support', `Updated Ticket ${ticketId} status to ${nextStatus}`);
    
    if (selectedTicket && selectedTicket.id === ticketId) {
      setSelectedTicket(prev => ({ ...prev, status: nextStatus }));
    }
  };

  return (
    <div className="support-manager-view">
      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Support Helpdesk & Complaints</h2>
            <p className="page-subtitle">
              Resolve customer grievances, assignment escalations, and technician disputes
            </p>
          </div>
        </div>

        {/* ─── FLAT TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Ticket ID</th>
                <th>Customer</th>
                <th>Booking ID</th>
                <th>Issue Category</th>
                <th>Description</th>
                <th>Priority</th>
                <th>Assigned Agent</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {supportTickets.map((t) => (
                <tr key={t.id}>
                  <td>
                    <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{t.id}</strong>
                  </td>
                  <td>
                    <strong style={{ color: 'var(--text-main)' }}>{t.customer}</strong>
                  </td>
                  <td>
                    <strong style={{ color: 'var(--text-main)', fontFamily: 'monospace' }}>{t.bookingId}</strong>
                  </td>
                  <td>
                    <span className="badge badge-info">{t.issueType}</span>
                  </td>
                  <td>
                    <span style={{ fontSize: '12.5px', color: 'var(--text-secondary)' }}>
                      {t.description.slice(0, 60)}...
                    </span>
                  </td>
                  <td>
                    <span className={`badge ${t.priority === 'High' ? 'badge-cancelled' : 'badge-pending'}`}>
                      {t.priority}
                    </span>
                  </td>
                  <td>{t.assignedAgent || 'Unassigned'}</td>
                  <td>
                    <span className={`badge ${
                      t.status === 'Open' ? 'badge-cancelled' :
                      t.status === 'In Progress' ? 'badge-confirmed' : 'badge-completed'
                    }`}>
                      {t.status}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn btn-primary btn-sm" onClick={() => setSelectedTicket(t)}>
                      Resolve →
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── TICKET RESOLUTION MODAL ─── */}
      {selectedTicket && (
        <div className="modal-overlay" onClick={() => setSelectedTicket(null)}>
          <div className="modal-dialog" style={{ maxWidth: '560px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Helpdesk Ticket: {selectedTicket.id}</h3>
              <button className="modal-close-btn" onClick={() => setSelectedTicket(null)}>×</button>
            </div>
            <div className="modal-body">
              <div style={{ padding: '12px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '4px', marginBottom: '14px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Customer:</span>
                  <strong>{selectedTicket.customer}</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Booking ID:</span>
                  <strong style={{ fontFamily: 'monospace', color: 'var(--primary)' }}>{selectedTicket.bookingId}</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Issue Type:</span>
                  <span className="badge badge-info">{selectedTicket.issueType}</span>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Full Complaint Description</label>
                <div style={{ padding: '10px 12px', background: '#FFFFFF', border: '1px solid var(--border-color)', borderRadius: '4px', fontSize: '13px' }}>
                  {selectedTicket.description}
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Update Ticket Status</label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {['Open', 'In Progress', 'Resolved', 'Closed'].map(st => (
                    <button
                      key={st}
                      type="button"
                      className={`btn btn-sm ${selectedTicket.status === st ? 'btn-primary' : 'btn-outline'}`}
                      onClick={() => handleUpdateTicketStatus(selectedTicket.id, st)}
                    >
                      {st}
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-outline" onClick={() => setSelectedTicket(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
