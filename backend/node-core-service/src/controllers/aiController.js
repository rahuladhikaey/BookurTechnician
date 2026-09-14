/**
 * Embedded AI Matchmaker & Dynamic Pricing Engine (Node.js High-Performance Fallback)
 * Provides 100% parity with Python FastAPI AI Engine
 */

const calculateMatchScore = (tech, requiredSkills = []) => {
  const maxRadius = 15.0;
  const clampedDist = Math.min(tech.distanceKm || 5.0, maxRadius);
  const distanceScore = Math.max(0, (1.0 - (clampedDist / maxRadius)) * 100.0);

  const rating = tech.rating || 4.8;
  const ratingScore = (rating / 5.0) * 100.0;

  let skillScore = 90.0;
  if (requiredSkills.length > 0 && tech.skills) {
    const matched = requiredSkills.filter(s => tech.skills.includes(s));
    skillScore = (matched.length / requiredSkills.length) * 100.0;
  }

  const acceptanceScore = tech.acceptanceRate || 95.0;

  const totalScore = parseFloat((
    (0.40 * distanceScore) +
    (0.30 * ratingScore) +
    (0.20 * skillScore) +
    (0.10 * acceptanceScore)
  ).toFixed(1));

  const reasons = [];
  if (tech.distanceKm <= 3.0) reasons.append ? reasons.push('⚡ Hyperlocal (Under 3km)') : reasons.push('⚡ Hyperlocal (Under 3km)');
  if (rating >= 4.8) reasons.push(`⭐ Top Rated (${rating})`);
  if ((tech.totalJobsCompleted || 0) >= 50) reasons.push('🏆 Experienced Veteran');
  if (reasons.length === 0) reasons.push(`📍 ${(tech.distanceKm || 5.0).toFixed(1)}km away`);

  return {
    score: totalScore,
    reason: reasons.join(' · '),
  };
};

const matchTechnicians = async (req, res) => {
  try {
    const { bookingId, candidateTechnicians = [], requiredSkills = [] } = req.body;

    const scored = candidateTechnicians.map((tech) => {
      const { score, reason } = calculateMatchScore(tech, requiredSkills);
      return {
        technicianId: tech.technicianId,
        matchScore: score,
        distanceKm: tech.distanceKm,
        rating: tech.rating || 4.8,
        recommendationReason: reason,
      };
    });

    scored.sort((a, b) => b.matchScore - a.matchScore);

    const rankedMatches = scored.map((item, index) => ({
      ...item,
      rank: index + 1,
    }));

    return res.json({
      success: true,
      bookingId,
      rankedMatches,
      topPickId: rankedMatches[0]?.technicianId || null,
      totalEvaluated: candidateTechnicians.length,
      engine: 'Node.js Embedded AI Matchmaker Engine',
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const computeDynamicPricing = async (req, res) => {
  try {
    const { category = 'ELECTRICIAN', basePrice = 299, distanceKm = 3.0, isPeakHour = false, urgencyLevel = 'STANDARD' } = req.body;

    let surge = 1.0;
    if (isPeakHour) surge += 0.15;
    if (urgencyLevel === 'EMERGENCY') surge += 0.35;
    else if (urgencyLevel === 'URGENT') surge += 0.15;

    const distanceAddon = distanceKm > 10.0 ? 50.0 : 0.0;
    const laborPrice = parseFloat(((basePrice * surge) + distanceAddon).toFixed(2));
    const taxAmount = parseFloat((laborPrice * 0.18).toFixed(2));
    const finalPrice = parseFloat((laborPrice + taxAmount).toFixed(2));

    return res.json({
      success: true,
      category,
      basePrice,
      surgeMultiplier: parseFloat(surge.toFixed(2)),
      estimatedLaborPrice: laborPrice,
      taxAmount,
      finalEstimatedPrice: finalPrice,
      estimatedDurationMinutes: category.toUpperCase().includes('AC') ? 75 : 45,
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

const diagnoseIssue = async (req, res) => {
  const { category = 'ELECTRICIAN', issueDescription = '' } = req.body;
  const desc = issueDescription.toLowerCase();

  let causes = ['General component wear & tear requiring on-site inspection'];
  let tools = ['Standard Electrician / Technician Multi-Tool Kit'];
  let complexity = 'LOW';

  if (desc.includes('spark') || desc.includes('short') || desc.includes('trip')) {
    causes = ['MCB Overload / Tripping', 'Loose Neutral Wire Connection', 'Damaged insulation inside switchboard'];
    tools = ['Digital Multimeter', 'Insulated Screwdriver Set', 'Wire Stripper & Tester'];
    complexity = 'HIGH';
  } else if (desc.includes('leak') || desc.includes('drip')) {
    causes = ['Worn-out O-ring washer', 'Corroded valve seal', 'High inlet water pressure'];
    tools = ['Adjustable Pipe Wrench', 'Teflon Thread Seal Tape', 'Basin Wrench'];
    complexity = 'LOW';
  }

  return res.json({
    success: true,
    category,
    potentialCauses: causes,
    suggestedTools: tools,
    estimatedComplexity: complexity,
    recommendedServiceCategory: category.toUpperCase(),
  });
};

module.exports = {
  matchTechnicians,
  computeDynamicPricing,
  diagnoseIssue,
};
