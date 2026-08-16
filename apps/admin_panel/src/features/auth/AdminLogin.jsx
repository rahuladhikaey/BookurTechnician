import React, { useState, useEffect } from 'react';
import api from '../../api/apiClient';

export default function AdminLogin({ onLoginSuccess }) {
  const [step, setStep] = useState('EMAIL'); // 'EMAIL' | 'OTP'
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [resendTimer, setResendTimer] = useState(60);
  const [canResend, setCanResend] = useState(false);

  useEffect(() => {
    let timer;
    if (step === 'OTP' && resendTimer > 0) {
      timer = setInterval(() => {
        setResendTimer((prev) => {
          if (prev <= 1) {
            setCanResend(true);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [step, resendTimer]);

  const handleRequestOtp = async (e) => {
    e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedEmail = email.trim().toLowerCase();
    if (!trimmedEmail || !trimmedEmail.includes('@')) {
      setErrorMessage('Please provide a valid administrator email address.');
      return;
    }

    setIsLoading(true);
    try {
      await api.requestOtp(trimmedEmail, 'Admin', 'LOGIN');
      setSuccessMessage(`Verification code sent to ${trimmedEmail}`);
      setStep('OTP');
      setResendTimer(60);
      setCanResend(false);
    } catch (err) {
      setErrorMessage(err?.message || 'Unable to dispatch verification code. Please check server connectivity.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const trimmedOtp = otp.trim();
    if (trimmedOtp.length !== 6 || !/^\d+$/.test(trimmedOtp)) {
      setErrorMessage('Please enter the exact 6-digit numeric verification code.');
      return;
    }

    setIsLoading(true);
    try {
      const response = await api.verifyOtp(email.trim().toLowerCase(), trimmedOtp, 'ADMIN');
      const user = response?.data?.user;
      const accessToken = response?.data?.accessToken;
      const refreshToken = response?.data?.refreshToken;

      // Validate administrative role strictly
      const validAdminRoles = ['ADMIN', 'SUPER_ADMIN', 'FINANCE_ADMIN'];
      if (!user || !validAdminRoles.includes(user.role)) {
        api.clearToken();
        throw new Error('Administrator access is not configured.');
      }

      if (accessToken) {
        api.setToken(accessToken, true);
        if (refreshToken) {
          localStorage.setItem('bt_admin_refresh_token', refreshToken);
        }
      }

      onLoginSuccess(user);
    } catch (err) {
      setErrorMessage(err?.message || 'Administrator authentication failed.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleResendOtp = async () => {
    if (!canResend || isLoading) return;
    setErrorMessage('');
    setSuccessMessage('');
    setIsLoading(true);
    try {
      await api.requestOtp(email.trim().toLowerCase(), 'Admin', 'LOGIN');
      setSuccessMessage('A new verification code has been dispatched.');
      setResendTimer(60);
      setCanResend(false);
    } catch (err) {
      setErrorMessage(err?.message || 'Failed to resend code. Please try again.');
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
          <div style={styles.badge}>ADMINISTRATION CONSOLE</div>
          <p style={styles.subtitle}>
            Secure developer-provisioned access only. Authenticate with your authorized identity.
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

        {step === 'EMAIL' ? (
          <form onSubmit={handleRequestOtp} style={styles.form}>
            <div style={styles.inputGroup}>
              <label style={styles.label}>Administrator Email</label>
              <input
                type="email"
                placeholder="admin@bookurtechnician.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={styles.input}
                autoFocus
                disabled={isLoading}
                required
              />
            </div>

            <button
              type="submit"
              disabled={isLoading}
              style={{
                ...styles.primaryButton,
                opacity: isLoading ? 0.7 : 1,
                cursor: isLoading ? 'not-allowed' : 'pointer'
              }}
            >
              {isLoading ? 'Dispatching OTP...' : 'Request One-Time Password →'}
            </button>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp} style={styles.form}>
            <div style={styles.emailContext}>
              <span>Authenticating: <strong>{email}</strong></span>
              <button
                type="button"
                onClick={() => { setStep('EMAIL'); setOtp(''); setErrorMessage(''); }}
                style={styles.linkButton}
              >
                Change
              </button>
            </div>

            <div style={styles.inputGroup}>
              <label style={styles.label}>6-Digit Verification Code</label>
              <input
                type="text"
                placeholder="000000"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                style={styles.otpInput}
                autoFocus
                disabled={isLoading}
                required
              />
            </div>

            <button
              type="submit"
              disabled={isLoading || otp.length !== 6}
              style={{
                ...styles.primaryButton,
                opacity: isLoading || otp.length !== 6 ? 0.7 : 1,
                cursor: isLoading || otp.length !== 6 ? 'not-allowed' : 'pointer'
              }}
            >
              {isLoading ? 'Verifying Security Token...' : 'Authenticate & Access Dashboard'}
            </button>

            <div style={styles.resendRow}>
              {canResend ? (
                <button
                  type="button"
                  onClick={handleResendOtp}
                  disabled={isLoading}
                  style={styles.linkButton}
                >
                  Resend Verification Code
                </button>
              ) : (
                <span style={styles.timerText}>
                  Resend code in {resendTimer}s
                </span>
              )}
            </div>
          </form>
        )}

        {/* Security Footer Notice */}
        <div style={styles.securityFooter}>
          <span>🔒 Protected by Developer Key Verification & Cryptographic OTP</span>
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
    background: 'linear-gradient(135deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)',
    padding: '20px',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
  },
  card: {
    width: '100%',
    maxWidth: '440px',
    background: '#1E293B',
    borderRadius: '16px',
    border: '1px solid #334155',
    boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.05)',
    padding: '36px 32px',
    color: '#F8FAFC'
  },
  header: {
    textAlign: 'center',
    marginBottom: '28px'
  },
  logoBadge: {
    fontSize: '36px',
    marginBottom: '10px'
  },
  title: {
    fontSize: '22px',
    fontWeight: '800',
    color: '#FFFFFF',
    margin: '0 0 6px 0',
    letterSpacing: '-0.5px'
  },
  badge: {
    display: 'inline-block',
    padding: '3px 10px',
    background: 'rgba(33, 70, 168, 0.3)',
    border: '1px solid #2146A8',
    color: '#60A5FA',
    fontSize: '11px',
    fontWeight: '700',
    borderRadius: '20px',
    letterSpacing: '1px',
    marginBottom: '12px'
  },
  subtitle: {
    fontSize: '13px',
    color: '#94A3B8',
    margin: 0,
    lineHeight: '1.5'
  },
  errorAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 14px',
    background: 'rgba(239, 68, 68, 0.15)',
    border: '1px solid #EF4444',
    borderRadius: '8px',
    color: '#FCA5A5',
    fontSize: '13px',
    marginBottom: '20px',
    lineHeight: '1.4'
  },
  successAlert: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 14px',
    background: 'rgba(34, 197, 94, 0.15)',
    border: '1px solid #22C55E',
    borderRadius: '8px',
    color: '#86EFAC',
    fontSize: '13px',
    marginBottom: '20px',
    lineHeight: '1.4'
  },
  alertIcon: {
    fontSize: '16px',
    flexShrink: 0
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '18px'
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '6px'
  },
  label: {
    fontSize: '12.5px',
    fontWeight: '600',
    color: '#CBD5E1',
    textTransform: 'uppercase',
    letterSpacing: '0.5px'
  },
  input: {
    padding: '12px 14px',
    background: '#0F172A',
    border: '1px solid #475569',
    borderRadius: '8px',
    color: '#FFFFFF',
    fontSize: '14.5px',
    outline: 'none',
    transition: 'border-color 0.2s'
  },
  otpInput: {
    padding: '14px',
    background: '#0F172A',
    border: '2px solid #2146A8',
    borderRadius: '8px',
    color: '#60A5FA',
    fontSize: '24px',
    letterSpacing: '8px',
    textAlign: 'center',
    fontWeight: '800',
    outline: 'none'
  },
  emailContext: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: '13px',
    color: '#94A3B8',
    background: '#0F172A',
    padding: '8px 12px',
    borderRadius: '6px',
    border: '1px solid #334155'
  },
  primaryButton: {
    padding: '13px 18px',
    background: 'linear-gradient(135deg, #2146A8 0%, #1D4ED8 100%)',
    color: '#FFFFFF',
    border: 'none',
    borderRadius: '8px',
    fontSize: '14px',
    fontWeight: '700',
    boxShadow: '0 4px 12px rgba(33, 70, 168, 0.4)',
    transition: 'opacity 0.2s'
  },
  resendRow: {
    textAlign: 'center',
    marginTop: '4px'
  },
  linkButton: {
    background: 'none',
    border: 'none',
    color: '#60A5FA',
    fontSize: '13px',
    fontWeight: '600',
    cursor: 'pointer',
    textDecoration: 'underline'
  },
  timerText: {
    fontSize: '12.5px',
    color: '#64748B'
  },
  securityFooter: {
    marginTop: '28px',
    paddingTop: '16px',
    borderTop: '1px solid #334155',
    textAlign: 'center',
    fontSize: '11px',
    color: '#64748B'
  }
};
