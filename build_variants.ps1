param(
    [string]$BlenderPath,
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
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
$characterRoot = Join-Path $repoRoot "godot\assets\characters"
$sourceCharacter = Join-Path $repoRoot "art_source\vendor\quaternius\universal-base-character.glb"
$defaultBlend = Join-Path $repoRoot "art_source\output\cases_suited_negotiator.blend"
$defaultGlb = Join-Path $characterRoot "cases_suited_negotiator.glb"
$legacyPreview = Join-Path $repoRoot "art_source\output\v2\seated_idle_front.png"
$variantRoot = Join-Path $repoRoot "art_source\output\v3"
$personas = @("senior_mediator", "younger_envoy", "scholarly_delegate")
$requiredRenderNames = @(
    "seated_idle_front.png", "seated_idle_three_quarter.png", "seated_idle_side.png",
    "seated_talking_front.png", "talking_frame_22.png", "talking_frame_30.png",
    "left_sleeve_detail.png", "right_sleeve_detail.png", "jacket_detail.png", "face_detail.png"
)
$legacyFiles = [ordered]@{
    "quaternius_source_glb" = $sourceCharacter
    "default_blend" = $defaultBlend
    "default_godot_glb" = $defaultGlb
}
foreach ($legacyPath in $legacyFiles.Values) {
    if (-not (Test-Path -LiteralPath $legacyPath -PathType Leaf)) { throw "Legacy file required for integrity proof is missing: $legacyPath" }
}
if (-not (Test-Path -LiteralPath $legacyPreview -PathType Leaf)) { throw "Default V2 preview required for comparison is missing: $legacyPreview" }
$beforeHashes = [ordered]@{}
foreach ($entry in $legacyFiles.GetEnumerator()) {
    $beforeHashes[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash
}

$buildStartedAt = Get-Date
Write-Output "Building variant-only personas with Blender: $BlenderPath"
foreach ($persona in $personas) {
    $variantGlb = Join-Path $characterRoot "cases_suited_negotiator_$persona.glb"
    $variantDir = Join-Path $variantRoot $persona
    $variantBlend = Join-Path $variantDir "$persona.blend"
    if ($variantGlb -in @($defaultGlb) -or $variantBlend -in @($defaultBlend)) {
        throw "Variant output path aliases a legacy asset: $persona"
    }
    & $BlenderPath -b --python $generator -- --persona $persona
    if ($LASTEXITCODE -ne 0) { throw "Blender generation failed for $persona with exit code $LASTEXITCODE" }
    foreach ($requiredFile in @($variantGlb, $variantBlend)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "Variant asset is missing: $requiredFile" }
        $fileInfo = Get-Item -LiteralPath $requiredFile
        if ($fileInfo.Length -le 0) { throw "Variant asset is empty: $requiredFile" }
        if ($fileInfo.LastWriteTime -lt $buildStartedAt.AddSeconds(-1)) { throw "Variant asset was not refreshed by this run: $requiredFile" }
    }
    foreach ($renderName in $requiredRenderNames) {
        $renderPath = Join-Path $variantDir $renderName
        if (-not (Test-Path -LiteralPath $renderPath -PathType Leaf)) { throw "Variant render is missing: $renderPath" }
        $renderInfo = Get-Item -LiteralPath $renderPath
        if ($renderInfo.Length -le 0) { throw "Variant render is empty: $renderPath" }
        if ($renderInfo.LastWriteTime -lt $buildStartedAt.AddSeconds(-1)) { throw "Variant render was not refreshed by this run: $renderPath" }
        $render = [System.Drawing.Image]::FromFile($renderPath)
        try {
            if ($render.Width -ne 1200 -or $render.Height -ne 1200) { throw "Unexpected render size for $renderPath ($($render.Width)x$($render.Height))" }
        } finally {
            $render.Dispose()
        }
    }
    Write-Output "Built and checked $persona"
}

# The comparison uses an existing default preview read-only and the new V3
# previews. No legacy renderer or cleanup path is called from this script.
$contactSheet = Join-Path $variantRoot "four_character_contact_sheet.png"
$tileWidth = 600
$tileHeight = 600
$labelHeight = 42
$margin = 18
$canvasWidth = $margin * 3 + $tileWidth * 2
$canvasHeight = $margin * 3 + ($tileHeight + $labelHeight) * 2
$bitmap = New-Object System.Drawing.Bitmap($canvasWidth, $canvasHeight)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::FromArgb(24, 31, 40))
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$tiles = @(
    @{ Label = "LEGACY DEFAULT · V2 PREVIEW"; Path = $legacyPreview },
    @{ Label = "SENIOR MEDIATOR · DOUBLE-BREASTED"; Path = (Join-Path (Join-Path $variantRoot "senior_mediator") "seated_idle_front.png") },
    @{ Label = "YOUNGER ENVOY · BLUE SUIT"; Path = (Join-Path (Join-Path $variantRoot "younger_envoy") "seated_idle_front.png") },
    @{ Label = "SCHOLARLY DELEGATE · OLIVE SUIT"; Path = (Join-Path (Join-Path $variantRoot "scholarly_delegate") "seated_idle_front.png") }
)
try {
    for ($index = 0; $index -lt $tiles.Count; $index++) {
        $column = $index % 2
        $row = [Math]::Floor($index / 2)
        $x = $margin + $column * ($tileWidth + $margin)
        $y = $margin + $row * ($tileHeight + $labelHeight + $margin)
        $image = [System.Drawing.Image]::FromFile($tiles[$index].Path)
        try { $graphics.DrawImage($image, $x, $y, $tileWidth, $tileHeight) }
        finally { $image.Dispose() }
        $graphics.DrawString($tiles[$index].Label, $font, $brush, [single]$x, [single]($y + $tileHeight + 8))
    }
    $bitmap.Save($contactSheet, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$godotProject = Join-Path $repoRoot "godot"
$godotCapture = Join-Path $variantRoot "godot_variant_lineup.png"
$godotComparison = Join-Path $variantRoot "four_character_blender_godot_comparison.png"
$godotVersion = (& $GodotPath --version | Out-String).Trim()
$temporaryRootFull = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
$temporaryProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $temporaryRootFull ("CasesGUI_HistoricalDelegate_GodotValidation_" + [Guid]::NewGuid().ToString("N"))))
if (-not $temporaryProjectRoot.StartsWith($temporaryRootFull, [StringComparison]::OrdinalIgnoreCase)) { throw "Temporary Godot project escaped the OS temporary directory: $temporaryProjectRoot" }
try {
New-Item -ItemType Directory -Path $temporaryProjectRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $godotProject "project.godot") -Destination (Join-Path $temporaryProjectRoot "project.godot") -Force
foreach ($relativeDirectory in @("assets\characters", "tests", "scenes", "scripts", "capture")) {
    New-Item -ItemType Directory -Path (Join-Path $temporaryProjectRoot $relativeDirectory) -Force | Out-Null
}
foreach ($assetName in (@("cases_suited_negotiator.glb") + @($personas | ForEach-Object { "cases_suited_negotiator_$_.glb" }))) {
    Copy-Item -LiteralPath (Join-Path $characterRoot $assetName) -Destination (Join-Path $temporaryProjectRoot "assets\characters\$assetName") -Force
}
foreach ($relativeFile in @(
    "tests\validate_suit.gd",
    "scenes\delegate_variants_preview.tscn",
    "scripts\delegate_variants_preview.gd",
    "scenes\seated_suit_demo.tscn",
    "scripts\seated_suit_demo.gd"
)) {
    Copy-Item -LiteralPath (Join-Path $godotProject $relativeFile) -Destination (Join-Path $temporaryProjectRoot $relativeFile) -Force
}

