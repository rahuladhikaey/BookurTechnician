@echo off
title BookurTechnician Production Server Launcher
echo ======================================================================
echo          BOOKURTECHNICIAN - PRODUCTION SYSTEM LAUNCHER
echo ======================================================================
echo.

cd /d "%~dp0\backend\node-core-service"

echo [1/3] Checking Node.js Environment...
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not found on PATH. Please install Node.js 18+ or 20+.
    pause
    exit /b 1
)

echo [2/3] Verifying Production Dependencies...
if not exist "node_modules" (
    echo Installing production dependencies...
    call npm install --production
)

echo [3/3] Launching Core Polyglot API Gateway and WebSocket Engine...
echo ======================================================================
echo 🌐 API Gateway: http://localhost:4000/api/v1
echo 💻 Admin Web Panel: http://localhost:4000/admin
echo 📡 Real-Time Dispatch: ws://localhost:4000
echo 🩺 Health Check: http://localhost:4000/health
echo ======================================================================
echo.

call npm start
pause
