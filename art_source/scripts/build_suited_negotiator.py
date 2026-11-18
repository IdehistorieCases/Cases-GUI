"""Build the CASES seated negotiator and tailored suit from local Quaternius assets.

Run from any working directory with Blender 4.2+:
    blender -b --python art_source/scripts/build_suited_negotiator.py

The generator deliberately keeps the original 65-bone Quaternius rig. Garment
profiles are controlled in PRESET; sleeve and trouser rings are derived from
the rest-pose bones rather than world-space cylinders.
"""
import bpy
import bmesh
import math
import pathlib
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_source" / "vendor" / "quaternius"
OUTPUT = ROOT / "art_source" / "output"
V2_OUTPUT = OUTPUT / "v2"
GODOT = ROOT / "godot" / "assets" / "characters"
OUTPUT.mkdir(parents=True, exist_ok=True)
V2_OUTPUT.mkdir(parents=True, exist_ok=True)
GODOT.mkdir(parents=True, exist_ok=True)

# One polished, reusable starting point. Dimensions are half-widths/radii in
# the source rig's meter-scale rest pose; colors are linear Blender RGB values.
PRESET = {
    "body": {
        "torso_width_reduction": 0.10,
        "shoulder_width_reduction": 0.12,
        "arm_width_reduction": 0.04,
        "neck_width_reduction": 0.10,
        "torso_depth_reduction": 0.08,
        "neck_depth_reduction": 0.06,
    },
    "jacket": {
        "hip_half_width": 0.196,
        "waist_half_width": 0.174,
        "chest_half_width": 0.210,
        "shoulder_half_width": 0.180,
        "depth_scale": 0.92,
        "front_opening_angle": 0.42,
        "collar_half_width": 0.076,
        "collar_depth": 0.052,
        "sleeve_shoulder_radius": 0.045,
        "sleeve_elbow_radius": 0.036,
        "sleeve_forearm_radius": 0.032,
        "sleeve_wrist_radius": 0.024,
        "sleeve_root_inset": 0.050,
        "sleeve_root_ratio": 0.50,
        "sleeve_length": 0.92,
        "lapel_width_scale": 0.90,
    },
    "waistcoat": {"width_scale": 0.94, "depth_scale": 0.88},
    "shirt": {
        "width_scale": 0.62,
        "depth_scale": 0.64,
        "neckline_half_width": 0.048,
        "neckline_depth": 0.040,
    },
    "cuff": {"diameter": 0.048, "length": 0.034},
    "trousers": {
        "hip_radius": 0.078,
        "thigh_radius": 0.069,
        "knee_radius": 0.058,
        "calf_radius": 0.051,
        "ankle_radius": 0.040,
        "depth_scale": 0.86,
    },
    "shoe": {"length_scale": 0.96, "width_scale": 0.94, "heel_height": 0.012},
    "palette": {
        "jacket": (0.038, 0.055, 0.090),
        "lapel": (0.052, 0.068, 0.100),
        "trousers": (0.045, 0.064, 0.104),
        "waistcoat": (0.065, 0.055, 0.043),
        "shirt": (0.64, 0.62, 0.57),
        "tie": (0.19, 0.027, 0.042),
        "metal": (0.56, 0.38, 0.15),
        "leather": (0.105, 0.038, 0.018),
        "hair": (0.105, 0.105, 0.095),
        "skin": (0.60, 0.40, 0.29),
        "wood": (0.20, 0.092, 0.040),
        "chair": (0.20, 0.225, 0.15),
        "backdrop": (0.40, 0.41, 0.40),
    },
}

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def make_material(name, color, roughness=0.7, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return material


COLORS = PRESET["palette"]
jacket_material = make_material("Suit wool · midnight navy", COLORS["jacket"])
lapel_material = make_material("Jacket lapels · fine wool", COLORS["lapel"])
trousers_material = make_material("Trousers · navy wool", COLORS["trousers"])
waistcoat_material = make_material("Waistcoat · charcoal wool", COLORS["waistcoat"])
shirt_material = make_material("Shirt · warm ivory cotton", COLORS["shirt"])
tie_material = make_material("Tie · burgundy silk", COLORS["tie"], 0.36)
metal_material = make_material("Buttons · antique brass", COLORS["metal"], 0.30, 0.45)
leather_material = make_material("Shoes · warm brown leather", COLORS["leather"], 0.50)
sole_material = make_material("Shoe soles · black leather", (0.027, 0.024, 0.022), 0.70)
hair_material = make_material("Hair · silvery gray", COLORS["hair"])
skin_material = make_material("Visible skin · warm beige", COLORS["skin"])
eye_material = make_material("Eyes · warm ivory", (0.78, 0.76, 0.69), 0.35)
iris_material = make_material("Eyes · deep brown iris", (0.13, 0.065, 0.032), 0.28)
pupil_material = make_material("Eyes · dark pupil", (0.012, 0.009, 0.008), 0.22)
chair_wood = make_material("Chair · dark mahogany", COLORS["wood"], 0.48)
chair_leather = make_material("Chair · olive green leather", COLORS["chair"], 0.68)

bpy.ops.import_scene.gltf(filepath=str(SOURCE / "universal-base-character.glb"))
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name == "SuperHero_Male")
rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
rig.name = "CASES_Humanoid65"
body.name = "OriginalQuaterniusBody"
print("BASE:", body.name, "verts", len(body.data.vertices), "bones", len(rig.data.bones))

for obj in list(bpy.data.objects):
    if obj != body and obj != rig and obj.type == "MESH" and obj.name not in ("Eyes", "Eyebrows"):
        bpy.data.objects.remove(obj, do_unlink=True)
    elif obj.type == "MESH" and obj.name in ("Eyes", "Eyebrows"):
        obj.data.materials.clear()
        obj.data.materials.append(eye_material if obj.name == "Eyes" else hair_material)


