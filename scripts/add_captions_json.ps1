[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$imagePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$outputPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$jsonPath,

    [switch]$Force,
    [switch]$AllowOverlap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Test-Property {
    param([object]$Object, [string]$Name)
    return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-NumberProperty {
    param(
        [object]$Object,
        [string]$Name,
        [double]$DefaultValue,
        [switch]$Required
    )

    if (-not (Test-Property $Object $Name)) {
        if ($Required) { throw "Missing required numeric property '$Name'." }
        return $DefaultValue
    }

    try {
        return [double]$Object.PSObject.Properties[$Name].Value
    }
    catch {
        throw "Property '$Name' must be numeric."
    }
}

function Get-AutoPosition {
    param(
        [string]$Position,
        [double]$PanelWidth,
        [double]$PanelHeight,
        [double]$Width,
        [double]$Height
    )

    $marginX = $PanelWidth * 0.04
    $marginY = $PanelHeight * 0.035
    $left = $marginX
    $centerX = ($PanelWidth - $Width) / 2.0
    $right = $PanelWidth - $Width - $marginX
    $top = $marginY
    $centerY = ($PanelHeight - $Height) / 2.0
    $bottom = $PanelHeight - $Height - $marginY

    switch ($Position) {
        "top-left" { return @{ x = $left; y = $top } }
        "top-center" { return @{ x = $centerX; y = $top } }
        "top-right" { return @{ x = $right; y = $top } }
        "center-left" { return @{ x = $left; y = $centerY } }
        "center" { return @{ x = $centerX; y = $centerY } }
        "center-right" { return @{ x = $right; y = $centerY } }
        "bottom-left" { return @{ x = $left; y = $bottom } }
        "bottom-center" { return @{ x = $centerX; y = $bottom } }
        "bottom-right" { return @{ x = $right; y = $bottom } }
        default { throw "Unsupported position '$Position'." }
    }
}

function New-SpeechBubblePath {
    param([double]$X, [double]$Y, [double]$Width, [double]$Height)

    $cx = $X + ($Width / 2.0)
    $cy = $Y + ($Height / 2.0)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath

    $top = [System.Drawing.PointF]::new([single]($cx - ($Width * 0.02)), [single]$Y)
    $right = [System.Drawing.PointF]::new([single]($X + $Width), [single]($cy - ($Height * 0.02)))
    $bottom = [System.Drawing.PointF]::new([single]($cx + ($Width * 0.01)), [single]($Y + $Height))
    $left = [System.Drawing.PointF]::new([single]$X, [single]($cy + ($Height * 0.01)))

    $path.StartFigure()
    $path.AddBezier(
        $top,
        [System.Drawing.PointF]::new([single]($X + ($Width * 0.78)), [single]($Y - ($Height * 0.005))),
        [System.Drawing.PointF]::new([single]($X + ($Width * 0.995)), [single]($Y + ($Height * 0.22))),
        $right
    )
    $path.AddBezier(
        $right,
        [System.Drawing.PointF]::new([single]($X + $Width), [single]($Y + ($Height * 0.78))),
        [System.Drawing.PointF]::new([single]($X + ($Width * 0.75)), [single]($Y + ($Height * 0.995))),
        $bottom
    )
    $path.AddBezier(
        $bottom,
        [System.Drawing.PointF]::new([single]($X + ($Width * 0.25)), [single]($Y + $Height)),
        [System.Drawing.PointF]::new([single]$X, [single]($Y + ($Height * 0.78))),
        $left
    )
    $path.AddBezier(
        $left,
        [System.Drawing.PointF]::new([single]$X, [single]($Y + ($Height * 0.24))),
        [System.Drawing.PointF]::new([single]($X + ($Width * 0.24)), [single]$Y),
        $top
    )
    $path.CloseFigure()
    return $path
}

function New-RoundedRectanglePath {
    param([double]$X, [double]$Y, [double]$Width, [double]$Height)

    $radius = [Math]::Min($Width, $Height) * 0.12
    $diameter = $radius * 2.0
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc([single]$X, [single]$Y, [single]$diameter, [single]$diameter, 180, 90)
    $path.AddArc([single]($X + $Width - $diameter), [single]$Y, [single]$diameter, [single]$diameter, 270, 90)
    $path.AddArc([single]($X + $Width - $diameter), [single]($Y + $Height - $diameter), [single]$diameter, [single]$diameter, 0, 90)
    $path.AddArc([single]$X, [single]($Y + $Height - $diameter), [single]$diameter, [single]$diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-ShoutBubblePath {
    param([double]$X, [double]$Y, [double]$Width, [double]$Height)

    $cx = $X + ($Width / 2.0)
    $cy = $Y + ($Height / 2.0)
    $rx = $Width / 2.0
    $ry = $Height / 2.0
    $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'

    for ($i = 0; $i -lt 32; $i++) {
        $angle = (2.0 * [Math]::PI * $i) / 32.0
        $factor = if (($i % 2) -eq 0) { 1.0 } else { 0.84 }
        $px = $cx + ($rx * [Math]::Cos($angle) * $factor)
        $py = $cy + ($ry * [Math]::Sin($angle) * $factor)
        $points.Add([System.Drawing.PointF]::new([single]$px, [single]$py))
    }

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddPolygon($points.ToArray())
    return $path
}

function Draw-HookTail {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Brush]$Brush,
        [System.Drawing.Pen]$Pen,
        [double]$BubbleX,
        [double]$BubbleY,
        [double]$BubbleWidth,
        [double]$BubbleHeight,
        [double]$TargetX,
        [double]$TargetY
    )

    $rx = $BubbleWidth / 2.0
    $ry = $BubbleHeight / 2.0
    $cx = $BubbleX + $rx
    $cy = $BubbleY + $ry
    $dx = $TargetX - $cx
    $dy = $TargetY - $cy
    $dist = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
    if ($dist -le 0) { return }

    $udx = $dx / $dist
    $udy = $dy / $dist
    $upx = -$udy
    $upy = $udx
    $ellipseScale = 1.0 / [Math]::Sqrt((($dx * $dx) / ($rx * $rx)) + (($dy * $dy) / ($ry * $ry)))
    $bx = $cx + ($dx * $ellipseScale)
    $by = $cy + ($dy * $ellipseScale)

    $scale = [Math]::Max(0.75, $BubbleHeight / 120.0)
    $baseHalfWidth = 12.0 * $scale
    $tailInset = 5.0 * $scale
    $tailLengthFactor = 0.18
    $ptX = $bx + (($TargetX - $bx) * $tailLengthFactor)
    $ptY = $by + (($TargetY - $by) * $tailLengthFactor)
    $tipSideShift = $baseHalfWidth * 1.50
    $ptX += $upx * $tipSideShift
    $ptY += $upy * $tipSideShift

    $p1 = [System.Drawing.PointF]::new(
        [single]($bx + ($upx * $baseHalfWidth) - ($udx * $tailInset)),
        [single]($by + ($upy * $baseHalfWidth) - ($udy * $tailInset))
    )
    $p2 = [System.Drawing.PointF]::new(
        [single]($bx - ($upx * $baseHalfWidth * 0.20) - ($udx * $tailInset)),
        [single]($by - ($upy * $baseHalfWidth * 0.20) - ($udy * $tailInset))
    )
    $tip = [System.Drawing.PointF]::new([single]$ptX, [single]$ptY)
    $tailLength = [Math]::Sqrt((($ptX - $bx) * ($ptX - $bx)) + (($ptY - $by) * ($ptY - $by)))
    $curveAmount = [Math]::Max(2.5, $tailLength * 0.16)

    $edge1Control1 = [System.Drawing.PointF]::new(
        [single]($p1.X + ($udx * $tailLength * 0.25) + ($upx * $curveAmount)),
        [single]($p1.Y + ($udy * $tailLength * 0.25) + ($upy * $curveAmount))
    )
    $edge1Control2 = [System.Drawing.PointF]::new(
        [single]($tip.X - ($udx * $tailLength * 0.25) + ($upx * $curveAmount * 0.45)),
        [single]($tip.Y - ($udy * $tailLength * 0.25) + ($upy * $curveAmount * 0.45))
    )
    $edge2Control1 = [System.Drawing.PointF]::new(
        [single]($tip.X - ($udx * $tailLength * 0.18) - ($upx * $curveAmount * 0.25)),
        [single]($tip.Y - ($udy * $tailLength * 0.18) - ($upy * $curveAmount * 0.25))
    )
    $edge2Control2 = [System.Drawing.PointF]::new(
        [single]($p2.X + ($udx * $tailLength * 0.45) - ($upx * $curveAmount * 0.25)),
        [single]($p2.Y + ($udy * $tailLength * 0.45) - ($upy * $curveAmount * 0.25))
    )

    $tailPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $tailPath.StartFigure()
        $tailPath.AddBezier($p1, $edge1Control1, $edge1Control2, $tip)
        $tailPath.AddBezier($tip, $edge2Control1, $edge2Control2, $p2)
        $tailPath.CloseFigure()
        $Graphics.FillPath($Brush, $tailPath)
        $Graphics.DrawBezier($Pen, $p1, $edge1Control1, $edge1Control2, $tip)
        $Graphics.DrawBezier($Pen, $tip, $edge2Control1, $edge2Control2, $p2)
    }
    finally {
        $tailPath.Dispose()
    }
}

function Draw-ThoughtTail {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Brush]$Brush,
        [System.Drawing.Pen]$Pen,
        [double]$BubbleX,
        [double]$BubbleY,
        [double]$BubbleWidth,
        [double]$BubbleHeight,
        [double]$TargetX,
        [double]$TargetY
    )

    $cx = $BubbleX + ($BubbleWidth / 2.0)
    $cy = $BubbleY + ($BubbleHeight / 2.0)
    $dx = $TargetX - $cx
    $dy = $TargetY - $cy
    $dist = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
    if ($dist -le 0) { return }

    $rx = $BubbleWidth / 2.0
    $ry = $BubbleHeight / 2.0
    $ellipseScale = 1.0 / [Math]::Sqrt((($dx * $dx) / ($rx * $rx)) + (($dy * $dy) / ($ry * $ry)))
    $bx = $cx + ($dx * $ellipseScale)
    $by = $cy + ($dy * $ellipseScale)
    $sizes = @(14.0, 10.0, 6.0)
    $fractions = @(0.16, 0.30, 0.43)

    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dotX = $bx + (($TargetX - $bx) * $fractions[$i])
        $dotY = $by + (($TargetY - $by) * $fractions[$i])
        $size = $sizes[$i]
        $Graphics.FillEllipse($Brush, [single]($dotX - ($size / 2.0)), [single]($dotY - ($size / 2.0)), [single]$size, [single]$size)
        $Graphics.DrawEllipse($Pen, [single]($dotX - ($size / 2.0)), [single]($dotY - ($size / 2.0)), [single]$size, [single]$size)
    }
}

