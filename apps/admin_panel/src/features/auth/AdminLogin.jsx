import React, { useState } from 'react';
import api from '../../api/apiClient';

export default function AdminLogin({ onLoginSuccess }) {
  const [email, setEmail] = useState('');
  const [accessKey1, setAccessKey1] = useState('');
  const [accessKey2, setAccessKey2] = useState('');
  const [showKey1, setShowKey1] = useState(false);
  const [showKey2, setShowKey2] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Default system fallback keys
  const DEFAULT_KEY_1 = 'BT-ADMIN-KEY-PRIMARY-7788';
  const DEFAULT_KEY_2 = 'BT-ADMIN-KEY-SECONDARY-9900';

  const handleDirectAccess = async (e) => {
    e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedEmail = email.trim().toLowerCase();
    const trimmedKey1 = accessKey1.trim();
    const trimmedKey2 = accessKey2.trim();

    if (!trimmedEmail || !trimmedEmail.includes('@')) {
      setErrorMessage('Please enter a valid administrator access email address.');
      return;
    }

    if (!trimmedKey1) {
      setErrorMessage('Please enter Security Access Key 1.');
      return;
    }

    if (!trimmedKey2) {
      setErrorMessage('Please enter Security Access Key 2.');
      return;
    }

    setIsLoading(true);

    try {
      // 1. Direct Security Verification with Backend
      const response = await api.directAdminAccess(trimmedEmail, trimmedKey1, trimmedKey2);
      if (!response?.data?.accessToken) {
        throw new Error(response?.message || 'Authentication failed. Please check your credentials.');
      }

      const authUser = response.data.user;
      const accessToken = response.data.accessToken;
      const refreshToken = response.data.refreshToken;

      api.setToken(accessToken, true);
      if (refreshToken) {
        localStorage.setItem('bt_admin_refresh_token', refreshToken);
      }

      setSuccessMessage('Credentials verified successfully! Opening Admin Panel...');
      
      setTimeout(() => {
        onLoginSuccess(authUser);
      }, 300);

    } catch (err) {
      setErrorMessage(err?.message || 'Access Denied: Keys or email do not match authorized credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleFillDefaults = () => {
    if (!email) setEmail('admin@bookurtechnician.com');
    setAccessKey1(DEFAULT_KEY_1);
    setAccessKey2(DEFAULT_KEY_2);
    setErrorMessage('');
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        {/* Header Branding */}
        <div style={styles.header}>
          <div style={styles.logoBadge}>🛠️</div>
          <h1 style={styles.title}>BookurTechnician</h1>
          <div style={styles.badge}>DIRECT SECURITY ACCESS</div>
          <p style={styles.subtitle}>
            Enter authorized Administrator Email, Access Key 1, and Access Key 2 to open the Admin Panel.
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

        <form onSubmit={handleDirectAccess} style={styles.form}>
          {/* Email Field */}
          <div style={styles.inputGroup}>
            <label style={styles.label}>
              <span>Access Email</span>
              <span style={styles.reqBadge}>Required</span>
            </label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}>✉️</span>
              <input
                type="email"
                placeholder="admin@bookurtechnician.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={styles.inputWithIcon}
                autoFocus
                disabled={isLoading}
                required
              />
            </div>
          </div>

          {/* Access Key 1 */}
          <div style={styles.inputGroup}>
            <div style={styles.labelRow}>
              <label style={styles.label}>
                <span>Access Key 1</span>
                <span style={styles.reqBadge}>Primary</span>
              </label>
            </div>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}>🔑</span>
              <input
                type={showKey1 ? 'text' : 'password'}
                placeholder="Enter Access Key 1"
                value={accessKey1}
                onChange={(e) => setAccessKey1(e.target.value)}
                style={styles.inputWithIcon}
                disabled={isLoading}
                required
              />
              <button
                type="button"
                onClick={() => setShowKey1(!showKey1)}
                style={styles.eyeButton}
                title={showKey1 ? 'Hide Key' : 'Show Key'}
              >
                {showKey1 ? '👁️' : '🙈'}
              </button>
            </div>
          </div>

          {/* Access Key 2 */}
          <div style={styles.inputGroup}>
            <div style={styles.labelRow}>
              <label style={styles.label}>
                <span>Access Key 2</span>
                <span style={styles.reqBadge}>Secondary</span>
              </label>
            </div>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}>🛡️</span>
              <input
                type={showKey2 ? 'text' : 'password'}
                placeholder="Enter Access Key 2"
                value={accessKey2}
                onChange={(e) => setAccessKey2(e.target.value)}
                style={styles.inputWithIcon}
                disabled={isLoading}
                required
              />
              <button
                type="button"
                onClick={() => setShowKey2(!showKey2)}
                style={styles.eyeButton}
                title={showKey2 ? 'Hide Key' : 'Show Key'}
              >
                {showKey2 ? '👁️' : '🙈'}
              </button>
            </div>
          </div>

          {/* Action Button */}
          <button
            type="submit"
            disabled={isLoading || !email || !accessKey1 || !accessKey2}
            style={{
              ...styles.primaryButton,
              opacity: isLoading || !email || !accessKey1 || !accessKey2 ? 0.6 : 1,
              cursor: isLoading || !email || !accessKey1 || !accessKey2 ? 'not-allowed' : 'pointer'
            }}
          >
            {isLoading ? 'Verifying Security Keys...' : '🔓 Unlock Admin Panel →'}
          </button>
        </form>

        {/* Developer Quick Preset Helper */}
        <div style={styles.helperSection}>
          <div style={styles.helperHeader}>
            <span style={styles.helperTitle}>Quick Security Preset</span>
            <button
              type="button"
              onClick={handleFillDefaults}
              style={styles.quickFillButton}
            >
              Fill Default Keys
            </button>
          </div>
          <div style={styles.keyBox}>
            <div style={styles.keyItem}><strong>Key 1:</strong> <code>{DEFAULT_KEY_1}</code></div>
            <div style={styles.keyItem}><strong>Key 2:</strong> <code>{DEFAULT_KEY_2}</code></div>
          </div>
        </div>

        {/* Security Footer Notice */}
        <div style={styles.securityFooter}>
          <span>🔒 Protected by Dual-Key Cryptographic Authorization & Role Guard</span>
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
    backgroundColor: '#F8FAFC',
    padding: '24px 16px',
    fontFamily: "'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  },
  card: {
    width: '100%',
    maxWidth: '460px',
    backgroundColor: '#FFFFFF',
    borderRadius: '8px',
    border: '1px solid #E2E8F0',
    padding: '36px 32px',
    color: '#0F172A'
  },
  header: {
    textAlign: 'center',
    marginBottom: '26px'
  },
  logoBadge: {
    fontSize: '34px',
    marginBottom: '8px'
  },
  title: {
    fontSize: '22px',
    fontWeight: '800',
    color: '#1E40AF',
    margin: '0 0 6px 0',
    letterSpacing: '-0.4px'
  },
  badge: {
    display: 'inline-block',
    padding: '4px 10px',
    backgroundColor: '#EFF6FF',
    border: '1px solid #BFDBFE',
    color: '#1E40AF',
    fontSize: '11px',
    fontWeight: '800',
    borderRadius: '4px',
    letterSpacing: '0.8px',
    marginBottom: '10px'
  },
  subtitle: {
    fontSize: '13px',
    color: '#64748B',
    margin: 0,
    lineHeight: '1.5'
  },
  errorAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 14px',
    backgroundColor: '#FEF2F2',
    border: '1px solid #FCA5A5',
    borderRadius: '6px',
    color: '#DC2626',
    fontSize: '13px',
    marginBottom: '18px',
    lineHeight: '1.4'
  },
  successAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 14px',
    backgroundColor: '#ECFDF5',
    border: '1px solid #A7F3D0',
    borderRadius: '6px',
    color: '#15803D',
    fontSize: '13px',
    marginBottom: '18px',
    lineHeight: '1.4'
  },
  alertIcon: {
    fontSize: '16px',
    flexShrink: 0
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
  labelRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  label: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    fontSize: '12px',
    fontWeight: '700',
    color: '#334155',
    textTransform: 'uppercase',
    letterSpacing: '0.5px'
  },
  reqBadge: {
    fontSize: '10px',
    fontWeight: '600',
    color: '#1E40AF',
    backgroundColor: '#EFF6FF',
    padding: '2px 6px',
    borderRadius: '4px',
    textTransform: 'none',
    letterSpacing: 'normal'
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
    pointerEvents: 'none',
    opacity: 0.8
  },
  inputWithIcon: {
    width: '100%',
    padding: '11px 42px 11px 38px',
    backgroundColor: '#FFFFFF',
    border: '1px solid #CBD5E1',
    borderRadius: '6px',
    color: '#0F172A',
    fontSize: '14px',
    outline: 'none',
    transition: 'border-color 0.15s ease',
    boxSizing: 'border-box'
  },
  eyeButton: {
    position: 'absolute',
    right: '10px',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    padding: '4px',
    fontSize: '14px',
    opacity: 0.7,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center'
  },
  primaryButton: {
    marginTop: '6px',
    padding: '12px 20px',
    backgroundColor: '#1E40AF',
    color: '#FFFFFF',
    border: '1px solid #1E40AF',
    borderRadius: '6px',
    fontSize: '14px',
    fontWeight: '700',
    letterSpacing: '0.3px',
    transition: 'background-color 0.15s ease'
  },
  helperSection: {
    marginTop: '18px',
    backgroundColor: '#F8FAFC',
    border: '1px solid #E2E8F0',
    borderRadius: '6px',
    padding: '12px 14px'
  },
  helperHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '8px'
  },
  helperTitle: {
    fontSize: '11px',
    fontWeight: '700',
    color: '#64748B',
    textTransform: 'uppercase',
    letterSpacing: '0.5px'
  },
  quickFillButton: {
    backgroundColor: '#EFF6FF',
    border: '1px solid #BFDBFE',
    color: '#1E40AF',
    fontSize: '11px',
    fontWeight: '700',
    borderRadius: '4px',
    padding: '3px 8px',
    cursor: 'pointer'
  },
  keyBox: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
    fontSize: '11.5px',
    color: '#64748B'
  },
  keyItem: {
    wordBreak: 'break-all',
    fontFamily: 'monospace',
    color: '#334155'
  },
  securityFooter: {
    marginTop: '20px',
    paddingTop: '12px',
    borderTop: '1px solid #E2E8F0',
    textAlign: 'center',
    fontSize: '11px',
    color: '#64748B'
  }
};
