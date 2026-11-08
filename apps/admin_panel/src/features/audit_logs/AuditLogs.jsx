import React from 'react';

export default function AuditLogs({ logs = [] }) {
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
          {logs.length === 0 ? (
            <tr>
              <td colSpan="4" style={{ textAlign: 'center', color: '#77716C', padding: '24px' }}>
                No audit events recorded yet. Live operational actions will appear here automatically.
              </td>
            </tr>
          ) : (
            logs.map((log, idx) => (
              <tr key={log.id || idx}>
                <td>{log.timestamp || 'Live'}</td>
                <td>{log.module || 'System'}</td>
                <td>{log.action || ''}</td>
                <td>{log.operator || 'Admin'}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
