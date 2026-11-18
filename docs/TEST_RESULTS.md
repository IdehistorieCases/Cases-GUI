# Suited Negotiator V2.1 geometry repair

Recorded 18 November 2026 on Windows with Blender 4.2.2 and Godot 4.7.2 stable. Run from the repository root with `.\build_and_validate.ps1`.

## Geometry changes

The Quaternius `SuperHero_Male` source and its 65-bone humanoid rig remain in use. The sleeve roots now extend 0.115 m under the jacket shell and widen across staged, bone-aligned rings. The cap is buried inside the torso, and shoulder weights blend from the clavicle into the upper arm before continuing across the elbow.

Body trimming no longer keeps polygons by broad face-center boxes. It identifies head geometry from the source `Head` vertex group, rejects the separate 230-face flared neck component, and retains the larger connected head surfaces. A tapered neck loft bridges the head and shirt collar with `neck_01`, `Head`, and `spine_03` weights. A shaped, skinned rear jacket yoke meets the collar and closes the open neckline edge.

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

The sleeves now meet the jacket through the inspected idle and talking poses, though the low-poly shoulder silhouette is still somewhat rounded. The large source neck flaps and isolated pointed wrist pieces are absent in the reviewed frames. A narrow dark inner-collar seam and a visible low-poly transition at the back of the neck remain; the three-piece suit and face are still stylized. The Godot frame shows the full chair and character at the existing demo camera distance, so Blender close-ups remain the more useful view for garment detail. These results cover the saved animation samples, not every interpolated frame.

## Reproduction

From the repository root, run `.\build_and_validate.ps1`. It locates Blender and Godot through command-line parameters, environment variables, `PATH`, or documented Windows defaults; regenerates the character; imports it into Godot; runs `godot/tests/validate_suit.gd`; starts the demo; and captures a Compatibility-renderer PNG.
