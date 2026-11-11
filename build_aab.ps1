# build_aab.ps1
# This script builds Google Play production Android App Bundles (.aab) for both
# the Customer App (Flutter) and Technician App (Flutter).
# It copies the built AABs to 'release_aab' and 'build_outputs' folders in the root workspace.

$ErrorActionPreference = "Continue"

# Create output directories
$OutputDir = Join-Path $PSScriptRoot "build_outputs"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}
$ReleaseAabDir = Join-Path $PSScriptRoot "release_aab"
if (-not (Test-Path $ReleaseAabDir)) {
    New-Item -ItemType Directory -Path $ReleaseAabDir | Out-Null
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   BookUrTechnician Android App Bundle (.aab)    " -ForegroundColor Cyan
Write-Host "             Google Play Release Build            " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Auto-detect JAVA_HOME if not set
if (-not $env:JAVA_HOME) {
    $JavaCandidates = @(
        "C:\Program Files\Java\jdk-21.0.11",
        "C:\Program Files\Java\jdk*",
        "C:\Program Files\Eclipse Adoptium\jdk*",
        "C:\Program Files\Android\Android Studio\jbr"
    )
    foreach ($cand in $JavaCandidates) {
        $resolved = Resolve-Path $cand -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($resolved -and (Test-Path (Join-Path $resolved.Path "bin\java.exe") -ErrorAction SilentlyContinue)) {
            $env:JAVA_HOME = $resolved.Path
            $env:Path = "$($resolved.Path)\bin;$env:Path"
            Write-Host "Auto-detected JAVA_HOME: $($env:JAVA_HOME)" -ForegroundColor Green
            break
        }
    }
}

# Auto-detect ANDROID_HOME
if (-not $env:ANDROID_HOME) {
    if (Test-Path "D:\Android\Sdk") {
        $env:ANDROID_HOME = "D:\Android\Sdk"
        Write-Host "Auto-detected ANDROID_HOME: $($env:ANDROID_HOME)" -ForegroundColor Green
    } elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk") {
        $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
        Write-Host "Auto-detected ANDROID_HOME: $($env:ANDROID_HOME)" -ForegroundColor Green
    }
}

# Auto-detect Flutter
$CommonFlutterPaths = @(
    "D:\Users\RAHUL\flutter\bin",
    "C:\Users\RAHUL\flutter\bin",
    "C:\flutter\bin",
    "D:\flutter\bin"
)
foreach ($Path in $CommonFlutterPaths) {
    if (Test-Path (Join-Path $Path "flutter.bat")) {
        $env:Path = "$Path;$env:Path"
        Write-Host "Found valid Flutter SDK at $Path." -ForegroundColor Green
        break
    }
}

# ----------------- 1. Build Technician App (.aab) -----------------
Write-Host "`n[1/2] Building Technician Partner App (AAB Release)..." -ForegroundColor Yellow
$TechAppDir = Join-Path $PSScriptRoot "apps\technician_app"

if (Test-Path $TechAppDir) {
    Push-Location $TechAppDir
    try {
        if (Get-Command flutter -ErrorAction SilentlyContinue) {
            Write-Host "Fetching packages..." -ForegroundColor Gray
            flutter pub get

            Write-Host "Building release App Bundle (.aab)..." -ForegroundColor Gray
            $env:GRADLE_OPTS = "-Dorg.gradle.project.kotlin.incremental=false"
            flutter build appbundle --release --no-tree-shake-icons

            $BuiltTechAab = "build\app\outputs\bundle\release\app-release.aab"
            if (Test-Path $BuiltTechAab) {
                $TargetAab = Join-Path $OutputDir "BookurTechnician_Technician_Partner.aab"
                $TargetNamedAab = Join-Path $ReleaseAabDir "BookurTechnician_Technician_Partner.aab"
                Copy-Item -Path $BuiltTechAab -Destination $TargetAab -Force
                Copy-Item -Path $BuiltTechAab -Destination $TargetNamedAab -Force
                Write-Host "Successfully built and copied Technician Partner AAB to:`n  -> $TargetAab`n  -> $TargetNamedAab" -ForegroundColor Green
            } else {
                Write-Warning "Could not find built technician app AAB at $BuiltTechAab"
            }
        }
    }
    finally {
        Pop-Location
    }
}

# ----------------- 2. Build Customer App (.aab) -----------------
Write-Host "`n[2/2] Building Customer App (AAB Release)..." -ForegroundColor Yellow
$CustomerAppDir = Join-Path $PSScriptRoot "apps\customer_app_flutter"

if (Test-Path $CustomerAppDir) {
    Push-Location $CustomerAppDir
    try {
        if (Get-Command flutter -ErrorAction SilentlyContinue) {
            Write-Host "Fetching packages..." -ForegroundColor Gray
            flutter pub get

            Write-Host "Building release App Bundle (.aab)..." -ForegroundColor Gray
            flutter build appbundle --release --no-tree-shake-icons

            $BuiltCustomerAab = "build\app\outputs\bundle\release\app-release.aab"
            if (Test-Path $BuiltCustomerAab) {
                $TargetCustAab = Join-Path $OutputDir "BookurTechnician_Customer_App.aab"
                $TargetNamedCustAab = Join-Path $ReleaseAabDir "BookurTechnician_Customer_App.aab"
                Copy-Item -Path $BuiltCustomerAab -Destination $TargetCustAab -Force
                Copy-Item -Path $BuiltCustomerAab -Destination $TargetNamedCustAab -Force
                Write-Host "Successfully built and copied Customer App AAB to:`n  -> $TargetCustAab`n  -> $TargetNamedCustAab" -ForegroundColor Green
            } else {
                Write-Warning "Could not find built customer app AAB at $BuiltCustomerAab"
            }
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "AAB Generation Complete! Upload-ready AAB files saved in: $ReleaseAabDir" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
