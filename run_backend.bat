@echo off
TITLE BookurTechnician Polyglot Backend Runner
echo ========================================================
echo   BookurTechnician Production Multi-Stack MVP Backend
echo ========================================================
echo.

echo [1/3] Starting Node.js Core API Gateway + Embedded AI Engine (Port 4000)...
start "Node.js Core Gateway (Port 4000)" cmd /k "cd /d "%~dp0backend\node-core-service" && npm start"

echo.
echo [2/3] Starting Java Spring Boot 3 Financial Ledger (Port 8080)...
start "Java Spring Boot Ledger (Port 8080)" cmd /k "cd /d "%~dp0" && mvn spring-boot:run"

echo.
echo [3/3] Checking Python for Standalone FastAPI AI Service (Port 8000)...
where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "Python FastAPI AI Engine (Port 8000)" cmd /k "cd /d "%~dp0backend\python-ai-service" && py -m pip install -r requirements.txt && py -m uvicorn app.main:app --port 8000 --reload"
) else (
    where python >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        start "Python FastAPI AI Engine (Port 8000)" cmd /k "cd /d "%~dp0backend\python-ai-service" && python -m pip install -r requirements.txt && python -m uvicorn app.main:app --port 8000 --reload"
    ) else (
        echo [INFO] Python not found in PATH.
        echo Note: The AI Matchmaking & Dynamic Pricing Engine is ALSO running directly inside Node.js on port 4000 (/api/v1/ai)!
    )
)

echo.
echo ========================================================
echo   Backend services launched successfully!
echo   Node API Gateway & AI: http://localhost:4000/api/v1
echo   Health Diagnostics:    http://localhost:4000/health
echo   Java Ledger Compute:   http://localhost:8080/actuator/health
echo ========================================================
pause
