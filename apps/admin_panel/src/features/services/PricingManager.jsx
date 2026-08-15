import React, { useState } from 'react';

export default function PricingManager({ auditLogAction }) {
  const [bookingCharge, setBookingCharge] = useState(99.0);
  const [gstRate, setGstRate] = useState(18.0);
  const [taxAppliesTo, setTaxAppliesTo] = useState('BOTH');
  const [testCost, setTestCost] = useState(1899);

  // Dynamic calculations
  const calculatedBookingFee = Number(bookingCharge) || 0;
  const calculatedCost = Number(testCost) || 0;
  const taxableAmount = taxAppliesTo === 'BOTH' ? (calculatedCost + calculatedBookingFee) : calculatedCost;
  const calculatedGst = (taxableAmount * (Number(gstRate) || 18)) / 100;
  const calculatedGrandTotal = calculatedCost + calculatedBookingFee + calculatedGst;

  const handleSavePricingConfig = (e) => {
    e.preventDefault();
    auditLogAction?.(
      'Pricing',
      `Updated Global Pricing Engine: Booking Charge = ₹${bookingCharge}, GST Rate = ${gstRate}%, Scope = ${taxAppliesTo}`
    );
    alert('Global Pricing & Tax Engine Configuration successfully updated!');
  };

  return (
    <div className="pricing-manager-view">
      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Pricing Engine & Tax Configuration</h2>
            <p className="page-subtitle">
              Configure system-wide booking charges, inspection rates, and 18% GST calculation rules
            </p>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '20px' }}>
          {/* ─── FORM: PRICING & TAX RULES ─── */}
          <div style={{ padding: '20px', background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
            <h3 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '14px', color: 'var(--text-main)' }}>
              ⚙️ Global Rate Card Parameters
            </h3>
            <form onSubmit={handleSavePricingConfig}>
              <div className="form-group">
                <label className="form-label">Standard Booking Convenience Charge (₹)</label>
                <input
                  type="number"
                  className="form-control"
                  value={bookingCharge}
                  onChange={e => setBookingCharge(Number(e.target.value))}
                  min="0"
                  step="1"
                  required
                />
                <span style={{ fontSize: '11.5px', color: 'var(--text-secondary)' }}>
                  Non-refundable standard fee applied per booking.
                </span>
              </div>

              <div className="form-group">
                <label className="form-label">Statutory GST / Tax Rate (%)</label>
                <input
                  type="number"
                  className="form-control"
                  value={gstRate}
                  onChange={e => setGstRate(Number(e.target.value))}
                  min="0"
                  max="50"
                  step="0.5"
                  required
                />
                <span style={{ fontSize: '11.5px', color: 'var(--text-secondary)' }}>
                  Standard Goods and Services Tax percentage (18%).
                </span>
              </div>

              <div className="form-group">
                <label className="form-label">GST Scope</label>
                <select className="form-control" value={taxAppliesTo} onChange={e => setTaxAppliesTo(e.target.value)}>
                  <option value="BOTH">Apply GST on (Service Cost + Booking Charge)</option>
                  <option value="SERVICE_ONLY">Apply GST on Service Cost Only</option>
                </select>
              </div>

              <button type="submit" className="btn btn-primary" style={{ width: '100%', marginTop: '8px' }}>
                Save Pricing Configuration
              </button>
            </form>
          </div>

          {/* ─── LIVE DYNAMIC PRICING SIMULATOR ─── */}
          <div style={{ padding: '20px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
            <h3 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '14px', color: 'var(--primary)' }}>
              🧮 Live Rate Calculation Simulator
            </h3>

            <div className="form-group">
              <label className="form-label">Test Base Service Cost (₹)</label>
              <input
                type="number"
                className="form-control"
                value={testCost}
                onChange={e => setTestCost(Number(e.target.value))}
                min="0"
                step="50"
              />
            </div>

            <div style={{ marginTop: '16px', background: 'var(--bg-white)', border: '1px solid var(--border-color)', borderRadius: '4px', padding: '14px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                <span>Base Service Cost:</span>
                <strong>₹{calculatedCost.toFixed(2)}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                <span>Booking Charge (Non-refundable):</span>
                <span>₹{calculatedBookingFee.toFixed(2)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                <span>GST Tax ({gstRate}%):</span>
                <span>₹{calculatedGst.toFixed(2)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '15px', fontWeight: '800', borderTop: '1px solid var(--border-color)', paddingTop: '8px', marginTop: '6px' }}>
                <span>Total Customer Pay:</span>
                <span style={{ color: 'var(--primary)' }}>₹{calculatedGrandTotal.toFixed(2)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
