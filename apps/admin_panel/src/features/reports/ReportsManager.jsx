import React, { useState } from 'react';

export default function ReportsManager({ auditLogAction }) {
  const [reportType, setReportType] = useState('REVENUE');
  const [dateRange, setDateRange] = useState('MONTH');

  const handleExportCsv = (title) => {
    auditLogAction?.('Reports', `Exported ${title} to CSV format`);
    alert(`Generating and downloading ${title} spreadsheet (CSV/Excel)...`);
  };

  return (
    <div className="reports-manager-view">
      {/* ─── FLAT TABS ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${reportType === 'REVENUE' ? 'active' : ''}`} onClick={() => setReportType('REVENUE')}>
          💰 Revenue & Tax BI
        </div>
        <div className={`flat-tab ${reportType === 'BOOKINGS' ? 'active' : ''}`} onClick={() => setReportType('BOOKINGS')}>
          📋 Booking Volume & Velocity
        </div>
        <div className={`flat-tab ${reportType === 'TECHNICIANS' ? 'active' : ''}`} onClick={() => setReportType('TECHNICIANS')}>
          👨🔧 Fleet Capacity & Efficiency
        </div>
      </div>

      <div className="panel">
        <div className="page-header-row">
          <div>
            <h2 className="page-title">Business Intelligence & Financial Reports</h2>
            <p className="page-subtitle">
              Detailed performance metrics, GST summaries, and exportable operational datasets
            </p>
          </div>
          <div className="page-actions-group">
            <select className="filter-select" value={dateRange} onChange={e => setDateRange(e.target.value)}>
              <option value="TODAY">Today</option>
              <option value="WEEK">Last 7 Days</option>
              <option value="MONTH">Current Month (August 2026)</option>
              <option value="YEAR">Financial Year 2026-27</option>
            </select>
            <button className="btn btn-primary" onClick={() => handleExportCsv(`${reportType} Report`)}>
              📥 Export CSV / Excel
            </button>
          </div>
        </div>

        {/* ─── REPORT CONTENT PANELS ─── */}
        {reportType === 'REVENUE' && (
          <div>
            <div className="table-responsive">
              <table className="flat-table">
                <thead>
                  <tr>
                    <th>Category Vertical</th>
                    <th>Gross Service Value</th>
                    <th>Booking Fees (₹99)</th>
                    <th>GST Collected (18%)</th>
                    <th>Refunds Processed</th>
                    <th>Net Realized Volume</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td><strong>AC Services</strong></td>
                    <td>₹2,48,500.00</td>
                    <td>₹16,434.00</td>
                    <td>₹47,688.12</td>
                    <td><span style={{ color: '#DC2626' }}>- ₹5,990.00</span></td>
                    <td><strong style={{ color: 'var(--primary)' }}>₹3,06,632.12</strong></td>
                  </tr>
                  <tr>
                    <td><strong>Laptop Repairs</strong></td>
                    <td>₹1,84,200.00</td>
                    <td>₹9,801.00</td>
                    <td>₹34,920.18</td>
                    <td><span style={{ color: '#DC2626' }}>- ₹3,499.00</span></td>
                    <td><strong style={{ color: 'var(--primary)' }}>₹2,25,422.18</strong></td>
                  </tr>
                  <tr>
                    <td><strong>Fan Services</strong></td>
                    <td>₹64,300.00</td>
                    <td>₹8,415.00</td>
                    <td>₹13,088.70</td>
                    <td><span style={{ color: '#DC2626' }}>- ₹897.00</span></td>
                    <td><strong style={{ color: 'var(--primary)' }}>₹84,906.70</strong></td>
                  </tr>
                  <tr>
                    <td><strong>Refrigerator & Appliances</strong></td>
                    <td>₹1,12,400.00</td>
                    <td>₹11,088.00</td>
                    <td>₹22,227.84</td>
                    <td><span style={{ color: '#DC2626' }}>- ₹1,798.00</span></td>
                    <td><strong style={{ color: 'var(--primary)' }}>₹1,43,917.84</strong></td>
                  </tr>
                  <tr style={{ background: 'var(--primary-light)', fontWeight: '800' }}>
                    <td>TOTAL CONSOLIDATED</td>
                    <td>₹6,09,400.00</td>
                    <td>₹45,738.00</td>
                    <td>₹1,17,924.84</td>
                    <td><span style={{ color: '#DC2626' }}>- ₹12,184.00</span></td>
                    <td><strong style={{ color: 'var(--primary)', fontSize: '15px' }}>₹7,60,878.84</strong></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        )}

        {reportType === 'BOOKINGS' && (
          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Booking Status</th>
                  <th>Order Count</th>
                  <th>Share (%)</th>
                  <th>Avg Fulfillment Time</th>
                  <th>SLA Adherence</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><span className="badge badge-completed">Completed Jobs</span></td>
                  <td><strong>92</strong></td>
                  <td>72%</td>
                  <td>54 mins</td>
                  <td><span className="badge badge-completed">98.2% On-time</span></td>
                </tr>
                <tr>
                  <td><span className="badge badge-confirmed">Active In-Field</span></td>
                  <td><strong>28</strong></td>
                  <td>22%</td>
                  <td>In Progress</td>
                  <td><span className="badge badge-info">Live Tracking Active</span></td>
                </tr>
                <tr>
                  <td><span className="badge badge-cancelled">Cancelled within 1h</span></td>
                  <td><strong>8</strong></td>
                  <td>6%</td>
                  <td>N/A</td>
                  <td><span className="badge badge-cancelled">Refund SLA Triggered</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        )}

        {reportType === 'TECHNICIANS' && (
          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Technician</th>
                  <th>Skill Category</th>
                  <th>Completed Jobs</th>
                  <th>Total Earnings</th>
                  <th>Customer Rating</th>
                  <th>Attendance State</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><strong>Rahul Adhikary</strong></td>
                  <td><span className="badge badge-info">AC Service</span></td>
                  <td>142 jobs</td>
                  <td><strong>₹42,800.00</strong></td>
                  <td>⭐ 4.9 (120 reviews)</td>
                  <td><span className="badge badge-completed">🟢 Online</span></td>
                </tr>
                <tr>
                  <td><strong>Amit Singh</strong></td>
                  <td><span className="badge badge-info">Fan Service</span></td>
                  <td>64 jobs</td>
                  <td><strong>₹18,400.00</strong></td>
                  <td>⭐ 4.8 (58 reviews)</td>
                  <td><span className="badge badge-completed">🟢 Online</span></td>
                </tr>
                <tr>
                  <td><strong>Kabir Dev</strong></td>
                  <td><span className="badge badge-info">Refrigerator Service</span></td>
                  <td>38 jobs</td>
                  <td><strong>₹24,600.00</strong></td>
                  <td>⭐ 4.7 (32 reviews)</td>
                  <td><span className="badge badge-cancelled">⚪ Offline</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
