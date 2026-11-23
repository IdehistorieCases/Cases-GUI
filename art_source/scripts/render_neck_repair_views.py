"""Render matching neck-review views from a saved CASES Blender scene.

Run with Blender 4.2+:
    blender -b --python art_source/scripts/render_neck_repair_views.py -- <scene.blend> <output-dir>
"""
import pathlib
import sys

import bpy
from mathutils import Vector


try:
    separator = sys.argv.index("--")
    blend_path = pathlib.Path(sys.argv[separator + 1]).resolve()
    output_dir = pathlib.Path(sys.argv[separator + 2]).resolve()
except (ValueError, IndexError):
    raise RuntimeError("Pass a saved Blender scene and output directory after --")

if not bpy.ops.wm.open_mainfile(filepath=str(blend_path)):
    raise RuntimeError(f"Could not open saved Blender scene: {blend_path}")

rig = next((obj for obj in bpy.data.objects if obj.type == "ARMATURE"), None)
camera = next((obj for obj in bpy.data.objects if obj.type == "CAMERA"), None)
if rig is None:
    raise RuntimeError("Saved Blender scene must contain the character rig")
if rig.animation_data is None:
    raise RuntimeError("Character rig has no animation data")
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next((action for action in bpy.data.actions if "Sitting_Idle_Loop" in action.name), None)
talking = next((action for action in bpy.data.actions if "Sitting_Talking_Loop" in action.name), None)
if idle is None or talking is None:
    raise RuntimeError("Could not find compatible seated idle and talking actions")

output_dir.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
if camera is None:
    bpy.ops.object.camera_add(location=(0.0, -3.4, 1.35))
    camera = bpy.context.object
    camera.name = "Neck comparison camera"
camera.data.lens = 50
scene.camera = camera
for name, location, energy, size, color in (
    ("Neck comparison key", (-2.2, -2.5, 3.3), 500, 3.0, (1.0, 0.89, 0.76)),
    ("Neck comparison fill", (2.6, -1.2, 2.0), 300, 2.5, (0.78, 0.86, 1.0)),
    ("Neck comparison rim", (0.0, 1.6, 2.8), 420, 2.0, (1.0, 0.94, 0.84)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (Vector((0.0, 0.25, 0.92)) - light.location).to_track_quat("-Z", "Y").to_euler()
if not any(obj.name == "Preview ground" for obj in bpy.data.objects):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, 0.0, -0.064))
    ground = bpy.context.object
    ground.name = "Preview ground"
    ground.dimensions = (6.0, 6.0, 0.09)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    material = bpy.data.materials.new("Neck comparison backdrop")
    material.diffuse_color = (0.40, 0.41, 0.40, 1.0)
    material.use_nodes = True
    material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.40, 0.41, 0.40, 1.0)
    ground.data.materials.append(material)
scene.world.color = (0.30, 0.30, 0.30)
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 48
scene.render.resolution_x = 1200
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

front = (0.0, -3.50, 1.32)
three_quarter = (1.52, -3.18, 1.62)
side = (3.55, 0.10, 1.30)
torso_target = (0.0, 0.29, 0.91)
views = [
    ("seated_idle_front.png", idle, 15, front, torso_target, 50),
    ("seated_idle_three_quarter.png", idle, 15, three_quarter, torso_target, 50),
    ("seated_idle_side.png", idle, 15, side, torso_target, 50),
    ("seated_talking_front.png", talking, 22, front, torso_target, 50),
    ("seated_talking_three_quarter.png", talking, 22, three_quarter, torso_target, 50),
    ("seated_talking_side.png", talking, 22, side, torso_target, 50),
    ("jacket_detail.png", idle, 15, (0.0, -2.16, 1.65), (0.0, 0.19, 1.36), 60),
]

for filename, action, frame, location, target, lens in views:
    camera.location = location
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = lens
    rig.animation_data.action = action
    scene.frame_set(frame)
    scene.render.filepath = str(output_dir / filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)