def fit_base_proportions(mesh_object):
    """Add an editable corrective shape key while preserving source weights/rig."""
    base = mesh_object.data.shape_keys.key_blocks["Basis"] if mesh_object.data.shape_keys else None
    if base is None:
        base = mesh_object.shape_key_add(name="Basis")
    correction = mesh_object.shape_key_add(name="CASES average-build correction")
    group_names = {index: group.name for index, group in enumerate(mesh_object.vertex_groups)}
    torso_bones = {"pelvis", "spine_01", "spine_02", "spine_03"}
    shoulder_bones = {"clavicle_l", "clavicle_r"}
    arm_bones = {"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"}
    body_parameters = PRESET["body"]
    for vertex in mesh_object.data.vertices:
        influence = {group_names[item.group]: item.weight for item in vertex.groups}
        torso_weight = sum(influence.get(name, 0.0) for name in torso_bones)
        shoulder_weight = sum(influence.get(name, 0.0) for name in shoulder_bones)
        arm_weight = sum(influence.get(name, 0.0) for name in arm_bones)
        neck_weight = influence.get("neck_01", 0.0)
        width_reduction = (
            body_parameters["torso_width_reduction"] * torso_weight
            + body_parameters["shoulder_width_reduction"] * shoulder_weight
            + body_parameters["arm_width_reduction"] * arm_weight
            + body_parameters["neck_width_reduction"] * neck_weight
        )
        source = base.data[vertex.index].co
        target = correction.data[vertex.index].co
        target.x = source.x * max(0.82, 1.0 - width_reduction)
        depth_reduction = body_parameters["torso_depth_reduction"] * torso_weight + body_parameters["neck_depth_reduction"] * neck_weight
        target.y = source.y * max(0.82, 1.0 - depth_reduction)
        target.z = source.z
    correction.value = 1.0
    mesh_object.active_shape_key_index = len(mesh_object.data.shape_keys.key_blocks) - 1
    print("BODY CORRECTION:", correction.name, "value", correction.value)


fit_base_proportions(body)


def cut_from_body(name, predicate, offset, material, thickness=0.0):
    """Copy a source surface and its original vertex groups/skin weights."""
    mesh = body.data.copy()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for group in body.vertex_groups:
        obj.vertex_groups.new(name=group.name)
    for vertex in body.data.vertices:
        for assignment in vertex.groups:
            obj.vertex_groups[assignment.group].add([vertex.index], assignment.weight, "REPLACE")
    obj.parent = rig
    armature_modifier = obj.modifiers.new("CASES shared 65-bone rig", "ARMATURE")
    armature_modifier.object = rig
    for vertex in mesh.vertices:
        vertex.co += vertex.normal * offset
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if not predicate(face.calc_center_median())], context="FACES")
    loose = [vertex for vertex in bm.verts if not vertex.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.clear()
    mesh.materials.append(material)
    if thickness:
        solidify = obj.modifiers.new("Thin cloth edge", "SOLIDIFY")
        solidify.thickness = thickness
        solidify.offset = 0.0
    print("GARMENT", name, "verts", len(mesh.vertices), "polys", len(mesh.polygons))
    return obj


def normalize_weights(weights):
    clean = {name: max(0.0, float(value)) for name, value in weights.items() if value > 0.0001}
    total = sum(clean.values())
    if total <= 0.0:
        raise ValueError("A skinned vertex must have at least one nonzero influence")
    return {name: value / total for name, value in clean.items()}


def skinned(name, vertices, faces, weights, material, thickness=0.0):
    if len(vertices) != len(weights):
        raise ValueError(f"{name}: {len(vertices)} vertices but {len(weights)} weight sets")
    valid_bones = {bone.name for bone in rig.data.bones}
    normalized = []
    for index, weight_set in enumerate(weights):
        unknown = set(weight_set) - valid_bones
        if unknown:
            raise ValueError(f"{name} vertex {index} has unknown bone groups: {sorted(unknown)}")
        row = normalize_weights(weight_set)
        if abs(sum(row.values()) - 1.0) > 1e-6:
            raise ValueError(f"{name} vertex {index} weights are not normalized")
        normalized.append(row)

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(vertex) for vertex in vertices], [], faces)
    mesh.update()
    if mesh.polygons:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    mesh.materials.append(material)
    groups = {}
    for index, weight_set in enumerate(normalized):
        for bone_name, value in weight_set.items():
            group = groups.get(bone_name)
            if group is None:
                group = obj.vertex_groups.new(name=bone_name)
                groups[bone_name] = group
            group.add([index], value, "REPLACE")
    modifier = obj.modifiers.new("Shared Quaternius armature", "ARMATURE")
    modifier.object = rig
    if thickness:
        solidify = obj.modifiers.new("Tailored cloth thickness", "SOLIDIFY")
        solidify.thickness = thickness
        solidify.offset = 0.0
    print("TAILORED", name, len(vertices), len(faces))
    return obj


def torso_weights(z):
    if z < 1.10:
        t = max(0.0, min(1.0, (z - 1.00) / 0.10))
        return {"pelvis": 0.20 * (1.0 - t), "spine_01": 0.80 + 0.20 * t}
    if z < 1.29:
        t = (z - 1.10) / 0.19
        return {"spine_01": 1.0 - t, "spine_02": t}
    if z < 1.45:
        t = (z - 1.29) / 0.16
        return {"spine_02": 1.0 - t, "spine_03": t}
    return {"spine_03": 1.0}


