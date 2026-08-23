from typing import List, Tuple
from ..models.schemas import CandidateTechnician, RankedTechnician

def calculate_match_score(
    tech: CandidateTechnician,
    required_skills: List[str] = None
) -> Tuple[float, str]:
    """
    Computes an AI matchmaking index (0 - 100) using a multi-factor weighting model:
    - Distance Factor (Weight: 40%): Closer technicians receive higher scores (max 15km cutoff)
    - Rating Factor (Weight: 30%): Normalized 1-5 star rating
    - Skill Match Factor (Weight: 20%): Overlap between customer request & technician skills
    - Acceptance Rate (Weight: 10%): Reliability history
    """
    # 1. Distance Score (Closer is better, capped at 15km)
    max_radius = 15.0
    clamped_dist = min(tech.distanceKm, max_radius)
    distance_score = max(0.0, (1.0 - (clamped_dist / max_radius)) * 100.0)

    # 2. Rating Score (Normalized to 0 - 100)
    rating_score = (tech.rating / 5.0) * 100.0

    # 3. Skill Match Score
    if required_skills and len(required_skills) > 0:
        matched = set(required_skills).intersection(set(tech.skills or []))
        skill_score = (len(matched) / len(required_skills)) * 100.0
    else:
        skill_score = 90.0 # Default baseline if no specialized sub-skill specified

    # 4. Acceptance Rate Score
    acceptance_score = tech.acceptanceRate

    # Weighted Composite Score
    w_dist = 0.40
    w_rate = 0.30
    w_skill = 0.20
    w_accept = 0.10

    total_score = (
        (w_dist * distance_score) +
        (w_rate * rating_score) +
        (w_skill * skill_score) +
        (w_accept * acceptance_score)
    )

    total_score = round(total_score, 1)

    # Build human-readable recommendation explanation
    reasons = []
    if tech.distanceKm <= 3.0:
        reasons.append("⚡ Hyperlocal (Under 3km)")
    if tech.rating >= 4.8:
        reasons.append(f"⭐ Top Rated ({tech.rating})")
    if tech.totalJobsCompleted >= 50:
        reasons.append("🏆 Experienced Veteran")
    if not reasons:
        reasons.append(f"📍 {tech.distanceKm:.1f}km away")

    reason_str = " · ".join(reasons)
    return total_score, reason_str


def rank_technicians(
    candidates: List[CandidateTechnician],
    required_skills: List[str] = None
) -> List[RankedTechnician]:
    """
    Ranks candidate technicians in descending order of AI match score.
    """
    scored_list = []
    for tech in candidates:
        score, reason = calculate_match_score(tech, required_skills)
        scored_list.append((score, tech, reason))

    # Sort by score descending
    scored_list.sort(key=lambda x: x[0], reverse=True)

    ranked_results = []
    for rank_idx, (score, tech, reason) in enumerate(scored_list, start=1):
        ranked_results.append(
            RankedTechnician(
                technicianId=tech.technicianId,
                matchScore=score,
                distanceKm=tech.distanceKm,
                rating=tech.rating,
                rank=rank_idx,
                recommendationReason=reason,
            )
        )

    return ranked_results
