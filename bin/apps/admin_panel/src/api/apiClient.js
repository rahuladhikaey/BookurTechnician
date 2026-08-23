// ============================================================================
// BOOKURTECHNICIAN ADMIN PANEL — CENTRALIZED API CLIENT
// Production-Ready Token Interception, Error Handling, and REST Integration
// ============================================================================

const PRIMARY_API_BASE_URL = 'https://api.bookurtechnician.online/api/v1';
const FALLBACK_API_BASE_URL = 'https://bookurtechnician-backend.onrender.com/api/v1';

const getInitialBaseUrl = () => {
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }
  if (typeof window !== 'undefined') {
    return '/api/v1';
  }
  return PRIMARY_API_BASE_URL;
};

const API_BASE_URL = getInitialBaseUrl();

class ApiClient {
  constructor() {
    this.baseUrl = API_BASE_URL;
    this.fallbackBaseUrl = FALLBACK_API_BASE_URL;
    this.onUnauthorizedCallback = null;
  }

  onUnauthorized(callback) {
    this.onUnauthorizedCallback = callback;
  }

  getToken() {
    return localStorage.getItem('bt_admin_token') || sessionStorage.getItem('bt_admin_token') || '';
  }

  setToken(token, persist = true) {
    if (persist) {
      localStorage.setItem('bt_admin_token', token);
    } else {
      sessionStorage.setItem('bt_admin_token', token);
    }
  }

  clearToken() {
    localStorage.removeItem('bt_admin_token');
    localStorage.removeItem('bt_admin_refresh_token');
    sessionStorage.removeItem('bt_admin_token');
  }

