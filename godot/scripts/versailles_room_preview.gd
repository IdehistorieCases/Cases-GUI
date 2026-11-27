extends Node3D
## Places the preview camera at the player's seat after the dynamic roster is built.

const DEFAULT_CAMERA_POSITION := Vector3(2.4, 2.0, 3.0)
const DEFAULT_CAMERA_ROTATION_DEGREES := Vector3(-5.0, 38.7, 0.0)


func _ready() -> void:
	_get_preview_camera().current = true


func set_player_seat_index(index: int) -> void:
	var camera := _get_preview_camera()

	if index < 0:
		if camera.get_parent() != self:
			camera.reparent(self, false)
		camera.transform = Transform3D.IDENTITY
		camera.position = DEFAULT_CAMERA_POSITION
		camera.rotation_degrees = DEFAULT_CAMERA_ROTATION_DEGREES
		camera.current = true
		return

	var seating := get_node_or_null("VersaillesRoom/Furniture/NegotiationSeating")
	if seating == null:
		push_warning("VersaillesRoomPreview: negotiation seating was not found.")
		return
	var seat := seating.get_node_or_null("Participant_%02d" % (index + 1))
	if seat == null:
		push_warning("VersaillesRoomPreview: player seat was not found.")
		return
	var eye := seat.get_node_or_null("PlayerEye") as Marker3D
	if eye == null:
		push_warning("VersaillesRoomPreview: player eye marker was not found.")
		return

	if camera.get_parent() != eye:
		camera.reparent(eye, false)
	camera.transform = Transform3D.IDENTITY
	camera.fov = 78.0
	camera.current = true
	var room := get_node_or_null("VersaillesRoom") as Node3D
	if room != null:
		camera.look_at(room.to_global(Vector3(0.0, 1.26, 0.0)), Vector3.UP)


func _get_preview_camera() -> Camera3D:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		# The seated view reparents this node under PlayerEye. Find it there on
		# subsequent roster rebuilds instead of treating it as a missing camera.
		camera = find_child("Camera3D", true, false) as Camera3D
	if camera == null:
		# Keep the room visible if a scene edit or stale resource removes the camera.
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
		camera.position = DEFAULT_CAMERA_POSITION
		camera.rotation_degrees = DEFAULT_CAMERA_ROTATION_DEGREES
		push_warning("VersaillesRoomPreview: Camera3D was missing; created a preview camera.")
	return camera
