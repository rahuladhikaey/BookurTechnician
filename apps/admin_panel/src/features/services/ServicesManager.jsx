import React, { useState } from 'react';

const INITIAL_POPULAR_SERVICES = [
  { id: 'pop_1', name: 'AC Deep Cleaning & Jet Pump', category: 'AC Service', displayOrder: 1, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500', bookingsCount: 1420 },
  { id: 'pop_2', name: 'Laptop Hardware & Screen Repair', category: 'Laptop Service', displayOrder: 2, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', bookingsCount: 980 },
  { id: 'pop_3', name: 'Ceiling Fan Installation & Repair', category: 'Fan Service', displayOrder: 3, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500', bookingsCount: 840 },
  { id: 'pop_4', name: 'Refrigerator Coolant & Thermostat', category: 'Refrigerator Service', displayOrder: 4, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500', bookingsCount: 650 },
  { id: 'pop_5', name: 'Washing Machine Installation', category: 'Washing Machine Service', displayOrder: 5, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500', bookingsCount: 520 }
];

const INITIAL_BRANDS = [
  { id: 'br_1', name: 'Daikin', category: 'AC Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Daikin_logo.svg/320px-Daikin_logo.svg.png', displayOrder: 1, status: 'Active' },
  { id: 'br_2', name: 'Voltas', category: 'AC Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Voltas_logo.svg/320px-Voltas_logo.svg.png', displayOrder: 2, status: 'Active' },
  { id: 'br_3', name: 'LG Electronics', category: 'Refrigerator Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/LG_logo_%282015%29.svg/320px-LG_logo_%282015%29.svg.png', displayOrder: 3, status: 'Active' },
  { id: 'br_4', name: 'Samsung', category: 'Washing Machine Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Samsung_Logo.svg/320px-Samsung_Logo.svg.png', displayOrder: 4, status: 'Active' },
  { id: 'br_5', name: 'Dell', category: 'Laptop Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Dell_logo_2016.svg/320px-Dell_logo_2016.svg.png', displayOrder: 5, status: 'Active' },
  { id: 'br_6', name: 'HP', category: 'Laptop Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/HP_logo_2012.svg/320px-HP_logo_2012.svg.png', displayOrder: 6, status: 'Active' },
  { id: 'br_7', name: 'Havells', category: 'Fan Service', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Havells_Logo.svg/320px-Havells_Logo.svg.png', displayOrder: 7, status: 'Active' }
];

const INITIAL_SERVICE_IMAGES = [
  { id: 'img_1', title: 'AC Filter Jet Wash', category: 'AC Service', url: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500', resolution: '1200x800', tags: 'indoor, jet pump, filter' },
  { id: 'img_2', title: 'Motherboard IC Diagnostics', category: 'Laptop Service', url: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', resolution: '1200x800', tags: 'pcb, chip, soldering' },
  { id: 'img_3', title: 'High-speed Fan Motor Check', category: 'Fan Service', url: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500', resolution: '1200x800', tags: 'bearing, coil, copper' },
  { id: 'img_4', title: 'Compressor Gas Level Gauge', category: 'Refrigerator Service', url: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500', resolution: '1200x800', tags: 'gas, freon, pressure' }
];

export default function ServicesManager({ categories, setCategories, services, setServices, auditLogAction, subTab = 'categories' }) {
  const [activeTab, setActiveTab] = useState(subTab);
  
  // Popular Services & Brands State
  const [popularServices, setPopularServices] = useState(INITIAL_POPULAR_SERVICES);
  const [brands, setBrands] = useState(INITIAL_BRANDS);
  const [serviceImages, setServiceImages] = useState(INITIAL_SERVICE_IMAGES);

  // Modals & Form State
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [editingCategory, setEditingCategory] = useState(null);
  const [categoryForm, setCategoryForm] = useState({ name: '', imageUrl: '', isActive: true });

  const [showServiceModal, setShowServiceModal] = useState(false);
  const [editingService, setEditingService] = useState(null);
  const [serviceForm, setServiceForm] = useState({
    name: '',
    imageUrl: '',
    category: '',
    description: '',
    price: 499,
    originalPrice: 699,
    durationMinutes: 45,
    isActive: true,
    rating: 4.8,
    inclusions: 'Professional tool verification\nPost-job cleanliness\nStandard 30-day warranty',
    exclusions: 'Heavy structural repairs\nExternal replacement parts (billed extra)'
  });

  const [showPopularModal, setShowPopularModal] = useState(false);
  const [editingPopular, setEditingPopular] = useState(null);
  const [popularForm, setPopularForm] = useState({
    name: '',
    category: 'AC Service',
    imageUrl: '',
    displayOrder: 1,
    isActive: true
  });

  const [showBrandModal, setShowBrandModal] = useState(false);
  const [editingBrand, setEditingBrand] = useState(null);
  const [brandForm, setBrandForm] = useState({
    name: '',
    category: 'AC Service',
    logoUrl: '',
    displayOrder: 1,
    status: 'Active'
  });

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCategory, setFilterCategory] = useState('ALL');

  // ─── CATEGORIES HANDLERS ───
  const openCategoryModal = (cat = null) => {
    if (cat) {
      setEditingCategory(cat.id);
      setCategoryForm({ name: cat.name, imageUrl: cat.imageUrl, isActive: cat.isActive !== false });
    } else {
      setEditingCategory(null);
      setCategoryForm({ name: '', imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500', isActive: true });
    }
    setShowCategoryModal(true);
  };

  const handleSaveCategory = (e) => {
    e.preventDefault();
    if (editingCategory) {
      setCategories(prev => prev.map(c => c.id === editingCategory ? { ...c, ...categoryForm } : c));
      auditLogAction?.('Services', `Updated category "${categoryForm.name}"`);
    } else {
      const newCat = {
        id: `cat_${Date.now()}`,
        name: categoryForm.name,
        imageUrl: categoryForm.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
        isActive: categoryForm.isActive
      };
      setCategories(prev => [...prev, newCat]);
      auditLogAction?.('Services', `Created new category "${newCat.name}"`);
    }
    setShowCategoryModal(false);
  };

  const handleDeleteCategory = (id, name) => {
    if (window.confirm(`Are you sure you want to delete category "${name}"?`)) {
      setCategories(prev => prev.filter(c => c.id !== id));
      auditLogAction?.('Services', `Deleted category "${name}"`);
    }
  };

  // ─── SERVICES HANDLERS ───
  const openServiceModal = (srv = null) => {
    if (srv) {
      setEditingService(srv.id);
      setServiceForm({
        name: srv.name,
        imageUrl: srv.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
        category: srv.category,
        description: srv.description || '',
        price: srv.price,
        originalPrice: srv.originalPrice || Math.round(srv.price * 1.3),
        durationMinutes: srv.durationMinutes || 45,
        isActive: srv.isActive !== false,
        rating: srv.rating || 4.8,
        inclusions: Array.isArray(srv.inclusions) ? srv.inclusions.join('\n') : (srv.inclusions || ''),
        exclusions: Array.isArray(srv.exclusions) ? srv.exclusions.join('\n') : (srv.exclusions || '')
      });
    } else {
      setEditingService(null);
      setServiceForm({
        name: '',
        imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
        category: categories[0]?.name || 'AC Service',
        description: '',
        price: 499,
        originalPrice: 699,
        durationMinutes: 45,
        isActive: true,
        rating: 4.8,
        inclusions: 'Professional tool verification\nPost-job cleanliness\nStandard 30-day warranty',
        exclusions: 'Heavy structural repairs\nExternal replacement parts (billed extra)'
      });
    }
    setShowServiceModal(true);
  };

  const handleSaveService = (e) => {
    e.preventDefault();
    const payload = {
      name: serviceForm.name,
      imageUrl: serviceForm.imageUrl,
      category: serviceForm.category,
      description: serviceForm.description,
      price: Number(serviceForm.price),
      originalPrice: Number(serviceForm.originalPrice),
      durationMinutes: Number(serviceForm.durationMinutes),
      isActive: serviceForm.isActive,
      rating: Number(serviceForm.rating) || 4.8,
      inclusions: serviceForm.inclusions.split('\n').filter(x => x.trim()),
      exclusions: serviceForm.exclusions.split('\n').filter(x => x.trim())
    };

    if (editingService) {
      setServices(prev => prev.map(s => s.id === editingService ? { ...s, ...payload } : s));
      auditLogAction?.('Services', `Updated service "${payload.name}"`);
    } else {
      const newSrv = { id: `srv_${Date.now()}`, ...payload };
      setServices(prev => [...prev, newSrv]);
      auditLogAction?.('Services', `Added new service "${newSrv.name}"`);
    }
    setShowServiceModal(false);
  };

  const handleDeleteService = (id, name) => {
    if (window.confirm(`Are you sure you want to delete service "${name}"?`)) {
      setServices(prev => prev.filter(s => s.id !== id));
      auditLogAction?.('Services', `Deleted service "${name}"`);
    }
  };

  // ─── POPULAR SERVICES HANDLERS ───
  const openPopularModal = (pop = null) => {
    if (pop) {
      setEditingPopular(pop.id);
      setPopularForm({
        name: pop.name,
        category: pop.category,
        imageUrl: pop.imageUrl,
        displayOrder: pop.displayOrder,
        isActive: pop.isActive !== false
      });
    } else {
      setEditingPopular(null);
      setPopularForm({
        name: '',
        category: categories[0]?.name || 'AC Service',
        imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
        displayOrder: popularServices.length + 1,
        isActive: true
      });
    }
    setShowPopularModal(true);
  };

  const handleSavePopular = (e) => {
    e.preventDefault();
    if (editingPopular) {
      setPopularServices(prev => prev.map(p => p.id === editingPopular ? { ...p, ...popularForm, displayOrder: Number(popularForm.displayOrder) } : p));
      auditLogAction?.('Services', `Updated popular service "${popularForm.name}"`);
    } else {
      const newPop = {
        id: `pop_${Date.now()}`,
        name: popularForm.name,
        category: popularForm.category,
        imageUrl: popularForm.imageUrl,
        displayOrder: Number(popularForm.displayOrder),
        isActive: popularForm.isActive,
        bookingsCount: 0
      };
      setPopularServices(prev => [...prev, newPop]);
      auditLogAction?.('Services', `Added popular service "${newPop.name}"`);
    }
    setShowPopularModal(false);
  };

  const handleTogglePopularStatus = (id) => {
    setPopularServices(prev => prev.map(p => p.id === id ? { ...p, isActive: !p.isActive } : p));
  };

  const handleDeletePopular = (id) => {
    if (window.confirm("Remove this popular service highlight?")) {
      setPopularServices(prev => prev.filter(p => p.id !== id));
      auditLogAction?.('Services', `Removed popular service ID ${id}`);
    }
  };

  // ─── BRANDS HANDLERS ───
  const openBrandModal = (br = null) => {
    if (br) {
      setEditingBrand(br.id);
      setBrandForm({
        name: br.name,
        category: br.category,
        logoUrl: br.logoUrl,
        displayOrder: br.displayOrder,
        status: br.status
      });
    } else {
      setEditingBrand(null);
      setBrandForm({
        name: '',
        category: categories[0]?.name || 'AC Service',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Daikin_logo.svg/320px-Daikin_logo.svg.png',
        displayOrder: brands.length + 1,
        status: 'Active'
      });
    }
    setShowBrandModal(true);
  };

  const handleSaveBrand = (e) => {
    e.preventDefault();
    if (editingBrand) {
      setBrands(prev => prev.map(b => b.id === editingBrand ? { ...b, ...brandForm, displayOrder: Number(brandForm.displayOrder) } : b));
      auditLogAction?.('Services', `Updated brand "${brandForm.name}"`);
    } else {
      const newBrand = {
        id: `br_${Date.now()}`,
        name: brandForm.name,
        category: brandForm.category,
        logoUrl: brandForm.logoUrl,
        displayOrder: Number(brandForm.displayOrder),
        status: brandForm.status
      };
      setBrands(prev => [...prev, newBrand]);
      auditLogAction?.('Services', `Created brand "${newBrand.name}"`);
    }
    setShowBrandModal(false);
  };

  const handleDeleteBrand = (id, name) => {
    if (window.confirm(`Delete brand "${name}"?`)) {
      setBrands(prev => prev.filter(b => b.id !== id));
      auditLogAction?.('Services', `Deleted brand "${name}"`);
    }
  };

  // Filtered Services List
  const filteredServices = services.filter(s => {
    const matchesSearch = s.name.toLowerCase().includes(searchQuery.toLowerCase()) || s.category.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCat = filterCategory === 'ALL' || s.category === filterCategory;
    return matchesSearch && matchesCat;
  });

  return (
    <div className="services-manager-view">
      {/* ─── FLAT TABS NAVIGATION (5 TABS) ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${activeTab === 'categories' ? 'active' : ''}`} onClick={() => setActiveTab('categories')}>
          📂 Categories ({categories.length})
        </div>
        <div className={`flat-tab ${activeTab === 'services' ? 'active' : ''}`} onClick={() => setActiveTab('services')}>
          🛠️ Services Catalog ({services.length})
        </div>
        <div className={`flat-tab ${activeTab === 'popular' ? 'active' : ''}`} onClick={() => setActiveTab('popular')}>
          ⭐ Popular Services ({popularServices.length})
        </div>
        <div className={`flat-tab ${activeTab === 'images' ? 'active' : ''}`} onClick={() => setActiveTab('images')}>
          🖼️ Service Images ({serviceImages.length})
        </div>
        <div className={`flat-tab ${activeTab === 'brands' ? 'active' : ''}`} onClick={() => setActiveTab('brands')}>
          🏷️ Brands Management ({brands.length})
        </div>
      </div>

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 1: CATEGORIES
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'categories' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Service Categories</h2>
              <p className="page-subtitle">Configure root service verticals for mobile customer apps</p>
            </div>
            <button className="btn btn-primary" onClick={() => openCategoryModal()}>
              + Add Category
            </button>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>Thumbnail</th>
                  <th>Category Name</th>
                  <th>Total Services</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {categories.map(cat => {
                  const count = services.filter(s => s.category === cat.name).length;
                  return (
                    <tr key={cat.id}>
                      <td>
                        <img src={cat.imageUrl} alt={cat.name} className="table-img-thumb" />
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)', fontSize: '14px' }}>{cat.name}</strong>
                      </td>
                      <td>{count} active services</td>
                      <td>
                        <span className={`badge ${cat.isActive !== false ? 'badge-completed' : 'badge-cancelled'}`}>
                          {cat.isActive !== false ? 'Active' : 'Disabled'}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                          <button className="btn btn-outline btn-sm" onClick={() => openCategoryModal(cat)}>Edit</button>
                          <button className="btn btn-danger btn-sm" onClick={() => handleDeleteCategory(cat.id, cat.name)}>Delete</button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 2: SERVICES
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'services' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Services Catalog</h2>
              <p className="page-subtitle">Configure individual service rates, inclusions, and durations</p>
            </div>
            <button className="btn btn-primary" onClick={() => openServiceModal()}>
              + Add Service
            </button>
          </div>

          <div className="toolbar-row">
            <div className="toolbar-left">
              <div className="search-input-box header-search">
                <input
                  type="text"
                  placeholder="Search services..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                />
              </div>
              <select className="filter-select" value={filterCategory} onChange={e => setFilterCategory(e.target.value)}>
                <option value="ALL">All Categories</option>
                {categories.map(c => <option key={c.id} value={c.name}>{c.name}</option>)}
              </select>
            </div>
            <div className="toolbar-right">
              <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                Showing {filteredServices.length} of {services.length} services
              </span>
            </div>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th style={{ width: '70px' }}>Image</th>
                  <th>Service Name</th>
                  <th>Category</th>
                  <th>Customer Price</th>
                  <th>Original Price</th>
                  <th>Duration</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredServices.map(srv => (
                  <tr key={srv.id}>
                    <td>
                      <img src={srv.imageUrl} alt={srv.name} className="table-img-thumb" />
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)' }}>{srv.name}</strong>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                        ⭐ {srv.rating || 4.8} ({srv.reviewsCount || 40} reviews)
                      </div>
                    </td>
                    <td>
                      <span className="badge badge-info">{srv.category}</span>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--primary)' }}>₹{srv.price}</strong>
                    </td>
                    <td>
                      <span style={{ textDecoration: 'line-through', color: 'var(--text-muted)' }}>₹{srv.originalPrice || srv.price}</span>
                    </td>
                    <td>{srv.durationMinutes || 45} mins</td>
                    <td>
                      <span className={`badge ${srv.isActive !== false ? 'badge-completed' : 'badge-cancelled'}`}>
                        {srv.isActive !== false ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => openServiceModal(srv)}>Edit</button>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeleteService(srv.id, srv.name)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 3: POPULAR SERVICES
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'popular' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Popular Services Management</h2>
              <p className="page-subtitle">Feature top performing services on mobile home page highlight carousels</p>
            </div>
            <button className="btn btn-primary" onClick={() => openPopularModal()}>
              + Add Popular Service
            </button>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>Order</th>
                  <th style={{ width: '70px' }}>Thumbnail</th>
                  <th>Service Name</th>
                  <th>Category</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {popularServices.map(pop => (
                  <tr key={pop.id}>
                    <td>
                      <span className="badge badge-info" style={{ fontWeight: '700' }}>#{pop.displayOrder}</span>
                    </td>
                    <td>
                      <img src={pop.imageUrl} alt={pop.name} className="table-img-thumb" />
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)' }}>{pop.name}</strong>
                    </td>
                    <td>
                      <span className="badge badge-info">{pop.category}</span>
                    </td>
                    <td>
                      <span className={`badge ${pop.isActive ? 'badge-completed' : 'badge-cancelled'}`}>
                        {pop.isActive ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => handleTogglePopularStatus(pop.id)}>
                          {pop.isActive ? 'Disable' : 'Enable'}
                        </button>
                        <button className="btn btn-secondary btn-sm" onClick={() => openPopularModal(pop)}>Edit</button>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeletePopular(pop.id)}>Remove</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 4: SERVICE IMAGES
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'images' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Service Image Asset Repository</h2>
              <p className="page-subtitle">Central flat gallery for high-resolution app and category icons</p>
            </div>
            <button className="btn btn-primary" onClick={() => alert('Flat file upload simulation: Image uploaded to CDN asset bucket!')}>
              + Upload Image
            </button>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>Preview</th>
                  <th>Image Title</th>
                  <th>Category</th>
                  <th>Resolution</th>
                  <th>Tags</th>
                  <th style={{ textAlign: 'right' }}>Action</th>
                </tr>
              </thead>
              <tbody>
                {serviceImages.map(img => (
                  <tr key={img.id}>
                    <td>
                      <img src={img.url} alt={img.title} className="table-img-thumb" style={{ width: '56px', height: '56px' }} />
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)' }}>{img.title}</strong>
                    </td>
                    <td>
                      <span className="badge badge-info">{img.category}</span>
                    </td>
                    <td>{img.resolution}</td>
                    <td>
                      <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{img.tags}</span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button className="btn btn-outline btn-sm" onClick={() => navigator.clipboard.writeText(img.url).then(() => alert('Image URL copied to clipboard!'))}>
                        Copy URL
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 5: BRANDS MANAGEMENT
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'brands' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Authorized Brand Management</h2>
              <p className="page-subtitle">Manage supported appliance manufacturers and display orders</p>
            </div>
            <button className="btn btn-primary" onClick={() => openBrandModal()}>
              + Add Brand
            </button>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>Order</th>
                  <th style={{ width: '80px' }}>Brand Logo</th>
                  <th>Brand Name</th>
                  <th>Service Category</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {brands.map(brand => (
                  <tr key={brand.id}>
                    <td>
                      <span className="badge badge-info" style={{ fontWeight: '700' }}>#{brand.displayOrder}</span>
                    </td>
                    <td>
                      <div className="brand-logo-container">
                        <img src={brand.logoUrl} alt={brand.name} />
                      </div>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)', fontSize: '14px' }}>{brand.name}</strong>
                    </td>
                    <td>
                      <span className="badge badge-info">{brand.category}</span>
                    </td>
                    <td>
                      <span className={`badge ${brand.status === 'Active' ? 'badge-completed' : 'badge-cancelled'}`}>
                        {brand.status}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => openBrandModal(brand)}>Edit</button>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeleteBrand(brand.id, brand.name)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          MODALS (FLAT 2D)
         ════════════════════════════════════════════════════════════════════════ */}

      {/* Category Modal */}
      {showCategoryModal && (
        <div className="modal-overlay" onClick={() => setShowCategoryModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingCategory ? 'Edit Category' : 'Add New Category'}</h3>
              <button className="modal-close-btn" onClick={() => setShowCategoryModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveCategory}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Category Name</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. AC Service"
                    value={categoryForm.name}
                    onChange={e => setCategoryForm({ ...categoryForm, name: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Image Thumbnail URL</label>
                  <input
                    type="url"
                    required
                    className="form-control"
                    placeholder="https://..."
                    value={categoryForm.imageUrl}
                    onChange={e => setCategoryForm({ ...categoryForm, imageUrl: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Category Status</label>
                  <select
                    className="form-control"
                    value={categoryForm.isActive ? 'true' : 'false'}
                    onChange={e => setCategoryForm({ ...categoryForm, isActive: e.target.value === 'true' })}
                  >
                    <option value="true">Active</option>
                    <option value="false">Disabled</option>
                  </select>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowCategoryModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Category</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Service Modal */}
      {showServiceModal && (
        <div className="modal-overlay" onClick={() => setShowServiceModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '640px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingService ? 'Edit Service' : 'Add New Service'}</h3>
              <button className="modal-close-btn" onClick={() => setShowServiceModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveService}>
              <div className="modal-body">
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Service Title</label>
                    <input
                      type="text"
                      required
                      className="form-control"
                      placeholder="e.g. AC Deep Cleaning"
                      value={serviceForm.name}
                      onChange={e => setServiceForm({ ...serviceForm, name: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Category</label>
                    <select
                      className="form-control"
                      value={serviceForm.category}
                      onChange={e => setServiceForm({ ...serviceForm, category: e.target.value })}
                    >
                      {categories.map(c => <option key={c.id} value={c.name}>{c.name}</option>)}
                    </select>
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Selling Price (₹)</label>
                    <input
                      type="number"
                      required
                      className="form-control"
                      value={serviceForm.price}
                      onChange={e => setServiceForm({ ...serviceForm, price: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Original Price (₹)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={serviceForm.originalPrice}
                      onChange={e => setServiceForm({ ...serviceForm, originalPrice: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Duration (Mins)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={serviceForm.durationMinutes}
                      onChange={e => setServiceForm({ ...serviceForm, durationMinutes: e.target.value })}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Image URL</label>
                  <input
                    type="url"
                    required
                    className="form-control"
                    value={serviceForm.imageUrl}
                    onChange={e => setServiceForm({ ...serviceForm, imageUrl: e.target.value })}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Inclusions (One per line)</label>
                  <textarea
                    className="form-control"
                    rows="3"
                    value={serviceForm.inclusions}
                    onChange={e => setServiceForm({ ...serviceForm, inclusions: e.target.value })}
                  ></textarea>
                </div>

                <div className="form-group">
                  <label className="form-label">Exclusions (One per line)</label>
                  <textarea
                    className="form-control"
                    rows="2"
                    value={serviceForm.exclusions}
                    onChange={e => setServiceForm({ ...serviceForm, exclusions: e.target.value })}
                  ></textarea>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowServiceModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Service</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Popular Service Modal */}
      {showPopularModal && (
        <div className="modal-overlay" onClick={() => setShowPopularModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingPopular ? 'Edit Popular Service' : 'Add Popular Service'}</h3>
              <button className="modal-close-btn" onClick={() => setShowPopularModal(false)}>×</button>
            </div>
            <form onSubmit={handleSavePopular}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Service Title</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. AC Deep Cleaning"
                    value={popularForm.name}
                    onChange={e => setPopularForm({ ...popularForm, name: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Category</label>
                  <select
                    className="form-control"
                    value={popularForm.category}
                    onChange={e => setPopularForm({ ...popularForm, category: e.target.value })}
                  >
                    {categories.map(c => <option key={c.id} value={c.name}>{c.name}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Display Order</label>
                    <input
                      type="number"
                      required
                      min="1"
                      className="form-control"
                      value={popularForm.displayOrder}
                      onChange={e => setPopularForm({ ...popularForm, displayOrder: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Thumbnail URL</label>
                    <input
                      type="url"
                      required
                      className="form-control"
                      value={popularForm.imageUrl}
                      onChange={e => setPopularForm({ ...popularForm, imageUrl: e.target.value })}
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowPopularModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Popular Highlight</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Brand Modal */}
      {showBrandModal && (
        <div className="modal-overlay" onClick={() => setShowBrandModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingBrand ? 'Edit Brand' : 'Add Brand'}</h3>
              <button className="modal-close-btn" onClick={() => setShowBrandModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveBrand}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Brand Name</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Daikin, Voltas, Samsung"
                    value={brandForm.name}
                    onChange={e => setBrandForm({ ...brandForm, name: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Service Category</label>
                  <select
                    className="form-control"
                    value={brandForm.category}
                    onChange={e => setBrandForm({ ...brandForm, category: e.target.value })}
                  >
                    {categories.map(c => <option key={c.id} value={c.name}>{c.name}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Logo URL</label>
                    <input
                      type="url"
                      required
                      className="form-control"
                      value={brandForm.logoUrl}
                      onChange={e => setBrandForm({ ...brandForm, logoUrl: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Display Order</label>
                    <input
                      type="number"
                      required
                      min="1"
                      className="form-control"
                      value={brandForm.displayOrder}
                      onChange={e => setBrandForm({ ...brandForm, displayOrder: e.target.value })}
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowBrandModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Brand</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
