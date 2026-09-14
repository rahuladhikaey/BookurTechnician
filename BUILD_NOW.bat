@echo off
setlocal enabledelayedexpansion

:: ─── BookUrTechnician - Full APK Build ───────────────────────
title BookUrTechnician APK Build
set "ROOT=%~dp0"
set "OUT=%ROOT%build_outputs"
if not exist "%OUT%" mkdir "%OUT%"

echo.
echo ==================================================
echo      BookUrTechnician APK Build
echo ==================================================

:: Auto-detect JAVA_HOME if not set
if "%JAVA_HOME%"=="" (
    for /d %%D in ("C:\Program Files\Java\jdk*" "C:\Program Files\Eclipse Adoptium\jdk*" "C:\Program Files\Android\Android Studio\jbr") do (
        if exist "%%~D\bin\java.exe" (
            set "JAVA_HOME=%%~D"
            set "PATH=%%~D\bin;!PATH!"
            goto :found_java
        )
    )
)
:found_java

:: Auto-detect healthy Flutter SDK
set "FLUTTER_FOUND=0"
for %%P in ("D:\flutter\bin" "C:\flutter\bin" "D:\src\flutter\bin" "C:\src\flutter\bin" "C:\Users\RAHUL\flutter\bin") do (
    if exist "%%~P\flutter.bat" (
        if exist "%%~P\..\packages\flutter_tools" (
            set "PATH=%%~P;!PATH!"
            set "FLUTTER_FOUND=1"
            goto :found_flutter
        )
    )
)

where flutter >nul 2>nul
if %errorlevel% equ 0 set "FLUTTER_FOUND=1"

if "!FLUTTER_FOUND!"=="0" (
    echo.
    echo [!] Flutter SDK is not installed or installation is corrupted.
    echo [*] Automatically downloading and installing fresh Flutter SDK...
    powershell -ExecutionPolicy Bypass -File "%ROOT%install_flutter.ps1"
    set "PATH=D:\flutter\bin;C:\flutter\bin;!PATH!"
)
:found_flutter

:: ─── 1. Technician App ───────────────────────────────────────
echo.
echo [1/2] Technician App (Flutter)
echo --------------------------------------------------
if exist "%ROOT%apps\technician_app" (
    cd /d "%ROOT%apps\technician_app"
    call flutter pub get
    if errorlevel 1 goto :err1
    call flutter build apk --debug
    if errorlevel 1 goto :err1
    if exist "build\app\outputs\flutter-apk\app-debug.apk" (
        copy /y "build\app\outputs\flutter-apk\app-debug.apk" "%OUT%\technician_app-debug.apk" >nul
        echo OK - technician_app-debug.apk
    )
    goto :cust
)

:err1
echo FAILED - Technician app build error or Flutter not found.

:cust
:: ─── 2. Customer App ─────────────────────────────────────────
echo.
echo [2/2] Customer App (Flutter)
echo --------------------------------------------------
if exist "%ROOT%apps\customer_app_flutter" (
    cd /d "%ROOT%apps\customer_app_flutter"
    call flutter pub get
    if errorlevel 1 goto :err2
    call flutter build apk --debug
    if errorlevel 1 goto :err2
    if exist "build\app\outputs\flutter-apk\app-debug.apk" (
        copy /y "build\app\outputs\flutter-apk\app-debug.apk" "%OUT%\customer_app-debug.apk" >nul
        echo OK - customer_app-debug.apk
    )
    goto :done
)

:err2
echo FAILED - Customer app build error or Flutter not found.

:done
echo.
echo ==================================================
echo  Output directory: %OUT%
echo ==================================================
cd /d "%ROOT%"
pause





