extends SceneTree
## Capture a fixed 15-frame sweep for both seated character animations.
## Run: Godot --path godot --script res://tests/capture_seated_animation_frames.gd -- <scene> <absolute-output-dir>

const SAMPLE_COUNT := 15
const CLIPS := ["SeatedIdle", "SeatedTalking"]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Pass a scene path and an absolute output directory after --")
		quit(2)
		return
	var scene_path: String = args[0]
	var output_dir: String = args[1]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load capture scene: " + scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	DisplayServer.window_set_size(Vector2i(1152, 648))
	await process_frame
	await process_frame
	if not _ensure_capture_camera(scene):
		push_error("Capture scene has no active camera or SeatedDemoCameraReference: " + scene_path)
		quit(2)
		return
	await process_frame
	var player := _find_seated_player(scene)
	if player == null:
		push_error("Capture scene has no seated AnimationPlayer: " + scene_path)
		quit(2)
		return
	var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK:
		push_error("Could not create capture directory: " + output_dir)
		quit(2)
		return
	var viewport := root.get_viewport()
	for clip in CLIPS:
		if not player.has_animation(clip):
			push_error("Missing animation " + clip + " in " + scene_path)
			quit(2)
			return
		player.play(clip, 0.0)
		var length := player.get_animation(clip).length
		for sample_index in range(SAMPLE_COUNT):
			await process_frame
			var fraction := float(sample_index) / float(SAMPLE_COUNT - 1)
			player.seek(length * fraction, true)
			player.advance(0.0)
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var filename := "%s_%02d.png" % [clip.to_snake_case().to_lower(), sample_index + 1]
			var save_error := image.save_png(output_dir.path_join(filename))
			if save_error != OK:
				push_error("Could not save animation sample: " + filename)
				quit(2)
				return
			print("CASES Godot visual sample: ", clip, " ", sample_index + 1, "/", SAMPLE_COUNT, " at ", length * fraction, " sec")
	print("CASES Godot animation captures saved: ", output_dir)
	quit(0)

func _find_seated_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		var candidate := node as AnimationPlayer
		if candidate.has_animation("SeatedIdle") and candidate.has_animation("SeatedTalking"):
			return candidate
	for child in node.get_children():
		var found := _find_seated_player(child)
		if found != null:
			return found
	return null

func _ensure_capture_camera(scene: Node) -> bool:
	if root.get_viewport().get_camera_3d() != null:
		return true
	var reference := scene.find_child("SeatedDemoCameraReference", true, false) as Node3D
	if reference == null:
		return false
	var camera := Camera3D.new()
	camera.name = "CASES capture camera"
	camera.fov = 43.0
	scene.add_child(camera)
	camera.global_transform = reference.global_transform
	camera.current = true
	return true
