import React from 'react';

export default function AuditLogs() {
  return (
    <div>
      <h3>Audit Logs & Operational History</h3>
      <table className="admin-table">
        <thead>
          <tr>
            <th>Timestamp</th>
            <th>Module</th>
            <th>Action Details</th>
            <th>Operator</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>13:40:05</td>
            <td>Technician OTP</td>
            <td>Server API validated arrival OTP 4821 for Ramesh (BT102938)</td>
            <td>Ramesh Kumar (Tech)</td>
          </tr>
          <tr>
            <td>13:20:12</td>
            <td>Payments Gateway</td>
            <td>UPI Transaction ID UPI839201 paid ₹399 for fan installation</td>
            <td>Rahul Customer</td>
          </tr>
          <tr>
            <td>12:45:00</td>
            <td>KYC Checks</td>
            <td>Technician partner Ramesh Kumar uploaded driver license files</td>
            <td>System Automator</td>
          </tr>
          <tr>
            <td>11:02:14</td>
            <td>Rescheduling</td>
            <td>Booking BT102938 status marked FORWARDED (next-day delay request)</td>
            <td>Ramesh Kumar (Tech)</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
