import React from 'react';

export default function ForwardedServices({ requests, onApproveReschedule }) {
  return (
    <div>
      <h3>Forwarded Reschedules Request Queue</h3>
      {requests.length === 0 ? (
        <p>No pending reschedule approvals.</p>
      ) : (
        <table className="admin-table">
          <thead>
            <tr>
              <th>Booking ID</th>
              <th>Technician</th>
              <th>Reason Picker</th>
              <th>Proposed Completion Date</th>
              <th>Status</th>
              <th>Admin Override</th>
            </tr>
          </thead>
          <tbody>
            {requests.map((r) => (
              <tr key={r.id}>
                <td>{r.id}</td>
                <td>{r.technician}</td>
                <td>{r.reason}</td>
                <td>{r.date}</td>
                <td>
                  <span className="badge badge-warning">{r.status}</span>
                </td>
                <td>
                  <button className="action-btn" onClick={() => onApproveReschedule(r.id)}>
                    Approve Next-Day visit
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
