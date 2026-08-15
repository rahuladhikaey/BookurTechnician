import React, { useState } from 'react';

const INITIAL_REVIEWS_LIST = [
  { id: 1, customer: 'Shreya Sharma', technician: 'Rahul Adhikary', techId: 'BT-TECH-000001', service: 'AC Deep Cleaning', rating: 5, comment: 'Excellent prompt cleaning, AC is cooling perfectly now. Technician arrived on time in clean uniform with ID card!', date: '14 Aug 2026', hidden: false, flagged: false },
  { id: 2, customer: 'Vikas Kumar', technician: 'Amit Singh', techId: 'BT-TECH-000002', service: 'Ceiling Fan Installation', rating: 4, comment: 'Quick assembly, standard installation done. Professional behavior.', date: '13 Aug 2026', hidden: false, flagged: false },
  { id: 3, customer: 'Ananya Gupta', technician: 'Rahul Adhikary', techId: 'BT-TECH-000001', service: 'AC Gas Refill', rating: 5, comment: 'Very transparent with gas pressure gauges and diagnostics.', date: '12 Aug 2026', hidden: false, flagged: false },
  { id: 4, customer: 'Rohan Sen', technician: 'Sunita Rao', techId: 'BT-TECH-000003', service: 'Laptop Keyboard Replacement', rating: 2, comment: 'Parts took a bit longer than estimated.', date: '11 Aug 2026', hidden: false, flagged: false }
];

export default function ReviewsManager({ auditLogAction }) {
  const [reviews, setReviews] = useState(INITIAL_REVIEWS_LIST);
  const [filterRating, setFilterRating] = useState('ALL');

  const filteredReviews = reviews.filter(r => {
    if (filterRating === 'ALL') return true;
    return r.rating === Number(filterRating);
  });

  const handleToggleHide = (id) => {
    const r = reviews.find(x => x.id === id);
    const nextState = !r.hidden;
    setReviews(prev => prev.map(x => x.id === id ? { ...x, hidden: nextState } : x));
    auditLogAction?.('Reviews', `${nextState ? 'Hidden' : 'Restored'} review ID ${id} by ${r?.customer}`);
  };

  const handleToggleFlag = (id) => {
    const r = reviews.find(x => x.id === id);
    const nextState = !r.flagged;
    setReviews(prev => prev.map(x => x.id === id ? { ...x, flagged: nextState } : x));
    auditLogAction?.('Reviews', `${nextState ? 'Flagged' : 'Unflagged'} review ID ${id}`);
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
              {filteredReviews.map(r => (
                <tr key={r.id} style={{ opacity: r.hidden ? 0.5 : 1 }}>
                  <td>
                    <span style={{ color: '#D97706', fontWeight: '700', fontSize: '13.5px' }}>
                      {'★'.repeat(r.rating)}{'☆'.repeat(5 - r.rating)} ({r.rating}.0)
                    </span>
                  </td>
                  <td>
                    <strong style={{ color: 'var(--text-main)' }}>{r.customer}</strong>
                  </td>
                  <td>
                    <span className="badge badge-info">{r.service}</span>
                  </td>
                  <td>
                    <strong style={{ color: 'var(--text-main)' }}>{r.technician}</strong>
                    <div style={{ fontSize: '11px', color: 'var(--primary)', fontFamily: 'monospace' }}>{r.techId}</div>
                  </td>
                  <td style={{ maxWidth: '300px', fontSize: '12.5px', lineHeight: '1.4' }}>
                    "{r.comment}"
                  </td>
                  <td>
                    <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{r.date}</span>
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
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