Write-Output "Importing the four GLBs in an isolated Godot project: $godotVersion"
& $GodotPath --headless --editor --path $temporaryProjectRoot --import
$importExit = $LASTEXITCODE
if ($importExit -ne 0) { throw "Godot isolated import failed with exit code $importExit" }

$validationOutput = & $GodotPath --headless --path $temporaryProjectRoot --script res://tests/validate_suit.gd 2>&1
$validationExit = $LASTEXITCODE
$validationText = $validationOutput | Out-String
Write-Output $validationText
if ($validationExit -ne 0) { throw "Godot four-asset validation failed with exit code $validationExit" }
if (-not $validationText.Contains("CASES validated character assets: 4")) { throw "Godot validator did not report all four character assets" }

$demoOutput = & $GodotPath --headless --path $temporaryProjectRoot --scene res://scenes/seated_suit_demo.tscn --quit-after 2 2>&1
$demoExit = $LASTEXITCODE
$demoText = $demoOutput | Out-String
Write-Output $demoText
if ($demoExit -ne 0 -or -not $demoText.Contains("CASES loaded animations:")) { throw "Unchanged single-character Godot demo did not load the original default" }

$moviePath = Join-Path (Join-Path $temporaryProjectRoot "capture") "lineup.png"
& $GodotPath --path $temporaryProjectRoot --scene res://scenes/delegate_variants_preview.tscn --write-movie $moviePath --quit-after 1
$movieExit = $LASTEXITCODE
if ($movieExit -ne 0) { throw "Godot visual lineup capture failed with exit code $movieExit" }
$framePath = Join-Path (Join-Path $temporaryProjectRoot "capture") "lineup00000000.png"
if (-not (Test-Path -LiteralPath $framePath -PathType Leaf)) { throw "Godot did not produce the first lineup frame: $framePath" }
$capture = [System.Drawing.Bitmap]::FromFile($framePath)
try {
    if ($capture.Width -lt 1000 -or $capture.Height -lt 600) { throw "Godot lineup capture is too small: $($capture.Width)x$($capture.Height)" }
    $brightSamples = 0
    for ($sampleY = 0; $sampleY -lt $capture.Height; $sampleY += 18) {
        for ($sampleX = 0; $sampleX -lt $capture.Width; $sampleX += 18) {
            $pixel = $capture.GetPixel($sampleX, $sampleY)
            if ($pixel.R -gt 70 -or $pixel.G -gt 70 -or $pixel.B -gt 70) { $brightSamples++ }
        }
    }
    if ($brightSamples -lt 40) { throw "Godot lineup capture is black or empty" }
} finally {
    $capture.Dispose()
}
Copy-Item -LiteralPath $framePath -Destination $godotCapture -Force

