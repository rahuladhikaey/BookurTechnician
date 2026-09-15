# install_flutter.ps1
# This script automatically downloads, installs, and configures the latest stable Flutter SDK on Windows,
# or registers an existing installation if found.

$ErrorActionPreference = "Stop"

# Detect if there's already an existing HEALTHY Flutter installation
$ExistingPaths = @(
    "D:\flutter",
    "C:\flutter",
    "D:\src\flutter",
    "C:\src\flutter",
    "C:\Users\RAHUL\flutter"
)

$ExistingPath = $null
foreach ($path in $ExistingPaths) {
    if ((Test-Path (Join-Path $path "bin\flutter.bat")) -and (Test-Path (Join-Path $path "packages\flutter_tools"))) {
        $ExistingPath = $path
        break
    }
}

if ($null -ne $ExistingPath) {
    Write-Host "Found healthy Flutter SDK at $ExistingPath!" -ForegroundColor Green
    $InstallDir = $ExistingPath
    $BinDir = Join-Path $InstallDir "bin"
    $SkipDownload = $true
} else {
    Write-Host "Existing Flutter installation is missing or corrupted. Fresh install will be set up at D:\flutter." -ForegroundColor Yellow
    $InstallDir = "D:\flutter"
    $BinDir = Join-Path $InstallDir "bin"
    $SkipDownload = $false
}
$ZipPath = Join-Path $env:TEMP "flutter_sdk.zip"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "      Flutter SDK Automatic Installer             " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Fetch the latest stable release metadata (only if not skipping)
if (-not $SkipDownload) {
    Write-Host "`n[1/5] Fetching latest stable release version..." -ForegroundColor Yellow
    try {
        $releases = Invoke-RestMethod -Uri "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
        $stableRelease = $releases.releases | Where-Object { $_.channel -eq "stable" } | Select-Object -First 1
        if (-not $stableRelease) {
            throw "Could not find a stable release in the metadata."
        }
        $version = $stableRelease.version
        $downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($stableRelease.archive)"
        Write-Host "Found latest stable version: $version" -ForegroundColor Green
        Write-Host "Download URL: $downloadUrl" -ForegroundColor Gray
    } catch {
        Write-Error "Failed to fetch Flutter release metadata: $_"
    }
} else {
    Write-Host "`n[1/5] Skipping download - using existing installation at $InstallDir" -ForegroundColor Green
}

# 2. Download the ZIP archive (High-Speed Turbo Download)
if (-not $SkipDownload) {
    Write-Host "`n[2/5] Turbo Downloading Flutter SDK (~1.2 GB at full speed)..." -ForegroundColor Yellow
    try {
        if (Test-Path $ZipPath) {
            Remove-Item $ZipPath -Force
        }
        Write-Host "Downloading to $ZipPath..." -ForegroundColor Gray
        
        # Disable PowerShell progress bar GUI throttling (boosts speed by 15x-20x)
        $ProgressPreference = 'SilentlyContinue'
        
        # Try native Windows curl.exe first (fastest multi-threaded speed)
        $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
        if ($curlCmd) {
            & curl.exe -L -o "$ZipPath" "$downloadUrl" --progress-bar
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $ZipPath)
        }
        
        Write-Host "Download complete!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download Flutter SDK: $_"
    }
}

# 3. Extract the ZIP archive (only if not skipping)
if (-not $SkipDownload) {
    Write-Host "`n[3/5] Extracting Flutter SDK to $InstallDir..." -ForegroundColor Yellow
    try {
        if (Test-Path $InstallDir) {
            Write-Host "Existing Flutter directory found at $InstallDir. Backing up..." -ForegroundColor Gray
            $BackupDir = "${InstallDir}_backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            Rename-Item -Path $InstallDir -NewName $BackupDir
        }
        
        Write-Host "Extracting files (turbo mode)..." -ForegroundColor Gray
        # Use native Windows tar if available (10x faster than Expand-Archive)
        $tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
        if ($tarCmd) {
            & tar.exe -xf "$ZipPath" -C "D:\"
        } else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, "D:\")
        }
        
        # Verify extraction
        if (Test-Path $BinDir) {
            Write-Host "Extraction complete!" -ForegroundColor Green
        } else {
            throw "Extraction failed. Bin folder not found at $BinDir"
        }
    } catch {
        Write-Error "Failed to extract Flutter SDK: $_"
    } finally {
        # Clean up zip
        if (Test-Path $ZipPath) {
            Remove-Item $ZipPath -Force
        }
    }
}

# 4. Add bin to PATH environment variable
Write-Host "`n[4/5] Configuring Environment Variables..." -ForegroundColor Yellow
try {
    # Add to User PATH permanently (if not already there)
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $PathElements = $UserPath -split ";"
    
    if ($PathElements -contains $BinDir) {
        Write-Host "Flutter bin is already in User PATH." -ForegroundColor Green
    } else {
        Write-Host "Adding $BinDir to User PATH..." -ForegroundColor Gray
        $NewPath = "$UserPath;$BinDir"
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "Permanently added Flutter to User PATH." -ForegroundColor Green
    }
    
    # Update current session PATH so the user can use it immediately without restarting
    $env:Path = "$env:Path;$BinDir"
} catch {
    Write-Warning "Failed to set Environment Variables automatically: $_"
    Write-Host "Please manually add '$BinDir' to your PATH environment variable." -ForegroundColor Yellow
}

# 5. Run flutter doctor
Write-Host "`n[5/5] Checking installation status with 'flutter doctor'..." -ForegroundColor Yellow
try {
    # Run flutter doctor
    & flutter doctor
} catch {
    Write-Warning "Flutter doctor finished with warnings or failed to run: $_"
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Flutter SDK Registration Complete!" -ForegroundColor Green
Write-Host "You can now run '.\build_apks.ps1' to build your APKs." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