JACKET = PRESET["jacket"]
JACKET_PROFILE = [
    (0.995, JACKET["hip_half_width"] * 0.94, 0.112 * JACKET["depth_scale"], 0.030),
    (1.055, JACKET["hip_half_width"], 0.118 * JACKET["depth_scale"], 0.030),
    (1.135, JACKET["waist_half_width"] * 0.98, 0.119 * JACKET["depth_scale"], 0.030),
    (1.220, JACKET["waist_half_width"], 0.123 * JACKET["depth_scale"], 0.030),
    (1.305, JACKET["chest_half_width"] * 0.94, 0.128 * JACKET["depth_scale"], 0.030),
    (1.390, JACKET["chest_half_width"], 0.132 * JACKET["depth_scale"], 0.030),
    (1.430, JACKET["shoulder_half_width"] * 0.99, 0.121 * JACKET["depth_scale"], 0.032),
    (1.455, JACKET["shoulder_half_width"] * 0.91, 0.115 * JACKET["depth_scale"], 0.034),
    (1.475, JACKET["collar_half_width"] * 2.05, 0.088 * JACKET["depth_scale"], 0.035),
    (1.492, JACKET["collar_half_width"] * 1.48, 0.067 * JACKET["depth_scale"], 0.036),
    (1.505, JACKET["collar_half_width"], JACKET["collar_depth"], 0.036),
]


def scaled_profile(profile, width_scale, depth_scale):
    return [(z, rx * width_scale, ry * depth_scale, cy) for z, rx, ry, cy in profile]


WAISTCOAT_PROFILE = scaled_profile(JACKET_PROFILE, PRESET["waistcoat"]["width_scale"], PRESET["waistcoat"]["depth_scale"])
SHIRT_PROFILE = scaled_profile(JACKET_PROFILE, PRESET["shirt"]["width_scale"], PRESET["shirt"]["depth_scale"])
# Narrow the shirt's upper edge from the shoulder line into the neck opening.
# This keeps the open-front jacket from revealing a broad, hollow shoulder ring.
SHIRT_PROFILE = [row for row in SHIRT_PROFILE if row[0] <= 1.455]
SHIRT_PROFILE.extend([
    (1.478, 0.068, 0.050, 0.036),
    (1.495, PRESET["shirt"]["neckline_half_width"], PRESET["shirt"]["neckline_depth"], 0.036),
])


def profile_at(profile, z):
    if z <= profile[0][0]:
        return profile[0][1:]
    if z >= profile[-1][0]:
        return profile[-1][1:]
    for first, second in zip(profile, profile[1:]):
        if first[0] <= z <= second[0]:
            t = (z - first[0]) / (second[0] - first[0])
            return tuple(first[i] + (second[i] - first[i]) * t for i in range(1, 4))
    return profile[-1][1:]


def surface_y(profile, x, z, inset=0.0):
    rx, ry, center_y = profile_at(profile, z)
    ratio = min(0.995, abs(x) / max(rx, 0.0001))
    return center_y - ry * math.sqrt(max(0.01, 1.0 - ratio * ratio)) - inset


def surface_mesh(name, profile, angles, material, wrap=False, thickness=0.0):
    vertices = []
    faces = []
    weights = []
    radial_count = len(angles)
    for z, rx, ry, center_y in profile:
        for angle in angles:
            vertices.append((rx * math.sin(angle), center_y - ry * math.cos(angle), z))
            weights.append(torso_weights(z))
    for row in range(len(profile) - 1):
        count = radial_count if wrap else radial_count - 1
        for column in range(count):
            next_column = (column + 1) % radial_count
            a = row * radial_count + column
            b = (row + 1) * radial_count + column
            faces.append((a, row * radial_count + next_column, (row + 1) * radial_count + next_column, b))
    return skinned(name, vertices, faces, weights, material, thickness)


opening = JACKET["front_opening_angle"]
jacket_angles = [opening + i * (2.0 * math.pi - 2.0 * opening) / 32.0 for i in range(33)]
coat = surface_mesh("03 · Tailored midnight jacket", JACKET_PROFILE, jacket_angles, jacket_material, thickness=0.003)
shirt_angles = [i * 2.0 * math.pi / 24.0 for i in range(24)]
surface_mesh("02 · Dress shirt body", SHIRT_PROFILE, shirt_angles, shirt_material, wrap=True, thickness=0.002)


def make_waistcoat():
    vertices = []
    weights = []
    faces = []
    rows = [
        (1.010, 0.012, 0.164),
        (1.105, 0.012, 0.182),
        (1.220, 0.013, 0.190),
        (1.315, 0.026, 0.190),
        (1.382, 0.045, 0.176),
        (1.420, 0.035, 0.158),
    ]
    subdivisions = 6
    for side in (-1.0, 1.0):
        start = len(vertices)
        for z, inner, outer in rows:
            for column in range(subdivisions + 1):
                x = side * (inner + (outer - inner) * column / subdivisions)
                vertices.append((x, surface_y(WAISTCOAT_PROFILE, x, z, 0.004), z))
                weights.append(torso_weights(z))
        for row in range(len(rows) - 1):
            for column in range(subdivisions):
                a = start + row * (subdivisions + 1) + column
                b = a + subdivisions + 1
                faces.append((a, a + 1, b + 1, b))
    return skinned("04 · Buttoned charcoal waistcoat", vertices, faces, weights, waistcoat_material, 0.002)


vest = make_waistcoat()


