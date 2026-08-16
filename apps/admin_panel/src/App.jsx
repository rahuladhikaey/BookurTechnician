import React, { useState, useEffect } from 'react';

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

export default function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [activeSubTab, setActiveSubTab] = useState('');
  const [currentRole, setCurrentRole] = useState('Super Admin');
  const [notifDropdownOpen, setNotifDropdownOpen] = useState(false);
  const [globalSearch, setGlobalSearch] = useState('');

  // ─── STATE INITIALIZATION (EMPTY PRODUCTION STATES) ───
  const [categories, setCategories] = useState([]);
  const [services, setServices] = useState([]);
  const [technicians, setTechnicians] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [supportTickets, setSupportTickets] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);

  const [settings, setSettings] = useState({
    bookingCharge: 99,
    gstRate: 18,
    cancellationWindow: 1,
    refundSlaHours: 48
  });

  // Fetch real data on component mount
  useEffect(() => {
    const fetchAdminData = async () => {
      try {
        const token = localStorage.getItem('bt_admin_token');
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};

        // Fetch Technicians
        fetch('/api/v1/admin/technicians', { headers })
          .then(res => res.ok ? res.json() : null)
          .then(data => { if (data?.data) setTechnicians(data.data); })
          .catch(() => {});

        // Fetch Bookings
        fetch('/api/v1/admin/bookings', { headers })
          .then(res => res.ok ? res.json() : null)
          .then(data => { if (data?.data) setBookings(data.data); })
          .catch(() => {});

        // Fetch Customers
        fetch('/api/v1/admin/customers', { headers })
          .then(res => res.ok ? res.json() : null)
          .then(data => { if (data?.data) setCustomers(data.data); })
          .catch(() => {});

        // Fetch Catalog
        fetch('/api/v1/catalog/categories')
          .then(res => res.ok ? res.json() : null)
          .then(data => { if (data?.data) setCategories(data.data); })
          .catch(() => {});
      } catch (err) {
        console.error('Error fetching admin data:', err);
      }
    };

    fetchAdminData();
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

  const selectView = (tab, subTab = '') => {
    setActiveTab(tab);
    setActiveSubTab(subTab);
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
          <div className="nav-group-label">Core Operations</div>
          
          <div className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => selectView('dashboard')}>
            <span className="nav-icon">🏠</span>
            <span>Dashboard</span>
          </div>

          <div className={`nav-item ${activeTab === 'bookings' ? 'active' : ''}`} onClick={() => selectView('bookings')}>
            <span className="nav-icon">📋</span>
            <span>Bookings</span>
            <span className="nav-item-badge">{bookings.length}</span>
          </div>

          <div className={`nav-item ${activeTab === 'customers' ? 'active' : ''}`} onClick={() => selectView('customers')}>
            <span className="nav-icon">👥</span>
            <span>Customers</span>
          </div>

          <div className={`nav-item ${activeTab === 'technicians' ? 'active' : ''}`} onClick={() => selectView('technicians')}>
            <span className="nav-icon">👨🔧</span>
            <span>Technicians</span>
            <span className="nav-item-badge">{technicians.length}</span>
          </div>

          <div className="nav-group-label">Catalog & Growth</div>

          <div className={`nav-item ${activeTab === 'services' ? 'active' : ''}`} onClick={() => selectView('services')}>
            <span className="nav-icon">🛠</span>
            <span>Services</span>
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
                {bookings.filter(b => b.status === 'PENDING').length > 0 && (
                  <span className="header-notif-badge">{bookings.filter(b => b.status === 'PENDING').length}</span>
                )}
              </button>

              {notifDropdownOpen && (
                <div className="notif-dropdown-menu">
                  <div className="notif-header">System Notifications ({bookings.filter(b => b.status === 'PENDING').length})</div>
                  {bookings.filter(b => b.status === 'PENDING').length === 0 ? (
                    <div className="notif-item" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>
                      <p>No new system alerts</p>
                    </div>
                  ) : (
                    bookings.filter(b => b.status === 'PENDING').map(b => (
                      <div key={b.id} className="notif-item unread">
                        <strong>New Booking: {b.id}</strong>
                        <p>{b.service || b.category} • ₹{b.price || 0}</p>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>

            {/* Admin Profile */}
            <div className="header-profile-box">
              <div className="profile-avatar">BT</div>
              <div className="profile-info">
                <span className="profile-name">Operations Admin</span>
                <span className="profile-role">{currentRole}</span>
              </div>
            </div>
          </div>
        </header>

        {/* ─── MAIN CONTENT VIEWPORT ─── */}
        <main className="page-container">
          {activeTab === 'dashboard' && (
            <Dashboard
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
              onNavigateToIdCard={() => selectView('technicians')}
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
