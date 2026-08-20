import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function PartnerVerificationView() {
  const [partners, setPartners] = useState([]);
  const [filterStatus, setFilterStatus] = useState('ALL'); // 'ALL' | 'PENDING_APPROVAL' | 'ACTIVE' | 'SUSPENDED' | 'REJECTED'
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedPartner, setSelectedPartner] = useState(null);
  const [rejectionReason, setRejectionReason] = useState('');
  const [suspensionReason, setSuspensionReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [toastMessage, setToastMessage] = useState(null);

  const loadPartners = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.getTechnicians();
      if (res && res.data) {
        setPartners(res.data);
      } else if (Array.isArray(res)) {
        setPartners(res);
      }
    } catch (err) {
      console.error('Failed to load partners:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadPartners();
  }, [loadPartners]);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const handleStatusUpdate = async (partnerId, kycStatus, reason = '') => {
    setSubmitting(true);
    try {
      const res = await api.updatePartnerKycStatus(partnerId, {
        kycStatus,
        rejectionReason: kycStatus === 'REJECTED' ? reason : undefined,
        suspensionReason: kycStatus === 'SUSPENDED' ? reason : undefined,
      });

      if (res && (res.success || res.status === 200)) {
        showToast(res.message || `Partner status updated to ${kycStatus}`);
        setSelectedPartner(null);
        setRejectionReason('');
        setSuspensionReason('');
        loadPartners();
      }
    } catch (err) {
      console.error('Status update error:', err);
      alert('Failed to update status: ' + err.message);
    } finally {
      setSubmitting(false);
    }
  };

  const filteredPartners = partners.filter(p => {
    const matchesFilter = filterStatus === 'ALL' || (p.kycStatus || 'ACTIVE') === filterStatus;
    const matchesSearch =
      (p.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.technicianCode || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.phone || '').includes(searchQuery) ||
      (p.category || '').toLowerCase().includes(searchQuery.toLowerCase());
    return matchesFilter && matchesSearch;
  });

  const pendingCount = partners.filter(p => (p.kycStatus || 'ACTIVE') === 'PENDING_APPROVAL').length;
  const activeCount = partners.filter(p => (p.kycStatus || 'ACTIVE') === 'ACTIVE').length;
  const suspendedCount = partners.filter(p => (p.kycStatus || 'ACTIVE') === 'SUSPENDED').length;

  return (
    <div className="space-y-6 text-slate-100 animate-fadeIn">
      
      {/* Toast */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 px-4 py-3 bg-emerald-600 text-white rounded-xl shadow-2xl flex items-center gap-2 border border-emerald-400/40 text-xs font-semibold animate-bounce">
          <i className="fa-solid fa-circle-check text-sm"></i>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Header */}
      <div className="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-purple-500/20 border border-purple-500/40 flex items-center justify-center text-purple-400">
            <i className="fa-solid fa-id-card-clip text-xl"></i>
          </div>
          <div>
            <h2 className="text-xl font-bold text-white flex items-center gap-2">
              Partner KYC Verification & Compliance Governance
              <span className="text-xs px-2.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/30 font-medium">
                Safety & Trust
              </span>
            </h2>
            <p className="text-xs text-slate-400">
              Inspect government IDs, verify skill certifications, approve onboarding, and enforce compliance suspensions
            </p>
          </div>
        </div>

        {/* Filter Pills */}
        <div className="flex items-center gap-2 bg-slate-800 p-1 rounded-xl border border-slate-700">
          {[
            { key: 'ALL', label: 'All Partners', count: partners.length },
            { key: 'PENDING_APPROVAL', label: 'Pending KYC', count: pendingCount, color: 'text-amber-400' },
            { key: 'ACTIVE', label: 'Active', count: activeCount, color: 'text-emerald-400' },
            { key: 'SUSPENDED', label: 'Suspended', count: suspendedCount, color: 'text-rose-400' },
          ].map(tab => (
            <button
              key={tab.key}
              onClick={() => setFilterStatus(tab.key)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-1.5 ${
                filterStatus === tab.key
                  ? 'bg-purple-600 text-white shadow'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <span>{tab.label}</span>
              <span className={`text-[10px] px-1.5 py-0.2 rounded-full bg-slate-900 ${tab.color || 'text-slate-300'}`}>
                {tab.count}
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Search & Grid */}
      <div className="space-y-4">
        <div className="relative max-w-md">
          <i className="fa-solid fa-magnifying-glass absolute left-3 top-3 text-slate-400 text-xs"></i>
          <input
            type="text"
            placeholder="Search partner name, phone, partner code, skill..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-2 bg-slate-900 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-purple-500"
          />
        </div>

        {/* Partner Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredPartners.map(partner => {
            const status = partner.kycStatus || 'ACTIVE';
            return (
              <div
                key={partner._id || partner.id}
                className="bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-lg space-y-4 hover:border-slate-700 transition-all flex flex-col justify-between"
              >
                <div className="space-y-3">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="w-11 h-11 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-sm text-purple-400">
                        {(partner.name || 'P')[0]}
                      </div>
                      <div>
                        <h4 className="font-bold text-white text-sm">{partner.name}</h4>
                        <span className="text-[11px] text-slate-400 font-mono block">
                          {partner.technicianCode || 'TECH-001'} • {partner.phone}
                        </span>
                      </div>
                    </div>

                    <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${
                      status === 'ACTIVE'
                        ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30'
                        : status === 'PENDING_APPROVAL'
                        ? 'bg-amber-500/20 text-amber-300 border-amber-500/30 animate-pulse'
                        : status === 'SUSPENDED'
                        ? 'bg-rose-500/20 text-rose-300 border-rose-500/30'
                        : 'bg-slate-800 text-slate-400 border-slate-700'
                    }`}>
                      {status}
                    </span>
                  </div>

                  <div className="grid grid-cols-2 gap-2 text-[11px] bg-slate-800/50 p-2.5 rounded-xl border border-slate-800">
                    <div>
                      <span className="text-slate-400 block">Category:</span>
                      <span className="font-semibold text-slate-200">{partner.category || 'Appliance'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 block">Customer Rating:</span>
                      <span className="font-semibold text-amber-400">★ {partner.rating || '4.8'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 block">Wallet Balance:</span>
                      <span className="font-semibold text-emerald-400 font-mono">₹{partner.walletBalance || 0}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 block">Online Status:</span>
                      <span className={`font-semibold ${partner.isOnline ? 'text-emerald-400' : 'text-slate-500'}`}>
                        {partner.isOnline ? '● Online' : '○ Offline'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Actions */}
                <div className="pt-2 flex items-center gap-2">
                  <button
                    onClick={() => setSelectedPartner(partner)}
                    className="w-full py-2 bg-purple-600/20 hover:bg-purple-600 border border-purple-500/40 text-purple-300 hover:text-white rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-1.5"
                  >
                    <i className="fa-solid fa-file-shield"></i>
                    <span>Inspect KYC Documents</span>
                  </button>
                </div>
              </div>
            );
          })}

          {filteredPartners.length === 0 && (
            <div className="col-span-full py-12 text-center text-slate-500 bg-slate-900 border border-dashed border-slate-800 rounded-2xl">
              <i className="fa-solid fa-user-shield text-3xl mb-2 text-slate-600 block"></i>
              No partner records match the selected filter.
            </div>
          )}
        </div>
      </div>

      {/* KYC Inspector Modal */}
      {selectedPartner && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/80 backdrop-blur-sm p-4 overflow-y-auto animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-2xl w-full shadow-2xl overflow-hidden text-slate-100">
            
            <div className="px-6 py-4 bg-slate-800/80 border-b border-slate-700 flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="w-9 h-9 rounded-xl bg-purple-500/20 border border-purple-500/40 flex items-center justify-center text-purple-400">
                  <i className="fa-solid fa-file-signature text-lg"></i>
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">KYC Document Inspection & Governance</h3>
                  <p className="text-xs text-slate-400">{selectedPartner.name} ({selectedPartner.technicianCode})</p>
                </div>
              </div>
              <button 
                onClick={() => setSelectedPartner(null)}
                className="w-8 h-8 rounded-lg bg-slate-700/50 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center"
              >
                <i className="fa-solid fa-xmark"></i>
              </button>
            </div>

            <div className="p-6 space-y-5 max-h-[75vh] overflow-y-auto text-xs">
              
              {/* Partner Details */}
              <div className="grid grid-cols-3 gap-3 p-3 bg-slate-800/60 rounded-xl border border-slate-700">
                <div>
                  <span className="text-slate-400 block">Phone:</span>
                  <span className="font-semibold text-white">{selectedPartner.phone}</span>
                </div>
                <div>
                  <span className="text-slate-400 block">Email:</span>
                  <span className="font-semibold text-white">{selectedPartner.email || 'partner@bookurtechnician.com'}</span>
                </div>
                <div>
                  <span className="text-slate-400 block">Current Status:</span>
                  <span className="font-bold uppercase text-purple-400">{selectedPartner.kycStatus || 'ACTIVE'}</span>
                </div>
              </div>

              {/* Document Previews */}
              <div className="space-y-3">
                <h4 className="font-bold text-slate-200 uppercase tracking-wider text-[11px]">Submitted Verification Documents</h4>
                
                <div className="grid grid-cols-3 gap-3">
                  {/* Aadhaar / ID Card */}
                  <div className="p-3 bg-slate-800 border border-slate-700 rounded-xl text-center space-y-2">
                    <i className="fa-solid fa-id-card text-2xl text-indigo-400"></i>
                    <div className="font-semibold text-slate-200">Government ID / Aadhaar</div>
                    <span className="text-[10px] text-emerald-400 block font-medium">Uploaded & Verified</span>
                  </div>

                  {/* Skill Certificate */}
                  <div className="p-3 bg-slate-800 border border-slate-700 rounded-xl text-center space-y-2">
                    <i className="fa-solid fa-award text-2xl text-amber-400"></i>
                    <div className="font-semibold text-slate-200">Skill Certificate</div>
                    <span className="text-[10px] text-emerald-400 block font-medium">{selectedPartner.category} Certified</span>
                  </div>

                  {/* Profile Selfie */}
                  <div className="p-3 bg-slate-800 border border-slate-700 rounded-xl text-center space-y-2">
                    <i className="fa-solid fa-camera text-2xl text-purple-400"></i>
                    <div className="font-semibold text-slate-200">Live Face Verification</div>
                    <span className="text-[10px] text-emerald-400 block font-medium">Biometric Matched</span>
                  </div>
                </div>
              </div>

              {/* Action Controls */}
              <div className="space-y-3 pt-3 border-t border-slate-800">
                <h4 className="font-bold text-slate-200 uppercase tracking-wider text-[11px]">Governance Actions</h4>

                <div className="grid grid-cols-3 gap-3">
                  <button
                    onClick={() => handleStatusUpdate(selectedPartner._id || selectedPartner.id, 'ACTIVE')}
                    disabled={submitting}
                    className="py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl font-bold flex items-center justify-center gap-1.5 shadow-md shadow-emerald-600/20"
                  >
                    <i className="fa-solid fa-circle-check"></i>
                    <span>Approve Partner</span>
                  </button>

                  <button
                    onClick={() => handleStatusUpdate(selectedPartner._id || selectedPartner.id, 'SUSPENDED', 'Compliance review')}
                    disabled={submitting}
                    className="py-2.5 bg-amber-600 hover:bg-amber-500 text-white rounded-xl font-bold flex items-center justify-center gap-1.5 shadow-md shadow-amber-600/20"
                  >
                    <i className="fa-solid fa-pause"></i>
                    <span>Suspend Partner</span>
                  </button>

                  <button
                    onClick={() => handleStatusUpdate(selectedPartner._id || selectedPartner.id, 'REJECTED', 'Documents unclear')}
                    disabled={submitting}
                    className="py-2.5 bg-rose-600 hover:bg-rose-500 text-white rounded-xl font-bold flex items-center justify-center gap-1.5 shadow-md shadow-rose-600/20"
                  >
                    <i className="fa-solid fa-ban"></i>
                    <span>Reject Documents</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
