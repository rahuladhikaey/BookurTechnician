@echo off
setlocal enabledelayedexpansion

:: ─────────────────────────────────────────────────────────────
:: BookurTechnician Unified Build Script (React Admin + Backend)
:: ─────────────────────────────────────────────────────────────
title BookurTechnician Unified Build
set "ROOT=%~dp0"

echo ==================================================
echo   BookurTechnician Unified Build (Admin + Backend)
echo ==================================================
echo.

:: 1. Check Node.js / NPM
echo [1/3] Building React Admin Frontend...
echo --------------------------------------------------
if not exist "%ROOT%apps\admin_panel" (
    echo [ERROR] Admin panel directory not found at apps\admin_panel!
    goto :err
)

cd /d "%ROOT%apps\admin_panel"
call npm install
if errorlevel 1 (
    echo [ERROR] npm install failed!
    goto :err
)

call npm run build
if errorlevel 1 (
    echo [ERROR] npm run build failed!
    goto :err
)
echo [SUCCESS] Admin Frontend compiled into apps\backend\src\main\resources\static\admin\
echo.

:: 2. Build Spring Boot Backend JAR
echo [2/3] Building Spring Boot Backend with Embedded Admin Panel...
echo --------------------------------------------------
cd /d "%ROOT%"
call mvn clean package -DskipTests
if errorlevel 1 (
    echo [ERROR] Maven build failed!
    goto :err
)

echo.
echo ==================================================
echo [3/3] BUILD SUCCESSFUL!
echo ==================================================
echo Unified JAR created in target\
echo You can run the application with:
echo   java -jar target\bookurtechnician-backend-1.0.0-PROD.jar
echo.
echo Admin Panel URL: http://localhost:8080/admin
echo Backend API URL: http://localhost:8080/api/v1
echo ==================================================
goto :end

:err
echo.
echo [FAILED] Unified build failed. Please check the logs above.
pause
exit /b 1

:end
cd /d "%ROOT%"
pause
