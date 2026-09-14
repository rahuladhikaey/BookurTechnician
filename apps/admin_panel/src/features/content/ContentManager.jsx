import React, { useState } from 'react';

export default function ContentManager({ globalContent, setGlobalContent, auditLogAction }) {
  const [subTab, setSubTab] = useState('banners');
  
  // Home Banner States
  const [banners, setBanners] = useState([
    { id: 1, title: '⚡ Monsoon AC Cleaning Special', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500', actionUrl: 'bookurtech://ac_cleaning' },
    { id: 2, title: '🔌 Safe Electrical Assembly Checks', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500', actionUrl: 'bookurtech://electrician' }
  ]);

  const [newBanner, setNewBanner] = useState({ title: '', imageUrl: '', actionUrl: '' });

  const handleAddBanner = (e) => {
    e.preventDefault();
    const item = { id: Date.now(), ...newBanner };
    setBanners(prev => [...prev, item]);
    auditLogAction('Content Broadcaster', `Added new promo home banner: "${newBanner.title}"`);
    setNewBanner({ title: '', imageUrl: '', actionUrl: '' });
    alert("New home banner slide uploaded!");
  };

  const handleDeleteBanner = (id) => {
    const target = banners.find(b => b.id === id);
    setBanners(prev => prev.filter(b => b.id !== id));
    auditLogAction('Content Broadcaster', `Removed home banner slide: "${target.title}"`);
  };

  const handleSavePolicies = (field, val) => {
    setGlobalContent(prev => ({ ...prev, [field]: val }));
    auditLogAction('Content Policies', `Updated app terms or policies: ${field}`);
    alert("Policy document updated successfully.");
  };

  return (
    <div className="content-manager">
      <div className="settings-tabs">
        <div className={`settings-tab ${subTab === 'banners' ? 'active' : ''}`} onClick={() => setSubTab('banners')}>
          🖼️ Home Promo Banners ({banners.length})
        </div>
        <div className={`settings-tab ${subTab === 'faq_content' ? 'active' : ''}`} onClick={() => setSubTab('faq_content')}>
          📋 Terms & Policies
        </div>
      </div>

      {/* ─── TAB 1: BANNERS ─── */}
      {subTab === 'banners' && (
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="chart-card">
            <h4>Upload Custom Landing Banner</h4>
            <form onSubmit={handleAddBanner} style={{ marginTop: '20px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-group">
                  <label>Banner Slide Title</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. 50% Off Diwali Electrician Checks"
                    value={newBanner.title}
                    onChange={(e) => setNewBanner(prev => ({ ...prev, title: e.target.value }))}
                  />
                </div>
                <div className="form-group">
                  <label>Image Resource URL</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="https://..."
                    value={newBanner.imageUrl}
                    onChange={(e) => setNewBanner(prev => ({ ...prev, imageUrl: e.target.value }))}
                  />
                </div>
                <div className="form-group">
                  <label>Deep Link redirection (App Schema Route)</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="bookurtech://ac_installation"
                    value={newBanner.actionUrl}
                    onChange={(e) => setNewBanner(prev => ({ ...prev, actionUrl: e.target.value }))}
                  />
                </div>
                <div className="text-right">
                  <button type="submit" className="action-btn">Upload Banner Slide</button>
                </div>
              </div>
            </form>
          </div>

          <div className="chart-card">
            <h4>Active Carousel Banners ({banners.length})</h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '20px' }}>
              {banners.map(b => (
                <div key={b.id} style={{ border: '1px solid var(--border-glass)', borderRadius: '12px', overflow: 'hidden', background: 'rgba(255,255,255,0.02)' }}>
                  <img src={b.imageUrl} alt="" style={{ width: '100%', height: '120px', objectFit: 'cover' }} />
                  <div className="p-20 flex-between">
                    <div>
                      <strong style={{ fontSize: '13.5px' }}>{b.title}</strong>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>Route: <code>{b.actionUrl}</code></div>
                    </div>
                    <button className="action-btn action-btn-danger" style={{ padding: '6px 12px' }} onClick={() => handleDeleteBanner(b.id)}>Delete</button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ─── TAB 2: TERMS & POLICIES ─── */}
      {subTab === 'faq_content' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div className="chart-card">
            <h4>Terms and Conditions of Service</h4>
            <textarea
              className="form-control"
              style={{ height: '150px', width: '100%', marginTop: '16px', fontFamily: 'monospace', fontSize: '12px' }}
              defaultValue={globalContent.terms || 'Welcome to BookurTechnician. By booking an installation, handyman or carpenter check, you agree to standard service fee policies...'}
              onBlur={(e) => handleSavePolicies('terms', e.target.value)}
            ></textarea>
            <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '8px' }}>Press Tab or click outside the text block to automatically save changes.</p>
          </div>

          <div className="chart-card">
            <h4>Privacy Policy Agreement</h4>
            <textarea
              className="form-control"
              style={{ height: '150px', width: '100%', marginTop: '16px', fontFamily: 'monospace', fontSize: '12px' }}
              defaultValue={globalContent.privacyPolicy || 'We protect client address details, contact credentials and transaction records with secure token structures...'}
              onBlur={(e) => handleSavePolicies('privacyPolicy', e.target.value)}
            ></textarea>
          </div>
        </div>
      )}
    </div>
  );
}
