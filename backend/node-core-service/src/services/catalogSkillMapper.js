/**
 * 🗺️ BookUrTechnician Canonical Skill ↔ Service Mapper
 * Provides bidirectional resolution between Master Catalog Service IDs (e.g. 'fan_rep', 'mcb_rep', 'ac_deep_cleaning')
 * and Technician Skill IDs / Names / Categories (e.g. 'sk_ceiling_fan_repair', 'Fan repair', 'cat_electrical').
 */

const { getFlattenedServices, getMasterCatalog } = require('../config/masterCatalog');

// Static and dynamic canonical alias registry
const SERVICE_SKILL_SYNONYMS = {
  // ⚡ Fan Services
  fan_rep: [
    'fan_rep', 'fan_repair', 'sk_fan_repair', 'sk_ceiling_fan_repair', 'sk_stand_fan_repair',
    'ceiling_fan_repair', 'stand_fan_repair', 'fan repair', 'ceiling fan repair', 'stand fan repair',
    'table fan repair', 'exhaust fan repair', 'fan'
  ],
  fan_install: [
    'fan_install', 'fan_installation', 'sk_fan_installation', 'sk_ceiling_fan_installation',
    'ceiling_fan_installation', 'fan installation', 'ceiling fan installation', 'exhaust fan'
  ],
  fan_ceiling_install: [
    'fan_ceiling_install', 'sk_ceiling_fan_installation', 'sk_ceiling_fan_repair', 'ceiling_fan_installation',
    'ceiling_fan_repair', 'ceiling fan installation', 'ceiling fan repair', 'fan installation', 'fan repair'
  ],
  fan_exhaust_install: [
    'fan_exhaust_install', 'sk_exhaust_fan', 'exhaust_fan', 'exhaust fan', 'exhaust fan installation'
  ],

  // ⚡ Switch & Socket
  switch_rep: [
    'switch_rep', 'switch_repair', 'sk_switch_repair', 'sk_switch_board_repair',
    'switchboard_repair', 'switch repair', 'switch board repair', 'switch'
  ],
  socket_rep: [
    'socket_rep', 'socket_repair', 'sk_socket_repair', 'socket repair', 'socket', '3-pin plug repair'
  ],
  switchboard_rep: [
    'switchboard_rep', 'switchboard_repair', 'sk_switch_board_repair', 'sk_switchboard_repair',
    'switch board repair', 'switchboard repair', 'modular switchboard'
  ],

  // ⚡ Lighting
  light_rep: [
    'light_rep', 'light_repair', 'sk_light_repair', 'light repair', 'light', 'lamp repair'
  ],
  light_install: [
    'light_install', 'light_installation', 'sk_light_installation', 'light installation',
    'wall light installation'
  ],
  led_install: [
    'led_install', 'led_light_installation', 'sk_led_installation_repair', 'led installation/repair',
    'led light installation', 'led panel'
  ],
  tubelight_svc: [
    'tubelight_svc', 'sk_tube_light', 'tube light installation/repair', 'tubelight', 'batten light'
  ],
  decorative_light_install: [
    'decorative_light_install', 'decorative light installation', 'chandelier installation'
  ],

  // ⚡ MCB & Safety
  mcb_rep: [
    'mcb_rep', 'mcb_repair', 'sk_mcb_repair', 'sk_mcb_distribution_board_repair',
    'mcb/distribution board repair', 'mcb repair/replacement', 'mcb replacement'
  ],
  fuse_rep: [
    'fuse_rep', 'fuse_repair', 'sk_fuse_repair', 'fuse repair', 'fuse'
  ],
  rccb_install: [
    'rccb_install', 'sk_mcb_installation', 'mcb installation', 'rccb/elcb installation', 'elcb'
  ],
  short_circuit_fix: [
    'short_circuit_fix', 'sk_short_circuit_troubleshooting', 'short circuit troubleshooting',
    'short circuit', 'tripping fix'
  ],
  elec_fault_diag: [
    'elec_fault_diag', 'electrical fault diagnosis', 'fault diagnosis', 'basic electrician'
  ],

  // ⚡ Connections & Inverter
  doorbell_svc: [
    'doorbell_svc', 'sk_doorbell_installation', 'doorbell installation', 'doorbell repair'
  ],
  geyser_connection: [
    'geyser_connection', 'geyser electrical connection', 'geyser power point'
  ],
  inverter_rep: [
    'inverter_rep', 'inverter_installation_repair', 'sk_inverter_installation', 'sk_inverter_repair',
    'inverter installation', 'inverter repair', 'inverter installation/repair'
  ],
  stabilizer_install: [
    'stabilizer_install', 'stabilizer installation', 'voltage stabilizer'
  ],
  appliance_connect: [
    'appliance_connect', 'sk_electrical_appliance_connection', 'electrical appliance connection'
  ],

  // 🏠 Wiring Projects
  house_wiring_new: [
    'house_wiring_new', 'sk_full_house_wiring', 'full house wiring', 'new house complete wiring', 'house wiring'
  ],
  flat_wiring: [
    'flat_wiring', 'flat complete wiring', 'apartment wiring'
  ],
  room_wiring: [
    'room_wiring', 'room wiring', 'single room wiring'
  ],
  kitchen_wiring: [
    'kitchen_wiring', 'kitchen wiring'
  ],
  bathroom_wiring: [
    'bathroom_wiring', 'bathroom wiring'
  ],
  shop_wiring: [
    'shop_wiring', 'commercial shop wiring'
  ],
  office_wiring: [
    'office_wiring', 'office wiring'
  ],
  new_switchboard_install: [
    'new_switchboard_install', 'sk_new_electrical_installation', 'new electrical installation',
    'new switchboard installation'
  ],
  db_install: [
    'db_install', 'distribution board installation', 'db dressing'
  ],
  mcb_box_install: [
    'mcb_box_install', 'mcb box installation'
  ],
  main_panel_install: [
    'main_panel_install', 'main electrical panel installation'
  ],
  meter_board_prep: [
    'meter_board_prep', 'meter board preparation'
  ],
  earthing_install: [
    'earthing_install', 'earthing installation', 'copper earthing pit'
  ],
  old_house_rewiring: [
    'old_house_rewiring', 'sk_wiring_repair', 'wiring repair', 'old house rewiring'
  ],
  damaged_wire_replace: [
    'damaged_wire_replace', 'sk_wiring_repair', 'damaged wire replacement'
  ],
  concealed_wiring_repair: [
    'concealed_wiring_repair', 'sk_wiring_repair', 'concealed wiring repair'
  ],
  open_wiring_install: [
    'open_wiring_install', 'open wiring installation', 'casing capping'
  ],
  power_point_install: [
    'power_point_install', 'power point installation', '16a power socket'
  ],
  three_phase_wiring: [
    'three_phase_wiring', 'three-phase wiring', '3 phase wiring'
  ],
  single_phase_wiring: [
    'single_phase_wiring', 'single-phase wiring'
  ],
  inverter_wiring: [
    'inverter_wiring', 'sk_inverter_installation', 'inverter wiring'
  ],

  // ❄️ AC Services
  ac_install: [
    'ac_install', 'sk_ac_installation', 'ac installation', 'split ac', 'window ac'
  ],
  ac_uninstall: [
    'ac_uninstall', 'sk_ac_uninstallation', 'ac uninstallation', 'ac unmounting'
  ],
  ac_general_service: [
    'ac_general_service', 'sk_ac_general_service', 'ac general service', 'ac general servicing', 'ac servicing'
  ],
  ac_deep_cleaning: [
    'ac_deep_cleaning', 'sk_ac_deep_cleaning', 'ac deep cleaning', 'deep cleaning service', 'jet pump cleaning'
  ],
  ac_relocation: [
    'ac_relocation', 'ac relocation', 'ac shift'
  ],
  ac_repair_general: [
    'ac_repair_general', 'ac_repair', 'sk_ac_cooling_problem', 'sk_ac_electrical_repair',
    'ac repair', 'ac troubleshooting'
  ],
  ac_cooling_problem: [
    'ac_cooling_problem', 'sk_ac_cooling_problem', 'ac cooling problem', 'low cooling'
  ],
  ac_gas_charging: [
    'ac_gas_charging', 'sk_ac_gas_charging', 'sk_ac_gas_leakage_inspection',
    'ac gas charging/refilling', 'ac gas charging', 'ac gas refill', 'gas charging'
  ],
  ac_water_leakage: [
    'ac_water_leakage', 'ac water leakage repair', 'ac water dripping'
  ],
  ac_pcb_repair: [
    'ac_pcb_repair', 'ac pcb repair', 'inverter ac pcb'
  ],
  ac_electrical_repair: [
    'ac_electrical_repair', 'sk_ac_electrical_repair', 'ac electrical repair'
  ],
  ac_compressor_issue: [
    'ac_compressor_issue', 'ac compressor issue', 'compressor replacement'
  ],

  // 🧊 Refrigerator Services
  fridge_general_rep: [
    'fridge_general_rep', 'sk_refrigerator_repair', 'refrigerator repair', 'refrigerator general repair', 'fridge repair'
  ],
  fridge_cooling_problem: [
    'fridge_cooling_problem', 'sk_refrigerator_cooling_problem', 'cooling problem', 'fridge cooling problem'
  ],
  fridge_gas_charging: [
    'fridge_gas_charging', 'sk_gas_charging', 'gas charging', 'fridge gas charging'
  ],
  fridge_compressor_issue: [
    'fridge_compressor_issue', 'sk_compressor_related_service', 'compressor related service', 'compressor issue'
  ],
  fridge_thermostat_rep: [
    'fridge_thermostat_rep', 'thermostat repair'
  ],
  fridge_door_seal_rep: [
    'fridge_door_seal_rep', 'sk_door_gasket_repair', 'door/gasket repair', 'door/seal repair'
  ],
  fridge_pcb_rep: [
    'fridge_pcb_rep', 'sk_refrigerator_electrical_repair', 'pcb/electrical repair', 'refrigerator electrical repair'
  ],

  // 🧺 Washing Machine Services
  wm_repair_general: [
    'wm_repair_general', 'sk_washing_machine_repair', 'washing machine repair', 'washing machine general repair'
  ],
  wm_installation: [
    'wm_installation', 'sk_washing_machine_installation', 'washing machine installation', 'installation'
  ],
  wm_drainage_problem: [
    'wm_drainage_problem', 'sk_drainage_problem', 'drainage problem'
  ],
  wm_spin_problem: [
    'wm_spin_problem', 'sk_spin_problem', 'spin problem'
  ],
  wm_water_inlet: [
    'wm_water_inlet', 'sk_water_inlet_problem', 'water inlet problem'
  ],
  wm_pcb_repair: [
    'wm_pcb_repair', 'sk_washing_machine_electrical_repair', 'pcb/electrical repair', 'washing machine electrical repair'
  ],

  // 💻 Computer & Laptop
  laptop_rep_gen: [
    'laptop_rep_gen', 'sk_laptop_repair', 'laptop repair', 'laptop repair general'
  ],
  laptop_diag: [
    'laptop_diag', 'laptop diagnosis', 'hardware troubleshooting'
  ],
  windows_install: [
    'windows_install', 'sk_windows_os_installation', 'windows installation', 'windows/os installation'
  ],
  software_install: [
    'software_install', 'sk_software_troubleshooting', 'software installation', 'software troubleshooting'
  ],
  desktop_repair: [
    'desktop_repair', 'sk_computer_repair', 'computer repair', 'desktop repair'
  ],
  pc_assembly: [
    'pc_assembly', 'sk_desktop_assembly', 'desktop assembly', 'pc assembly'
  ],

  // 📹 CCTV & Security
  cctv_install_gen: [
    'cctv_install_gen', 'sk_cctv_installation', 'cctv installation', 'cctv camera installation'
  ],
  cctv_repair_gen: [
    'cctv_repair_gen', 'cctv camera repair', 'cctv repair'
  ],
  dvr_install: [
    'dvr_install', 'dvr installation', 'nvr installation'
  ],
  video_doorbell_install: [
    'video_doorbell_install', 'video doorbell installation', 'smart doorbell setup'
  ],
  electronic_door_lock: [
    'electronic_door_lock', 'sk_door_lock_repair', 'door lock repair', 'electronic door lock installation'
  ],

  // 🔌 Appliances
  microwave_rep: [
    'microwave_rep', 'microwave repair', 'microwave oven repair'
  ],
  chimney_svc: [
    'chimney_svc', 'chimney repair/service', 'kitchen chimney repair'
  ],
  ro_service: [
    'ro_service', 'water purifier/ro service', 'ro service', 'ro repair'
  ],
};

