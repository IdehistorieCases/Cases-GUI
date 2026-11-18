# Milestone validation — 17 November 2026

## Tests actually performed

- Blender 4.2.2 LTS headless imported the Quaternius free base character and animation library.
- The base and animation armatures each had **65 bones** and matching bone naming.
- The seated idle action produced a seated pelvis near z=0.584 m; seated talking held the pelvis at the same location with arm gestures.
- Blender generated procedural jacket, trousers, waistcoat, shirt, cuffs and shoes, preserving weights to the Quaternius rig.
- GLB exported successfully with **two animation clips**.
- Blender rendered two still previews for visual checks.
- Godot 4.7.2 stable's Compatibility renderer imported the generated GLB.
- Godot test loaded **65 bones** and the two animation names `SeatedIdle`, `SeatedTalking`, and applied both successfully.

## Not yet proven

- Web browser export and performance on school laptops.
- Visual quality inside Godot's interactive renderer (the visual previews are from Blender Eevee).
- Historical garment accuracy, high-quality tailoring, robust collision avoidance across ALL animation frames.
- Repeatable generation for additional Quaternius body types.
- Different NPC instances and backend integration.

The initial procedural generator was revised after render inspections showed broken sleeve/torso silhouettes. The current final render is a basic recognizable stylized three-piece suit rather than a polished production character.
