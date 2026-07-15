[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$imagePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$outputPath,

    [ValidateRange(320, 3840)]
    [int]$width = 1080,

    [ValidateRange(400, 4800)]
    [int]$height = 1350,

    [ValidateSet("crop", "letterbox", "stretch")]
    [string]$fit = "crop",

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$img = $null
$bmp = $null
$graphics = $null
$backgroundBrush = $null
$tempPath = $null

try {
    $imagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($imagePath)
    $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)

    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw "Input image not found: $imagePath" }
    if ([System.IO.Path]::GetFullPath($imagePath) -eq [System.IO.Path]::GetFullPath($outputPath)) {
        throw "Input and output must be different files. Preserve the raw image."
    }
    if ((Test-Path -LiteralPath $outputPath) -and -not $Force) {
        throw "Output already exists: $outputPath. Use -Force to replace the normalized copy."
    }

    $outputDirectory = Split-Path -Parent $outputPath
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $img = [System.Drawing.Image]::FromFile($imagePath)
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    if ($fit -eq "letterbox") {
        $backgroundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 250, 247, 238))
        $graphics.FillRectangle($backgroundBrush, 0, 0, $width, $height)
        $scale = [Math]::Min($width / $img.Width, $height / $img.Height)
        $drawWidth = $img.Width * $scale
        $drawHeight = $img.Height * $scale
        $destX = ($width - $drawWidth) / 2.0
        $destY = ($height - $drawHeight) / 2.0
        $destRect = [System.Drawing.RectangleF]::new([single]$destX, [single]$destY, [single]$drawWidth, [single]$drawHeight)
        $graphics.DrawImage($img, $destRect)
    }
    elseif ($fit -eq "stretch") {
        $graphics.DrawImage($img, 0, 0, $width, $height)
    }
    else {
        $sourceRatio = $img.Width / $img.Height
        $targetRatio = $width / $height

        if ($sourceRatio -gt $targetRatio) {
            $cropHeight = [double]$img.Height
            $cropWidth = $cropHeight * $targetRatio
            $cropX = ($img.Width - $cropWidth) / 2.0
            $cropY = 0.0
        }
        else {
            $cropWidth = [double]$img.Width
            $cropHeight = $cropWidth / $targetRatio
            $cropX = 0.0
            $cropY = ($img.Height - $cropHeight) / 2.0
        }

        $destinationRect = [System.Drawing.RectangleF]::new(0, 0, [single]$width, [single]$height)
        $sourceRect = [System.Drawing.RectangleF]::new([single]$cropX, [single]$cropY, [single]$cropWidth, [single]$cropHeight)
        $graphics.DrawImage($img, $destinationRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    }

    $tempPath = Join-Path $outputDirectory (([System.IO.Path]::GetFileName($outputPath)) + ".tmp." + [guid]::NewGuid().ToString("N") + ".png")
    $bmp.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose(); $graphics = $null
    $bmp.Dispose(); $bmp = $null
    $img.Dispose(); $img = $null

    Move-Item -LiteralPath $tempPath -Destination $outputPath -Force
    $tempPath = $null
    Write-Output "Normalized image to ${width}x${height}: $outputPath"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if ($null -ne $backgroundBrush) { $backgroundBrush.Dispose() }
    if ($null -ne $graphics) { $graphics.Dispose() }
    if ($null -ne $bmp) { $bmp.Dispose() }
    if ($null -ne $img) { $img.Dispose() }
    if ($null -ne $tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force }
}
