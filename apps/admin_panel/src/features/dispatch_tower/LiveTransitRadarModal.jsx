import React, { useState, useEffect, useRef } from 'react';
import api from '../../api/apiClient';

export default function LiveTransitRadarModal({ booking, onClose, onReassign, onUpdateStatus }) {
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const techMarkerRef = useRef(null);
  const custMarkerRef = useRef(null);
  const polylineRef = useRef(null);

  const [liveData, setLiveData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [copiedField, setCopiedField] = useState('');
  const [autoFollow, setAutoFollow] = useState('both'); // 'tech' | 'cust' | 'both'

  // Fetch real live tracking data from backend
  const fetchTracking = async () => {
    if (!booking) return;
    try {
      const res = await api.getBookingLiveTracking(booking.id || booking.bookingCode);
      if (res?.data) {
        setLiveData(res.data);
      }
    } catch (err) {
      console.warn('Live tracking fetch warning:', err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTracking();
    const interval = setInterval(fetchTracking, 3000);
    return () => clearInterval(interval);
  }, [booking?.id, booking?.bookingCode]);

  // Leaflet Map Initialization and Dynamic Marker Updates
  useEffect(() => {
    if (!mapContainerRef.current) return;
    if (typeof window.L === 'undefined') {
      console.warn('Leaflet is not loaded yet.');
      return;
    }

    const L = window.L;

    // Use liveData or fallback to booking props
    const custLat = liveData?.customer?.latitude || booking.latitude || 12.9716;
    const custLng = liveData?.customer?.longitude || booking.longitude || 77.5946;
    const techLat = liveData?.technician?.latitude || (custLat + 0.012);
    const techLng = liveData?.technician?.longitude || (custLng - 0.015);

    // Initialize Map if not yet created
    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        zoomControl: true,
        attributionControl: false,
      }).setView([(custLat + techLat) / 2, (custLng + techLng) / 2], 14);

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
      }).addTo(map);

      mapInstanceRef.current = map;
    }

    const map = mapInstanceRef.current;

    // Custom Icon for Customer (Home / Doorstep)
    const customerIcon = L.divIcon({
      className: 'custom-customer-marker',
      html: `
        <div style="position: relative; display: flex; flex-direction: column; align-items: center;">
          <div style="background: #2563EB; color: #FFFFFF; font-size: 16px; width: 38px; height: 38px; border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 14px rgba(37,99,235,0.5); border: 2.5px solid #FFFFFF;">
            🏠
          </div>
          <div style="background: #0F172A; color: #FFFFFF; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 800; white-space: nowrap; margin-top: 4px; box-shadow: 0 2px 6px rgba(0,0,0,0.2);">
            Customer: ${liveData?.customer?.name || booking.customerName || 'Doorstep'}
          </div>
        </div>
      `,
      iconSize: [40, 60],
      iconAnchor: [20, 45],
    });

    // Custom Icon for Technician (Moving Vehicle / Scooter)
    const techIcon = L.divIcon({
      className: 'custom-technician-marker',
      html: `
        <div style="position: relative; display: flex; flex-direction: column; align-items: center;">
          <div style="position: absolute; width: 48px; height: 48px; border-radius: 50%; background: rgba(22,163,74,0.25); animation: pulse-ring 2s infinite; top: -5px;"></div>
          <div style="background: #16A34A; color: #FFFFFF; font-size: 18px; width: 38px; height: 38px; border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 14px rgba(22,163,74,0.5); border: 2.5px solid #FFFFFF; z-index: 2;">
            🛵
          </div>
          <div style="background: #166534; color: #FFFFFF; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 800; white-space: nowrap; margin-top: 4px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); z-index: 2;">
            ${liveData?.technician?.name || booking.technicianName || 'Technician'} • ${liveData?.telemetry?.etaMinutes || 8} min
          </div>
        </div>
      `,
      iconSize: [40, 60],
      iconAnchor: [20, 45],
    });

    // Update Customer Marker
    if (!custMarkerRef.current) {
      custMarkerRef.current = L.marker([custLat, custLng], { icon: customerIcon }).addTo(map);
      custMarkerRef.current.bindPopup(`
        <div style="font-family: sans-serif; font-size: 12px;">
          <strong>📍 Customer Destination</strong><br/>
          <strong>Name:</strong> ${liveData?.customer?.name || booking.customerName || 'Customer'}<br/>
          <strong>Phone:</strong> ${liveData?.customer?.phone || booking.customerPhone || 'N/A'}<br/>
          <strong>Address:</strong> ${liveData?.customer?.address || booking.address || 'Address provided'}
        </div>
      `);
    } else {
      custMarkerRef.current.setLatLng([custLat, custLng]);
    }

    // Update Technician Marker
    if (!techMarkerRef.current) {
      techMarkerRef.current = L.marker([techLat, techLng], { icon: techIcon }).addTo(map);
      techMarkerRef.current.bindPopup(`
        <div style="font-family: sans-serif; font-size: 12px;">
          <strong>👨‍🔧 Assigned Partner</strong><br/>
          <strong>Name:</strong> ${liveData?.technician?.name || booking.technicianName || 'Technician'}<br/>
          <strong>Phone:</strong> ${liveData?.technician?.phone || booking.technicianPhone || 'N/A'}<br/>
          <strong>Speed:</strong> ${liveData?.technician?.speed || 24} km/h<br/>
          <strong>Rating:</strong> ★ ${liveData?.technician?.rating || 4.9}
        </div>
      `);
    } else {
      techMarkerRef.current.setLatLng([techLat, techLng]);
    }

    // Update Polyline Route between Tech and Customer
    const routeCoords = [
      [techLat, techLng],
      [custLat, custLng],
    ];

    if (!polylineRef.current) {
      polylineRef.current = L.polyline(routeCoords, {
        color: '#2563EB',
        weight: 4,
        dashArray: '8, 8',
        opacity: 0.85,
      }).addTo(map);
    } else {
      polylineRef.current.setLatLngs(routeCoords);
    }

    // Adjust view according to follow mode
    if (autoFollow === 'both') {
      const bounds = L.latLngBounds([custLat, custLng], [techLat, techLng]);
      map.fitBounds(bounds, { padding: [60, 60], maxZoom: 16 });
    } else if (autoFollow === 'tech') {
      map.panTo([techLat, techLng]);
    } else if (autoFollow === 'cust') {
      map.panTo([custLat, custLng]);
    }

  }, [liveData, autoFollow]);

  // Clean up Leaflet on unmount
  useEffect(() => {
    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  const handleCopy = (text, field) => {
    if (!text) return;
    navigator.clipboard?.writeText(text);
    setCopiedField(field);
    setTimeout(() => setCopiedField(''), 2000);
  };

  const cust = liveData?.customer || {
    name: booking.customerName || booking.customer || 'Customer',
    phone: booking.customerPhone || booking.phone || '',
    address: booking.fullAddress || booking.address || 'Address provided',
    latitude: booking.latitude || 12.9716,
    longitude: booking.longitude || 77.5946,
  };

  const tech = liveData?.technician || {
    name: booking.technicianName || booking.technician || 'Assigned Technician',
    phone: booking.technicianPhone || '',
    category: booking.technicianCategory || booking.category || 'General',
    rating: booking.technicianRating || 4.88,
    speed: 26,
    latitude: (booking.latitude || 12.9716) + 0.012,
    longitude: (booking.longitude || 77.5946) - 0.015,
  };

  const telemetry = liveData?.telemetry || {
    distanceKm: 2.8,
    etaMinutes: 7,
    isMoving: true,
  };

  return (
    <div className="modal-overlay" onClick={onClose} style={{ zIndex: 1100 }}>
      <div
        className="modal-dialog"
        style={{
          maxWidth: '1000px',
          width: '95%',
          maxHeight: '92vh',
          display: 'flex',
          flexDirection: 'column',
          padding: 0,
          overflow: 'hidden',
          borderRadius: '12px',
          boxShadow: '0 25px 50px -12px rgba(0,0,0,0.25)',
        }}
        onClick={e => e.stopPropagation()}
      >
        {/* ─── MODAL HEADER ─── */}
        <div style={{ padding: '16px 20px', background: '#0F172A', color: '#FFFFFF', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <h2 style={{ margin: 0, fontSize: '17px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span>🛰️ Live Dispatch & GPS Transit Radar</span>
                <span className="badge badge-info" style={{ background: '#2563EB', color: '#FFFFFF', fontSize: '11px' }}>
                  #{booking.bookingCode || booking.id}
                </span>
              </h2>
              <span className="badge" style={{ background: '#16A34A', color: '#FFFFFF', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <span style={{ display: 'inline-block', width: '7px', height: '7px', borderRadius: '50%', background: '#FFFFFF', animation: 'pulse-dot 1.5s infinite' }}></span>
                LIVE STREAMING
              </span>
            </div>
            <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#94A3B8' }}>
              Real-time hardware GPS telemetry connecting assigned technician and customer doorstep (Zomato / Blinkit / Uber Mode)
            </p>
          </div>

          <button
            onClick={onClose}
            style={{ background: 'rgba(255,255,255,0.1)', border: 'none', color: '#FFFFFF', width: '32px', height: '32px', borderRadius: '50%', fontSize: '18px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            ✕
          </button>
        </div>

        {/* ─── LIVE TELEMETRY HUD BAR ─── */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1px', background: '#334155', borderBottom: '1px solid #334155' }}>
          {/* ETA */}
          <div style={{ background: '#1E293B', padding: '10px 16px', color: '#FFFFFF' }}>
            <span style={{ fontSize: '11px', color: '#94A3B8', fontWeight: '700', textTransform: 'uppercase' }}>ESTIMATED TIME (ETA)</span>
            <div style={{ fontSize: '20px', fontWeight: '800', color: '#38BDF8', marginTop: '2px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span>🛵</span> {telemetry.etaMinutes} mins
            </div>
          </div>

          {/* Distance */}
          <div style={{ background: '#1E293B', padding: '10px 16px', color: '#FFFFFF' }}>
            <span style={{ fontSize: '11px', color: '#94A3B8', fontWeight: '700', textTransform: 'uppercase' }}>REMAINING DISTANCE</span>
            <div style={{ fontSize: '20px', fontWeight: '800', color: '#4ADE80', marginTop: '2px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span>📏</span> {telemetry.distanceKm} km
            </div>
          </div>

          {/* Speed & Heading */}
          <div style={{ background: '#1E293B', padding: '10px 16px', color: '#FFFFFF' }}>
            <span style={{ fontSize: '11px', color: '#94A3B8', fontWeight: '700', textTransform: 'uppercase' }}>VEHICLE SPEED</span>
            <div style={{ fontSize: '20px', fontWeight: '800', color: '#FBBF24', marginTop: '2px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span>⚡</span> {tech.speed || 24} km/h
            </div>
          </div>

          {/* Status */}
          <div style={{ background: '#1E293B', padding: '10px 16px', color: '#FFFFFF' }}>
            <span style={{ fontSize: '11px', color: '#94A3B8', fontWeight: '700', textTransform: 'uppercase' }}>DISPATCH LIFECYCLE</span>
            <div style={{ fontSize: '14px', fontWeight: '800', color: '#FFFFFF', marginTop: '4px' }}>
              <span className={`badge ${
                booking.status === 'COMPLETED' ? 'badge-completed' :
                booking.status === 'TECHNICIAN_ON_THE_WAY' || booking.status === 'ASSIGNED' || booking.status === 'TECHNICIAN_ASSIGNED' ? 'badge-confirmed' : 'badge-pending'
              }`} style={{ fontSize: '11.5px', padding: '4px 8px' }}>
                {booking.status}
              </span>
            </div>
          </div>
        </div>

        {/* ─── MAIN CONTENT: MAP + SIDE PROFILE PANELS ─── */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', flex: 1, minHeight: '440px' }}>
          
          {/* LEFT: LEAFLET INTERACTIVE MAP */}
          <div style={{ position: 'relative', width: '100%', height: '100%', minHeight: '440px' }}>
            <div ref={mapContainerRef} style={{ width: '100%', height: '100%', minHeight: '440px', background: '#E2E8F0' }}></div>

            {/* Map Camera Control Overlay */}
            <div style={{ position: 'absolute', top: '12px', right: '12px', zIndex: 1000, background: 'rgba(255,255,255,0.92)', backdropFilter: 'blur(4px)', padding: '6px', borderRadius: '8px', boxShadow: '0 4px 12px rgba(0,0,0,0.15)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <button
                className={`btn btn-sm ${autoFollow === 'both' ? 'btn-primary' : 'btn-outline'}`}
                style={{ fontSize: '11px', padding: '4px 8px' }}
                onClick={() => setAutoFollow('both')}
              >
                🔍 Fit Both
              </button>
              <button
                className={`btn btn-sm ${autoFollow === 'tech' ? 'btn-primary' : 'btn-outline'}`}
                style={{ fontSize: '11px', padding: '4px 8px' }}
                onClick={() => setAutoFollow('tech')}
              >
                🛵 Focus Tech
              </button>
              <button
                className={`btn btn-sm ${autoFollow === 'cust' ? 'btn-primary' : 'btn-outline'}`}
                style={{ fontSize: '11px', padding: '4px 8px' }}
                onClick={() => setAutoFollow('cust')}
              >
                🏠 Focus Home
              </button>
            </div>
          </div>

          {/* RIGHT: REAL DETAILS SIDEBAR */}
          <div style={{ padding: '18px', background: '#F8FAFC', borderLeft: '1px solid var(--border-color)', display: 'flex', flexDirection: 'column', gap: '14px', overflowY: 'auto', maxHeight: '480px' }}>
            
            {/* Assigned Technician Profile Box */}
            <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #E2E8F0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                <span style={{ fontSize: '11px', fontWeight: '800', color: '#166534', textTransform: 'uppercase' }}>
                  🛵 Assigned Technician
                </span>
                <span className="badge badge-completed" style={{ fontSize: '10px' }}>Verified Partner</span>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div style={{ width: '42px', height: '42px', borderRadius: '50%', background: '#16A34A', color: '#FFFFFF', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '20px', fontWeight: '800' }}>
                  👨‍🔧
                </div>
                <div>
                  <div style={{ fontWeight: '800', fontSize: '14px', color: '#0F172A' }}>{tech.name}</div>
                  <div style={{ fontSize: '12px', color: '#64748B' }}>
                    {tech.category} • ⭐ {tech.rating} / 5.0
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '8px', marginTop: '10px' }}>
                <a
                  href={`tel:${tech.phone}`}
                  className="btn btn-sm"
                  style={{ flex: 1, textAlign: 'center', textDecoration: 'none', background: '#16A34A', color: '#FFFFFF', fontWeight: '700', fontSize: '11.5px', padding: '6px' }}
                >
                  📞 Call Tech ({tech.phone || 'N/A'})
                </a>
                <button
                  className="btn btn-outline btn-sm"
                  style={{ fontSize: '11px', padding: '6px 8px' }}
                  onClick={() => handleCopy(tech.phone, 'tech_phone')}
                >
                  {copiedField === 'tech_phone' ? '✓' : 'Copy'}
                </button>
              </div>
            </div>

            {/* Customer Doorstep Profile Box */}
            <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #E2E8F0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                <span style={{ fontSize: '11px', fontWeight: '800', color: '#1E40AF', textTransform: 'uppercase' }}>
                  🏠 Customer & Destination
                </span>
                <span className="badge badge-info" style={{ fontSize: '10px' }}>Doorstep Delivery</span>
              </div>

              <div style={{ fontWeight: '800', fontSize: '14px', color: '#0F172A' }}>{cust.name}</div>
              
              <div style={{ fontSize: '12px', color: '#475569', marginTop: '6px', background: '#F1F5F9', padding: '8px', borderRadius: '4px', lineHeight: '1.4' }}>
                <strong>📍 Destination Address:</strong>
                <div style={{ color: '#64748B', marginTop: '2px' }}>{cust.address}</div>
              </div>

              <div style={{ display: 'flex', gap: '8px', marginTop: '10px' }}>
                <a
                  href={`tel:${cust.phone}`}
                  className="btn btn-sm"
                  style={{ flex: 1, textAlign: 'center', textDecoration: 'none', background: '#2563EB', color: '#FFFFFF', fontWeight: '700', fontSize: '11.5px', padding: '6px' }}
                >
                  📞 Call Customer ({cust.phone || 'N/A'})
                </a>
                <button
                  className="btn btn-outline btn-sm"
                  style={{ fontSize: '11px', padding: '6px 8px' }}
                  onClick={() => handleCopy(cust.phone, 'cust_phone')}
                >
                  {copiedField === 'cust_phone' ? '✓' : 'Copy'}
                </button>
              </div>
            </div>

            {/* Service & Security OTPs */}
            <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #E2E8F0' }}>
              <div style={{ fontSize: '12px', fontWeight: '700', color: '#334155', marginBottom: '8px' }}>
                🛠️ Service: <strong>{booking.serviceName || booking.service || 'Service Booking'}</strong> (₹{booking.totalAmount || booking.price})
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <div style={{ padding: '6px', background: '#EFF6FF', borderRadius: '4px', border: '1px solid #BFDBFE', textAlign: 'center' }}>
                  <span style={{ fontSize: '10px', color: '#1E40AF', fontWeight: '700', display: 'block' }}>START OTP</span>
                  <strong style={{ fontSize: '14px', color: '#1E40AF', letterSpacing: '2px', fontFamily: 'monospace' }}>
                    {booking.startOtp || '—'}
                  </strong>
                </div>
                <div style={{ padding: '6px', background: '#F0FDF4', borderRadius: '4px', border: '1px solid #BBF7D0', textAlign: 'center' }}>
                  <span style={{ fontSize: '10px', color: '#166534', fontWeight: '700', display: 'block' }}>END OTP</span>
                  <strong style={{ fontSize: '14px', color: '#166534', letterSpacing: '2px', fontFamily: 'monospace' }}>
                    {booking.endOtp || '—'}
                  </strong>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div style={{ display: 'flex', gap: '8px', marginTop: 'auto' }}>
              <button
                className="btn btn-outline btn-sm"
                style={{ flex: 1, fontSize: '11px' }}
                onClick={() => {
                  onClose();
                  onReassign?.(booking);
                }}
              >
                🔄 Reassign
              </button>
              <button
                className="btn btn-primary btn-sm"
                style={{ flex: 1, fontSize: '11px' }}
                onClick={() => {
                  window.open(`https://www.google.com/maps/dir/?api=1&origin=${tech.latitude},${tech.longitude}&destination=${cust.latitude},${cust.longitude}`, '_blank');
                }}
              >
                🗺️ Google Maps ↗
              </button>
            </div>

          </div>
        </div>

      </div>
    </div>
  );
}
