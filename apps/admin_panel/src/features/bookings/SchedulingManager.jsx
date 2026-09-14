import React, { useState } from 'react';

export default function SchedulingManager({ auditLogAction }) {
  const [maxAdvanceDays, setMaxAdvanceDays] = useState(3); // 3-Day Limitation
  const [slotDurationMinutes, setSlotDurationMinutes] = useState(60);
  const [maxBookingsPerSlot, setMaxBookingsPerSlot] = useState(15);
  const [workingStart, setWorkingStart] = useState('08:00 AM');
  const [workingEnd, setWorkingEnd] = useState('09:00 PM');
  const [blackoutDates, setBlackoutDates] = useState(['2026-10-02', '2026-12-25']);
  const [newBlackoutDate, setNewBlackoutDate] = useState('');

  const activeTimeSlots = [
    '09:00 AM – 10:00 AM',
    '11:00 AM – 12:00 PM',
    '02:00 PM – 03:00 PM',
    '03:00 PM – 04:00 PM',
    '05:00 PM – 06:00 PM',
    '07:00 PM – 08:00 PM'
  ];

  const handleSaveScheduling = (e) => {
    e.preventDefault();
    auditLogAction(
      'Scheduling Engine',
      `Updated Scheduling Rules: Max Advance Limit = ${maxAdvanceDays} Days, Slot Duration = ${slotDurationMinutes} mins, Max Bookings/Slot = ${maxBookingsPerSlot}, Hours = ${workingStart} to ${workingEnd}`
    );
    alert('Scheduling & 3-Day Slot limitation successfully synced with Customer App!');
  };

  const handleAddBlackout = (e) => {
    e.preventDefault();
    if (newBlackoutDate && !blackoutDates.includes(newBlackoutDate)) {
      setBlackoutDates(prev => [...prev, newBlackoutDate]);
      auditLogAction('Scheduling Engine', `Added blackout holiday date: ${newBlackoutDate}`);
      setNewBlackoutDate('');
    }
  };

  return (
    <div className="scheduling-manager-view">
      <div className="section-header">
        <div>
          <h2>Service Scheduling & 3-Day Slot Configuration</h2>
          <p style={{ fontSize: '13px', color: '#64748B' }}>
            Enforce client booking date limits (1 to 3 days advance max), slot duration, capacity limits, and operating blackout windows.
          </p>
        </div>
      </div>

      <div className="pricing-grid-layout">
        {/* ─── SCHEDULING RULES FORM ─── */}
        <div className="settings-card">
          <h3>📅 Booking Advance & Operating Hours</h3>
          <form onSubmit={handleSaveScheduling}>
            <div className="form-group" style={{ marginBottom: '16px' }}>
              <label>Maximum Booking Advance Window (Days)</label>
              <input
                type="number"
                value={maxAdvanceDays}
                onChange={e => setMaxAdvanceDays(Number(e.target.value))}
                min="1"
                max="7"
                required
              />
              <span className="helper-text" style={{ color: '#16A34A', fontWeight: 'bold' }}>
                ✓ Set to 3 Days (Today, Tomorrow, Day After Tomorrow) as per platform rule.
              </span>
            </div>

            <div className="form-group" style={{ marginBottom: '16px' }}>
              <label>Slot Interval Duration (Minutes)</label>
              <select value={slotDurationMinutes} onChange={e => setSlotDurationMinutes(Number(e.target.value))}>
                <option value="30">30 Minutes</option>
                <option value="45">45 Minutes</option>
                <option value="60">60 Minutes (Standard 1 Hour)</option>
                <option value="90">90 Minutes</option>
              </select>
            </div>

            <div className="form-group" style={{ marginBottom: '16px' }}>
              <label>Maximum Concurrent Bookings Per Time Slot</label>
              <input
                type="number"
                value={maxBookingsPerSlot}
                onChange={e => setMaxBookingsPerSlot(Number(e.target.value))}
                min="1"
                max="100"
                required
              />
              <span className="helper-text">
                Prevents technician overbooking across covered service zones.
              </span>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
              <div className="form-group">
                <label>Daily Start Time</label>
                <input type="text" value={workingStart} onChange={e => setWorkingStart(e.target.value)} />
              </div>
              <div className="form-group">
                <label>Daily End Time</label>
                <input type="text" value={workingEnd} onChange={e => setWorkingEnd(e.target.value)} />
              </div>
            </div>

            <button type="submit" className="btn primary" style={{ width: '100%' }}>
              Save Scheduling Configuration
            </button>
          </form>
        </div>

        {/* ─── ACTIVE SLOTS & BLACKOUT DATES ─── */}
        <div className="settings-card">
          <h3>🕒 Active Daily Service Time Slots</h3>
          <div className="slots-chips-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', margin: '12px 0 20px' }}>
            {activeTimeSlots.map((slot, i) => (
              <div key={i} style={{ padding: '10px', background: '#F1F5F9', borderRadius: '8px', border: '1px solid #CBD5E1', textAlign: 'center', fontSize: '12.5px', fontWeight: 'bold', color: '#0B1635' }}>
                {slot}
              </div>
            ))}
          </div>

          <h3 style={{ marginTop: '16px' }}>🚫 Blackout & Holiday Dates</h3>
          <p style={{ fontSize: '12px', color: '#64748B', marginBottom: '10px' }}>
            Dates where service booking is disabled on the Customer App:
          </p>

          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '14px' }}>
            {blackoutDates.map(d => (
              <li key={d} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', background: '#FEE2E2', borderRadius: '6px', fontSize: '12px', color: '#991B1B' }}>
                <span>📅 {d} (National Holiday / Blackout)</span>
                <button className="text-btn danger" onClick={() => setBlackoutDates(prev => prev.filter(x => x !== d))}>✕</button>
              </li>
            ))}
          </ul>

          <form onSubmit={handleAddBlackout} style={{ display: 'flex', gap: '8px' }}>
            <input
              type="date"
              value={newBlackoutDate}
              onChange={e => setNewBlackoutDate(e.target.value)}
              style={{ flex: 1 }}
            />
            <button type="submit" className="btn outline">Add Holiday</button>
          </form>
        </div>
      </div>
    </div>
  );
}
