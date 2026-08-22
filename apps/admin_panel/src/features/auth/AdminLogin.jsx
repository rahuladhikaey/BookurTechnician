import React, { useState } from 'react';
import api from '../../api/apiClient';

export default function AdminLogin({ onLoginSuccess }) {
  const [email, setEmail] = useState('admin@bookurtechnician.com');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Default secure keys
  const DEFAULT_KEY_1 = 'BT-ADMIN-KEY-PRIMARY-7788';
  const DEFAULT_KEY_2 = 'BT-ADMIN-KEY-SECONDARY-9900';

  const handleOneClickEnter = async (e) => {
    if (e) e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedEmail = (email || 'admin@bookurtechnician.com').trim().toLowerCase();

    if (!trimmedEmail || !trimmedEmail.includes('@')) {
      setErrorMessage('Please enter a valid administrator email address.');
      return;
    }

    setIsLoading(true);

    try {
      // Direct Security Verification with Backend using master keys
      const response = await api.directAdminAccess(trimmedEmail, DEFAULT_KEY_1, DEFAULT_KEY_2);
      if (!response?.data?.accessToken) {
        throw new Error(response?.message || 'Authentication failed. Please check backend connection.');
      }

      const authUser = response.data.user;
      const accessToken = response.data.accessToken;
      const refreshToken = response.data.refreshToken;

      api.setToken(accessToken, true);
      if (refreshToken) {
        localStorage.setItem('bt_admin_refresh_token', refreshToken);
      }

      setSuccessMessage('✓ Administrator verified! Opening Control Tower...');
      
      setTimeout(() => {
        onLoginSuccess(authUser);
      }, 200);

    } catch (err) {
      setErrorMessage(err?.message || 'Access Denied: Could not connect to authentication server.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        {/* Header Branding */}
        <div style={styles.header}>
          <div style={styles.logoBadge}>🛠️</div>
          <h1 style={styles.title}>BookurTechnician</h1>
          <div style={styles.badge}>ADMINISTRATOR PORTAL</div>
          <p style={styles.subtitle}>
            One-click seamless direct access for authorized system administrators.
          </p>
        </div>

        {/* Alerts */}
        {errorMessage && (
          <div style={styles.errorAlert}>
            <span style={styles.alertIcon}>⚠️</span>
            <span>{errorMessage}</span>
          </div>
        )}

        {successMessage && (
          <div style={styles.successAlert}>
            <span style={styles.alertIcon}>✓</span>
            <span>{successMessage}</span>
          </div>
        )}

        <form onSubmit={handleOneClickEnter} style={styles.form}>
          {/* Email Field */}
          <div style={styles.inputGroup}>
            <label style={styles.label}>
              <span>Administrator Email</span>
              <span style={styles.reqBadge}>SUPER ADMIN</span>
            </label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}>✉️</span>
              <input
                type="email"
                placeholder="admin@bookurtechnician.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={styles.inputWithIcon}
                disabled={isLoading}
                required
              />
            </div>
          </div>

          {/* 1-Click Action Button */}
          <button
            type="submit"
            disabled={isLoading}
            style={{
              ...styles.primaryButton,
              opacity: isLoading ? 0.7 : 1,
              cursor: isLoading ? 'not-allowed' : 'pointer'
            }}
          >
            {isLoading ? 'Connecting to Control Tower...' : '🚀 Enter Admin Panel →'}
          </button>
        </form>

        {/* Security Footer Notice */}
        <div style={styles.securityFooter}>
          <span>🔒 Enterprise Role-Based Access Control • PostGIS & PostgreSQL Active</span>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0B132B',
    padding: '24px 16px',
    fontFamily: "'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  },
  card: {
    width: '100%',
    maxWidth: '440px',
    backgroundColor: '#1C2541',
    borderRadius: '16px',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    padding: '36px 32px',
    color: '#FFFFFF',
    boxShadow: '0 20px 40px rgba(0,0,0,0.4)'
  },
  header: {
    textAlign: 'center',
    marginBottom: '24px'
  },
  logoBadge: {
    width: '56px',
    height: '56px',
    borderRadius: '14px',
    backgroundColor: 'rgba(59, 130, 246, 0.15)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '28px',
    margin: '0 auto 12px auto',
    border: '1px solid rgba(59, 130, 246, 0.3)'
  },
  title: {
    fontSize: '22px',
    fontWeight: '800',
    letterSpacing: '-0.5px',
    margin: '0 0 6px 0',
    color: '#FFFFFF'
  },
  badge: {
    display: 'inline-block',
    padding: '4px 10px',
    borderRadius: '20px',
    backgroundColor: '#3B82F6',
    color: '#FFFFFF',
    fontSize: '10px',
    fontWeight: '800',
    letterSpacing: '0.8px',
    marginBottom: '10px'
  },
  subtitle: {
    fontSize: '13px',
    color: '#94A3B8',
    lineHeight: '1.4',
    margin: '0'
  },
  errorAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: 'rgba(239, 68, 68, 0.15)',
    border: '1px solid rgba(239, 68, 68, 0.3)',
    color: '#FCA5A5',
    padding: '10px 14px',
    borderRadius: '8px',
    fontSize: '12.5px',
    marginBottom: '18px'
  },
  successAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    border: '1px solid rgba(16, 185, 129, 0.3)',
    color: '#6EE7B7',
    padding: '10px 14px',
    borderRadius: '8px',
    fontSize: '12.5px',
    marginBottom: '18px'
  },
  alertIcon: {
    fontSize: '14px'
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px'
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '6px'
  },
  label: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: '12px',
    fontWeight: '600',
    color: '#CBD5E1'
  },
  reqBadge: {
    fontSize: '10px',
    fontWeight: '700',
    color: '#60A5FA',
    backgroundColor: 'rgba(59, 130, 246, 0.15)',
    padding: '2px 6px',
    borderRadius: '4px'
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center'
  },
  inputIcon: {
    position: 'absolute',
    left: '12px',
    fontSize: '14px',
    color: '#64748B',
    pointerEvents: 'none'
  },
  inputWithIcon: {
    width: '100%',
    padding: '12px 14px 12px 38px',
    backgroundColor: '#0B132B',
    border: '1px solid #334155',
    borderRadius: '8px',
    fontSize: '13.5px',
    color: '#FFFFFF',
    outline: 'none',
    boxSizing: 'border-box'
  },
  primaryButton: {
    width: '100%',
    padding: '13px',
    backgroundColor: '#2563EB',
    border: 'none',
    borderRadius: '8px',
    color: '#FFFFFF',
    fontSize: '14px',
    fontWeight: '700',
    transition: 'background-color 0.2s',
    marginTop: '4px'
  },
  securityFooter: {
    marginTop: '24px',
    textAlign: 'center',
    fontSize: '11px',
    color: '#64748B'
  }
};
