import React, { useState } from 'react';

export default function LocationsManager({ auditLogAction }) {
  const [subTab, setSubTab] = useState('cities');
  
  // Operating Cities States
  const [cities, setCities] = useState([
    { id: 1, name: 'Kolkata', state: 'West Bengal', status: 'Active', pincodes: '700001, 700091, 700156' },
    { id: 2, name: 'Bengaluru', state: 'Karnataka', status: 'Active', pincodes: '560001, 560102, 560087' },
    { id: 3, name: 'Delhi NCR', state: 'Delhi', status: 'Inactive', pincodes: '110001, 110020' }
  ]);

  const [newCity, setNewCity] = useState({ name: '', state: '', status: 'Active', pincodes: '' });

  const handleAddCity = (e) => {
    e.preventDefault();
    const item = { id: Date.now(), ...newCity };
    setCities(prev => [...prev, item]);
    auditLogAction('Location Administration', `Added operating city: "${newCity.name}"`);
    setNewCity({ name: '', state: '', status: 'Active', pincodes: '' });
    alert(`City ${newCity.name} added!`);
  };

  const handleToggleCityStatus = (id) => {
    setCities(prev => prev.map(c => {
      if (c.id === id) {
        const nextStatus = c.status === 'Active' ? 'Inactive' : 'Active';
        auditLogAction('Location Administration', `Toggled operating status for ${c.name} to ${nextStatus}`);
        return { ...c, status: nextStatus };
      }
      return c;
    }));
  };

  return (
    <div className="locations-manager">
      <div className="settings-tabs">
        <div className={`settings-tab ${subTab === 'cities' ? 'active' : ''}`} onClick={() => setSubTab('cities')}>
          📍 Serviceable Cities ({cities.length})
        </div>
        <div className={`settings-tab ${subTab === 'radius' ? 'active' : ''}`} onClick={() => setSubTab('radius')}>
          🗺️ Service Radius & Boundaries
        </div>
      </div>

      {/* ─── TAB 1: CITIES ─── */}
      {subTab === 'cities' && (
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="chart-card">
            <h4>Add New Operating City</h4>
            <form onSubmit={handleAddCity} style={{ marginTop: '20px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-group">
                  <label>City Name</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Mumbai"
                    value={newCity.name}
                    onChange={(e) => setNewCity(prev => ({ ...prev, name: e.target.value }))}
                  />
                </div>
                <div className="form-group">
                  <label>State</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Maharashtra"
                    value={newCity.state}
                    onChange={(e) => setNewCity(prev => ({ ...prev, state: e.target.value }))}
                  />
                </div>
                <div className="form-group">
                  <label>Serviceable Pincodes (Comma separated)</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. 400001, 400012"
                    value={newCity.pincodes}
                    onChange={(e) => setNewCity(prev => ({ ...prev, pincodes: e.target.value }))}
                  />
                </div>
                <div className="text-right">
                  <button type="submit" className="action-btn">Launch City Coverage</button>
                </div>
              </div>
            </form>
          </div>

          <div className="chart-card">
            <h4>Operating Hubs Database</h4>
            <div className="table-container m-t-20" style={{ border: 'none', boxShadow: 'none' }}>
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>City</th>
                    <th>State</th>
                    <th>Pincodes Coverage</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {cities.map(c => (
                    <tr key={c.id}>
                      <td style={{ fontWeight: '700' }}>{c.name}</td>
                      <td>{c.state}</td>
                      <td><span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{c.pincodes}</span></td>
                      <td>
                        <span className={`badge ${c.status === 'Active' ? 'badge-success' : 'badge-error'}`}>
                          {c.status === 'Active' ? 'Active' : 'Coming Soon'}
                        </span>
                      </td>
                      <td>
                        <button className="action-btn action-btn-secondary" style={{ padding: '4px 8px', fontSize: '11px' }} onClick={() => handleToggleCityStatus(c.id)}>
                          {c.status === 'Active' ? 'Deactivate' : 'Activate'}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ─── TAB 2: SERVICE RADIUS ─── */}
      {subTab === 'radius' && (
        <div className="chart-card">
          <h4>Configure Service Dispatch Radius Boundaries</h4>
          <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px' }}>Set matching limits for technician auto-assignment scans.</p>
          
          <div className="grid-2 m-b-20" style={{ gap: '20px' }}>
            <div className="form-group">
              <label>Maximum Dispatch Search Radius (km)</label>
              <input type="number" className="form-control" defaultValue="15" />
            </div>
            <div className="form-group">
              <label>Normal Travel ETA Boundary (minutes)</label>
              <input type="number" className="form-control" defaultValue="45" />
            </div>
          </div>
          
          <div className="text-right">
            <button className="action-btn" onClick={() => {
              auditLogAction('Location Administration', 'Updated service dispatch radius search boundaries');
              alert("Dispatch boundary radius thresholds configured!");
            }}>Save Boundary Radii</button>
          </div>
        </div>
      )}
    </div>
  );
}
