# Historical Delegate Archetypes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task, then request one whole-branch review.

**Goal:** Preserve the current negotiator and add three visually distinct, reusable, animation-compatible period archetypes.

**Architecture:** Keep the monolithic Blender generator and 65-bone Quaternius source rig. Put persona configuration, safe merge logic, output-path logic, and face-landmark transforms in a small pure-Python helper so they can be tested without importing Blender. Invoke the generator once per new persona and isolate each variant's `.blend`, GLB, and renders; the build orchestrator validates the existing default without overwriting it. Extend the Godot validator to check all four assets while leaving the demo pointed at the unchanged default.

**Tech Stack:** Python 3 standard library, Blender 4.2.2 Python API, PowerShell, Godot 4.7.2 and GDScript, System.Drawing contact-sheet generation.

**Spec:** `docs/superpowers/specs/2026-11-18-historical-delegate-archetypes-design.md`

## Global Constraints

- Preserve the source character, bone names, 65-bone skeleton, `SeatedIdle`, and `SeatedTalking`.
- Keep the existing single-character GLB and Blender source unchanged as the default; generate three named variants as separate assets so current consumers continue working.
- Make the generator select a persona deterministically and write variant outputs without overwriting another variant.
- Keep body adjustments as localized, armature-safe shape changes; do not uniformly scale the whole character.
- Validate each output for Godot import, skeleton, animations, valid normalized skin weights, and stable seated pelvis/root.
- Produce same-camera Blender previews for all three variants and a comparison sheet that includes the existing default plus all three.
- Keep the existing demo single-seat and do not add gameplay, a runtime roster, dialogue, or new animations in this iteration.

## Review Focus

- **Unknown persona id:** reject before deleting the current Blender scene or touching outputs. Test `resolve_persona()` with an unknown id and assert a clear `ValueError`.
- **Default asset compatibility:** no-argument generation must preserve the current output filenames and selected default preset; the multi-variant orchestrator must leave the existing default files untouched. Test default resolution and compare default-file hashes before and after the orchestrated build.
- **Variant file collisions:** each persona must get a distinct GLB, blend, and render directory. Test the output-stem helper across all three keys and require distinct paths in the build script.
- **Face landmark drift:** eye, brow, hairline, and facial-hair placement must follow face-shape changes. Inspect same-camera head close-ups for each generated persona and revise until landmarks sit on the face.
- **Animation deformation:** all four models must retain valid weights and stable pelvis/root transforms at sampled idle/talking times. Run the expanded Godot validator on every output and inspect talking frame 22/30 renders.

---

### Task 1: Add tested persona configuration

**Files:**
- Create: `art_source/scripts/persona_presets.py`
- Create: `art_source/tests/test_persona_presets.py`
- Modify: `art_source/scripts/build_suited_negotiator.py`

**Interfaces:**
- `resolve_persona(persona_id: str, base_preset: dict) -> dict`: returns a deep-merged preset without mutating `base_preset`; accepts `default`, `senior_mediator`, `younger_envoy`, and `scholarly_delegate`; raises `ValueError` for any other key.
- `variant_output_paths(repo_root: pathlib.Path, persona_id: str) -> dict[str, pathlib.Path]`: returns unique GLB, blend, and render paths for one new persona; rejects `default` so the helper cannot redirect legacy outputs.
- `PERSONA_OVERRIDES: dict[str, dict]`: identity, face, body, and palette/garment overrides for the three added personas.
- `PERSONA_OVERRIDES: dict[str, dict]`: identity, face, body, and palette/garment overrides for the three added personas.

- [ ] **Step 1: Write standard-library unit tests** for default no-mutation, nested override merge, all required persona keys, distinct output paths, and unknown-id rejection.
- [ ] **Step 2: Run `python -m unittest art_source.tests.test_persona_presets -v`** and confirm the new API tests fail because the helper does not yet exist.
- [ ] **Step 3: Implement the helper and persona metadata** in `persona_presets.py`; keep numeric appearance tuning in the persona dictionaries.
- [ ] **Step 4: Run the unit tests** and verify unknown ids are rejected before the generator can use a path or preset.
- [ ] **Step 6: Commit** as `feat: add delegate persona presets`.

### Task 2: Generate distinct faces, builds, and suits

**Files:**
- Modify: `art_source/scripts/build_suited_negotiator.py`
- Modify: `art_source/scripts/persona_presets.py`
- Modify: `art_source/tests/test_persona_presets.py`

**Interfaces:**
- `fit_base_proportions()` consumes the active `body` and `face` preset sections and writes a localized corrective shape key while retaining source vertex groups.
- `transform_face_point(point: tuple[float, float, float], face_profile: dict) -> tuple[float, float, float]` maps facial landmarks to the active face profile for attached eyes and facial-hair geometry.
- `make_hair_and_face()` consumes `identity.hair_style`, `identity.facial_hair`, and palette settings; all added pieces use `Head` weights.

