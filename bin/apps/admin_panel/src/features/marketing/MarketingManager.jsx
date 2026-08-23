import React, { useState, useEffect } from 'react';

export default function MarketingManager({ 
  coupons, 
  setCoupons, 
  auditLogAction, 
  notificationsLog = [], 
  setNotificationsLog,
  categories = [],
  services = []
}) {
  const [subTab, setSubTab] = useState('coupons');
  
  // Coupon Form States
  const [showCouponModal, setShowCouponModal] = useState(false);
  const [couponForm, setCouponForm] = useState({
    code: '',
    discountType: 'Fixed',
    discountValue: 100,
    maxDiscount: 100,
    minBookingAmount: 499,
    usageLimit: 100,
    userLimit: 1,
    targetAudience: 'New Customers Only',
    isActive: true
  });

  // Notification Broadcaster States
  const [notifForm, setNotifForm] = useState({
    title: '',
    message: '',
    imageUrl: '',
    audience: 'Customers', 
    deepLink: 'bookurtech://home',
    scheduleTime: 'Immediate'
  });

  // Spotlight Banners States
  const [banners, setBanners] = useState([]);
  const [showBannerModal, setShowBannerModal] = useState(false);
  const [editingBannerId, setEditingBannerId] = useState(null);

  // Hero Banners States
  const [heroBanners, setHeroBanners] = useState([]);
  const [showHeroModal, setShowHeroModal] = useState(false);
  const [editingHeroId, setEditingHeroId] = useState(null);

  // Fetch banners from API on mount
  useEffect(() => {
    fetch('/api/v1/banners/spotlight')
      .then(res => res.ok ? res.json() : null)
      .then(data => { if (data?.data && Array.isArray(data.data)) setBanners(data.data); })
      .catch(() => {});

    fetch('/api/v1/banners/hero')
      .then(res => res.ok ? res.json() : null)
      .then(data => { if (data?.data && Array.isArray(data.data)) setHeroBanners(data.data); })
      .catch(() => {});
  }, []);

  // ─── Fetch Banners ──────────────────────────────────────────────────────────
  const fetchAllBanners = async () => {
    // Fetch Spotlight Banners
    try {
      const res = await fetch('/api/v1/spotlight-banners');
      if (res.ok) {
        const data = await res.json();
        if (data.success && data.banners) {
          setBanners(data.banners);
        }
      }
    } catch (e) {
      console.warn('Backend spotlight API offline.');
    }

    // Fetch Hero Banners
    try {
      const res = await fetch('/api/v1/hero-banners');
      if (res.ok) {
        const data = await res.json();
        if (data.success && data.banners) {
          setHeroBanners(data.banners);
        }
      }
    } catch (e) {
      console.warn('Backend hero API offline.');
    }
  };

  useEffect(() => {
    fetchAllBanners();
  }, []);

  // Sync to localstorage
  useEffect(() => {
    localStorage.setItem('bt_spotlight_banners', JSON.stringify(banners));
  }, [banners]);

  useEffect(() => {
    localStorage.setItem('bt_hero_banners', JSON.stringify(heroBanners));
  }, [heroBanners]);

  // ─── Coupons Handlers ──────────────────────────────────────────────────────
  const handleCreateCoupon = (e) => {
    e.preventDefault();
    const newCoupon = {
      id: `coupon_${Date.now()}`,
      ...couponForm,
      discountValue: Number(couponForm.discountValue),
      maxDiscount: Number(couponForm.maxDiscount),
      minBookingAmount: Number(couponForm.minBookingAmount),
      usageLimit: Number(couponForm.usageLimit),
      userLimit: Number(couponForm.userLimit)
    };
    setCoupons(prev => [newCoupon, ...prev]);
    auditLogAction('Marketing Promotion', `Created promotion coupon code ${couponForm.code} (Value: ${couponForm.discountValue})`);
    setShowCouponModal(false);
    alert(`Coupon code ${couponForm.code} has been created and published!`);
  };

  const handleDeleteCoupon = (id) => {
    const target = coupons.find(c => c.id === id);
    if (window.confirm(`Delete coupon ${target.code}?`)) {
      setCoupons(prev => prev.filter(c => c.id !== id));
      auditLogAction('Marketing Promotion', `Deleted promotion coupon code ${target.code}`);
    }
  };

  const handleToggleCoupon = (id) => {
    setCoupons(prev => prev.map(c => {
      if (c.id === id) {
        const nextState = !c.isActive;
        auditLogAction('Marketing Promotion', `Toggled coupon ${c.code} status to ${nextState ? 'Active' : 'Disabled'}`);
        return { ...c, isActive: nextState };
      }
      return c;
    }));
  };

  // ─── Notification Broadcast Handlers ─────────────────────────────────────────
  const handleSendNotification = (e) => {
    e.preventDefault();
    const newLogItem = {
      id: Date.now(),
      title: notifForm.title,
      message: notifForm.message,
      imageUrl: notifForm.imageUrl || 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500',
      audience: notifForm.audience,
      deepLink: notifForm.deepLink,
      sentTime: new Date().toLocaleTimeString(),
      status: 'Sent Successfully'
    };

    setNotificationsLog(prev => [newLogItem, ...prev]);
    auditLogAction('Push Broadcaster', `Sent push broadcast to ${notifForm.audience}: "${notifForm.title}"`);
    alert(`Push Notification broadcasted successfully to all online ${notifForm.audience}!`);
    
    // Clear form
    setNotifForm({
      title: '',
      message: '',
      imageUrl: '',
      audience: 'Customers',
      deepLink: 'bookurtech://home',
      scheduleTime: 'Immediate'
    });
  };

  // ─── Spotlight Banners Handlers ────────────────────────────────────────────
  const handleOpenCreateBanner = () => {
    setEditingBannerId(null);
    setBannerForm({
      badgeText: 'Trending',
      title: '',
      subtitle: '',
      ctaText: 'Book Now',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=800',
      serviceId: '',
      categoryId: '',
      displayOrder: banners.length + 1,
      isActive: true,
      autoSlide: true,
      slideDuration: 4000,
      startDate: new Date().toISOString().slice(0, 10),
      endDate: new Date(Date.now() + 31536000000).toISOString().slice(0, 10)
    });
    setShowBannerModal(true);
  };

  const handleOpenEditBanner = (banner) => {
    setEditingBannerId(banner.id);
    setBannerForm({
      badgeText: banner.badgeText || '',
      title: banner.title || '',
      subtitle: banner.subtitle || '',
      ctaText: banner.ctaText || 'Book Now',
      imageUrl: banner.imageUrl || '',
      serviceId: banner.serviceId || '',
      categoryId: banner.categoryId || '',
      displayOrder: banner.displayOrder || 0,
      isActive: banner.isActive !== undefined ? banner.isActive : true,
      autoSlide: banner.autoSlide !== undefined ? banner.autoSlide : true,
      slideDuration: banner.slideDuration || 4000,
      startDate: new Date(banner.startDate).toISOString().slice(0, 10),
      endDate: new Date(banner.endDate).toISOString().slice(0, 10)
    });
    setShowBannerModal(true);
  };

  const handleSaveBanner = async (e) => {
    e.preventDefault();
    const isEdit = !!editingBannerId;
    const bodyData = {
      ...bannerForm,
      displayOrder: Number(bannerForm.displayOrder),
      slideDuration: Number(bannerForm.slideDuration),
      isActive: Boolean(bannerForm.isActive),
      autoSlide: Boolean(bannerForm.autoSlide)
    };

    if (isEdit) {
      try {
        const res = await fetch(`/api/v1/spotlight-banners/${editingBannerId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(bodyData)
        });
        if (res.ok) {
          setBanners(prev => prev.map(b => b.id === editingBannerId ? { ...bodyData, id: editingBannerId } : b));
          alert('Spotlight banner updated successfully!');
        } else {
          throw new Error('Edit failed');
        }
      } catch (err) {
        setBanners(prev => prev.map(b => b.id === editingBannerId ? { ...bodyData, id: editingBannerId } : b));
        alert('Spotlight banner updated locally (Offline mode).');
      }
      auditLogAction('Spotlight Banners', `Edited spotlight banner "${bannerForm.title}"`);
    } else {
      const tempId = `banner_${Date.now()}`;
      try {
        const res = await fetch('/api/v1/spotlight-banners', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(bodyData)
        });
        if (res.ok) {
          const data = await res.json();
          setBanners(prev => [...prev, { ...bodyData, id: data.banner.id }]);
          alert('Spotlight banner created successfully!');
        } else {
          throw new Error('Create failed');
        }
      } catch (err) {
        setBanners(prev => [...prev, { ...bodyData, id: tempId }]);
        alert('Spotlight banner created locally (Offline mode).');
      }
      auditLogAction('Spotlight Banners', `Created spotlight banner "${bannerForm.title}"`);
    }
    setShowBannerModal(false);
  };

  const handleToggleBanner = async (id) => {
    const target = banners.find(b => b.id === id);
    const updatedStatus = !target.isActive;
    setBanners(prev => prev.map(b => b.id === id ? { ...b, isActive: updatedStatus } : b));
    try {
      await fetch(`/api/v1/spotlight-banners/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: updatedStatus })
      });
    } catch (e) {
      console.warn('Backend offline. Toggled locally.');
    }
    auditLogAction('Spotlight Banners', `Toggled banner "${target.title}" status to ${updatedStatus ? 'Active' : 'Disabled'}`);
  };

  const handleDeleteBanner = async (id) => {
    const target = banners.find(b => b.id === id);
    if (!window.confirm(`Delete spotlight banner "${target.title}"?`)) return;
    try {
      const res = await fetch(`/api/v1/spotlight-banners/${id}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        setBanners(prev => prev.filter(b => b.id !== id));
        alert('Spotlight banner deleted successfully!');
      } else {
        throw new Error('Delete failed');
      }
    } catch (err) {
      setBanners(prev => prev.filter(b => b.id !== id));
      alert('Spotlight banner deleted locally (Offline mode).');
    }
    auditLogAction('Spotlight Banners', `Deleted spotlight banner "${target.title}"`);
  };

  // ─── Hero Banners Handlers ─────────────────────────────────────────────────
  const handleOpenCreateHero = () => {
    setEditingHeroId(null);
    setHeroForm({
      badgeText: 'Trending',
      title: '',
      subtitle: '',
      ctaText: 'Book Now',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000',
      targetServiceId: '',
      displayOrder: heroBanners.length + 1,
      active: true,
      startDate: new Date().toISOString().slice(0, 10),
      endDate: new Date(Date.now() + 31536000000).toISOString().slice(0, 10)
    });
    setShowHeroModal(true);
  };

  const handleOpenEditHero = (hero) => {
    setEditingHeroId(hero.id);
    setHeroForm({
      badgeText: hero.badgeText || '',
      title: hero.title || '',
      subtitle: hero.subtitle || '',
      ctaText: hero.ctaText || 'Book Now',
      imageUrl: hero.imageUrl || '',
      targetServiceId: hero.targetServiceId || '',
      displayOrder: hero.displayOrder || 0,
      active: hero.active !== undefined ? hero.active : true,
      startDate: new Date(hero.startDate).toISOString().slice(0, 10),
      endDate: new Date(hero.endDate).toISOString().slice(0, 10)
    });
    setShowHeroModal(true);
  };

  const handleSaveHeroBanner = async (e) => {
    e.preventDefault();
    const isEdit = !!editingHeroId;
    const bodyData = {
      ...heroForm,
      displayOrder: Number(heroForm.displayOrder),
      active: Boolean(heroForm.active)
    };

    if (isEdit) {
      try {
        const res = await fetch(`/api/v1/hero-banners/${editingHeroId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(bodyData)
        });
        if (res.ok) {
          setHeroBanners(prev => prev.map(h => h.id === editingHeroId ? { ...bodyData, id: editingHeroId } : h));
          alert('Hero banner updated successfully!');
        } else {
          throw new Error('Edit failed');
        }
      } catch (err) {
        setHeroBanners(prev => prev.map(h => h.id === editingHeroId ? { ...bodyData, id: editingHeroId } : h));
        alert('Hero banner updated locally (Offline mode).');
      }
      auditLogAction('Hero Banners', `Edited hero banner "${heroForm.title}"`);
    } else {
      const tempId = `hero_${Date.now()}`;
      try {
        const res = await fetch('/api/v1/hero-banners', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(bodyData)
        });
        if (res.ok) {
          const data = await res.json();
          setHeroBanners(prev => [...prev, { ...bodyData, id: data.banner.id }]);
          alert('Hero banner created successfully!');
        } else {
          throw new Error('Create failed');
        }
      } catch (err) {
        setHeroBanners(prev => [...prev, { ...bodyData, id: tempId }]);
        alert('Hero banner created locally (Offline mode).');
      }
      auditLogAction('Hero Banners', `Created hero banner "${heroForm.title}"`);
    }
    setShowHeroModal(false);
  };

  const handleToggleHero = async (id) => {
    const target = heroBanners.find(h => h.id === id);
    const updatedStatus = !target.active;
    setHeroBanners(prev => prev.map(h => h.id === id ? { ...h, active: updatedStatus } : h));
    try {
      await fetch(`/api/v1/hero-banners/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: updatedStatus })
      });
    } catch (e) {
      console.warn('Backend offline. Toggled locally.');
    }
    auditLogAction('Hero Banners', `Toggled hero banner "${target.title}" status to ${updatedStatus ? 'Active' : 'Disabled'}`);
  };

  const handleDeleteHero = async (id) => {
    const target = heroBanners.find(h => h.id === id);
    if (!window.confirm(`Delete hero banner "${target.title}"?`)) return;
    try {
      const res = await fetch(`/api/v1/hero-banners/${id}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        setHeroBanners(prev => prev.filter(h => h.id !== id));
        alert('Hero banner deleted successfully!');
      } else {
        throw new Error('Delete failed');
      }
    } catch (err) {
      setHeroBanners(prev => prev.filter(h => h.id !== id));
      alert('Hero banner deleted locally (Offline mode).');
    }
    auditLogAction('Hero Banners', `Deleted hero banner "${target.title}"`);
  };

  return (
    <div className="marketing-manager">
      <div className="settings-tabs">
        <div className={`settings-tab ${subTab === 'coupons' ? 'active' : ''}`} onClick={() => setSubTab('coupons')}>
          🎟️ Offers & Coupons ({coupons.length})
        </div>
        <div className={`settings-tab ${subTab === 'notifications' ? 'active' : ''}`} onClick={() => setSubTab('notifications')}>
          🔔 Push Broadcaster & Logs
        </div>
        <div className={`settings-tab ${subTab === 'hero' ? 'active' : ''}`} onClick={() => setSubTab('hero')}>
          👑 Hero Banners ({heroBanners.length})
        </div>
        <div className={`settings-tab ${subTab === 'spotlight' ? 'active' : ''}`} onClick={() => setSubTab('spotlight')}>
          🎬 Spotlight Banners ({banners.length})
        </div>
      </div>

      {/* ─── TAB 1: OFFERS / COUPONS ─── */}
      {subTab === 'coupons' && (
        <div>
          <div className="flex-between m-b-20">
            <h3>Manage Coupons & Discounts</h3>
            <button className="action-btn" onClick={() => setShowCouponModal(true)}>+ Create New Coupon</button>
          </div>

          <div className="table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Coupon Code</th>
                  <th>Discount Value</th>
                  <th>Min Booking</th>
                  <th>Max Discount</th>
                  <th>Limits (User / Total)</th>
                  <th>Target Audience</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {coupons.map((c) => (
                  <tr key={c.id}>
                    <td><code style={{ fontSize: '13.5px', fontWeight: 'bold', color: 'var(--secondary)' }}>{c.code}</code></td>
                    <td>
                      {c.discountType === 'Percentage' ? `${c.discountValue}% Off` : `₹${c.discountValue} Off`}
                    </td>
                    <td>₹{c.minBookingAmount}</td>
                    <td>₹{c.maxDiscount || 'NA'}</td>
                    <td>Limit {c.userLimit} per user / Total {c.usageLimit}</td>
                    <td><span className="badge badge-info">{c.targetAudience}</span></td>
                    <td>
                      <span className={`badge ${c.isActive ? 'badge-success' : 'badge-error'}`}>
                        {c.isActive ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td>
                      <div className="flex-gap">
                        <button className="action-btn action-btn-secondary" onClick={() => handleToggleCoupon(c.id)}>
                          {c.isActive ? 'Disable' : 'Enable'}
                        </button>
                        <button className="action-btn action-btn-danger" onClick={() => handleDeleteCoupon(c.id)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── TAB 2: PUSH BROADCASTER ─── */}
      {subTab === 'notifications' && (
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="chart-card">
            <h4>Broadcaster Tool Terminal</h4>
            <form onSubmit={handleSendNotification} style={{ marginTop: '20px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-group">
                  <label>Target Audience</label>
                  <select className="form-control" value={notifForm.audience} onChange={(e) => setNotifForm(prev => ({ ...prev, audience: e.target.value }))}>
                    <option value="Customers">All Registered Customers</option>
                    <option value="Technicians">All Active Technicians</option>
                    <option value="All">Everyone (Customers + Technicians)</option>
                  </select>
                </div>

                <div className="form-group">
                  <label>Notification Title</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 🌧️ Monsoon Plumbing Checks!"
                    className="form-control"
                    value={notifForm.title}
                    onChange={(e) => setNotifForm(prev => ({ ...prev, title: e.target.value }))}
                  />
                </div>

                <div className="form-group">
                  <label>Message Content</label>
                  <textarea
                    required
                    placeholder="Provide description text..."
                    className="form-control"
                    style={{ height: '70px' }}
                    value={notifForm.message}
                    onChange={(e) => setNotifForm(prev => ({ ...prev, message: e.target.value }))}
                  ></textarea>
                </div>

                <div className="form-group">
                  <label>Promo Image URL (Optional)</label>
                  <input
                    type="text"
                    placeholder="https://..."
                    className="form-control"
                    value={notifForm.imageUrl}
                    onChange={(e) => setNotifForm(prev => ({ ...prev, imageUrl: e.target.value }))}
                  />
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Deep Link Action URL</label>
                    <input
                      type="text"
                      className="form-control"
                      value={notifForm.deepLink}
                      onChange={(e) => setNotifForm(prev => ({ ...prev, deepLink: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>Broadcast Schedule</label>
                    <select className="form-control" value={notifForm.scheduleTime} onChange={(e) => setNotifForm(prev => ({ ...prev, scheduleTime: e.target.value }))}>
                      <option value="Immediate">Send Instantly (Immediate)</option>
                      <option value="1Hour">In 1 Hour</option>
                      <option value="Tonight">Tonight (09:00 PM)</option>
                    </select>
                  </div>
                </div>

                <div className="text-right" style={{ marginTop: '10px' }}>
                  <button type="submit" className="action-btn">Broadcasting Push Alert 📢</button>
                </div>
              </div>
            </form>
          </div>

          <div className="chart-card">
            <h4>Push Notification Dispatch Logs</h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '20px', maxHeight: '350px', overflowY: 'auto' }}>
              {notificationsLog.map(log => (
                <div key={log.id} style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.05)', padding: '12px 14px', borderRadius: '8px' }}>
                  <div className="flex-between">
                    <strong style={{ fontSize: '13px' }}>{log.title}</strong>
                    <span className="badge badge-success" style={{ fontSize: '9px' }}>{log.audience}</span>
                  </div>
                  <div style={{ fontSize: '11.5px', color: 'var(--text-secondary)', marginTop: '4px' }}>{log.message}</div>
                  <div className="flex-between" style={{ marginTop: '8px', fontSize: '10px', color: 'var(--text-muted)' }}>
                    <span>Link: <code>{log.deepLink}</code></span>
                    <span>Sent: {log.sentTime}</span>
                  </div>
                </div>
              ))}

              {notificationsLog.length === 0 && (
                <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '12px', paddingTop: '30px' }}>No broad notifications sent yet.</p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ─── TAB 3: HERO BANNERS ─── */}
      {subTab === 'hero' && (
        <div>
          <div className="flex-between m-b-20">
            <h3>Home Screen Layered Hero Banners</h3>
            <button className="action-btn" onClick={handleOpenCreateHero}>+ Create Hero Campaign</button>
          </div>

          <div className="table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Preview</th>
                  <th>Badge</th>
                  <th>Title / Campaign</th>
                  <th>Pricing / Subtitle</th>
                  <th>Order</th>
                  <th>Linked Service Target</th>
                  <th>Campaign Schedule</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {heroBanners.map((h) => (
                  <tr key={h.id}>
                    <td>
                      <img 
                        src={h.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=100'} 
                        alt="hero banner" 
                        style={{ width: '80px', height: '45px', objectFit: 'cover', borderRadius: '4px', border: '1px solid rgba(255,255,255,0.1)' }}
                      />
                    </td>
                    <td><span className="badge badge-info">{h.badgeText}</span></td>
                    <td style={{ maxWidth: '180px', fontWeight: 'bold' }}>{h.title}</td>
                    <td>{h.subtitle}</td>
                    <td>{h.displayOrder}</td>
                    <td>
                      {h.targetServiceId ? (
                        <div style={{ fontSize: '11px' }}>🛠️ Service: <code>{h.targetServiceId}</code></div>
                      ) : (
                        <span style={{ color: 'var(--text-muted)', fontSize: '11px' }}>None (Static Offer)</span>
                      )}
                    </td>
                    <td style={{ fontSize: '11px', whiteSpace: 'nowrap' }}>
                      {h.startDate.slice(0, 10)} to {h.endDate.slice(0, 10)}
                    </td>
                    <td>
                      <span className={`badge ${h.active ? 'badge-success' : 'badge-error'}`}>
                        {h.active ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td>
                      <div className="flex-gap">
                        <button className="action-btn action-btn-secondary" onClick={() => handleToggleHero(h.id)}>
                          {h.active ? 'Disable' : 'Enable'}
                        </button>
                        <button className="action-btn" onClick={() => handleOpenEditHero(h)}>Edit</button>
                        <button className="action-btn action-btn-danger" onClick={() => handleDeleteHero(h.id)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
                {heroBanners.length === 0 && (
                  <tr>
                    <td colSpan="9" style={{ textAlign: 'center', padding: '30px', color: 'var(--text-muted)' }}>
                      No hero banners created yet. Click "+ Create Hero Campaign" to add one.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── TAB 4: SPOTLIGHT BANNERS ─── */}
      {subTab === 'spotlight' && (
        <div>
          <div className="flex-between m-b-20">
            <h3>Home Screen Promotional Spotlight Banners</h3>
            <button className="action-btn" onClick={handleOpenCreateBanner}>+ Create Spotlight Banner</button>
          </div>

          <div className="table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Preview</th>
                  <th>Badge</th>
                  <th>Headline / Title</th>
                  <th>Sub-text / Category</th>
                  <th>Order</th>
                  <th>Auto-Slide</th>
                  <th>Linked Target</th>
                  <th>Date Range</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {banners.map((b) => (
                  <tr key={b.id}>
                    <td>
                      <img 
                        src={b.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=100'} 
                        alt="banner" 
                        style={{ width: '80px', height: '45px', objectFit: 'cover', borderRadius: '4px', border: '1px solid rgba(255,255,255,0.1)' }}
                      />
                    </td>
                    <td><span className="badge badge-info">{b.badgeText}</span></td>
                    <td style={{ maxWidth: '180px', fontWeight: 'bold' }}>{b.title}</td>
                    <td>{b.subtitle}</td>
                    <td>{b.displayOrder}</td>
                    <td>{b.autoSlide ? `Yes (${b.slideDuration}ms)` : 'No'}</td>
                    <td>
                      {b.serviceId ? (
                        <div style={{ fontSize: '11px' }}>🛠️ Service: <code>{b.serviceId}</code></div>
                      ) : b.categoryId ? (
                        <div style={{ fontSize: '11px' }}>📂 Category: <code>{b.categoryId}</code></div>
                      ) : (
                        <span style={{ color: 'var(--text-muted)', fontSize: '11px' }}>None (Static CTA)</span>
                      )}
                    </td>
                    <td style={{ fontSize: '11px', whiteSpace: 'nowrap' }}>
                      {b.startDate.slice(0, 10)} to {b.endDate.slice(0, 10)}
                    </td>
                    <td>
                      <span className={`badge ${b.isActive ? 'badge-success' : 'badge-error'}`}>
                        {b.isActive ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td>
                      <div className="flex-gap">
                        <button className="action-btn action-btn-secondary" onClick={() => handleToggleBanner(b.id)}>
                          {b.isActive ? 'Disable' : 'Enable'}
                        </button>
                        <button className="action-btn" onClick={() => handleOpenEditBanner(b)}>Edit</button>
                        <button className="action-btn action-btn-danger" onClick={() => handleDeleteBanner(b.id)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* CREATE/EDIT HERO MODAL */}
      {showHeroModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '650px' }}>
            <div className="modal-header">
              <h3>{editingHeroId ? 'Edit Hero Banner' : 'Create Hero Banner'}</h3>
              <button className="modal-close" onClick={() => setShowHeroModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveHeroBanner}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="grid-2">
                  <div className="form-group">
                    <label>Badge Text</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Trending, Popular, New"
                      className="form-control"
                      value={heroForm.badgeText}
                      onChange={(e) => setHeroForm(prev => ({ ...prev, badgeText: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>CTA Button Text</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Book Now, Explore"
                      className="form-control"
                      value={heroForm.ctaText}
                      onChange={(e) => setHeroForm(prev => ({ ...prev, ctaText: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Hero Campaign Title / Header</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Expert AC Service"
                    className="form-control"
                    value={heroForm.title}
                    onChange={(e) => setHeroForm(prev => ({ ...prev, title: e.target.value }))}
                  />
                </div>

                <div className="form-group">
                  <label>Pricing / Subtitle Label</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Starting from ₹299"
                    className="form-control"
                    value={heroForm.subtitle}
                    onChange={(e) => setHeroForm(prev => ({ ...prev, subtitle: e.target.value }))}
                  />
                </div>

                <div className="form-group">
                  <label>Remote Banner Background Image (16:9 recommended)</label>
                  <input
                    type="text"
                    required
                    placeholder="https://images.unsplash.com/..."
                    className="form-control"
                    value={heroForm.imageUrl}
                    onChange={(e) => setHeroForm(prev => ({ ...prev, imageUrl: e.target.value }))}
                  />
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Link to Specific Service Target</label>
                    <select 
                      className="form-control" 
                      value={heroForm.targetServiceId} 
                      onChange={(e) => setHeroForm(prev => ({ ...prev, targetServiceId: e.target.value }))}
                    >
                      <option value="">-- None / Static Display --</option>
                      {services.map(s => (
                        <option key={s.id} value={s.id}>{s.name} ({s.category})</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Display Order</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={heroForm.displayOrder}
                      onChange={(e) => setHeroForm(prev => ({ ...prev, displayOrder: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Start Date</label>
                    <input
                      type="date"
                      required
                      className="form-control"
                      value={heroForm.startDate}
                      onChange={(e) => setHeroForm(prev => ({ ...prev, startDate: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>End Date</label>
                    <input
                      type="date"
                      required
                      className="form-control"
                      value={heroForm.endDate}
                      onChange={(e) => setHeroForm(prev => ({ ...prev, endDate: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={heroForm.active}
                      onChange={(e) => setHeroForm(prev => ({ ...prev, active: e.target.checked }))}
                    />
                    Campaign is Active & Ready to Display
                  </label>
                </div>

                <div className="text-right" style={{ marginTop: '16px' }}>
                  <button type="button" className="action-btn action-btn-secondary" style={{ marginRight: '10px' }} onClick={() => setShowHeroModal(false)}>Cancel</button>
                  <button type="submit" className="action-btn">Publish Hero Campaign</button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CREATE/EDIT SPOTLIGHT BANNER MODAL */}
      {showBannerModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '650px' }}>
            <div className="modal-header">
              <h3>{editingBannerId ? 'Edit Spotlight Banner' : 'Create Spotlight Banner'}</h3>
              <button className="modal-close" onClick={() => setShowBannerModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveBanner}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                
                <div className="grid-2">
                  <div className="form-group">
                    <label>Badge Text</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Trending, Popular, New"
                      className="form-control"
                      value={bannerForm.badgeText}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, badgeText: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>CTA Button Text</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Book Now, Explore"
                      className="form-control"
                      value={bannerForm.ctaText}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, ctaText: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Banner Headline / Title</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Get your AC ready for summer"
                    className="form-control"
                    value={bannerForm.title}
                    onChange={(e) => setBannerForm(prev => ({ ...prev, title: e.target.value }))}
                  />
                </div>

                <div className="form-group">
                  <label>Sub-text / Category Label</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. AC Service, Electrical Services"
                    className="form-control"
                    value={bannerForm.subtitle}
                    onChange={(e) => setBannerForm(prev => ({ ...prev, subtitle: e.target.value }))}
                  />
                </div>

                <div className="form-group">
                  <label>Remote Banner Image URL (16:9 recommended)</label>
                  <input
                    type="text"
                    required
                    placeholder="https://images.unsplash.com/..."
                    className="form-control"
                    value={bannerForm.imageUrl}
                    onChange={(e) => setBannerForm(prev => ({ ...prev, imageUrl: e.target.value }))}
                  />
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Link to Category (Optional)</label>
                    <select 
                      className="form-control" 
                      value={bannerForm.categoryId} 
                      onChange={(e) => setBannerForm(prev => ({ ...prev, categoryId: e.target.value }))}
                    >
                      <option value="">-- None / Custom Link --</option>
                      {categories.map(c => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Link to Specific Service (Optional)</label>
                    <select 
                      className="form-control" 
                      value={bannerForm.serviceId} 
                      onChange={(e) => setBannerForm(prev => ({ ...prev, serviceId: e.target.value }))}
                    >
                      <option value="">-- None / Custom Link --</option>
                      {services.map(s => (
                        <option key={s.id} value={s.id}>{s.name} ({s.category})</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="grid-3" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                  <div className="form-group">
                    <label>Display Order</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={bannerForm.displayOrder}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, displayOrder: e.target.value }))}
                    />
                  </div>
                  <div className="form-group" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer', marginTop: '16px' }}>
                      <input
                        type="checkbox"
                        checked={bannerForm.autoSlide}
                        onChange={(e) => setBannerForm(prev => ({ ...prev, autoSlide: e.target.checked }))}
                      />
                      Enable Auto-Slide
                    </label>
                  </div>
                  <div className="form-group">
                    <label>Slide Duration (ms)</label>
                    <input
                      type="number"
                      disabled={!bannerForm.autoSlide}
                      className="form-control"
                      value={bannerForm.slideDuration}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, slideDuration: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Start Date</label>
                    <input
                      type="date"
                      required
                      className="form-control"
                      value={bannerForm.startDate}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, startDate: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>End Date</label>
                    <input
                      type="date"
                      required
                      className="form-control"
                      value={bannerForm.endDate}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, endDate: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={bannerForm.isActive}
                      onChange={(e) => setBannerForm(prev => ({ ...prev, isActive: e.target.checked }))}
                    />
                    Banner is Active (Display immediately if within date range)
                  </label>
                </div>

                <div className="text-right" style={{ marginTop: '16px' }}>
                  <button type="button" className="action-btn action-btn-secondary" style={{ marginRight: '10px' }} onClick={() => setShowBannerModal(false)}>Cancel</button>
                  <button type="submit" className="action-btn">Publish Banner</button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CREATE COUPON MODAL */}
      {showCouponModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>Create Coupon Offer</h3>
              <button className="modal-close" onClick={() => setShowCouponModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateCoupon}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="grid-2">
                  <div className="form-group">
                    <label>Coupon Code (Uppercase)</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. FLAT300"
                      className="form-control"
                      value={couponForm.code}
                      onChange={(e) => setCouponForm(prev => ({ ...prev, code: e.target.value.toUpperCase() }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>Discount Type</label>
                    <select className="form-control" value={couponForm.discountType} onChange={(e) => setCouponForm(prev => ({ ...prev, discountType: e.target.value }))}>
                      <option value="Fixed">Fixed Amount Discount (₹)</option>
                      <option value="Percentage">Percentage Discount (%)</option>
                    </select>
                  </div>
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Discount Value</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={couponForm.discountValue}
                      onChange={(e) => setCouponForm(prev => ({ ...prev, discountValue: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>Min Booking Amount (₹)</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={couponForm.minBookingAmount}
                      onChange={(e) => setCouponForm(prev => ({ ...prev, minBookingAmount: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Max Discount (₹) [For % Type]</label>
                    <input
                      type="number"
                      className="form-control"
                      value={couponForm.maxDiscount}
                      onChange={(e) => setCouponForm(prev => ({ ...prev, maxDiscount: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>Total Usage Limit</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={couponForm.usageLimit}
                      onChange={(e) => setCouponForm(prev => ({ ...prev, usageLimit: e.target.value }))}
                    />
                  </div>
                </div>

                <div className="grid-2">
                  <div className="form-group">
                    <label>Usage Limit Per User</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={couponForm.userLimit}
                      onChange={(e) => setCouponForm(prev => ({ ...prev, userLimit: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label>Applicable Audience</label>
                    <select className="form-control" value={couponForm.targetAudience} onChange={(e) => setCouponForm(prev => ({ ...prev, targetAudience: e.target.value }))}>
                      <option value="Everyone">All Users</option>
                      <option value="New Customers Only">New Customers Only</option>
                      <option value="Premium Clients">Premium Tier Clients</option>
                    </select>
                  </div>
                </div>

                <div className="text-right" style={{ marginTop: '16px' }}>
                  <button type="button" className="action-btn action-btn-secondary" style={{ marginRight: '10px' }} onClick={() => setShowCouponModal(false)}>Cancel</button>
                  <button type="submit" className="action-btn">Publish Coupon</button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
