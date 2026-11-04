import React, { useState, useEffect, useCallback } from 'react';
import api from './api/apiClient';

// Feature Components
import Dashboard from './features/dashboard/Dashboard';
import BookingsManager from './features/bookings/BookingsManager';
import DispatchManager from './features/bookings/DispatchManager';
import SchedulingManager from './features/bookings/SchedulingManager';
import CustomersManager from './features/customers/CustomersManager';
import TechniciansManager from './features/technicians/TechniciansManager';
import TechnicianIdCardManager from './features/technicians/TechnicianIdCardManager';
import ServicesManager from './features/services/ServicesManager';
import PricingManager from './features/services/PricingManager';
import PaymentsManager from './features/payments/PaymentsManager';
import RefundsManager from './features/payments/RefundsManager';
import CancellationsManager from './features/payments/CancellationsManager';
import BannersManager from './features/content/BannersManager';
import SupportManager from './features/support/SupportManager';
import ReviewsManager from './features/support/ReviewsManager';
import ReportsManager from './features/reports/ReportsManager';
import SettingsManager from './features/settings/SettingsManager';
import AiAssistantCms from './features/ai_assistant/AiAssistantCms';
import AdminLogin from './features/auth/AdminLogin';

// Control Tower Feature Components
import LiveBookingRadar from './features/dispatch_tower/LiveBookingRadar';
import FinancialSettlementPortal from './features/payouts/FinancialSettlementPortal';

