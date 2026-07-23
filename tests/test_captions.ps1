[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Invoke-HiddenPowerShell {
    param([string]$Arguments)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $null = $process.StandardOutput.ReadToEnd()
        $null = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return $process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$normalizeScript = Join-Path $repoRoot "scripts\normalize_comic.ps1"
$captionScript = Join-Path $repoRoot "scripts\add_captions_json.ps1"
$fixturePath = Join-Path $PSScriptRoot "fixtures\bubbles.json"
$tempRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$tempDirectory = Join-Path $tempRoot ("teaching-comic-tests-" + [guid]::NewGuid().ToString("N"))
$sourcePath = Join-Path $tempDirectory "source-square.png"
$normalizedPath = Join-Path $tempDirectory "comic-normalized.png"
$finalPath = Join-Path $tempDirectory "comic-final.png"
$textOnlyPath = Join-Path $tempDirectory "comic-final-textonly.png"
$invalidJsonPath = Join-Path $tempDirectory "invalid.json"

function Measure-ChangedPixels {
    param([string]$BasePath, [string]$ComparePath)

    $baseBitmap = New-Object System.Drawing.Bitmap($BasePath)
    $compareBitmap = New-Object System.Drawing.Bitmap($ComparePath)
    try {
        $changed = 0
        for ($x = 0; $x -lt $baseBitmap.Width; $x += 4) {
            for ($y = 0; $y -lt $baseBitmap.Height; $y += 4) {
                $a = $baseBitmap.GetPixel($x, $y)
                $b = $compareBitmap.GetPixel($x, $y)
                if ([Math]::Abs($a.R - $b.R) -gt 12 -or [Math]::Abs($a.G - $b.G) -gt 12 -or [Math]::Abs($a.B - $b.B) -gt 12) {
                    $changed++
                }
            }
        }
        return $changed
    }
    finally {
        $baseBitmap.Dispose()
        $compareBitmap.Dispose()
    }
}

try {
    New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null

    $bitmap = New-Object System.Drawing.Bitmap(1200, 1200)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $brushes = @(
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 231, 244, 255))),
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 241, 255, 232))),
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 242, 224))),
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 246, 234, 255)))
    )
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 70, 60, 50), 8)
    try {
        $graphics.FillRectangle($brushes[0], 0, 0, 600, 600)
        $graphics.FillRectangle($brushes[1], 600, 0, 600, 600)
        $graphics.FillRectangle($brushes[2], 0, 600, 600, 600)
        $graphics.FillRectangle($brushes[3], 600, 600, 600, 600)
        $graphics.DrawLine($gridPen, 600, 0, 600, 1200)
        $graphics.DrawLine($gridPen, 0, 600, 1200, 600)
        $bitmap.Save($sourcePath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $gridPen.Dispose()
        foreach ($brush in $brushes) { $brush.Dispose() }
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $normalizeScript `
        -imagePath $sourcePath `
        -outputPath $normalizedPath
    if ($LASTEXITCODE -ne 0) { throw "normalize_comic.ps1 failed." }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $captionScript `
        -imagePath $normalizedPath `
        -outputPath $finalPath `
        -jsonPath $fixturePath
    if ($LASTEXITCODE -ne 0) { throw "add_captions_json.ps1 failed." }

    $result = [System.Drawing.Image]::FromFile($finalPath)
    try {
        if ($result.Width -ne 1080 -or $result.Height -ne 1350) {
            throw "Unexpected output size: $($result.Width)x$($result.Height)"
        }
    }
    finally {
        $result.Dispose()
    }

    $pixelCheck = New-Object System.Drawing.Bitmap($finalPath)
    try {
        $darkPixels = 0
        $sampleCount = 0
        for ($x = 10; $x -lt $pixelCheck.Width; $x += 20) {
            for ($y = 10; $y -lt $pixelCheck.Height; $y += 20) {
                $pixel = $pixelCheck.GetPixel($x, $y)
                if ($pixel.R -lt 20 -and $pixel.G -lt 20 -and $pixel.B -lt 20) { $darkPixels++ }
                $sampleCount++
            }
        }
        if (($darkPixels / $sampleCount) -gt 0.05) {
            throw "Unexpected black-area regression detected."
        }
    }
    finally {
        $pixelCheck.Dispose()
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $captionScript `
        -imagePath $normalizedPath `
        -outputPath $textOnlyPath `
        -jsonPath $fixturePath `
        -TextOnly
    if ($LASTEXITCODE -ne 0) { throw "add_captions_json.ps1 -TextOnly failed." }

    $fullDiff = Measure-ChangedPixels $normalizedPath $finalPath
    $textOnlyDiff = Measure-ChangedPixels $normalizedPath $textOnlyPath
    if ($textOnlyDiff -eq 0) { throw "-TextOnly rendered nothing onto the image." }
    if ($textOnlyDiff -ge ($fullDiff * 0.5)) {
        throw "-TextOnly still paints bubble shapes (changed=$textOnlyDiff vs full=$fullDiff)."
    }

    $samePathArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$captionScript`" -imagePath `"$normalizedPath`" -outputPath `"$normalizedPath`" -jsonPath `"$fixturePath`""
    $samePathExitCode = Invoke-HiddenPowerShell $samePathArguments
    if ($samePathExitCode -eq 0) { throw "Same-path safety check did not fail as expected." }

    [System.IO.File]::WriteAllText(
        $invalidJsonPath,
        '[{"panel":9,"text":"invalid"}]',
        [System.Text.UTF8Encoding]::new($false)
    )
    $invalidOutputPath = Join-Path $tempDirectory "invalid-output.png"
    $invalidArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$captionScript`" -imagePath `"$normalizedPath`" -outputPath `"$invalidOutputPath`" -jsonPath `"$invalidJsonPath`""
    $invalidExitCode = Invoke-HiddenPowerShell $invalidArguments
    if ($invalidExitCode -eq 0) { throw "Invalid-panel validation did not fail as expected." }

    $leftovers = @(Get-ChildItem -LiteralPath $tempDirectory -File | Where-Object { $_.Name -like "*.tmp.*" })
    if ($leftovers.Count -gt 0) { throw "Temporary files were not cleaned up." }

    Write-Output "PASS: normalize, render, five bubble types, auto-fit, text-only mode, validation, overwrite protection, and temp cleanup."
}
finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempDirectory)
    if ($resolvedTemp.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
