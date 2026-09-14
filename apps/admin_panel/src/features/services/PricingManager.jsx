import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function PricingManager({ auditLogAction }) {
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCategory, setFilterCategory] = useState('ALL');
  const [gstRate, setGstRate] = useState(18.0);
  
  // Modal Edit State
  const [editingService, setEditingService] = useState(null);
  const [editForm, setEditForm] = useState({
    price: 499,
    basePrice: 599,
    offerPrice: 499,
    bookingCharge: 49,
    advancePrepaymentPct: 30,
    technicianPayoutAmount: 380,
    durationMinutes: 45,
    warrantyText: '30 Days Warranty',
    active: true,
  });

  // Simulator Selected Service
  const [simServiceId, setSimServiceId] = useState('');
  const [toastMessage, setToastMessage] = useState(null);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const loadPricingData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.getServices();
      let list = res?.data || (Array.isArray(res) ? res : []);
      if (!Array.isArray(list)) list = [];
      setServices(list);
      if (list.length > 0 && !simServiceId) {
        setSimServiceId(list[0].id);
      }
    } catch (err) {
      console.error('Failed to load pricing data:', err);
      setServices([]);
    } finally {
      setLoading(false);
    }
  }, [simServiceId]);

  useEffect(() => {
    loadPricingData();
  }, [loadPricingData]);

  const openEditPricingModal = (srv) => {
    setEditingService(srv);
    const activePrice = srv.price || srv.basePrice || 499;
    const regularPrice = srv.basePrice || srv.price || 499;
    const offer = srv.offerPrice !== undefined ? srv.offerPrice : activePrice;

    setEditForm({
      price: activePrice,
      basePrice: regularPrice,
      offerPrice: offer,
      bookingCharge: srv.bookingCharge || 49,
      advancePrepaymentPct: srv.advancePrepaymentPct || 30,
      technicianPayoutAmount: srv.technicianPayoutAmount || Math.round(activePrice * 0.8),
      durationMinutes: srv.durationMinutes || 45,
      warrantyText: srv.warrantyText || '30 Days Warranty',
      active: srv.active !== false,
    });
  };

  const handleSaveServicePricing = async (e) => {
    e.preventDefault();
    if (!editingService) return;

    const baseP = Number(editForm.basePrice) || Number(editForm.price) || 0;
    const offerP = editForm.offerPrice !== '' && editForm.offerPrice !== null ? Number(editForm.offerPrice) : baseP;
    const finalSellingPrice = (offerP > 0 && offerP < baseP) ? offerP : (Number(editForm.price) || baseP);

    const updated = {
      ...editingService,
      price: finalSellingPrice,
      basePrice: baseP,
      offerPrice: offerP,
      bookingCharge: Number(editForm.bookingCharge),
      advancePrepaymentPct: Number(editForm.advancePrepaymentPct),
      technicianPayoutAmount: Number(editForm.technicianPayoutAmount),
      durationMinutes: Number(editForm.durationMinutes),
      warrantyText: editForm.warrantyText,
      active: editForm.active,
    };

    try {
      await api.updatePricing(editingService.id, {
        price: updated.price,
        basePrice: updated.basePrice,
        offerPrice: updated.offerPrice,
        bookingCharge: updated.bookingCharge,
        advancePrepaymentPct: updated.advancePrepaymentPct,
        technicianPayoutAmount: updated.technicianPayoutAmount,
        durationMinutes: updated.durationMinutes,
        warrantyText: updated.warrantyText,
        active: updated.active,
      });

      const newList = services.map(s => s.id === editingService.id ? updated : s);
      setServices(newList);
      auditLogAction?.('Pricing', `Updated rate card for "${editingService.name}": Selling=₹${updated.price}, Regular=₹${updated.basePrice}, Offer=₹${updated.offerPrice}, BookingFee=₹${updated.bookingCharge}, Payout=₹${updated.technicianPayoutAmount}`);
      showToast(`✓ Pricing updated for "${editingService.name}"`);
      setEditingService(null);
    } catch (err) {
      console.error('API update pricing error:', err);
      alert('Failed to update pricing: ' + err.message);
    }
  };

  // Filtered Services
  const categories = ['ALL', ...new Set(services.map(s => s.categoryName || s.category?.name || s.category || 'General'))];
  const filteredServices = services.filter(s => {
    const catName = s.categoryName || s.category?.name || s.category || 'General';
    const matchesCat = filterCategory === 'ALL' || catName === filterCategory;
    const q = searchQuery.toLowerCase().trim();
    if (!q) return matchesCat;
    return matchesCat && (s.name.toLowerCase().includes(q) || catName.toLowerCase().includes(q) || (s.subcategoryName && s.subcategoryName.toLowerCase().includes(q)));
  });

  // Simulator Math
  const activeSim = services.find(s => s.id === simServiceId) || services[0] || null;
  const simBase = Number(activeSim?.price) || 0;
  const simBookingFee = Number(activeSim?.bookingCharge) || 0;
  const simGst = ((simBase + simBookingFee) * gstRate) / 100;
  const simGrandTotal = simBase + simBookingFee + simGst;
  const simAdvancePrepayment = simBookingFee + (simBase * (Number(activeSim?.advancePrepaymentPct || 30) / 100));
  const simBalanceOnFinish = simGrandTotal - simAdvancePrepayment;
  const simPartnerPayout = Number(activeSim?.technicianPayoutAmount) || Math.round(simBase * 0.8);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast */}
      {toastMessage && (
        <div style={{
          position: 'fixed',
          bottom: '24px',
          right: '24px',
          zIndex: 999,
          padding: '12px 18px',
          backgroundColor: '#0F172A',
          color: '#FFFFFF',
          borderRadius: '8px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.15)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          fontSize: '13px',
          fontWeight: '700'
        }}>
          <span>✓</span>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* ─── 1. TOP HEADER ─── */}
      <div className="panel" style={{ margin: 0, display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '8px',
            backgroundColor: '#0F172A',
            color: '#FFFFFF',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '20px'
          }}>
            🏷️
          </div>
          <div>
            <h2 style={{ fontSize: '18px', fontWeight: '800', color: '#0F172A', margin: 0 }}>
              Dynamic Service Rate Cards & Pricing Management ({services.length} Services)
            </h2>
            <p style={{ fontSize: '12.5px', color: '#64748B', margin: '2px 0 0' }}>
              Set customized selling rates, regular MRP, special offer prices, booking fees (₹49 / ₹99), advance % rules, and partner earnings.
            </p>
          </div>
        </div>

        <button onClick={loadPricingData} className="btn btn-outline btn-sm">
          🔄 Refresh Rate Cards
        </button>
      </div>

      {/* ─── 2. LIVE PRICING SIMULATOR & PARAMETER SUMMARY ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '14px' }}>
        
        {/* Simulator Selector Card */}
        <div className="panel" style={{ margin: 0, padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: '13.5px', fontWeight: '800', color: '#0F172A' }}>
              🧮 Live Multi-Service Pricing Simulator
            </div>
            <span className="badge badge-info">18% GST Configured</span>
          </div>

          <div className="form-group" style={{ margin: 0 }}>
            <label className="form-label" style={{ fontSize: '12px' }}>Select Target Service to Simulate Customer Pay</label>
            <select
              className="form-control"
              value={simServiceId}
              onChange={e => setSimServiceId(e.target.value)}
              style={{ fontSize: '13px', fontWeight: '700' }}
            >
              {services.map(s => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.categoryName || s.category?.name || 'General'}) — Selling ₹{s.price} {s.offerPrice && s.offerPrice < s.basePrice ? `(Offer ₹${s.offerPrice})` : ''} | Fee ₹{s.bookingCharge || 49}
                </option>
              ))}
            </select>
          </div>

          <div style={{ backgroundColor: '#F8FAFC', padding: '12px', borderRadius: '6px', border: '1px solid #E2E8F0', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: '#64748B' }}>Base / Selling Cost:</span>
              <strong style={{ color: '#0F172A', fontFamily: 'monospace' }}>₹{simBase.toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: '#64748B' }}>Service Booking / Inspection Fee:</span>
              <strong style={{ color: '#D97706', fontFamily: 'monospace' }}>₹{simBookingFee.toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: '#64748B' }}>Statutory GST Tax (18%):</span>
              <strong style={{ color: '#0F172A', fontFamily: 'monospace' }}>₹{simGst.toFixed(2)}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid #E2E8F0', paddingTop: '6px', fontWeight: '800', fontSize: '13.5px' }}>
              <span style={{ color: '#0F172A' }}>Total Customer Payable:</span>
              <span style={{ color: '#15803D', fontFamily: 'monospace' }}>₹{simGrandTotal.toFixed(2)}</span>
            </div>
          </div>
        </div>

        {/* Prepayment & Technician Payout Split Card */}
        <div className="panel" style={{ margin: 0, padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <div style={{ fontSize: '13.5px', fontWeight: '800', color: '#0F172A' }}>
            💳 Online Prepayment & Technician Settlement Split
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
            <div style={{ backgroundColor: '#EFF6FF', border: '1px solid #BFDBFE', borderRadius: '6px', padding: '10px' }}>
              <div style={{ fontSize: '11px', fontWeight: '800', color: '#1E40AF', textTransform: 'uppercase' }}>
                Online Prepayment ({activeSim?.advancePrepaymentPct || 30}%)
              </div>
              <div style={{ fontSize: '18px', fontWeight: '900', color: '#1E40AF', fontFamily: 'monospace', marginTop: '2px' }}>
                ₹{simAdvancePrepayment.toFixed(2)}
              </div>
              <div style={{ fontSize: '10.5px', color: '#64748B', marginTop: '2px' }}>
                Booking Fee + {activeSim?.advancePrepaymentPct || 30}% Service
              </div>
            </div>

            <div style={{ backgroundColor: '#ECFDF5', border: '1px solid #A7F3D0', borderRadius: '6px', padding: '10px' }}>
              <div style={{ fontSize: '11px', fontWeight: '800', color: '#15803D', textTransform: 'uppercase' }}>
                Partner Net Payout
              </div>
              <div style={{ fontSize: '18px', fontWeight: '900', color: '#15803D', fontFamily: 'monospace', marginTop: '2px' }}>
                ₹{simPartnerPayout.toFixed(2)}
              </div>
              <div style={{ fontSize: '10.5px', color: '#64748B', marginTop: '2px' }}>
                Disbursed to Partner Wallet
              </div>
            </div>
          </div>

          <div style={{ backgroundColor: '#FFFBEB', border: '1px solid #FDE68A', borderRadius: '6px', padding: '8px 10px', fontSize: '11.5px', color: '#D97706', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>Balance to Collect by Partner on Finish:</span>
            <strong style={{ fontFamily: 'monospace', fontSize: '13px' }}>₹{simBalanceOnFinish.toFixed(2)}</strong>
          </div>
        </div>
      </div>

      {/* ─── 3. SEARCH & CATEGORY FILTER ─── */}
      <div className="panel" style={{ margin: 0, padding: '12px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div style={{ position: 'relative', width: '100%', maxWidth: '320px' }}>
          <input
            type="text"
            className="form-control"
            placeholder="Search service title, category, subcategory..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{ paddingLeft: '32px', fontSize: '12.5px' }}
          />
          <span style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', opacity: 0.5 }}>
            🔍
          </span>
        </div>

        {/* Category Pills */}
        <div style={{ display: 'flex', backgroundColor: '#F1F5F9', borderRadius: '6px', padding: '2px', border: '1px solid #E2E8F0', flexWrap: 'wrap', gap: '2px' }}>
          {categories.map(cat => (
            <button
              key={cat}
              onClick={() => setFilterCategory(cat)}
              style={{
                padding: '4px 10px',
                borderRadius: '4px',
                border: 'none',
                backgroundColor: filterCategory === cat ? '#0F172A' : 'transparent',
                color: filterCategory === cat ? '#FFFFFF' : '#64748B',
                fontSize: '11.5px',
                fontWeight: '700',
                cursor: 'pointer'
              }}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* ─── 4. SERVICE-BY-SERVICE PRICING TABLE ─── */}
      <div className="panel" style={{ margin: 0, padding: 0, overflow: 'hidden' }}>
        <div style={{ overflowX: 'auto' }}>
          <table className="data-table" style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ backgroundColor: '#F8FAFC', borderBottom: '1px solid #E2E8F0' }}>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Service Name</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Category / Subcategory</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Regular MRP (₹)</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Offer Price (₹)</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Booking Fee (₹)</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Advance Pay (30%)</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Partner Payout (₹)</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Warranty</th>
                <th style={{ padding: '12px 16px', textAlign: 'right', fontSize: '12px', fontWeight: '800', color: '#0F172A' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredServices.map(srv => {
                const base = Number(srv.basePrice || srv.price) || 0;
                const activePrice = Number(srv.price) || base;
                const offer = srv.offerPrice !== undefined ? Number(srv.offerPrice) : activePrice;
                const hasDiscount = offer > 0 && offer < base;
                const discountPct = hasDiscount ? Math.round(((base - offer) / base) * 100) : 0;
                const fee = Number(srv.bookingCharge) || 49;
                const advance = fee + (activePrice * (Number(srv.advancePrepaymentPct || 30) / 100));
                const payout = Number(srv.technicianPayoutAmount) || Math.round(activePrice * 0.8);
                const catName = srv.categoryName || srv.category?.name || srv.category || 'General';
                const subName = srv.subcategoryName || srv.subcategory?.name || '';

                return (
                  <tr key={srv.id} style={{ borderBottom: '1px solid #E2E8F0' }}>
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ fontWeight: '800', color: '#0F172A', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span>{srv.name}</span>
                        {!srv.active && <span className="badge badge-error" style={{ fontSize: '9.5px' }}>Disabled</span>}
                      </div>
                      <div style={{ fontSize: '11px', color: '#64748B', maxWidth: '280px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {srv.description || 'Verified on-demand doorstep service.'}
                      </div>
                    </td>
                    <td style={{ padding: '12px 16px' }}>
                      <span className="badge badge-info" style={{ fontWeight: '700' }}>{catName}</span>
                      {subName && (
                        <div style={{ fontSize: '10.5px', color: '#64748B', marginTop: '3px' }}>
                          ↳ {subName}
                        </div>
                      )}
                    </td>
                    <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '800', fontSize: '13px', color: hasDiscount ? '#94A3B8' : '#0F172A', textDecoration: hasDiscount ? 'line-through' : 'none' }}>
                      ₹{base}
                    </td>
                    <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '900', fontSize: '13.5px', color: '#16A34A' }}>
                      ₹{offer || activePrice}
                      {hasDiscount && (
                        <span style={{ marginLeft: '6px', fontSize: '10px', backgroundColor: '#DCFCE7', color: '#15803D', padding: '2px 5px', borderRadius: '4px', fontWeight: '800' }}>
                          {discountPct}% OFF
                        </span>
                      )}
                    </td>
                    <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '800', fontSize: '13.5px', color: '#D97706' }}>
                      ₹{fee}
                    </td>
                    <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '800', fontSize: '12.5px', color: '#1E40AF' }}>
                      ₹{advance.toFixed(0)}
                    </td>
                    <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: '800', fontSize: '13.5px', color: '#15803D' }}>
                      ₹{payout}
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '11.5px', color: '#64748B' }}>
                      🛡️ {srv.warrantyText || '30 Days'}
                    </td>
                    <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                      <button
                        onClick={() => openEditPricingModal(srv)}
                        className="btn btn-primary btn-sm"
                        style={{ fontSize: '11.5px', padding: '4px 10px' }}
                      >
                        ⚙️ Edit Rates
                      </button>
                    </td>
                  </tr>
                );
              })}

              {filteredServices.length === 0 && (
                <tr>
                  <td colSpan={9} style={{ padding: '32px', textAlign: 'center', color: '#94A3B8' }}>
                    {loading ? 'Loading live service rates...' : 'No services found matching search or category.'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── 5. EDIT SERVICE PRICING MODAL ─── */}
      {editingService && (
        <div className="modal-overlay">
          <div className="modal-dialog" style={{ maxWidth: '580px' }}>
            <div className="modal-header">
              <div className="modal-title">
                Configure Pricing & Rates for "{editingService.name}"
              </div>
              <button className="modal-close-btn" onClick={() => setEditingService(null)}>
                ✕
              </button>
            </div>

            <form onSubmit={handleSaveServicePricing}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div style={{ backgroundColor: '#F8FAFC', padding: '10px 14px', borderRadius: '6px', border: '1px solid #E2E8F0', fontSize: '12px', display: 'flex', justifyContent: 'space-between' }}>
                  <div>
                    <strong>Category:</strong> {editingService.categoryName || editingService.category?.name || 'General'}
                    {editingService.subcategoryName && ` • ${editingService.subcategoryName}`}
                  </div>
                  <div>
                    <strong>Service ID:</strong> <code>{editingService.id}</code>
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Regular Price / MRP (₹)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={editForm.basePrice}
                      onChange={e => setEditForm({ ...editForm, basePrice: e.target.value })}
                      min="0"
                      step="1"
                      required
                    />
                    <span style={{ fontSize: '11px', color: '#64748B' }}>Original price displayed to customer</span>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Offer / Discount Price (₹)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={editForm.offerPrice}
                      onChange={e => setEditForm({ ...editForm, offerPrice: e.target.value })}
                      min="0"
                      step="1"
                      placeholder="Same as regular if no discount"
                    />
                    <span style={{ fontSize: '11px', color: '#64748B' }}>Discounted selling price (shows discount badge)</span>
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Booking / Convenience Fee (₹)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={editForm.bookingCharge}
                      onChange={e => setEditForm({ ...editForm, bookingCharge: e.target.value })}
                      min="0"
                      step="1"
                      required
                    />
                    <span style={{ fontSize: '11px', color: '#64748B' }}>e.g. ₹49 for Repair, ₹99 for Installation</span>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Online Advance Prepayment %</label>
                    <input
                      type="number"
                      className="form-control"
                      value={editForm.advancePrepaymentPct}
                      onChange={e => setEditForm({ ...editForm, advancePrepaymentPct: e.target.value })}
                      min="10"
                      max="100"
                      step="5"
                      required
                    />
                    <span style={{ fontSize: '11px', color: '#64748B' }}>e.g. 30% collected upfront</span>
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Partner Base Payout (₹)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={editForm.technicianPayoutAmount}
                      onChange={e => setEditForm({ ...editForm, technicianPayoutAmount: e.target.value })}
                      min="0"
                      step="1"
                      required
                    />
                    <span style={{ fontSize: '11px', color: '#64748B' }}>Direct net earnings to technician wallet</span>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Estimated Duration (Mins)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={editForm.durationMinutes}
                      onChange={e => setEditForm({ ...editForm, durationMinutes: e.target.value })}
                      min="5"
                      step="5"
                      required
                    />
                    <span style={{ fontSize: '11px', color: '#64748B' }}>e.g. 30 mins, 45 mins, 60 mins</span>
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Warranty Text</label>
                    <input
                      type="text"
                      className="form-control"
                      value={editForm.warrantyText}
                      onChange={e => setEditForm({ ...editForm, warrantyText: e.target.value })}
                      placeholder="e.g. 30 Days Warranty, 90 Days Warranty"
                      required
                    />
                  </div>

                  <div className="form-group" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                    <label className="form-label">Service Status</label>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', marginTop: '6px' }}>
                      <input
                        type="checkbox"
                        checked={editForm.active}
                        onChange={e => setEditForm({ ...editForm, active: e.target.checked })}
                      />
                      <span style={{ fontSize: '13px', fontWeight: '700' }}>Active in Customer App</span>
                    </label>
                  </div>
                </div>

                {/* Calculation Preview */}
                <div style={{ backgroundColor: '#EFF6FF', border: '1px solid #BFDBFE', borderRadius: '6px', padding: '10px 14px', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <div style={{ fontWeight: '800', color: '#1E40AF' }}>Live Summary Preview:</div>
                  <div>• Selling Price: <strong>₹{editForm.offerPrice || editForm.basePrice || editForm.price}</strong> {Number(editForm.offerPrice) < Number(editForm.basePrice) ? `(${Math.round(((Number(editForm.basePrice) - Number(editForm.offerPrice)) / Number(editForm.basePrice)) * 100)}% Discount)` : '(No Discount)'}</div>
                  <div>• Customer Advance: <strong>₹{(Number(editForm.bookingCharge) + ((Number(editForm.offerPrice) || Number(editForm.basePrice) || Number(editForm.price)) * (Number(editForm.advancePrepaymentPct) / 100))).toFixed(0)}</strong></div>
                  <div>• Partner Payout: <strong>₹{editForm.technicianPayoutAmount}</strong></div>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setEditingService(null)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Save & Apply Real Rates
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
