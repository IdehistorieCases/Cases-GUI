extends SceneTree

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var client_script: Script = load("res://scripts/game_client.gd")
	var client: Node = client_script.new()
	client.call("_build_interface")

	var canvas := client.get_node_or_null("GameInterface") as CanvasLayer
	_expect(canvas != null, "HUD CanvasLayer is created")
	_expect(canvas != null and canvas.layer == 10, "HUD draws above the room")
	_expect(
		client.get_node_or_null("GameInterface/HudRoot/HudSafeArea/HudLayout/TopBar") != null,
		"Top bar is present"
	)
	_expect(
		client.get_node_or_null(
			"GameInterface/HudRoot/HudSafeArea/HudLayout/HudContent/BriefingSidebar"
		) != null,
		"Briefing sidebar is present"
	)
	_expect(
		client.get_node_or_null(
			"GameInterface/HudRoot/HudSafeArea/HudLayout/HudContent/NegotiationPanel"
		) != null,
		"Negotiation panel is present"
	)
	var sidebar := _find_named(client, "BriefingSidebar") as Control
	var negotiation := _find_named(client, "NegotiationPanel") as Control
	_expect(
		sidebar != null
			and sidebar.size_flags_horizontal == Control.SIZE_EXPAND_FILL
			and is_equal_approx(sidebar.size_flags_stretch_ratio, 0.25),
		"Briefing column scales proportionally on wide displays"
	)
	_expect(
		negotiation != null
			and negotiation.size_flags_horizontal == Control.SIZE_EXPAND_FILL
			and is_equal_approx(negotiation.size_flags_stretch_ratio, 0.75),
		"Conversation panel receives the remaining responsive width"
	)

	var hud_root := client.get_node_or_null("GameInterface/HudRoot") as Control
	_expect(
		hud_root != null and hud_root.mouse_filter == Control.MOUSE_FILTER_PASS,
		"HUD background does not block clicks"
	)

	var objective := _find_named(client, "ObjectiveCard") as Control
	_expect(objective != null, "Objective card is present")
	var actions := _find_named(client, "NegotiationActions") as VBoxContainer
	var start_button := client.get("_new_session_button") as Button
	_expect(
		actions != null and start_button != null and start_button.get_parent() == actions,
		"Session actions stay outside the scrollable briefing"
	)
	_expect(start_button != null and start_button.visible, "Start action remains visible")
	var turn_status := client.get("_turn_status_label") as Label
	client.set("_backend_ready", true)
	client.call("_update_session_label")
	_expect(
		turn_status != null and turn_status.text == "KLAR TIL AT STARTE",
		"Round status updates after backend connection"
	)
	var connection_details := _find_named(client, "ConnectionDetails") as Control
	var connection_toggle := client.get("_connection_toggle_button") as Button
	_expect(
		connection_details != null and not connection_details.visible,
		"Technical details start collapsed"
	)
	if connection_details != null and connection_toggle != null:
		connection_toggle.emit_signal("pressed")
		_expect(connection_details.visible, "Technical details open from their button")
		connection_toggle.emit_signal("pressed")
		_expect(not connection_details.visible, "Technical details close from their button")

	var transcript := _find_named(client, "Transcript") as VBoxContainer
	_expect(transcript != null, "Transcript container is present")
	if transcript != null:
		var old_count := transcript.get_child_count()
		client.call("_add_message", "HUD TEST", "Message card", "system")
		_expect(
			transcript.get_child_count() == old_count + 1,
			"New transcript message adds one speaker card"
		)

	client.free()
	if failures.is_empty():
		print("GAME HUD TESTS PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAME HUD TESTS FAIL: %d" % failures.size())
		quit(1)


func _find_named(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found: Node = _find_named(child, target_name)
		if found != null:
			return found
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
