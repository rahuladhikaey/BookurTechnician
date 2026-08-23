import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function ReviewsManager({ auditLogAction }) {
  const [reviews, setReviews] = useState([]);
  const [filterRating, setFilterRating] = useState('ALL');
  const [loading, setLoading] = useState(false);

  const fetchReviews = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.getReviews();
      if (res?.data && Array.isArray(res.data)) {
        setReviews(res.data);
      } else {
        setReviews([]);
      }
    } catch (err) {
      console.error('Error fetching admin reviews:', err);
      setReviews([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchReviews();
  }, [fetchReviews]);

  const filteredReviews = reviews.filter(r => {
    if (filterRating === 'ALL') return true;
    return r.rating === Number(filterRating);
  });

  const handleToggleHide = async (id) => {
    const r = reviews.find(x => x.id === id);
    if (!r) return;
    try {
      const res = await api.toggleHideReview(id);
      const updated = res?.data;
      setReviews(prev => prev.map(x => x.id === id ? { ...x, hidden: updated?.hidden ?? !x.hidden } : x));
      auditLogAction?.('Reviews', `${updated?.hidden ? 'Hidden' : 'Restored'} review ID ${id} by ${r.customerName || r.customer || 'Customer'}`);
    } catch (err) {
      console.error('Failed to toggle review visibility:', err);
    }
  };

  const handleToggleFlag = async (id) => {
    const r = reviews.find(x => x.id === id);
    if (!r) return;
    try {
      const res = await api.toggleFlagReview(id);
      const updated = res?.data;
      setReviews(prev => prev.map(x => x.id === id ? { ...x, flagged: updated?.flagged ?? !x.flagged } : x));
      auditLogAction?.('Reviews', `${updated?.flagged ? 'Flagged' : 'Unflagged'} review ID ${id}`);
    } catch (err) {
      console.error('Failed to toggle review flag:', err);
    }
  };

  return (
    <div className="reviews-manager-view">
      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Customer Reviews & Ratings Moderation</h2>
            <p className="page-subtitle">
              Preserve authentic feedback from customers while monitoring service partner quality
            </p>
          </div>
          <div className="page-actions-group">
            <select className="filter-select" value={filterRating} onChange={e => setFilterRating(e.target.value)}>
              <option value="ALL">All Star Ratings</option>
              <option value="5">5 Stars (⭐⭐⭐⭐⭐)</option>
              <option value="4">4 Stars (⭐⭐⭐⭐)</option>
              <option value="3">3 Stars (⭐⭐⭐)</option>
              <option value="2">2 Stars (⭐⭐)</option>
              <option value="1">1 Star (⭐)</option>
            </select>
            <button className="btn btn-outline btn-sm" onClick={fetchReviews} disabled={loading}>
              {loading ? 'Refreshing...' : '🔄 Refresh'}
            </button>
          </div>
        </div>

        {/* ─── FLAT TABLE ─── */}
        <div className="table-responsive">
          <table className="flat-table">
            <thead>
              <tr>
                <th>Rating</th>
                <th>Customer</th>
                <th>Service</th>
                <th>Technician</th>
                <th>Customer Feedback</th>
                <th>Date</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredReviews.length === 0 ? (
                <tr>
                  <td colSpan="8" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                    {loading ? 'Loading reviews...' : '⭐ No customer reviews found in database'}
                  </td>
                </tr>
              ) : (
                filteredReviews.map(r => {
                  const rating = r.rating || 5;
                  const custName = r.customerName || r.customer || 'Customer';
                  const srvName = r.serviceName || r.service || 'Service';
                  const techName = r.technicianName || r.technician || 'Technician';
                  const techCode = r.technicianCode || r.techId || '';
                  const comment = r.reviewText || r.comment || '';
                  const dateDisplay = r.date || (r.createdAt ? r.createdAt.toString().substring(0, 10) : 'Recent');

                  return (
                    <tr key={r.id} style={{ opacity: r.hidden ? 0.5 : 1 }}>
                      <td>
                        <span style={{ color: '#D97706', fontWeight: '700', fontSize: '13.5px' }}>
                          {'★'.repeat(rating)}{'☆'.repeat(Math.max(0, 5 - rating))} ({rating}.0)
                        </span>
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)' }}>{custName}</strong>
                      </td>
                      <td>
                        <span className="badge badge-info">{srvName}</span>
                      </td>
                      <td>
                        <strong style={{ color: 'var(--text-main)' }}>{techName}</strong>
                        {techCode && <div style={{ fontSize: '11px', color: 'var(--primary)', fontFamily: 'monospace' }}>{techCode}</div>}
                      </td>
                      <td style={{ maxWidth: '300px', fontSize: '12.5px', lineHeight: '1.4' }}>
                        "{comment}"
                      </td>
                      <td>
                        <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{dateDisplay}</span>
                      </td>
                      <td>
                        {r.hidden ? (
                          <span className="badge badge-cancelled">Hidden</span>
                        ) : r.flagged ? (
                          <span className="badge badge-pending">🚩 Flagged</span>
                        ) : (
                          <span className="badge badge-completed">Published</span>
                        )}
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                          <button className={`btn btn-sm ${r.hidden ? 'btn-primary' : 'btn-outline'}`} onClick={() => handleToggleHide(r.id)}>
                            {r.hidden ? 'Restore' : 'Hide'}
                          </button>
                          <button className="btn btn-outline btn-sm" onClick={() => handleToggleFlag(r.id)}>
                            {r.flagged ? 'Unflag' : 'Flag'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
