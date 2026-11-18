# Blender 4.2 emits a harmless TBBmalloc warning on stderr under Windows PowerShell 5.
# Do not treat native-program stderr as a terminating PowerShell exception.
# Check each executable's actual exit code instead.
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$blender = "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"
$godot = "D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $blender)) { throw "Blender 4.2 not found: $blender" }
if (-not (Test-Path $godot)) { throw "Godot 4.7.2 not found: $godot" }
& $blender -b --python (Join-Path $repo "art_source\scripts\build_suited_negotiator.py")
if ($LASTEXITCODE -ne 0) { throw "Blender build failed" }
& $godot --headless --editor --import --path (Join-Path $repo "godot")
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
& $godot --headless --path (Join-Path $repo "godot") --script res://tests/validate_suit.gd
if ($LASTEXITCODE -ne 0) { throw "Godot validation failed" }
Write-Output "CASES three-piece suit milestone PASS"
