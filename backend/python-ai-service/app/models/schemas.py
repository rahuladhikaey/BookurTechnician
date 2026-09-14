from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

class CandidateTechnician(BaseModel):
    technicianId: str
    distanceKm: float = Field(..., ge=0.0, description="Distance from customer in KM")
    rating: float = Field(default=4.8, ge=1.0, le=5.0)
    totalJobsCompleted: int = Field(default=25, ge=0)
    acceptanceRate: float = Field(default=95.0, ge=0.0, le=100.0)
    skills: List[str] = Field(default_factory=list)
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class MatchRequest(BaseModel):
    bookingId: str
    category: str
    customerLatitude: float
    customerLongitude: float
    candidateTechnicians: List[CandidateTechnician] = Field(default_factory=list)
    requiredSkills: Optional[List[str]] = None

class RankedTechnician(BaseModel):
    technicianId: str
    matchScore: float
    distanceKm: float
    rating: float
    rank: int
    recommendationReason: str

class MatchResponse(BaseModel):
    success: bool
    bookingId: str
    rankedMatches: List[RankedTechnician]
    topPickId: Optional[str] = None
    totalEvaluated: int

class PricingRequest(BaseModel):
    category: str
    basePrice: float
    distanceKm: float
    isPeakHour: bool = False
    urgencyLevel: str = "STANDARD"  # STANDARD, URGENT, EMERGENCY

class PricingResponse(BaseModel):
    success: bool
    category: str
    basePrice: float
    surgeMultiplier: float
    estimatedLaborPrice: float
    taxAmount: float
    finalEstimatedPrice: float
    estimatedDurationMinutes: int

class DiagnosticRequest(BaseModel):
    category: str
    issueDescription: str

class DiagnosticResponse(BaseModel):
    success: bool
    category: str
    potentialCauses: List[str]
    suggestedTools: List[str]
    estimatedComplexity: str  # LOW, MEDIUM, HIGH
    recommendedServiceCategory: str
