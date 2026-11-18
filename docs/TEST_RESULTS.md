# Suited Negotiator V2 — Build and visual review

Recorded 18 November 2026 on Windows with Blender 4.2.2 and Godot 4.7.2 stable.

## Build and Godot validation

`build_and_validate.ps1` completed successfully from the repository root. It generated the editable Blender scene and Godot GLB, rendered the requested PNG set, imported the GLB into Godot, ran the validation script, and started the Compatibility-renderer demo headlessly.

- Blender exported `cases_suited_negotiator.glb` with `SeatedIdle` and `SeatedTalking`.
- Godot imported a 65-bone skeleton with the expected humanoid bone names and both animation clips.
- All **32** character/garment skinned meshes use the shared skeleton. All **32** weighted surfaces have normalized weights and valid bone indices.
- The validator sampled seven points in each animation, including both endpoints. Both clips applied bone motion, and the model root stayed fixed.
- Pelvis height was **0.583530 m** in both clips at the comparison sample.
- Sleeve, cuff, trouser, and shoe dimensions passed the proportion guards.
- The headless demo started and reported both clips without runtime errors.

The validator is at `godot/tests/validate_suit.gd`. To reproduce the full build, run `.\build_and_validate.ps1` from the repository root. Blender/Godot paths can be set with command-line parameters or `BLENDER_EXE` / `GODOT_EXE`.

## Blender renders inspected

The generator rendered the eight required 1200×1200 views under `art_source/output/v2/`, created a contact sheet, and rendered six talking samples at frames 1, 10, 22, 30, 45, and 60. The before set is preserved in `art_source/output/v2/before/`.

The idle and talking renders show a narrower torso, shaped jacket profile, tapered bone-aligned sleeves and trousers, smaller shoes, and wrists that emerge through fitted cuffs. The sleeve cross-sections follow the rest-pose shoulder, elbow, forearm, and wrist directions. The observed talking samples keep the hands visually connected to the cuffs.

### Before / after talking pose

![Before V2 talking pose](../art_source/output/v2/before/seated_talking.png)

![After V2 talking pose](../art_source/output/v2/seated_talking_three_quarter.png)

## Known limitations

- The available Quaternius base package contains `SuperHero_Male` but no average-build male replacement. The generator keeps its compatible skeleton and source mesh; the retained visible skin is limited to the head/neck and hands while suit parameters define the visible torso and limb silhouette. An editable corrective shape key is also retained on the source mesh.
- The character remains stylized low-poly. The dark inner jacket arc at the neckline is still visible in close-ups; shoulder transitions, angular lapel faces, face/hair, and dress-shoe details are simplified and could use further art-direction.
- Blender Eevee is the source of visual screenshots. A Godot GUI capture was attempted, but the window rendered black in this environment. Godot import, animation, and headless Compatibility-renderer runtime are validated; Godot visual appearance is not.
- The validator and Blender review cover seven animation samples and six rendered talking frames. They do not prove collision-free deformation at every interpolated time or across other animation packs/body types.
