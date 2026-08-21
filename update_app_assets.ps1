# update_app_assets.ps1
# PowerShell script to update launcher icons and names for both BookUrTechnician apps.

$CustLogoPath = Join-Path $PSScriptRoot "apps\customer_app_flutter\assets\images\app_logo.png"
$TechLogoPath = Join-Path $PSScriptRoot "apps\technician_app\assets\images\app_logo.png"
$AppLabel = "BookUrTechnician"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Updating App Logos & Icons: $AppLabel" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Load System.Drawing for high-quality resizing
Add-Type -AssemblyName System.Drawing

# Dictionary of resolutions
$Sizes = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

function Resize-And-Save {
    param(
        [System.Drawing.Image]$SrcImage,
        [int]$Size,
        [string]$DestPath
    )
    $DestDir = [System.IO.Path]::GetDirectoryName($DestPath)
    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }
    
    $DestImage = New-Object System.Drawing.Bitmap($Size, $Size)
    $Graphics = [System.Drawing.Graphics]::FromImage($DestImage)
    
    # Configure high-quality rendering options
    $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    
    $Rect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
    $Graphics.DrawImage($SrcImage, $Rect, 0, 0, $SrcImage.Width, $SrcImage.Height, [System.Drawing.GraphicsUnit]::Pixel)
    
    # Save as PNG
    $DestImage.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $Graphics.Dispose()
    $DestImage.Dispose()
}

# 1. Update Customer App Assets
if (Test-Path $CustLogoPath) {
    Write-Host "Updating Customer App Launcher Icons from $CustLogoPath..." -ForegroundColor Yellow
    $CustImage = [System.Drawing.Image]::FromFile($CustLogoPath)
    $CustResDir = Join-Path $PSScriptRoot "apps\customer_app_flutter\android\app\src\main\res"
    
    foreach ($Folder in $Sizes.Keys) {
        $Size = $Sizes[$Folder]
        $TargetFolder = Join-Path $CustResDir $Folder
        
        # Delete XML adaptive launcher icon overrides so the system uses the PNG
        Remove-Item (Join-Path $TargetFolder "ic_launcher.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TargetFolder "ic_launcher_round.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TargetFolder "ic_launcher_background.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TargetFolder "ic_launcher_foreground.xml") -ErrorAction SilentlyContinue
        
        # Save new PNG launcher icons
        Resize-And-Save $CustImage $Size (Join-Path $TargetFolder "ic_launcher.png")
        Resize-And-Save $CustImage $Size (Join-Path $TargetFolder "ic_launcher_round.png")
    }
    $CustImage.Dispose()
} else {
    Write-Warning "Customer App logo not found at: $CustLogoPath"
}

# 2. Update Technician App Assets
if (Test-Path $TechLogoPath) {
    Write-Host "Updating Technician App Launcher Icons from $TechLogoPath..." -ForegroundColor Yellow
    $TechImage = [System.Drawing.Image]::FromFile($TechLogoPath)
    $TechResDir = Join-Path $PSScriptRoot "apps\technician_app\android\app\src\main\res"
    
    foreach ($Folder in $Sizes.Keys) {
        $Size = $Sizes[$Folder]
        $TargetFolder = Join-Path $TechResDir $Folder
        
        Remove-Item (Join-Path $TargetFolder "ic_launcher.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TargetFolder "ic_launcher_round.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TargetFolder "ic_launcher_background.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TargetFolder "ic_launcher_foreground.xml") -ErrorAction SilentlyContinue
        
        Resize-And-Save $TechImage $Size (Join-Path $TargetFolder "ic_launcher.png")
        Resize-And-Save $TechImage $Size (Join-Path $TargetFolder "ic_launcher_round.png")
    }
    $TechImage.Dispose()
} else {
    Write-Warning "Technician App logo not found at: $TechLogoPath"
}

Write-Host "SUCCESS: App icons updated successfully!" -ForegroundColor Green
Write-Host "Please rebuild using .\build_apks.ps1 to apply the changes." -ForegroundColor Green

