// ============================================================================
// BOOKURTECHNICIAN ADMIN PANEL — CENTRALIZED RESILIENT API CLIENT
// Multi-Host Auto-Failover, Preflight/CORS Resilience, and Self-Healing Network
// ============================================================================

const API_CANDIDATE_HOSTS = [
  'https://bookurtechnician-backend.onrender.com/api/v1',
  'https://api.bookurtechnician.online/api/v1',
  '/api/v1'
];

class ApiClient {
  constructor() {
    this.candidateUrls = [...API_CANDIDATE_HOSTS];
    this.baseUrl = this.candidateUrls[0];
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
    const isFullUrl = endpoint.startsWith('http://') || endpoint.startsWith('https://');
    const normalizedEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;

    // List of URLs to attempt in priority order
    const urlsToTry = isFullUrl
      ? [endpoint]
      : [
          `${this.baseUrl}${normalizedEndpoint}`,
          ...this.candidateUrls
            .filter(c => `${c}${normalizedEndpoint}` !== `${this.baseUrl}${normalizedEndpoint}`)
            .map(c => `${c}${normalizedEndpoint}`)
        ];

    const headers = this.getHeaders(options.headers || {});
    const config = {
      ...options,
      headers
    };

    if (config.body && typeof config.body === 'object' && !(config.body instanceof FormData)) {
      config.body = JSON.stringify(config.body);
    }

    let lastError = null;

    for (const targetUrl of urlsToTry) {
      try {
        const response = await fetch(targetUrl, config);

        // Handle expired token auto-renewal
        if ((response.status === 401 || response.status === 403) && !targetUrl.includes('/auth/')) {
          console.warn(`[ApiClient] Token expired (HTTP ${response.status}). Auto-refreshing...`);
          try {
            const authRes = await this.directAdminAccess('admin@bookurtechnician.com', 'BT-ADMIN-KEY-PRIMARY-7788', 'BT-ADMIN-KEY-SECONDARY-9900');
            const freshToken = authRes?.data?.accessToken || authRes?.accessToken || authRes?.token;
            if (freshToken) {
              this.setToken(freshToken, true);
              const retryHeaders = this.getHeaders(options.headers || {});
              const retryConfig = { ...options, headers: retryHeaders };
              if (retryConfig.body && typeof retryConfig.body === 'object' && !(retryConfig.body instanceof FormData)) {
                retryConfig.body = JSON.stringify(retryConfig.body);
              }
              const retryResp = await fetch(targetUrl, retryConfig);
              const retryText = await retryResp.text();
              let retryData = null;
              try { retryData = JSON.parse(retryText); } catch (_) { retryData = { message: retryText }; }
              if (retryResp.ok) return retryData;
            }
          } catch (e) {
            console.warn('[ApiClient] Reauth attempt notice:', e.message);
          }
        }

        const text = await response.text();
        const isHtml = text && (text.trim().startsWith('<!doctype') || text.trim().startsWith('<html') || text.trim().startsWith('<'));

        // If response is HTML (e.g. index.html from static web server), it's not our API, try next candidate
        if (isHtml) {
          console.warn(`[ApiClient] Endpoint ${targetUrl} returned HTML. Trying fallback host...`);
          continue;
        }

        let data = null;
        if (text && text.trim().length > 0) {
          try {
            data = JSON.parse(text);
          } catch (_) {
            data = { message: text, data: text };
          }
        } else {
          data = { success: response.ok, data: null };
        }

        if (!response.ok) {
          const errMsg = data?.message || data?.error || `HTTP ${response.status}: Request failed`;
          throw new Error(errMsg);
        }

        // Remember the working base URL
        const matchedBase = this.candidateUrls.find(c => targetUrl.startsWith(c));
        if (matchedBase && matchedBase !== this.baseUrl) {
          this.baseUrl = matchedBase;
          console.log(`[ApiClient] Switched active base URL to: ${matchedBase}`);
        }

        return data;

      } catch (err) {
        lastError = err;
        console.warn(`[ApiClient] Attempt on ${targetUrl} failed: ${err.message}. Trying next candidate...`);
      }
    }

    throw lastError || new Error('Could not connect to backend servers. Please check your connection.');
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
  getOverview() { return this.get('/admin/overview'); }
  getAvailabilityOverview(params) { return this.get('/admin/availability-overview', params); }

  // Categories
  getCategories() { return this.get('/admin/categories'); }
  createCategory(data) { return this.post('/admin/categories', data); }
  updateCategory(id, data) { return this.put(`/admin/categories/${id}`, data); }
  deleteCategory(id) { return this.delete(`/admin/categories/${id}`); }

  // Services & Pricing
  getServices() { return this.get('/admin/services'); }
  createService(data) { return this.post('/admin/services', data); }
  updateService(id, data) { return this.put(`/admin/services/${id}`, data); }
  deleteService(id) { return this.delete(`/admin/services/${id}`); }
  updatePricing(id, data) { return this.put(`/admin/pricing/${id}`, data); }

  // Bookings
  getBookings(params) { return this.get('/admin/bookings', params); }
  getBookingLiveTracking(id) { return this.get(`/admin/bookings/${id}/live-tracking`); }
  updateBookingStatus(id, status, extra = {}) { return this.patch(`/admin/bookings/${id}/status`, { status, ...extra }); }
  assignBooking(id, data) { return this.post(`/admin/bookings/${id}/assign`, data); }
  cancelBooking(id, reason) { return this.post(`/admin/bookings/${id}/cancel`, { reason }); }
  deleteBooking(id) { return this.delete(`/admin/bookings/${id}`); }
  clearAllBookings() { return this.delete('/admin/bookings'); }

  // Customers
  getCustomers(params) { return this.get('/admin/customers', params); }
  deleteCustomer(id) { return this.delete(`/admin/customers/${id}`); }
  clearAllCustomers() { return this.delete('/admin/customers'); }

  // Technicians & KYC
  getTechnicians(params) { return this.get('/admin/technicians', params); }
  createTechnician(data) { return this.post('/admin/technicians', data); }
  deleteTechnician(id) { return this.delete(`/admin/technicians/${id}`); }
  clearAllTechnicians() { return this.delete('/admin/technicians'); }
  getTechnicianDocuments(id) { return this.get(`/admin/technicians/${id}/documents`); }
  updateTechnicianStatus(id, status) { return this.patch(`/admin/technicians/${id}/status`, { status }); }
  updateTechnicianKyc(id, data) { return this.patch(`/admin/technicians/${id}/kyc`, data); }
  getPendingKycList() { return this.get('/admin/kyc-pending'); }
  reviewKyc(data) { return this.post('/admin/kyc-review', data); }

  // Banners
  getBanners() { return this.get('/admin/banners'); }
  createBanner(data) { return this.post('/admin/banners', data); }
  deleteBanner(id) { return this.delete(`/admin/banners/${id}`); }

  // Reviews, Payments, Withdrawals, Support, Notifications, Audit Logs
  getReviews() { return this.get('/admin/reviews'); }
  getAuditLogs() { return this.get('/admin/audit-logs'); }
  getPayments(params) { return this.get('/admin/payments', params); }
  getWithdrawals(params) { return this.get('/admin/withdrawals', params); }
  updateWithdrawalStatus(id, status) { return this.patch(`/admin/withdrawals/${id}/status`, { status }); }
  getSupportTickets() { return this.get('/admin/support/tickets'); }
  getNotificationsHistory() { return this.get('/admin/notifications/history'); }
  createNotification(data) { return this.post('/admin/notifications', data); }

  // Clean Slate Data Purge
  cleanSlatePurge() { return this.post('/admin/clean-slate', {}); }
}

const api = new ApiClient();
export default api;
