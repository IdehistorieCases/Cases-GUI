# Suited Negotiator V2.1 geometry repair

Recorded 18 November 2026 on Windows with Blender 4.2.2 and Godot 4.7.2 stable. Run from the repository root with `.\build_and_validate.ps1`.

## Geometry changes

The Quaternius `SuperHero_Male` source and its 65-bone humanoid rig remain in use. The sleeve roots now extend 0.115 m under the jacket shell and widen across staged, bone-aligned rings. The cap is buried inside the torso, and shoulder weights blend from the clavicle into the upper arm before continuing across the elbow.

Body trimming no longer keeps polygons by broad face-center boxes. It identifies head geometry from the source `Head` vertex group, rejects the separate 230-face flared neck component, and retains the larger connected head surfaces. A tapered neck loft bridges the head and shirt collar with `neck_01`, `Head`, and `spine_03` weights. Its final height is scaled to 92% around its midpoint, shortening it by about 9 mm while preserving overlap at the head and collar. A shaped, skinned rear jacket yoke meets the collar and closes the open neckline edge.

Hand extraction now uses a plane derived from each lower-arm rest-pose bone, retaining the hand plus a short wrist overlap inside the cuff. Connected components under 50 faces are discarded to remove detached wrist fragments. Original hand vertex groups and skinning remain intact.

## Build and Godot validation

`build_and_validate.ps1` completed successfully after regenerating the Blender source, GLB, and previews.

- Blender 4.2.2 generated the editable `.blend`, exported the GLB, and rendered the full V2 preview set.
- Godot 4.7.2 imported a 65-bone skeleton with `SeatedIdle` and `SeatedTalking`.
- **40 skinned meshes / 40 weighted surfaces** passed valid-bone and normalized-weight checks.
- The validator sampled seven times in each animation. Both clips applied bone transforms and the character root remained fixed.
- Pelvis height was **0.583530 m** in both seated states.
- The Compatibility-renderer demo started without runtime errors and produced a nonblack **1152 x 648** Movie Maker frame at `art_source/output/v2/godot_engine_capture00000000.png`.

The full run transcript is `art_source/output/v2/build_validation_transcript.txt`; the Godot capture log is `art_source/output/v2/godot_capture.log`.

## Visual inspection

Blender regenerated front, three-quarter, and side idle views; front and three-quarter talking views; shoulder/cuff details; and talking frames 1, 10, 22, 30, 45, and 60. The shoulder, neckline, and wrist close-ups were reviewed alongside talking frames 22 and 30. The saved comparison uses the same cameras and animation frames for V2.0 and V2.1:

![V2.0 and V2.1 shoulder, neckline, cuff, and hand comparisons](../art_source/output/v2/geometry_repair_comparison.png)

The committed representative previews include the current contact sheet, front idle/talking views, both sleeve details, frames 22 and 30, and the before/after comparison. Run the generator or full build to refresh the other views. The Godot capture confirms the model renders in the target engine:

![Godot Compatibility-renderer capture](../art_source/output/v2/godot_engine_capture00000000.png)

## Remaining limitations

The sleeves now meet the jacket through the inspected idle and talking poses, though the low-poly shoulder silhouette is still somewhat rounded. The large source neck flaps and isolated pointed wrist pieces are absent in the reviewed frames. The neck loft now bends forward under the jaw to close the head-to-neck gap; its overlap was reviewed in Blender's idle and talking close-ups and the rebuilt model was imported into the Godot room preview. A narrow dark inner-collar seam remains at the shirt, and the three-piece suit and face are still stylized. The Godot frame shows the full chair and character at the existing demo camera distance, so Blender close-ups remain the more useful view for garment detail. These results cover the saved animation samples, not every interpolated frame.

## V3 original delegate personas

Recorded 18 November 2026 on Windows with Blender 4.2.2 and Godot 4.7.2 stable. The variant-only command is `.\build_variants.ps1`; it was run from the feature worktree and does not call `build_and_validate.ps1`.

