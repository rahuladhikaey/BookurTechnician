import React, { useState } from 'react';

const ADMIN_ROLES = [
  { role: 'Super Admin', desc: 'Full unrestricted system, finance, dispatch and user access.', usersCount: 2, color: 'var(--primary)' },
  { role: 'Operations Admin', desc: 'Bookings, technicians verification, dispatch console, live fleet.', usersCount: 5, color: '#0284C7' },
  { role: 'Finance Admin', desc: 'Payments ledger, pricing rules, GST rates, refund processing (48h).', usersCount: 3, color: '#15803D' },
  { role: 'Support Admin', desc: 'Customer complaints, tickets, review moderation, customer accounts.', usersCount: 8, color: '#D97706' },
  { role: 'Content Admin', desc: 'Promotional banners, services catalog, notification broadcasts.', usersCount: 2, color: '#7C3AED' }
];

export default function SettingsManager({ settings, setSettings, auditLogs, auditLogAction, subTab = 'settings', onResetDatabase }) {
  const [currentSubTab, setCurrentSubTab] = useState(subTab);
  const [formData, setFormData] = useState({
    companyName: 'BookurTechnician Private Limited',
    supportPhone: '+91 99999-88888',
    supportEmail: 'support@bookurtechnician.com',
    cancellationWindow: 1,
    bookingCharge: 99,
    gstRate: 18,
    refundSlaHours: 48,
    dispatchTimeoutMinutes: 10,
    serviceRadiusKm: 25,
    enable2Fa: true,
    ...settings
  });

  const handleSaveGeneral = (e) => {
    e.preventDefault();
    setSettings(formData);
    auditLogAction?.('Settings', 'Updated Global Platform & Business Settings');
    alert('System configuration updated successfully!');
  };

  return (
    <div className="settings-manager-view">
      {/* ─── FLAT TABS ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${currentSubTab === 'settings' ? 'active' : ''}`} onClick={() => setCurrentSubTab('settings')}>
          ⚙️ Business & General Config
        </div>
        <div className={`flat-tab ${currentSubTab === 'roles' ? 'active' : ''}`} onClick={() => setCurrentSubTab('roles')}>
          🛡️ Roles & Permissions Matrix
        </div>
        <div className={`flat-tab ${currentSubTab === 'audit' ? 'active' : ''}`} onClick={() => setCurrentSubTab('audit')}>
          📜 Immutable Audit Logs ({auditLogs.length})
        </div>
        <div className={`flat-tab ${currentSubTab === 'reset' ? 'active' : ''}`} onClick={() => setCurrentSubTab('reset')}>
          🧹 Reset Sandbox Database
        </div>
      </div>

      {/* ─── TAB 1: GENERAL CONFIG ─── */}
      {currentSubTab === 'settings' && (
        <div className="panel" style={{ maxWidth: '840px' }}>
          <div className="panel-header">
            <h3 className="panel-title">🏢 Platform & Enterprise Parameters</h3>
          </div>
          <form onSubmit={handleSaveGeneral}>
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Company Legal Name</label>
                <input
                  type="text"
                  className="form-control"
                  value={formData.companyName}
                  onChange={e => setFormData({ ...formData, companyName: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Support Helpline Number</label>
                <input
                  type="text"
                  className="form-control"
                  value={formData.supportPhone}
                  onChange={e => setFormData({ ...formData, supportPhone: e.target.value })}
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Official Support Email</label>
                <input
                  type="email"
                  className="form-control"
                  value={formData.supportEmail}
                  onChange={e => setFormData({ ...formData, supportEmail: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Service Radius (km)</label>
                <input
                  type="number"
                  className="form-control"
                  value={formData.serviceRadiusKm}
                  onChange={e => setFormData({ ...formData, serviceRadiusKm: Number(e.target.value) })}
                />
              </div>
            </div>

            <div style={{ padding: '16px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '4px', margin: '20px 0' }}>
              <div style={{ fontSize: '13px', fontWeight: '700', color: 'var(--primary)', marginBottom: '8px' }}>
                ⚖️ MANDATORY SYSTEM CONSTANTS (SERVER TRUTH)
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div style={{ padding: '10px', background: 'var(--bg-white)', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
                  <strong>Booking Charge: ₹{formData.bookingCharge}.00</strong>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Non-refundable fee per booking</div>
                </div>
                <div style={{ padding: '10px', background: 'var(--bg-white)', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
                  <strong>Statutory GST: {formData.gstRate}%</strong>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Non-refundable government tax</div>
                </div>
                <div style={{ padding: '10px', background: 'var(--bg-white)', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
                  <strong>Free Cancellation: {formData.cancellationWindow} hour(s)</strong>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Before slot starts</div>
                </div>
                <div style={{ padding: '10px', background: 'var(--bg-white)', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
                  <strong>Refund SLA: {formData.refundSlaHours} hours</strong>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Standard bank gateway turnaround</div>
                </div>
              </div>
            </div>

            <button type="submit" className="btn btn-primary">
              Save Platform Configuration
            </button>
          </form>
        </div>
      )}

      {/* ─── TAB 2: ROLES MATRIX ─── */}
      {currentSubTab === 'roles' && (
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">🛡️ Role-Based Access Control (RBAC)</h3>
          </div>
          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Role Name</th>
                  <th>Permission Scope & Responsibilities</th>
                  <th>Active Operators</th>
                  <th>Access Level</th>
                </tr>
              </thead>
              <tbody>
                {ADMIN_ROLES.map(r => (
                  <tr key={r.role}>
                    <td>
                      <strong style={{ color: 'var(--primary)' }}>{r.role}</strong>
                    </td>
                    <td>{r.desc}</td>
                    <td>{r.usersCount} Operators Assigned</td>
                    <td>
                      <span className="badge badge-info">{r.role === 'Super Admin' ? 'Full Root' : 'Scoped Role'}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── TAB 3: AUDIT LOGS ─── */}
      {currentSubTab === 'audit' && (
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">📜 Immutable System & Admin Audit Logs</h3>
          </div>
          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Module</th>
                  <th>Operation Executed</th>
                  <th>Operator</th>
                </tr>
              </thead>
              <tbody>
                {auditLogs.map((log, idx) => (
                  <tr key={idx}>
                    <td>
                      <span style={{ fontSize: '12px', fontFamily: 'monospace', color: 'var(--text-secondary)' }}>
                        {log.timestamp}
                      </span>
                    </td>
                    <td>
                      <span className="badge badge-info">{log.module}</span>
                    </td>
                    <td>{log.action}</td>
                    <td>
                      <strong>{log.operator}</strong>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── TAB 4: DATABASE RESET ─── */}
      {currentSubTab === 'reset' && (
        <div className="panel" style={{ maxWidth: '600px' }}>
          <div className="panel-header">
            <h3 className="panel-title">🧹 Seed & Sandbox Database Utilities</h3>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
            Resetting clears the current browser localStorage session and re-populates all official initial datasets for bookings, services, categories, technicians, and promo banners.
          </p>
          <button className="btn btn-danger" onClick={onResetDatabase}>
            Reset Database to Production Defaults
          </button>
        </div>
      )}
    </div>
  );
}
