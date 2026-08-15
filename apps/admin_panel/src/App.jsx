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

// ─── INITIAL BASELINE DATASETS ───
const INITIAL_CATEGORIES = [
  { id: 'cat_ac', name: 'AC Service', imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500', isActive: true },
  { id: 'cat_laptop', name: 'Laptop Service', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', isActive: true },
  { id: 'cat_fan', name: 'Fan Service', imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500', isActive: true },
  { id: 'cat_refrigerator', name: 'Refrigerator Service', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500', isActive: true },
  { id: 'cat_washing', name: 'Washing Machine Service', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500', isActive: true },
  { id: 'cat_lighting', name: 'Lighting Service', imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500', isActive: true }
];

const INITIAL_SERVICES = [
  { id: 'ac_install', name: 'New AC Installation', price: 1499, originalPrice: 1999, category: 'AC Service', durationMinutes: 90, rating: 4.8, reviewsCount: 120, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500', description: 'Professional split or window AC wall-mounting and alignment.' },
  { id: 'ac_clean', name: 'AC Deep Cleaning', price: 599, originalPrice: 899, category: 'AC Service', durationMinutes: 45, rating: 4.9, reviewsCount: 380, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500', description: 'Filters, jet pump cleaning, and cooling gas pressure diagnosis.' },
  { id: 'laptop_scr', name: 'Screen Replacement', price: 3499, originalPrice: 4999, category: 'Laptop Service', durationMinutes: 60, rating: 4.7, reviewsCount: 85, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', description: 'Genuine high-definition LCD screen replacement with 6 months warranty.' },
  { id: 'laptop_key', name: 'Keyboard Replacement', price: 1899, originalPrice: 2499, category: 'Laptop Service', durationMinutes: 45, rating: 4.8, reviewsCount: 94, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500', description: 'OEM replacement keys, testing, and alignment.' },
  { id: 'fan_install', name: 'Ceiling Fan Installation', price: 299, originalPrice: 499, category: 'Fan Service', durationMinutes: 30, rating: 4.8, reviewsCount: 420, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500', description: 'Quick assembly, hook connection, and regulator checking.' },
  { id: 'fridge_rep', name: 'Refrigerator Repair', price: 899, originalPrice: 1299, category: 'Refrigerator Service', durationMinutes: 60, rating: 4.6, reviewsCount: 140, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500', description: 'Compressor check, thermostat settings fix, and coolant refill.' },
  { id: 'wm_install', name: 'Washing Machine Install', price: 499, originalPrice: 699, category: 'Washing Machine Service', durationMinutes: 45, rating: 4.9, reviewsCount: 95, isActive: true, imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500', description: 'Inlet hose connection, drainage align, leveling check, and demo.' }
];

const INITIAL_TECHNICIANS = [
  { id: 'BT-TECH-000001', name: 'Rahul Adhikary', category: 'AC Service', status: 'Approved', onlineStatus: 'Online', rating: 4.9, completedJobs: 142, earnings: 42800, phone: '+91 98302-93821', photo: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400', kycStatus: 'Approved', experience: '5 years', location: 'Bengaluru, Hebbal', panCard: 'BPRPK9028L' },
  { id: 'BT-TECH-000002', name: 'Amit Singh', category: 'Fan Service', status: 'Approved', onlineStatus: 'Online', rating: 4.8, completedJobs: 64, earnings: 18400, phone: '+91 70032-19283', photo: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400', kycStatus: 'Approved', experience: '3 years', location: 'Bengaluru, Indiranagar', panCard: 'CPNPK1039B' },
  { id: 'BT-TECH-000003', name: 'Sunita Rao', category: 'Laptop Service', status: 'Pending', onlineStatus: 'Offline', rating: 4.6, completedJobs: 0, earnings: 0, phone: '+91 82938-10293', photo: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400', kycStatus: 'Pending', experience: '4 years', location: 'Bengaluru, Koramangala', panCard: 'APRPK4829K' },
  { id: 'BT-TECH-000004', name: 'Kabir Dev', category: 'Refrigerator Service', status: 'Approved', onlineStatus: 'Offline', rating: 4.7, completedJobs: 38, earnings: 24600, phone: '+91 99038-48291', photo: 'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?w=400', kycStatus: 'Approved', experience: '6 years', location: 'Bengaluru, Whitefield', panCard: 'ZPRPK9038L' }
];

const INITIAL_BOOKINGS = [
  { id: 'BT-BK-00001234', category: 'Laptop Service', service: 'Keyboard Replacement', customer: 'Rahul Customer', phone: '+91 99382-01938', technician: 'Rahul Adhikary', status: 'CONFIRMED', startOtp: '4821', price: 1899, date: '15 Aug 2026', timeSlot: '3:00 PM – 4:00 PM', paymentStatus: 'Paid', isRescheduled: false },
  { id: 'BT-BK-00001235', category: 'AC Service', service: 'AC Deep Cleaning', customer: 'Shreya Sharma', phone: '+91 88920-19283', technician: 'Rahul Adhikary', status: 'COMPLETED', startOtp: '1938', price: 599, date: '14 Aug 2026', timeSlot: '10:00 AM – 11:00 AM', paymentStatus: 'Paid', isRescheduled: false },
  { id: 'BT-BK-00001236', category: 'Refrigerator Service', service: 'Refrigerator Repair', customer: 'Vikas Kumar', phone: '+91 70029-48291', technician: 'None Assigned', status: 'PENDING', startOtp: '7482', price: 899, date: '15 Aug 2026', timeSlot: '05:00 PM – 06:00 PM', paymentStatus: 'Paid', isRescheduled: false }
];

const INITIAL_CUSTOMERS = [
  { id: 'CUST-301', name: 'Rahul Customer', email: 'rahul@gmail.com', phone: '+91 99382-01938', status: 'Active', totalBookings: 8, totalSpend: 14200, address: 'Hebbal, Bengaluru' },
  { id: 'CUST-302', name: 'Shreya Sharma', email: 'shreya@gmail.com', phone: '+91 88920-19283', status: 'Active', totalBookings: 3, totalSpend: 3450, address: 'Indiranagar, Bengaluru' },
  { id: 'CUST-303', name: 'Vikas Kumar', email: 'vikas@gmail.com', phone: '+91 70029-48291', status: 'Suspended', totalBookings: 1, totalSpend: 899, address: 'Koramangala, Bengaluru' }
];

const INITIAL_SUPPORT_TICKETS = [
  { id: 'TKT-101', customer: 'Vikas Kumar', bookingId: 'BT-BK-00001236', issueType: 'Technician Assignment Delay', description: 'Technician has not accepted the job even after 30 minutes of wait.', priority: 'High', assignedAgent: 'Unassigned', status: 'Open' },
  { id: 'TKT-102', customer: 'Rahul Customer', bookingId: 'BT-BK-00001234', issueType: 'Schedule Adjustment', description: 'Requesting adjustment of service slot to 3:30 PM.', priority: 'Medium', assignedAgent: 'Super Admin', status: 'In Progress' }
];

const INITIAL_AUDIT_LOGS = [
  { timestamp: '12:20:10 PM', module: 'System Initialization', action: 'Admin Console loaded production datasets.', operator: 'Super Admin' },
  { timestamp: '12:24:45 PM', module: 'Security', action: 'Technician App Icon & Digital ID verification tokens active.', operator: 'Super Admin' }
];

export default function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [activeSubTab, setActiveSubTab] = useState('');
  const [currentRole, setCurrentRole] = useState('Super Admin');
  const [notifDropdownOpen, setNotifDropdownOpen] = useState(false);
  const [globalSearch, setGlobalSearch] = useState('');

  // ─── STATE WITH LOCAL STORAGE PERSISTENCE ───
  const [categories, setCategories] = useState(() => {
    const s = localStorage.getItem('bt_categories');
    return s ? JSON.parse(s) : INITIAL_CATEGORIES;
  });

  const [services, setServices] = useState(() => {
    const s = localStorage.getItem('bt_services');
    return s ? JSON.parse(s) : INITIAL_SERVICES;
  });

  const [technicians, setTechnicians] = useState(() => {
    const s = localStorage.getItem('bt_technicians');
    return s ? JSON.parse(s) : INITIAL_TECHNICIANS;
  });

  const [bookings, setBookings] = useState(() => {
    const s = localStorage.getItem('bt_bookings');
    return s ? JSON.parse(s) : INITIAL_BOOKINGS;
  });

  const [customers, setCustomers] = useState(() => {
    const s = localStorage.getItem('bt_customers');
    return s ? JSON.parse(s) : INITIAL_CUSTOMERS;
  });

  const [supportTickets, setSupportTickets] = useState(() => {
    const s = localStorage.getItem('bt_support_tickets');
    return s ? JSON.parse(s) : INITIAL_SUPPORT_TICKETS;
  });

  const [auditLogs, setAuditLogs] = useState(() => {
    const s = localStorage.getItem('bt_audit_logs');
    return s ? JSON.parse(s) : INITIAL_AUDIT_LOGS;
  });

  const [settings, setSettings] = useState({
    bookingCharge: 99,
    gstRate: 18,
    cancellationWindow: 1,
    refundSlaHours: 48
  });

  // Save to LocalStorage
  useEffect(() => { localStorage.setItem('bt_categories', JSON.stringify(categories)); }, [categories]);
  useEffect(() => { localStorage.setItem('bt_services', JSON.stringify(services)); }, [services]);
  useEffect(() => { localStorage.setItem('bt_technicians', JSON.stringify(technicians)); }, [technicians]);
  useEffect(() => { localStorage.setItem('bt_bookings', JSON.stringify(bookings)); }, [bookings]);
  useEffect(() => { localStorage.setItem('bt_customers', JSON.stringify(customers)); }, [customers]);
  useEffect(() => { localStorage.setItem('bt_support_tickets', JSON.stringify(supportTickets)); }, [supportTickets]);
  useEffect(() => { localStorage.setItem('bt_audit_logs', JSON.stringify(auditLogs)); }, [auditLogs]);

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
    localStorage.clear();
    setCategories(INITIAL_CATEGORIES);
    setServices(INITIAL_SERVICES);
    setTechnicians(INITIAL_TECHNICIANS);
    setBookings(INITIAL_BOOKINGS);
    setCustomers(INITIAL_CUSTOMERS);
    setSupportTickets(INITIAL_SUPPORT_TICKETS);
    setAuditLogs([
      { timestamp: new Date().toLocaleTimeString(), module: 'Database Reset', action: 'Database reseeded to production defaults.', operator: currentRole }
    ]);
    alert('Sandbox database re-seeded successfully!');
    window.location.reload();
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
                <span className="header-notif-badge">3</span>
              </button>

              {notifDropdownOpen && (
                <div className="notif-dropdown-menu">
                  <div className="notif-header">System Notifications (3)</div>
                  <div className="notif-item unread">
                    <strong>New Booking: BT-BK-00001234</strong>
                    <p>Keyboard Replacement • Rahul Customer (₹1,899)</p>
                  </div>
                  <div className="notif-item unread">
                    <strong>Technician KYC: Sunita Rao</strong>
                    <p>Live photo & PAN card submitted for verification</p>
                  </div>
                  <div className="notif-item">
                    <strong>Refund SLA: REF-801</strong>
                    <p>48h SLA timer active (₹899.00)</p>
                  </div>
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
