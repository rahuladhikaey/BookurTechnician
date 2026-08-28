// ============================================================================
// BOOKURTECHNICIAN MASTER SERVICES CATALOG
// Synchronized single source of truth across Admin Panel, Backend APIs, and Customer App
// ============================================================================

let MASTER_CATALOG = [
  // 1. ⚡ Electrical Services
  {
    id: 'cat_electrical',
    categoryId: 'cat_electrical',
    name: 'Electrical Services',
    icon: 'flash_on',
    imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 1,
    subcategories: [
      {
        id: 'sub_fan',
        name: 'Fan Services',
        services: [
          { id: 'fan_rep', name: 'Fan repair', price: 149, basePrice: 199, offerPrice: 149, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 119, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Fixing blade speed, capacitor, winding, or noise issues.', imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop', active: true },
          { id: 'fan_install', name: 'Fan installation', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Standard fan mounting and secure hook installation.', imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop', active: true },
          { id: 'fan_ceiling_install', name: 'Ceiling fan installation', price: 249, basePrice: 299, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Ceiling assembly, rod fitting, downrod check, and balancing.', imageUrl: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=500&auto=format&fit=crop', active: true },
          { id: 'fan_exhaust_install', name: 'Exhaust fan installation', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Kitchen and bathroom exhaust fan fitting and connection.', imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_switch_socket',
        name: 'Switch & Socket',
        services: [
          { id: 'switch_rep', name: 'Switch repair', price: 99, basePrice: 149, offerPrice: 99, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 79, durationMinutes: 20, warrantyText: '30 Days Warranty', description: 'Fixing loose, spark, or non-working electrical switches.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'socket_rep', name: 'Socket repair', price: 99, basePrice: 149, offerPrice: 99, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 79, durationMinutes: 20, warrantyText: '30 Days Warranty', description: 'Repairing power sockets, 3-pin plugs, and loose points.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'switchboard_rep', name: 'Switchboard repair', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Internal board rewiring, sparking repair, and modular fixing.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_lighting',
        name: 'Lighting Solutions',
        services: [
          { id: 'light_rep', name: 'Light repair', price: 99, basePrice: 149, offerPrice: 99, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 79, durationMinutes: 20, warrantyText: '30 Days Warranty', description: 'Troubleshooting dim, flickering, or dead light fixtures.', imageUrl: 'https://images.unsplash.com/photo-1550985616-10810253b84d?w=500&auto=format&fit=crop', active: true },
          { id: 'light_install', name: 'Light installation', price: 149, basePrice: 199, offerPrice: 149, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 119, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Installing wall lamps, brackets, and bulb fixtures.', imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500&auto=format&fit=crop', active: true },
          { id: 'led_install', name: 'LED light installation', price: 149, basePrice: 199, offerPrice: 149, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 119, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Ceiling LED panel, concealed COB, or strip light mounting.', imageUrl: 'https://images.unsplash.com/photo-1567427017947-545c5f8996ac?w=500&auto=format&fit=crop', active: true },
          { id: 'tubelight_svc', name: 'Tube light installation/repair', price: 129, basePrice: 179, offerPrice: 129, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 103, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Batten tube light fitting, choke, or driver replacement.', imageUrl: 'https://images.unsplash.com/photo-1567427017947-545c5f8996ac?w=500&auto=format&fit=crop', active: true },
          { id: 'decorative_light_install', name: 'Decorative light installation', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Chandelier, festive lights, wall art lights, and track lighting.', imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_mcb_protection',
        name: 'MCB, Fuse & Safety',
        services: [
          { id: 'mcb_rep', name: 'MCB repair/replacement', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Replacing tripped or burning single/double-pole MCB.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'fuse_rep', name: 'Fuse repair', price: 99, basePrice: 149, offerPrice: 99, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 79, durationMinutes: 20, warrantyText: '30 Days Warranty', description: 'Rewiring or replacement of blown ceramic/cartridge fuses.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'rccb_install', name: 'RCCB/ELCB installation', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Earth leakage circuit breaker installation for shock prevention.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'short_circuit_fix', name: 'Short-circuit troubleshooting', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Tracing line shorts, burning smell diagnosis, and isolation.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'elec_fault_diag', name: 'Electrical fault diagnosis', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Complete multi-meter voltage, phase, and ground diagnostic.', imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_appliance_connection',
        name: 'Appliance Connections',
        services: [
          { id: 'doorbell_svc', name: 'Doorbell installation/repair', price: 149, basePrice: 199, offerPrice: 149, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 119, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Wired or wireless doorbell chime fitting and wiring.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'geyser_connection', name: 'Geyser electrical connection', price: 249, basePrice: 299, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Heavy duty 16A/20A socket and DP switch wiring for geyser.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'inverter_rep', name: 'Inverter installation/repair', price: 499, basePrice: 599, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Inverter & battery setup, charging calibration, and backup check.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'stabilizer_install', name: 'Stabilizer installation', price: 249, basePrice: 299, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'AC, fridge, or mainline voltage stabilizer connection.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'appliance_connect', name: 'Electrical appliance connection', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Safe high-load electrical connection for home appliances.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 2. 🏠 Home Wiring & Electrical Projects
  {
    id: 'cat_wiring',
    categoryId: 'cat_wiring',
    name: 'Home Wiring & Projects',
    icon: 'home_work',
    imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 2,
    subcategories: [
      {
        id: 'sub_complete_wiring',
        name: 'Complete Home Wiring',
        services: [
          { id: 'house_wiring_new', name: 'New house complete wiring', price: 14999, basePrice: 17999, offerPrice: 14999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 11999, durationMinutes: 480, warrantyText: '90 Days Warranty', description: 'End-to-end multi-room wiring with conduits, boxes, and testing.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'flat_wiring', name: 'Flat complete wiring', price: 8999, basePrice: 10999, offerPrice: 8999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 7199, durationMinutes: 360, warrantyText: '90 Days Warranty', description: '1BHK/2BHK/3BHK complete electrical distribution and wiring.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'room_wiring', name: 'Room wiring', price: 1999, basePrice: 2499, offerPrice: 1999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 1599, durationMinutes: 120, warrantyText: '60 Days Warranty', description: 'Dedicated single bedroom or living area wiring from main DB.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'kitchen_wiring', name: 'Kitchen wiring', price: 1499, basePrice: 1899, offerPrice: 1499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 1199, durationMinutes: 90, warrantyText: '60 Days Warranty', description: 'High load wiring for microwave, chimney, induction, and fridge.', imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop', active: true },
          { id: 'bathroom_wiring', name: 'Bathroom wiring', price: 999, basePrice: 1299, offerPrice: 999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 799, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Moisture-proof wiring for geyser, mirror lights, and exhaust.', imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop', active: true },
          { id: 'shop_wiring', name: 'Commercial shop wiring', price: 6999, basePrice: 8499, offerPrice: 6999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 5599, durationMinutes: 240, warrantyText: '90 Days Warranty', description: 'Showroom and retail shop lighting and point distribution.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'office_wiring', name: 'Office wiring', price: 9999, basePrice: 11999, offerPrice: 9999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 7999, durationMinutes: 300, warrantyText: '90 Days Warranty', description: 'Workstation UPS, server rack, and office lighting layout.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_electrical_installation',
        name: 'Electrical Installation',
        services: [
          { id: 'new_switchboard_install', name: 'New switchboard installation', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Cutting, box embedding, modular board mounting and wiring.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'db_install', name: 'Distribution board installation', price: 999, basePrice: 1299, offerPrice: 999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 799, durationMinutes: 90, warrantyText: '60 Days Warranty', description: 'Main sub-distribution board setup with busbar and circuit tags.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'mcb_box_install', name: 'MCB box installation', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: '4-way to 12-way MCB enclosure installation and dressing.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'main_panel_install', name: 'Main electrical panel installation', price: 1999, basePrice: 2499, offerPrice: 1999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1599, durationMinutes: 180, warrantyText: '90 Days Warranty', description: 'Heavy duty commercial or multi-floor main electrical panel setup.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'meter_board_prep', name: 'Meter board preparation', price: 899, basePrice: 1199, offerPrice: 899, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 719, durationMinutes: 90, warrantyText: '60 Days Warranty', description: 'Electric supply meter board setup complying with electricity board.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'earthing_install', name: 'Earthing installation', price: 1499, basePrice: 1899, offerPrice: 1499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 1199, durationMinutes: 120, warrantyText: '90 Days Warranty', description: 'Chemical earthing / copper rod pit for total shock & surge safety.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'load_distribution', name: 'Electrical load distribution', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Balancing loads between phases to prevent tripping and overheated wires.', imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_wiring_repair',
        name: 'Wiring Repair & Upgrade',
        services: [
          { id: 'old_house_rewiring', name: 'Old house rewiring', price: 4999, basePrice: 6299, offerPrice: 4999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 3999, durationMinutes: 240, warrantyText: '90 Days Warranty', description: 'Replacing aged wires with high-grade fire retardant cables.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'damaged_wire_replace', name: 'Damaged wire replacement', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Pulling new wires through conduits to replace burnt sections.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'concealed_wiring_repair', name: 'Concealed wiring repair', price: 699, basePrice: 899, offerPrice: 699, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 559, durationMinutes: 90, warrantyText: '30 Days Warranty', description: 'Locating in-wall broken circuits without excessive plaster damage.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'open_wiring_install', name: 'Open wiring installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Neat casing-capping surface wiring for rental or new rooms.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'wire_extension', name: 'Wire extension', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Extending electrical line to balconies, terraces, or garden areas.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'power_point_install', name: 'Power point installation', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Installing dedicated 16A/20A power plugs for heavy appliances.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'new_socket_point', name: 'New socket point installation', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Adding an extra wall socket point next to desk or bed.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'new_switch_point', name: 'New switch point installation', price: 149, basePrice: 199, offerPrice: 149, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 119, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Connecting an additional switch for fan, lamp, or appliance.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_special_electrical',
        name: 'Special Electrical Work',
        services: [
          { id: 'three_phase_wiring', name: 'Three-phase wiring', price: 3499, basePrice: 4499, offerPrice: 3499, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 2799, durationMinutes: 180, warrantyText: '90 Days Warranty', description: '415V three-phase commercial and residential power setup.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'single_phase_wiring', name: 'Single-phase wiring', price: 1499, basePrice: 1899, offerPrice: 1499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 1199, durationMinutes: 90, warrantyText: '60 Days Warranty', description: 'Standard 230V domestic supply wiring and breaker protection.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'generator_connect', name: 'Generator connection', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Manual or automatic changeover switch installation for genset.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'inverter_wiring', name: 'Inverter wiring', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Separating inverter line circuits across rooms.', imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop', active: true },
          { id: 'ups_wiring', name: 'UPS wiring', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Dedicated noise-free power line for computers and work setups.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'safety_inspect', name: 'Electrical safety inspection', price: 499, basePrice: 699, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Full audit of grounding, insulation resistance, and hazard prevention.', imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop', active: true },
          { id: 'load_calc', name: 'Load calculation', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Wattage and amperage calculation for meter upgrade or solar install.', imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop', active: true },
          { id: 'fault_inspect', name: 'Electrical fault inspection', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Expert inspection for intermittent trips, high bill causes, and earthing faults.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 3. ❄️ AC Services
  {
    id: 'cat_ac',
    categoryId: 'cat_ac',
    name: 'AC Services',
    icon: 'ac_unit',
    imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 3,
    subcategories: [
      {
        id: 'sub_ac_install_service',
        name: 'Installation & Servicing',
        services: [
          { id: 'ac_install', name: 'AC installation', price: 1299, basePrice: 1599, offerPrice: 1299, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1039, durationMinutes: 90, warrantyText: '30 Days Warranty', description: 'Split or window AC installation with precision bracket leveling.', imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_uninstall', name: 'AC uninstallation', price: 699, basePrice: 899, offerPrice: 699, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 559, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Safe gas lock and indoor/outdoor unit unmounting.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_general_service', name: 'AC general servicing', price: 499, basePrice: 699, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Filter wash, cooling coil brushing, drain tray cleaning.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_deep_cleaning', name: 'Deep cleaning service', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Foam jet high-pressure wash for indoor and outdoor units.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_relocation', name: 'AC relocation', price: 1699, basePrice: 2099, offerPrice: 1699, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1359, durationMinutes: 120, warrantyText: '30 Days Warranty', description: 'Complete uninstallation, transport packing, and reinstall.', imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_ac_repairs',
        name: 'Repair & Troubleshooting',
        services: [
          { id: 'ac_repair_general', name: 'AC repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Diagnosis and fixing of all AC mechanical or electrical issues.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_cooling_problem', name: 'AC cooling problem', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Resolving low airflow, warm air blowing, or slow cooling.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_gas_charging', name: 'AC gas charging/refilling', price: 1899, basePrice: 2299, offerPrice: 1899, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1519, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Nitrogen leak test, vacuuming, and 100% genuine refrigerant refill.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_water_leakage', name: 'AC water leakage repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Clearing clogged drain pipe, tray alignment, and ice buildup.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_pcb_repair', name: 'AC PCB repair', price: 999, basePrice: 1299, offerPrice: 999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 799, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Inverter motherboard repair, display board fixing, and sensor reset.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_electrical_repair', name: 'AC electrical repair', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Capacitor replacement, contactor fixing, and wiring overhaul.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_compressor_issue', name: 'AC compressor issue', price: 1499, basePrice: 1899, offerPrice: 1499, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1199, durationMinutes: 90, warrantyText: '90 Days Warranty', description: 'Compressor tripping, starting relay, and pump replacement.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_noise_vibration', name: 'AC noise/vibration issue', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Blower fan balancing, motor bush oiling, and dampener installation.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_remote_sensor', name: 'AC remote/sensor issue', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'IR receiver repair, sensor replacement, and remote pairing.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'ac_outdoor_repair', name: 'AC outdoor unit repair', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Fan motor fixing, condenser coil cleaning, and valve repair.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'outdoor_mounting', name: 'Outdoor unit mounting', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Heavy duty rust-proof wall bracket installation.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
          { id: 'copper_pipe_install', name: 'Copper pipe installation', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Insulated copper tubing with flare nuts per running meter.', imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 4. 🧊 Refrigerator Services
  {
    id: 'cat_refrigerator',
    categoryId: 'cat_refrigerator',
    name: 'Refrigerator Services',
    icon: 'kitchen',
    imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 4,
    subcategories: [
      {
        id: 'sub_fridge_repair',
        name: 'Refrigerator Repair & Maintenance',
        services: [
          { id: 'fridge_general_rep', name: 'Refrigerator general repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Complete inspection and minor fixes for single & double door fridges.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_cooling_problem', name: 'Cooling problem', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Troubleshooting low cooling in bottom or top freezer compartment.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_gas_charging', name: 'Gas charging', price: 1499, basePrice: 1799, offerPrice: 1499, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1199, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Leak identification, capillary tube flushing, and gas refill.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_compressor_issue', name: 'Compressor issue', price: 1299, basePrice: 1599, offerPrice: 1299, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1039, durationMinutes: 75, warrantyText: '90 Days Warranty', description: 'Relay replacement, OLP fixing, or new compressor installation.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_thermostat_rep', name: 'Thermostat repair', price: 449, basePrice: 599, offerPrice: 449, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 359, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Replacing faulty temperature sensor or mechanical thermostat.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_water_leakage', name: 'Water leakage', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Unclogging defrost drain hole and defrost heater check.', imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_door_seal_rep', name: 'Door/seal repair', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Magnetic gasket rubber seal replacement and door hinge adjustment.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_not_starting', name: 'Refrigerator not starting', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Power cord, thermal fuse, or inverter board diagnostics.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_excessive_cooling', name: 'Excessive cooling/freezing', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Fixing ice buildup in vegetable tray and thermostat over-cycling.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_pcb_rep', name: 'PCB/electrical repair', price: 899, basePrice: 1199, offerPrice: 899, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 719, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Inverter control circuit board diagnostics and soldering.', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'fridge_installation', name: 'Refrigerator installation', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Unpacking, base level adjustment, stabilizer connection, and demo.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
          { id: 'deep_freezer_rep', name: 'Deep freezer repair', price: 699, basePrice: 899, offerPrice: 699, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 559, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Commercial and domestic chest freezer cooling and thermostat repair.', imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 5. 🧺 Washing Machine Services
  {
    id: 'cat_washing',
    categoryId: 'cat_washing',
    name: 'Washing Machine Services',
    icon: 'local_laundry_service',
    imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 5,
    subcategories: [
      {
        id: 'sub_washing_repair',
        name: 'Washing Machine Repair & Care',
        services: [
          { id: 'wm_repair_general', name: 'Washing machine repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'General diagnostics and fixing for top load & front load machines.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_installation', name: 'Installation', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Inlet hose fitting, drain pipe setup, transit bolt removal & leveling.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_uninstallation', name: 'Uninstallation', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Safe disconnection and transit preparation.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_drainage_problem', name: 'Drainage problem', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Clearing clogged drain pump, lint filter, and drain valve repair.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_spin_problem', name: 'Spin problem', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Fixing spin basket not rotating, belt slipping, or capacitor issue.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_water_inlet', name: 'Water inlet problem', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Inlet solenoid valve replacement and low pressure troubleshooting.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_motor_repair', name: 'Motor repair', price: 899, basePrice: 1199, offerPrice: 899, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 719, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Drive motor rewinding, carbon brush, and coupler replacement.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_pcb_repair', name: 'PCB/electrical repair', price: 999, basePrice: 1299, offerPrice: 999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 799, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Microcontroller board repair, error code clearing (dE, OE, UE, etc.).', imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_drum_issue', name: 'Drum issue', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Drum spider arm repair, bearing replacement, and pulsator fixing.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_noise_vibration', name: 'Noise/vibration issue', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Shock absorber suspension rod replacement and base balance.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_door_lock_issue', name: 'Door lock issue', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Front load thermal door lock latch replacement.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
          { id: 'wm_not_starting', name: 'Washing machine not starting', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Mains fuse, door interlock switch, and power supply check.', imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 6. 💻 Laptop & Computer Services
  {
    id: 'cat_computer',
    categoryId: 'cat_computer',
    name: 'Laptop & Computer',
    icon: 'laptop_mac',
    imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 6,
    subcategories: [
      {
        id: 'sub_laptop',
        name: 'Laptop Services',
        services: [
          { id: 'laptop_rep_gen', name: 'Laptop repair', price: 499, basePrice: 699, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Hardware and software troubleshooting for all major laptop brands.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'laptop_diag', name: 'Laptop diagnosis', price: 199, basePrice: 299, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Complete health checkup of battery, SSD, RAM, and motherboard.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'windows_install', name: 'Windows installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Fresh Windows 10/11 installation with genuine drivers and updates.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'software_install', name: 'Software installation', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'MS Office, Adobe suite, development tools, and antivirus setup.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'virus_cleanup', name: 'Virus/malware cleanup', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Deep scanning, spyware removal, and startup speed optimization.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'ssd_upgrade', name: 'SSD upgrade', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'NVMe/SATA SSD installation with OS cloning for 10x faster speed.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'ram_upgrade', name: 'RAM upgrade', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'DDR4/DDR5 RAM memory expansion and dual-channel testing.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'laptop_cleaning', name: 'Laptop cleaning', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Internal heat sink and fan dust cleaning to prevent overheating.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'thermal_paste_rep', name: 'Thermal paste replacement', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'High thermal conductivity paste application on CPU & GPU.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'laptop_screen_rep', name: 'Screen replacement', price: 1999, basePrice: 2499, offerPrice: 1999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1599, durationMinutes: 60, warrantyText: '90 Days Warranty', description: 'FHD / IPS / OLED laptop display panel replacement.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'laptop_kbd_rep', name: 'Keyboard replacement', price: 999, basePrice: 1299, offerPrice: 999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 799, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Original backlit or standard keyboard installation.', imageUrl: 'https://images.unsplash.com/photo-1595225476474-87563907a212?w=500&auto=format&fit=crop', active: true },
          { id: 'laptop_battery_rep', name: 'Battery replacement', price: 699, basePrice: 899, offerPrice: 699, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 559, durationMinutes: 30, warrantyText: '90 Days Warranty', description: 'OEM battery replacement with extended backup warranty.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'charging_port_rep', name: 'Charging port repair', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Type-C / DC jack soldering and loose port replacement.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'motherboard_diag', name: 'Motherboard diagnosis', price: 699, basePrice: 899, offerPrice: 699, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 559, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Chip level short-circuit detection, IO chip, and power rail check.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'laptop_not_turning_on', name: 'Laptop not turning on', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Fixing dead laptop, charging light blinking, or black screen.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_desktop',
        name: 'Desktop Services',
        services: [
          { id: 'desktop_repair', name: 'Desktop repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Complete PC hardware and software troubleshooting.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'pc_assembly', name: 'PC assembly', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 90, warrantyText: '60 Days Warranty', description: 'Custom gaming or workstation PC building with cable management.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'desktop_windows', name: 'Windows installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Clean OS install with BIOS optimization and driver installation.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'hardware_upgrade', name: 'Hardware upgrade', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'GPU, CPU cooler, cabinet fans, or storage installation.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'desktop_ssd_ram', name: 'SSD/RAM upgrade', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Desktop RAM and SSD expansion.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'motherboard_troubleshoot', name: 'Motherboard troubleshooting', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Fixing no post, RAM beep errors, and CMOS battery replacement.', imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop', active: true },
          { id: 'smps_replace', name: 'Power supply replacement', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'SMPS testing and installation.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'desktop_cleaning', name: 'Desktop cleaning', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Blower cleaning, thermal re-pasting, and fan lubrication.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_network',
        name: 'Network & Internet',
        services: [
          { id: 'wifi_troubleshoot', name: 'Wi-Fi troubleshooting', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Fixing frequent Wi-Fi drops, speed issues, and channel congestion.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'router_setup', name: 'Router setup', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Dual-band Wi-Fi router / mesh node configuration and security.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'internet_troubleshoot', name: 'Internet connection troubleshooting', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'DNS, gateway, IP conflict, and adapter diagnosis.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'network_setup', name: 'Home/office network setup', price: 999, basePrice: 1299, offerPrice: 999, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 799, durationMinutes: 90, warrantyText: '60 Days Warranty', description: 'Switch, printer sharing, NAS, and multi-room network setup.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
          { id: 'lan_cable_setup', name: 'LAN cable setup', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Cat6 LAN cable routing, RJ45 crimping, and I/O wall faceplate.', imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 7. 📹 CCTV & Security Services
  {
    id: 'cat_cctv',
    categoryId: 'cat_cctv',
    name: 'CCTV & Security',
    icon: 'videocam',
    imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 7,
    subcategories: [
      {
        id: 'sub_cctv_install',
        name: 'CCTV Installation',
        services: [
          { id: 'cctv_install_gen', name: 'CCTV camera installation', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Standard camera mounting, angle calibration, and power supply.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'indoor_camera_install', name: 'Indoor camera installation', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Dome camera ceiling mounting for home and office rooms.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'outdoor_camera_install', name: 'Outdoor camera installation', price: 449, basePrice: 599, offerPrice: 449, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 359, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Weatherproof bullet camera mounting with junction box.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'wireless_cctv_setup', name: 'Wireless CCTV setup', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Wi-Fi 360-degree smart camera setup and cloud sync.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'wired_cctv_setup', name: 'Wired CCTV setup', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Coaxial / CAT6 conduit routing and BNC / DC connection.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'ip_camera_install', name: 'IP camera installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'PoE IP camera configuration with static IP and NVR integration.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'analog_camera_install', name: 'Analog camera installation', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'HD Analog camera setup with BNC video balun.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_cctv_repair',
        name: 'CCTV Repair',
        services: [
          { id: 'cctv_repair_gen', name: 'CCTV camera repair', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Fixing blurry lens, water condensation, or power adapter failure.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'dvr_repair', name: 'DVR repair', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'DVR power supply, video channel board, or firmware issue fix.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'nvr_repair', name: 'NVR setup/repair', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Network Video Recorder PoE port check and camera stream binding.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'camera_not_working', name: 'Camera not working', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Power line, BNC connector, or voltage drop diagnostics.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'no_video_signal', name: 'No video signal', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Resolving black screen, video loss, or flickering camera feed.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'night_vision_issue', name: 'Night vision problem', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'IR LED board repair, IR cut filter sticking, or color night vision fix.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'storage_recording_issue', name: 'Storage/recording problem', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Fixing HDD not detected, overwrite error, or playback loss.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'cctv_wiring_repair', name: 'CCTV wiring repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Re-splicing broken cables and renewing connectors.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_cctv_system_setup',
        name: 'CCTV System Setup',
        services: [
          { id: 'dvr_install', name: 'DVR installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: '4/8/16 channel DVR setup with HDMI/VGA display connection.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'nvr_install', name: 'NVR installation', price: 599, basePrice: 799, offerPrice: 599, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 479, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'NVR rack installation, PoE switch connection, and IP assign.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'hdd_install', name: 'Hard disk installation', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 25, warrantyText: '30 Days Warranty', description: 'Surveillance HDD formatting and continuous recording schedule.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'cctv_mobile_viewing', name: 'CCTV mobile viewing setup', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Configuring smartphone app for live 24x7 HD camera stream.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'remote_monitoring', name: 'Remote monitoring setup', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Static IP, DDNS, and port forwarding for PC and remote screens.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'multi_camera_config', name: 'Multi-camera configuration', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Configuring motion alerts, masking zones, and AI human detection.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'camera_relocation', name: 'Camera relocation', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Dismantling camera and reinstalling in new point.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
        ],
      },
      {
        id: 'sub_security_systems',
        name: 'Security Systems',
        services: [
          { id: 'video_doorbell_install', name: 'Video doorbell installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Smart Wi-Fi video doorbell mounting with two-way audio setup.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'smart_doorbell_setup', name: 'Smart doorbell setup', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Smartphone app pairing, chime sync, and cloud notification test.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'biometric_install', name: 'Biometric attendance device installation', price: 899, basePrice: 1199, offerPrice: 899, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 719, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Fingerprint / face recognition attendance device mounting & software.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'access_control_install', name: 'Access control installation', price: 1199, basePrice: 1499, offerPrice: 1199, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 959, durationMinutes: 90, warrantyText: '90 Days Warranty', description: 'Electromagnetic EM lock, RFID card reader, and exit switch.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
          { id: 'electronic_door_lock', name: 'Electronic door lock installation', price: 799, basePrice: 999, offerPrice: 799, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 639, durationMinutes: 60, warrantyText: '60 Days Warranty', description: 'Smart digital keypad & fingerprint door lock installation on wooden/glass door.', imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop', active: true },
          { id: 'home_security_system', name: 'Home security system installation', price: 1999, basePrice: 2499, offerPrice: 1999, bookingCharge: 99, advancePrepaymentPct: 30, technicianPayoutAmount: 1599, durationMinutes: 120, warrantyText: '90 Days Warranty', description: 'Siren alarm, magnetic door sensors, and PIR motion sensor setup.', imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },

  // 8. 🔌 Home Appliance Services
  {
    id: 'cat_appliances',
    categoryId: 'cat_appliances',
    name: 'Home Appliances',
    icon: 'microwave',
    imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
    active: true,
    displayOrder: 8,
    subcategories: [
      {
        id: 'sub_kitchen_appliances',
        name: 'Kitchen & Home Appliance Care',
        services: [
          { id: 'microwave_rep', name: 'Microwave repair', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Fixing not heating, turntable not spinning, keypad error, or sparks.', imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop', active: true },
          { id: 'chimney_svc', name: 'Chimney repair/service', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 60, warrantyText: '30 Days Warranty', description: 'Baffle filter degreasing, motor suction repair, and duct checking.', imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop', active: true },
          { id: 'induction_rep', name: 'Induction cooktop repair', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'IGBT replacement, sensor error fix, and glass surface replacement.', imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop', active: true },
          { id: 'mixer_grinder_rep', name: 'Mixer/grinder repair', price: 199, basePrice: 249, offerPrice: 199, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 159, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'Jar coupler replacement, motor carbon brush, and blade sharpening.', imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop', active: true },
          { id: 'ro_service', name: 'Water purifier/RO service', price: 399, basePrice: 499, offerPrice: 399, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 319, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'TDS testing, complete pipeline sanitization, and booster pump check.', imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop', active: true },
          { id: 'ro_installation', name: 'Water purifier installation', price: 499, basePrice: 649, offerPrice: 499, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 399, durationMinutes: 45, warrantyText: '30 Days Warranty', description: 'Wall mounting, diverter valve connection, and waste pipe routing.', imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop', active: true },
          { id: 'ro_filter_replacement', name: 'Water purifier filter replacement', price: 299, basePrice: 399, offerPrice: 299, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 239, durationMinutes: 35, warrantyText: '30 Days Warranty', description: 'Sediment, pre-carbon, RO membrane, and post-carbon cartridge change.', imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop', active: true },
          { id: 'ro_repair', name: 'Water purifier repair', price: 349, basePrice: 449, offerPrice: 349, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 279, durationMinutes: 40, warrantyText: '30 Days Warranty', description: 'Fixing water leakage, auto cutoff failure, and low water output.', imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop', active: true },
          { id: 'kitchen_appliance_troubleshoot', name: 'Kitchen appliance troubleshooting', price: 249, basePrice: 349, offerPrice: 249, bookingCharge: 49, advancePrepaymentPct: 30, technicianPayoutAmount: 199, durationMinutes: 30, warrantyText: '30 Days Warranty', description: 'General electrical troubleshooting for toasters, kettles, and blenders.', imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop', active: true },
        ],
      },
    ],
  },
];

// Helper: Flatten all services into tabular items for Admin Table / Pricing Table
function getFlattenedServices() {
  const result = [];
  MASTER_CATALOG.forEach(cat => {
    (cat.subcategories || []).forEach(sub => {
      (sub.services || []).forEach(srv => {
        result.push({
          ...srv,
          categoryId: cat.id,
          categoryName: cat.name,
          category: { id: cat.id, name: cat.name },
          subcategoryId: sub.id,
          subcategoryName: sub.name,
          subcategory: { id: sub.id, name: sub.name },
        });
      });
    });
  });
  return result;
}

// Helper: Get categories with counts
function getAdminCategories() {
  return MASTER_CATALOG.map((cat, idx) => {
    const srvCount = (cat.subcategories || []).reduce((sum, sub) => sum + (sub.services || []).length, 0);
    return {
      id: cat.id,
      categoryId: cat.categoryId || cat.id,
      name: cat.name,
      iconUrl: cat.imageUrl,
      bannerUrl: cat.imageUrl,
      active: cat.active !== false,
      displayOrder: cat.displayOrder || (idx + 1),
      servicesCount: srvCount,
      subcategories: cat.subcategories || [],
    };
  });
}

// Helper: Update pricing for a specific service ID
function updateServicePricing(serviceId, pricingData) {
  let found = false;
  let updatedService = null;

  MASTER_CATALOG.forEach(cat => {
    (cat.subcategories || []).forEach(sub => {
      (sub.services || []).forEach(srv => {
        if (srv.id === serviceId) {
          found = true;
          if (pricingData.price !== undefined) srv.price = parseFloat(pricingData.price) || srv.price;
          if (pricingData.basePrice !== undefined) srv.basePrice = parseFloat(pricingData.basePrice) || srv.basePrice;
          if (pricingData.offerPrice !== undefined) srv.offerPrice = parseFloat(pricingData.offerPrice) || srv.offerPrice;
          if (pricingData.bookingCharge !== undefined) srv.bookingCharge = parseFloat(pricingData.bookingCharge) || srv.bookingCharge;
          if (pricingData.advancePrepaymentPct !== undefined) srv.advancePrepaymentPct = parseInt(pricingData.advancePrepaymentPct, 10) || srv.advancePrepaymentPct;
          if (pricingData.technicianPayoutAmount !== undefined) srv.technicianPayoutAmount = parseFloat(pricingData.technicianPayoutAmount) || srv.technicianPayoutAmount;
          if (pricingData.durationMinutes !== undefined) srv.durationMinutes = parseInt(pricingData.durationMinutes, 10) || srv.durationMinutes;
          if (pricingData.warrantyText !== undefined) srv.warrantyText = pricingData.warrantyText;
          if (pricingData.active !== undefined) srv.active = pricingData.active;
          updatedService = { ...srv, categoryId: cat.id, categoryName: cat.name, subcategoryId: sub.id, subcategoryName: sub.name };
        }
      });
    });
  });

  return updatedService;
}

// Helper: Update service full metadata
function updateServiceItem(serviceId, updateData) {
  let updatedService = null;

  MASTER_CATALOG.forEach(cat => {
    (cat.subcategories || []).forEach(sub => {
      const idx = (sub.services || []).findIndex(s => s.id === serviceId);
      if (idx !== -1) {
        sub.services[idx] = {
          ...sub.services[idx],
          ...updateData,
          id: serviceId,
        };
        updatedService = {
          ...sub.services[idx],
          categoryId: cat.id,
          categoryName: cat.name,
          subcategoryId: sub.id,
          subcategoryName: sub.name,
        };
      }
    });
  });

  return updatedService;
}

// Helper: Create a new service under a category/subcategory
function createServiceItem(serviceData) {
  const targetCatId = serviceData.categoryId || 'cat_electrical';
  const targetSubId = serviceData.subcategoryId || 'sub_fan';
  
  let targetCat = MASTER_CATALOG.find(c => c.id === targetCatId);
  if (!targetCat) {
    targetCat = MASTER_CATALOG[0];
  }

  let targetSub = (targetCat.subcategories || []).find(s => s.id === targetSubId);
  if (!targetSub) {
    if (!targetCat.subcategories) targetCat.subcategories = [];
    if (targetCat.subcategories.length === 0) {
      targetCat.subcategories.push({ id: 'sub_general', name: 'General Services', services: [] });
    }
    targetSub = targetCat.subcategories[0];
  }

  const newService = {
    id: serviceData.id || `srv_${Date.now().toString(36)}`,
    name: serviceData.name || serviceData.title || 'New Custom Service',
    price: parseFloat(serviceData.price || serviceData.basePrice) || 199,
    basePrice: parseFloat(serviceData.basePrice || serviceData.price) || 249,
    offerPrice: parseFloat(serviceData.offerPrice || serviceData.price) || 199,
    bookingCharge: parseFloat(serviceData.bookingCharge) || 49,
    advancePrepaymentPct: parseInt(serviceData.advancePrepaymentPct, 10) || 30,
    technicianPayoutAmount: parseFloat(serviceData.technicianPayoutAmount) || 159,
    durationMinutes: parseInt(serviceData.durationMinutes || serviceData.estimatedDurationMinutes, 10) || 45,
    warrantyText: serviceData.warrantyText || '30 Days Warranty',
    description: serviceData.description || '',
    imageUrl: serviceData.imageUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
    active: serviceData.active !== false,
  };

  targetSub.services.push(newService);
  return {
    ...newService,
    categoryId: targetCat.id,
    categoryName: targetCat.name,
    subcategoryId: targetSub.id,
    subcategoryName: targetSub.name,
  };
}

// Helper: Delete service item
function deleteServiceItem(serviceId) {
  let deleted = false;
  MASTER_CATALOG.forEach(cat => {
    (cat.subcategories || []).forEach(sub => {
      const initialLen = sub.services.length;
      sub.services = (sub.services || []).filter(s => s.id !== serviceId);
      if (sub.services.length < initialLen) {
        deleted = true;
      }
    });
  });
  return deleted;
}

// Helper: Create category
function createCategoryItem(catData) {
  const newCat = {
    id: catData.id || `cat_${Date.now().toString(36)}`,
    categoryId: catData.categoryId || `cat_${Date.now().toString(36)}`,
    name: catData.name || 'New Category',
    icon: catData.icon || 'build',
    imageUrl: catData.imageUrl || catData.iconUrl || 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
    active: catData.active !== false,
    displayOrder: MASTER_CATALOG.length + 1,
    subcategories: catData.subcategories || [
      { id: `sub_${Date.now().toString(36)}`, name: 'General Services', services: [] },
    ],
  };
  MASTER_CATALOG.push(newCat);
  return newCat;
}

// Helper: Update category
function updateCategoryItem(catId, catData) {
  const index = MASTER_CATALOG.findIndex(c => c.id === catId || c.categoryId === catId);
  if (index === -1) return null;
  MASTER_CATALOG[index] = {
    ...MASTER_CATALOG[index],
    ...catData,
    id: MASTER_CATALOG[index].id,
  };
  return MASTER_CATALOG[index];
}

// Helper: Delete category
function deleteCategoryItem(catId) {
  const initialLen = MASTER_CATALOG.length;
  MASTER_CATALOG = MASTER_CATALOG.filter(c => c.id !== catId && c.categoryId !== catId);
  return MASTER_CATALOG.length < initialLen;
}

function getMasterCatalog() {
  return MASTER_CATALOG;
}

module.exports = {
  getMasterCatalog,
  getFlattenedServices,
  getAdminCategories,
  updateServicePricing,
  updateServiceItem,
  createServiceItem,
  deleteServiceItem,
  createCategoryItem,
  updateCategoryItem,
  deleteCategoryItem,
};
