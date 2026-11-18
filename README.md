# CASES-GUI — Suited Negotiator V2

CASES is an educational 3D negotiation game. This repository contains the Godot 4 character prototype and its reproducible Blender asset pipeline. The separate FastAPI backend and Local-AI-API-LITE are not part of this repository.

## Character pipeline

The V2 generator keeps the vendored Quaternius humanoid and its compatible 65-bone skeleton. The supplied Universal Base Character file contains the `SuperHero_Male` mesh, but no regular male alternative. It adds an editable `CASES average-build correction` shape key to the source mesh; the exported visible skin is limited to the head/neck and hands, while configurable garment profiles define the slimmer visible silhouette.

Garments are generated in Blender from reusable meter-scale parameters in `PRESET` in [build_suited_negotiator.py](art_source/scripts/build_suited_negotiator.py). The torso uses a profiled jacket shell, separate shirt and waistcoat panels, a fitted collar and tie, and surface-conforming notched lapels. Sleeve rings use the upper-arm, elbow, and wrist rest-pose joints to define their centers and local cross-sections. Vertex weights blend across the upper arm, elbow, lower arm, and hand. Fitted shirt cuffs sit inside the jacket sleeves and follow the wrist bones. Trouser rings follow thigh, knee, and calf bones, and low-profile leather dress shoes follow each foot bone. The generator normalizes weights and rejects missing bone names.

Blender produces an editable `.blend`, a Godot-ready skinned GLB, eight 1200×1200 preview renders, and six talking-animation frame samples. The build script combines the requested views into contact sheets, preserves a same-camera before/after talking comparison, runs Godot import, animation, skin-binding, and proportion checks, and captures a Compatibility-renderer frame with Godot Movie Maker.

Persona data lives in the Blender-independent [persona_presets.py](art_source/scripts/persona_presets.py) module. The `senior_mediator`, `younger_envoy`, and `scholarly_delegate` presets reuse the same Quaternius 65-bone skeleton and `SeatedIdle` / `SeatedTalking` clips while varying face shape, build, hair, facial hair, palette, and suit construction. They are original period archetypes, not portraits of specific historical people; the Godot demo remains a single character and does not add gameplay roster behavior.

Every persona profile is validated before the generator edits the Blender scene or creates output directories. Validation checks finite, bounded dimensions, known hairstyle and facial-hair values, known suit styles, and RGB triples with channels in `[0, 1]`. Garment-fit offsets are explicit meter-scale parameters: the shared profile sets 4 mm body clearance, 28 mm jacket-armhole overlap, 12 mm cuff overlap, 4 mm waistcoat clearance, 2 mm shirt clearance, 4 mm trouser clearance, and 6 mm shoe-to-foot overlap. Jacket and sleeve geometry uses the same values while retaining the established bone-aligned skinning.

Face shape is applied through one `transform_face_point()` mapping shared by the head surface and attached hair, eye, brow, pupil, and facial-hair landmarks. The senior mediator uses two overlapping, skinned jacket fronts with two columns of buttons for a double-breasted construction.

## Open the demo

Project directory: `D:\projects\Cases-GUI\godot`

Open `godot/project.godot` in Godot 4.7.2 and run the main scene.

- `1`: seated idle
- `2`: seated talking
- `3`: pause or resume

The demo remains a single seated actor and chair. It does not include multi-participant placement, backend integration, or dialogue systems.

## Rebuild and validate

From the repository root, run:

```powershell
.\build_and_validate.ps1
```

The script discovers Blender and Godot on `PATH`, then falls back to documented Windows defaults. You can override them with `-BlenderPath` and `-GodotPath`, or set `BLENDER_EXE` and `GODOT_EXE`.

The build runs the Blender generator, checks generated assets and all required preview dimensions, creates the contact sheets, imports the GLB in Godot, runs `godot/tests/validate_suit.gd`, starts the demo headlessly, and saves `godot_engine_capture00000000.png`. It returns a nonzero status if any required step fails.

To open the demo directly in Godot after generation:

```powershell
& 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path godot
```

The main previews and talking samples are under `art_source/output/v2/`. The original V2 baseline is preserved under `art_source/output/v2/before/`, and the state before this refinement pass is under `art_source/output/v2/pre_refinement/`. Previous and current validation notes are in [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md).

### Build the three additional personas only

Run this separate path from the repository root:

```powershell
.\build_variants.ps1
```

It creates each named variant GLB under `godot/assets/characters/` and its editable `.blend` plus 1200×1200 preview set under `art_source/output/v3/<persona>/`. It imports and validates copies in a temporary Godot project, captures the four-character engine lineup, and produces labeled Blender and Blender/Godot comparison sheets. It does not invoke the legacy default build or write to the default `.blend`, default GLB, or V2 renders. `art_source/output/v3/legacy_sha256.txt` records before/after SHA-256 hashes for the vendored source, default `.blend`, and default GLB. Set `BLENDER_EXE` / `GODOT_EXE` or pass `-BlenderPath` / `-GodotPath` to choose executables.

The generated comparison sheets are reviewed in [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md). Remaining visual limitations are recorded there rather than treating import success as a visual-quality pass.

## V2 visual review

![Seated idle front](art_source/output/v2/seated_idle_front.png)

![Seated talking front](art_source/output/v2/seated_talking_front.png)

![V2 comparison contact sheet](art_source/output/v2/comparison_contact_sheet.png)

![Before and after talking-frame comparison](art_source/output/v2/before_after_talking_comparison.png)

![Godot Compatibility-renderer capture](art_source/output/v2/godot_engine_capture00000000.png)

## Asset provenance and limitations

The base character and two seated actions remain Quaternius-derived GLBs. License notices and the exact redistributions are recorded in [docs/ASSET_PROVENANCE.md](docs/ASSET_PROVENANCE.md). No third-party suit geometry has been added.

This is a polished stylized low-poly character rather than a photoreal historical portrait. Facial features, lapel folds, and shoe forms remain deliberately simple. The current build validates the idle and talking loops at sampled times; it does not claim exhaustive collision-free results for every possible pose.
