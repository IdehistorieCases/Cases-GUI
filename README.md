# CASES Client — Seated Negotiator Milestone

Independent Godot 4 + Blender prototype for the CASES educational negotiation game. The FastAPI backend and Local-AI-API-LITE are intentionally not included.

## Implemented

- Quaternius Universal Base **Superhero Male** with its original 65-bone humanoid armature
- Procedurally constructed three-piece suit: midnight jacket, charcoal waistcoat, dress shirt with tie, navy trousers, shirt cuffs, shoes, hair, and mustache
- Clothing attached to the Quaternius bones via skinned mesh vertex groups
- A simple modeled and upholstered meeting chair positioned beneath the seated character
- SeatedIdle and SeatedTalking loops taken from the compatible Quaternius Universal Animation Library
- A Godot 4.7.2 Compatibility renderer demo scene
- Scripted Godot validation of animation and skeleton imports
- Editable Blender .blend and two visual previews

## Open the demo on Marcus_Computer

Project directory: `D:\projects\cases-client\godot`

Open `project.godot` in Godot 4.7.2. Press **F6/F5** to run the demo.

- `1`: seated idle
- `2`: seated talking
- `3`: pause/resume playback

The model is currently a single actor and chair. Multi-participant placement is a **separate next milestone**.

## Rebuild the character

Requires Blender 4.2 or newer and the two source GLBs under `art_source/vendor/quaternius/`.

From the repository root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' -b --python art_source/scripts/build_suited_negotiator.py
```

Outputs:
- `godot/assets/characters/cases_suited_negotiator.glb` — game-ready model with two animation clips
- `art_source/output/cases_suited_negotiator.blend` — editable Blender model
- `art_source/output/seated_idle.png`
- `art_source/output/seated_talking.png`

The generator uses only Blender's built-in Python API (bpy/bmesh). No third-party Blender extension is required.

## Godot automated checks

```powershell
$g = 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --editor --import --path godot
& $g --headless --path godot --script res://tests/validate_suit.gd
& $g --headless --path godot --quit-after 5
```

## Scope and known limitations

This is a **technical proof of concept**, not a final historically accurate character. The silhouette and clothing materials are intentionally simplified; shoulders, cuffs, lapel folds, facial hair, seat fit, and fabric shading still require artistic cleanup. Only two animations were imported. There is no player camera system, voice sync, multiplayer, AI dialogue integration, or browser export verification yet.

The Quaternius character and animation files are third-party assets. See `docs/ASSET_PROVENANCE.md` and the license files in `art_source/vendor/quaternius/`. Asset provenance must be checked again before public redistribution.

## Directory overview

```
art_source/
  scripts/build_suited_negotiator.py
  vendor/quaternius/
  output/*.blend + preview PNGs
godot/
  project.godot
  scenes/seated_suit_demo.tscn
  scripts/seated_suit_demo.gd
  tests/validate_suit.gd
  assets/characters/cases_suited_negotiator.glb
docs/
  ASSET_PROVENANCE.md
  TEST_RESULTS.md
```
