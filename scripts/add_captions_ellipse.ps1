param(
    [string]$imagePath,
    [string]$outputPath,
    [string]$text1,
    [string]$text2,
    [string]$text3,
    [string]$text4
)

Add-Type -AssemblyName System.Drawing

$imagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($imagePath)
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)

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
$font = New-Object System.Drawing.Font($fontFamily, 13, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$textBrush = [System.Drawing.Brushes]::Black
$boxBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 255, 255)) # Soft pure white background (96% opacity)
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2.5) # Thicker border for comic style

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

# Speech bubble dimensions
$bubbleWidth = 260
$bubbleHeight = 130

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
    
    # Position the bubble near the top-center of each panel
    $rectX = $p.x + [int]((512 - $bubbleWidth) / 2)
    $rectY = $p.y + 40
    
    $rect = New-Object System.Drawing.RectangleF($rectX, $rectY, $bubbleWidth, $bubbleHeight)
    
    # Create a path to combine the ellipse and the tail pointer
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    
    # Add the main elliptical bubble
    $path.AddEllipse($rectX, $rectY, $bubbleWidth, $bubbleHeight)
    
    # Add the tail pointing down-left or down-right depending on the panel
    # Panel 1 & 3: tail points down-left; Panel 2 & 4: tail points down-right
    $tailDirection = 1
    if (($i % 2) -eq 1) { $tailDirection = -1 } # Point inward/outward
    
    $p1_x = $rectX + ($bubbleWidth / 2) - (15 * $tailDirection)
    $p1_y = $rectY + $bubbleHeight - 3
    $p2_x = $rectX + ($bubbleWidth / 2) + (10 * $tailDirection)
    $p2_y = $rectY + $bubbleHeight - 3
    $p3_x = $rectX + ($bubbleWidth / 2) - (35 * $tailDirection)
    $p3_y = $rectY + $bubbleHeight + 25
    
    $p1 = New-Object System.Drawing.PointF($p1_x, $p1_y)
    $p2 = New-Object System.Drawing.PointF($p2_x, $p2_y)
    $p3 = New-Object System.Drawing.PointF($p3_x, $p3_y)
    
    $path.AddPolygon(@($p1, $p2, $p3))
    
    # Draw bubble background and border
    $g.FillPath($boxBrush, $path)
    $g.DrawPath($borderPen, $path)
    
    # Draw text centered in the bubble
    # Ellipse bounds are tighter at corners, so we shrink the text area slightly for margins
    $textRect = New-Object System.Drawing.RectangleF(($rectX + 25), ($rectY + 20), ($bubbleWidth - 50), ($bubbleHeight - 40))
    $g.DrawString($txt, $font, $textBrush, $textRect, $sf)
    
    $path.Dispose()
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
Write-Output "Successfully overlaid speech bubbles on $outputPath"
