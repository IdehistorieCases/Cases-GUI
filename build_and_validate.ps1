param(
    [string]$BlenderPath,
    [string]$GodotPath
)

# Defaults can be replaced with -BlenderPath / -GodotPath or BLENDER_EXE / GODOT_EXE.
$ErrorActionPreference = "Continue"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($BlenderPath)) { $BlenderPath = $env:BLENDER_EXE }
if ([string]::IsNullOrWhiteSpace($BlenderPath)) {
    $blenderCommand = Get-Command blender.exe -ErrorAction SilentlyContinue
    if ($blenderCommand) { $BlenderPath = $blenderCommand.Source }
    else { $BlenderPath = "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_EXE }
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot4.exe,godot.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
    else { $GodotPath = "D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" }
}

if (-not (Test-Path -LiteralPath $BlenderPath -PathType Leaf)) { throw "Blender executable not found: $BlenderPath" }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }

$generator = Join-Path $repoRoot "art_source\scripts\build_suited_negotiator.py"
$godotProject = Join-Path $repoRoot "godot"
$characterGlb = Join-Path $godotProject "assets\characters\cases_suited_negotiator.glb"
$editableBlend = Join-Path $repoRoot "art_source\output\cases_suited_negotiator.blend"
$previewRoot = Join-Path $repoRoot "art_source\output\v2"
$requiredPreviews = @(
    "seated_idle_front.png",
    "seated_idle_three_quarter.png",
    "seated_idle_side.png",
    "seated_talking_front.png",
    "seated_talking_three_quarter.png",
    "seated_talking_side.png",
    "left_sleeve_detail.png",
    "right_sleeve_detail.png",
    "jacket_detail.png"
)
$previewFrames = @(1, 10, 22, 30, 45, 60) | ForEach-Object { "talking_frames\talking_frame_{0:d2}.png" -f $_ }
$legacyPreviews = @("seated_idle.png", "seated_talking.png")
$refinementBefore = Join-Path (Join-Path $previewRoot "pre_refinement") "seated_talking_front.png"
$refinementComparison = Join-Path $previewRoot "before_after_talking_comparison.png"
$godotCaptureBase = Join-Path $previewRoot "godot_engine_capture.png"
$godotCaptureFrame = Join-Path $previewRoot "godot_engine_capture00000000.png"
$godotCaptureAudio = Join-Path $previewRoot "godot_engine_capture.wav"
$godotCaptureLog = Join-Path $previewRoot "godot_capture.log"

# Remove only generated preview targets so a failed Blender render cannot be
# masked by an older file left from a previous iteration.
New-Item -ItemType Directory -Force -Path $previewRoot | Out-Null
foreach ($previewName in $requiredPreviews) {
    $previewPath = Join-Path $previewRoot $previewName
    if (Test-Path -LiteralPath $previewPath) { Remove-Item -LiteralPath $previewPath -Force }
}
foreach ($frameName in $previewFrames) {
    $framePath = Join-Path $previewRoot $frameName
    if (Test-Path -LiteralPath $framePath) { Remove-Item -LiteralPath $framePath -Force }
}
foreach ($previewName in $legacyPreviews) {
    $previewPath = Join-Path (Join-Path $repoRoot "art_source\output") $previewName
    if (Test-Path -LiteralPath $previewPath) { Remove-Item -LiteralPath $previewPath -Force }
}
$sheetPath = Join-Path $previewRoot "comparison_contact_sheet.png"
if (Test-Path -LiteralPath $sheetPath) { Remove-Item -LiteralPath $sheetPath -Force }
foreach ($captureTarget in @($refinementComparison, $godotCaptureFrame, $godotCaptureAudio, $godotCaptureLog)) {
    if (Test-Path -LiteralPath $captureTarget) { Remove-Item -LiteralPath $captureTarget -Force }
}

Write-Output "Building the procedural character with Blender: $BlenderPath"
$buildStartedAt = Get-Date
& $BlenderPath -b --python $generator
if ($LASTEXITCODE -ne 0) { throw "Blender character generation failed with exit code $LASTEXITCODE" }

foreach ($requiredFile in @($characterGlb, $editableBlend)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "Required generated asset missing: $requiredFile" }
    $fileInfo = Get-Item -LiteralPath $requiredFile
    if ($fileInfo.Length -le 0) { throw "Generated asset is empty: $requiredFile" }
    if ($fileInfo.LastWriteTime -lt $buildStartedAt.AddSeconds(-1)) { throw "Generated asset was not refreshed by this Blender run: $requiredFile" }
}
foreach ($previewName in $requiredPreviews) {
    $previewPath = Join-Path $previewRoot $previewName
    if (-not (Test-Path -LiteralPath $previewPath -PathType Leaf)) { throw "Required render missing: $previewPath" }
    $fileInfo = Get-Item -LiteralPath $previewPath
    if ($fileInfo.Length -le 0) { throw "Required render is empty: $previewPath" }
    if ($fileInfo.LastWriteTime -lt $buildStartedAt.AddSeconds(-1)) { throw "Required render was not refreshed by this Blender run: $previewPath" }
}
foreach ($frameName in $previewFrames) {
    $framePath = Join-Path $previewRoot $frameName
    if (-not (Test-Path -LiteralPath $framePath -PathType Leaf)) { throw "Talking pose render missing: $framePath" }
    $fileInfo = Get-Item -LiteralPath $framePath
    if ($fileInfo.Length -le 0) { throw "Talking pose render is empty: $framePath" }
    if ($fileInfo.LastWriteTime -lt $buildStartedAt.AddSeconds(-1)) { throw "Talking pose render was not refreshed by this Blender run: $framePath" }
}

