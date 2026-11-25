extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/versailles_room_preview.tscn")
const CLIENT_SCRIPT: Script = preload("res://scripts/game_client.gd")

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var room: Node3D = ROOM_SCENE.instantiate() as Node3D
	root.add_child(room)
	await process_frame

	var seating := room.get_node_or_null("VersaillesRoom/Furniture/NegotiationSeating")
	_expect(seating != null, "Room exposes its negotiation seating")
	if seating == null:
		await _finish(room, null)
		return

	var countries: PackedStringArray = seating.get("participant_countries")
	_expect(countries.size() >= 6, "Six national flags are configured")
	if countries.size() >= 6:
		_expect(countries[1] == "France", "France flag matches the French seat")
		_expect(countries[3] == "China", "China flag matches the Chinese seat")
		_expect(countries[5] == "United Kingdom", "UK flag matches the British seat")

	var client: Node = CLIENT_SCRIPT.new()
	client.call("_populate_delegates", room)
	var roster := {"france": 1, "china": 3, "britain": 5}
	for delegate_id in roster:
		var seat_index: int = roster[delegate_id]
		var seat_name := "Participant_%02d" % (seat_index + 1)
		var seat := seating.get_node_or_null(seat_name) as Node3D
		_expect(seat != null, "%s seat exists" % delegate_id)
		if seat == null:
			continue
		_expect(
			seat.get_node_or_null("Delegate_" + delegate_id) != null,
			"%s delegate is seated in the expected place" % delegate_id
		)
		var chair := seat.get_node_or_null("Chair") as Node3D
		_expect(chair != null and not chair.visible, "%s duplicate chair is hidden" % delegate_id)

	var players: Dictionary = client.get("_delegate_players")
	_expect(players.size() == 3, "All three delegate animation players are registered")
	client.set("_active_delegate_id", "china")
	client.call("_set_actor_talking", true)
	for delegate_id in players:
		var player := players[delegate_id] as AnimationPlayer
		var expected_animation := "SeatedTalking" if delegate_id == "china" else "SeatedIdle"
		_expect(
			player != null and player.current_animation == expected_animation,
			"%s uses the correct speaking animation" % delegate_id
		)

	await _finish(room, client)


func _finish(room: Node3D, client: Node) -> void:
	if client != null:
		client.free()
	room.queue_free()
	await process_frame
	if failures.is_empty():
		print("ROOM INTEGRATION TESTS PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ROOM INTEGRATION TESTS FAIL: %d" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
