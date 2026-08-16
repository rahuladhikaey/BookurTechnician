import React, { useState, useEffect } from 'react';

export default function BannersManager({ auditLogAction }) {
  const [banners, setBanners] = useState([]);
  const [activeTab, setActiveTab] = useState('Customer App');
  const [showModal, setShowModal] = useState(false);
  const [editingBanner, setEditingBanner] = useState(null);

  useEffect(() => {
    fetch('/api/v1/banners/running')
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (data?.data && Array.isArray(data.data)) {
          setBanners(data.data);
        }
      })
      .catch(() => {});
  }, []);

  const [formState, setFormState] = useState({
    title: '',
    subtitle: '',
    category: 'AC Service',
    displayOrder: 1,
    isActive: true,
    imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=600',
    appType: 'Customer App'
  });

  const filteredBanners = banners.filter(b => b.appType === activeTab);

  const openAddModal = () => {
    setEditingBanner(null);
    setFormState({
      title: '',
      subtitle: '',
      category: 'AC Service',
      displayOrder: filteredBanners.length + 1,
      isActive: true,
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=600',
      appType: activeTab
    });
    setShowModal(true);
  };

  const openEditModal = (banner) => {
    setEditingBanner(banner.id);
    setFormState({
      title: banner.title,
      subtitle: banner.subtitle,
      category: banner.category,
      displayOrder: banner.displayOrder,
      isActive: banner.isActive,
      imageUrl: banner.imageUrl,
      appType: banner.appType
    });
    setShowModal(true);
  };

  const handleToggleStatus = (id) => {
    setBanners(prev => prev.map(b => b.id === id ? { ...b, isActive: !b.isActive } : b));
    auditLogAction?.('Banners', `Toggled banner status ID ${id}`);
  };

  const handleDelete = (id, title) => {
    if (window.confirm(`Delete banner "${title}"?`)) {
      setBanners(prev => prev.filter(b => b.id !== id));
      auditLogAction?.('Banners', `Deleted banner "${title}"`);
    }
  };

  const handleSave = (e) => {
    e.preventDefault();
    if (editingBanner) {
      setBanners(prev => prev.map(b => b.id === editingBanner ? { ...b, ...formState, displayOrder: Number(formState.displayOrder) } : b));
      auditLogAction?.('Banners', `Updated banner "${formState.title}"`);
    } else {
      const newB = {
        id: `bn_${Date.now()}`,
        ...formState,
        displayOrder: Number(formState.displayOrder)
      };
      setBanners(prev => [...prev, newB]);
      auditLogAction?.('Banners', `Created new banner "${newB.title}"`);
    }
    setShowModal(false);
  };

  return (
    <div className="banners-manager-view">
      <div className="flat-tabs">
        <div className={`flat-tab ${activeTab === 'Customer App' ? 'active' : ''}`} onClick={() => setActiveTab('Customer App')}>
          📱 Customer Running Banners ({banners.filter(b => b.appType === 'Customer App').length})
        </div>
        <div className={`flat-tab ${activeTab === 'Technician App' ? 'active' : ''}`} onClick={() => setActiveTab('Technician App')}>
          👨🔧 Technician Running Banners ({banners.filter(b => b.appType === 'Technician App').length})
        </div>
      </div>

      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Running Banners</h2>
            <p className="page-subtitle">Configure promo hero carousels with flat preview cards and order sequence</p>
          </div>
          <button className="btn btn-primary" onClick={openAddModal}>
            + Add Banner
          </button>
        </div>

        {/* ─── FLAT TABLE VIEW OF RUNNING BANNERS ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th style={{ width: '80px' }}>Order</th>
                <th style={{ width: '120px' }}>Banner Image</th>
                <th>Title / Headline</th>
                <th>Target Category</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBanners.length === 0 ? (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                    🖼️ No banners configured yet
                  </td>
                </tr>
              ) : (
                filteredBanners.map(banner => (
                  <tr key={banner.id}>
                  <td>
                    <span className="badge badge-info" style={{ fontWeight: '700' }}>#{banner.displayOrder}</span>
                  </td>
                  <td>
                    <img src={banner.imageUrl} alt={banner.title} style={{ width: '100px', height: '54px', borderRadius: '4px', objectFit: 'cover', border: '1px solid var(--border-color)' }} />
                  </td>
                  <td>
                    <strong style={{ color: 'var(--text-main)', fontSize: '14px' }}>{banner.title}</strong>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                      {banner.subtitle}
                    </div>
                  </td>
                  <td>
                    <span className="badge badge-info">{banner.category}</span>
                  </td>
                  <td>
                    <span className={`badge ${banner.isActive ? 'badge-completed' : 'badge-cancelled'}`}>
                      {banner.isActive ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                      <button className="btn btn-outline btn-sm" onClick={() => handleToggleStatus(banner.id)}>
                        {banner.isActive ? 'Disable' : 'Enable'}
                      </button>
                      <button className="btn btn-secondary btn-sm" onClick={() => openEditModal(banner)}>
                        Edit
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => handleDelete(banner.id, banner.title)}>
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              )))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── MODAL (FLAT 2D) ─── */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingBanner ? 'Edit Banner' : 'Add New Banner'}</h3>
              <button className="modal-close-btn" onClick={() => setShowModal(false)}>×</button>
            </div>
            <form onSubmit={handleSave}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Banner Headline</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. AC Deep Cleaning Service"
                    value={formState.title}
                    onChange={e => setFormState({ ...formState, title: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Subtitle / Promotion Text</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Flat 20% off on jet pump clean"
                    value={formState.subtitle}
                    onChange={e => setFormState({ ...formState, subtitle: e.target.value })}
                  />
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Target Service / Category</label>
                    <input
                      type="text"
                      className="form-control"
                      value={formState.category}
                      onChange={e => setFormState({ ...formState, category: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Display Order</label>
                    <input
                      type="number"
                      min="1"
                      required
                      className="form-control"
                      value={formState.displayOrder}
                      onChange={e => setFormState({ ...formState, displayOrder: e.target.value })}
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Banner Image URL</label>
                  <input
                    type="url"
                    required
                    className="form-control"
                    value={formState.imageUrl}
                    onChange={e => setFormState({ ...formState, imageUrl: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Status</label>
                  <select
                    className="form-control"
                    value={formState.isActive ? 'true' : 'false'}
                    onChange={e => setFormState({ ...formState, isActive: e.target.value === 'true' })}
                  >
                    <option value="true">Active (Visible on App)</option>
                    <option value="false">Disabled (Hidden)</option>
                  </select>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Banner</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
