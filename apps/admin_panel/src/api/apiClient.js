// ============================================================================
// BOOKURTECHNICIAN ADMIN PANEL — CENTRALIZED RESILIENT API CLIENT
// Multi-Host Auto-Failover, Preflight/CORS Resilience, and Self-Healing Network
// ============================================================================

import { handleFirestoreFallback } from './firestoreAdapter';

const API_CANDIDATE_HOSTS = [
  import.meta.env?.VITE_API_BASE_URL,
  import.meta.env?.VITE_API_URL,
  typeof window !== 'undefined' && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? 'http://localhost:4000/api/v1'
    : null,
].filter(Boolean);

class ApiClient {
  constructor() {
    const savedBaseUrl = typeof localStorage !== 'undefined' ? localStorage.getItem('bt_active_base_url') : null;
    const baseList = [...API_CANDIDATE_HOSTS];
    if (savedBaseUrl && !baseList.includes(savedBaseUrl)) {
      baseList.unshift(savedBaseUrl);
    } else if (savedBaseUrl) {
      // Prioritize saved working base URL
      const idx = baseList.indexOf(savedBaseUrl);
      if (idx > -1) {
        baseList.splice(idx, 1);
        baseList.unshift(savedBaseUrl);
      }
    }
    this.candidateUrls = baseList.filter(u => u && !u.includes('onrender.com') && !u.includes('api.bookurtechnician.online'));
    this.baseUrl = this.candidateUrls[0] || '';
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

    // List of URLs to attempt in priority order (empty when running in 100% Direct Firebase Mode)
    const urlsToTry = isFullUrl
      ? [endpoint]
      : this.candidateUrls.map(c => `${c}${normalizedEndpoint}`);

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
        // Fast 4.5s timeout signal per candidate attempt to prevent freezing
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 4500);
        
        const response = await fetch(targetUrl, {
          ...config,
          signal: options.signal || controller.signal,
        });
        clearTimeout(timeoutId);

        // Handle expired or invalid token - trigger callback and fail securely immediately (NEVER bypass to fallback!)
        if ((response.status === 401 || response.status === 403) && !targetUrl.includes('/auth/')) {
          console.warn(`[ApiClient] Authentication rejected (HTTP ${response.status}). Triggering unauthorized callback.`);
          if (this.onUnauthorizedCallback) {
            this.onUnauthorizedCallback();
          }
          this.clearToken();
          const authErr = new Error(`HTTP ${response.status}: Administrative authentication required. Please log in.`);
          authErr.isAuthError = true;
          authErr.status = response.status;
          throw authErr;
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

        // Remember the working base URL persistently
        const matchedBase = this.candidateUrls.find(c => targetUrl.startsWith(c));
        if (matchedBase && matchedBase !== this.baseUrl) {
          this.baseUrl = matchedBase;
          localStorage.setItem('bt_active_base_url', matchedBase);
          console.log(`[ApiClient] Switched active base URL to: ${matchedBase}`);
        } else if (matchedBase) {
          localStorage.setItem('bt_active_base_url', matchedBase);
        }

        return data;

      } catch (err) {
        lastError = err;
        // Never continue loop or attempt bypass when backend explicitly rejected authentication
        if (err?.isAuthError) {
          throw err;
        }
        console.warn(`[ApiClient] Attempt on ${targetUrl} failed: ${err.message}. Trying next candidate...`);
      }
    }

    // SECURITY: Administrative and authentication endpoints CANNOT fall back to Firestore.
    // Privileged admin operations must strictly validate against the authenticated backend.
    if (normalizedEndpoint.startsWith('/admin') || normalizedEndpoint.startsWith('/auth') || lastError?.isAuthError) {
      throw lastError || new Error(`Backend server required for administrative operations at ${normalizedEndpoint}.`);
    }

    // Automatic Direct Cloud Firestore Fallback (Read-Only Public Catalog Projection)
    try {
      let parsedBody = options.body;
      if (typeof parsedBody === 'string') {
        try { parsedBody = JSON.parse(parsedBody); } catch (_) {}
      }
      console.log(`🔥 [Firebase Direct] Serving public projection ${normalizedEndpoint} via Cloud Firestore (bookmytechnician-53d94)`);
      return await handleFirestoreFallback(normalizedEndpoint, options.method || 'GET', parsedBody);
    } catch (fbErr) {
      console.warn('[Firebase Direct] Fallback error:', fbErr);
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
  directAdminAccess(email, accessKey1, accessKey2 = null) {
    // SECURITY: Credentials must be entered dynamically by the user, never hardcoded in client source.
    if (!email || !accessKey1) {
      throw new Error('Authentication credentials required: Administrator email and access key must be provided.');
    }
    return this.post('/auth/admin/direct-access', {
      email,
      password: accessKey1,
      accessKey1,
      accessKey2: accessKey2 || accessKey1,
    });
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

  // Bookings & Dispatch Engine (Section 15 & 17)
  getBookings(params) { return this.get('/admin/bookings', params); }
  getBookingLiveTracking(id) { return this.get(`/admin/bookings/${id}/live-tracking`); }
  updateBookingStatus(id, status, extra = {}) { return this.patch(`/admin/bookings/${id}/status`, { status, ...extra }); }
  assignBooking(id, data) { return this.post(`/admin/bookings/${id}/assign`, typeof data === 'object' ? data : { technicianId: data }); }
  manualAssignDispatch(bookingId, technicianId, reason = 'ADMIN_MANUAL_ASSIGNMENT') {
    return this.post(`/dispatch/${bookingId}/manual-assign`, { technicianId, reason });
  }
  retryBookingDispatch(bookingId) { return this.post(`/dispatch/${bookingId}/retry`, {}); }
  getLiveDispatch() { return this.get('/admin/dispatch/live'); }
  getDispatchHistory(bookingId) { return this.get(`/admin/dispatch/${bookingId}/history`); }
  updateDispatchConfig(config) { return this.put('/admin/dispatch/config', config); }
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
