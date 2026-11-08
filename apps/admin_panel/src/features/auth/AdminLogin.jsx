import React, { useState } from 'react';
import api from '../../api/apiClient';

export default function AdminLogin({ onLoginSuccess }) {
  const [email, setEmail] = useState('admin@bookurtechnician.com');
  const [passkey, setPasskey] = useState('');
  const [showPasskey, setShowPasskey] = useState(false);
  const [loginMode, setLoginMode] = useState('passkey'); // 'passkey' | 'otp'
  const [otpCode, setOtpCode] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const handlePasskeySubmit = async (e) => {
    if (e) e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedEmail = (email || '').trim().toLowerCase();
    const trimmedPasskey = (passkey || '').trim();

    if (!trimmedEmail || !trimmedEmail.includes('@')) {
      setErrorMessage('Please enter a valid administrator email address.');
      return;
    }
    if (!trimmedPasskey) {
      setErrorMessage('Please enter your administrator passkey or security key.');
      return;
    }

    setIsLoading(true);

    try {
      // Authoritative Security Verification with Backend (Zero hardcoded secrets in bundle)
      const response = await api.directAdminAccess(trimmedEmail, trimmedPasskey);
      const accessToken = response?.accessToken || response?.token || response?.data?.accessToken || response?.data?.token;

      if (!accessToken) {
        throw new Error(response?.message || response?.error || 'Authentication failed. Invalid credentials.');
      }

      const authUser = response?.user || response?.data?.user || {
        id: 'admin-master-001',
        email: trimmedEmail,
        fullName: 'System Administrator',
        role: 'SUPER_ADMIN'
      };
      const refreshToken = response?.refreshToken || response?.data?.refreshToken;

      api.setToken(accessToken, true);
      if (refreshToken) {
        localStorage.setItem('bt_admin_refresh_token', refreshToken);
      }

      setSuccessMessage('✓ Administrator verified! Opening Control Tower...');
      
      setTimeout(() => {
        onLoginSuccess(authUser);
      }, 300);

    } catch (err) {
      console.error('Admin Login Error:', err);
      const msg = err?.message || '';
      if (msg.includes('Failed to fetch') || msg.includes('NetworkError') || msg.includes('Could not connect')) {
        setErrorMessage('Cannot connect to authentication backend server. Please verify backend is running.');
      } else {
        setErrorMessage(msg || 'Access Denied: Invalid administrator credentials.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleRequestOtp = async (e) => {
    if (e) e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedEmail = (email || '').trim().toLowerCase();
    if (!trimmedEmail || !trimmedEmail.includes('@')) {
      setErrorMessage('Please enter a valid administrator email address to receive OTP.');
      return;
    }

    setIsLoading(true);
    try {
      const res = await api.requestOtp(trimmedEmail, 'System Admin', 'LOGIN');
      if (res?.success) {
        setOtpSent(true);
        setSuccessMessage('✓ 6-Digit security OTP dispatched to registered administrator email.');
      } else {
        throw new Error(res?.error || res?.message || 'Failed to dispatch OTP.');
      }
    } catch (err) {
      setErrorMessage(err?.message || 'Failed to dispatch security OTP to admin email.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyOtp = async (e) => {
    if (e) e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedEmail = (email || '').trim().toLowerCase();
    const trimmedOtp = (otpCode || '').trim();

    if (!trimmedOtp || trimmedOtp.length < 6) {
      setErrorMessage('Please enter the 6-digit OTP received via email.');
      return;
    }

    setIsLoading(true);
    try {
      const response = await api.verifyOtp(trimmedEmail, trimmedOtp, 'ADMIN');
      const accessToken = response?.accessToken || response?.token || response?.data?.accessToken || response?.data?.token;

      if (!accessToken) {
        throw new Error(response?.message || response?.error || 'OTP verification failed.');
      }

      const authUser = response?.user || response?.data?.user || {
        id: 'admin-master-001',
        email: trimmedEmail,
        fullName: 'System Administrator',
        role: 'SUPER_ADMIN'
      };
      const refreshToken = response?.refreshToken || response?.data?.refreshToken;

      api.setToken(accessToken, true);
      if (refreshToken) {
        localStorage.setItem('bt_admin_refresh_token', refreshToken);
      }

      setSuccessMessage('✓ 2FA Verified! Opening Control Tower...');
      setTimeout(() => {
        onLoginSuccess(authUser);
      }, 300);
    } catch (err) {
      setErrorMessage(err?.message || 'Invalid or expired OTP. Please try again.');
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
            Secure cryptographic role-based access control for operations and dispatch command.
          </p>
        </div>

        {/* Tab Toggle: Passkey vs OTP */}
        <div style={styles.tabToggleRow}>
          <button
            type="button"
            onClick={() => { setLoginMode('passkey'); setErrorMessage(''); }}
            style={{
              ...styles.tabBtn,
              backgroundColor: loginMode === 'passkey' ? '#E85B08' : '#F5EBE1',
              color: loginMode === 'passkey' ? '#FFFFFF' : '#77716C',
            }}
          >
            🔑 Security Passkey
          </button>
          <button
            type="button"
            onClick={() => { setLoginMode('otp'); setErrorMessage(''); }}
            style={{
              ...styles.tabBtn,
              backgroundColor: loginMode === 'otp' ? '#E85B08' : '#F5EBE1',
              color: loginMode === 'otp' ? '#FFFFFF' : '#77716C',
            }}
          >
            ✉️ 2FA Email OTP
          </button>
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

        {loginMode === 'passkey' ? (
          <form onSubmit={handlePasskeySubmit} style={styles.form}>
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

            {/* Passkey / Secret Key Field */}
            <div style={styles.inputGroup}>
              <label style={styles.label}>
                <span>Security Passkey / Admin Secret</span>
                <span
                  style={{ cursor: 'pointer', fontSize: '11px', color: '#E85B08', fontWeight: '600' }}
                  onClick={() => setShowPasskey(!showPasskey)}
                >
                  {showPasskey ? 'Hide' : 'Show'}
                </span>
              </label>
              <div style={styles.inputWrapper}>
                <span style={styles.inputIcon}>🔒</span>
                <input
                  type={showPasskey ? 'text' : 'password'}
                  placeholder="Enter administrator passkey"
                  value={passkey}
                  onChange={(e) => setPasskey(e.target.value)}
                  style={styles.inputWithIcon}
                  disabled={isLoading}
                  required
                />
              </div>
            </div>

            {/* Submit Action Button */}
            <button
              type="submit"
              disabled={isLoading}
              style={{
                ...styles.primaryButton,
                opacity: isLoading ? 0.7 : 1,
                cursor: isLoading ? 'not-allowed' : 'pointer'
              }}
            >
              {isLoading ? 'Verifying Admin Authority...' : '🔐 Authenticate & Enter Portal →'}
            </button>
          </form>
        ) : (
          <form onSubmit={otpSent ? handleVerifyOtp : handleRequestOtp} style={styles.form}>
            {/* Email Field */}
            <div style={styles.inputGroup}>
              <label style={styles.label}>
                <span>Registered Admin Email</span>
                <span style={styles.reqBadge}>2FA REQUIRED</span>
              </label>
              <div style={styles.inputWrapper}>
                <span style={styles.inputIcon}>✉️</span>
                <input
                  type="email"
                  placeholder="admin@bookurtechnician.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={styles.inputWithIcon}
                  disabled={isLoading || otpSent}
                  required
                />
              </div>
            </div>

            {otpSent && (
              <div style={styles.inputGroup}>
                <label style={styles.label}>
                  <span>6-Digit Verification Code</span>
                  <button
                    type="button"
                    onClick={handleRequestOtp}
                    disabled={isLoading}
                    style={{ background: 'none', border: 'none', color: '#E85B08', fontSize: '11px', cursor: 'pointer', fontWeight: '600' }}
                  >
                    Resend Code
                  </button>
                </label>
                <div style={styles.inputWrapper}>
                  <span style={styles.inputIcon}>🔢</span>
                  <input
                    type="text"
                    maxLength={6}
                    placeholder="123456"
                    value={otpCode}
                    onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                    style={styles.inputWithIcon}
                    disabled={isLoading}
                    autoFocus
                    required
                  />
                </div>
              </div>
            )}

            <button
              type="submit"
              disabled={isLoading}
              style={{
                ...styles.primaryButton,
                opacity: isLoading ? 0.7 : 1,
                cursor: isLoading ? 'not-allowed' : 'pointer'
              }}
            >
              {isLoading
                ? 'Processing...'
                : otpSent
                ? '✓ Verify 2FA & Access Control Tower'
                : '📨 Send Secure 2FA Code →'}
            </button>
          </form>
        )}

        {/* Security Footer Notice */}
        <div style={styles.securityFooter}>
          <span>🔒 Cryptographic Role-Based Access Control • Zero Hardcoded Secrets</span>
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
    backgroundColor: '#FCF9F6',
    padding: '24px 16px',
    fontFamily: "'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  },
  card: {
    width: '100%',
    maxWidth: '440px',
    backgroundColor: '#FFFFFF',
    borderRadius: '20px',
    border: '1px solid #EEE8E2',
    padding: '36px 32px',
    color: '#222222',
    boxShadow: '0 16px 36px rgba(34, 34, 34, 0.08)'
  },
  header: {
    textAlign: 'center',
    marginBottom: '24px'
  },
  logoBadge: {
    width: '56px',
    height: '56px',
    borderRadius: '14px',
    backgroundColor: '#FBE4D5',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '28px',
    margin: '0 auto 12px auto',
    border: '1px solid rgba(244, 107, 18, 0.3)'
  },
  title: {
    fontSize: '22px',
    fontWeight: '800',
    letterSpacing: '-0.5px',
    margin: '0 0 6px 0',
    color: '#222222'
  },
  badge: {
    display: 'inline-block',
    padding: '4px 12px',
    borderRadius: '20px',
    backgroundColor: '#FBE4D5',
    color: '#E85B08',
    fontSize: '10px',
    fontWeight: '800',
    letterSpacing: '0.8px',
    marginBottom: '10px'
  },
  subtitle: {
    fontSize: '13px',
    color: '#77716C',
    lineHeight: '1.4',
    margin: '0'
  },
  tabToggleRow: {
    display: 'flex',
    gap: '8px',
    backgroundColor: '#F5EBE1',
    padding: '4px',
    borderRadius: '12px',
    marginBottom: '20px'
  },
  tabBtn: {
    flex: 1,
    padding: '8px 12px',
    borderRadius: '8px',
    border: 'none',
    fontSize: '12px',
    fontWeight: '700',
    cursor: 'pointer',
    transition: 'all 0.2s'
  },
  errorAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: '#FDECEC',
    border: '1px solid rgba(220, 53, 69, 0.3)',
    color: '#DC3545',
    padding: '10px 14px',
    borderRadius: '10px',
    fontSize: '12.5px',
    marginBottom: '18px'
  },
  successAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: '#E8F5E9',
    border: '1px solid rgba(25, 135, 84, 0.3)',
    color: '#198754',
    padding: '10px 14px',
    borderRadius: '10px',
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
    fontWeight: '700',
    color: '#222222'
  },
  reqBadge: {
    fontSize: '10px',
    fontWeight: '800',
    color: '#E85B08',
    backgroundColor: '#FBE4D5',
    padding: '2px 6px',
    borderRadius: '6px'
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
    color: '#77716C',
    pointerEvents: 'none'
  },
  inputWithIcon: {
    width: '100%',
    padding: '12px 14px 12px 38px',
    backgroundColor: '#FCF9F6',
    border: '1.5px solid #EEE8E2',
    borderRadius: '10px',
    fontSize: '13.5px',
    color: '#222222',
    outline: 'none',
    boxSizing: 'border-box'
  },
  primaryButton: {
    width: '100%',
    padding: '14px',
    backgroundColor: '#F46B12',
    border: 'none',
    borderRadius: '12px',
    color: '#FFFFFF',
    fontSize: '14px',
    fontWeight: '800',
    transition: 'background-color 0.2s',
    boxShadow: '0 4px 14px rgba(244, 107, 18, 0.25)',
    marginTop: '4px'
  },
  securityFooter: {
    marginTop: '24px',
    textAlign: 'center',
    fontSize: '11px',
    color: '#77716C'
  }
};
