param(
    [string]$imagePath,
    [string]$outputPath,
    [string]$jsonPath
)

Add-Type -AssemblyName System.Drawing

$imagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($imagePath)
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
$jsonPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($jsonPath)

if (-not (Test-Path $imagePath)) {
    Write-Error "Input image not found: $imagePath"
    exit 1
}

if (-not (Test-Path $jsonPath)) {
    Write-Error "JSON config file not found: $jsonPath"
    exit 1
}

# Parse JSON
$jsonContent = Get-Content -Raw -Path $jsonPath -Encoding UTF8
$bubbles = $jsonContent | ConvertFrom-Json

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
$font = New-Object System.Drawing.Font($fontFamily, 12, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$textBrush = [System.Drawing.Brushes]::Black
$boxBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255)) # Solid white for classic comic style
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2.5) # Thicker border for comic style

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

$panels = @(
    @{ x = 0; y = 0 },      # Panel 1
    @{ x = 512; y = 0 },    # Panel 2
    @{ x = 0; y = 512 },    # Panel 3
    @{ x = 512; y = 512 }   # Panel 4
)

# Tail design parameters
$tailLengthFactor = 0.15 # Tail only goes 15% of the distance from the bubble boundary to the target
$baseHalfWidth = 7       # Half of the width of the tail base
$bendFactor = 0.00       # Set to 0.00 for a straight triangle tail

foreach ($b in $bubbles) {
    $pIdx = $b.panel - 1
    if ($pIdx -lt 0 -or $pIdx -ge 4) { continue }
    $p = $panels[$pIdx]
    
    $rectX = $p.x + $b.x
    $rectY = $p.y + $b.y
    $w = $b.w
    $h = $b.h
    $txt = $b.text
    
    $rx = $w / 2
    $ry = $h / 2
    $cx = $rectX + $rx
    $cy = $rectY + $ry
    
    # Create path for speech bubble
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($rectX, $rectY, $w, $h)
    
    # Draw tail if tail coordinates are provided
    if ($b.tail_x -ne $null -and $b.tail_y -ne $null) {
        $tx = $p.x + $b.tail_x
        $ty = $p.y + $b.tail_y
        
        # Direction vector from bubble center to target
        $dx = $tx - $cx
        $dy = $ty - $cy
        $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
        
        if ($dist -gt 0) {
            # Normalized direction vectors
            $udx = $dx / $dist
            $udy = $dy / $dist
            
            # Normalized perpendicular vectors
            $upx = -$udy
            $upy = $udx
            
            # 1. Calculate boundary point (B) of the ellipse along the direction vector
            $bx = $cx + $rx * $udx
            $by = $cy + $ry * $udy
            
            # 2. Calculate shortened tail tip (pt) - 30% of distance from boundary to target
            $pt_x = $bx + ($tx - $bx) * $tailLengthFactor
            $pt_y = $by + ($ty - $by) * $tailLengthFactor
            $tailLen = [Math]::Sqrt(($pt_x - $bx)*($pt_x - $bx) + ($pt_y - $by)*($pt_y - $by))
            
            # 3. Calculate tail base points (p1 and p2) on the ellipse boundary
            # Offset perpendicularly and slightly pull inwards toward center to ensure overlap
            $p1_x = $bx + $upx * $baseHalfWidth - $udx * 4
            $p1_y = $by + $upy * $baseHalfWidth - $udy * 4
            
            $p2_x = $bx - $upx * $baseHalfWidth - $udx * 4
            $p2_y = $by - $upy * $baseHalfWidth - $udy * 4
            
            # 4. Calculate control points for the Bezier curves to make them look curved
            # Shift control points perpendicularly by $bendFactor to create a natural hand-drawn bend
            $ctrl1_1_x = $p1_x + $udx * ($tailLen * 0.3) + $upx * ($tailLen * $bendFactor)
            $ctrl1_1_y = $p1_y + $udy * ($tailLen * 0.3) + $upy * ($tailLen * $bendFactor)
            $ctrl1_2_x = $pt_x - $udx * ($tailLen * 0.1) + $upx * ($tailLen * $bendFactor * 1.5)
            $ctrl1_2_y = $pt_y - $udy * ($tailLen * 0.1) + $upy * ($tailLen * $bendFactor * 1.5)
            
            # Curve 2 (pt to p2): curves back to the other side of the base
            $ctrl2_1_x = $pt_x - $udx * ($tailLen * 0.1) + $upx * ($tailLen * $bendFactor * 1.5)
            $ctrl2_1_y = $pt_y - $udy * ($tailLen * 0.1) + $upy * ($tailLen * $bendFactor * 1.5)
            $ctrl2_2_x = $p2_x + $udx * ($tailLen * 0.3) + $upx * ($tailLen * $bendFactor)
            $ctrl2_2_y = $p2_y + $udy * ($tailLen * 0.3) + $upy * ($tailLen * $bendFactor)
            
            # Add Bezier curves to the path
            $path.AddBezier($p1_x, $p1_y, $ctrl1_1_x, $ctrl1_1_y, $ctrl1_2_x, $ctrl1_2_y, $pt_x, $pt_y)
            $path.AddBezier($pt_x, $pt_y, $ctrl2_1_x, $ctrl2_1_y, $ctrl2_2_x, $ctrl2_2_y, $p2_x, $p2_y)
        }
    }
    
    # Fill and draw border
    $g.FillPath($boxBrush, $path)
    $g.DrawPath($borderPen, $path)
    
    # Draw text with padding inside the bubble
    $textRect = New-Object System.Drawing.RectangleF(($rectX + 22), ($rectY + 16), ($w - 44), ($h - 32))
    $g.DrawString($txt, $font, $textBrush, $textRect, $sf)
    
    $path.Dispose()
}

# Clean up and save to temporary file
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
Write-Output "Successfully overlaid JSON speech bubbles on $outputPath"