- [ ] **Step 1: Add failing landmark-transform tests** for a no-op profile and for wider/narrower jaw profiles at fixed eye and chin coordinates.
- [ ] **Step 2: Run the unit tests** and confirm the new transform API is missing.
- [ ] **Step 3: Implement `transform_face_point()`** as pure coordinate mapping; verify the new tests pass.
- [ ] **Step 4: Add localized face and body parameters** for the stockier senior mediator, lean younger envoy, and average-build scholarly delegate; preserve unchanged default settings and source weights.
- [ ] **Step 5: Apply the face profile consistently** to source head shape, eyes/brows, scalp/hair silhouette, and optional facial hair. Keep generated facial pieces skinned to `Head`.
- [ ] **Step 6: Apply each jacket, waistcoat, shirt, tie, trouser, and leather palette** through the existing material and garment functions; avoid per-function color constants.
- [ ] **Step 7: Run unit tests and generate each persona in Blender**; inspect same-camera idle front/three-quarter and talking frame 22 images. Refine any duplicate silhouette, facial floating, or garment intersection before proceeding.
- [ ] **Step 8: Commit** as `feat: build distinct negotiator appearances`.

### Task 3: Isolate variant exports and previews

**Files:**
- Modify: `art_source/scripts/build_suited_negotiator.py`
- Modify: `build_and_validate.ps1`
- Create: `art_source/output/v3/<persona>/` generated previews and `.blend` files
- Create: `godot/assets/characters/cases_suited_negotiator_<persona>.glb`

**Interfaces:**
- Default persona outputs remain `godot/assets/characters/cases_suited_negotiator.glb` and `art_source/output/cases_suited_negotiator.blend`.
- New persona exports use `cases_suited_negotiator_<persona>.glb` and separate `art_source/output/v3/<persona>/` folders.
- Each variant preview folder contains 1200×1200 idle front, idle three-quarter, talking front (frame 22), and head/suit detail renders.

- [ ] **Step 1: Add `--persona <id>` parsing** in the Blender generator; resolve configuration and unique output paths before deleting the scene, while no argument preserves the legacy default route.
- [ ] **Step 2: Route each variant's GLB, blend, and render destinations** through `variant_output_paths()`; default V2 render paths and model files remain separate.
- [ ] **Step 3: Extend `build_and_validate.ps1`** to invoke Blender once for each new persona only, verify that the existing default GLB/blend are present without overwriting them, and check fresh nonempty variant outputs.
- [ ] **Step 4: Render four same-camera views per variant** and validate each render's dimensions; create `art_source/output/v3/four_character_contact_sheet.png` from the default and three new idle-front views using `System.Drawing`.
- [ ] **Step 5: Run the generation stage** and compare default file hashes before and after; confirm all four characters appear in the sheet and no output paths collide.
- [ ] **Step 6: Commit** as `build: export delegate variants and previews`.

### Task 4: Validate every asset in Godot

**Files:**
- Modify: `godot/tests/validate_suit.gd`
- Modify: `build_and_validate.ps1`

**Interfaces:**
- `CHARACTER_PATHS` contains the default scene and all three variant scene paths.
- `validate_character(path: String) -> void` runs the existing skeleton, mesh binding, normalized-weight, animation, root, and pelvis checks for one imported PackedScene.

- [ ] **Step 1: Add a build-script output assertion** requiring the Godot validator to report `CASES validated character assets: 4`; run the existing validator and confirm this assertion fails while it only checks the default.
- [ ] **Step 2: Add the four exact GLB resource paths** to `CHARACTER_PATHS` in `validate_suit.gd` and implement `validate_character(path: String) -> void` by moving the current per-character checks into one function.
- [ ] **Step 3: Run seven samples for both clips on each character**; include the path in failures and print `CASES validated character assets: 4` after all checks pass.
- [ ] **Step 4: Run the Godot validator** and confirm all four assets retain 65 bones, valid normalized skin weights, animated arm/hand/leg bones, fixed roots, and consistent seated pelvis placement.
- [ ] **Step 5: Commit** as `test: validate all negotiator variants in Godot`.

### Task 5: Record results and deliver the variants

**Files:**
- Modify: `README.md`
- Modify: `docs/TEST_RESULTS.md`
- Create: `art_source/output/v3/four_character_contact_sheet.png`
- Modify: pull request #1 description after successful validation

- [ ] **Step 1: Update the README** with persona-generation commands, output paths, and a note that the demo still loads the original default.
- [ ] **Step 2: Run `python -m unittest art_source.tests.test_persona_presets -v`** and then `.\build_and_validate.ps1`; record Blender/Godot versions, four-asset checks, and any visible defects in `docs/TEST_RESULTS.md`.
- [ ] **Step 3: Inspect all individual previews and the four-character sheet**; verify the three new characters read differently from the default in face/hair, build, and suit. Review idle, talking, frame 22, frame 30, and close-ups; revise and rebuild if defects remain.
- [ ] **Step 4: Verify the Godot capture is nonblack** and that the unchanged demo still loads the original character.
- [ ] **Step 5: Commit** as `docs: record delegate variant results`, push `codex/suited-negotiator-v2`, and update PR #1 with the sheet and test summary; leave the PR unmerged.

## Plan Self-Review

- **Spec coverage:** four total assets and unchanged default are covered in Tasks 1/3/4; face/build/suit variety and same-camera review in Task 2/3/5; rig, animation, weights, pelvis/root, Godot import in Task 4; documentation and PR delivery in Task 5.
- **Step scan:** each task has a focused API or artifact, a failing check before its implementation, a verification command or visual review, and a commit.
- **Type consistency:** config merge consumes `dict`; the generator owns CLI parsing and export paths; the Godot validator accepts `String` resource paths.
- **Review focus:** all five failure classes above have an explicit test or visual inspection.
- **Proportion:** five tasks follow the existing single-file pipeline and add only a testable config helper, isolated outputs, and per-asset validation; no runtime roster or new model source is introduced.
