import React, { useState } from 'react';
import api from '../../api/apiClient';

export default function OtpDisputeModal({ booking, onClose, onSuccess }) {
  const [otpType, setOtpType] = useState('START'); // 'START' | 'END'
  const [reason, setReason] = useState('Customer unable to receive SMS/Email OTP due to cellular outage. Verified caller identity.');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const handleBypass = async () => {
    if (!reason || reason.trim().length < 5) {
      setError('A valid dispute verification reason (minimum 5 characters) is required for audit logs.');
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      const res = await api.emergencyBypassOtp(booking._id || booking.id, otpType, reason);
      if (res && (res.success || res.status === 200)) {
        if (onSuccess) onSuccess(res.message || 'OTP successfully bypassed');
        onClose();
      } else {
        setError(res?.message || 'Failed to bypass OTP.');
      }
    } catch (err) {
      console.error('OTP bypass error:', err);
      setError(err.message || 'OTP bypass request failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/75 backdrop-blur-sm p-4 overflow-y-auto animate-fadeIn">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-lg w-full shadow-2xl overflow-hidden text-slate-100">
        
        {/* Header */}
        <div className="px-6 py-4 bg-slate-800/80 border-b border-slate-700 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-9 h-9 rounded-xl bg-rose-500/20 border border-rose-500/40 flex items-center justify-center text-rose-400">
              <i className="fa-solid fa-key text-lg"></i>
            </div>
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                Emergency OTP Bypass & Dispute
              </h3>
              <p className="text-xs text-slate-400">
                Booking <span className="text-rose-400 font-mono font-semibold">{booking?.bookingCode || 'BT-JOB'}</span>
              </p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="w-8 h-8 rounded-lg bg-slate-700/50 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center transition-colors"
          >
            <i className="fa-solid fa-xmark"></i>
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-4">
          {error && (
            <div className="p-3 bg-rose-500/15 border border-rose-500/30 rounded-xl text-rose-300 text-xs flex items-center gap-2">
              <i className="fa-solid fa-triangle-exclamation text-rose-400"></i>
              <span>{error}</span>
            </div>
          )}

          <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700 text-xs space-y-1">
            <div className="flex justify-between">
              <span className="text-slate-400">Current Status:</span>
              <span className="font-semibold text-white uppercase">{booking?.status || 'UNKNOWN'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Customer:</span>
              <span className="text-slate-200">{booking?.customerName || 'N/A'} ({booking?.customerPhone || 'N/A'})</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Assigned Technician:</span>
              <span className="text-slate-200">{booking?.technician?.name || 'Assigned Partner'}</span>
            </div>
          </div>

          {/* Select OTP Stage */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-slate-300">Select OTP Stage to Authorize</label>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setOtpType('START')}
                className={`p-3 rounded-xl border text-left transition-all ${
                  otpType === 'START'
                    ? 'bg-rose-500/20 border-rose-500 text-white'
                    : 'bg-slate-800 border-slate-700 text-slate-400 hover:bg-slate-700/50'
                }`}
              >
                <div className="font-bold text-xs">3-Hour Start OTP</div>
                <div className="text-[11px] text-slate-400 mt-0.5">Move job to IN_PROGRESS</div>
              </button>

              <button
                type="button"
                onClick={() => setOtpType('END')}
                className={`p-3 rounded-xl border text-left transition-all ${
                  otpType === 'END'
                    ? 'bg-rose-500/20 border-rose-500 text-white'
                    : 'bg-slate-800 border-slate-700 text-slate-400 hover:bg-slate-700/50'
                }`}
              >
                <div className="font-bold text-xs">24-Hour End OTP</div>
                <div className="text-[11px] text-slate-400 mt-0.5">Complete & Credit Wallet</div>
              </button>
            </div>
          </div>

          {/* Dispute Reason */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-slate-300 flex items-center justify-between">
              <span>Dispute Justification & Caller Verification</span>
              <span className="text-rose-400 text-[10px]">*Mandatory Audit Trail</span>
            </label>
            <textarea
              rows={3}
              value={reason}
              onChange={e => setReason(e.target.value)}
              placeholder="State verified reason for customer support override..."
              className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-rose-500"
            ></textarea>
          </div>

          <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl text-amber-300 text-[11px] flex items-start gap-2">
            <i className="fa-solid fa-shield-halved text-amber-400 mt-0.5"></i>
            <span>
              This administrative action is recorded permanently in the platform immutable compliance ledger with your Admin ID, timestamp, and IP.
            </span>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 bg-slate-800/80 border-t border-slate-700 flex items-center justify-end space-x-3">
          <button
            onClick={onClose}
            disabled={submitting}
            className="px-4 py-2 rounded-xl bg-slate-700 hover:bg-slate-600 text-slate-300 text-xs font-medium"
          >
            Cancel
          </button>
          <button
            onClick={handleBypass}
            disabled={submitting || !reason}
            className="px-5 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 disabled:opacity-50 text-white text-xs font-bold shadow-lg shadow-rose-600/30 flex items-center gap-2"
          >
            {submitting ? (
              <>
                <i className="fa-solid fa-spinner fa-spin"></i>
                <span>Authorizing Bypass...</span>
              </>
            ) : (
              <>
                <i className="fa-solid fa-unlock-keyhole"></i>
                <span>Confirm {otpType} OTP Bypass</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