/**
 * Normalizes text for robust comparisons
 */
const cleanString = (str) => {
  if (!str) return '';
  return String(str)
    .toLowerCase()
    .trim()
    .replace(/^sk_/, '')
    .replace(/^cat_/, '')
    .replace(/^sub_/, '')
    .replace(/[\s\-_/\\,]+/g, ' ');
};

/**
 * Maps a single technician skill identifier (e.g. 'sk_ceiling_fan_repair', 'Ceiling Fan Repair', 'fan_rep')
 * to an array of matching Master Catalog Service IDs.
 * @param {string|object} skillInput
 * @returns {string[]} array of matching serviceIds
 */
const resolveServiceIdsFromSkill = (skillInput) => {
  const raw = typeof skillInput === 'object' ? (skillInput.skillId || skillInput.id || skillInput.name || '') : String(skillInput || '');
  const cleanInput = cleanString(raw);
  if (!cleanInput) return [];

  const matchedServiceIds = new Set();

  // 1. Direct exact or synonym check
  for (const [srvId, synonyms] of Object.entries(SERVICE_SKILL_SYNONYMS)) {
    for (const syn of synonyms) {
      const cleanSyn = cleanString(syn);
      if (cleanInput === cleanSyn || cleanInput.includes(cleanSyn) || cleanSyn.includes(cleanInput)) {
        matchedServiceIds.add(srvId);
      }
    }
  }

  // 2. Cross-reference with flattened master catalog
  const catalog = getFlattenedServices();
  for (const srv of catalog) {
    const sId = srv.id;
    const cleanSrvId = cleanString(sId);
    const cleanSrvName = cleanString(srv.name);
    const cleanCatName = cleanString(srv.categoryName || srv.categoryId);

    if (cleanInput === cleanSrvId || cleanInput.includes(cleanSrvId) || cleanSrvId.includes(cleanInput)) {
      matchedServiceIds.add(sId);
    } else if (cleanInput === cleanSrvName || cleanInput.includes(cleanSrvName) || cleanSrvName.includes(cleanInput)) {
      matchedServiceIds.add(sId);
    }
  }

  // If exact raw ID exists in catalog, ensure it is added
  const directMatch = catalog.find(s => s.id.toLowerCase() === raw.toLowerCase());
  if (directMatch) {
    matchedServiceIds.add(directMatch.id);
  }

  return Array.from(matchedServiceIds);
};

