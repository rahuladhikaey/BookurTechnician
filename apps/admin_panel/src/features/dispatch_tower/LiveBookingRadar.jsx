import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';
import ForceAssignModal from './ForceAssignModal';
import OtpDisputeModal from '../support/OtpDisputeModal';

const STAGES = [
  { key: 'PENDING', label: 'Unassigned (Pending)', color: 'border-amber-500/60 bg-amber-500/10 text-amber-300', dot: 'bg-amber-400' },
  { key: 'ACCEPTED', label: 'Accepted / Dispatched', color: 'border-blue-500/60 bg-blue-500/10 text-blue-300', dot: 'bg-blue-400' },
  { key: 'ARRIVED', label: 'Arrived at Doorstep', color: 'border-purple-500/60 bg-purple-500/10 text-purple-300', dot: 'bg-purple-400' },
  { key: 'IN_PROGRESS', label: 'In Progress (Start OTP)', color: 'border-indigo-500/60 bg-indigo-500/10 text-indigo-300', dot: 'bg-indigo-400' },
  { key: 'COMPLETED', label: 'Completed (Settled)', color: 'border-emerald-500/60 bg-emerald-500/10 text-emerald-300', dot: 'bg-emerald-400' },
  { key: 'CANCELLED', label: 'Cancelled / Refunded', color: 'border-rose-500/60 bg-rose-500/10 text-rose-300', dot: 'bg-rose-400' },
];

