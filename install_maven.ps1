# install_maven.ps1
# Automates Apache Maven installation and PATH configuration on Windows

$ErrorActionPreference = "Stop"

$MavenVersion = "3.9.9"
$InstallDir = "C:\maven"
$ZipUrl = "https://archive.apache.org/dist/maven/maven-3/$MavenVersion/binaries/apache-maven-$MavenVersion-bin.zip"
$TempZip = Join-Path $env:TEMP "apache-maven-$MavenVersion-bin.zip"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "         Installing Apache Maven $MavenVersion    " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Download Maven Zip
Write-Host "`n[1/3] Downloading Apache Maven from $ZipUrl..." -ForegroundColor Yellow
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
Write-Host "Download completed." -ForegroundColor Green

# 2. Extract to Install Directory
Write-Host "`n[2/3] Extracting to $InstallDir..." -ForegroundColor Yellow
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

$ExtractTemp = Join-Path $env:TEMP "maven_extract"
if (Test-Path $ExtractTemp) { Remove-Item -Path $ExtractTemp -Recurse -Force }
Expand-Archive -Path $TempZip -DestinationPath $ExtractTemp -Force
$ExtractedFolder = (Get-ChildItem -Path $ExtractTemp -Directory | Select-Object -First 1).FullName
Move-Item -Path $ExtractedFolder -Destination $InstallDir -Force
Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item -Path $ExtractTemp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Extracted successfully." -ForegroundColor Green

# 3. Add to System and User PATH
Write-Host "`n[3/3] Configuring Environment PATH and JAVA_HOME..." -ForegroundColor Yellow
$MavenBin = Join-Path $InstallDir "bin"

# Set User PATH
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$MavenBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$MavenBin", "User")
    Write-Host "Added $MavenBin to User PATH." -ForegroundColor Green
}

# Auto-detect and set JAVA_HOME if not present
if (-not [Environment]::GetEnvironmentVariable("JAVA_HOME", "User") -and -not [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")) {
    $JavaPath = "C:\Program Files\Java\jdk-21.0.11"
    if (Test-Path $JavaPath) {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $JavaPath, "User")
        Write-Host "Set JAVA_HOME to $JavaPath" -ForegroundColor Green
    }
}

# Update current session PATH
$env:Path = "$MavenBin;$env:Path"
if (Test-Path "C:\Program Files\Java\jdk-21.0.11") {
    $env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.11"
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Verification:" -ForegroundColor Cyan
& (Join-Path $MavenBin "mvn.cmd") -version
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Maven installed successfully!" -ForegroundColor Green
Write-Host "Restart your terminal / VS Code window to use 'mvn' directly." -ForegroundColor Yellow