/**
 * Returns all synonym strings & skill identifiers for a given serviceId
 * Used for building comprehensive SQL WHERE / JOIN clauses.
 * @param {string} serviceId
 * @returns {string[]}
 */
const getSkillSynonymsForService = (serviceId) => {
  if (!serviceId) return [];
  const srvId = String(serviceId).trim().toLowerCase();
  const synonyms = new Set();

  synonyms.add(srvId);
  synonyms.add(`sk_${srvId}`);
  synonyms.add(srvId.replace(/_/g, ' '));
  synonyms.add(srvId.replace(/_/g, '-'));

  if (SERVICE_SKILL_SYNONYMS[srvId]) {
    for (const syn of SERVICE_SKILL_SYNONYMS[srvId]) {
      synonyms.add(syn);
      synonyms.add(cleanString(syn));
      synonyms.add(`sk_${cleanString(syn).replace(/\s+/g, '_')}`);
    }
  }

  // Also lookup in Master Catalog for service name, slug, category
  const catalog = getFlattenedServices();
  const item = catalog.find(s => s.id.toLowerCase() === srvId);
  if (item) {
    synonyms.add(item.name.toLowerCase());
    synonyms.add(item.name);
    if (item.slug) synonyms.add(item.slug.toLowerCase());
    const cleanName = cleanString(item.name);
    synonyms.add(cleanName);
    synonyms.add(`sk_${cleanName.replace(/\s+/g, '_')}`);
  }

  return Array.from(synonyms).filter(Boolean);
};

