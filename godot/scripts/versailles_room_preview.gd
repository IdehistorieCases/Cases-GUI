extends Node3D
## Places the preview camera at the player's seat after the dynamic roster is built.

func set_player_seat_index(index: int) -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		push_warning("VersaillesRoomPreview: Camera3D was not found.")
		return

	if index < 0:
		if camera.get_parent() != self:
			camera.reparent(self, false)
		camera.transform = Transform3D.IDENTITY
		camera.position = Vector3(2.4, 2.0, 3.0)
		camera.rotation_degrees = Vector3(-5.0, 38.7, 0.0)
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
