param(
    [string]$imagePath,
    [string]$outputPath,
    [string]$text1,
    [string]$text2,
    [string]$text3,
    [string]$text4
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $imagePath)) {
    Write-Error "Input image not found: $imagePath"
    exit 1
}

$img = [System.Drawing.Image]::FromFile($imagePath)
$bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)

# Enable high quality rendering
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

# Draw original image
$g.DrawImage($img, 0, 0, $img.Width, $img.Height)

# Set up font and brushes
$fontFamily = New-Object System.Drawing.FontFamily("Microsoft JhengHei")
$font = New-Object System.Drawing.Font($fontFamily, 14, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$textBrush = [System.Drawing.Brushes]::Black
$boxBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 255, 255, 240)) # Soft light ivory background (92% opacity)
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

$boxHeight = 55
$boxMargin = 30
$yOffset = 25 # space from the bottom of each panel

$panels = @(
    @{ x = 0; y = 0 },      # Panel 1 (Top-Left)
    @{ x = 512; y = 0 },    # Panel 2 (Top-Right)
    @{ x = 0; y = 512 },    # Panel 3 (Bottom-Left)
    @{ x = 512; y = 512 }   # Panel 4 (Bottom-Right)
)

$texts = @($text1, $text2, $text3, $text4)

for ($i = 0; $i -lt 4; $i++) {
    $p = $panels[$i]
    $txt = $texts[$i]
    if ([string]::IsNullOrEmpty($txt)) { continue }
    
    $rectX = $p.x + $boxMargin
    $rectY = $p.y + 512 - $boxHeight - $yOffset
    $rectW = 512 - ($boxMargin * 2)
    $rectH = $boxHeight
    
    $rect = New-Object System.Drawing.RectangleF($rectX, $rectY, $rectW, $rectH)
    
    # Draw background box
    $g.FillRectangle($boxBrush, $rect)
    $g.DrawRectangle($borderPen, $rectX, $rectY, $rectW, $rectH)
    
    # Draw text centered in the box
    $g.DrawString($txt, $font, $textBrush, $rect, $sf)
}

# Clean up and save to temporary file to avoid lock issues
$g.Dispose()
$font.Dispose()
$fontFamily.Dispose()
$boxBrush.Dispose()
$borderPen.Dispose()

$tmpPath = $outputPath + ".tmp"
$bmp.Save($tmpPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$img.Dispose()

# Overwrite original file
Move-Item $tmpPath $outputPath -Force
Write-Output "Successfully overlaid text on $outputPath"