def smoothstep(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def limb_frame(tangent, preferred_front):
    axis = tangent.normalized()
    front = preferred_front - axis * preferred_front.dot(axis)
    if front.length < 0.05:
        preferred_up = Vector((0.0, 0.0, 1.0))
        front = preferred_up - axis * preferred_up.dot(axis)
    front.normalize()
    across = axis.cross(front).normalized()
    return front, across


def interpolated_tangent(points, index):
    if index == 0:
        tangent = points[1] - points[0]
    elif index == len(points) - 1:
        tangent = points[-1] - points[-2]
    else:
        tangent = points[index + 1] - points[index - 1]
    if tangent.length < 1e-6:
        raise ValueError("Limb centerline contains coincident ring centers")
    return tangent.normalized()


def ring_limb(name, centers, radii, bone_weights, material, depth_scale=0.84, up_scale=1.08, thickness=0.0, close_start=False, close_end=False):
    """Create locally oriented, bone-weighted rings along a rest-pose limb."""
    if not (len(centers) == len(radii) == len(bone_weights)):
        raise ValueError(f"{name}: centerline ring inputs must have matching lengths")
    radial_count = 16
    vertices = []
    weights = []
    faces = []
    centers = [Vector(center) for center in centers]
    for row, (center, radius, weight_set) in enumerate(zip(centers, radii, bone_weights)):
        tangent = interpolated_tangent(centers, row)
        front, across = limb_frame(tangent, Vector((0.0, -1.0, 0.0)))
        for column in range(radial_count):
            angle = 2.0 * math.pi * column / radial_count
            point = center + front * (radius * depth_scale * math.cos(angle)) + across * (radius * up_scale * math.sin(angle))
            vertices.append(tuple(point))
            weights.append(weight_set)
    for row in range(len(centers) - 1):
        for column in range(radial_count):
            next_column = (column + 1) % radial_count
            a = row * radial_count + column
            b = (row + 1) * radial_count + column
            faces.append((a, row * radial_count + next_column, (row + 1) * radial_count + next_column, b))
    if close_start:
        center_index = len(vertices)
        vertices.append(tuple(centers[0]))
        weights.append(bone_weights[0])
        for column in range(radial_count):
            faces.append((center_index, (column + 1) % radial_count, column))
    if close_end:
        center_index = len(vertices)
        vertices.append(tuple(centers[-1]))
        weights.append(bone_weights[-1])
        offset = (len(centers) - 1) * radial_count
        for column in range(radial_count):
            faces.append((center_index, offset + column, offset + (column + 1) % radial_count))
    return skinned(name, vertices, faces, weights, material, thickness)


def arm_centerline(side, label):
    clavicle = rig.data.bones[f"clavicle_{label}"]
    upper = rig.data.bones[f"upperarm_{label}"]
    lower = rig.data.bones[f"lowerarm_{label}"]
    # Run the open shoulder end under the jacket body, so the upper arm joins
    # the torso without a visible or hollow shoulder cap.
    elbow = upper.tail_local.copy()
    wrist = lower.tail_local.copy()
    lower_head = lower.head_local.copy()
    upper_axis = (elbow - upper.head_local).normalized()
    sleeve_end = JACKET["sleeve_length"]
    if not 0.80 < sleeve_end < 0.98:
        raise ValueError("jacket.sleeve_length must end between 80% and 98% of the forearm")
    path_points = [
        upper.head_local - upper_axis * JACKET["sleeve_root_inset"],
        upper.head_local.copy(),
        upper.head_local.lerp(elbow, 0.14),
        upper.head_local.lerp(elbow, 0.40),
        upper.head_local.lerp(elbow, 0.68),
        elbow,
        lower_head.lerp(wrist, 0.24),
        lower_head.lerp(wrist, 0.52),
        lower_head.lerp(wrist, 0.79),
        lower_head.lerp(wrist, sleeve_end),
        wrist,
    ]
    shoulder_radius = JACKET["sleeve_shoulder_radius"]
    elbow_radius = JACKET["sleeve_elbow_radius"]
    forearm_radius = JACKET["sleeve_forearm_radius"]
    wrist_radius = JACKET["sleeve_wrist_radius"]
    radii = [
        shoulder_radius * JACKET["sleeve_root_ratio"],
        shoulder_radius * 0.72,
        shoulder_radius * 0.84,
        shoulder_radius,
        shoulder_radius * 0.96,
        elbow_radius * 1.05,
        elbow_radius * 0.97,
        forearm_radius * 1.12,
        forearm_radius * 1.04,
        wrist_radius * 1.08,
        wrist_radius,
    ]
    total_length = max(0.0001, sum((b - a).length for a, b in zip(path_points, path_points[1:])))
    traveled = 0.0
    normalized_distance = [0.0]
    for first, second in zip(path_points, path_points[1:]):
        traveled += (second - first).length
        normalized_distance.append(traveled / total_length)
    weights = []
    for position in normalized_distance:
        if position < 0.20:
            clavicle_weight = 0.50 * (1.0 - smoothstep(position / 0.20))
            weights.append({f"clavicle_{label}": clavicle_weight, f"upperarm_{label}": 1.0 - clavicle_weight})
        elif position < 0.40:
            weights.append({f"upperarm_{label}": 1.0})
        elif position < 0.66:
            t = smoothstep((position - 0.40) / 0.26)
            weights.append({f"upperarm_{label}": 1.0 - t, f"lowerarm_{label}": t})
        elif position < 0.98:
            weights.append({f"lowerarm_{label}": 1.0})
        else:
            weights.append({f"lowerarm_{label}": 0.80, f"hand_{label}": 0.20})
    return path_points, radii, weights, lower_head, wrist


def make_sleeve(side, label):
    points, radii, weights, lower_head, wrist = arm_centerline(side, label)
    jacket_points = points[:-1]
    jacket_radii = radii[:-1]
    jacket_weights = weights[:-1]
    # Fade the shoulder root into the jacket yoke rather than pinching it to a
    # tiny cap, and run the cuff into the last 8% of the forearm.
    ring_limb("Suit sleeve " + label, jacket_points, jacket_radii, jacket_weights, jacket_material,
              depth_scale=0.82, up_scale=0.88, thickness=0.002, close_start=True)
    make_cuff(label, lower_head, wrist)


def make_cuff(label, lower_head, wrist):
    settings = PRESET["cuff"]
    axis = (wrist - lower_head).normalized()
    front, across = limb_frame(axis, Vector((0.0, -1.0, 0.0)))
    radius = settings["diameter"] * 0.5
    half_length = settings["length"] * 0.5
    center = wrist - axis * half_length
    positions = [-half_length, -half_length * 0.72, half_length * 0.63, half_length]
    outer_radii = [radius * 0.96, radius, radius, radius * 0.95]
    inner_radii = [value - 0.004 for value in outer_radii]
    radial_count = 16
    vertices = []
    weights = []
    faces = []
    for row, current_radius in enumerate(outer_radii + inner_radii):
        centerline_position = positions[row] if row < len(positions) else positions[row - len(positions)]
        local_center = center + axis * centerline_position
        for column in range(radial_count):
            angle = 2.0 * math.pi * column / radial_count
            point = local_center + front * (current_radius * math.cos(angle)) + across * (current_radius * math.sin(angle))
            vertices.append(tuple(point))
            if centerline_position >= 0.0 and abs(centerline_position) >= half_length * 0.95:
                weights.append({f"lowerarm_{label}": 0.82, f"hand_{label}": 0.18})
            else:
                weights.append({f"lowerarm_{label}": 1.0})
    for row in range(3):
        for column in range(radial_count):
            next_column = (column + 1) % radial_count
            a = row * radial_count + column
            faces.append((a, row * radial_count + next_column, (row + 1) * radial_count + next_column, (row + 1) * radial_count + column))
            inner_a = (4 + row) * radial_count + column
            faces.append((inner_a, (4 + row) * radial_count + next_column, (5 + row) * radial_count + next_column, (5 + row) * radial_count + column))
    for end_row in (0, 3):
        outer = end_row * radial_count
        inner = (end_row + 4) * radial_count
        for column in range(radial_count):
            next_column = (column + 1) % radial_count
            faces.append((outer + column, inner + column, inner + next_column, outer + next_column))
    skinned("Ivory shirt cuff " + label, vertices, faces, weights, shirt_material)


for side, label in ((1.0, "l"), (-1.0, "r")):
    make_sleeve(side, label)


def make_shirt_front():
    rows = [(1.16, 0.044), (1.28, 0.048), (1.38, 0.048), (1.445, 0.038)]
    vertices = []
    weights = []
    faces = []
    subdivisions = 6
    for z, half_width in rows:
        for column in range(subdivisions + 1):
            x = -half_width + 2.0 * half_width * column / subdivisions
            vertices.append((x, surface_y(SHIRT_PROFILE, x, z, 0.004), z))
            weights.append(torso_weights(z))
    for row in range(len(rows) - 1):
        for column in range(subdivisions):
            a = row * (subdivisions + 1) + column
            b = a + subdivisions + 1
            faces.append((a, a + 1, b + 1, b))
    return skinned("Dress shirt front", vertices, faces, weights, shirt_material, 0.002)


make_shirt_front()


def make_lapels():
    result = []
    panels = [
        # Collar leaf, then the long chest lapel. Shared corners create a
        # readable notch without a single large, folded n-gon.
        ((0.056, 1.504), (0.156, 1.463), (0.136, 1.416), (0.094, 1.438)),
        ((0.094, 1.438), (0.136, 1.416), (0.158, 1.312), (0.094, 1.274)),
    ]
    for side in (-1.0, 1.0):
        for panel_index, (inner_top, outer_top, outer_bottom, inner_bottom) in enumerate(panels):
            inner_top = (inner_top[0] * JACKET["lapel_width_scale"], inner_top[1])
            outer_top = (outer_top[0] * JACKET["lapel_width_scale"], outer_top[1])
            outer_bottom = (outer_bottom[0] * JACKET["lapel_width_scale"], outer_bottom[1])
            inner_bottom = (inner_bottom[0] * JACKET["lapel_width_scale"], inner_bottom[1])
            row_count = 8
            column_count = 4
            vertices = []
            weights = []
            faces = []
            for row in range(row_count + 1):
                along = row / row_count
                inner_x = inner_top[0] * (1.0 - along) + inner_bottom[0] * along
                inner_z = inner_top[1] * (1.0 - along) + inner_bottom[1] * along
                outer_x = outer_top[0] * (1.0 - along) + outer_bottom[0] * along
                outer_z = outer_top[1] * (1.0 - along) + outer_bottom[1] * along
                for column in range(column_count + 1):
                    across = column / column_count
                    x = inner_x * (1.0 - across) + outer_x * across
                    z = inner_z * (1.0 - across) + outer_z * across
                    vertices.append((side * x, surface_y(JACKET_PROFILE, side * x, z, 0.003), z))
                    weights.append(torso_weights(z))
            for row in range(row_count):
                for column in range(column_count):
                    a = row * (column_count + 1) + column
                    b = a + column_count + 1
                    faces.append((a, a + 1, b + 1, b))
            result.append(skinned("05 · Notched jacket lapel " + str(int(side)) + " panel " + str(panel_index), vertices, faces, weights, lapel_material, 0.0015))
    return result


lapels = make_lapels()


def make_shirt_collar():
    vertices = []
    weights = []
    faces = []
    sections = [(1.490, 0.060, 0.047), (1.505, 0.056, 0.044), (1.523, 0.050, 0.041), (1.541, 0.045, 0.038)]
    count = 20
    for z, rx, ry in sections:
        for column in range(count):
            angle = 2.0 * math.pi * column / count
            vertices.append((rx * math.sin(angle), 0.038 - ry * math.cos(angle), z))
            weights.append({"neck_01": 1.0})
    for row in range(len(sections) - 1):
        for column in range(count):
            next_column = (column + 1) % count
            a = row * count + column
            faces.append((a, row * count + next_column, (row + 1) * count + next_column, (row + 1) * count + column))
    collar = skinned("06 · Turn-down shirt collar", vertices, faces, weights, shirt_material, 0.002)
    # Two short collar points wrap the tie knot and lie against the shirt front.
    for side in (-1.0, 1.0):
        points = [
            (side * 0.035, -0.026, 1.512),
            (side * 0.038, -0.048, 1.494),
            (side * 0.018, -0.073, 1.466),
            (side * 0.013, -0.059, 1.486),
        ]
        skinned("06 · Shirt collar point " + str(int(side)), points, [(0, 1, 2, 3)], [{"neck_01": 0.45, "spine_03": 0.55}] * 4, shirt_material, 0.002)
    return collar


make_shirt_collar()


def make_tie():
    vertices = []
    weights = []
    faces = []
    tie_profile = [
        (0.018, 1.425, -0.093),
        (0.024, 1.402, -0.095),
        (0.026, 1.375, -0.098),
        (0.020, 1.345, -0.100),
        (0.025, 1.195, -0.100),
        (0.0, 1.163, -0.097),
    ]
    # A front face and shallow reverse face make the tie a fabric piece rather
    # than a zero-thickness triangle pasted onto the jacket.
    for x_abs, z, front_y in tie_profile:
        half_width = x_abs
        for side in (-1.0, 1.0):
            vertices.append((side * half_width, front_y, z))
            weights.append(torso_weights(z))
            vertices.append((side * half_width, front_y + 0.009, z))
            weights.append(torso_weights(z))
    for row in range(len(tie_profile) - 1):
        a = row * 4
        b = (row + 1) * 4
        faces.extend([(a, a + 2, b + 2, b), (a + 1, b + 1, b + 3, a + 3)])
        faces.extend([(a, b, b + 1, a + 1), (a + 2, a + 3, b + 3, b + 2)])
    faces.append((0, 1, 3, 2))
    end = (len(tie_profile) - 1) * 4
    faces.append((end, end + 2, end + 3, end + 1))
    return skinned("07 · Burgundy necktie", vertices, faces, weights, tie_material, 0.0015)


make_tie()


def make_trouser(side, label):
    thigh = rig.data.bones[f"thigh_{label}"]
    calf = rig.data.bones[f"calf_{label}"]
    hip = thigh.head_local.copy()
    knee = thigh.tail_local.copy()
    ankle = calf.tail_local.copy()
    settings = PRESET["trousers"]
    depth_scale = settings["depth_scale"]
    centers = [
        hip + Vector((0.0, 0.0, 0.050)),
        hip,
        hip.lerp(knee, 0.20),
        hip.lerp(knee, 0.52),
        knee,
        knee.lerp(ankle, 0.16),
        knee.lerp(ankle, 0.43),
        knee.lerp(ankle, 0.72),
        knee.lerp(ankle, 0.94),
        ankle,
    ]
    radii = [
        settings["hip_radius"], settings["hip_radius"] * 0.98,
        settings["thigh_radius"], settings["thigh_radius"] * 0.95,
        settings["knee_radius"], settings["knee_radius"] * 0.99,
        settings["calf_radius"], settings["calf_radius"] * 0.90,
        settings["ankle_radius"] * 1.08, settings["ankle_radius"],
    ]
    weights = [
        {"pelvis": 0.30, f"thigh_{label}": 0.70},
        {"pelvis": 0.20, f"thigh_{label}": 0.80},
        {f"thigh_{label}": 1.0},
        {f"thigh_{label}": 1.0},
        {f"thigh_{label}": 0.50, f"calf_{label}": 0.50},
        {f"thigh_{label}": 0.20, f"calf_{label}": 0.80},
        {f"calf_{label}": 1.0},
        {f"calf_{label}": 1.0},
        {f"calf_{label}": 1.0},
        {f"calf_{label}": 1.0},
    ]
    ring_limb("Wool trousers " + label, centers, radii, weights, trousers_material,
              depth_scale=depth_scale, up_scale=1.03, thickness=0.002, close_start=True, close_end=True)


for side, label in ((1.0, "l"), (-1.0, "r")):
    make_trouser(side, label)


def make_shoe(label):
    foot = rig.data.bones[f"foot_{label}"]
    ankle = foot.head_local.copy()
    toe = foot.tail_local.copy()
    direction = (toe - ankle).normalized()
    width_axis = Vector((1.0, 0.0, 0.0))
    width_axis = (width_axis - direction * width_axis.dot(direction)).normalized()
    up_axis = direction.cross(width_axis).normalized()
    settings = PRESET["shoe"]
    width_scale = settings["width_scale"]
    length_scale = settings["length_scale"]
    positions = [-0.018, 0.0, 0.032, 0.067, 0.101, 0.136, 0.165, 0.185]
    widths = [0.031, 0.038, 0.043, 0.044, 0.043, 0.038, 0.030, 0.020]
    heights = [0.021, 0.027, 0.032, 0.033, 0.031, 0.027, 0.020, 0.010]
    vertices = []
    weights = []
    faces = []
    count = 12
    lift = settings["heel_height"] + 0.010
    for distance, width, height in zip(positions, widths, heights):
        center = ankle + direction * (distance * length_scale) + up_axis * lift
        for column in range(count):
            angle = 2.0 * math.pi * column / count
            point = center + width_axis * (width * width_scale * math.cos(angle)) + up_axis * (height * math.sin(angle))
            vertices.append(tuple(point))
            weights.append({f"foot_{label}": 1.0})
    for row in range(len(positions) - 1):
        for column in range(count):
            next_column = (column + 1) % count
            a = row * count + column
            faces.append((a, row * count + next_column, (row + 1) * count + next_column, (row + 1) * count + column))
    skinned("Leather shoe " + label, vertices, faces, weights, leather_material, 0.001)

    # A thin, slightly wider sole gives the shoe a separate heel and outsole.
    sole_vertices = []
    sole_weights = []
    sole_faces = []
    for distance, width in zip(positions, widths):
        center = ankle + direction * (distance * length_scale) + up_axis * 0.002
        for column in range(count):
            angle = 2.0 * math.pi * column / count
            point = center + width_axis * (width * width_scale * 1.06 * math.cos(angle)) + up_axis * (0.006 * math.sin(angle))
            sole_vertices.append(tuple(point))
            sole_weights.append({f"foot_{label}": 1.0})
    for row in range(len(positions) - 1):
        for column in range(count):
            next_column = (column + 1) % count
            a = row * count + column
            sole_faces.append((a, row * count + next_column, (row + 1) * count + next_column, (row + 1) * count + column))
    skinned("Dress shoe sole " + label, sole_vertices, sole_faces, sole_weights, sole_material)


for label in ("l", "r"):
    make_shoe(label)


def uvball(name, position, scale, material, weights):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.parent = rig
    for bone_name, value in normalize_weights(weights).items():
        obj.vertex_groups.new(name=bone_name).add(list(range(len(obj.data.vertices))), value, "REPLACE")
    modifier = obj.modifiers.new("Armature binding", "ARMATURE")
    modifier.object = rig
    obj.data.materials.append(material)
    return obj


def make_buttons():
    for index, z in enumerate((1.095, 1.166, 1.237, 1.308)):
        x = 0.035
        y = surface_y(WAISTCOAT_PROFILE, x, z, 0.010)
        uvball("Waistcoat brass button " + str(index + 1), (x, y, z), (0.006, 0.0035, 0.006), metal_material, torso_weights(z))
    for index, x in enumerate((-0.142, 0.142)):
        z = 1.095
        y = surface_y(JACKET_PROFILE, x, z, 0.008)
        uvball("Jacket front button " + str(index + 1), (x, y, z), (0.006, 0.0035, 0.006), metal_material, torso_weights(z))


make_buttons()
tie_knot_vertices = [
    (-0.014, -0.103, 1.446), (0.014, -0.103, 1.446),
    (0.019, -0.103, 1.425), (-0.019, -0.103, 1.425),
    (-0.014, -0.097, 1.446), (0.014, -0.097, 1.446),
    (0.019, -0.097, 1.425), (-0.019, -0.097, 1.425),
]
tie_knot_faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
skinned("Burgundy tie knot", tie_knot_vertices, tie_knot_faces, [torso_weights(1.435)] * len(tie_knot_vertices), tie_material, 0.001)


def make_hair_and_face():
    cut_from_body(
        "Close-cropped gray hair",
        lambda center: center.z > (1.724 - 0.006 * math.exp(-((center.x + 0.035) / 0.026) ** 2) if center.y < 0.0 else 1.724) and abs(center.x) < 0.15,
        0.006,
        hair_material,
    )
    for side in (-1.0, 1.0):
        uvball("Brown iris " + str(int(side)), (side * 0.024, -0.084, 1.699), (0.0075, 0.0032, 0.008), iris_material, {"Head": 1.0})
        uvball("Pupil " + str(int(side)), (side * 0.024, -0.087, 1.699), (0.0035, 0.0018, 0.0045), pupil_material, {"Head": 1.0})

    moustache_outline = [
        (-0.050, 1.639), (-0.041, 1.645), (-0.027, 1.648), (-0.014, 1.645),
        (0.000, 1.640), (0.014, 1.645), (0.027, 1.648), (0.041, 1.645),
        (0.050, 1.639), (0.040, 1.633), (0.027, 1.631), (0.014, 1.635),
        (0.000, 1.637), (-0.014, 1.635), (-0.027, 1.631), (-0.040, 1.633),
    ]
    vertices = []
    for x, z in moustache_outline:
        hit, location, _, _ = body.ray_cast(Vector((x, -0.30, z)), Vector((0.0, 1.0, 0.0)))
        y = location.y - 0.002 if hit else -0.104
        vertices.append((x, y, z))
    skinned("Contiguous close-set moustache", vertices, [tuple(range(len(vertices)))], [{"Head": 1.0}] * len(vertices), hair_material, 0.002)


make_hair_and_face()

# Keep the original face and animated hands. The torso, arms and legs are
# completely covered by the tailored garments, which remain independently
# skinned to the same 65-bone armature.
bm = bmesh.new()
bm.from_mesh(body.data)
discard = []
for face in bm.faces:
    center = face.calc_center_median()
    visible_head = (center.z > 1.565 and abs(center.x) < 0.16) or (center.z > 1.515 and abs(center.x) < 0.105)
    visible_hands = abs(center.x) > 0.685 and center.z > 1.19
    if not (visible_head or visible_hands):
        discard.append(face)
bmesh.ops.delete(bm, geom=discard, context="FACES")
loose = [vertex for vertex in bm.verts if not vertex.link_faces]
if loose:
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
bm.to_mesh(body.data)
bm.free()
body.data.materials.clear()
body.data.materials.append(skin_material)


def cube(name, location, size, material, bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


# Static meeting chair positioned under the seated Quaternius pelvis.
cube("Chair · seat wood", (0, 0.35, 0.475), (0.64, 0.61, 0.10), chair_wood)
cube("Chair · padded seat", (0, 0.34, 0.535), (0.58, 0.55, 0.035), chair_leather)
cube("Chair · high upholstered back", (0, 0.668, 0.95), (0.59, 0.09, 0.79), chair_wood)
cube("Chair · back upholstery", (0, 0.611, 0.98), (0.51, 0.042, 0.62), chair_leather)
for side in (-1.0, 1.0):
    cube("Chair · front leg", (side * 0.265, 0.095, 0.24), (0.065, 0.07, 0.48), chair_wood)
    cube("Chair · rear leg", (side * 0.265, 0.60, 0.245), (0.065, 0.08, 0.49), chair_wood)
    cube("Chair · armrest", (side * 0.355, 0.31, 0.73), (0.07, 0.60, 0.055), chair_wood)
    cube("Chair · armrest support", (side * 0.355, 0.55, 0.64), (0.055, 0.07, 0.18), chair_wood)

# Attach only the compatible seated Quaternius actions.
old_objects = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / "universal-animation-library.glb"))
for obj in list(bpy.data.objects):
    if obj not in old_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