# Create a comparison sheet with .NET's built-in Windows imaging library.
Add-Type -AssemblyName System.Drawing
$tileWidth = 400
$tileHeight = 400
$headerHeight = 30
$columns = 4
$rows = [int][Math]::Ceiling($requiredPreviews.Count / $columns)
$sheet = [System.Drawing.Bitmap]::new($columns * $tileWidth, $rows * ($tileHeight + $headerHeight))
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$font = [System.Drawing.Font]::new("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(37, 42, 49))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    for ($index = 0; $index -lt $requiredPreviews.Count; $index++) {
        $name = $requiredPreviews[$index]
        $previewPath = Join-Path $previewRoot $name
        $image = [System.Drawing.Image]::FromFile($previewPath)
        try {
            if ($image.Width -lt 1080 -or $image.Height -lt 1080) { throw "Render must be at least 1080 px: $previewPath" }
            $x = ($index % $columns) * $tileWidth
            $y = [Math]::Floor($index / $columns) * ($tileHeight + $headerHeight)
            $label = [System.IO.Path]::GetFileNameWithoutExtension($name).Replace("_", " ")
            $graphics.DrawString($label, $font, $brush, [single]($x + 8), [single]($y + 5))
            $destination = [System.Drawing.Rectangle]::new($x, $y + $headerHeight, $tileWidth, $tileHeight)
            $graphics.DrawImage($image, $destination)
        }
        finally { $image.Dispose() }
    }
    $sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $sheet.Dispose()
}
if (-not (Test-Path -LiteralPath $sheetPath -PathType Leaf) -or (Get-Item -LiteralPath $sheetPath).Length -le 0) {
    throw "Comparison contact sheet was not generated: $sheetPath"
}

if (-not (Test-Path -LiteralPath $refinementBefore -PathType Leaf)) {
    throw "Preserved pre-refinement talking render is missing: $refinementBefore"
}
$beforeAfter = [System.Drawing.Bitmap]::new(1200, 642)
$beforeAfterGraphics = [System.Drawing.Graphics]::FromImage($beforeAfter)
$beforeAfterFont = [System.Drawing.Font]::new("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)
$beforeAfterBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
try {
    $beforeAfterGraphics.Clear([System.Drawing.Color]::FromArgb(37, 42, 49))
    $beforeAfterGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $beforeAfterGraphics.DrawString("Before refinement - talking frame", $beforeAfterFont, $beforeAfterBrush, [single]12, [single]8)
    $beforeAfterGraphics.DrawString("Refined V2 - same camera and frame", $beforeAfterFont, $beforeAfterBrush, [single]612, [single]8)
    foreach ($tile in @(@{ Path = $refinementBefore; X = 0 }, @{ Path = (Join-Path $previewRoot "seated_talking_front.png"); X = 600 })) {
        $image = [System.Drawing.Image]::FromFile($tile.Path)
        try {
            $destination = [System.Drawing.Rectangle]::new($tile.X, 42, 600, 600)
            $beforeAfterGraphics.DrawImage($image, $destination)
        }
        finally { $image.Dispose() }
    }
    $beforeAfter.Save($refinementComparison, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $beforeAfterBrush.Dispose()
    $beforeAfterFont.Dispose()
    $beforeAfterGraphics.Dispose()
    $beforeAfter.Dispose()
}
if (-not (Test-Path -LiteralPath $refinementComparison -PathType Leaf) -or (Get-Item -LiteralPath $refinementComparison).Length -le 0) {
    throw "Before/after refinement comparison was not generated: $refinementComparison"
}

Write-Output "Importing generated GLB into Godot: $GodotPath"
& $GodotPath --headless --editor --import --path $godotProject
if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE" }

Write-Output "Running animation, skinning, and proportion checks"
& $GodotPath --headless --path $godotProject --script res://tests/validate_suit.gd
if ($LASTEXITCODE -ne 0) { throw "Godot suit validation failed with exit code $LASTEXITCODE" }

Write-Output "Starting the Compatibility-renderer demo headlessly"
& $GodotPath --headless --path $godotProject --quit-after 5
if ($LASTEXITCODE -ne 0) { throw "Godot demo runtime failed with exit code $LASTEXITCODE" }

Write-Output "Capturing a Compatibility-renderer demo frame with Godot Movie Maker"
& $GodotPath --path $godotProject --scene res://scenes/seated_suit_demo.tscn --write-movie $godotCaptureBase --fixed-fps 30 --quit-after 1 --resolution 1152x648 --log-file $godotCaptureLog
if ($LASTEXITCODE -ne 0) { throw "Godot visual capture failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $godotCaptureFrame -PathType Leaf)) { throw "Godot visual capture did not produce its PNG frame: $godotCaptureFrame" }
if ((Get-Item -LiteralPath $godotCaptureFrame).Length -le 0) { throw "Godot visual capture is empty: $godotCaptureFrame" }
if (Test-Path -LiteralPath $godotCaptureAudio) { Remove-Item -LiteralPath $godotCaptureAudio -Force }

Write-Output "CASES Suited Negotiator V2 build and validation PASS"
