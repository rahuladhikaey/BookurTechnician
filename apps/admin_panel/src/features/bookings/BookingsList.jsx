import React from 'react';

export default function BookingsList({ bookings }) {
  return (
    <div>
      <h3>Active Bookings & Live Status</h3>
      <table className="admin-table">
        <thead>
          <tr>
            <th>Booking ID</th>
            <th>Service Requested</th>
            <th>Customer</th>
            <th>Technician Assigned</th>
            <th>Secret OTP</th>
            <th>Price</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {bookings.map((b) => (
            <tr key={b.id}>
              <td>{b.id}</td>
              <td>{b.service}</td>
              <td>{b.customer}</td>
              <td>{b.technician}</td>
              <td><code>{b.startOtp}</code></td>
              <td>₹{b.price}</td>
              <td>
                <span className={`badge ${b.status === 'COMPLETED' ? 'badge-success' : b.status === 'SERVICE_STARTED' ? 'badge-info' : b.status === 'FORWARD_APPROVED' ? 'badge-success' : 'badge-warning'}`}>
                  {b.status.replace('_', ' ')}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
