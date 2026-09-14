Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\RAHUL\.gemini\antigravity-ide\brain\fbad632e-ac4f-422a-9c9e-3f1b9b421831\technician_app_icon_1786776972676.jpg"
if (!(Test-Path $srcPath)) {
    Write-Error "Source image not found at $srcPath"
    exit 1
}

$srcImg = [System.Drawing.Image]::FromFile($srcPath)

$assetDir = "d:\bookurtechnician\apps\technician_app\assets\images"
if (!(Test-Path $assetDir)) { New-Item -ItemType Directory -Path $assetDir -Force }
$iconDir = "d:\bookurtechnician\apps\technician_app\assets\icons"
if (!(Test-Path $iconDir)) { New-Item -ItemType Directory -Path $iconDir -Force }

$srcImg.Save("d:\bookurtechnician\apps\technician_app\assets\images\app_logo.png", [System.Drawing.Imaging.ImageFormat]::Png)
$srcImg.Save("d:\bookurtechnician\apps\technician_app\assets\icons\app_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)

function Resize-And-Save($src, $w, $h, $outPath) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $w, $h)
    $g.Dispose()
    $dir = [System.IO.Path]::GetDirectoryName($outPath)
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Generated: $outPath ($w x $h)"
}

$resBase = "d:\bookurtechnician\apps\technician_app\android\app\src\main\res"

Resize-And-Save $srcImg 48 48 "$resBase\mipmap-mdpi\ic_launcher.png"
Resize-And-Save $srcImg 48 48 "$resBase\mipmap-mdpi\ic_launcher_round.png"

Resize-And-Save $srcImg 72 72 "$resBase\mipmap-hdpi\ic_launcher.png"
Resize-And-Save $srcImg 72 72 "$resBase\mipmap-hdpi\ic_launcher_round.png"

Resize-And-Save $srcImg 96 96 "$resBase\mipmap-xhdpi\ic_launcher.png"
Resize-And-Save $srcImg 96 96 "$resBase\mipmap-xhdpi\ic_launcher_round.png"

Resize-And-Save $srcImg 144 144 "$resBase\mipmap-xxhdpi\ic_launcher.png"
Resize-And-Save $srcImg 144 144 "$resBase\mipmap-xxhdpi\ic_launcher_round.png"

Resize-And-Save $srcImg 192 192 "$resBase\mipmap-xxxhdpi\ic_launcher.png"
Resize-And-Save $srcImg 192 192 "$resBase\mipmap-xxxhdpi\ic_launcher_round.png"

$srcImg.Dispose()
Write-Host "All technician app launcher icons successfully generated and installed!"