/**
 * Checks if a technician profile's skills or category match a target serviceId
 * @param {object} profile - { skills: string[]|object[], category: string }
 * @param {string} targetServiceId
 * @returns {boolean}
 */
const doesTechnicianMatchService = (profile, targetServiceId) => {
  if (!profile || !targetServiceId) return false;

  const targetSynonyms = getSkillSynonymsForService(targetServiceId).map(s => cleanString(s));
  const rawSkills = Array.isArray(profile.skills) ? profile.skills : (typeof profile.skills === 'string' ? [profile.skills] : []);

  // 1. If technician has declared specific skills, ONLY those skills determine matching
  if (rawSkills.length > 0) {
    for (const s of rawSkills) {
      const sStr = typeof s === 'object' ? (s.skillId || s.id || s.name || '') : String(s);
      const cleanSkill = cleanString(sStr);
      
      // Check direct match with service synonyms
      if (targetSynonyms.some(syn => syn === cleanSkill || cleanSkill.includes(syn) || syn.includes(cleanSkill))) {
        return true;
      }

      // Check if skill resolves to targetServiceId
      const resolvedSrvIds = resolveServiceIdsFromSkill(sStr);
      if (resolvedSrvIds.includes(targetServiceId)) {
        return true;
      }
    }
    return false; // Has specific skills, but none matched this service
  }

  // 2. If technician has no specific skills configured yet (new account), fallback to base category
  const cat = cleanString(profile.category || '');
  const allServices = getFlattenedServices();
  const srv = allServices.find(s => s.id === targetServiceId);
  if (srv) {
    const srvCat = cleanString(srv.categoryName || srv.categoryId || '');
    if (cat && srvCat && (cat === srvCat || cat.includes(srvCat) || srvCat.includes(cat))) {
      return true;
    }
  }

  return false;
};

module.exports = {
  resolveServiceIdsFromSkill,
  getSkillSynonymsForService,
  doesTechnicianMatchService,
  SERVICE_SKILL_SYNONYMS,
};

