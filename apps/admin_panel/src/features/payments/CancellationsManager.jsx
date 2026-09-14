import React, { useState } from 'react';

export default function CancellationsManager({ auditLogAction }) {
  const [cancellationWindowHours, setCancellationWindowHours] = useState(1);
  const [allowFreeCancellation, setAllowFreeCancellation] = useState(true);
  const [cancellationReasons, setCancellationReasons] = useState([
    'Changed my mind',
    'Wrong service selected',
    'Technician unavailable / delay',
    'Scheduling conflict',
    'Issue resolved independently',
    'Other'
  ]);
  const [newReason, setNewReason] = useState('');

  const handleAddReason = (e) => {
    e.preventDefault();
    if (newReason.trim() && !cancellationReasons.includes(newReason.trim())) {
      setCancellationReasons(prev => [...prev, newReason.trim()]);
      auditLogAction('Cancellation Policy', `Added cancellation reason option: "${newReason.trim()}"`);
      setNewReason('');
    }
  };

  const handleSavePolicy = (e) => {
    e.preventDefault();
    auditLogAction(
      'Cancellation Policy',
      `Updated Cancellation Policy: Free Cancellation Window = ${cancellationWindowHours} hour(s) before scheduled slot. Auto Refund = Enabled.`
    );
    alert('Cancellation Policy configuration saved and updated across Customer and Technician apps!');
  };

  return (
    <div className="cancellations-manager-view">
      <div className="section-header">
        <div>
          <h2>Cancellation Policy & Automated Eligibility Rules</h2>
          <p style={{ fontSize: '13px', color: '#64748B' }}>
            Configure client cancellation windows and automated refund calculations for BookurTechnician.
          </p>
        </div>
      </div>

      <div className="pricing-grid-layout">
        {/* ─── POLICY CONFIGURATION FORM ─── */}
        <div className="settings-card">
          <h3>⏱️ Cancellation Policy Rules</h3>
          <form onSubmit={handleSavePolicy}>
            <div className="form-group" style={{ marginBottom: '16px' }}>
              <label>Free Cancellation Window (Hours before service)</label>
              <input
                type="number"
                value={cancellationWindowHours}
                onChange={e => setCancellationWindowHours(Number(e.target.value))}
                min="0.5"
                max="24"
                step="0.5"
                required
              />
              <span className="helper-text">
                Customers can cancel free of charge up to <strong>{cancellationWindowHours} hour(s)</strong> before their scheduled time slot.
              </span>
            </div>

            <div className="form-group" style={{ marginBottom: '16px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <input
                  type="checkbox"
                  checked={allowFreeCancellation}
                  onChange={e => setAllowFreeCancellation(e.target.checked)}
                />
                <span>Enable Automated Refund Calculation on Qualifying Cancellation</span>
              </label>
            </div>

            <div className="detail-section" style={{ background: '#F8FAFC', marginBottom: '20px' }}>
              <h4>📌 Automated Refund Terms Displayed to Customer:</h4>
              <ul style={{ fontSize: '12px', color: '#64748B', paddingLeft: '18px', marginTop: '6px', lineHeight: '1.5' }}>
                <li>Free cancellation available up to {cancellationWindowHours} hour before scheduled service.</li>
                <li>Booking Charge (₹99.00) is strictly non-refundable.</li>
                <li>GST/taxes are non-refundable.</li>
                <li>Eligible service refund is processed within 48 hours.</li>
              </ul>
            </div>

            <button type="submit" className="btn primary" style={{ width: '100%' }}>
              Save Cancellation Policy
            </button>
          </form>
        </div>

        {/* ─── CANCELLATION REASONS LIST ─── */}
        <div className="settings-card">
          <h3>📋 Customer Cancellation Reasons</h3>
          <p style={{ fontSize: '12px', color: '#64748B', marginBottom: '14px' }}>
            These options are presented to the customer when cancelling in the mobile app:
          </p>

          <ul className="reasons-list" style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {cancellationReasons.map((r, i) => (
              <li key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', background: '#F1F5F9', borderRadius: '8px', fontSize: '13px' }}>
                <span>• {r}</span>
                {cancellationReasons.length > 2 && (
                  <button
                    className="text-btn danger"
                    onClick={() => setCancellationReasons(prev => prev.filter((_, idx) => idx !== i))}
                  >
                    ✕
                  </button>
                )}
              </li>
            ))}
          </ul>

          <form onSubmit={handleAddReason} style={{ display: 'flex', gap: '8px', marginTop: '16px' }}>
            <input
              type="text"
              placeholder="Add new cancellation reason..."
              value={newReason}
              onChange={e => setNewReason(e.target.value)}
              style={{ flex: 1 }}
            />
            <button type="submit" className="btn outline">Add</button>
          </form>
        </div>
      </div>
    </div>
  );
}
