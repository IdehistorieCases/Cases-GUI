extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var packed := load("res://assets/characters/cases_suited_negotiator.glb") as PackedScene
    if packed == null:
        push_error("FAIL: exported GLB is not an importable PackedScene")
        quit(1)
        return
    var model := packed.instantiate()
    root.add_child(model)
    var player := _find_player(model)
    var skeleton := _find_skeleton(model)
    if player == null or skeleton == null:
        push_error("FAIL: AnimationPlayer or Skeleton3D missing")
        quit(1)
        return
    print("CASES Godot imported skeleton bones: ", skeleton.get_bone_count())
    print("CASES Godot animation names: ", player.get_animation_list())
    var valid := skeleton.get_bone_count() >= 60
    valid = valid and player.has_animation("SeatedIdle")
    valid = valid and player.has_animation("SeatedTalking")
    if valid:
        var hip_idx: int = skeleton.find_bone("pelvis")
        var rest_hip: Vector3 = skeleton.get_bone_global_rest(hip_idx).origin
        player.play("SeatedIdle")
        player.seek(0.5, true)
        var idle_hip: Vector3 = skeleton.get_bone_global_pose(hip_idx).origin
        print("CASES seated idle animation applied: ", player.current_animation)
        player.play("SeatedTalking")
        player.seek(0.5, true)
        var talk_hip: Vector3 = skeleton.get_bone_global_pose(hip_idx).origin
        print("CASES seated speaking animation applied: ", player.current_animation)
        print("CASES pelvis rest / idle / talking: ", rest_hip, " / ", idle_hip, " / ", talk_hip)
        valid = hip_idx >= 0 and absf(rest_hip.y-idle_hip.y) > 0.20
        valid = valid and absf(idle_hip.y-talk_hip.y) < 0.07
    print("CASES VALIDATION ", "PASS" if valid else "FAIL")
    quit(0 if valid else 1)

func _find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for c in node.get_children():
        var result := _find_player(c)
        if result != null:
            return result
    return null

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for c in node.get_children():
        var result := _find_skeleton(c)
        if result != null:
            return result
    return null