clips = {
    "SeatedIdle": next(action for action in bpy.data.actions if "Sitting_Idle_Loop" in action.name),
    "SeatedTalking": next(action for action in bpy.data.actions if "Sitting_Talking_Loop" in action.name),
}
rig.animation_data_create()
for name, action in clips.items():
    action.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, action)
    strip.action_frame_start = action.frame_range[0]
    strip.action_frame_end = action.frame_range[1]
for action in list(bpy.data.actions):
    if action not in clips.values():
        bpy.data.actions.remove(action)
print("NLA", [(track.name, [strip.action.name for strip in track.strips]) for track in rig.animation_data.nla_tracks])

for track in rig.animation_data.nla_tracks:
    track.mute = False

glb_path = GODOT / "cases_suited_negotiator.glb"
bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format="GLB",
    export_animations=True,
    export_nla_strips=True,
    export_apply=False,
    export_yup=True,
)
print("EXPORTED", str(glb_path), glb_path.stat().st_size)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "cases_suited_negotiator.blend"))
print("SAVED BLEND")

# Blender preview environment. None of these objects enter the exported GLB.
for track in rig.animation_data.nla_tracks:
    track.mute = True
bpy.ops.object.camera_add(location=(0.0, -3.4, 1.35))
camera = bpy.context.object
camera.name = "V2 preview camera"
camera.data.lens = 50
scene = bpy.context.scene
scene.camera = camera