  getHeaders(customHeaders = {}) {
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...customHeaders
    };
    const token = this.getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  async request(endpoint, options = {}) {
    let url = endpoint.startsWith('http') ? endpoint : `${this.baseUrl}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
    const headers = this.getHeaders(options.headers || {});

    const config = {
      ...options,
      headers
    };

    if (config.body && typeof config.body === 'object' && !(config.body instanceof FormData)) {
      config.body = JSON.stringify(config.body);
    }

    try {
      let response;
      try {
        response = await fetch(url, config);
      } catch (fetchErr) {
        if (url.includes('api.bookurtechnician.online')) {
          const fallbackUrl = url.replace('https://api.bookurtechnician.online/api/v1', this.fallbackBaseUrl);
          console.warn(`Primary API unreachable. Retrying with fallback: ${fallbackUrl}`);
          response = await fetch(fallbackUrl, config);
        } else {
          throw fetchErr;
        }
      }

      if (response.status === 401) {
        console.warn('Unauthorized request to:', url);
        if (this.onUnauthorizedCallback && !url.includes('/auth/verify-otp') && !url.includes('/auth/request-otp') && !url.includes('/auth/admin/direct-access')) {
          this.onUnauthorizedCallback();
        }
      }

      const text = await response.text();
      let data = null;
      if (text && text.trim().length > 0) {
        try {
          data = JSON.parse(text);
        } catch (e) {
          data = { message: text, data: text };
        }
      } else {
        data = { success: response.ok, data: null };
      }

      if (!response.ok) {
        const errorMessage = data?.message || data?.error || `HTTP ${response.status}: Request failed`;
        throw new Error(errorMessage);
      }

      return data;
    } catch (error) {
      console.error(`API Error on [${options.method || 'GET'}] ${url}:`, error.message);
      throw error;
    }
  }

  get(endpoint, params = {}) {
    let url = endpoint;
    const query = new URLSearchParams();
    Object.entries(params).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') {
        query.append(k, v);
      }
    });
    const queryString = query.toString();
    if (queryString) {
      url += (url.includes('?') ? '&' : '?') + queryString;
    }
    return this.request(url, { method: 'GET' });
  }

  post(endpoint, body) {
    return this.request(endpoint, { method: 'POST', body });
  }

  put(endpoint, body) {
    return this.request(endpoint, { method: 'PUT', body });
  }

  patch(endpoint, body) {
    return this.request(endpoint, { method: 'PATCH', body });
  }

  delete(endpoint) {
    return this.request(endpoint, { method: 'DELETE' });
  }

  // ─── AUTHENTICATION METHODS ───────────────────────────────────────────────
  directAdminAccess(email, accessKey1, accessKey2) {
    return this.post('/auth/admin/direct-access', { email, accessKey1, accessKey2 });
  }

  requestOtp(email, name = 'Admin', purpose = 'LOGIN') {
    return this.post('/auth/request-otp', { email, name, purpose });
  }

  verifyOtp(email, otp, role = 'ADMIN') {
    return this.post('/auth/verify-otp', { email, otp, role, purpose: 'LOGIN' });
  }

  logout() {
    const refreshToken = localStorage.getItem('bt_admin_refresh_token');
    if (refreshToken) {
      this.post('/auth/logout', { refreshToken }).catch(() => {});
    }
    this.clearToken();
  }

  // ─── ADMIN CONVENIENCE METHODS ─────────────────────────────────────────────
  getAdminMe() { return this.get('/admin/me'); }
  getStats() { return this.get('/admin/stats'); }
  getCustomers(params) { return this.get('/admin/customers', params); }
  updateCustomerStatus(id, status) { return this.patch(`/admin/customers/${id}/status`, { status }); }

  getTechnicians(params) { return this.get('/admin/technicians', params); }
  getTechnicianById(id) { return this.get(`/admin/technicians/${id}`); }
  createTechnician(data) { return this.post('/admin/technicians', data); }
  getOnlineTechnicians() { return this.get('/admin/technicians/online'); }
  getTechnicianDocuments(id) { return this.get(`/admin/technicians/${id}/documents`); }
  getTechnicianSkills(techId) { return this.get(`/technician/skills/technician/${techId}`); }
  verifyTechnicianSkill(technicianSkillId, status, rejectionReason = '') {
    return this.post(`/technician/skills/admin/${technicianSkillId}/verify`, { status, rejectionReason });
  }
  updateKyc(id, status, reason = '') { return this.patch(`/admin/technicians/${id}/kyc`, { status, reason }); }
  updateTechnicianStatus(id, status) { return this.patch(`/admin/technicians/${id}/status`, { status }); }

  getBookings(params) { return this.get('/admin/bookings', params); }
  assignBooking(id, technicianId) { return this.post(`/admin/bookings/${id}/assign`, { technicianId }); }
  updateBookingStatus(id, status) { return this.patch(`/admin/bookings/${id}/status`, { status }); }
  cancelBooking(id, reason) { return this.post(`/admin/bookings/${id}/cancel`, { reason }); }

  getCategories() { return this.get('/admin/categories'); }
  createCategory(category) { return this.post('/admin/categories', category); }
  updateCategory(id, category) { return this.put(`/admin/categories/${id}`, category); }
  deleteCategory(id) { return this.delete(`/admin/categories/${id}`); }

  getServices() { return this.get('/admin/services'); }
  createService(service) { return this.post('/admin/services', service); }
  updateService(id, service) { return this.put(`/admin/services/${id}`, service); }
  deleteService(id) { return this.delete(`/admin/services/${id}`); }
  updatePricing(serviceId, data) { return this.put(`/admin/pricing/${serviceId}`, data); }

  getPayments() { return this.get('/admin/payments'); }
  getRefunds() { return this.get('/admin/refunds'); }
  updateRefundStatus(id, status) { return this.patch(`/admin/refunds/${id}/status`, { status }); }
  getWithdrawals() { return this.get('/admin/withdrawals'); }
  updateWithdrawalStatus(id, status, utrNumber = '') { return this.patch(`/admin/withdrawals/${id}/status`, { status, utrNumber }); }

  getReviews() { return this.get('/admin/reviews'); }
  toggleHideReview(id) { return this.patch(`/admin/reviews/${id}/hide`); }
  toggleFlagReview(id) { return this.patch(`/admin/reviews/${id}/flag`); }

  getBanners() { return this.get('/admin/banners'); }
  createBanner(banner) { return this.post('/admin/banners', banner); }
  updateBanner(id, banner) { return this.put(`/admin/banners/${id}`, banner); }
  deleteBanner(id) { return this.delete(`/admin/banners/${id}`); }

  getSupportTickets(params) { return this.get('/admin/support/tickets', params); }
  updateTicketStatus(id, status, resolutionNotes = '') { return this.patch(`/admin/support/tickets/${id}/status`, { status, resolutionNotes }); }

  getNotifications() { return this.get('/admin/notifications/history'); }
  createNotification(data) { return this.post('/admin/notifications', data); }

  getAiDocs() { return this.get('/admin/ai/documents'); }
  createAiDoc(doc) { return this.post('/admin/ai/documents', doc); }
  deleteAiDoc(id) { return this.delete(`/admin/ai/documents/${id}`); }
  getAiFaqs() { return this.get('/admin/ai/faqs'); }
  createAiFaq(faq) { return this.post('/admin/ai/faqs', faq); }
  deleteAiFaq(id) { return this.delete(`/admin/ai/faqs/${id}`); }

  getAuditLogs() { return this.get('/admin/audit-logs'); }
  
  // ─── SKILL HIERARCHY & VERIFICATION APIs ───
  getSkillsHierarchy() { return this.get('/catalog/hierarchy'); }
  getSkills() { return this.get('/catalog/skills'); }
  createSkill(skill) { return this.post('/catalog/admin/skills', skill); }
  updateSkill(id, skill) { return this.put(`/catalog/admin/skills/${id}`, skill); }
  deleteSkill(id) { return this.delete(`/catalog/admin/skills/${id}`); }
  getSkillCompatibility(skillId) { return this.get(`/catalog/admin/skills/${skillId}/compatibility`); }
  updateSkillCompatibility(skillId, serviceItemIds) { return this.put(`/catalog/admin/skills/${skillId}/compatibility`, { serviceItemIds }); }
  getMatchingRules() { return this.get('/catalog/admin/matching-rules'); }
  updateMatchingRules(rules) { return this.put('/catalog/admin/matching-rules', rules); }

  // ─── CONTROL TOWER & OPERATIONS MANAGEMENT APIs ───
  getControlTowerOverview() { return this.get('/admin/stats/overview'); }
  getLiveBookingsRadar(params = {}) { return this.get('/admin/bookings/live', params); }
  getNearbyTechniciansForBooking(bookingId) { return this.get(`/admin/bookings/${bookingId}/nearby-technicians`); }
  forceAssignBooking(bookingId, technicianId, reason = '') {
    return this.post(`/admin/bookings/${bookingId}/force-assign`, { technicianId, reason });
  }
  releaseWalletPayout(payoutData) {
    return this.post('/admin/payouts/release', payoutData);
  }
  getPayoutTransactions(technicianId = 'all', params = {}) {
    return this.get(`/admin/payouts/history/${technicianId}`, params);
  }
  updatePartnerKycStatus(partnerId, statusData) {
    return this.patch(`/admin/partners/${partnerId}/status`, statusData);
  }
  emergencyBypassOtp(bookingId, otpType, reason) {
    return this.post(`/admin/bookings/${bookingId}/bypass-otp`, { otpType, reason });
  }
}

export const api = new ApiClient();
export default api;
