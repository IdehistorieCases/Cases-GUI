extends SceneTree

const CHARACTER_PATHS := [
    "res://assets/characters/cases_suited_negotiator.glb",
    "res://assets/characters/cases_suited_negotiator_senior_mediator.glb",
    "res://assets/characters/cases_suited_negotiator_younger_envoy.glb",
    "res://assets/characters/cases_suited_negotiator_scholarly_delegate.glb",
]
const REQUIRED_BONES := ["pelvis", "spine_03", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l"]
const REQUIRED_ANIMATED_BONES_BY_CLIP := {
    "SeatedIdle": ["Head", "neck_01", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"],
    "SeatedTalking": ["Head", "neck_01", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"],
}
const SAMPLE_FRACTIONS := [
    0.0, 0.0714286, 0.1428571, 0.2142857, 0.2857143,
    0.3571429, 0.4285714, 0.5, 0.5714286, 0.6428571,
    0.7142857, 0.7857143, 0.8571429, 0.9285714, 1.0,
]

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var results: Array[Dictionary] = []
    for asset_path in CHARACTER_PATHS:
        results.append(validate_character(asset_path))
    var failure_count := 0
    for result in results:
        failure_count += (result["failures"] as Array).size()
        print("CASES asset result: ", result["path"], " | skinned meshes ", result["skinned_mesh_count"], " | weighted surfaces ", result["weighted_surface_count"], " | failures ", (result["failures"] as Array).size())
    if failure_count == 0 and results.size() == 4:
        print("CASES validated character assets: 4")
        print("CASES VALIDATION PASS")
        quit(0)
        return
    print("CASES VALIDATION FAIL (", failure_count, " issues across ", results.size(), " assets)")
    quit(1)
    return

func validate_character(asset_path: String) -> Dictionary:
    # Every character gets fresh counters and a fresh failure list.
    var result := {
        "path": asset_path,
        "failures": [],
        "skinned_mesh_count": 0,
        "weighted_surface_count": 0,
        "sleeve_count": 0,
        "cuff_count": 0,
        "trouser_count": 0,
        "shoe_count": 0,
    }
    var packed := load(asset_path) as PackedScene
    if packed == null:
        _fail(result, "GLB did not import as a PackedScene")
        return result

    var model := packed.instantiate() as Node3D
    if model == null:
        _fail(result, "GLB root is not a Node3D")
        return result
    root.add_child(model)
    var player := _find_player(model)
    var skeleton := _find_skeleton(model)
    if player == null or skeleton == null:
        _fail(result, "AnimationPlayer or Skeleton3D is missing")
        model.free()
        return result

    print("CASES Godot imported skeleton bones: ", asset_path, " = ", skeleton.get_bone_count())
    if skeleton.get_bone_count() != 65:
        _fail(result, "Expected the compatible 65-bone Quaternius skeleton")
    for bone_name in REQUIRED_BONES:
        if skeleton.find_bone(bone_name) < 0:
            _fail(result, "Missing required skeleton bone: " + bone_name)
    for clip in REQUIRED_ANIMATED_BONES_BY_CLIP:
        if not player.has_animation(clip):
            _fail(result, "Missing seated animation: " + clip)
    print("CASES Godot animations: ", asset_path, " = ", player.get_animation_list())
    _check_meshes(model, skeleton, result)
    _check_animations(player, skeleton, model, result)
    model.free()
    return result

func _check_meshes(model: Node, skeleton: Skeleton3D, result: Dictionary) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model, meshes)
    var retained_source_body := false
    var is_default_character: bool = str(result["path"]).ends_with("cases_suited_negotiator.glb")
    for mesh_node in meshes:
        if mesh_node.name.begins_with("Chair"):
            continue
        if mesh_node.name == "OriginalQuaterniusBody":
            retained_source_body = true
        if is_default_character and mesh_node.name.to_lower().contains("anatomical neck transition"):
            _fail(result, "Replacement neck loft is still rendered alongside the Quaternius source mesh")
        var mesh := mesh_node.mesh
        var bound_skeleton := mesh_node.get_node_or_null(mesh_node.skeleton) as Skeleton3D
        if mesh_node.skin == null or bound_skeleton != skeleton:
            _fail(result, "Skinned character mesh is not bound to the shared skeleton: " + mesh_node.name)
            continue
        result["skinned_mesh_count"] += 1
        if mesh is ArrayMesh:
            var found_weights := false
            for surface in range(mesh.get_surface_count()):
                var arrays := mesh.surface_get_arrays(surface)
                var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
                var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                if weights.is_empty() or vertices.is_empty():
                    continue
                found_weights = true
                var influences := weights.size() / vertices.size()
                if influences <= 0 or weights.size() % vertices.size() != 0 or bones.size() != weights.size():
                    _fail(result, "Malformed weight array on " + mesh_node.name)
                    continue
                for vertex_index in range(vertices.size()):
                    var total := 0.0
                    for influence in range(influences):
                        var slot := vertex_index * influences + influence
                        var weight := weights[slot]
                        total += weight
                        if weight > 0.0001 and (bones[slot] < 0 or bones[slot] >= skeleton.get_bone_count()):
                            _fail(result, "Skin refers to an invalid skeleton bone on " + mesh_node.name)
                            break
                    if absf(total - 1.0) > 0.025:
                        _fail(result, "Non-normalized vertex weights on " + mesh_node.name)
                        break
                result["weighted_surface_count"] += 1
            if not found_weights:
                _fail(result, "Skinned character mesh has no vertex weights: " + mesh_node.name)

        var bounds := mesh.get_aabb().size if mesh != null else Vector3.ZERO
        if mesh_node.name.begins_with("Suit sleeve"):
            result["sleeve_count"] += 1
            var arm_length := maxf(bounds.x, 0.0001)
            if maxf(bounds.y, bounds.z) / arm_length >= 0.47:
                _fail(result, "Sleeve is too bulky for its arm length: " + mesh_node.name + " " + str(bounds))
        elif mesh_node.name.begins_with("Ivory shirt cuff"):
            result["cuff_count"] += 1
            if maxf(bounds.y, bounds.z) >= 0.10:
                _fail(result, "Shirt cuff opening is oversized: " + mesh_node.name + " " + str(bounds))
        elif mesh_node.name.begins_with("Wool trousers"):
            result["trouser_count"] += 1
            if maxf(bounds.x, bounds.z) / maxf(bounds.y, 0.0001) >= 0.25:
                _fail(result, "Trouser leg is too bulky for its length: " + mesh_node.name + " " + str(bounds))
        elif mesh_node.name.begins_with("Leather shoe"):
            result["shoe_count"] += 1
            if maxf(bounds.x, bounds.z) >= 0.24:
                _fail(result, "Dress shoe is oversized: " + mesh_node.name + " " + str(bounds))

    if is_default_character and not retained_source_body:
        _fail(result, "Original Quaternius head skin is missing")
    if result["skinned_mesh_count"] < 15 or result["weighted_surface_count"] < 15:
        _fail(result, "Expected all character and garment meshes to carry normalized skin weights")
    if result["sleeve_count"] != 2 or result["cuff_count"] != 2 or result["trouser_count"] != 2 or result["shoe_count"] != 2:
        _fail(result, "Expected two sleeves, cuffs, trouser legs, and shoes")
    print("CASES skinned meshes / weighted surfaces: ", result["skinned_mesh_count"], " / ", result["weighted_surface_count"])

func _check_animations(player: AnimationPlayer, skeleton: Skeleton3D, model: Node3D, result: Dictionary) -> void:
    var initial_root: Transform3D = model.transform
    var pelvis_index := skeleton.find_bone("pelvis")
    var pelvis_by_clip: Dictionary = {}
    for clip in REQUIRED_ANIMATED_BONES_BY_CLIP:
        if not player.has_animation(clip):
            continue
        var animation: Animation = player.get_animation(clip)
        var length: float = animation.length
        if length <= 0.0:
            _fail(result, "Animation has no duration: " + clip)
            continue
        var required_bones: Array = REQUIRED_ANIMATED_BONES_BY_CLIP[clip]
        var initial_poses: Dictionary = {}
        var changed_bones: Dictionary = {}
        for sample_index in range(SAMPLE_FRACTIONS.size()):
            var sample_time: float = length * SAMPLE_FRACTIONS[sample_index]
            player.play(clip)
            player.seek(sample_time, true)
            player.advance(0.0)
            for bone_name in required_bones:
                var bone_index := skeleton.find_bone(bone_name)
                if bone_index < 0:
                    _fail(result, "Missing required animated bone " + bone_name + " in " + clip)
                    continue
                var pose := skeleton.get_bone_global_pose(bone_index)
                if sample_index == 0:
                    initial_poses[bone_name] = pose
                else:
                    var initial: Transform3D = initial_poses[bone_name]
                    if pose.origin.distance_to(initial.origin) > 0.0005 or not pose.basis.is_equal_approx(initial.basis):
                        changed_bones[bone_name] = true
            if model.transform.origin.distance_to(initial_root.origin) > 0.0001 or not model.transform.basis.is_equal_approx(initial_root.basis):
                _fail(result, "Character root moved during " + clip)
            var pelvis_sample_index := int(round(0.4 * float(SAMPLE_FRACTIONS.size() - 1)))
            if pelvis_index >= 0 and sample_index == pelvis_sample_index:
                pelvis_by_clip[clip] = skeleton.get_bone_global_pose(pelvis_index).origin.y
        var clip_passed: Array[String] = []
        for bone_name in required_bones:
            if not changed_bones.get(bone_name, false):
                _fail(result, "Required bone did not change across sampled " + clip + " frames: " + bone_name)
            else:
                clip_passed.append(bone_name)
        print("CASES animated bones ", clip, ": ", ", ".join(clip_passed), " / ", required_bones.size())
        print("CASES sampled ", SAMPLE_FRACTIONS.size(), " frames from ", clip, " (", length, " sec)")

    if pelvis_by_clip.has("SeatedIdle") and pelvis_by_clip.has("SeatedTalking"):
        var idle_pelvis_y: float = pelvis_by_clip["SeatedIdle"]
        var talking_pelvis_y: float = pelvis_by_clip["SeatedTalking"]
        if absf(idle_pelvis_y - talking_pelvis_y) >= 0.07:
            _fail(result, "Pelvis height differs between seated animations")
        print("CASES pelvis idle / talking: ", idle_pelvis_y, " / ", talking_pelvis_y)
    else:
        _fail(result, "Could not measure pelvis height in both seated animations")
    model.transform = initial_root

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        result.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, result)

func _find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_player(child)
        if found != null:
            return found
    return null

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _fail(result: Dictionary, message: String) -> void:
    (result["failures"] as Array).append(message)
    push_error("FAIL: " + str(result["path"]) + " :: " + message)