def add_area_light(name, location, energy, size, color):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (Vector((0.0, 0.25, 0.92)) - light.location).to_track_quat("-Z", "Y").to_euler()
    return light


add_area_light("Preview key light", (-2.2, -2.5, 3.3), 500, 3.0, (1.0, 0.89, 0.76))
add_area_light("Preview fill light", (2.6, -1.2, 2.0), 300, 2.5, (0.78, 0.86, 1.0))
add_area_light("Preview rim light", (0.0, 1.6, 2.8), 420, 2.0, (1.0, 0.94, 0.84))
cube("Preview ground", (0.0, 0.0, -0.064), (6.0, 6.0, 0.09), make_material("Backdrop", COLORS["backdrop"]), 0.0)
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 48
scene.render.resolution_x = 1200
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = False
scene.world.color = (0.30, 0.30, 0.30)
scene.view_settings.view_transform = "AgX"


def render_view(filename, action, frame, location, target, lens=50, destination=V2_OUTPUT):
    camera.location = location
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = lens
    rig.animation_data.action = action
    scene.frame_set(frame)
    scene.render.filepath = str(destination / filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)


idle = clips["SeatedIdle"]
talking = clips["SeatedTalking"]
front = (0.0, -3.50, 1.32)
three_quarter = (1.52, -3.18, 1.62)
side_camera = (3.55, 0.10, 1.30)
torso_target = (0.0, 0.29, 0.91)
render_view("seated_idle_front.png", idle, 15, front, torso_target)
render_view("seated_idle_three_quarter.png", idle, 15, three_quarter, torso_target)
render_view("seated_idle_side.png", idle, 15, side_camera, torso_target)
render_view("seated_talking_front.png", talking, 22, front, torso_target)
render_view("seated_talking_three_quarter.png", talking, 22, three_quarter, torso_target)
render_view("left_sleeve_detail.png", talking, 30, (0.62, -1.55, 1.12), (0.36, 0.12, 1.05), 56)
render_view("right_sleeve_detail.png", talking, 22, (-0.62, -1.55, 1.13), (-0.36, 0.12, 1.05), 56)
render_view("jacket_detail.png", idle, 15, (0.0, -2.16, 1.65), (0.0, 0.19, 1.36), 60)

# Keep sampled talking frames for elbow/wrist inspection and iteration.
frames_dir = V2_OUTPUT / "talking_frames"
frames_dir.mkdir(parents=True, exist_ok=True)
for frame in (1, 10, 22, 30, 45, 60):
    render_view(f"talking_frame_{frame:02d}.png", talking, frame, front, torso_target, destination=frames_dir)

# Preserve the original two-preview paths for existing project workflows.
for filename, action, frame in (("seated_idle.png", idle, 15), ("seated_talking.png", talking, 22)):
    render_view(filename, action, frame, three_quarter, torso_target, destination=OUTPUT)

print("DONE: 65-bone suit GLB, editable blend and V2 visual review set")
