# install_cmdline_tools.ps1
# This script downloads and installs Android cmdline-tools and SDK components on the D: drive,
# configures ANDROID_HOME, and automatically accepts Android licenses.

$ErrorActionPreference = "Stop"

$SdkPath = "D:\Android\Sdk"
$CmdlineToolsDir = Join-Path $SdkPath "cmdline-tools"
$LatestToolsDir = Join-Path $CmdlineToolsDir "latest"
$ZipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$ZipPath = Join-Path $env:TEMP "cmdline_tools.zip"
$ExtractTemp = Join-Path $env:TEMP "cmdline_tools_extract"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Installing Android SDK on D: Drive (No Studio)  " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Ensure Sdk folder exists on D:
if (-not (Test-Path $SdkPath)) {
    Write-Host "Creating Android SDK folder at $SdkPath..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $SdkPath | Out-Null
}

# 1. Download cmdline-tools
Write-Host "`n[1/4] Downloading Android command line tools..." -ForegroundColor Yellow
try {
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }
    Write-Host "Downloading from $ZipUrl..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
    Write-Host "Download complete!" -ForegroundColor Green
} catch {
    Write-Error "Failed to download command line tools: $_"
}

# 2. Extract and install cmdline-tools
Write-Host "`n[2/4] Extracting and installing to $LatestToolsDir..." -ForegroundColor Yellow
try {
    if (Test-Path $ExtractTemp) {
        Remove-Item $ExtractTemp -Recurse -Force
    }
    New-Item -ItemType Directory -Path $ExtractTemp | Out-Null

    Write-Host "Extracting ZIP..." -ForegroundColor Gray
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractTemp -Force

    # Ensure clean install path
    if (Test-Path $LatestToolsDir) {
        Write-Host "Removing existing cmdline-tools latest..." -ForegroundColor Gray
        Remove-Item $LatestToolsDir -Recurse -Force
    }
    
    # Create parent cmdline-tools folder
    if (-not (Test-Path $CmdlineToolsDir)) {
        New-Item -ItemType Directory -Path $CmdlineToolsDir | Out-Null
    }

    # The zip contains a folder named 'cmdline-tools'. Move its contents to 'latest'
    $ExtractedToolsFolder = Join-Path $ExtractTemp "cmdline-tools"
    if (Test-Path $ExtractedToolsFolder) {
        Write-Host "Copying tools to $LatestToolsDir..." -ForegroundColor Gray
        Copy-Item -Path $ExtractedToolsFolder -Destination $LatestToolsDir -Recurse -Force
        Write-Host "cmdline-tools installed successfully!" -ForegroundColor Green
    } else {
        throw "Could not find extracted 'cmdline-tools' directory inside temp folder."
    }

} catch {
    Write-Error "Failed to install command line tools: $_"
} finally {
    # Clean up temp files
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    if (Test-Path $ExtractTemp) { Remove-Item $ExtractTemp -Recurse -Force }
}

# 3. Configure Android Environment Variables
Write-Host "`n[3/4] Configuring Environment Variables..." -ForegroundColor Yellow
try {
    # Set ANDROID_HOME permanently for User
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $SdkPath, "User")
    $env:ANDROID_HOME = $SdkPath
    Write-Host "ANDROID_HOME set to: $SdkPath" -ForegroundColor Green

    # Add platform-tools to User PATH permanently (if not already there)
    $PlatformToolsBin = Join-Path $SdkPath "platform-tools"
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $PathElements = $UserPath -split ";"
    
    if ($PathElements -contains $PlatformToolsBin) {
        Write-Host "Platform-tools bin is already in User PATH." -ForegroundColor Green
    } else {
        Write-Host "Adding $PlatformToolsBin to User PATH..." -ForegroundColor Gray
        $NewPath = "$UserPath;$PlatformToolsBin"
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "Added platform-tools to User PATH." -ForegroundColor Green
    }
    
    # Update current session PATH
    $env:Path = "$env:Path;$PlatformToolsBin"
} catch {
    Write-Warning "Failed to configure environment variables automatically: $_"
}

# 4. Download SDK components (platform-tools, platforms, build-tools)
Write-Host "`n[4/4] Installing necessary SDK components (platform-tools, build-tools, platforms)..." -ForegroundColor Yellow
try {
    $SdkManager = Join-Path $LatestToolsDir "bin\sdkmanager.bat"
    
    # Run sdkmanager to install platform-tools, platforms;android-34, build-tools;34.0.0
    Write-Host "Running sdkmanager..." -ForegroundColor Gray
    
    # Create empty repositories.cfg to avoid sdkmanager warnings
    $HomeDir = $env:USERPROFILE
    $AndroidFolder = Join-Path $HomeDir ".android"
    if (-not (Test-Path $AndroidFolder)) {
        New-Item -ItemType Directory -Path $AndroidFolder | Out-Null
    }
    $RepoCfg = Join-Path $AndroidFolder "repositories.cfg"
    if (-not (Test-Path $RepoCfg)) {
        New-Item -ItemType File -Path $RepoCfg | Out-Null
    }
    
    # Install components and accept licenses automatically
    $yesList = @("y", "y", "y", "y", "y", "y", "y", "y", "y", "y")
    $yesList | & $SdkManager --sdk_root=$SdkPath "platform-tools" "build-tools;34.0.0" "platforms;android-34"
    
    Write-Host "SDK components installed successfully!" -ForegroundColor Green
} catch {
    Write-Warning "Failed to install SDK components: $_"
}

# 5. Accept Android Licenses via Flutter
Write-Host "`nAccepting Android licenses..." -ForegroundColor Yellow

# Ensure Flutter is in the current session PATH
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $CommonFlutterPaths = @(
        "D:\Users\RAHUL\flutter\bin",
        "C:\Users\RAHUL\flutter\bin",
        "D:\flutter\bin"
    )
    foreach ($Path in $CommonFlutterPaths) {
        if (Test-Path (Join-Path $Path "flutter.bat")) {
            $env:Path = "$env:Path;$Path"
            Write-Host "Found Flutter SDK at $Path. Temporarily added to session PATH." -ForegroundColor Gray
            break
        }
    }
}

try {
    # Tell Flutter to configure Android SDK location
    & flutter config --android-sdk $SdkPath
    
    $YesInput = @("y", "y", "y", "y", "y", "y", "y", "y", "y", "y")
    $YesInput | & flutter doctor --android-licenses
    Write-Host "Android licenses accepted successfully!" -ForegroundColor Green
} catch {
    Write-Warning "Failed to automatically accept licenses: $_"
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Android D: Drive SDK Setup Complete!" -ForegroundColor Green
Write-Host "You can now run '.\build_apks.ps1' to build your APKs." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