export default function LiveBookingRadar() {
  const [bookings, setBookings] = useState([]);
  const [summary, setSummary] = useState({ PENDING: 0, ACCEPTED: 0, ARRIVED: 0, IN_PROGRESS: 0, COMPLETED: 0, CANCELLED: 0, TOTAL: 0 });
  const [loading, setLoading] = useState(true);
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState('kanban'); // 'kanban' | 'table'
  const [autoRefresh, setAutoRefresh] = useState(true);

  // Modals state
  const [forceAssignTarget, setForceAssignTarget] = useState(null);
  const [otpDisputeTarget, setOtpDisputeTarget] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);

  const fetchLiveBookings = useCallback(async () => {
    try {
      const res = await api.getLiveBookingsRadar({
        status: selectedStatus,
        search: searchQuery,
      });

      if (res && res.bookings) {
        setBookings(res.bookings);
        if (res.summary) setSummary(res.summary);
      } else if (res && res.data) {
        setBookings(res.data.bookings || []);
        if (res.data.summary) setSummary(res.data.summary);
      }
    } catch (err) {
      console.error('Failed to load live booking radar:', err);
    } finally {
      setLoading(false);
    }
  }, [selectedStatus, searchQuery]);

  useEffect(() => {
    fetchLiveBookings();
  }, [fetchLiveBookings]);

  // Auto-refresh interval every 8 seconds
  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(() => {
      fetchLiveBookings();
    }, 8000);
    return () => clearInterval(interval);
  }, [autoRefresh, fetchLiveBookings]);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  return (
    <div className="space-y-6 animate-fadeIn text-slate-100">
      
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 px-4 py-3 bg-emerald-600 text-white rounded-xl shadow-2xl flex items-center gap-2 border border-emerald-400/40 text-xs font-semibold animate-bounce">
          <i className="fa-solid fa-circle-check text-sm"></i>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Header & Metric Bar */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-indigo-600/20 border border-indigo-500/40 flex items-center justify-center text-indigo-400">
              <i className="fa-solid fa-tower-broadcast text-xl animate-pulse"></i>
            </div>
            <div>
              <h2 className="text-xl font-bold text-white flex items-center gap-2">
                Live Operations Radar & Dispatch Tower
                <span className="text-xs px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 flex items-center gap-1 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping"></span>
                  Real-time Stream
                </span>
              </h2>
              <p className="text-xs text-slate-400">
                End-to-end pipeline monitoring, 15 km spatial force-assign, and dual-OTP dispute controls
              </p>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-3">
          <button
            onClick={() => setAutoRefresh(!autoRefresh)}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold border flex items-center gap-2 transition-all ${
              autoRefresh 
                ? 'bg-emerald-500/20 border-emerald-500/40 text-emerald-300' 
                : 'bg-slate-800 border-slate-700 text-slate-400'
            }`}
          >
            <i className={`fa-solid fa-rotate ${autoRefresh ? 'fa-spin' : ''}`}></i>
            <span>{autoRefresh ? 'Auto-Sync: ON (8s)' : 'Auto-Sync: PAUSED'}</span>
          </button>

          <div className="flex items-center bg-slate-800 rounded-xl p-1 border border-slate-700">
            <button
              onClick={() => setViewMode('kanban')}
              className={`px-3 py-1 rounded-lg text-xs font-medium transition-colors ${
                viewMode === 'kanban' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <i className="fa-solid fa-table-columns mr-1.5"></i> Kanban
            </button>
            <button
              onClick={() => setViewMode('table')}
              className={`px-3 py-1 rounded-lg text-xs font-medium transition-colors ${
                viewMode === 'table' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <i className="fa-solid fa-list mr-1.5"></i> Table
            </button>
          </div>
        </div>
      </div>

      {/* Stage Summary Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        {STAGES.map(stage => {
          const count = summary[stage.key] || 0;
          const isSelected = selectedStatus === stage.key;
          return (
            <div
              key={stage.key}
              onClick={() => setSelectedStatus(isSelected ? 'ALL' : stage.key)}
              className={`p-3.5 rounded-2xl border cursor-pointer transition-all ${
                isSelected
                  ? `${stage.color} ring-2 ring-indigo-500 shadow-lg`
                  : 'bg-slate-900/80 border-slate-800 hover:border-slate-700'
              }`}
            >
              <div className="flex items-center justify-between mb-1">
                <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">{stage.key}</span>
                <span className={`w-2 h-2 rounded-full ${stage.dot}`}></span>
              </div>
              <div className="text-2xl font-black text-white font-mono">{count}</div>
              <div className="text-[10px] text-slate-400 mt-0.5 truncate">{stage.label}</div>
            </div>
          );
        })}
      </div>

      {/* Search & Filter Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-900/60 p-3 rounded-xl border border-slate-800">
        <div className="relative w-full sm:w-80">
          <i className="fa-solid fa-magnifying-glass absolute left-3 top-3 text-slate-400 text-xs"></i>
          <input
            type="text"
            placeholder="Search booking code, customer, technician..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
          <span className="text-xs text-slate-400">
            Showing <strong className="text-white">{bookings.length}</strong> active jobs
          </span>
          {selectedStatus !== 'ALL' && (
            <button
              onClick={() => setSelectedStatus('ALL')}
              className="text-xs text-indigo-400 hover:underline font-semibold ml-2"
            >
              Clear Filter
            </button>
          )}
        </div>
      </div>

      {/* Main View: Kanban Pipeline */}
      {viewMode === 'kanban' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 items-start overflow-x-auto pb-6">
          {STAGES.map(stage => {
            const stageBookings = bookings.filter(b => b.status === stage.key);
            return (
              <div key={stage.key} className="bg-slate-900/90 border border-slate-800 rounded-2xl p-3 space-y-3 min-w-[240px]">
                
                {/* Column Header */}
                <div className="flex items-center justify-between pb-2 border-b border-slate-800">
                  <div className="flex items-center gap-2">
                    <span className={`w-2.5 h-2.5 rounded-full ${stage.dot}`}></span>
                    <span className="font-bold text-xs text-slate-200">{stage.key}</span>
                  </div>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-slate-800 text-slate-300 font-mono font-bold">
                    {stageBookings.length}
                  </span>
                </div>

                {/* Column Items */}
                <div className="space-y-3 max-h-[650px] overflow-y-auto pr-1">
                  {stageBookings.length === 0 ? (
                    <div className="py-8 text-center text-slate-600 text-xs border border-dashed border-slate-800 rounded-xl">
                      No jobs in this stage
                    </div>
                  ) : (
                    stageBookings.map(b => (
                      <div
                        key={b._id || b.id}
                        className="p-3.5 bg-slate-800/80 border border-slate-700/70 hover:border-indigo-500/70 rounded-xl space-y-2.5 transition-all shadow-md hover:shadow-indigo-500/10 group"
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-mono font-bold text-xs text-amber-400">{b.bookingCode}</span>
                          <span className="text-[11px] font-semibold text-slate-300">₹{b.payoutAmount || 450}</span>
                        </div>

                        <div>
                          <h4 className="text-xs font-bold text-white truncate">{b.serviceType}</h4>
                          <p className="text-[11px] text-slate-400 truncate">{b.customerName || 'Customer'}</p>
                        </div>

                        <div className="text-[11px] text-slate-400 bg-slate-900/60 p-2 rounded-lg border border-slate-800 space-y-1">
                          <div className="flex items-center gap-1.5 truncate">
                            <i className="fa-solid fa-location-dot text-rose-400 text-[10px]"></i>
                            <span className="truncate">{b.customerAddress || 'Local Address'}</span>
                          </div>
                          
                          {b.technician ? (
                            <div className="flex items-center gap-1.5 text-indigo-300 truncate">
                              <i className="fa-solid fa-user-gear text-[10px]"></i>
                              <span className="truncate">{b.technician.name}</span>
                              {b.isForceAssigned && (
                                <span className="text-[9px] px-1 py-0.2 rounded bg-amber-500/20 text-amber-300 font-mono">
                                  FORCE
                                </span>
                              )}
                            </div>
                          ) : (
                            <div className="text-amber-400 text-[10px] font-semibold flex items-center gap-1">
                              <i className="fa-solid fa-triangle-exclamation"></i>
                              <span>Awaiting Partner Acceptance</span>
                            </div>
                          )}
                        </div>

                        {/* Quick Action Buttons */}
                        <div className="pt-1 flex items-center gap-1.5">
                          {b.status === 'PENDING' && (
                            <button
                              onClick={() => setForceAssignTarget(b)}
                              className="w-full py-1.5 bg-amber-600/20 hover:bg-amber-600 border border-amber-500/40 text-amber-300 hover:text-white rounded-lg text-[11px] font-bold flex items-center justify-center gap-1.5 transition-all shadow-sm"
                            >
                              <i className="fa-solid fa-bolt text-[10px]"></i>
                              <span>Force Assign</span>
                            </button>
                          )}

                          {['ARRIVED', 'IN_PROGRESS'].includes(b.status) && (
                            <button
                              onClick={() => setOtpDisputeTarget(b)}
                              className="w-full py-1.5 bg-rose-600/20 hover:bg-rose-600 border border-rose-500/40 text-rose-300 hover:text-white rounded-lg text-[11px] font-bold flex items-center justify-center gap-1.5 transition-all"
                            >
                              <i className="fa-solid fa-unlock-keyhole text-[10px]"></i>
                              <span>Bypass OTP</span>
                            </button>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* Table View */
        <div className="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-800/80 text-slate-400 font-semibold border-b border-slate-700">
                <tr>
                  <th className="p-3.5">Booking Code</th>
                  <th className="p-3.5">Customer</th>
                  <th className="p-3.5">Service</th>
                  <th className="p-3.5">Assigned Technician</th>
                  <th className="p-3.5">Status</th>
                  <th className="p-3.5">Payout</th>
                  <th className="p-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {bookings.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="p-8 text-center text-slate-500">
                      No active bookings found.
                    </td>
                  </tr>
                ) : (
                  bookings.map(b => (
                    <tr key={b._id || b.id} className="hover:bg-slate-800/40 transition-colors">
                      <td className="p-3.5 font-mono font-bold text-amber-400">
                        {b.bookingCode}
                        {b.isForceAssigned && (
                          <span className="ml-2 text-[9px] px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">
                            FORCE-ASSIGNED
                          </span>
                        )}
                      </td>
                      <td className="p-3.5">
                        <div className="font-semibold text-white">{b.customerName || 'Customer'}</div>
                        <div className="text-[11px] text-slate-400">{b.customerPhone || 'N/A'}</div>
                      </td>
                      <td className="p-3.5 text-slate-200">{b.serviceType}</td>
                      <td className="p-3.5">
                        {b.technician ? (
                          <div>
                            <span className="font-semibold text-indigo-300">{b.technician.name}</span>
                            <span className="text-[10px] text-slate-400 block font-mono">{b.technician.technicianCode}</span>
                          </div>
                        ) : (
                          <span className="text-amber-400 text-xs italic">Unassigned</span>
                        )}
                      </td>
                      <td className="p-3.5">
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-800 border border-slate-700 text-slate-300">
                          {b.status}
                        </span>
                      </td>
                      <td className="p-3.5 font-mono font-semibold text-white">₹{b.payoutAmount || 450}</td>
                      <td className="p-3.5 text-right space-x-2">
                        {b.status === 'PENDING' && (
                          <button
                            onClick={() => setForceAssignTarget(b)}
                            className="px-3 py-1 bg-amber-600 hover:bg-amber-500 text-white rounded-lg text-xs font-semibold shadow"
                          >
                            Force Assign
                          </button>
                        )}
                        {['ARRIVED', 'IN_PROGRESS'].includes(b.status) && (
                          <button
                            onClick={() => setOtpDisputeTarget(b)}
                            className="px-3 py-1 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-semibold shadow"
                          >
                            Bypass OTP
                          </button>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Force Assign Modal */}
      {forceAssignTarget && (
        <ForceAssignModal
          booking={forceAssignTarget}
          onClose={() => setForceAssignTarget(null)}
          onSuccess={(msg) => {
            showToast(msg);
            fetchLiveBookings();
          }}
        />
      )}

      {/* Emergency OTP Dispute Modal */}
      {otpDisputeTarget && (
        <OtpDisputeModal
          booking={otpDisputeTarget}
          onClose={() => setOtpDisputeTarget(null)}
          onSuccess={(msg) => {
            showToast(msg);
            fetchLiveBookings();
          }}
        />
      )}
    </div>
  );
}
