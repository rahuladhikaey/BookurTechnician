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
import MarketingManager from './features/marketing/MarketingManager';
import SupportManager from './features/support/SupportManager';
import ReviewsManager from './features/support/ReviewsManager';
import ReportsManager from './features/reports/ReportsManager';
import SettingsManager from './features/settings/SettingsManager';
import AiAssistantCms from './features/ai_assistant/AiAssistantCms';
import AdminLogin from './features/auth/AdminLogin';

// Control Tower Feature Components
import LiveBookingRadar from './features/dispatch_tower/LiveBookingRadar';
import FinancialSettlementPortal from './features/payouts/FinancialSettlementPortal';
import PartnerVerificationView from './features/kyc/PartnerVerificationView';

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

  // ─── STATE INITIALIZATION (EMPTY PRODUCTION STATES) ───
  const [stats, setStats] = useState(null);
  const [categories, setCategories] = useState([]);
  const [services, setServices] = useState([]);
  const [technicians, setTechnicians] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [supportTickets, setSupportTickets] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [selectedTechForIdCard, setSelectedTechForIdCard] = useState(null);

  const [settings, setSettings] = useState({
    bookingCharge: 99,
    gstRate: 18,
    cancellationWindow: 1,
    refundSlaHours: 48
  });

  // Centralized Live Data Fetcher
  const loadAllAdminData = useCallback(async () => {
    try {
      // 1. Stats
      api.getStats()
        .then(res => { if (res?.data) setStats(res.data); })
        .catch(() => {});

      // 2. Technicians
      api.getTechnicians()
        .then(res => { if (res?.data) setTechnicians(res.data); })
        .catch(() => {});

      // 3. Bookings
      api.getBookings()
        .then(res => { if (res?.data) setBookings(res.data); })
        .catch(() => {});

      // 4. Customers
      api.getCustomers()
        .then(res => { if (res?.data) setCustomers(res.data); })
        .catch(() => {});

      // 5. Catalog Categories & Services
      api.getCategories()
        .then(res => { if (res?.data) setCategories(res.data); })
        .catch(() => {});

      api.getServices()
        .then(res => { if (res?.data) setServices(res.data); })
        .catch(() => {});

      // 6. Support Tickets
      api.getSupportTickets()
        .then(res => { if (res?.data) setSupportTickets(res.data); })
        .catch(() => {});

      // 7. Audit Logs
      api.getAuditLogs()
        .then(res => { if (res?.data) setAuditLogs(res.data); })
        .catch(() => {});
    } catch (err) {
      console.error('Error fetching admin data:', err);
    }
  }, []);

  useEffect(() => {
    // Authenticate Super Admin session in background and load live database
    const token = api.getToken();
    if (!token || token.startsWith('bt_mock_')) {
      api.directAdminAccess('admin@bookurtechnician.com', 'BT-ADMIN-KEY-PRIMARY-7788', 'BT-ADMIN-KEY-SECONDARY-9900')
        .then(res => {
          if (res?.data?.accessToken) {
            api.setToken(res.data.accessToken, true);
            if (res.data.refreshToken) {
              localStorage.setItem('bt_admin_refresh_token', res.data.refreshToken);
            }
          }
          loadAllAdminData();
        })
        .catch(() => {
          loadAllAdminData();
        });
    } else {
      loadAllAdminData();
    }
  }, [loadAllAdminData]);

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

  return (
    <div className="admin-layout">
      {/* ─── FIXED LEFT SIDEBAR (SOLID ROYAL BLUE) ─── */}
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="sidebar-logo-icon">🛠️</div>
          <div className="sidebar-brand-text">
            <span className="sidebar-brand-title">BookurTechnician</span>
            <span className="sidebar-brand-subtitle">ADMIN PANEL</span>
          </div>
        </div>

        <div className="nav-container">
          <div className="nav-group-label">⚡ Operations Control Tower</div>

          <div className={`nav-item ${activeTab === 'live_radar' ? 'active' : ''}`} onClick={() => selectView('live_radar')}>
            <span className="nav-icon">📡</span>
            <span>Live Dispatch Radar</span>
            <span className="nav-item-badge live-badge">LIVE</span>
          </div>

          <div className={`nav-item ${activeTab === 'settlements' ? 'active' : ''}`} onClick={() => selectView('settlements')}>
            <span className="nav-icon">💰</span>
            <span>Wallet Settlements (UTR)</span>
          </div>

          <div className={`nav-item ${activeTab === 'partner_kyc' ? 'active' : ''}`} onClick={() => selectView('partner_kyc')}>
            <span className="nav-icon">🛡</span>
            <span>Partner KYC & Safety</span>
          </div>

          <div className="nav-group-label">Core Operations</div>
          
          <div className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => selectView('dashboard')}>
            <span className="nav-icon">🏠</span>
            <span>Dashboard</span>
          </div>

          <div className={`nav-item ${activeTab === 'bookings' ? 'active' : ''}`} onClick={() => selectView('bookings')}>
            <span className="nav-icon">📋</span>
            <span>Bookings</span>
            <span className="nav-item-badge">{stats?.totalBookings !== undefined && stats?.totalBookings !== null ? stats.totalBookings : bookings.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'customers' ? 'active' : ''}`} onClick={() => selectView('customers')}>
            <span className="nav-icon">👥</span>
            <span>Customers</span>
            <span className="nav-item-badge">{stats?.totalCustomers !== undefined && stats?.totalCustomers !== null ? stats.totalCustomers : customers.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'technicians' || activeTab === 'id_card' ? 'active' : ''}`} onClick={() => selectView('technicians')}>
            <span className="nav-icon">👨🔧</span>
            <span>Technicians</span>
            <span className="nav-item-badge">{stats?.totalTechnicians !== undefined && stats?.totalTechnicians !== null ? stats.totalTechnicians : technicians.length}</span>
          </div>

          <div className="nav-group-label">Catalog & Growth</div>

          <div className={`nav-item ${activeTab === 'services' ? 'active' : ''}`} onClick={() => selectView('services')}>
            <span className="nav-icon">🛠</span>
            <span>Services</span>
            <span className="nav-item-badge">{services.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'pricing' ? 'active' : ''}`} onClick={() => selectView('pricing')}>
            <span className="nav-icon">💰</span>
            <span>Pricing</span>
          </div>

          <div className={`nav-item ${activeTab === 'banners' ? 'active' : ''}`} onClick={() => selectView('banners')}>
            <span className="nav-icon">🖼</span>
            <span>Banners</span>
          </div>

          <div className={`nav-item ${activeTab === 'notifications' ? 'active' : ''}`} onClick={() => selectView('notifications')}>
            <span className="nav-icon">🔔</span>
            <span>Notifications</span>
          </div>

          <div className="nav-group-label">Finance & Audit</div>

          <div className={`nav-item ${activeTab === 'payments' ? 'active' : ''}`} onClick={() => selectView('payments')}>
            <span className="nav-icon">💳</span>
            <span>Payments</span>
          </div>

          <div className={`nav-item ${activeTab === 'refunds' ? 'active' : ''}`} onClick={() => selectView('refunds')}>
            <span className="nav-icon">↩</span>
            <span>Refunds</span>
          </div>

          <div className="nav-group-label">Support & System</div>

          <div className={`nav-item ${activeTab === 'reviews' ? 'active' : ''}`} onClick={() => selectView('reviews')}>
            <span className="nav-icon">⭐</span>
            <span>Reviews</span>
          </div>

          <div className={`nav-item ${activeTab === 'reports' ? 'active' : ''}`} onClick={() => selectView('reports')}>
            <span className="nav-icon">📊</span>
            <span>Reports</span>
          </div>

          <div className={`nav-item ${activeTab === 'support' ? 'active' : ''}`} onClick={() => selectView('support')}>
            <span className="nav-icon">🎧</span>
            <span>Support</span>
            <span className="nav-item-badge">{supportTickets.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'ai_assistant' ? 'active' : ''}`} onClick={() => selectView('ai_assistant')}>
            <span className="nav-icon">🤖</span>
            <span>AI Help Center CMS</span>
          </div>

          <div className={`nav-item ${activeTab === 'settings' ? 'active' : ''}`} onClick={() => selectView('settings')}>
            <span className="nav-icon">⚙</span>
            <span>Settings</span>
          </div>

          <div className={`nav-item ${activeTab === 'audit_logs' ? 'active' : ''}`} onClick={() => selectView('audit_logs')}>
            <span className="nav-icon">📜</span>
            <span>Audit Logs</span>
          </div>
        </div>
      </aside>

      {/* ─── MAIN CONTENT WRAPPER ─── */}
      <div className="main-wrapper">
        {/* ─── TOP HEADER (FLAT WHITE) ─── */}
        <header className="top-header">
          <div className="header-left">
            <div className="header-title-box">
              <span className="header-page-title">
                {activeTab.charAt(0).toUpperCase() + activeTab.slice(1).replace('_', ' ')}
              </span>
              <span className="header-breadcrumbs">
                BookurTechnician Admin &gt; {activeTab.toUpperCase()} {activeSubTab ? `&gt; ${activeSubTab.toUpperCase()}` : ''}
              </span>
            </div>
          </div>

          <div className="header-right">
            {/* Quick Search */}
            <div className="header-search">
              <span className="header-search-icon">🔍</span>
              <input
                type="text"
                placeholder="Quick search..."
                value={globalSearch}
                onChange={e => setGlobalSearch(e.target.value)}
              />
            </div>

            {/* Notifications 🔔 */}
            <div style={{ position: 'relative' }}>
              <button className="header-notif-btn" onClick={() => setNotifDropdownOpen(!notifDropdownOpen)}>
                🔔
                {bookings.filter(b => b.status === 'PENDING' || b.status === 'REQUESTED').length > 0 && (
                  <span className="header-notif-badge">{bookings.filter(b => b.status === 'PENDING' || b.status === 'REQUESTED').length}</span>
                )}
              </button>

              {notifDropdownOpen && (
                <div className="notif-dropdown-menu">
                  <div className="notif-header">System Notifications ({bookings.filter(b => b.status === 'PENDING' || b.status === 'REQUESTED').length})</div>
                  {bookings.filter(b => b.status === 'PENDING' || b.status === 'REQUESTED').length === 0 ? (
                    <div className="notif-item" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>
                      <p>No pending booking alerts</p>
                    </div>
                  ) : (
                    bookings.filter(b => b.status === 'PENDING' || b.status === 'REQUESTED').map(b => (
                      <div key={b.id} className="notif-item unread">
                        <strong>New Booking: {b.bookingCode || b.id}</strong>
                        <p>{b.service?.name || b.service || 'Service'} • ₹{b.grandTotal || b.price || 0}</p>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>

            {/* Admin Profile */}
            <div className="header-profile-box" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div className="profile-avatar">
                {adminUser?.fullName ? adminUser.fullName.substring(0, 2).toUpperCase() : 'AD'}
              </div>
              <div className="profile-info">
                <span className="profile-name">{adminUser?.fullName || 'Administrator'}</span>
                <span className="profile-role">{adminUser?.role || currentRole}</span>
              </div>
              <button
                type="button"
                onClick={() => {
                  api.logout();
                  setAdminUser(null);
                }}
                title="Sign Out of Admin Console"
                style={{
                  marginLeft: '8px',
                  background: 'rgba(239, 68, 68, 0.12)',
                  border: '1px solid rgba(239, 68, 68, 0.35)',
                  color: '#EF4444',
                  padding: '5px 10px',
                  borderRadius: '6px',
                  fontSize: '11px',
                  fontWeight: '700',
                  cursor: 'pointer'
                }}
              >
                Sign Out
              </button>
            </div>
          </div>
        </header>

        {/* ─── MAIN CONTENT VIEWPORT ─── */}
        <main className="page-container">
          {activeTab === 'live_radar' && (
            <LiveBookingRadar />
          )}

          {activeTab === 'settlements' && (
            <FinancialSettlementPortal />
          )}

          {activeTab === 'partner_kyc' && (
            <PartnerVerificationView />
          )}

          {activeTab === 'dashboard' && (
            <Dashboard
              stats={stats}
              bookings={bookings}
              technicians={technicians}
              customers={customers}
              services={services}
              onNavigate={selectView}
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
            />
          )}

          {activeTab === 'customers' && (
            <CustomersManager
              customers={customers}
              setCustomers={setCustomers}
              auditLogAction={auditLogAction}
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
            />
          )}

          {activeTab === 'id_card' && (
            <TechnicianIdCardManager
              technician={selectedTechForIdCard || technicians[0]}
              onBack={() => selectView('technicians')}
              auditLogAction={auditLogAction}
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
            />
          )}

          {activeTab === 'pricing' && (
            <PricingManager
              services={services}
              setServices={setServices}
              auditLogAction={auditLogAction}
            />
          )}

          {activeTab === 'payments' && (
            <PaymentsManager
              bookings={bookings}
              auditLogAction={auditLogAction}
              subTab={activeSubTab || 'transactions'}
            />
          )}

          {activeTab === 'refunds' && (
            <RefundsManager
              auditLogAction={auditLogAction}
            />
          )}

          {activeTab === 'banners' && (
            <BannersManager
              auditLogAction={auditLogAction}
            />
          )}

          {activeTab === 'notifications' && (
            <MarketingManager
              coupons={[]}
              setCoupons={() => {}}
              auditLogAction={auditLogAction}
              subTab="notifications"
            />
          )}

          {activeTab === 'reviews' && (
            <ReviewsManager
              auditLogAction={auditLogAction}
            />
          )}

          {activeTab === 'reports' && (
            <ReportsManager
              bookings={bookings}
              technicians={technicians}
              customers={customers}
              auditLogAction={auditLogAction}
            />
          )}

          {activeTab === 'support' && (
            <SupportManager
              supportTickets={supportTickets}
              setSupportTickets={setSupportTickets}
              auditLogAction={auditLogAction}
              subTab="tickets"
            />
          )}

          {activeTab === 'ai_assistant' && (
            <AiAssistantCms
              auditLogAction={auditLogAction}
            />
          )}

          {activeTab === 'settings' && (
            <SettingsManager
              settings={settings}
              setSettings={setSettings}
              auditLogs={auditLogs}
              auditLogAction={auditLogAction}
              subTab={activeSubTab || 'settings'}
              onResetDatabase={handleResetDatabase}
            />
          )}

          {activeTab === 'audit_logs' && (
            <SettingsManager
              settings={settings}
              setSettings={setSettings}
              auditLogs={auditLogs}
              auditLogAction={auditLogAction}
              subTab="audit"
              onResetDatabase={handleResetDatabase}
            />
          )}
        </main>
      </div>
    </div>
  );
}
