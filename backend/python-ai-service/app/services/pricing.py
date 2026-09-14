from ..models.schemas import PricingRequest, PricingResponse, DiagnosticRequest, DiagnosticResponse

def compute_dynamic_pricing(request: PricingRequest) -> PricingResponse:
    """
    Computes real-time dynamic pricing based on distance, time urgency, and demand surge.
    """
    surge = 1.0
    if request.isPeakHour:
        surge += 0.15 # 15% peak hour surge
    
    if request.urgencyLevel == "EMERGENCY":
        surge += 0.35 # 35% emergency dispatch
    elif request.urgencyLevel == "URGENT":
        surge += 0.15

    # Distance convenience charge (if > 10km, + ₹50)
    distance_addon = 50.0 if request.distanceKm > 10.0 else 0.0

    labor_price = round((request.basePrice * surge) + distance_addon, 2)
    tax_amount = round(labor_price * 0.18, 2) # 18% GST standard
    final_price = round(labor_price + tax_amount, 2)

    # Base duration
    duration = 45
    if request.category.upper() in ["AC_REPAIR", "WIRING"]:
        duration = 75

    return PricingResponse(
        success=True,
        category=request.category,
        basePrice=request.basePrice,
        surgeMultiplier=round(surge, 2),
        estimatedLaborPrice=labor_price,
        taxAmount=tax_amount,
        finalEstimatedPrice=final_price,
        estimatedDurationMinutes=duration
    )


def diagnose_issue(request: DiagnosticRequest) -> DiagnosticResponse:
    """
    Rule & NLP heuristic based troubleshooting assistant
    """
    desc = request.issueDescription.lower()
    cat = request.category.upper()

    causes = []
    tools = []
    complexity = "MEDIUM"

    if "spark" in desc or "short" in desc or "trip" in desc:
        causes = ["MCB Overload / Tripping", "Loose Neutral Wire Connection", "Damaged insulation inside switchboard"]
        tools = ["Digital Multimeter", "Insulated Screwdriver Set", "Wire Stripper & Tester"]
        complexity = "HIGH"
    elif "leak" in desc or "drip" in desc:
        causes = ["Worn-out O-ring washer", "Corroded valve seal", "High inlet water pressure"]
        tools = ["Adjustable Pipe Wrench", "Teflon Thread Seal Tape", "Basin Wrench"]
        complexity = "LOW"
    elif "noise" in desc or "fan" in desc:
        causes = ["Capacitor degradation", "Dry motor ball bearings", "Loose blade balancing"]
        tools = ["2.5uF Motor Capacitor", "Bearing Lubricant Grease", "Screw Set"]
        complexity = "MEDIUM"
    else:
        causes = ["General wear & tear", "Component aging requiring part inspection"]
        tools = ["Standard Technician Multi-Tool Toolkit"]
        complexity = "LOW"

    return DiagnosticResponse(
        success=True,
        category=request.category,
        potentialCauses=causes,
        suggestedTools=tools,
        estimatedComplexity=complexity,
        recommendedServiceCategory=cat
    )
