import React from 'react';

export default function KycVerification({ technicians, onApprove, onReject }) {
  return (
    <div>
      <h3>Technician KYC Background Verification</h3>
      <table className="admin-table">
        <thead>
          <tr>
            <th>Technician ID</th>
            <th>Name</th>
            <th>Category</th>
            <th>Experience</th>
            <th>Status</th>
            <th>KYC Actions</th>
          </tr>
        </thead>
        <tbody>
          {technicians.map((t) => (
            <tr key={t.id}>
              <td>{t.id}</td>
              <td>{t.name}</td>
              <td>{t.category}</td>
              <td>{t.experience}</td>
              <td>
                <span className={`badge ${t.status === 'Approved' ? 'badge-success' : t.status === 'Pending' ? 'badge-warning' : 'badge-error'}`}>
                  {t.status}
                </span>
              </td>
              <td>
                {t.status === 'Pending' ? (
                  <>
                    <button className="action-btn" onClick={() => onApprove(t.id)}>Approve Partner</button>
                    <button className="action-btn action-btn-danger" onClick={() => onReject(t.id)}>Reject Partner</button>
                  </>
                ) : (
                  <span style={{ color: '#9ca3af' }}>Verification completed</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
