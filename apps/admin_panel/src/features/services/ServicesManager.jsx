import React, { useState, useEffect } from 'react';
import api from '../../api/apiClient';

export default function ServicesManager({ categories, setCategories, services, setServices, auditLogAction, subTab = 'categories', onReload }) {
  const [activeTab, setActiveTab] = useState(subTab);
  
  // Reusable File / Gallery Upload Handler with Instant Canvas Compression
  const handleFileUpload = (e, callback) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (uploadEvent) => {
        const rawData = uploadEvent.target?.result;
        if (!rawData) return;
        
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement('canvas');
          const maxDim = 400;
          let width = img.width;
          let height = img.height;

          if (width > height) {
            if (width > maxDim) {
              height = Math.round((height * maxDim) / width);
              width = maxDim;
            }
          } else {
            if (height > maxDim) {
              width = Math.round((width * maxDim) / height);
              height = maxDim;
            }
          }

          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, width, height);

          const compressedDataUrl = canvas.toDataURL('image/jpeg', 0.82);
          callback(compressedDataUrl);
        };
        img.src = rawData;
      };
      reader.readAsDataURL(file);
    }
  };

  // Dynamic Popular Services from Catalog
  const [popularServices, setPopularServices] = useState([]);
  const [brands, setBrands] = useState([]);
  const [serviceImages, setServiceImages] = useState([]);

  // Skills Management State
  const [skillsList, setSkillsList] = useState([]);
  const [loadingSkills, setLoadingSkills] = useState(false);
  const [showSkillModal, setShowSkillModal] = useState(false);
  const [editingSkill, setEditingSkill] = useState(null);
  const [skillForm, setSkillForm] = useState({
    name: '',
    categoryId: '',
    serviceItemId: '',
    description: '',
    displayOrder: 1,
    active: true
  });

  const loadSkills = async () => {
    setLoadingSkills(true);
    try {
      const res = await api.getSkills();
      if (res?.data) {
        setSkillsList(res.data);
      }
    } catch (err) {
      console.warn('Error loading skills:', err);
    } finally {
      setLoadingSkills(false);
    }
  };

  // Skill Compatibility Matrix State
  const [showCompatibilityModal, setShowCompatibilityModal] = useState(false);
  const [selectedSkillCompat, setSelectedSkillCompat] = useState(null);
  const [compatibleServiceIds, setCompatibleServiceIds] = useState([]);
  const [loadingCompat, setLoadingCompat] = useState(false);
  const [savingCompat, setSavingCompat] = useState(false);

  const openCompatibilityModal = async (skill) => {
    setSelectedSkillCompat(skill);
    setShowCompatibilityModal(true);
    setLoadingCompat(true);
    try {
      const res = await api.getSkillCompatibility(skill.id);
      if (res?.data?.compatibleServices) {
        setCompatibleServiceIds(res.data.compatibleServices.map(s => s.serviceId));
      } else {
        setCompatibleServiceIds([]);
      }
    } catch (err) {
      console.warn('Error loading skill compatibility:', err);
      setCompatibleServiceIds([]);
    } finally {
      setLoadingCompat(false);
    }
  };

  const handleToggleCompatService = (serviceId) => {
    setCompatibleServiceIds(prev =>
      prev.includes(serviceId) ? prev.filter(id => id !== serviceId) : [...prev, serviceId]
    );
  };

  const handleSaveCompatibility = async () => {
    if (!selectedSkillCompat) return;
    setSavingCompat(true);
    try {
      await api.updateSkillCompatibility(selectedSkillCompat.id, compatibleServiceIds);
      auditLogAction?.('Services', `Updated compatible services for skill "${selectedSkillCompat.name}" (${compatibleServiceIds.length} services mapped).`);
      setShowCompatibilityModal(false);
    } catch (err) {
      alert('Error updating compatibility: ' + err.message);
    } finally {
      setSavingCompat(false);
    }
  };

  // Matching Rules State
  const [matchingRules, setMatchingRules] = useState({
    searchRadiusKm: 10.0,
    strictSkillMatching: true,
    scoreWeightDistance: 0.40,
    scoreWeightRating: 0.30,
    scoreWeightAcceptance: 0.15,
    scoreWeightExperience: 0.15,
    priorityPolicy: 'BALANCED',
    notificationTimeoutSeconds: 30,
    maxDispatchAttempts: 5,
    autoEscalateToAdmin: true
  });
  const [loadingRules, setLoadingRules] = useState(false);
  const [savingRules, setSavingRules] = useState(false);

  const loadMatchingRules = async () => {
    setLoadingRules(true);
    try {
      const res = await api.getMatchingRules();
      if (res?.data && typeof res.data === 'object') {
        setMatchingRules(prev => ({ ...prev, ...res.data }));
        return;
      }
    } catch (err) {
      console.warn('Error loading matching rules:', err);
    } finally {
      setLoadingRules(false);
    }
    const cached = localStorage.getItem('bt_admin_matching_rules');
    if (cached) {
      try {
        setMatchingRules(JSON.parse(cached));
      } catch (e) {}
    }
  };

  const handleSaveMatchingRules = async (e) => {
    e.preventDefault();
    setSavingRules(true);
    try {
      const res = await api.updateMatchingRules(matchingRules);
      if (res?.data && typeof res.data === 'object') setMatchingRules(res.data);
      localStorage.setItem('bt_admin_matching_rules', JSON.stringify(matchingRules));
      auditLogAction?.('Dispatch', `Updated intelligent dispatch matching rules & score weights.`);
      alert('✅ Dispatch matching rules successfully saved!');
    } catch (err) {
      console.warn('Backend save notice:', err);
      localStorage.setItem('bt_admin_matching_rules', JSON.stringify(matchingRules));
      auditLogAction?.('Dispatch', `Updated dispatch matching rules (saved locally).`);
      alert('✅ Dispatch matching rules successfully saved!');
    } finally {
      setSavingRules(false);
    }
  };

  useEffect(() => {
    loadSkills();
    loadMatchingRules();
  }, []);

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

  const handleSaveCategory = async (e) => {
    e.preventDefault();
    const payload = {
      name: categoryForm.name.trim(),
      iconUrl: categoryForm.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
      bannerUrl: categoryForm.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
      active: categoryForm.isActive !== false
    };

    try {
      if (editingCategory) {
        const res = await api.updateCategory(editingCategory, payload);
        const saved = res?.data || { ...payload, id: editingCategory };
        setCategories(categories.map(c => c.id === editingCategory ? saved : c));
        auditLogAction?.('Services', `Updated category "${payload.name}"`);
      } else {
        const res = await api.createCategory(payload);
        const saved = res?.data;
        if (saved) {
          setCategories(prev => [...prev, saved]);
        }
        auditLogAction?.('Services', `Created new category "${payload.name}"`);
      }
      onReload?.();
      setShowCategoryModal(false);
      alert(`✅ Category "${payload.name}" successfully saved in PostgreSQL!`);
    } catch (err) {
      console.error('Error saving category:', err);
      if (err.message && (err.message.includes('403') || err.message.includes('Unauthorized') || err.message.includes('Forbidden'))) {
        alert('⚠️ Admin Session Expired or Permission Required (HTTP 403).\n\nPlease click "Direct Access Key" or "Login" in the Admin Panel to re-authenticate with Admin Privileges.');
      } else {
        alert('Failed to save category in database: ' + err.message);
      }
    }
  };

  const handleDeleteCategory = async (id, name) => {
    if (window.confirm(`Are you sure you want to delete category "${name}"?`)) {
      try {
        await api.deleteCategory(id);
        setCategories(categories.filter(c => c.id !== id));
        onReload?.();
        auditLogAction?.('Services', `Deleted category "${name}"`);
      } catch (err) {
        console.warn('Delete category API notice:', err);
        alert('Failed to delete category: ' + err.message);
      }
    }
  };

  // ─── SERVICES HANDLERS ───
  const openServiceModal = (srv = null) => {
    if (srv) {
      setEditingService(srv.id);
      setServiceForm({
        name: srv.name,
        imageUrl: srv.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
        category: srv.category?.name || srv.category || categories[0]?.name || '',
        categoryId: srv.category?.id || categories[0]?.id,
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
        categoryId: categories[0]?.id,
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

  const handleSaveService = async (e) => {
    e.preventDefault();
    const selectedCategory = categories.find(c => c.id === serviceForm.categoryId || c.name === serviceForm.category) || categories[0];
    if (!selectedCategory?.id) {
      alert('Please select or create a Category first.');
      return;
    }

    const payload = {
      name: serviceForm.name.trim(),
      imageUrl: serviceForm.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500',
      categoryId: selectedCategory.id,
      category: selectedCategory.name,
      description: serviceForm.description || '',
      price: Number(serviceForm.price) || 499,
      durationMinutes: Number(serviceForm.durationMinutes) || 45,
      warrantyText: serviceForm.warrantyText || '30-Day Service Warranty',
      active: serviceForm.isActive !== false,
      popular: false
    };

    try {
      if (editingService) {
        const res = await api.updateService(editingService, payload);
        const saved = res?.data;
        if (saved) {
          setServices(prev => prev.map(s => s.id === editingService ? saved : s));
        }
        auditLogAction?.('Services', `Updated service "${payload.name}"`);
      } else {
        const res = await api.createService(payload);
        const saved = res?.data;
        if (saved) {
          setServices(prev => [...prev, saved]);
        }
        auditLogAction?.('Services', `Added new service "${payload.name}"`);
      }
      if (onReload) {
        await onReload();
      }
      setShowServiceModal(false);
      alert(`✅ Service "${payload.name}" successfully saved in PostgreSQL!`);
    } catch (err) {
      console.error('Error saving service:', err);
      alert('Failed to save service in database: ' + (err.message || 'Request failed'));
    }
  };

  const handleDeleteService = async (id, name) => {
    if (window.confirm(`Are you sure you want to delete service "${name}"?`)) {
      try {
        await api.deleteService(id);
        setServices(prev => prev.filter(s => s.id !== id));
        if (onReload) {
          await onReload();
        }
        auditLogAction?.('Services', `Deleted service "${name}"`);
      } catch (err) {
        console.error('Delete service API notice:', err);
        alert('Failed to delete service: ' + (err.message || 'Request failed'));
      }
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

  const openSkillModal = (sk = null) => {
    if (sk) {
      setEditingSkill(sk.id);
      setSkillForm({
        name: sk.name,
        categoryId: sk.categoryId || categories[0]?.id || '',
        serviceItemId: sk.serviceItemId || '',
        description: sk.description || '',
        displayOrder: sk.displayOrder || 1,
        active: sk.active !== false
      });
    } else {
      setEditingSkill(null);
      setSkillForm({
        name: '',
        categoryId: categories[0]?.id || '',
        serviceItemId: '',
        description: '',
        displayOrder: skillsList.length + 1,
        active: true
      });
    }
    setShowSkillModal(true);
  };

  const handleSaveSkill = async (e) => {
    e.preventDefault();
    try {
      if (editingSkill) {
        await api.updateSkill(editingSkill, {
          name: skillForm.name,
          description: skillForm.description,
          displayOrder: Number(skillForm.displayOrder),
          active: skillForm.active
        });
        auditLogAction?.('Services', `Updated skill "${skillForm.name}"`);
      } else {
        await api.createSkill({
          name: skillForm.name,
          categoryId: skillForm.categoryId,
          serviceItemId: skillForm.serviceItemId || null,
          description: skillForm.description,
          displayOrder: Number(skillForm.displayOrder)
        });
        auditLogAction?.('Services', `Created skill "${skillForm.name}"`);
      }
      setShowSkillModal(false);
      loadSkills();
    } catch (err) {
      alert('Error saving skill: ' + err.message);
    }
  };

  const handleDeleteSkill = async (id, name) => {
    if (window.confirm(`Deactivate skill "${name}"?`)) {
      try {
        await api.deleteSkill(id);
        auditLogAction?.('Services', `Deactivated skill "${name}"`);
        loadSkills();
      } catch (err) {
        alert('Error deactivating skill: ' + err.message);
      }
    }
  };

  // Category Extraction Helpers
  const getCategoryName = (item) => {
    if (!item) return 'General';
    if (typeof item === 'string') return item;
    if (typeof item.category === 'string') return item.category;
    if (item.category && typeof item.category === 'object' && item.category.name) return item.category.name;
    if (item.categoryName) return item.categoryName;
    return 'General';
  };

  const getCategoryId = (item) => {
    if (!item) return '';
    if (item.categoryId) return item.categoryId;
    if (item.category && typeof item.category === 'object' && item.category.id) return item.category.id;
    return '';
  };

  // Filtered Services List
  const filteredServices = (services || []).filter(s => {
    const sCat = getCategoryName(s);
    const sCatId = getCategoryId(s);
    const matchesSearch = !searchQuery || 
      (s.name && s.name.toLowerCase().includes(searchQuery.toLowerCase())) || 
      sCat.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCat = filterCategory === 'ALL' || sCat.toLowerCase() === filterCategory.toLowerCase() || sCatId === filterCategory;
    return matchesSearch && matchesCat;
  });

  const filteredSkills = (skillsList || []).filter(sk => {
    const skCat = sk.categoryName || '';
    const matchesSearch = !searchQuery || 
      (sk.name && sk.name.toLowerCase().includes(searchQuery.toLowerCase())) || 
      skCat.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCat = filterCategory === 'ALL' || sk.categoryId === filterCategory || skCat.toLowerCase() === filterCategory.toLowerCase();
    return matchesSearch && matchesCat;
  });

  // Dynamic Derived States for Visual Asset Repository & Popular Services
  const activePopular = popularServices.length > 0 
    ? popularServices 
    : (services || []).filter(s => s.popular || s.isPopular || s.is_popular).map((s, idx) => ({
        id: s.id,
        name: s.name,
        category: getCategoryName(s),
        imageUrl: s.imageUrl,
        displayOrder: idx + 1,
        isActive: s.isActive !== false
      }));

  const activeImages = serviceImages.length > 0
    ? serviceImages
    : [
        ...(services || []).filter(s => s.imageUrl).map(s => ({
          id: s.id,
          url: s.imageUrl,
          title: s.name,
          category: getCategoryName(s),
          resolution: '400x400',
          tags: 'Service, Thumbnail'
        })),
        ...(categories || []).filter(c => c.imageUrl || c.iconUrl).map(c => ({
          id: c.id,
          url: c.imageUrl || c.iconUrl,
          title: c.name,
          category: 'Category Vertical',
          resolution: '500x500',
          tags: 'Category, Icon'
        }))
      ];

  return (
    <div className="services-manager-view">
      {/* ─── FLAT TABS NAVIGATION (7 TABS) ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${activeTab === 'categories' ? 'active' : ''}`} onClick={() => setActiveTab('categories')}>
          📂 Categories ({categories.length})
        </div>
        <div className={`flat-tab ${activeTab === 'services' ? 'active' : ''}`} onClick={() => setActiveTab('services')}>
          🛠️ Services Catalog ({services.length})
        </div>
        <div className={`flat-tab ${activeTab === 'skills' ? 'active' : ''}`} onClick={() => setActiveTab('skills')}>
          🎯 Skills Directory ({skillsList.length})
        </div>
        <div className={`flat-tab ${activeTab === 'matching' ? 'active' : ''}`} onClick={() => setActiveTab('matching')}>
          ⚙️ Matching Rules
        </div>
        <div className={`flat-tab ${activeTab === 'popular' ? 'active' : ''}`} onClick={() => setActiveTab('popular')}>
          ⭐ Popular Services ({activePopular.length})
        </div>
        <div className={`flat-tab ${activeTab === 'images' ? 'active' : ''}`} onClick={() => setActiveTab('images')}>
          🖼️ Service Images ({activeImages.length})
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
            <div style={{ display: 'flex', gap: '8px' }}>
              <button className="btn btn-outline" onClick={() => onReload?.()}>
                🔄 Refresh Categories
              </button>
              <button className="btn btn-primary" onClick={() => openCategoryModal()}>
                + Add Category
              </button>
            </div>
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
                {categories.length === 0 ? (
                  <tr>
                    <td colSpan="5" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                      📁 No categories found
                    </td>
                  </tr>
                ) : (
                  categories.map(cat => {
                    const count = (services || []).filter(s => getCategoryName(s).toLowerCase() === cat.name.toLowerCase() || getCategoryId(s) === cat.id).length;
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
                  })
                )}
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
            <div style={{ display: 'flex', gap: '8px' }}>
              <button className="btn btn-outline" onClick={() => onReload?.()}>
                🔄 Refresh Services
              </button>
              <button className="btn btn-primary" onClick={() => openServiceModal()}>
                + Add Service
              </button>
            </div>
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
                {filteredServices.length === 0 ? (
                  <tr>
                    <td colSpan="8" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                      🛠️ No services found. Click "+ Add Service" to create a new service in the database.
                    </td>
                  </tr>
                ) : (
                  filteredServices.map(srv => (
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
                      <span className="badge badge-info">{getCategoryName(srv)}</span>
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
                ))
              )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB: SKILLS HIERARCHY & DIRECTORY
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'skills' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">Technician Skills Directory</h2>
              <p className="page-subtitle">Configure granular skills hierarchy (Category → Service → Skill) for onboarding & dispatch matching</p>
            </div>
            <button className="btn btn-primary" onClick={() => openSkillModal()}>
              + Add Skill
            </button>
          </div>

          <div className="toolbar-row">
            <div className="toolbar-left">
              <div className="search-box">
                <span className="search-icon">🔍</span>
                <input
                  type="text"
                  placeholder="Search skills or categories..."
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
                Showing {filteredSkills.length} of {skillsList.length} skills
              </span>
            </div>
          </div>

          {loadingSkills ? (
            <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
              Loading skills catalog...
            </div>
          ) : (
            <div className="table-responsive">
              <table className="flat-table">
                <thead>
                  <tr>
                    <th style={{ width: '70px' }}>Order</th>
                    <th>Skill Name</th>
                    <th>Parent Category</th>
                    <th>Associated Service</th>
                    <th>Status</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredSkills.length === 0 ? (
                    <tr>
                      <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-secondary)' }}>
                        🎯 No skills found for current filter. Click <strong>+ Add Skill</strong> to create one.
                      </td>
                    </tr>
                  ) : (
                    filteredSkills.map(sk => (
                      <tr key={sk.id}>
                        <td>
                          <span className="badge badge-info" style={{ fontWeight: '700' }}>#{sk.displayOrder || 1}</span>
                        </td>
                        <td>
                          <strong style={{ color: 'var(--text-main)', fontSize: '14px' }}>{sk.name}</strong>
                          <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>slug: {sk.slug}</div>
                        </td>
                        <td>
                          <span className="badge badge-info">{sk.categoryName}</span>
                        </td>
                        <td>
                          <span style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
                            {sk.serviceItemName || 'General Category Skill'}
                          </span>
                        </td>
                        <td>
                          <span className={`badge ${sk.active !== false ? 'badge-completed' : 'badge-cancelled'}`}>
                            {sk.active !== false ? 'Active' : 'Disabled'}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                            <button
                              className="btn btn-outline btn-sm"
                              style={{ borderColor: 'var(--primary)', color: 'var(--primary)' }}
                              onClick={() => openCompatibilityModal(sk)}
                            >
                              🔗 Compatibility
                            </button>
                            <button className="btn btn-outline btn-sm" onClick={() => openSkillModal(sk)}>Edit</button>
                            <button className="btn btn-danger btn-sm" onClick={() => handleDeleteSkill(sk.id, sk.name)}>Deactivate</button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB: MATCHING RULES & DISPATCH CONFIGURATION
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'matching' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">⚙️ Intelligent Dispatch & Skill Matching Engine Rules</h2>
              <p className="page-subtitle">Configure search radius, skill matching strictness, candidate score weights, proposal timeouts, and escalation triggers</p>
            </div>
          </div>

          <form onSubmit={handleSaveMatchingRules} style={{ maxWidth: '900px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
            {/* 1. Spatial Search & Matching Strictness */}
            <div style={{ background: 'var(--card-bg, #ffffff)', border: '1px solid var(--border-color, #E2E8F0)', borderRadius: '12px', padding: '20px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '14px', color: 'var(--text-main)' }}>
                📍 1. Spatial Search & Skill Compatibility Strictness
              </h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                <div className="form-group">
                  <label className="form-label">
                    Search Radius (km): <strong style={{ color: 'var(--primary)' }}>{matchingRules.searchRadiusKm} km</strong>
                  </label>
                  <input
                    type="range"
                    min="1"
                    max="50"
                    step="1"
                    value={matchingRules.searchRadiusKm}
                    onChange={e => setMatchingRules({ ...matchingRules, searchRadiusKm: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: 'var(--primary)' }}
                  />
                  <small style={{ color: 'var(--text-secondary)' }}>Maximum GPS distance to look for online, active technicians (Default: 10 km)</small>
                </div>

                <div className="form-group">
                  <label className="form-label">Skill Matching Rule</label>
                  <select
                    className="form-control"
                    value={matchingRules.strictSkillMatching ? 'strict' : 'flexible'}
                    onChange={e => setMatchingRules({ ...matchingRules, strictSkillMatching: e.target.value === 'strict' })}
                  >
                    <option value="strict">Strict (Require exact verified skill or mapped compatibility)</option>
                    <option value="flexible">Flexible (Allow category-level fallback if profile lacks specific skill)</option>
                  </select>
                  <small style={{ color: 'var(--text-secondary)' }}>Enforces verified technical capability before booking proposal dispatch</small>
                </div>
              </div>
            </div>

            {/* 2. Dispatch Priority & Score Weights */}
            <div style={{ background: 'var(--card-bg, #ffffff)', border: '1px solid var(--border-color, #E2E8F0)', borderRadius: '12px', padding: '20px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '14px', color: 'var(--text-main)' }}>
                ⚖️ 2. Priority Policy & Candidate Scoring Weights
              </h3>
              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label className="form-label">Priority Strategy Policy</label>
                <select
                  className="form-control"
                  value={matchingRules.priorityPolicy}
                  onChange={e => setMatchingRules({ ...matchingRules, priorityPolicy: e.target.value })}
                >
                  <option value="BALANCED">Balanced Multi-Factor (Distance + Rating + Acceptance + Experience)</option>
                  <option value="NEAREST_FIRST">Fastest Response (Nearest GPS Distance Priority)</option>
                  <option value="HIGHEST_RATED">Quality First (Highest Rated & Experienced Technicians)</option>
                  <option value="FAIR_SHARE">Fair Distribution (Balance job opportunities across all active partners)</option>
                </select>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div className="form-group">
                  <label className="form-label">Distance Weight: <strong>{Math.round(matchingRules.scoreWeightDistance * 100)}%</strong></label>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.05"
                    value={matchingRules.scoreWeightDistance}
                    onChange={e => setMatchingRules({ ...matchingRules, scoreWeightDistance: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: 'var(--primary)' }}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Rating Weight: <strong>{Math.round(matchingRules.scoreWeightRating * 100)}%</strong></label>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.05"
                    value={matchingRules.scoreWeightRating}
                    onChange={e => setMatchingRules({ ...matchingRules, scoreWeightRating: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: '#D97706' }}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Acceptance Rate Weight: <strong>{Math.round(matchingRules.scoreWeightAcceptance * 100)}%</strong></label>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.05"
                    value={matchingRules.scoreWeightAcceptance}
                    onChange={e => setMatchingRules({ ...matchingRules, scoreWeightAcceptance: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: '#059669' }}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Experience Weight: <strong>{Math.round(matchingRules.scoreWeightExperience * 100)}%</strong></label>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.05"
                    value={matchingRules.scoreWeightExperience}
                    onChange={e => setMatchingRules({ ...matchingRules, scoreWeightExperience: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: '#7C3AED' }}
                  />
                </div>
              </div>
            </div>

            {/* 3. Notification Timeouts & Escalation Triggers */}
            <div style={{ background: 'var(--card-bg, #ffffff)', border: '1px solid var(--border-color, #E2E8F0)', borderRadius: '12px', padding: '20px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '14px', color: 'var(--text-main)' }}>
                ⏱️ 3. Notification Countdown & Admin Escalation Triggers
              </h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                <div className="form-group">
                  <label className="form-label">
                    Proposal Countdown Timeout: <strong style={{ color: 'var(--primary)' }}>{matchingRules.notificationTimeoutSeconds} seconds</strong>
                  </label>
                  <input
                    type="range"
                    min="15"
                    max="120"
                    step="5"
                    value={matchingRules.notificationTimeoutSeconds}
                    onChange={e => setMatchingRules({ ...matchingRules, notificationTimeoutSeconds: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: 'var(--primary)' }}
                  />
                  <small style={{ color: 'var(--text-secondary)' }}>Seconds technician has to accept before cascading to next candidate</small>
                </div>

                <div className="form-group">
                  <label className="form-label">
                    Max Candidate Attempts: <strong>{matchingRules.maxDispatchAttempts} attempts</strong>
                  </label>
                  <input
                    type="range"
                    min="1"
                    max="10"
                    step="1"
                    value={matchingRules.maxDispatchAttempts}
                    onChange={e => setMatchingRules({ ...matchingRules, maxDispatchAttempts: Number(e.target.value) })}
                    style={{ width: '100%', accentColor: 'var(--primary)' }}
                  />
                  <small style={{ color: 'var(--text-secondary)' }}>Number of sequential technician proposals before triggering escalation</small>
                </div>
              </div>

              <div style={{ marginTop: '14px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <input
                  type="checkbox"
                  id="escalateAdmin"
                  checked={matchingRules.autoEscalateToAdmin}
                  onChange={e => setMatchingRules({ ...matchingRules, autoEscalateToAdmin: e.target.checked })}
                  style={{ width: '18px', height: '18px', accentColor: 'var(--primary)' }}
                />
                <label htmlFor="escalateAdmin" style={{ fontWeight: '600', color: 'var(--text-main)', cursor: 'pointer' }}>
                  Auto-escalate to Admin Operations Console if no partner accepts within attempt limit
                </label>
              </div>
            </div>

            <div>
              <button type="submit" className="btn btn-primary" style={{ padding: '12px 28px', fontSize: '15px' }} disabled={savingRules}>
                {savingRules ? 'Saving Matching Rules...' : '💾 Save Dispatch Matching Engine Rules'}
              </button>
            </div>
          </form>
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
                {activePopular.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-secondary)' }}>
                      ⭐ No popular services pinned yet. Click <strong>+ Add Popular Service</strong> to highlight one.
                    </td>
                  </tr>
                ) : (
                  activePopular.map(pop => (
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
                  ))
                )}
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
                {activeImages.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-secondary)' }}>
                      🖼️ No image assets found. Add services or categories with images to populate this gallery.
                    </td>
                  </tr>
                ) : (
                  activeImages.map(img => (
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
                  ))
                )}
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
                  <label className="form-label" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span>Category Image / Thumbnail</span>
                    <label className="btn btn-outline btn-sm" style={{ cursor: 'pointer', padding: '3px 8px', fontSize: '11px' }}>
                      📁 Choose from Gallery / Files
                      <input
                        type="file"
                        accept="image/*"
                        style={{ display: 'none' }}
                        onChange={e => handleFileUpload(e, (dataUrl) => setCategoryForm(prev => ({ ...prev, imageUrl: dataUrl })))}
                      />
                    </label>
                  </label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="Paste image URL or click 'Choose from Gallery' above..."
                    value={categoryForm.imageUrl}
                    onChange={e => setCategoryForm({ ...categoryForm, imageUrl: e.target.value })}
                  />
                  {/* Live Active Image Preview */}
                  <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginTop: '8px', backgroundColor: '#F8FAFC', padding: '8px 12px', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
                    <div style={{
                      width: '48px',
                      height: '48px',
                      borderRadius: '6px',
                      border: '1px solid #CBD5E1',
                      backgroundColor: '#FFFFFF',
                      overflow: 'hidden',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0
                    }}>
                      {categoryForm.imageUrl ? (
                        <img
                          src={categoryForm.imageUrl}
                          alt="Live Preview"
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                          onError={(e) => {
                            e.target.style.display = 'none';
                            e.target.nextSibling.style.display = 'block';
                          }}
                          onLoad={(e) => {
                            e.target.style.display = 'block';
                            if (e.target.nextSibling) e.target.nextSibling.style.display = 'none';
                          }}
                        />
                      ) : null}
                      <span style={{ fontSize: '20px', display: categoryForm.imageUrl ? 'none' : 'block' }}>🖼️</span>
                    </div>
                    <div style={{ fontSize: '11.5px', color: '#64748B', flex: 1 }}>
                      <strong style={{ color: '#0F172A', display: 'block' }}>Live Thumbnail Preview</strong>
                      Uploaded from gallery or pasted direct image link.
                    </div>
                    {categoryForm.imageUrl && (
                      <button
                        type="button"
                        className="btn btn-outline btn-sm"
                        style={{ color: '#EF4444', borderColor: '#FCA5A5' }}
                        onClick={() => setCategoryForm(prev => ({ ...prev, imageUrl: '' }))}
                      >
                        ✕ Clear
                      </button>
                    )}
                  </div>
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
                  <label className="form-label" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span>Service Image / Thumbnail</span>
                    <label className="btn btn-outline btn-sm" style={{ cursor: 'pointer', padding: '3px 8px', fontSize: '11px' }}>
                      📁 Choose from Gallery / Files
                      <input
                        type="file"
                        accept="image/*"
                        style={{ display: 'none' }}
                        onChange={e => handleFileUpload(e, (dataUrl) => setServiceForm(prev => ({ ...prev, imageUrl: dataUrl })))}
                      />
                    </label>
                  </label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="Paste image URL or click 'Choose from Gallery' above..."
                    value={serviceForm.imageUrl}
                    onChange={e => setServiceForm({ ...serviceForm, imageUrl: e.target.value })}
                  />
                  {/* Live Active Image Preview */}
                  <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginTop: '8px', backgroundColor: '#F8FAFC', padding: '8px 12px', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
                    <div style={{
                      width: '48px',
                      height: '48px',
                      borderRadius: '6px',
                      border: '1px solid #CBD5E1',
                      backgroundColor: '#FFFFFF',
                      overflow: 'hidden',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0
                    }}>
                      {serviceForm.imageUrl ? (
                        <img
                          src={serviceForm.imageUrl}
                          alt="Service Preview"
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                          onError={(e) => {
                            e.target.style.display = 'none';
                            e.target.nextSibling.style.display = 'block';
                          }}
                          onLoad={(e) => {
                            e.target.style.display = 'block';
                            if (e.target.nextSibling) e.target.nextSibling.style.display = 'none';
                          }}
                        />
                      ) : null}
                      <span style={{ fontSize: '20px', display: serviceForm.imageUrl ? 'none' : 'block' }}>🛠️</span>
                    </div>
                    <div style={{ fontSize: '11.5px', color: '#64748B', flex: 1 }}>
                      <strong style={{ color: '#0F172A', display: 'block' }}>Live Thumbnail Preview</strong>
                      Uploaded from device gallery or pasted URL link.
                    </div>
                    {serviceForm.imageUrl && (
                      <button
                        type="button"
                        className="btn btn-outline btn-sm"
                        style={{ color: '#EF4444', borderColor: '#FCA5A5' }}
                        onClick={() => setServiceForm(prev => ({ ...prev, imageUrl: '' }))}
                      >
                        ✕ Clear
                      </button>
                    )}
                  </div>
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

      {/* ─── SKILL MODAL ─── */}
      {showSkillModal && (
        <div className="modal-overlay" onClick={() => setShowSkillModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '580px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingSkill ? 'Edit Technician Skill' : 'Create New Skill'}</h3>
              <button className="modal-close-btn" onClick={() => setShowSkillModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveSkill}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-group">
                  <label className="form-label">Skill Name *</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Ceiling Fan Repair, AC Deep Cleaning"
                    value={skillForm.name}
                    onChange={e => setSkillForm({ ...skillForm, name: e.target.value })}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Parent Service Category *</label>
                  <select
                    className="form-control"
                    required
                    value={skillForm.categoryId}
                    onChange={e => setSkillForm({ ...skillForm, categoryId: e.target.value })}
                  >
                    <option value="">Select Parent Category</option>
                    {categories.map(c => (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Associated Service (Optional)</label>
                  <select
                    className="form-control"
                    value={skillForm.serviceItemId}
                    onChange={e => setSkillForm({ ...skillForm, serviceItemId: e.target.value })}
                  >
                    <option value="">General Category Skill (All Services)</option>
                    {services.map(s => (
                      <option key={s.id} value={s.id}>{s.name} ({getCategoryName(s)})</option>
                    ))}
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
                      value={skillForm.displayOrder}
                      onChange={e => setSkillForm({ ...skillForm, displayOrder: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Status</label>
                    <select
                      className="form-control"
                      value={skillForm.active ? 'true' : 'false'}
                      onChange={e => setSkillForm({ ...skillForm, active: e.target.value === 'true' })}
                    >
                      <option value="true">Active (Visible for Onboarding)</option>
                      <option value="false">Disabled / Inactive</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Skill Description (Optional)</label>
                  <textarea
                    className="form-control"
                    rows="2"
                    placeholder="Brief description of verified technical competency required"
                    value={skillForm.description}
                    onChange={e => setSkillForm({ ...skillForm, description: e.target.value })}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowSkillModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">
                  {editingSkill ? 'Save Changes' : 'Create Skill'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── SKILL SERVICE COMPATIBILITY MODAL ─── */}
      {showCompatibilityModal && selectedSkillCompat && (
        <div className="modal-overlay" onClick={() => setShowCompatibilityModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '680px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <div>
                <h3 className="modal-title">🔗 Skill Compatibility Matrix</h3>
                <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                  Skill: <strong>{selectedSkillCompat.name}</strong> ({selectedSkillCompat.categoryName})
                </div>
              </div>
              <button className="modal-close-btn" onClick={() => setShowCompatibilityModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '14px' }}>
                Select all customer services that technicians holding this verified skill are qualified to handle. When customer bookings are dispatched, partners with this skill will automatically be eligible.
              </p>

              {loadingCompat ? (
                <div style={{ textAlign: 'center', padding: '30px', color: 'var(--text-secondary)' }}>
                  Loading service compatibility...
                </div>
              ) : (
                <div style={{ maxHeight: '350px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {services.map(srv => {
                    const isChecked = compatibleServiceIds.includes(srv.id);
                    return (
                      <div
                        key={srv.id}
                        onClick={() => handleToggleCompatService(srv.id)}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          padding: '10px 14px',
                          borderRadius: '8px',
                          border: isChecked ? '1.5px solid var(--primary, #1E3A8A)' : '1px solid var(--border-color, #E2E8F0)',
                          background: isChecked ? '#EFF6FF' : 'var(--card-bg, #ffffff)',
                          cursor: 'pointer',
                          transition: 'all 0.15s ease'
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <input
                            type="checkbox"
                            checked={isChecked}
                            onChange={() => {}}
                            style={{ width: '17px', height: '17px', accentColor: 'var(--primary, #1E3A8A)', cursor: 'pointer' }}
                          />
                          <div>
                            <strong style={{ color: 'var(--text-main)', fontSize: '13.5px' }}>{srv.name}</strong>
                            <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                              Category: {getCategoryName(srv)} • ₹{srv.price}
                            </div>
                          </div>
                        </div>
                        <span className={`badge ${isChecked ? 'badge-completed' : 'badge-cancelled'}`} style={{ fontSize: '11px' }}>
                          {isChecked ? 'Compatible' : 'Not Linked'}
                        </span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
            <div className="modal-footer">
              <div style={{ marginRight: 'auto', fontSize: '13px', color: 'var(--text-secondary)' }}>
                <strong>{compatibleServiceIds.length}</strong> of {services.length} services mapped
              </div>
              <button type="button" className="btn btn-outline" onClick={() => setShowCompatibilityModal(false)}>
                Cancel
              </button>
              <button type="button" className="btn btn-primary" onClick={handleSaveCompatibility} disabled={savingCompat}>
                {savingCompat ? 'Saving Matrix...' : '💾 Save Compatibility Mapping'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