$comparisonBitmap = New-Object System.Drawing.Bitmap(1500, 830)
$comparisonGraphics = [System.Drawing.Graphics]::FromImage($comparisonBitmap)
$comparisonGraphics.Clear([System.Drawing.Color]::FromArgb(24, 31, 40))
$comparisonGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$titleFont = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$sectionFont = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
try {
    $comparisonGraphics.DrawString("BLENDER PREVIEWS - LABELED FOUR-CHARACTER CONTACT SHEET", $sectionFont, $whiteBrush, 24, 18)
    $comparisonGraphics.DrawString("GODOT 4.7.2 - IMPORTED GLB LINEUP", $sectionFont, $whiteBrush, 735, 126)
    $comparisonGraphics.DrawString("Same four assets in Godot's Compatibility renderer", $titleFont, $whiteBrush, 24, 790)
    $blenderImage = [System.Drawing.Image]::FromFile($contactSheet)
    try { $comparisonGraphics.DrawImage($blenderImage, 24, 58, 680, 746) }
    finally { $blenderImage.Dispose() }
    $godotImage = [System.Drawing.Image]::FromFile($godotCapture)
    try { $comparisonGraphics.DrawImage($godotImage, 735, 170, 740, 416) }
    finally { $godotImage.Dispose() }
} finally {
    $whiteBrush.Dispose()
    $titleFont.Dispose()
    $sectionFont.Dispose()
    $comparisonGraphics.Dispose()
    $comparisonBitmap.Save($godotComparison, [System.Drawing.Imaging.ImageFormat]::Png)
    $comparisonBitmap.Dispose()
}
Write-Output "Godot $godotVersion validated all four assets and captured a nonblack lineup"
} finally {
    if (Test-Path -LiteralPath $temporaryProjectRoot -PathType Container) {
        $resolvedTemporaryProject = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $temporaryProjectRoot).Path)
        if (-not $resolvedTemporaryProject.StartsWith($temporaryRootFull, [StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path -Leaf $resolvedTemporaryProject).StartsWith("CasesGUI_HistoricalDelegate_GodotValidation_")) {
            throw "Refusing to remove a path outside the generated temporary Godot project: $resolvedTemporaryProject"
        }
        [System.IO.Directory]::Delete($resolvedTemporaryProject, $true)
    }
}

$afterHashes = [ordered]@{}
$hashReport = [System.Collections.Generic.List[string]]::new()
$hashReport.Add("Legacy asset integrity proof (SHA-256)")
$hashReport.Add("Created UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))")
foreach ($entry in $legacyFiles.GetEnumerator()) {
    $afterHashes[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash
    $unchanged = $beforeHashes[$entry.Key] -eq $afterHashes[$entry.Key]
    $hashReport.Add("$($entry.Key) before: $($beforeHashes[$entry.Key])")
    $hashReport.Add("$($entry.Key) after:  $($afterHashes[$entry.Key])")
    $hashReport.Add("$($entry.Key) unchanged: $unchanged")
    if (-not $unchanged) { throw "Legacy asset changed during variant-only generation: $($entry.Value)" }
}
$hashReport.Add("Contact sheet: $contactSheet")
$hashReport.Add("Godot version: $godotVersion")
$hashReport.Add("Godot capture: $godotCapture")
$hashReport.Add("Blender/Godot comparison: $godotComparison")
$hashReport | Set-Content -LiteralPath (Join-Path $variantRoot "legacy_sha256.txt") -Encoding utf8
Write-Output "Verified three legacy SHA-256 hashes; wrote labeled Blender/Godot sheets: $contactSheet and $godotComparison"
