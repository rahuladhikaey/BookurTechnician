from fastapi import APIRouter, HTTPException
from ..models.schemas import (
    MatchRequest, MatchResponse,
    PricingRequest, PricingResponse,
    DiagnosticRequest, DiagnosticResponse
)
from ..services.matchmaker import rank_technicians
from ..services.pricing import compute_dynamic_pricing, diagnose_issue

router = APIRouter(prefix="/api/v1/ai", tags=["AI & Matchmaking"])

@router.post("/match", response_model=MatchResponse)
async def match_technicians_endpoint(request: MatchRequest):
    try:
        ranked = rank_technicians(request.candidateTechnicians, request.requiredSkills)
        top_pick = ranked[0].technicianId if ranked else None

        return MatchResponse(
            success=True,
            bookingId=request.bookingId,
            rankedMatches=ranked,
            topPickId=top_pick,
            totalEvaluated=len(request.candidateTechnicians)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/dynamic-pricing", response_model=PricingResponse)
async def dynamic_pricing_endpoint(request: PricingRequest):
    try:
        return compute_dynamic_pricing(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/diagnostics", response_model=DiagnosticResponse)
async def diagnostic_assistant_endpoint(request: DiagnosticRequest):
    try:
        return diagnose_issue(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
