# Historical Delegate Archetypes — Design

## Intent

Keep the current negotiator and add three visually distinct, reusable seated delegates, for four characters total. Their different faces, builds, and suits should make them readable as separate delegates while preserving the current Quaternius 65-bone rig and seated animation compatibility.

## Proposed set

The three new characters are original, early-20th-century diplomatic archetypes, not portraits of named people. The existing negotiator remains unchanged as the default:

- **Senior mediator:** stockier build, broader jaw, receding silver hair and clean-shaven; charcoal double-breasted suit with a muted green waistcoat.
- **Younger envoy:** lean build, narrow face, dark side-parted hair, clean-shaven; deep blue suit with a restrained copper tie.
- **Scholarly delegate:** average build, fuller cheeks, short wavy hair and neat beard; dark olive suit with a warm ivory waistcoat.

Use these as starting identities; keep all features stylized and avoid claiming likeness to actual historical people.

## Approaches

1. **Procedural identity presets on the current base and rig — selected.** Add per-persona body and face adjustments, hair/facial-hair choices, and garment/material settings, then export separate assets. This reuses the installed animation library and retains the proven rig. Facial changes remain stylized and limited by the shared source head.
2. **Bring in separate base characters.** This could create stronger anatomical variety, but the repository contains only one base character mesh. New assets would require source/license review and rig adaptation, increasing animation risk.
3. **Color-only suit variants.** This is inexpensive but does not meet the request for different faces and builds.

## Scope and constraints

- Preserve the source character, bone names, 65-bone skeleton, `SeatedIdle`, and `SeatedTalking`.
- Keep the existing single-character GLB and Blender source unchanged as the default; generate three named variants as separate assets so current consumers continue working.
- Make the generator select a persona deterministically and write variant outputs without overwriting another variant.
- Keep body adjustments as localized, armature-safe shape changes; do not uniformly scale the whole character.
- Validate each output for Godot import, skeleton, animations, valid normalized skin weights, and stable seated pelvis/root.
- Produce same-camera Blender previews for all three variants and a comparison sheet that includes the existing default plus all three. Inspect front and three-quarter seated poses, including a talking sample.
- Keep the existing demo single-seat and do not add gameplay, a runtime roster, dialogue, or new animations in this iteration.

## Artifacts

- Reusable persona presets in the existing Blender generator.
- Three editable Blender files and three Godot-compatible skinned GLBs under variant-specific paths, in addition to the unchanged default asset.
- Individual preview renders for each variant and a four-character comparison sheet under `art_source/output/v3/`.
- Targeted build/validation updates and a short record of visual and technical results.

## Acceptance

At a glance, each new variant differs from the default and from the other two in face/hair, fitted body silhouette, and suit. All four retain recognizable facial detail and tailored proportions, deform through the seated idle and talking clips, and import and animate in Godot.

## Decisions left to the builder

Choose exact numeric dimensions and colors through render iteration; choose the simplest isolated output layout; document any face details limited by the source mesh. No named-person likenesses or additional source assets are planned.
