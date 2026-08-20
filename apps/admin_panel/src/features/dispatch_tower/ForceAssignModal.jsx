import React, { useState, useEffect } from 'react';
import api from '../../api/apiClient';

export default function ForceAssignModal({ booking, onClose, onSuccess }) {
  const [technicians, setTechnicians] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedTechId, setSelectedTechId] = useState('');
  const [reason, setReason] = useState('Manual dispatcher force-assign: Customer requested immediate priority technician.');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [searchFilter, setSearchFilter] = useState('');

  useEffect(() => {
    if (!booking) return;

    setLoading(true);
    setError(null);
    api.getNearbyTechniciansForBooking(booking._id || booking.id)
      .then(res => {
        if (res && res.technicians) {
          setTechnicians(res.technicians);
        } else if (res && res.data) {
          setTechnicians(res.data.technicians || []);
        }
      })
      .catch(err => {
        console.error('Failed to load nearby technicians:', err);
        setError('Could not load nearby technicians: ' + (err.message || 'Network error'));
      })
      .finally(() => setLoading(false));
  }, [booking]);

  const handleForceAssign = async () => {
    if (!selectedTechId) {
      setError('Please select a technician from the active 15 km list.');
      return;
    }
    if (!reason || reason.trim().length < 5) {
      setError('Please provide a valid override reason for the audit trail.');
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      const res = await api.forceAssignBooking(booking._id || booking.id, selectedTechId, reason);
      if (res && (res.success || res.status === 200)) {
        if (onSuccess) onSuccess(res.message || 'Booking force-assigned successfully');
        onClose();
      } else {
        setError(res?.message || 'Failed to force-assign booking.');
      }
    } catch (err) {
      console.error('Force assign error:', err);
      setError(err.message || 'Force assignment request failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const filteredTechs = technicians.filter(t => 
    (t.name || '').toLowerCase().includes(searchFilter.toLowerCase()) ||
    (t.technicianCode || '').toLowerCase().includes(searchFilter.toLowerCase()) ||
    (t.category || '').toLowerCase().includes(searchFilter.toLowerCase()) ||
    (t.phone || '').includes(searchFilter)
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/75 backdrop-blur-sm p-4 overflow-y-auto animate-fadeIn">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-2xl w-full shadow-2xl overflow-hidden text-slate-100">
        
        {/* Header */}
        <div className="px-6 py-4 bg-slate-800/80 border-b border-slate-700 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-9 h-9 rounded-xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400">
              <i className="fa-solid fa-satellite-dish text-lg animate-pulse"></i>
            </div>
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                Manual Dispatch Override (Force-Assign)
                <span className="text-xs px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 font-mono font-medium border border-amber-500/30">
                  15 km Radar
                </span>
              </h3>
              <p className="text-xs text-slate-400">
                Booking <span className="text-amber-400 font-mono font-semibold">{booking?.bookingCode || 'BT-JOB'}</span> • {booking?.serviceType || 'Service'}
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

        {/* Body Content */}
        <div className="p-6 space-y-5 max-h-[75vh] overflow-y-auto">
          {error && (
            <div className="p-3.5 bg-rose-500/15 border border-rose-500/30 rounded-xl text-rose-300 text-xs flex items-center gap-2">
              <i className="fa-solid fa-triangle-exclamation text-rose-400 text-sm"></i>
              <span>{error}</span>
            </div>
          )}

          {/* Job Target Summary */}
          <div className="grid grid-cols-2 gap-3 p-3.5 bg-slate-800/50 rounded-xl border border-slate-700/60 text-xs">
            <div>
              <span className="text-slate-400 block mb-0.5">Customer Details:</span>
              <span className="font-semibold text-white">{booking?.customerName || 'Customer'}</span>
              <span className="text-slate-400 block">{booking?.customerPhone || 'N/A'}</span>
            </div>
            <div>
              <span className="text-slate-400 block mb-0.5">Location:</span>
              <span className="font-medium text-slate-200 line-clamp-2">{booking?.customerAddress || 'Local Address'}</span>
            </div>
          </div>

          {/* Search Nearby Technicians */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-slate-300 uppercase tracking-wider">
                Select Online Technician within 15 km ({filteredTechs.length} found)
              </label>
              <span className="text-[11px] text-emerald-400 flex items-center gap-1 font-medium">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
                Live GPS Online
              </span>
            </div>

            <div className="relative">
              <i className="fa-solid fa-magnifying-glass absolute left-3 top-3 text-slate-400 text-xs"></i>
              <input
                type="text"
                placeholder="Filter by name, partner code, category, phone..."
                value={searchFilter}
                onChange={e => setSearchFilter(e.target.value)}
                className="w-full pl-9 pr-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
            </div>

            {/* Technician Select List */}
            <div className="space-y-2 max-h-52 overflow-y-auto pr-1">
              {loading ? (
                <div className="py-8 text-center text-slate-400 text-xs space-y-2">
                  <i className="fa-solid fa-spinner fa-spin text-lg text-indigo-400"></i>
                  <p>Scanning 15 km radius for active technicians...</p>
                </div>
              ) : filteredTechs.length === 0 ? (
                <div className="py-6 text-center text-slate-400 bg-slate-800/30 rounded-xl border border-dashed border-slate-700 text-xs">
                  <i className="fa-solid fa-user-slash text-slate-500 text-lg mb-1 block"></i>
                  No available online partners found matching your search.
                </div>
              ) : (
                filteredTechs.map(tech => {
                  const isSelected = selectedTechId === (tech._id || tech.id);
                  return (
                    <div
                      key={tech._id || tech.id}
                      onClick={() => setSelectedTechId(tech._id || tech.id)}
                      className={`p-3 rounded-xl border cursor-pointer transition-all flex items-center justify-between ${
                        isSelected
                          ? 'bg-indigo-600/20 border-indigo-500 shadow-md shadow-indigo-500/10'
                          : 'bg-slate-800/60 border-slate-700 hover:bg-slate-800'
                      }`}
                    >
                      <div className="flex items-center space-x-3">
                        <div className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs ${
                          isSelected ? 'bg-indigo-500 text-white' : 'bg-slate-700 text-slate-300'
                        }`}>
                          {(tech.name || 'P')[0]}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-semibold text-sm text-white">{tech.name}</span>
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-700 text-slate-300 font-mono">
                              {tech.technicianCode || 'TECH'}
                            </span>
                            {tech.isCurrentlyBusy && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">
                                Busy with Job
                              </span>
                            )}
                          </div>
                          <p className="text-xs text-slate-400">
                            {tech.category || 'General'} • ★ {tech.rating || '4.8'} • {tech.phone || 'N/A'}
                          </p>
                        </div>
                      </div>

                      <div className="text-right flex items-center gap-3">
                        <div>
                          <span className="text-xs font-semibold text-indigo-400 block font-mono">
                            {tech.distanceKm !== undefined ? `${tech.distanceKm} km` : '< 5 km'}
                          </span>
                          <span className="text-[10px] text-emerald-400">Online</span>
                        </div>
                        <div className={`w-5 h-5 rounded-full border flex items-center justify-center ${
                          isSelected ? 'border-indigo-400 bg-indigo-500 text-white' : 'border-slate-600'
                        }`}>
                          {isSelected && <i className="fa-solid fa-check text-[10px]"></i>}
                        </div>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Audit Reason */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-slate-300 flex items-center justify-between">
              <span>Dispatcher Override Justification (Immutable Audit Log)</span>
              <span className="text-rose-400 text-[10px]">*Required</span>
            </label>
            <textarea
              rows={2}
              value={reason}
              onChange={e => setReason(e.target.value)}
              placeholder="State reason for manual dispatch (e.g., auto-dispatch stalled, customer escalation, VIP priority)..."
              className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            ></textarea>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 bg-slate-800/80 border-t border-slate-700 flex items-center justify-end space-x-3">
          <button
            onClick={onClose}
            disabled={submitting}
            className="px-4 py-2 rounded-xl bg-slate-700 hover:bg-slate-600 text-slate-300 text-xs font-medium transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleForceAssign}
            disabled={submitting || !selectedTechId || !reason}
            className="px-5 py-2 rounded-xl bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-white text-xs font-bold shadow-lg shadow-amber-600/30 flex items-center gap-2 transition-all"
          >
            {submitting ? (
              <>
                <i className="fa-solid fa-spinner fa-spin"></i>
                <span>Force-Assigning...</span>
              </>
            ) : (
              <>
                <i className="fa-solid fa-bolt"></i>
                <span>Confirm Force Dispatch</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
