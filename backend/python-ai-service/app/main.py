from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api.endpoints import router as ai_router

app = FastAPI(
    title="BookurTechnician AI & Matchmaking Engine",
    description="Python FastAPI High-Performance Data Science, Matchmaking Algorithm, and Dynamic Pricing Service",
    version="1.0.0-MVP"
)

# Enable Cross-Origin Resource Sharing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount AI routes
app.include_router(ai_router)

@app.get("/health")
def health_check():
    return {
        "status": "HEALTHY",
        "service": "bookurtechnician-python-ai-service",
        "engine": "FastAPI + NumPy Matchmaker",
        "algorithms": ["multi_factor_scoring", "dynamic_surge_pricing", "rule_diagnostics"]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