function New-FittedFont {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.FontFamily]$Family,
        [System.Drawing.StringFormat]$Format,
        [string]$Text,
        [System.Drawing.RectangleF]$Rectangle,
        [double]$PreferredSize,
        [double]$MinimumSize,
        [System.Drawing.FontStyle]$Style
    )

    for ($size = [Math]::Floor($PreferredSize); $size -ge $MinimumSize; $size--) {
        $candidate = New-Object System.Drawing.Font($Family, $size, $Style, [System.Drawing.GraphicsUnit]::Pixel)
        $layout = [System.Drawing.SizeF]::new([single]$Rectangle.Width, [single]10000)
        $measured = $Graphics.MeasureString($Text, $candidate, $layout, $Format)
        if ($measured.Width -le ($Rectangle.Width + 1) -and $measured.Height -le ($Rectangle.Height + 1)) {
            return $candidate
        }
        $candidate.Dispose()
    }

    throw "Text does not fit inside its bubble even at ${MinimumSize}px: $Text"
}

$img = $null
$bmp = $null
$graphics = $null
$fontFamily = $null
$stringFormat = $null
$tempPath = $null

try {
    $imagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($imagePath)
    $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
    $jsonPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($jsonPath)

    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw "Input image not found: $imagePath" }
    if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { throw "JSON config file not found: $jsonPath" }
    if ([System.IO.Path]::GetFullPath($imagePath) -eq [System.IO.Path]::GetFullPath($outputPath)) {
        throw "Input and output must be different files. Keep the raw image and final image separate."
    }
    if ((Test-Path -LiteralPath $outputPath) -and -not $Force) {
        throw "Output already exists: $outputPath. Use -Force to replace the final image."
    }

    $outputDirectory = Split-Path -Parent $outputPath
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    try {
        $parsed = Get-Content -Raw -LiteralPath $jsonPath -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Invalid JSON config: $($_.Exception.Message)"
    }

    if (Test-Property $parsed "bubbles") {
        $bubbleSource = @($parsed.bubbles)
    }
    else {
        $bubbleSource = @($parsed)
    }
    if ($bubbleSource.Count -eq 0) { throw "JSON config must contain at least one bubble." }

    $img = [System.Drawing.Image]::FromFile($imagePath)
    $aspectRatio = $img.Width / $img.Height
    if ([Math]::Abs($aspectRatio - (4.0 / 5.0)) -gt 0.01) {
        throw "Input image must use a portrait 4:5 aspect ratio. Actual size: $($img.Width)x$($img.Height)"
    }

    $panelWidth = $img.Width / 2.0
    $panelHeight = $img.Height / 2.0
    $panelOrigins = @(
        @{ x = 0.0; y = 0.0 },
        @{ x = $panelWidth; y = 0.0 },
        @{ x = 0.0; y = $panelHeight },
        @{ x = $panelWidth; y = $panelHeight }
    )
    $allowedTypes = @("speech", "thought", "narration", "shout", "whisper")
    $autoSlots = @("top-left", "top-right", "bottom-left", "bottom-right", "top-center", "bottom-center", "center")
    $autoCounts = @{ 1 = 0; 2 = 0; 3 = 0; 4 = 0 }
    $resolvedBubbles = New-Object System.Collections.Generic.List[object]

    for ($index = 0; $index -lt $bubbleSource.Count; $index++) {
        $bubble = $bubbleSource[$index]
        if (-not (Test-Property $bubble "panel")) { throw "Bubble $($index + 1): missing 'panel'." }
        $panel = [int]$bubble.panel
        if ($panel -lt 1 -or $panel -gt 4) { throw "Bubble $($index + 1): panel must be between 1 and 4." }
        if (-not (Test-Property $bubble "text") -or [string]::IsNullOrWhiteSpace([string]$bubble.text)) {
            throw "Bubble $($index + 1): text cannot be empty."
        }

        $type = if (Test-Property $bubble "type") { ([string]$bubble.type).ToLowerInvariant() } else { "speech" }
        if ($allowedTypes -notcontains $type) {
            throw "Bubble $($index + 1): unsupported type '$type'. Allowed: $($allowedTypes -join ', ')."
        }

        $defaultWidthFactor = if ($type -eq "narration") { 0.78 } else { 0.54 }
        $defaultHeightFactor = if ($type -eq "narration") { 0.14 } elseif ($type -eq "shout") { 0.21 } else { 0.18 }
        $width = Get-NumberProperty $bubble "w" ($panelWidth * $defaultWidthFactor)
        $height = Get-NumberProperty $bubble "h" ($panelHeight * $defaultHeightFactor)
        if ($width -lt 80 -or $height -lt 55) { throw "Bubble $($index + 1): w and h are too small." }

        $hasX = Test-Property $bubble "x"
        $hasY = Test-Property $bubble "y"
        if ($hasX -xor $hasY) { throw "Bubble $($index + 1): provide both x and y, or neither." }

        if ($hasX) {
            $localX = Get-NumberProperty $bubble "x" 0 -Required
            $localY = Get-NumberProperty $bubble "y" 0 -Required
        }
        else {
            if (Test-Property $bubble "position") {
                $position = ([string]$bubble.position).ToLowerInvariant()
            }
            else {
                $slotIndex = $autoCounts[$panel] % $autoSlots.Count
                $position = $autoSlots[$slotIndex]
                $autoCounts[$panel]++
            }
            $autoPosition = Get-AutoPosition $position $panelWidth $panelHeight $width $height
            $localX = $autoPosition.x
            $localY = $autoPosition.y
        }

        if ($localX -lt 0 -or $localY -lt 0 -or ($localX + $width) -gt $panelWidth -or ($localY + $height) -gt $panelHeight) {
            throw "Bubble $($index + 1): rectangle exceeds panel $panel bounds."
        }

        $hasSpeakerX = Test-Property $bubble "speaker_x"
        $hasSpeakerY = Test-Property $bubble "speaker_y"
        $hasTailX = Test-Property $bubble "tail_x"
        $hasTailY = Test-Property $bubble "tail_y"
        if (($hasSpeakerX -xor $hasSpeakerY) -or ($hasTailX -xor $hasTailY)) {
            throw "Bubble $($index + 1): tail/speaker coordinates must be provided as an x/y pair."
        }

        $tailX = $null
        $tailY = $null
        if ($type -ne "narration") {
            if ($hasSpeakerX) {
                $tailX = Get-NumberProperty $bubble "speaker_x" 0 -Required
                $tailY = Get-NumberProperty $bubble "speaker_y" 0 -Required
            }
            elseif ($hasTailX) {
                $tailX = Get-NumberProperty $bubble "tail_x" 0 -Required
                $tailY = Get-NumberProperty $bubble "tail_y" 0 -Required
            }
            if ($null -ne $tailX -and ($tailX -lt 0 -or $tailY -lt 0 -or $tailX -gt $panelWidth -or $tailY -gt $panelHeight)) {
                throw "Bubble $($index + 1): tail/speaker target must stay inside panel $panel."
            }
        }

        $preferredFontSize = Get-NumberProperty $bubble "font_size" ([Math]::Min(28, [Math]::Max(18, [Math]::Round($img.Height / 60.0))))
        $minimumFontSize = Get-NumberProperty $bubble "min_font_size" 12
        if ($preferredFontSize -lt $minimumFontSize) { throw "Bubble $($index + 1): font_size must be >= min_font_size." }

        $origin = $panelOrigins[$panel - 1]
        $resolvedBubbles.Add([pscustomobject]@{
            index = $index + 1
            panel = $panel
            type = $type
            text = [string]$bubble.text
            localX = $localX
            localY = $localY
            x = $origin.x + $localX
            y = $origin.y + $localY
            w = $width
            h = $height
            tailX = if ($null -eq $tailX) { $null } else { $origin.x + $tailX }
            tailY = if ($null -eq $tailY) { $null } else { $origin.y + $tailY }
            preferredFontSize = $preferredFontSize
            minimumFontSize = $minimumFontSize
        })
    }

    if (-not $AllowOverlap) {
        for ($i = 0; $i -lt $resolvedBubbles.Count; $i++) {
            for ($j = $i + 1; $j -lt $resolvedBubbles.Count; $j++) {
                $a = $resolvedBubbles[$i]
                $b = $resolvedBubbles[$j]
                if ($a.panel -ne $b.panel) { continue }
                $rectA = [System.Drawing.RectangleF]::new([single]$a.localX, [single]$a.localY, [single]$a.w, [single]$a.h)
                $rectB = [System.Drawing.RectangleF]::new([single]$b.localX, [single]$b.localY, [single]$b.w, [single]$b.h)
                if ($rectA.IntersectsWith($rectB)) {
                    throw "Bubble $($a.index) and bubble $($b.index) overlap in panel $($a.panel). Reposition them or use -AllowOverlap."
                }
            }
        }
    }

    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.DrawImage($img, 0, 0, $img.Width, $img.Height)

    try {
        $fontFamily = New-Object System.Drawing.FontFamily("Microsoft JhengHei")
    }
    catch {
        $fontFamily = [System.Drawing.FontFamily]::GenericSansSerif
    }

    $stringFormat = New-Object System.Drawing.StringFormat
    $stringFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $stringFormat.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $stringFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

    foreach ($bubble in $resolvedBubbles) {
        $fillColor = switch ($bubble.type) {
            "narration" { [System.Drawing.Color]::FromArgb(248, 255, 247, 218) }
            "shout" { [System.Drawing.Color]::FromArgb(250, 255, 255, 245) }
            default { [System.Drawing.Color]::FromArgb(248, 255, 255, 252) }
        }
        $borderColor = if ($bubble.type -eq "whisper") {
            [System.Drawing.Color]::FromArgb(230, 92, 82, 72)
        }
        else {
            [System.Drawing.Color]::FromArgb(255, 58, 49, 40)
        }

        $fillBrush = New-Object System.Drawing.SolidBrush($fillColor)
        $borderPen = New-Object System.Drawing.Pen($borderColor, $(if ($bubble.type -eq "narration") { 1.5 } else { 2.0 }))
        $borderPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $borderPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $borderPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        if ($bubble.type -eq "whisper") { $borderPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }

        $bubblePath = $null
        $font = $null
        try {
            $bubblePath = switch ($bubble.type) {
                "narration" { New-RoundedRectanglePath $bubble.x $bubble.y $bubble.w $bubble.h }
                "shout" { New-ShoutBubblePath $bubble.x $bubble.y $bubble.w $bubble.h }
                default { New-SpeechBubblePath $bubble.x $bubble.y $bubble.w $bubble.h }
            }
            $graphics.FillPath($fillBrush, $bubblePath)
            $graphics.DrawPath($borderPen, $bubblePath)

            if ($null -ne $bubble.tailX) {
                if ($bubble.type -eq "thought") {
                    Draw-ThoughtTail $graphics $fillBrush $borderPen $bubble.x $bubble.y $bubble.w $bubble.h $bubble.tailX $bubble.tailY
                }
                elseif ($bubble.type -ne "narration") {
                    Draw-HookTail $graphics $fillBrush $borderPen $bubble.x $bubble.y $bubble.w $bubble.h $bubble.tailX $bubble.tailY
                }
            }

            $paddingX = [Math]::Max(18.0, $bubble.w * 0.09)
            $paddingY = [Math]::Max(14.0, $bubble.h * 0.14)
            if ($bubble.type -eq "shout") {
                $paddingX = [Math]::Max($paddingX, $bubble.w * 0.14)
                $paddingY = [Math]::Max($paddingY, $bubble.h * 0.18)
            }
            $textRectangle = [System.Drawing.RectangleF]::new(
                [single]($bubble.x + $paddingX),
                [single]($bubble.y + $paddingY),
                [single]($bubble.w - (2.0 * $paddingX)),
                [single]($bubble.h - (2.0 * $paddingY))
            )
            $fontStyle = if ($bubble.type -eq "whisper") { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
            $font = New-FittedFont $graphics $fontFamily $stringFormat $bubble.text $textRectangle $bubble.preferredFontSize $bubble.minimumFontSize $fontStyle
            $graphics.DrawString($bubble.text, $font, [System.Drawing.Brushes]::Black, $textRectangle, $stringFormat)
        }
        finally {
            if ($null -ne $font) { $font.Dispose() }
            if ($null -ne $bubblePath) { $bubblePath.Dispose() }
            $fillBrush.Dispose()
            $borderPen.Dispose()
        }
    }

    $tempPath = Join-Path $outputDirectory (([System.IO.Path]::GetFileName($outputPath)) + ".tmp." + [guid]::NewGuid().ToString("N") + ".png")
    $bmp.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose(); $graphics = $null
    $bmp.Dispose(); $bmp = $null
    $img.Dispose(); $img = $null

    Move-Item -LiteralPath $tempPath -Destination $outputPath -Force
    $tempPath = $null
    Write-Output "Successfully rendered $($resolvedBubbles.Count) bubbles to $outputPath"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if ($null -ne $graphics) { $graphics.Dispose() }
    if ($null -ne $bmp) { $bmp.Dispose() }
    if ($null -ne $img) { $img.Dispose() }
    if ($null -ne $stringFormat) { $stringFormat.Dispose() }
    if ($null -ne $fontFamily -and $fontFamily -ne [System.Drawing.FontFamily]::GenericSansSerif) { $fontFamily.Dispose() }
    if ($null -ne $tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force }
}