### Build and integrity

- Blender generated separate GLBs and editable `.blend` files for `senior_mediator`, `younger_envoy`, and `scholarly_delegate`. Each received ten 1200×1200 Blender views, including idle front/three-quarter/side, talking, frames 22 and 30, both sleeve details, jacket, and face.
- The senior mediator uses overlapping, skinned double-breasted front panels and two button columns. The younger envoy uses a slimmer blue single-breasted profile; the scholarly delegate has an olive suit and neat beard. All three are original archetypes with distinct face/build/style settings, not historical portraits.
- All 14 persona unit tests pass. Input preflight tests cover finite/bounded and missing dimensions, unknown hairstyle/facial-hair/suit-style values, unknown keys, missing palette fields, and malformed or out-of-range RGB colors. All profiles resolve through the shared face-point transform for the head and its attached features.
- The labeled four-character Blender sheet is `art_source/output/v3/four_character_contact_sheet.png`. The engine view and Blender/Godot comparison are `art_source/output/v3/godot_variant_lineup.png` and `art_source/output/v3/four_character_blender_godot_comparison.png`.
- The Godot capture is 1152×648, rendered with OpenGL 3.3 Compatibility on an NVIDIA RTX 3060. The comparison shows the imported GLBs side by side with Blender previews; Godot's framing and lighting are not pixel-identical to Blender.
- A fresh temporary Godot project imported all four GLBs. Per-character state and failure counters reset for each model. Each asset exposed 65 bones, both seated clips, 39–45 skinned meshes, and all mesh surfaces had valid bones and normalized weights. Each clip sampled seven times and individually changed all 11 required bones (`Head`, `neck_01`, `spine_03`, both clavicles, upper arms, lower arms, and hands). The character root remained fixed, and pelvis height was 0.583530 m in both seated clips. Result: four assets, zero validation failures. The unchanged single-character demo also loaded both animations.
- `art_source/output/v3/legacy_sha256.txt` records matching before/after SHA-256 values for the Quaternius source GLB, the original Blender `.blend`, and the original Godot GLB. All three are unchanged.

### Visual review and remaining defects

The labeled Blender contact sheet and Godot import comparison were inspected alongside both animation frames and garment/face close-ups. The four suits and head treatments are distinguishable, and the engine import shows all four animated assets. The previews still show the base model's stylized low-poly anatomy: shoulders remain somewhat broad and rounded, the senior's double-breasted front reads plate-like, and a thin dark seam remains around the neck/collar. The collar, shirt, and tie also look crowded in close-up; hand/cuff transitions, facial details, and hair/beard silhouettes remain blunt and stylized. These are visible appearance limitations, not failed rig/import checks. The talking samples cover frames 22 and 30 plus the validator's seven evenly spaced samples, not every interpolated frame.

![Clearly labeled four-character Blender comparison](../art_source/output/v3/four_character_contact_sheet.png)

![Blender and Godot imported character comparison](../art_source/output/v3/four_character_blender_godot_comparison.png)

## Variant reproduction

From the repository root, run `.\build_variants.ps1` to rebuild only the three variants, render their previews, import and validate all four characters in a disposable Godot project, capture the engine lineup, and verify the three legacy hashes. It accepts `-BlenderPath` / `-GodotPath`, or `BLENDER_EXE` / `GODOT_EXE`. Run `python -m unittest art_source.tests.test_persona_presets -v` for the data and input-validation tests. Use the older `.\build_and_validate.ps1` only when intentionally rebuilding the legacy default character.

## V2 reproduction

From the repository root, run `.\build_and_validate.ps1`. It locates Blender and Godot through command-line parameters, environment variables, `PATH`, or documented Windows defaults; regenerates the character; imports it into Godot; runs `godot/tests/validate_suit.gd`; starts the demo; and captures a Compatibility-renderer PNG.
