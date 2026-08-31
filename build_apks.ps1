# build_apks.ps1
# This script builds APKs for both the Customer App (Flutter) and Technician App (Flutter).
# It copies the built APKs to a 'build_outputs' folder in the root of the workspace.

$ErrorActionPreference = "Continue"

# Create output directories
$OutputDir = Join-Path $PSScriptRoot "build_outputs"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}
$OutputsDir = Join-Path $PSScriptRoot "outputs"
if (-not (Test-Path $OutputsDir)) {
    New-Item -ItemType Directory -Path $OutputsDir | Out-Null
}
$ReleaseOutputDir = Join-Path $PSScriptRoot "release_apks"
if (-not (Test-Path $ReleaseOutputDir)) {
    New-Item -ItemType Directory -Path $ReleaseOutputDir | Out-Null
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "      BookUrTechnician APK Build Script           " -ForegroundColor Cyan
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
        Write-Host "Found valid Flutter SDK at $Path. Added to session PATH." -ForegroundColor Green
        break
    }
}


# ----------------- Build Technician App (Flutter) -----------------
Write-Host "`n[1/2] Building Technician App (Flutter)..." -ForegroundColor Yellow
$TechAppDir = Join-Path $PSScriptRoot "apps\technician_app"

if (Test-Path $TechAppDir) {
    Push-Location $TechAppDir
    try {
        if (Get-Command flutter -ErrorAction SilentlyContinue) {
            Write-Host "Fetching packages..." -ForegroundColor Gray
            flutter pub get

            Write-Host "Building debug APK..." -ForegroundColor Gray
            $env:GRADLE_OPTS = "-Dorg.gradle.project.kotlin.incremental=false"
            flutter build apk --debug

            $BuiltTechApk = "build\app\outputs\flutter-apk\app-debug.apk"
            if (Test-Path $BuiltTechApk) {
                $TargetApk = Join-Path $OutputDir "technician_app-debug.apk"
                Copy-Item -Path $BuiltTechApk -Destination $TargetApk -Force
                Copy-Item -Path $BuiltTechApk -Destination (Join-Path $OutputsDir "technician_app-debug.apk") -Force
                Write-Host "Successfully built and copied Technician App (Debug) to: $TargetApk" -ForegroundColor Green
            }

            Write-Host "Building release APK..." -ForegroundColor Gray
            flutter build apk --release --no-tree-shake-icons

            $BuiltTechReleaseApk = "build\app\outputs\flutter-apk\app-release.apk"
            if (Test-Path $BuiltTechReleaseApk) {
                $TargetReleaseApk = Join-Path $OutputDir "technician_app-release.apk"
                Copy-Item -Path $BuiltTechReleaseApk -Destination $TargetReleaseApk -Force
                Copy-Item -Path $BuiltTechReleaseApk -Destination (Join-Path $OutputsDir "technician_app-release.apk") -Force
                Copy-Item -Path $BuiltTechReleaseApk -Destination (Join-Path $OutputsDir "BookurTechnician_Technician_App.apk") -Force
                $TargetNamedApk = Join-Path $ReleaseOutputDir "BookurTechnician_Technician_App.apk"
                Copy-Item -Path $BuiltTechReleaseApk -Destination $TargetNamedApk -Force
                Write-Host "Successfully built and copied Technician App (Release) to: $TargetReleaseApk & $TargetNamedApk" -ForegroundColor Green
            } else {
                Write-Warning "Could not find built technician app release APK at $BuiltTechReleaseApk"
            }
        } else {
            Write-Warning "Flutter CLI is not found in your PATH. Skipping Technician App build."
        }
    }
    finally {
        Pop-Location
    }
} else {
    Write-Warning "Technician App directory not found at $TechAppDir"
}

# ----------------- Build Customer App (Flutter) -----------------
Write-Host "`n[2/2] Building Customer App (Flutter)..." -ForegroundColor Yellow
$CustomerAppDir = Join-Path $PSScriptRoot "apps\customer_app_flutter"

if (Test-Path $CustomerAppDir) {
    Push-Location $CustomerAppDir
    try {
        if (Get-Command flutter -ErrorAction SilentlyContinue) {
            Write-Host "Fetching packages..." -ForegroundColor Gray
            flutter pub get
            
            Write-Host "Building debug APK..." -ForegroundColor Gray
            flutter build apk --debug

            $BuiltApk = "build\app\outputs\flutter-apk\app-debug.apk"
            if (Test-Path $BuiltApk) {
                $TargetApk = Join-Path $OutputDir "customer_app-debug.apk"
                Copy-Item -Path $BuiltApk -Destination $TargetApk -Force
                Copy-Item -Path $BuiltApk -Destination (Join-Path $OutputsDir "customer_app-debug.apk") -Force
                Write-Host "Successfully built and copied Customer App (Debug) to: $TargetApk" -ForegroundColor Green
            }
            Write-Host "Building release APK..." -ForegroundColor Gray
            flutter build apk --release --no-tree-shake-icons

            $BuiltReleaseApk = "build\app\outputs\flutter-apk\app-release.apk"
            if (Test-Path $BuiltReleaseApk) {
                $TargetReleaseApk = Join-Path $OutputDir "customer_app-release.apk"
                Copy-Item -Path $BuiltReleaseApk -Destination $TargetReleaseApk -Force
                Copy-Item -Path $BuiltReleaseApk -Destination (Join-Path $OutputsDir "customer_app-release.apk") -Force
                Copy-Item -Path $BuiltReleaseApk -Destination (Join-Path $OutputsDir "BookurTechnician_Customer_App.apk") -Force
                $TargetNamedApk = Join-Path $ReleaseOutputDir "BookurTechnician_Customer_App.apk"
                Copy-Item -Path $BuiltReleaseApk -Destination $TargetNamedApk -Force
                Write-Host "Successfully built and copied Customer App (Release) to: $TargetReleaseApk & $TargetNamedApk" -ForegroundColor Green
            } else {
                Write-Warning "Could not find built customer app release APK at $BuiltReleaseApk"
            }
        } else {
            Write-Warning "Flutter CLI not found. Skipping Customer App build."
        }
    }
    finally {
        Pop-Location
    }
} else {
    Write-Warning "Customer App Flutter directory not found at $CustomerAppDir"
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Build complete! APKs are saved in: $OutputDir" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
