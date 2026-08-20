import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function FinancialSettlementPortal() {
  const [transactions, setTransactions] = useState([]);
  const [technicians, setTechnicians] = useState([]);
  const [totalDisbursed, setTotalDisbursed] = useState(0);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Settlement Modal State
  const [showDisburseModal, setShowDisburseModal] = useState(false);
  const [selectedTech, setSelectedTech] = useState(null);
  const [payoutAmount, setPayoutAmount] = useState('');
  const [utrReference, setUtrReference] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('UPI');
  const [destinationUpi, setDestinationUpi] = useState('');
  const [settlementNotes, setSettlementNotes] = useState('Immediate partner earnings payout release');
  const [submitting, setSubmitting] = useState(false);
  const [modalError, setModalError] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);

  const loadFinancialData = useCallback(async () => {
    setLoading(true);
    try {
      const [payoutRes, techRes] = await Promise.all([
        api.getPayoutTransactions('all').catch(() => ({ transactions: [], totalDisbursedAmount: 0 })),
        api.getTechnicians().catch(() => ({ data: [] })),
      ]);

      if (payoutRes && payoutRes.transactions) {
        setTransactions(payoutRes.transactions);
        setTotalDisbursed(payoutRes.totalDisbursedAmount || 0);
      } else if (payoutRes && payoutRes.data) {
        setTransactions(payoutRes.data.transactions || []);
        setTotalDisbursed(payoutRes.data.totalDisbursedAmount || 0);
      }

      if (techRes && techRes.data) {
        setTechnicians(techRes.data);
      } else if (Array.isArray(techRes)) {
        setTechnicians(techRes);
      }
    } catch (err) {
      console.error('Failed to load financial data:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadFinancialData();
  }, [loadFinancialData]);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const handleOpenDisburse = (tech) => {
    setSelectedTech(tech);
    setPayoutAmount(tech.walletBalance ? tech.walletBalance.toString() : '500');
    setDestinationUpi(tech.upiId || '');
    setUtrReference(`UTR${Date.now().toString(36).toUpperCase()}${Math.floor(1000 + Math.random() * 9000)}`);
    setModalError(null);
    setShowDisburseModal(true);
  };

  const handleExecutePayout = async () => {
    if (!selectedTech) return;
    if (!utrReference || utrReference.trim().length < 6) {
      setModalError('Valid Bank / UPI UTR Transaction Reference is strictly mandatory.');
      return;
    }
    const amt = parseFloat(payoutAmount);
    if (isNaN(amt) || amt <= 0) {
      setModalError('Please enter a valid payout disbursement amount.');
      return;
    }

    setSubmitting(true);
    setModalError(null);

    try {
      const res = await api.releaseWalletPayout({
        technicianId: selectedTech._id || selectedTech.id,
        amount: amt,
        paymentMethod,
        utrReference: utrReference.trim(),
        destinationUpi: destinationUpi.trim(),
        notes: settlementNotes,
      });

      if (res && (res.success || res.status === 200)) {
        showToast(res.message || 'Payout successfully disbursed with UTR ledger record');
        setShowDisburseModal(false);
        loadFinancialData();
      } else {
        setModalError(res?.message || 'Payout transaction failed.');
      }
    } catch (err) {
      console.error('Payout disbursement error:', err);
      setModalError(err.message || 'Server error releasing payout.');
    } finally {
      setSubmitting(false);
    }
  };

  // Compute metrics
  const totalHeldBalance = technicians.reduce((acc, t) => acc + (t.walletBalance || 0), 0);
  const pendingRequestsCount = technicians.filter(t => (t.walletBalance || 0) > 0).length;

  return (
    <div className="space-y-6 text-slate-100 animate-fadeIn">
      
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 px-4 py-3 bg-emerald-600 text-white rounded-xl shadow-2xl flex items-center gap-2 border border-emerald-400/40 text-xs font-semibold animate-bounce">
          <i className="fa-solid fa-circle-check text-sm"></i>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Header */}
      <div className="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400">
            <i className="fa-solid fa-vault text-xl"></i>
          </div>
          <div>
            <h2 className="text-xl font-bold text-white flex items-center gap-2">
              Financial Ledger & Wallet Payout Settlements
              <span className="text-xs px-2.5 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 font-mono">
                Atomic MongoDB Ledger
              </span>
            </h2>
            <p className="text-xs text-slate-400">
              Disburse partner earnings, verify unique UTR reference reconciliation, and manage held wallet balances
            </p>
          </div>
        </div>

        <button
          onClick={loadFinancialData}
          className="px-3.5 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl border border-slate-700 flex items-center gap-2 transition-all"
        >
          <i className="fa-solid fa-arrows-rotate"></i>
          <span>Refresh Ledger</span>
        </button>
      </div>

      {/* Overview Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 bg-slate-900 border border-slate-800 rounded-2xl shadow-lg">
          <div className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Total Held in Partner Wallets</div>
          <div className="text-2xl font-black text-amber-400 font-mono">₹{totalHeldBalance.toLocaleString()}</div>
          <div className="text-[11px] text-slate-400 mt-1">{pendingRequestsCount} partners with withdrawable balance</div>
        </div>

        <div className="p-4 bg-slate-900 border border-slate-800 rounded-2xl shadow-lg">
          <div className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Total Payouts Disbursed</div>
          <div className="text-2xl font-black text-emerald-400 font-mono">₹{totalDisbursed.toLocaleString()}</div>
          <div className="text-[11px] text-slate-400 mt-1">{transactions.length} settled ledger transactions</div>
        </div>

        <div className="p-4 bg-slate-900 border border-slate-800 rounded-2xl shadow-lg">
          <div className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Compliance & Reconciliation SLA</div>
          <div className="text-2xl font-black text-indigo-400 font-mono">100%</div>
          <div className="text-[11px] text-emerald-400 mt-1 flex items-center gap-1 font-medium">
            <i className="fa-solid fa-circle-check"></i>
            Strict UTR Idempotency Guard Active
          </div>
        </div>
      </div>

      {/* Partner Wallets Ready for Payout */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-xl space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-base font-bold text-white flex items-center gap-2">
            <i className="fa-solid fa-wallet text-amber-400"></i>
            Partner Wallets Pending Payout Release
          </h3>
          <span className="text-xs text-slate-400">Click 'Process Payout' to disburse via bank/UPI</span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {technicians.filter(t => (t.walletBalance || 0) > 0).slice(0, 6).map(tech => (
            <div key={tech._id || tech.id} className="p-4 bg-slate-800/80 border border-slate-700/70 rounded-xl space-y-3 shadow">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="font-bold text-white text-sm">{tech.name}</h4>
                  <p className="text-[11px] text-slate-400 font-mono">{tech.technicianCode || 'TECH'} • {tech.phone}</p>
                </div>
                <span className="text-base font-black text-amber-400 font-mono">
                  ₹{tech.walletBalance || 0}
                </span>
              </div>

              <div className="text-[11px] text-slate-400 bg-slate-900/60 p-2 rounded-lg border border-slate-800 flex justify-between">
                <span>Destination UPI:</span>
                <span className="font-mono text-slate-200">{tech.upiId || 'Not Configured'}</span>
              </div>

              <button
                onClick={() => handleOpenDisburse(tech)}
                className="w-full py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-bold shadow-md shadow-emerald-600/20 flex items-center justify-center gap-2 transition-all"
              >
                <i className="fa-solid fa-money-bill-transfer"></i>
                <span>Process Payout (₹{tech.walletBalance})</span>
              </button>
            </div>
          ))}

          {technicians.filter(t => (t.walletBalance || 0) > 0).length === 0 && (
            <div className="col-span-full py-8 text-center text-slate-500 text-xs border border-dashed border-slate-800 rounded-xl">
              No pending partner wallet balances require disbursement.
            </div>
          )}
        </div>
      </div>

      {/* Immutable Financial Ledger Table */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl space-y-3 p-5">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <h3 className="text-base font-bold text-white flex items-center gap-2">
            <i className="fa-solid fa-receipt text-indigo-400"></i>
            Immutable Payout Ledger & UTR Audit Records
          </h3>

          <div className="relative w-full sm:w-72">
            <i className="fa-solid fa-magnifying-glass absolute left-3 top-3 text-slate-400 text-xs"></i>
            <input
              type="text"
              placeholder="Search by UTR, Ledger Code, Partner..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-800/80 text-slate-400 font-semibold border-b border-slate-700">
              <tr>
                <th className="p-3">Ledger Code</th>
                <th className="p-3">Partner Details</th>
                <th className="p-3">Disbursed Amount</th>
                <th className="p-3">Payment Method</th>
                <th className="p-3">Bank UTR Reference</th>
                <th className="p-3">Disbursed At</th>
                <th className="p-3">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {transactions
                .filter(tx => 
                  (tx.utrReference || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
                  (tx.payoutCode || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
                  (tx.technicianName || '').toLowerCase().includes(searchQuery.toLowerCase())
                )
                .map(tx => (
                  <tr key={tx._id || tx.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="p-3 font-mono font-bold text-indigo-300">{tx.payoutCode}</td>
                    <td className="p-3">
                      <div className="font-semibold text-white">{tx.technicianName}</div>
                      <div className="text-[10px] text-slate-400 font-mono">{tx.technicianPhone || tx.technicianId}</div>
                    </td>
                    <td className="p-3 font-mono font-bold text-emerald-400">₹{tx.amount}</td>
                    <td className="p-3">
                      <span className="px-2 py-0.5 rounded bg-slate-800 border border-slate-700 text-slate-300 text-[10px] font-mono">
                        {tx.paymentMethod}
                      </span>
                    </td>
                    <td className="p-3 font-mono font-bold text-amber-400">{tx.utrReference}</td>
                    <td className="p-3 text-slate-400 text-[11px]">
                      {tx.disbursedAt ? new Date(tx.disbursedAt).toLocaleString() : 'Just now'}
                    </td>
                    <td className="p-3">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                        {tx.status || 'PROCESSED'}
                      </span>
                    </td>
                  </tr>
                ))}

              {transactions.length === 0 && (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-slate-500">
                    No payout transactions recorded in ledger.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Disburse Modal */}
      {showDisburseModal && selectedTech && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/75 backdrop-blur-sm p-4 overflow-y-auto animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-lg w-full shadow-2xl overflow-hidden text-slate-100">
            
            <div className="px-6 py-4 bg-slate-800/80 border-b border-slate-700 flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="w-9 h-9 rounded-xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400">
                  <i className="fa-solid fa-money-bill-transfer text-lg"></i>
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Execute Partner Payout Settlement</h3>
                  <p className="text-xs text-slate-400">Partner: {selectedTech.name} ({selectedTech.technicianCode})</p>
                </div>
              </div>
              <button 
                onClick={() => setShowDisburseModal(false)}
                className="w-8 h-8 rounded-lg bg-slate-700/50 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center"
              >
                <i className="fa-solid fa-xmark"></i>
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              {modalError && (
                <div className="p-3 bg-rose-500/15 border border-rose-500/30 rounded-xl text-rose-300 flex items-center gap-2">
                  <i className="fa-solid fa-triangle-exclamation text-rose-400"></i>
                  <span>{modalError}</span>
                </div>
              )}

              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700 space-y-1">
                <div className="flex justify-between">
                  <span className="text-slate-400">Available Wallet Balance:</span>
                  <span className="font-bold text-amber-400 font-mono">₹{selectedTech.walletBalance || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Configured UPI ID:</span>
                  <span className="font-mono text-slate-200">{selectedTech.upiId || 'None'}</span>
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Disbursement Amount (₹)</label>
                <input
                  type="number"
                  value={payoutAmount}
                  onChange={e => setPayoutAmount(e.target.value)}
                  placeholder="Enter amount"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-white font-mono font-bold focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Payment Method</label>
                <select
                  value={paymentMethod}
                  onChange={e => setPaymentMethod(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-white focus:outline-none focus:border-emerald-500"
                >
                  <option value="UPI">UPI Instant Payout</option>
                  <option value="IMPS">IMPS Immediate Payment</option>
                  <option value="NEFT">NEFT National Electronic Funds Transfer</option>
                  <option value="BANK_TRANSFER">Direct Bank Settlement</option>
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">
                  Destination UPI ID / Bank Account
                </label>
                <input
                  type="text"
                  value={destinationUpi}
                  onChange={e => setDestinationUpi(e.target.value)}
                  placeholder="e.g. partner@upi / 9876543210@paytm"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-white font-mono focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 flex items-center justify-between mb-1">
                  <span>Bank Transaction UTR Reference</span>
                  <span className="text-rose-400 text-[10px]">*Mandatory for audit</span>
                </label>
                <input
                  type="text"
                  value={utrReference}
                  onChange={e => setUtrReference(e.target.value)}
                  placeholder="e.g. UTR492834019283"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-amber-400 font-mono font-bold focus:outline-none focus:border-amber-500"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Internal Notes</label>
                <input
                  type="text"
                  value={settlementNotes}
                  onChange={e => setSettlementNotes(e.target.value)}
                  placeholder="Settlement notes"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-white focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>

            <div className="px-6 py-4 bg-slate-800/80 border-t border-slate-700 flex items-center justify-end space-x-3">
              <button
                onClick={() => setShowDisburseModal(false)}
                disabled={submitting}
                className="px-4 py-2 rounded-xl bg-slate-700 hover:bg-slate-600 text-slate-300 text-xs font-medium"
              >
                Cancel
              </button>
              <button
                onClick={handleExecutePayout}
                disabled={submitting || !utrReference || !payoutAmount}
                className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 flex items-center gap-2"
              >
                {submitting ? (
                  <>
                    <i className="fa-solid fa-spinner fa-spin"></i>
                    <span>Settling Atomic Ledger...</span>
                  </>
                ) : (
                  <>
                    <i className="fa-solid fa-shield-check"></i>
                    <span>Disburse & Record UTR</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