export default function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [activeSubTab, setActiveSubTab] = useState('');
  const [currentRole, setCurrentRole] = useState('SUPER_ADMIN');
  const [adminUser, setAdminUser] = useState({
    id: 'admin-master-001',
    email: 'admin@bookurtechnician.com',
    fullName: 'System Administrator',
    role: 'SUPER_ADMIN'
  });
  const [isCheckingAuth, setIsCheckingAuth] = useState(false);
  const [notifDropdownOpen, setNotifDropdownOpen] = useState(false);
  const [globalSearch, setGlobalSearch] = useState('');

  // ─── STATE INITIALIZATION (CLEAN LAUNCH CACHE VERSION GUARD + LIVE REVALIDATION) ───
  const CACHE_SCHEMA_VERSION = 'bt_clean_launch_v3';
  try {
    if (typeof localStorage !== 'undefined' && localStorage.getItem('bt_cache_schema_version') !== CACHE_SCHEMA_VERSION) {
      localStorage.removeItem('bt_cache_stats');
      localStorage.removeItem('bt_cache_bookings');
      localStorage.removeItem('bt_cache_customers');
      localStorage.removeItem('bt_cache_technicians');
      localStorage.setItem('bt_cache_schema_version', CACHE_SCHEMA_VERSION);
    }
  } catch (_) {}

  const [stats, setStats] = useState(() => {
    try { return JSON.parse(localStorage.getItem('bt_cache_stats')) || null; } catch (_) { return null; }
  });
  const [categories, setCategories] = useState(() => {
    try { return JSON.parse(localStorage.getItem('bt_cache_categories')) || []; } catch (_) { return []; }
  });
  const [services, setServices] = useState(() => {
    try { return JSON.parse(localStorage.getItem('bt_cache_services')) || []; } catch (_) { return []; }
  });
  const [technicians, setTechnicians] = useState(() => {
    try { return JSON.parse(localStorage.getItem('bt_cache_technicians')) || []; } catch (_) { return []; }
  });
  const [bookings, setBookings] = useState(() => {
    try { return JSON.parse(localStorage.getItem('bt_cache_bookings')) || []; } catch (_) { return []; }
  });
  const [customers, setCustomers] = useState(() => {
    try { return JSON.parse(localStorage.getItem('bt_cache_customers')) || []; } catch (_) { return []; }
  });
  const [supportTickets, setSupportTickets] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [selectedTechForIdCard, setSelectedTechForIdCard] = useState(null);
  const [isSyncing, setIsSyncing] = useState(false);

  const [settings, setSettings] = useState({
    bookingCharge: 99,
    gstRate: 18,
    cancellationWindow: 1,
    refundSlaHours: 48
  });

  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    const token = api.getToken();
    return Boolean(token && !token.startsWith('bt_mock_'));
  });

  // Centralized Live Data Fetcher
  const loadAllAdminData = useCallback(async () => {
    setIsSyncing(true);
    try {
      await Promise.allSettled([
        api.getStats().then(res => { 
          if (res?.data) {
            setStats(res.data);
            try { localStorage.setItem('bt_cache_stats', JSON.stringify(res.data)); } catch (_) {}
          }
        }),
        api.getTechnicians().then(res => {
          const list = res?.data || (Array.isArray(res) ? res : []);
          if (Array.isArray(list)) {
            setTechnicians(list);
            try { localStorage.setItem('bt_cache_technicians', JSON.stringify(list)); } catch (_) {}
          }
        }),
        api.getBookings().then(res => { 
          if (res?.data) {
            setBookings(res.data);
            try { localStorage.setItem('bt_cache_bookings', JSON.stringify(res.data)); } catch (_) {}
          }
        }),
        api.getCustomers().then(res => { 
          if (res?.data) {
            setCustomers(res.data);
            try { localStorage.setItem('bt_cache_customers', JSON.stringify(res.data)); } catch (_) {}
          }
        }),
        api.getCategories().then(res => {
          const list = res?.data || (Array.isArray(res) ? res : []);
          if (Array.isArray(list)) {
            setCategories(list);
            try { localStorage.setItem('bt_cache_categories', JSON.stringify(list)); } catch (_) {}
          }
        }),
        api.getServices().then(res => {
          const list = res?.data || (Array.isArray(res) ? res : []);
          if (Array.isArray(list)) {
            setServices(list);
            try { localStorage.setItem('bt_cache_services', JSON.stringify(list)); } catch (_) {}
          }
        }),
        api.getSupportTickets().then(res => { if (res?.data) setSupportTickets(res.data); }),
        api.getAuditLogs().then(res => { if (res?.data) setAuditLogs(res.data); }),
      ]);
    } catch (err) {
      console.error('Error fetching admin data from PostgreSQL:', err);
    } finally {
      setTimeout(() => setIsSyncing(false), 200);
    }
  }, []);

  useEffect(() => {
    if (isAuthenticated) {
      loadAllAdminData();
    }
  }, [isAuthenticated, loadAllAdminData]);

  // Periodic 10-second background polling to keep bookings, technicians, and stats synced with PostgreSQL
  useEffect(() => {
    const interval = setInterval(() => {
      api.getStats().then(res => { if (res?.data) setStats(res.data); }).catch(() => {});
      api.getBookings().then(res => { if (res?.data) setBookings(res.data); }).catch(() => {});
      api.getTechnicians().then(res => { if (res?.data) setTechnicians(res.data); }).catch(() => {});
    }, 10000);
    return () => clearInterval(interval);
  }, []);

  const auditLogAction = (moduleName, description) => {
    const timeStr = new Date().toLocaleTimeString();
    const newLog = {
      timestamp: timeStr,
      module: moduleName,
      action: description,
      operator: currentRole
    };
    setAuditLogs(prev => [newLog, ...prev]);
  };

  const handleResetDatabase = () => {
    if (window.confirm("Are you sure you want to refresh all data from the database?")) {
      loadAllAdminData();
      alert("Admin state successfully synchronized with PostgreSQL!");
    }
  };

  const selectView = (tab, subTab = '') => {
    setActiveTab(tab);
    setActiveSubTab(subTab);
  };

  const handleNavigateToIdCard = (tech) => {
    setSelectedTechForIdCard(tech);
    setActiveTab('id_card');
  };

  const handleLogout = () => {
    api.logout();
    setAdminUser(null);
    setIsAuthenticated(false);
  };

  if (!isAuthenticated) {
    return (
      <AdminLogin
        onLoginSuccess={(user) => {
          setIsAuthenticated(true);
          if (user) setAdminUser(user);
          loadAllAdminData();
        }}
      />
    );
  }

  return (
    <div className="app-container">
      {/* ─── FIXED LEFT SIDEBAR (OBSIDIAN BLACK + ROYAL BLUE) ─── */}
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="sidebar-logo-icon">🛠️</div>
          <div>
            <div className="sidebar-brand-text">BookurTechnician</div>
            <div className="sidebar-brand-badge">CONTROL TOWER</div>
          </div>
        </div>

        <div className="sidebar-nav">
          <div className="nav-section-title">⚡ OPERATIONS &amp; DISPATCH</div>

          <div className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => selectView('dashboard')}>
            <div className="nav-item-content">
              <span className="nav-icon">🏠</span>
              <span>Dashboard</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'live_radar' ? 'active' : ''}`} onClick={() => selectView('live_radar')}>
            <div className="nav-item-content">
              <span className="nav-icon">📡</span>
              <span>Live Dispatch</span>
            </div>
            <span className="nav-badge nav-badge-pulse">LIVE</span>
          </div>

          <div className={`nav-item ${activeTab === 'bookings' ? 'active' : ''}`} onClick={() => selectView('bookings', 'all')}>
            <div className="nav-item-content">
              <span className="nav-icon">📋</span>
              <span>All Bookings</span>
            </div>
            <span className="nav-badge nav-badge-royal">{stats?.totalBookings !== undefined && stats?.totalBookings !== null ? stats.totalBookings : bookings.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'customers' ? 'active' : ''}`} onClick={() => selectView('customers')}>
            <div className="nav-item-content">
              <span className="nav-icon">👥</span>
              <span>Customers</span>
            </div>
            <span className="nav-badge nav-badge-royal">{stats?.totalCustomers !== undefined && stats?.totalCustomers !== null ? stats.totalCustomers : customers.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'technicians' && activeSubTab !== 'verification' ? 'active' : ''}`} onClick={() => selectView('technicians', 'directory')}>
            <div className="nav-item-content">
              <span className="nav-icon">👨‍🔧</span>
              <span>Technicians</span>
            </div>
            <span className="nav-badge nav-badge-royal">{stats?.totalTechnicians !== undefined && stats?.totalTechnicians !== null ? stats.totalTechnicians : technicians.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'technicians' && activeSubTab === 'verification' ? 'active' : ''}`} onClick={() => selectView('technicians', 'verification')}>
            <div className="nav-item-content">
              <span className="nav-icon">🪪</span>
              <span>Technician Verification</span>
            </div>
          </div>

          <div className="nav-section-title">CATALOG &amp; COVERAGE</div>

          <div className={`nav-item ${activeTab === 'services' && activeSubTab === 'categories' ? 'active' : ''}`} onClick={() => selectView('services', 'categories')}>
            <div className="nav-item-content">
              <span className="nav-icon">🗂️</span>
              <span>Service Categories</span>
            </div>
            <span className="nav-badge nav-badge-royal">{categories.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'services' && activeSubTab !== 'categories' ? 'active' : ''}`} onClick={() => selectView('services', 'services')}>
            <div className="nav-item-content">
              <span className="nav-icon">🛠️</span>
              <span>Service Management</span>
            </div>
            <span className="nav-badge nav-badge-royal">{services.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'pricing' ? 'active' : ''}`} onClick={() => selectView('pricing')}>
            <div className="nav-item-content">
              <span className="nav-icon">🏷️</span>
              <span>Pricing &amp; Addons</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'availability' ? 'active' : ''}`} onClick={() => selectView('availability')}>
            <div className="nav-item-content">
              <span className="nav-icon">🗓️</span>
              <span>Availability Management</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'service_areas' ? 'active' : ''}`} onClick={() => selectView('service_areas')}>
            <div className="nav-item-content">
              <span className="nav-icon">📍</span>
              <span>Service Areas</span>
            </div>
          </div>

          <div className="nav-section-title">FINANCE &amp; SETTLEMENT</div>

          <div className={`nav-item ${activeTab === 'payments' ? 'active' : ''}`} onClick={() => selectView('payments', 'transactions')}>
            <div className="nav-item-content">
              <span className="nav-icon">💳</span>
              <span>Payments</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'refunds' ? 'active' : ''}`} onClick={() => selectView('refunds')}>
            <div className="nav-item-content">
              <span className="nav-icon">↩️</span>
              <span>Refunds</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'settlements' && activeSubTab !== 'withdrawals' ? 'active' : ''}`} onClick={() => selectView('settlements', 'earnings')}>
            <div className="nav-item-content">
              <span className="nav-icon">💰</span>
              <span>Technician Earnings</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'settlements' && activeSubTab === 'withdrawals' ? 'active' : ''}`} onClick={() => selectView('settlements', 'withdrawals')}>
            <div className="nav-item-content">
              <span className="nav-icon">🏦</span>
              <span>Withdrawals</span>
            </div>
          </div>

          <div className="nav-section-title">SUPPORT, GROWTH &amp; GOVERNANCE</div>

          <div className={`nav-item ${activeTab === 'reviews' ? 'active' : ''}`} onClick={() => selectView('reviews')}>
            <div className="nav-item-content">
              <span className="nav-icon">⭐</span>
              <span>Reviews</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'support' ? 'active' : ''}`} onClick={() => selectView('support')}>
            <div className="nav-item-content">
              <span className="nav-icon">🎧</span>
              <span>Support Tickets</span>
            </div>
            <span className="nav-badge nav-badge-royal">{supportTickets.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'banners' ? 'active' : ''}`} onClick={() => selectView('banners')}>
            <div className="nav-item-content">
              <span className="nav-icon">🎁</span>
              <span>Promotions</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'ai_assistant' ? 'active' : ''}`} onClick={() => selectView('ai_assistant')}>
            <div className="nav-item-content">
              <span className="nav-icon">🔔</span>
              <span>Notifications</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'reports' ? 'active' : ''}`} onClick={() => selectView('reports')}>
            <div className="nav-item-content">
              <span className="nav-icon">📊</span>
              <span>Reports &amp; Analytics</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'audit_logs' && activeSubTab !== 'settings' ? 'active' : ''}`} onClick={() => selectView('audit_logs', 'audit')}>
            <div className="nav-item-content">
              <span className="nav-icon">📜</span>
              <span>Audit Logs</span>
            </div>
          </div>

          <div className={`nav-item ${activeTab === 'admin_settings' ? 'active' : ''}`} onClick={() => selectView('admin_settings', 'settings')}>
            <div className="nav-item-content">
              <span className="nav-icon">⚙️</span>
              <span>Admin Settings</span>
            </div>
          </div>
        </div>

        <div className="sidebar-footer">
          <div className="sidebar-user-card">
            <div className="sidebar-user-avatar">
              {adminUser?.fullName ? adminUser.fullName.substring(0, 2).toUpperCase() : 'AD'}
            </div>
            <div className="sidebar-user-info">
              <div className="sidebar-user-name">{adminUser?.fullName || 'Administrator'}</div>
              <div className="sidebar-user-role">{adminUser?.role || currentRole}</div>
            </div>
            <button
              type="button"
              onClick={handleLogout}
              title="Sign Out of Admin Console"
              style={{
                background: 'rgba(239, 68, 68, 0.1)',
                border: '1px solid rgba(239, 68, 68, 0.3)',
                color: '#EF4444',
                padding: '6px 8px',
                borderRadius: '6px',
                fontSize: '11px',
                fontWeight: '700',
                cursor: 'pointer'
              }}
            >
              Exit
            </button>
          </div>
        </div>
      </aside>

      {/* ─── MAIN CONTENT WRAPPER ─── */}
      <div className="main-wrapper">
        {/* ─── TOPBAR HEADER (CRISP WHITE + ROYAL BLUE ACCENTS) ─── */}
        <header className="topbar">
          <div className="topbar-left">
            <div>
              <h2 style={{ fontSize: '18px', fontWeight: '900', color: 'var(--text-main)', margin: 0, textTransform: 'capitalize' }}>
                {activeTab.replace('_', ' ')}
              </h2>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                BookurTechnician Control Tower &gt; {activeTab.toUpperCase()} {activeSubTab ? `&gt; ${activeSubTab.toUpperCase()}` : ''}
              </span>
            </div>
          </div>

          <div className="topbar-right">
            {/* Live Database Status Indicator */}
            <div className="sync-status-badge">
              <div className="sync-dot" style={{ background: isSyncing ? 'var(--status-amber)' : 'var(--status-green)' }}></div>
              <span>{isSyncing ? 'Syncing...' : 'Live Connected'}</span>
            </div>

            {/* Live Refresh Database Button */}
            <button
              type="button"
              className="btn btn-outline btn-sm"
              onClick={loadAllAdminData}
              disabled={isSyncing}
              title="Refresh and synchronize all live data from PostgreSQL"
            >
              <span style={{ display: 'inline-block', transform: isSyncing ? 'rotate(360deg)' : 'none', transition: 'transform 0.5s ease' }}>
                🔄
              </span>
              <span>{isSyncing ? 'Syncing...' : 'Live Sync'}</span>
            </button>

            {/* Sign Out Button */}
            <button
              type="button"
              className="btn btn-dark btn-sm"
              onClick={handleLogout}
              title="Sign Out of Admin Console"
            >
              Sign Out
            </button>
          </div>
        </header>

        {/* ─── MAIN CONTENT VIEWPORT ─── */}
        <main className="content-body">
          {activeTab === 'live_radar' && (
            <LiveBookingRadar
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'settlements' && (
            <FinancialSettlementPortal
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'dashboard' && (
            <Dashboard
              stats={stats}
              bookings={bookings}
              technicians={technicians}
              customers={customers}
              services={services}
              onNavigate={selectView}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'bookings' && (
            <BookingsManager
              bookings={bookings}
              setBookings={setBookings}
              technicians={technicians}
              auditLogAction={auditLogAction}
              subTab={activeSubTab || 'all'}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'customers' && (
            <CustomersManager
              customers={customers}
              setCustomers={setCustomers}
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'technicians' && (
            <TechniciansManager
              technicians={technicians}
              setTechnicians={setTechnicians}
              auditLogAction={auditLogAction}
              subTab={activeSubTab}
              onNavigateToIdCard={handleNavigateToIdCard}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'id_card' && (
            <TechnicianIdCardManager
              technician={selectedTechForIdCard || technicians[0]}
              onBack={() => selectView('technicians')}
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'services' && (
            <ServicesManager
              categories={categories}
              setCategories={setCategories}
              services={services}
              setServices={setServices}
              auditLogAction={auditLogAction}
              subTab={activeSubTab || 'categories'}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'pricing' && (
            <PricingManager
              services={services}
              setServices={setServices}
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'payments' && (
            <PaymentsManager
              bookings={bookings}
              auditLogAction={auditLogAction}
              subTab={activeSubTab || 'transactions'}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'refunds' && (
            <RefundsManager
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'banners' && (
            <BannersManager
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'reviews' && (
            <ReviewsManager
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'reports' && (
            <ReportsManager
              bookings={bookings}
              technicians={technicians}
              customers={customers}
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'support' && (
            <SupportManager
              supportTickets={supportTickets}
              setSupportTickets={setSupportTickets}
              auditLogAction={auditLogAction}
              subTab="tickets"
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'ai_assistant' && (
            <AiAssistantCms
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'availability' && (
            <SchedulingManager
              bookings={bookings}
              technicians={technicians}
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {activeTab === 'service_areas' && (
            <DispatchManager
              bookings={bookings}
              setBookings={setBookings}
              technicians={technicians}
              auditLogAction={auditLogAction}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}

          {(activeTab === 'audit_logs' || activeTab === 'admin_settings') && (
            <SettingsManager
              settings={settings}
              setSettings={setSettings}
              auditLogs={auditLogs}
              auditLogAction={auditLogAction}
              subTab={activeTab === 'admin_settings' ? 'general' : 'audit'}
              onResetDatabase={handleResetDatabase}
              onReload={loadAllAdminData}
              isSyncing={isSyncing}
            />
          )}
        </main>
      </div>
    </div>
  );
}
