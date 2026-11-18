# Versailles room layout

## Design intent

A reusable, character-free formal diplomatic room in the project's 1 unit = 1 metre scale, using dark wood paneling, parquet, warm plaster, muted brass and an imported lantern chandelier. The room is a restrained period-inspired composition; it is not a reconstruction of a specific Versailles chamber. No flags, maps, portraits, or historical claims are added because the candidate references could not be verified.

## Dimensions and views

- Interior footprint: 8.4 m × 8.4 m, with a 4.2 m ceiling.
- Central round table: scale the reviewed 1.4 m table to about 2.45 m diameter while keeping its top near 0.85 m, leaving open tabletop space.
- Shell: dark wood wainscoting to 1.3 m, warm cream upper wall, tall rear windows with wood mullions and muted blue-grey glazing, and a centered double-door opening at the entry wall.
- The wall shell, door leaves, window trim, and simplified pleated drape panels are custom box geometry. The drapes are intentionally simple visual placeholders; the unavailable architecture and curtain candidates were not substituted with unverified downloaded assets.
- Lighting: one warm directional source with soft ambient fill and one low-energy chandelier light; the scene remains within Godot's GL Compatibility renderer.
- Interior overview: preview camera near (2.4, 2.0, 3.0), just inside the entry doors and looking diagonally across the table toward the rear windows and lantern.
- Negotiation camera reference: preserve the existing demo camera offset of (1.8, 1.5, 2.85) and 43° FOV as a reference only. The main project has no Versailles negotiation camera or level to integrate with.
- `ParticipantSeatAnchor_Template`: one empty marker at the west side of the table, facing toward the centre. It is an authoring template, not a one-seat scenario. Duplicate it only after a real participant layout is added.

## Furniture and asset use

- Use Round Wooden Table 01 at the centre and keep the document props small and to the centre of its surface.
- Use Vintage Wooden Drawer 01 against one side wall as a low storage cabinet.
- Use Lantern Chandelier 01 centered under the ceiling.
- Use Dark Paneled Wood on lower wall panels and Diagonal Parquet on the floor.
- Do not place Green Chair 01 or Arm Chair 01 as room furniture: the current seated negotiator asset already includes a chair, and the repository has no participant count or seat layout. The scene exposes a marker template without embedding characters or chair duplication.
- Exclude Vintage Cabinet 01 from runtime because of its 61k triangle count. Exclude the modern stationery, supplied landscape image, unverified flags/maps/art, and inaccessible Sketchfab sources.

## Scope and integration

`godot/scenes/versailles_room.tscn` is a standalone reusable environment. It does not replace `res://scenes/seated_suit_demo.tscn`, which remains the project main scene. There is no existing Versailles level or browser-export preset in this repository, so this environment cannot be integrated into a scenario without a later scene-loading decision. The scene uses no character meshes, rig, animations, dialogue, AI, negotiation logic, or collision/navigation systems.

The comparison project under `assets/versailles/` is outside the main game project. Only the CC0 assets selected in `docs/ASSET_LICENSES.md` are copied to the main project's `godot/assets/versailles/optimized/` area.
