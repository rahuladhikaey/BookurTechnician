/**
 * Canonical Central Catalog Service & Skill Schema
 * BookurTechnician (Pure Firebase Architecture)
 */

const CANONICAL_SERVICE_ALIASES = {
  // AC Services
  'sk_ac_installation': 'ac_install',
  'ac installation': 'ac_install',
  'ac_install': 'ac_install',
  'sk_ac_uninstallation': 'ac_uninstall',
  'ac uninstallation': 'ac_uninstall',
  'ac_uninstall': 'ac_uninstall',
  'sk_deep_cleaning_service': 'ac_deep_cleaning',
  'deep cleaning service': 'ac_deep_cleaning',
  'ac deep cleaning service': 'ac_deep_cleaning',
  'ac deep cleaning': 'ac_deep_cleaning',
  'ac_deep_cleaning': 'ac_deep_cleaning',
  'ac_deep_clean': 'ac_deep_cleaning',
  'sk_ac_repair': 'ac_repair_general',
  'ac repair': 'ac_repair_general',
  'ac_repair_general': 'ac_repair_general',
  'ac_repair': 'ac_repair_general',
  'sk_ac_pcb_repair': 'ac_pcb_repair',
  'ac pcb repair': 'ac_pcb_repair',
  'ac_pcb_repair': 'ac_pcb_repair',
  'sk_ac_relocation': 'ac_relocation',
  'ac relocation': 'ac_relocation',
  'ac_relocation': 'ac_relocation',
  'sk_ac_general_servicing': 'ac_general_service',
  'ac general servicing': 'ac_general_service',
  'ac general service': 'ac_general_service',
  'sk_ac_general_service': 'ac_general_service',
  'ac_general_service': 'ac_general_service',
  'sk_gas_refill_top_up': 'ac_gas_refill',
  'gas refill / top-up': 'ac_gas_refill',
  'ac gas refill': 'ac_gas_refill',
  'gas refill': 'ac_gas_refill',
  'ac_gas_refill': 'ac_gas_refill',
  'ac_gas_charging': 'ac_gas_refill',
  'ac gas charging/refilling': 'ac_gas_refill',
  'ac cooling problem': 'ac_cooling_problem',
  'ac cooling issue': 'ac_cooling_problem',
  'sk_ac_cooling_problem': 'ac_cooling_problem',
  'ac_cooling_issue': 'ac_cooling_problem',
  'ac_cooling_problem': 'ac_cooling_problem',
  'ac compressor issue': 'ac_compressor_issue',
  'ac compressor repair': 'ac_compressor_issue',
  'ac_compressor_repair': 'ac_compressor_issue',
  'ac_compressor_issue': 'ac_compressor_issue',
  'ac water leakage repair': 'ac_water_leakage',
  'sk_ac_water_leakage': 'ac_water_leakage',
  'ac_water_leakage': 'ac_water_leakage',
  'ac electrical repair': 'ac_electrical_repair',
  'sk_ac_electrical_repair': 'ac_electrical_repair',
  'ac_electrical_repair': 'ac_electrical_repair',
  'ac noise/vibration issue': 'ac_noise_vibration',
  'ac_noise_vibration': 'ac_noise_vibration',
  'ac outdoor unit repair': 'ac_outdoor_repair',
  'ac_outdoor_repair': 'ac_outdoor_repair',
  'ac remote/sensor issue': 'ac_remote_sensor',
  'ac_remote_sensor': 'ac_remote_sensor',
  'copper pipe installation': 'copper_pipe_install',
  'copper_pipe_install': 'copper_pipe_install',

  // Electrical Services
  'sk_ceiling_fan_installation': 'fan_ceiling_install',
  'ceiling fan installation': 'fan_ceiling_install',
  'fan_ceiling_install': 'fan_ceiling_install',
  'sk_exhaust_fan': 'fan_exhaust_install',
  'exhaust fan': 'fan_exhaust_install',
  'exhaust fan installation': 'fan_exhaust_install',
  'fan_exhaust_install': 'fan_exhaust_install',
  'sk_fan_installation': 'fan_install',
  'fan installation': 'fan_install',
  'fan_install': 'fan_install',
  'sk_ceiling_fan_repair': 'fan_rep',
  'ceiling fan repair': 'fan_rep',
  'fan repair': 'fan_rep',
  'fan_rep': 'fan_rep',
  'sk_fan_repair': 'fan_rep',
  'sk_light_repair': 'light_rep',
  'light repair': 'light_rep',
  'light_rep': 'light_rep',
  'sk_light_installation': 'light_install',
  'light installation': 'light_install',
  'light_install': 'light_install',
  'sk_led_installation_repair': 'led_install',
  'led installation/repair': 'led_install',
  'led light installation': 'led_install',
  'led_install': 'led_install',
  'led_light_install': 'led_install',
  'decorative light installation': 'decorative_light_install',
  'decorative_light_install': 'decorative_light_install',
  'sk_basic_electrician': 'elec_fault_diag',
  'basic electrician': 'elec_fault_diag',
  'electrical fault diagnosis': 'elec_fault_diag',
  'elec_fault_diag': 'elec_fault_diag',
  'sk_mcb_repair': 'mcb_rep',
  'mcb repair': 'mcb_rep',
  'mcb replacement': 'mcb_rep',
  'mcb repair/replacement': 'mcb_rep',
  'mcb_rep': 'mcb_rep',
  'mcb_replace': 'mcb_rep',
  'sk_fuse_repair': 'fuse_rep',
  'fuse repair': 'fuse_rep',
  'fuse_rep': 'fuse_rep',
  'doorbell installation/repair': 'doorbell_svc',
  'doorbell_svc': 'doorbell_svc',
  'inverter installation/repair': 'inverter_rep',
  'inverter repair': 'inverter_rep',
  'inverter_rep': 'inverter_rep',
  'inverter_install': 'inverter_rep',
  'geyser electrical connection': 'geyser_connection',
  'geyser_connection': 'geyser_connection',
  'electrical appliance connection': 'appliance_connect',
  'appliance_connect': 'appliance_connect',
  'switch repair': 'switch_rep',
  'switch replacement': 'switch_rep',
  'switch_rep': 'switch_rep',
  'switch_replace': 'switch_rep',
  'socket repair': 'socket_rep',
  'socket replacement': 'socket_rep',
  'socket_rep': 'socket_rep',
  'socket_replace': 'socket_rep',
  'switchboard repair': 'switchboard_repair',
  'switchboard_repair': 'switchboard_repair',
};

