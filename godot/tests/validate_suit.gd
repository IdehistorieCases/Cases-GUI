extends SceneTree

const REQUIRED_BONES := ["pelvis", "spine_03", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l"]
const SAMPLE_FRACTIONS := [0.0, 0.2, 0.4, 0.6, 0.8, 0.98, 1.0]

var failures: Array[String] = []
var skinned_mesh_count := 0
var weighted_surface_count := 0
var sleeve_count := 0
var cuff_count := 0
var trouser_count := 0
var shoe_count := 0

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load("res://assets/characters/cases_suited_negotiator.glb") as PackedScene
	if packed == null:
		_fail("GLB did not import as a PackedScene")
		_finish()
		return

	var model := packed.instantiate() as Node3D
	root.add_child(model)
	var player := _find_player(model)
	var skeleton := _find_skeleton(model)
	if player == null or skeleton == null:
		_fail("AnimationPlayer or Skeleton3D is missing")
		_finish()
		return

	print("CASES Godot imported skeleton bones: ", skeleton.get_bone_count())
	if skeleton.get_bone_count() != 65:
		_fail("Expected the compatible 65-bone Quaternius skeleton")
	for bone_name in REQUIRED_BONES:
		if skeleton.find_bone(bone_name) < 0:
			_fail("Missing required skeleton bone: " + bone_name)

	for clip in ["SeatedIdle", "SeatedTalking"]:
		if not player.has_animation(clip):
			_fail("Missing seated animation: " + clip)
	print("CASES Godot animation names: ", player.get_animation_list())
	_check_meshes(model, skeleton)
	_check_animations(player, skeleton, model)
	_finish()

func _check_meshes(model: Node, skeleton: Skeleton3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	for mesh_node in meshes:
		if mesh_node.name.begins_with("Chair"):
			continue
		var mesh := mesh_node.mesh
		if mesh_node.skin == null or mesh_node.get_node_or_null(mesh_node.skeleton) != skeleton:
			_fail("Skinned character mesh is not bound to the shared skeleton: " + mesh_node.name)
			continue
		skinned_mesh_count += 1
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
					_fail("Malformed weight array on " + mesh_node.name)
					continue
				for vertex_index in range(vertices.size()):
					var total := 0.0
					for influence in range(influences):
						var slot := vertex_index * influences + influence
						var weight := weights[slot]
						total += weight
						if weight > 0.0001 and (bones[slot] < 0 or bones[slot] >= skeleton.get_bone_count()):
							_fail("Skin refers to an invalid skeleton bone on " + mesh_node.name)
							break
					if absf(total - 1.0) > 0.025:
						_fail("Non-normalized vertex weights on " + mesh_node.name)
						break
				weighted_surface_count += 1
			if not found_weights:
				_fail("Skinned character mesh has no vertex weights: " + mesh_node.name)

		var bounds := mesh.get_aabb().size if mesh != null else Vector3.ZERO
		if mesh_node.name.begins_with("Suit sleeve"):
			sleeve_count += 1
			var arm_length := maxf(bounds.x, 0.0001)
			if maxf(bounds.y, bounds.z) / arm_length >= 0.47:
				_fail("Sleeve is too bulky for its arm length: " + mesh_node.name + " " + str(bounds))
		elif mesh_node.name.begins_with("Ivory shirt cuff"):
			cuff_count += 1
			if maxf(bounds.y, bounds.z) >= 0.10:
				_fail("Shirt cuff opening is oversized: " + mesh_node.name + " " + str(bounds))
		elif mesh_node.name.begins_with("Wool trousers"):
			trouser_count += 1
			if maxf(bounds.x, bounds.z) / maxf(bounds.y, 0.0001) >= 0.25:
				_fail("Trouser leg is too bulky for its length: " + mesh_node.name + " " + str(bounds))
		elif mesh_node.name.begins_with("Leather shoe"):
			shoe_count += 1
			if maxf(bounds.x, bounds.z) >= 0.24:
				_fail("Dress shoe is oversized: " + mesh_node.name + " " + str(bounds))

	if skinned_mesh_count < 15 or weighted_surface_count < 15:
		_fail("Expected all character and garment meshes to carry normalized skin weights")
	if sleeve_count != 2 or cuff_count != 2 or trouser_count != 2 or shoe_count != 2:
		_fail("Expected two sleeves, cuffs, trouser legs, and shoes")
	print("CASES skinned meshes / weighted surfaces: ", skinned_mesh_count, " / ", weighted_surface_count)

func _check_animations(player: AnimationPlayer, skeleton: Skeleton3D, model: Node3D) -> void:
	var initial_root: Transform3D = model.transform
	var pelvis_index := skeleton.find_bone("pelvis")
	var idle_pelvis_y := 0.0
	var talking_pelvis_y := 0.0
	for clip in ["SeatedIdle", "SeatedTalking"]:
		if not player.has_animation(clip):
			continue
		var animation: Animation = player.get_animation(clip)
		var length: float = animation.length
		if length <= 0.0:
			_fail("Animation has no duration: " + clip)
			continue
		var animated_bone := false
		var initial_poses: Dictionary = {}
		var changed_bones: Dictionary = {}
		for sample_index in range(SAMPLE_FRACTIONS.size()):
			var sample_time: float = length * SAMPLE_FRACTIONS[sample_index]
			player.play(clip)
			player.seek(sample_time, true)
			for bone_name in ["upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l"]:
				var bone_index := skeleton.find_bone(bone_name)
				if bone_index < 0:
					continue
				var pose := skeleton.get_bone_global_pose(bone_index)
				if sample_index == 0:
					initial_poses[bone_name] = pose
				elif pose.origin.distance_to((initial_poses[bone_name] as Transform3D).origin) > 0.001 or not pose.basis.is_equal_approx((initial_poses[bone_name] as Transform3D).basis):
					changed_bones[bone_name] = true
			if not changed_bones.is_empty():
				animated_bone = true
			if model.transform.origin.distance_to(initial_root.origin) > 0.0001 or not model.transform.basis.is_equal_approx(initial_root.basis):
				_fail("Character root moved during " + clip)
			if pelvis_index >= 0 and is_equal_approx(SAMPLE_FRACTIONS[sample_index], 0.4):
				if clip == "SeatedIdle":
					idle_pelvis_y = skeleton.get_bone_global_pose(pelvis_index).origin.y
				else:
					talking_pelvis_y = skeleton.get_bone_global_pose(pelvis_index).origin.y
		if not animated_bone:
			_fail("No sampled bone motion applied by " + clip)
		print("CASES sampled ", SAMPLE_FRACTIONS.size(), " frames from ", clip, " (", length, " sec)")

	if absf(idle_pelvis_y - talking_pelvis_y) >= 0.07:
		_fail("Pelvis height differs between seated animations")
	print("CASES pelvis idle / talking: ", idle_pelvis_y, " / ", talking_pelvis_y)
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

func _fail(message: String) -> void:
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("CASES VALIDATION PASS")
		quit(0)
	else:
		print("CASES VALIDATION FAIL (", failures.size(), " issues)")
		quit(1)
