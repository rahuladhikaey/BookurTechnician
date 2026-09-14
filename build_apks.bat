@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo       BookUrTechnician Multi-App APK Builder       
echo ==================================================

set "ROOT_DIR=%~dp0"
set "OUTPUT_DIR=%ROOT_DIR%build_outputs"

if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

:: Set Java Environment
if exist "C:\Program Files\Java\jdk-21.0.11" (
    set "JAVA_HOME=C:\Program Files\Java\jdk-21.0.11"
    set "PATH=C:\Program Files\Java\jdk-21.0.11\bin;!PATH!"
)

:: Set Android SDK
if exist "C:\Users\RAHUL\AppData\Local\Android\Sdk" (
    set "ANDROID_HOME=C:\Users\RAHUL\AppData\Local\Android\Sdk"
    set "PATH=C:\Users\RAHUL\AppData\Local\Android\Sdk\platform-tools;!PATH!"
)
if exist "D:\Android\Sdk" (
    set "ANDROID_HOME=D:\Android\Sdk"
    set "PATH=D:\Android\Sdk\platform-tools;!PATH!"
)

:: Set Flutter SDK Path
if exist "C:\Users\RAHUL\flutter\bin" (
    set "PATH=C:\Users\RAHUL\flutter\bin;!PATH!"
)
if exist "D:\Users\RAHUL\flutter\bin" (
    set "PATH=D:\Users\RAHUL\flutter\bin;!PATH!"
)
if exist "C:\flutter\bin" (
    set "PATH=C:\flutter\bin;!PATH!"
)
if exist "D:\flutter\bin" (
    set "PATH=D:\flutter\bin;!PATH!"
)

echo [Environment Verification]
call java -version
call flutter --version

:: -----------------------------------------------------------------
:: 1/2. BUILD TECHNICIAN APP APK
:: -----------------------------------------------------------------
echo.
echo ==================================================
echo [1/2] Building Technician App (Flutter)...
echo ==================================================
set "TECH_DIR=%ROOT_DIR%apps\technician_app"

if exist "%TECH_DIR%" (
    cd /d "%TECH_DIR%"
    echo Working in: %TECH_DIR%
    
    echo Running flutter pub get for Technician App...
    call flutter pub get
    
    echo Building Debug APK for Technician App...
    set GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false
    call flutter build apk --debug
    
    if exist "build\app\outputs\flutter-apk\app-debug.apk" (
        copy /y "build\app\outputs\flutter-apk\app-debug.apk" "%OUTPUT_DIR%\technician_app-debug.apk" >nul
        echo [SUCCESS] Copied Technician APK to "%OUTPUT_DIR%\technician_app-debug.apk"
    ) else (
        echo [WARNING] app-debug.apk not found in build directory.
    )
) else (
    echo [ERROR] Technician App directory not found!
)

:: -----------------------------------------------------------------
:: 2/2. BUILD CUSTOMER APP APK
:: -----------------------------------------------------------------
echo.
echo ==================================================
echo [2/2] Building Customer App (Flutter)...
echo ==================================================
set "CUST_DIR=%ROOT_DIR%apps\customer_app_flutter"

if exist "%CUST_DIR%" (
    cd /d "%CUST_DIR%"
    echo Working in: %CUST_DIR%
    
    echo Running flutter pub get for Customer App...
    call flutter pub get
    
    echo Building Debug APK for Customer App...
    set GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false
    call flutter build apk --debug
    
    if exist "build\app\outputs\flutter-apk\app-debug.apk" (
        copy /y "build\app\outputs\flutter-apk\app-debug.apk" "%OUTPUT_DIR%\customer_app-debug.apk" >nul
        echo [SUCCESS] Copied Customer APK to "%OUTPUT_DIR%\customer_app-debug.apk"
    ) else (
        echo [WARNING] app-debug.apk not found in build directory.
    )
) else (
    echo [ERROR] Customer App directory not found!
)

echo.
echo ==================================================
echo All APK builds completed!
echo Output directory: %OUTPUT_DIR%
echo ==================================================
cd /d "%ROOT_DIR%"
dir "%OUTPUT_DIR%"