function resolveCanonicalServiceId(rawId, name) {
  if (rawId) {
    const clean = String(rawId).trim().toLowerCase();
    if (CANONICAL_SERVICE_ALIASES[clean]) {
      return CANONICAL_SERVICE_ALIASES[clean];
    }
    const norm = clean.replace(/^sk_/, '').replace(/_/g, ' ').trim();
    if (CANONICAL_SERVICE_ALIASES[norm]) {
      return CANONICAL_SERVICE_ALIASES[norm];
    }
    if (clean.length > 0) {
      return clean;
    }
  }
  if (name) {
    const cleanName = String(name).trim().toLowerCase();
    if (CANONICAL_SERVICE_ALIASES[cleanName]) {
      return CANONICAL_SERVICE_ALIASES[cleanName];
    }
  }
  return '';
}

/**
 * Validates whether a technician possesses the verified, active skill for the requested service.
 * Category matching alone is strictly prohibited.
 */
function doesTechnicianPossessVerifiedSkill(techDoc, serviceId, serviceName) {
  if (!techDoc) return false;
  const targetCanonical = resolveCanonicalServiceId(serviceId, serviceName);
  if (!targetCanonical) return false;

  const rawSkills = [
    ...(Array.isArray(techDoc.skills) ? techDoc.skills : []),
    ...(Array.isArray(techDoc.selectedSkills) ? techDoc.selectedSkills : []),
  ];

  if (rawSkills.length === 0) return false;

  for (const skill of rawSkills) {
    let skillId = '';
    let canonicalId = '';
    let skillName = '';
    let verificationStatus = 'VERIFIED';
    let isSkillEnabled = true;

    if (skill && typeof skill === 'object') {
      skillId = skill.skillId || skill.id || '';
      canonicalId = skill.canonicalServiceId || skill.serviceId || '';
      skillName = skill.name || skill.skillName || '';
      const rawVer = (skill.verificationStatus || skill.status || '').toUpperCase().trim();
      if (rawVer) {
        verificationStatus = rawVer;
      }
      if ('enabled' in skill) {
        isSkillEnabled = skill.enabled === true;
      }
      if ('isActive' in skill) {
        isSkillEnabled = isSkillEnabled && skill.isActive === true;
      }
    } else if (typeof skill === 'string') {
      skillId = skill;
      canonicalId = skill;
      skillName = skill;
    }

    // 1. Mandatory verification check: Must be VERIFIED
    if (verificationStatus !== 'VERIFIED') continue;

    // 2. Mandatory active toggle check: Must be enabled
    if (!isSkillEnabled) continue;

    // 3. Exact Canonical ID match
    const skillCanonical = resolveCanonicalServiceId(
      canonicalId || skillId || skillName,
      skillName
    );

    if (skillCanonical && skillCanonical === targetCanonical) {
      return true;
    }

    if (skillName) {
      const nameCanonical = resolveCanonicalServiceId(null, skillName);
      if (nameCanonical && nameCanonical === targetCanonical) {
        return true;
      }
    }
  }

  return false;
}

module.exports = {
  CANONICAL_SERVICE_ALIASES,
  resolveCanonicalServiceId,
  doesTechnicianPossessVerifiedSkill,
};

