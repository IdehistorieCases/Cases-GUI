extends Node

## First playable network path for the existing seated negotiator prototype.
## The backend remains authoritative for scenario state and generated dialogue.

const BACKEND_API_SCRIPT = preload("res://scripts/cases_backend_api.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/versailles_room_preview.tscn")
const BRITISH_DELEGATE: PackedScene = preload("res://assets/characters/cases_suited_negotiator.glb")
const FRENCH_DELEGATE: PackedScene = preload("res://assets/characters/cases_suited_negotiator_senior_mediator.glb")
const CHINESE_DELEGATE: PackedScene = preload("res://assets/characters/cases_suited_negotiator_scholarly_delegate.glb")
const SCENARIO_SLUG := "versailles-1919"
const PINNED_SCENARIO_VERSION := "3.1-negotiation-ai"
const PLAYER_ROLE_ID := "british_adviser"
const NARRATOR_ID := "gpt6_luna_high"
const SESSION_STORE_PATH := "user://cases_sessions.json"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:18082"
const DEFAULT_WEB_BACKEND_URL := "https://marcus-computer.taile97c31.ts.net"
const INITIALIZATION_POLL_LIMIT := 180
const TURN_POLL_LIMIT := 360
const REFLECTION_REQUEST_TIMEOUT_SECONDS := 300.0

const COLOR_GOLD := Color(0.79, 0.64, 0.39, 1.0)
const COLOR_TEXT := Color(0.91, 0.89, 0.83, 1.0)
const COLOR_MUTED := Color(0.62, 0.65, 0.65, 1.0)
const COLOR_GREEN := Color(0.53, 0.78, 0.61, 1.0)
const COLOR_RED := Color(0.87, 0.49, 0.44, 1.0)
const COLOR_AMBER := Color(0.91, 0.72, 0.39, 1.0)

var _api: Node
var _room: Node3D
var _store: Dictionary = {"sessions": [], "current_session_local_id": "", "base_url": ""}
var _session_store_path := SESSION_STORE_PATH
var _api_base_url := DEFAULT_BACKEND_URL
var _scenario: Dictionary = {}
var _player_role: Dictionary = {}
var _opening: Dictionary = {}
var _turns: Array = []
var _session_snapshot: Dictionary = {}
var _narrator_ready := false
var _backend_ready := false
var _scenario_available := false
var _operation_in_progress := false
var _session_completed := false
var _current_turn_number := 0

var _endpoint_input: LineEdit
var _header_status: Label
var _sidebar_status: Label
var _scenario_title_label: Label
var _scenario_summary_label: Label
var _role_title_label: Label
var _role_intro_label: Label
var _narrator_status_label: Label
var _briefing_tension_label: Label
var _briefing_goal_label: Label
var _session_id_label: Label
var _issue_board_container: VBoxContainer
var _transcript_column: VBoxContainer
var _next_prompt_label: Label
var _composer: TextEdit
var _connect_button: Button
var _new_session_button: Button
var _resume_button: Button
var _retry_opening_button: Button
var _retry_turn_button: Button
var _complete_button: Button
var _retry_reflection_button: Button
var _send_button: Button
var _composer_row: HBoxContainer
var _results_panel: PanelContainer
var _results_status_label: Label
var _results_scroll: ScrollContainer
var _results_content: VBoxContainer
var _simulation_badge: Label
var _turn_status_label: Label
var _connection_details: VBoxContainer
var _connection_toggle_button: Button
var _latest_turn_request_id := ""
var _reflection_retry_pending := false
var _reflection_failed_permanently := false
var _reflection_loading := false
var _reflection_error := ""
var _reflection_result: Dictionary = {}
var _delegate_players: Dictionary = {}
var _active_delegate_id := "france"


func _ready() -> void:
	_room = ROOM_SCENE.instantiate() as Node3D
	_room.name = "VersaillesNegotiationRoom"
	add_child(_room)

	_api = BACKEND_API_SCRIPT.new()
	_api.name = "CasesBackendApi"
	add_child(_api)

	_load_store()
	_build_interface()
	_api.call("set_base_url", _api_base_url)
	_connect_backend()


func _populate_delegates(room: Node3D, scenario: Dictionary) -> void:
	var seating := room.get_node_or_null("VersaillesRoom/Furniture/NegotiationSeating")
	if seating == null:
		push_warning("CASES: room seating was not found; delegates will not be shown.")
		return

	var actors: Variant = scenario.get("actors", [])
	if not actors is Array or actors.size() != 3:
		push_warning("CASES: pinned three-party scenario must contain exactly three delegations.")
		return

	var country_by_actor := {
		"britain": "United Kingdom",
		"france": "France",
		"china": "China",
	}
	var label_by_actor := {
		"britain": "Storbritannien",
		"france": "Frankrig",
		"china": "Kina",
	}
	var scene_by_actor := {
		"britain": BRITISH_DELEGATE,
		"france": FRENCH_DELEGATE,
		"china": CHINESE_DELEGATE,
	}
	var countries := PackedStringArray()
	var seen_actor_ids: Dictionary = {}
	for actor_data in actors:
		if not actor_data is Dictionary:
			push_warning("CASES: scenario contains an invalid actor entry.")
			return
		var actor_id := str(actor_data.get("id", ""))
		if (
			not country_by_actor.has(actor_id)
			or not scene_by_actor.has(actor_id)
			or seen_actor_ids.has(actor_id)
		):
			push_warning("CASES: invalid or repeated actor in pinned three-party roster: %s" % actor_id)
			return
		seen_actor_ids[actor_id] = true
		countries.append(country_by_actor[actor_id])
	if seen_actor_ids.size() != country_by_actor.size():
		push_warning("CASES: pinned three-party roster must include Britain, France and China.")
		return

	# Detach before rebuilding seats so the camera is not freed with its old marker.
	room.call("set_player_seat_index", -1)
	# Rebuild seating from the same ordered actor list used for the delegate models.
	seating.set("participant_count", 0)
	seating.set("participant_countries", countries)
	seating.set("participant_count", actors.size())
	_delegate_players.clear()
	var player_seat_index := -1

	for index in range(actors.size()):
		var actor_data: Dictionary = actors[index]
		var actor_id := str(actor_data.get("id", ""))
		var seat_name := "Participant_%02d" % (index + 1)
		var seat: Node3D = seating.get_node_or_null(seat_name) as Node3D
		if seat == null:
			push_warning("CASES: missing seat %s for %s." % [seat_name, actor_id])
			continue
		var is_player_seat := actor_id == "britain"
		if is_player_seat:
			player_seat_index = index
		var chair := seat.get_node_or_null("Chair")
		if chair != null:
			chair.visible = is_player_seat # The player's empty chair remains visible.
		var delegate_scene: PackedScene = scene_by_actor[actor_id]
		var actor: Node3D = delegate_scene.instantiate() as Node3D
		if actor == null:
			continue
		actor.name = "Delegate_" + actor_id
		actor.position = Vector3.ZERO
		actor.visible = not is_player_seat
		seat.add_child(actor)
		var animation_player := _find_animation_player(actor)
		if animation_player != null and animation_player.has_animation("SeatedIdle"):
			animation_player.play("SeatedIdle")
			_delegate_players[actor_id] = animation_player
		if not is_player_seat:
			var nameplate := Label3D.new()
			nameplate.name = "DelegateNameplate"
			nameplate.text = label_by_actor[actor_id]
			nameplate.position = Vector3(0.0, 2.05, 0.0)
			nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			nameplate.font_size = 24
			nameplate.pixel_size = 0.006
			nameplate.outline_size = 4
			nameplate.modulate = Color(0.96, 0.88, 0.67, 1.0)
			seat.add_child(nameplate)

	room.call("set_player_seat_index", player_seat_index)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null


func _load_store() -> void:
	if FileAccess.file_exists(_session_store_path):
		var file := FileAccess.open(_session_store_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_store = parsed
	if not (_store.get("sessions", []) is Array):
		_store["sessions"] = []
	if not _store.has("current_session_local_id"):
		_store["current_session_local_id"] = ""

	var environment_url := OS.get_environment("CASES_API_BASE_URL").strip_edges()
	if not environment_url.is_empty():
		_api_base_url = environment_url.trim_suffix("/")
	else:
		var saved_url := str(_store.get("base_url", "")).strip_edges()
		var default_url := DEFAULT_WEB_BACKEND_URL if OS.has_feature("web") else DEFAULT_BACKEND_URL
		_api_base_url = saved_url.trim_suffix("/") if not saved_url.is_empty() else default_url


func _save_store() -> void:
	_store["base_url"] = _api_base_url
	var file := FileAccess.open(_session_store_path, FileAccess.WRITE)
	if file == null:
		_set_status(
			"Kunne ikke gemme den lokale session (%d)." % FileAccess.get_open_error(),
			"error"
		)
		return
	file.store_string(JSON.stringify(_store))


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameInterface"
	canvas.layer = 10
	add_child(canvas)

	var screen := Control.new()
	screen.name = "HudRoot"
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(screen)

	var scrim := ColorRect.new()
	scrim.color = Color(0.025, 0.035, 0.043, 0.03)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(scrim)

	var header := _build_header()
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.offset_left = 22
	header.offset_top = 18
	header.offset_right = -22
	header.offset_bottom = 80
	screen.add_child(header)

	var sidebar := _build_sidebar()
	sidebar.anchor_left = 0.0
	sidebar.anchor_right = 0.0
	sidebar.anchor_top = 0.0
	sidebar.anchor_bottom = 1.0
	sidebar.offset_left = 22
	sidebar.offset_top = 92
	sidebar.offset_right = 322
	sidebar.offset_bottom = -18
	screen.add_child(sidebar)

	var conversation := _build_conversation()
	conversation.anchor_left = 0.0
	conversation.anchor_right = 1.0
	conversation.anchor_top = 0.50
	conversation.anchor_bottom = 1.0
	conversation.offset_left = 340
	conversation.offset_top = 0
	conversation.offset_right = -22
	conversation.offset_bottom = -18
	screen.add_child(conversation)

	_update_session_label()
	_update_controls()


func _build_header() -> PanelContainer:
	var panel := _make_panel(Color(0.075, 0.09, 0.10, 0.96), COLOR_GOLD)
	panel.name = "TopBar"
	panel.custom_minimum_size = Vector2(0, 62)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_theme_constant_override("margin_left", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	margin.add_child(row)

	var brand := VBoxContainer.new()
	brand.custom_minimum_size = Vector2(158, 0)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	brand.add_theme_constant_override("separation", 0)
	brand.add_child(_make_label("CASES", 20, COLOR_GOLD, true))
	brand.add_child(_make_label("PARIS · 1919", 11, COLOR_MUTED, true))
	row.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_header_status = _make_label("Forbinder …", 13, COLOR_AMBER, true)
	_header_status.custom_minimum_size = Vector2(168, 0)
	_header_status.size_flags_horizontal = Control.SIZE_SHRINK_END
	_header_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_header_status)

	_connect_button = _make_button("Forbind igen", false)
	_connect_button.custom_minimum_size = Vector2(132, 38)
	_connect_button.pressed.connect(_connect_backend)
	row.add_child(_connect_button)
	return panel


func _build_sidebar() -> PanelContainer:
	var panel := _make_panel(Color(0.075, 0.09, 0.10, 0.95), Color(0.35, 0.33, 0.27, 1.0))
	panel.name = "BriefingSidebar"
	panel.custom_minimum_size = Vector2(292, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.25
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var sidebar_layout := VBoxContainer.new()
	sidebar_layout.name = "SidebarLayout"
	sidebar_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_layout.add_theme_constant_override("separation", 9)
	margin.add_child(sidebar_layout)

	var scroll := ScrollContainer.new()
	scroll.name = "BriefingScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_layout.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)

	column.add_child(_make_label("SCENARIET", 11, COLOR_GOLD, true))
	_scenario_title_label = _make_label("Fredskonferencen i Paris", 18, COLOR_TEXT, true)
	column.add_child(_scenario_title_label)
	_scenario_summary_label = _make_label(
		"Henter oplæg …",
		12,
		COLOR_MUTED
	)
	column.add_child(_scenario_summary_label)
	column.add_child(_make_separator())
	column.add_child(_make_label("DIN ROLLE", 11, COLOR_GOLD, true))
	_role_title_label = _make_label("Britisk rådgiver", 15, COLOR_TEXT, true)
	column.add_child(_role_title_label)
	_role_intro_label = _make_label(
		"Du rådgiver Storbritannien ved fredsforhandlingerne.",
		12,
		COLOR_MUTED
	)
	column.add_child(_role_intro_label)

	var briefing_card := _make_panel(Color(0.13, 0.12, 0.095, 0.94), Color(0.49, 0.40, 0.24, 1.0))
	briefing_card.name = "ObjectiveCard"
	var briefing_margin := MarginContainer.new()
	briefing_margin.add_theme_constant_override("margin_left", 12)
	briefing_margin.add_theme_constant_override("margin_top", 10)
	briefing_margin.add_theme_constant_override("margin_right", 12)
	briefing_margin.add_theme_constant_override("margin_bottom", 10)
	briefing_card.add_child(briefing_margin)
	var briefing_column := VBoxContainer.new()
	briefing_column.add_theme_constant_override("separation", 5)
	briefing_margin.add_child(briefing_column)
	briefing_column.add_child(_make_label("DIT MÅL", 10, COLOR_GOLD, true))
	_briefing_tension_label = _make_label(
		"Dit mål vises, når forhandlingen starter.",
		14,
		COLOR_TEXT,
		true
	)
	briefing_column.add_child(_briefing_tension_label)
	_briefing_goal_label = _make_label("", 12, COLOR_MUTED)
	briefing_column.add_child(_briefing_goal_label)
	column.add_child(briefing_card)

	column.add_child(_make_label("FORHANDLINGSPUNKTER", 10, COLOR_GOLD, true))
	_issue_board_container = VBoxContainer.new()
	_issue_board_container.name = "TreatyIssueBoard"
	_issue_board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_issue_board_container.add_theme_constant_override("separation", 6)
	column.add_child(_issue_board_container)
	column.add_child(
		_make_label(
			"Din rolle er rådgiver. Forslag er ikke bindende aftaler.",
			10,
			COLOR_AMBER
		)
	)

	_connection_details = VBoxContainer.new()
	_connection_details.name = "ConnectionDetails"
	_connection_details.visible = false
	_connection_details.add_theme_constant_override("separation", 7)
	column.add_child(_connection_details)
	_connection_details.add_child(_make_label("BACKEND-ADRESSE", 10, COLOR_GOLD, true))
	_endpoint_input = LineEdit.new()
	_endpoint_input.text = _api_base_url
	_endpoint_input.placeholder_text = "https://server.example.dk"
	_endpoint_input.custom_minimum_size = Vector2(0, 38)
	_endpoint_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connection_details.add_child(_endpoint_input)
	_sidebar_status = _make_label("Backend kontrolleres …", 12, COLOR_AMBER)
	_connection_details.add_child(_sidebar_status)
	_narrator_status_label = _make_label("ChatGPT 6 Luna: kontrolleres …", 12, COLOR_MUTED)
	_connection_details.add_child(_narrator_status_label)

	var actions := VBoxContainer.new()
	actions.name = "NegotiationActions"
	actions.add_theme_constant_override("separation", 6)
	sidebar_layout.add_child(actions)
	_session_id_label = _make_label("Ingen forhandling endnu", 11, COLOR_MUTED)
	actions.add_child(_session_id_label)

	_new_session_button = _make_button("Start forhandling", true)
	_new_session_button.custom_minimum_size = Vector2(0, 42)
	_new_session_button.pressed.connect(_start_new_session)
	actions.add_child(_new_session_button)

	_resume_button = _make_button("Fortsæt gemt spil", false)
	_resume_button.custom_minimum_size = Vector2(0, 38)
	_resume_button.pressed.connect(_resume_saved_session)
	actions.add_child(_resume_button)

	_retry_opening_button = _make_button("Prøv åbningen igen", false)
	_retry_opening_button.custom_minimum_size = Vector2(0, 36)
	_retry_opening_button.visible = false
	_retry_opening_button.pressed.connect(_retry_opening)
	actions.add_child(_retry_opening_button)

	_retry_turn_button = _make_button("Prøv svaret igen", false)
	_retry_turn_button.custom_minimum_size = Vector2(0, 36)
	_retry_turn_button.visible = false
	_retry_turn_button.pressed.connect(_retry_turn)
	actions.add_child(_retry_turn_button)

	_connection_toggle_button = _make_button("Forbindelse", false)
	_connection_toggle_button.custom_minimum_size = Vector2(0, 34)
	_connection_toggle_button.pressed.connect(_toggle_connection_details)
	actions.add_child(_make_separator())
	actions.add_child(_connection_toggle_button)
	return panel


func _build_conversation() -> PanelContainer:
	var panel := _make_panel(Color(0.075, 0.09, 0.10, 0.92), Color(0.35, 0.33, 0.27, 1.0))
	panel.name = "NegotiationPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.75
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_block.add_theme_constant_override("separation", 1)
	title_block.add_child(_make_label("FORHANDLING", 14, COLOR_GOLD, true))
	title_block.add_child(_make_label("Skriv et forslag. De andre delegationer svarer.", 12, COLOR_MUTED))
	top.add_child(title_block)

	var status_block := VBoxContainer.new()
	status_block.custom_minimum_size = Vector2(204, 0)
	status_block.size_flags_horizontal = Control.SIZE_SHRINK_END
	status_block.add_theme_constant_override("separation", 2)
	status_block.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(status_block)
	_turn_status_label = _make_label("KLAR TIL START", 12, COLOR_GOLD, true)
	_turn_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_block.add_child(_turn_status_label)
	_simulation_badge = _make_label("FIKTIV FORHANDLING", 10, COLOR_AMBER, true)
	_simulation_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_block.add_child(_simulation_badge)

	var divider := _make_separator()
	column.add_child(divider)

	var transcript_scroll := ScrollContainer.new()
	transcript_scroll.name = "TranscriptScroll"
	transcript_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(transcript_scroll)

	_transcript_column = VBoxContainer.new()
	_transcript_column.name = "Transcript"
	_transcript_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript_column.add_theme_constant_override("separation", 9)
	transcript_scroll.add_child(_transcript_column)
	_add_message(
		"KLAR TIL FORHANDLING",
		"Start forhandlingen for at læse oplægget.",
		"system"
	)

	_next_prompt_label = _make_label(
		"Dit forslag og delegationernes svar vises her.",
		12,
		COLOR_MUTED
	)
	_next_prompt_label.name = "PromptHint"
	_next_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_next_prompt_label)

	_composer_row = HBoxContainer.new()
	_composer_row.name = "ComposerRow"
	_composer_row.add_theme_constant_override("separation", 10)
	column.add_child(_composer_row)

	_composer = TextEdit.new()
	_composer.name = "ProposalComposer"
	_composer.custom_minimum_size = Vector2(0, 82)
	_composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_composer.placeholder_text = "Skriv dit forslag …"
	_composer.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_composer.add_theme_color_override("font_color", COLOR_TEXT)
	_composer.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	_composer.add_theme_stylebox_override(
		"normal",
		_make_style(Color(0.045, 0.058, 0.066, 0.96), Color(0.28, 0.31, 0.31, 1.0), 8)
	)
	_composer.add_theme_stylebox_override(
		"focus",
		_make_style(Color(0.045, 0.058, 0.066, 0.98), COLOR_GOLD, 8)
	)
	_composer_row.add_child(_composer)

	_send_button = _make_button("Send forslag", true)
	_send_button.name = "SendProposalButton"
	_send_button.tooltip_text = "Send forslaget til de andre delegationer."
	_send_button.custom_minimum_size = Vector2(136, 82)
	_send_button.pressed.connect(_submit_turn)
	_composer_row.add_child(_send_button)

	_complete_button = _make_button("Afslut forhandling", false)
	_complete_button.name = "CompleteSessionButton"
	_complete_button.tooltip_text = "Afslut forhandlingen og gå til refleksionen."
	_complete_button.custom_minimum_size = Vector2(132, 82)
	_complete_button.pressed.connect(_complete_session)
	_composer_row.add_child(_complete_button)

	_results_panel = _make_panel(Color(0.085, 0.11, 0.105, 0.96), Color(0.38, 0.53, 0.41, 1.0))
	_results_panel.name = "ResultsReflectionPanel"
	_results_panel.custom_minimum_size = Vector2(0, 184)
	_results_panel.visible = false
	column.add_child(_results_panel)
	var results_margin := MarginContainer.new()
	results_margin.add_theme_constant_override("margin_left", 14)
	results_margin.add_theme_constant_override("margin_top", 10)
	results_margin.add_theme_constant_override("margin_right", 14)
	results_margin.add_theme_constant_override("margin_bottom", 10)
	_results_panel.add_child(results_margin)
	var results_column := VBoxContainer.new()
	results_column.add_theme_constant_override("separation", 6)
	results_margin.add_child(results_column)
	_results_status_label = _make_label("REFLEKSION", 12, COLOR_GOLD, true)
	_results_status_label.name = "ReflectionStatus"
	results_column.add_child(_results_status_label)
	_results_scroll = ScrollContainer.new()
	_results_scroll.name = "ResultsScroll"
	_results_scroll.custom_minimum_size = Vector2(0, 112)
	_results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_column.add_child(_results_scroll)
	_results_content = VBoxContainer.new()
	_results_content.name = "ResultsContent"
	_results_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_content.add_theme_constant_override("separation", 8)
	_results_scroll.add_child(_results_content)
	_retry_reflection_button = _make_button("Hent refleksion igen", false)
	_retry_reflection_button.name = "RetryReflectionButton"
	_retry_reflection_button.custom_minimum_size = Vector2(0, 34)
	_retry_reflection_button.visible = false
	_retry_reflection_button.pressed.connect(_request_reflection)
	results_column.add_child(_retry_reflection_button)
	return panel


func _make_label(
	text_value: String,
	font_size: int,
	color: Color,
	bold: bool = false
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_GOLD if bold and color == COLOR_TEXT else color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	return label


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("color", Color(0.36, 0.34, 0.29, 0.75))
	return separator


func _make_panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var hud_background := background
	hud_background.a = minf(hud_background.a, 0.62)
	panel.add_theme_stylebox_override("panel", _make_style(hud_background, border, 12))
	return panel


func _make_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 9
	style.content_margin_top = 7
	style.content_margin_right = 9
	style.content_margin_bottom = 7
	return style


func _make_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.45, 1))
	var base := Color(0.29, 0.23, 0.14, 0.98) if primary else Color(0.11, 0.14, 0.15, 0.98)
	var border := COLOR_GOLD if primary else Color(0.31, 0.34, 0.33, 1)
	button.add_theme_stylebox_override("normal", _make_style(base, border, 8))
	button.add_theme_stylebox_override("hover", _make_style(base.lightened(0.12), COLOR_GOLD, 8))
	button.add_theme_stylebox_override("pressed", _make_style(base.darkened(0.12), border, 8))
	button.add_theme_stylebox_override(
		"disabled",
		_make_style(Color(0.10, 0.11, 0.11, 0.96), Color(0.24, 0.25, 0.23, 1), 8)
	)
	button.add_theme_stylebox_override("focus", _make_style(base, COLOR_GOLD, 8))
	return button


func _connect_backend() -> void:
	if _operation_in_progress:
		return
	var candidate := _endpoint_input.text.strip_edges().trim_suffix("/") if _endpoint_input != null else _api_base_url
	if not _is_safe_endpoint(candidate):
		_set_status(
			"Brug HTTPS til en ekstern server. Almindelig HTTP er kun tilladt på localhost.",
			"error"
		)
		return

	_api_base_url = candidate
	_api.call("set_base_url", _api_base_url)
	_save_store()
	_set_busy(true)
	_set_status("Kontrollerer backend …", "working")

	var health: Dictionary = await _api.call("get_json", "/healthz", "")
	if not health.get("ok", false):
		_backend_ready = false
		_scenario_available = false
		_set_status("Backend kan ikke nås: %s" % health.get("error", "Ukendt netværksfejl"), "error")
		_set_busy(false)
		return

	var ready: Dictionary = await _api.call("get_json", "/readyz", "")
	if not ready.get("ok", false) or not ready.get("data", {}).get("database", false):
		_backend_ready = false
		_scenario_available = false
		_set_status("Backend svarer, men databasen er ikke klar.", "error")
		_set_busy(false)
		return
	_backend_ready = true

	var scenario_response: Dictionary = await _api.call(
		"get_json",
		"/api/v1/scenarios/" + SCENARIO_SLUG,
		""
	)
	if not scenario_response.get("ok", false):
		_scenario_available = false
		_set_status(
			"Backend er klar, men Versailles-sagen kunne ikke indlæses: %s"
			% scenario_response.get("error", "Ukendt fejl"),
			"error"
		)
		_set_busy(false)
		return

	_scenario = scenario_response.get("data", {})
	if str(_scenario.get("version", "")) != PINNED_SCENARIO_VERSION:
		_scenario_available = false
		_set_status(
			"Forkert scenarieversion: forventede %s, men backend har %s."
			% [PINNED_SCENARIO_VERSION, str(_scenario.get("version", "ukendt"))],
			"error"
		)
		_set_busy(false)
		return
	_scenario_available = not _scenario.is_empty()
	_update_scenario_labels()
	_update_issue_board()
	if _room != null:
		_populate_delegates(_room, _scenario)

	var narrators: Dictionary = await _api.call("get_json", "/api/v1/narrators", "")
	_narrator_ready = false
	if narrators.get("ok", false) and narrators.get("data") is Array:
		for narrator in narrators["data"]:
			if narrator is Dictionary and narrator.get("id") == NARRATOR_ID:
				_narrator_ready = bool(narrator.get("ready", false))
				break
	if _narrator_ready:
		_narrator_status_label.text = "ChatGPT 6 Luna: klar"
		_narrator_status_label.add_theme_color_override("font_color", COLOR_GREEN)
	else:
		_narrator_status_label.text = "ChatGPT 6 Luna: ikke klar endnu — åbningen kan fejle"
		_narrator_status_label.add_theme_color_override("font_color", COLOR_AMBER)

	print(
		"CASES backend ready: %s/%s; gpt6_luna_high_ready=%s"
		% [str(_scenario.get("slug", "")), str(_scenario.get("version", "")), str(_narrator_ready)]
	)
	_set_status("Backend og database er klar.", "ok")
	_sidebar_status.text = "Forbundet · %s" % _api_base_url
	_sidebar_status.add_theme_color_override("font_color", COLOR_GREEN)
	_update_session_label()
	_set_busy(false)


func _is_safe_endpoint(value: String) -> bool:
	if value.is_empty() or value.contains("@") or value.contains("?") or value.contains("#"):
		return false
	var lower := value.to_lower()
	if lower.begins_with("https://"):
		return true
	if lower == "http://localhost" or lower.begins_with("http://localhost:"):
		return true
	if lower == "http://127.0.0.1" or lower.begins_with("http://127.0.0.1:"):
		return true
	return false


func _update_scenario_labels() -> void:
	var metadata: Dictionary = _scenario.get("metadata", {})
	var full_title := str(metadata.get("title", "Fredskonferencen i Paris")).strip_edges()
	var is_versailles := SCENARIO_SLUG == "versailles-1919"
	var display_title := full_title
	if is_versailles:
		display_title = "Fredskonferencen i Paris"
	else:
		var title_separator := full_title.find(":")
		if title_separator >= 0:
			display_title = full_title.substr(0, title_separator).strip_edges()
	_scenario_title_label.text = display_title
	_scenario_title_label.tooltip_text = "Paris, 1919" if is_versailles else full_title
	_scenario_summary_label.text = (
		"Paris, 1919. Forhandl om, hvordan freden skal se ud efter krigen."
		if is_versailles
		else str(metadata.get("summary", "Samtalerne tager udgangspunkt i fredsforhandlingerne i Paris."))
	)
	_player_role = {}
	var roles: Array = _scenario.get("roles", [])
	for role in roles:
		if role is Dictionary and role.get("id") == PLAYER_ROLE_ID:
			_player_role = role
			break
	if not _player_role.is_empty():
		_role_title_label.text = (
			"Britisk rådgiver"
			if is_versailles
			else str(_player_role.get("title", "Britisk rådgiver"))
		)
		_role_intro_label.text = (
			"Du rådgiver Storbritannien ved fredsforhandlingerne."
			if is_versailles
			else str(_player_role.get("introduction", "Du rådgiver en delegation ved fredsforhandlingerne."))
		)
		_role_intro_label.add_theme_font_size_override("font_size", 12)
	else:
		_role_title_label.text = "Den britiske rolle mangler"
		_role_intro_label.text = "Tjek, at scenariet er hentet korrekt fra serveren."


func _start_new_session() -> void:
	if _operation_in_progress or not _backend_ready or not _scenario_available:
		return
	if not _current_record().is_empty() and str(_current_record().get("session_id", "")).is_empty():
		_set_status("Genoptag først den igangværende oprettelse.", "error")
		return

	_session_completed = false
	_reflection_retry_pending = false
	_reflection_failed_permanently = false
	_reflection_loading = false
	_reflection_error = ""
	_reflection_result = {}
	var record := {
		"local_id": _make_uuid(),
		"session_id": "",
		"scenario": SCENARIO_SLUG,
		"role_id": PLAYER_ROLE_ID,
		"narrator": NARRATOR_ID,
		"creation_key": _make_uuid(),
		"capability": _make_capability(),
		"pending_turn": {},
		"pending_request_id": "",
		"reflection": {},
		"pending_completion": {},
	}
	var sessions: Array = _store.get("sessions", [])
	sessions.append(record)
	_store["sessions"] = sessions
	_store["current_session_local_id"] = record["local_id"]
	_save_store()
	_operation_in_progress = true
	_update_controls()
	_set_status("Opretter en fast britisk session …", "working")
	var created := await _create_session(record)
	if not created:
		_operation_in_progress = false
		_update_controls()
		return
	await _restore_session(record)


func _resume_saved_session() -> void:
	if _operation_in_progress or not _backend_ready:
		return
	var record := _current_record()
	if record.is_empty():
		_set_status("Der er ingen gemt session at genoptage.", "error")
		return
	_store["current_session_local_id"] = str(record.get("local_id", ""))
	_save_store()
	_operation_in_progress = true
	_update_controls()
	if str(record.get("session_id", "")).is_empty():
		_set_status("Fortsætter den idempotente session-oprettelse …", "working")
		var created := await _create_session(record)
		if not created:
			_operation_in_progress = false
			_update_controls()
			return
	await _restore_session(record)


func _create_session(record: Dictionary) -> bool:
	var payload := {
		"scenario": SCENARIO_SLUG,
		"scenario_version": PINNED_SCENARIO_VERSION,
		"role_id": PLAYER_ROLE_ID,
		"narrator": NARRATOR_ID,
	}
	var headers := {
		"Idempotency-Key": str(record.get("creation_key", "")),
		"X-Session-Capability": str(record.get("capability", "")),
	}
	var response: Dictionary = await _api.call(
		"post_json",
		"/api/v1/sessions",
		payload,
		"",
		headers
	)
	if not response.get("ok", false):
		_set_status("Sessionen blev ikke oprettet: %s" % response.get("error", "Ukendt fejl"), "error")
		return false

	var data: Dictionary = response.get("data", {})
	var session_id := str(data.get("id", ""))
	if session_id.is_empty():
		_set_status("Backend svarede uden et session-id.", "error")
		return false
	record["session_id"] = session_id
	var returned_capability := str(data.get("token", ""))
	if not returned_capability.is_empty():
		record["capability"] = returned_capability
	_store["current_session_local_id"] = str(record.get("local_id", ""))
	_save_store()
	return true


func _restore_session(record: Dictionary) -> void:
	_reflection_retry_pending = false
	_reflection_failed_permanently = false
	var session_id := str(record.get("session_id", ""))
	var capability := str(record.get("capability", ""))
	if session_id.is_empty() or capability.is_empty():
		_set_status("Den gemte session mangler de nødvendige lokale data.", "error")
		_operation_in_progress = false
		_update_controls()
		return

	var session_response: Dictionary = await _api.call(
		"get_json",
		"/api/v1/sessions/" + session_id,
		capability
	)
	if not session_response.get("ok", false):
		_set_status(
			"Sessionen kunne ikke genoptages: %s. Opret en ny session, hvis den er udløbet."
			% session_response.get("error", "Ukendt fejl"),
			"error"
		)
		_operation_in_progress = false
		_update_controls()
		return
	_session_snapshot = session_response.get("data", {})
	if (
		str(_session_snapshot.get("scenario", "")) != SCENARIO_SLUG
		or str(_session_snapshot.get("scenario_version", "")) != PINNED_SCENARIO_VERSION
	):
		_set_status(
			"Den gemte session tilhører en anden scenarieversion end %s."
			% PINNED_SCENARIO_VERSION,
			"error"
		)
		_operation_in_progress = false
		_update_controls()
		return
	_current_turn_number = int(_session_snapshot.get("turn_number", 0))
	var cached_reflection: Variant = record.get("reflection", {})
	_reflection_result = cached_reflection if cached_reflection is Dictionary else {}

	var initialization: Dictionary = await _api.call(
		"get_json",
		"/api/v1/sessions/%s/initialization" % session_id,
		capability
	)
	if not initialization.get("ok", false):
		_set_status("Åbningen kunne ikke læses: %s" % initialization.get("error", "Ukendt fejl"), "error")
		_operation_in_progress = false
		_update_controls()
		return

	var turns_response: Dictionary = await _api.call(
		"get_json",
		"/api/v1/sessions/%s/turns" % session_id,
		capability
	)
	if not turns_response.get("ok", false):
		_set_status("Samtalehistorikken kunne ikke læses.", "error")
		_operation_in_progress = false
		_update_controls()
		return

	var initialization_data: Dictionary = initialization.get("data", {})
	_opening = initialization_data.get("opening", {}) if initialization_data.get("opening") is Dictionary else {}
	_turns = turns_response.get("data", {}).get("turns", [])
	_session_completed = _session_snapshot.get("state", {}).get("completion_status") == "complete"
	_update_briefing_labels()
	_render_transcript()
	_update_session_label()

	var init_status := str(initialization_data.get("status", ""))
	if init_status in ["queued", "running", "uninitialized"]:
		_set_status("Backend forbereder åbningen …", "working")
		await _poll_initialization(record)
		return
	if init_status == "retryable_failure":
		_retry_opening_button.visible = true
		_set_status("Åbningen kunne ikke genereres. Du kan prøve igen.", "error")
		_operation_in_progress = false
		_update_controls()
		return
	if init_status == "failed":
		_set_status("Backend kunne ikke oprette åbningen.", "error")
		_operation_in_progress = false
		_update_controls()
		return
	if init_status != "ready" and init_status != "not_applicable":
		_set_status("Ukendt status fra backend: %s" % init_status, "error")
		_operation_in_progress = false
		_update_controls()
		return
	if _session_completed:
		var pending_completion: Variant = record.get("pending_completion", {})
		if pending_completion is Dictionary and not pending_completion.is_empty():
			record["pending_completion"] = {}
			_save_store()
		_operation_in_progress = false
		_render_transcript()
		_update_controls()
		await _request_reflection()
		return

	await _resume_pending_turn(record, _session_snapshot.get("pending_request", {}))


func _poll_initialization(record: Dictionary) -> void:
	var session_id := str(record.get("session_id", ""))
	var capability := str(record.get("capability", ""))
	for attempt in range(INITIALIZATION_POLL_LIMIT):
		var response: Dictionary = await _api.call(
			"get_json",
			"/api/v1/sessions/%s/initialization" % session_id,
			capability
		)
		if not response.get("ok", false):
			_set_status("Status for åbningen kunne ikke hentes: %s" % response.get("error", ""), "error")
			_operation_in_progress = false
			_update_controls()
			return
		var data: Dictionary = response.get("data", {})
		var status := str(data.get("status", ""))
		if status == "ready":
			_opening = data.get("opening", {}) if data.get("opening") is Dictionary else {}
			var refreshed := await _refresh_authoritative_state(record)
			if not refreshed:
				_operation_in_progress = false
				_update_controls()
				return
			_retry_opening_button.visible = false
			_set_status("Åbningen er klar. Forhandlingen kan begynde.", "ok")
			await _resume_pending_turn(record, _session_snapshot.get("pending_request", {}))
			return
		if status == "retryable_failure":
			_retry_opening_button.visible = true
			_set_status("Åbningen fejlede, men kan forsøges igen.", "error")
			_operation_in_progress = false
			_update_controls()
			return
		if status == "failed":
			_set_status("Backend markerede åbningen som fejlet.", "error")
			_operation_in_progress = false
			_update_controls()
			return
		if attempt % 5 == 0:
			_set_status("Backend forbereder åbningen … (%d sek.)" % attempt, "working")
		await get_tree().create_timer(1.0).timeout

	_set_status(
		"Åbningen tager længere tid end forventet. Genoptag sessionen for at kontrollere igen.",
		"error"
	)
	_operation_in_progress = false
	_update_controls()


func _retry_opening() -> void:
	if _operation_in_progress:
		return
	var record := _current_record()
	if record.is_empty():
		return
	_operation_in_progress = true
	_update_controls()
	var response: Dictionary = await _api.call(
		"post_json",
		"/api/v1/sessions/%s/initialization/retry" % str(record.get("session_id", "")),
		null,
		str(record.get("capability", "")),
		{}
	)
	if not response.get("ok", false):
		_set_status("Åbningen kan ikke genstartes: %s" % response.get("error", ""), "error")
		_operation_in_progress = false
		_update_controls()
		return
	_retry_opening_button.visible = false
	await _poll_initialization(record)


func _resume_pending_turn(record: Dictionary, server_pending: Variant) -> void:
	if _session_completed:
		var pending_completion: Variant = record.get("pending_completion", {})
		if pending_completion is Dictionary and not pending_completion.is_empty():
			record["pending_completion"] = {}
			_save_store()
		_operation_in_progress = false
		_render_transcript()
		_update_controls()
		await _request_reflection()
		return

	var saved_request_id := str(record.get("pending_request_id", ""))
	if not saved_request_id.is_empty():
		_latest_turn_request_id = saved_request_id
		var request_is_local := not bool(record.get("pending_request_is_external", false))
		await _poll_turn_request(record, saved_request_id, request_is_local)
		return

	var pending_turn: Variant = record.get("pending_turn", {})
	if pending_turn is Dictionary and not pending_turn.is_empty():
		_composer.text = str(pending_turn.get("text", ""))
		var expected := int(pending_turn.get("expected_turn", -1))
		if _current_turn_number != expected:
			if _current_turn_number > expected:
				_rebase_pending_turn(record)
				_save_store()
				_set_status(
					"Sessionen har ændret sig. Dit gemte indlæg er bevaret; kontrollér det, og send igen.",
					"error"
				)
			else:
				_set_status("Det gemte indlæg venter på den tilsvarende tur i sessionen.", "error")
			_operation_in_progress = false
			_update_controls()
			return
		await _send_saved_turn(record, pending_turn)
		return

	if server_pending is Dictionary and not str(server_pending.get("request_id", "")).is_empty():
		_latest_turn_request_id = str(server_pending.get("request_id", ""))
		record["pending_request_id"] = _latest_turn_request_id
		record["pending_request_is_external"] = true
		record["external_request_retryable"] = false
		_save_store()
		await _poll_turn_request(record, _latest_turn_request_id, false)
		return

	var pending_completion: Variant = record.get("pending_completion", {})
	if pending_completion is Dictionary and not pending_completion.is_empty():
		await _send_completion(record, pending_completion)
		return

	_set_status("Sessionen er genoptaget.", "ok")
	_operation_in_progress = false
	_update_controls()


func _submit_turn() -> void:
	if _operation_in_progress or _session_completed or not _backend_ready:
		return
	var text_value := _composer.text.strip_edges()
	if text_value.is_empty():
		_set_status("Skriv et indlæg først.", "error")
		return
	var record := _current_record()
	if record.is_empty() or str(record.get("session_id", "")).is_empty():
		_set_status("Start eller genoptag en session, før du skriver.", "error")
		return

	var pending: Dictionary = record.get("pending_turn", {})
	if not pending.is_empty():
		if str(pending.get("text", "")) != text_value:
			_set_status(
				"Et tidligere indlæg afventer stadig svar. Genoptag det, før du skriver et nyt.",
				"error"
			)
			return
	else:
		pending = {
			"client_turn_id": _make_uuid(),
			"expected_turn": _current_turn_number,
			"text": text_value,
		}
		record["pending_turn"] = pending
		_save_store()

	_operation_in_progress = true
	_update_controls()
	await _send_saved_turn(record, pending)


func _send_saved_turn(record: Dictionary, pending: Dictionary) -> void:
	var session_id := str(record.get("session_id", ""))
	var capability := str(record.get("capability", ""))
	var turn_id := str(pending.get("client_turn_id", ""))
	var payload := {
		"client_turn_id": turn_id,
		"expected_turn": int(pending.get("expected_turn", _current_turn_number)),
		"text": str(pending.get("text", "")),
		"input_language": "da",
	}
	var headers := {"Idempotency-Key": turn_id}
	_set_status("Indlæg sendes til backend …", "working")
	_set_actor_talking(true)

	var response: Dictionary = await _api.call(
		"post_json",
		"/api/v1/sessions/%s/turns" % session_id,
		payload,
		capability,
		headers
	)
	if not response.get("ok", false):
		var response_data: Variant = response.get("data", {})
		if int(response.get("status", 0)) == 409 and response_data is Dictionary and response_data.has("request_id"):
			_latest_turn_request_id = str(response_data.get("request_id", ""))
			record["pending_request_id"] = _latest_turn_request_id
			record["pending_request_is_external"] = true
			record["external_request_retryable"] = false
			_save_store()
			_set_status("En anden tur er allerede i gang. Dit indlæg er gemt, mens status kontrolleres …", "working")
			await _poll_turn_request(record, _latest_turn_request_id, false)
			return
		if (
			int(response.get("status", 0)) == 409
			and str(response.get("error", "")).contains("Expected turn does not match session")
		):
			var refreshed := await _refresh_authoritative_state(record, false)
			if refreshed:
				_rebase_pending_turn(record)
				record["pending_request_id"] = ""
				record["pending_request_is_external"] = false
				record["external_request_retryable"] = false
				_save_store()
				_composer.text = str(pending.get("text", ""))
				_set_actor_talking(false)
				_set_status("Sessionen er opdateret. Dit indlæg er bevaret; kontrollér det, og send igen.", "error")
			_operation_in_progress = false
			_update_controls()
			return
		_set_actor_talking(false)
		_set_status(
			"Indlægget blev ikke bekræftet: %s. Det kan sendes sikkert igen."
			% response.get("error", "Ukendt fejl"),
			"error"
		)
		_operation_in_progress = false
		_update_controls()
		return

	var result_data: Dictionary = response.get("data", {})
	_latest_turn_request_id = str(result_data.get("request_id", ""))
	if _latest_turn_request_id.is_empty():
		_set_actor_talking(false)
		_set_status("Backend svarede uden et turn-request-id.", "error")
		_operation_in_progress = false
		_update_controls()
		return
	record["pending_request_id"] = _latest_turn_request_id
	record["pending_request_is_external"] = false
	record["external_request_retryable"] = false
	_save_store()
	await _poll_turn_request(record, _latest_turn_request_id, true)


func _poll_turn_request(
	record: Dictionary, request_id: String, resolve_local_turn: bool = true
) -> void:
	var capability := str(record.get("capability", ""))
	for attempt in range(TURN_POLL_LIMIT):
		var response: Dictionary = await _api.call(
			"get_json",
			"/api/v1/turn-requests/" + request_id,
			capability
		)
		if not response.get("ok", false):
			_set_actor_talking(false)
			_set_status(
				"Turn-status kunne ikke hentes. Sessionen kan genoptages senere.",
				"error"
			)
			_operation_in_progress = false
			_update_controls()
			return
		var data: Dictionary = response.get("data", {})
		var status := str(data.get("status", ""))
		if status == "completed":
			var refreshed := await _refresh_authoritative_state(record, resolve_local_turn)
			if not refreshed:
				_operation_in_progress = false
				_update_controls()
				return
			if resolve_local_turn:
				_clear_pending_turn(record, true)
				_set_status("Svaret er gemt i sessionen.", "ok")
			else:
				_finish_external_request(record)
				_set_status(
					"En anden tur blev gemt. Dit indlæg er bevaret; kontrollér det, og send igen.",
					"ok"
				)
			_set_actor_talking(false)
			_retry_turn_button.visible = false
			_operation_in_progress = false
			_update_controls()
			if _session_completed:
				var pending_completion: Variant = record.get("pending_completion", {})
				if pending_completion is Dictionary and not pending_completion.is_empty():
					record["pending_completion"] = {}
					_save_store()
				await _request_reflection()
				return
			var pending_completion: Variant = record.get("pending_completion", {})
			if pending_completion is Dictionary and not pending_completion.is_empty():
				await _send_completion(record, pending_completion)
				return
			return
		if status == "retryable_failure":
			var failure: Dictionary = data.get("failure", {})
			_latest_turn_request_id = request_id
			_retry_turn_button.visible = true
			_set_actor_talking(false)
			if resolve_local_turn:
				_retry_turn_button.text = "Genforsøg turen"
				_set_status(
					"Svaret fejlede, men kan forsøges igen: %s"
					% failure.get("message", "Backendens turn-worker kunne ikke færdiggøre turen."),
					"error"
				)
			else:
				record["external_request_retryable"] = true
				_save_store()
				_retry_turn_button.text = "Genforsøg den anden tur"
				_set_status(
					"En anden tur venter på genforsøg. Dit indlæg er gemt imens.",
					"error"
				)
			_operation_in_progress = false
			_update_controls()
			return
		if status == "failed":
			var failure: Dictionary = data.get("failure", {})
			if resolve_local_turn:
				_clear_pending_turn(record, false)
			else:
				_finish_external_request(record)
			_retry_turn_button.visible = false
			_set_actor_talking(false)
			if resolve_local_turn:
				_set_status(
					"Turen kunne ikke gennemføres: %s"
					% failure.get("message", "Backendens turn-worker afviste turen."),
					"error"
				)
			else:
				_set_status(
					"Den anden tur fejlede permanent. Dit indlæg er bevaret og kan sendes igen.",
					"error"
				)
			_operation_in_progress = false
			_update_controls()
			return
		if status == "cancelled":
			if resolve_local_turn:
				_clear_pending_turn(record, false)
			else:
				_finish_external_request(record)
			_retry_turn_button.visible = false
			_set_actor_talking(false)
			_set_status("Turen blev annulleret. Dit indlæg er stadig tilgængeligt.", "error")
			_operation_in_progress = false
			_update_controls()
			return
		if status in ["queued", "running"]:
			if attempt % 5 == 0:
				_set_status("Backendens turn-worker behandler indlægget … (%d sek.)" % attempt, "working")
			await get_tree().create_timer(1.0).timeout
			continue
		_set_status("Ukendt turn-status fra backend: %s" % status, "error")
		_operation_in_progress = false
		_update_controls()
		return

	_set_actor_talking(false)
	_set_status(
		"Svaret er stadig under behandling. Genoptag sessionen senere for at kontrollere status.",
		"error"
	)
	_operation_in_progress = false
	_update_controls()


func _retry_turn() -> void:
	if _operation_in_progress or _latest_turn_request_id.is_empty():
		return
	var record := _current_record()
	if record.is_empty():
		return
	_operation_in_progress = true
	_update_controls()
	var request_is_local := not bool(record.get("pending_request_is_external", false))
	var response: Dictionary = await _api.call(
		"post_json",
		"/api/v1/turn-requests/%s/retry" % _latest_turn_request_id,
		null,
		str(record.get("capability", "")),
		{}
	)
	if not response.get("ok", false):
		_set_status("Turen kan ikke genstartes: %s" % response.get("error", ""), "error")
		_operation_in_progress = false
		_update_controls()
		return
	record["external_request_retryable"] = false
	_save_store()
	_retry_turn_button.visible = false
	_set_actor_talking(true)
	await _poll_turn_request(record, _latest_turn_request_id, request_is_local)


func _complete_session() -> void:
	if _operation_in_progress or not _backend_ready or _session_completed:
		return
	var record := _current_record()
	if record.is_empty() or str(record.get("session_id", "")).is_empty():
		return
	if _opening.is_empty():
		_set_status("Åbningen skal være klar, før forløbet kan afsluttes.", "error")
		return
	var pending: Variant = record.get("pending_completion", {})
	if not (pending is Dictionary) or pending.is_empty():
		pending = {
			"client_turn_id": _make_uuid(),
			"expected_turn": _current_turn_number,
		}
		record["pending_completion"] = pending
		_save_store()
	await _send_completion(record, pending)


func _send_completion(record: Dictionary, pending: Dictionary) -> void:
	if not _operation_in_progress:
		_operation_in_progress = true
		_update_controls()
	var client_turn_id := str(pending.get("client_turn_id", ""))
	if client_turn_id.is_empty():
		pending["client_turn_id"] = _make_uuid()
		client_turn_id = str(pending["client_turn_id"])
		pending["expected_turn"] = _current_turn_number
		record["pending_completion"] = pending
		_save_store()
	var payload := {
		"client_turn_id": client_turn_id,
		"expected_turn": int(pending.get("expected_turn", _current_turn_number)),
	}
	var response: Dictionary = await _api.call(
		"post_json",
		"/api/v1/sessions/%s/completion" % str(record.get("session_id", "")),
		payload,
		str(record.get("capability", "")),
		{"Idempotency-Key": client_turn_id}
	)
	if not response.get("ok", false):
		var response_data: Variant = response.get("data", {})
		if int(response.get("status", 0)) == 409 and response_data is Dictionary:
			var conflicting_request_id := str(response_data.get("request_id", ""))
			if not conflicting_request_id.is_empty():
				_latest_turn_request_id = conflicting_request_id
				record["pending_request_id"] = conflicting_request_id
				record["pending_request_is_external"] = true
				record["external_request_retryable"] = false
				_save_store()
				_set_status("En anden tur afsluttes først. Afslutningen fortsætter bagefter …", "working")
				await _poll_turn_request(record, conflicting_request_id, false)
				return
			if str(response.get("error", "")).contains("Expected turn does not match session"):
				var refreshed := await _refresh_authoritative_state(record, false)
				if refreshed and _session_completed:
					record["pending_completion"] = {}
					_save_store()
					_operation_in_progress = false
					_render_transcript()
					_update_controls()
					await _request_reflection()
					return
				if refreshed:
					pending["expected_turn"] = _current_turn_number
					pending["client_turn_id"] = _make_uuid()
					record["pending_completion"] = pending
					_save_store()
			_set_status(
				"Afslutningen blev ikke bekræftet: %s. Prøv afslutningen igen; den gemte anmodning genbruges sikkert."
				% response.get("error", "Ukendt fejl"),
				"error"
			)
		_operation_in_progress = false
		_update_controls()
		return

	var refreshed := await _refresh_authoritative_state(record, false)
	if not refreshed:
		_set_status("Afslutningen blev gemt, men kunne ikke genindlæses. Genoptag sessionen for at kontrollere.", "error")
		_operation_in_progress = false
		_update_controls()
		return
	if not _session_completed:
		_set_status("Backend bekræftede ikke, at forløbet er afsluttet. Genoptag sessionen for at kontrollere.", "error")
		_operation_in_progress = false
		_update_controls()
		return
	record["pending_completion"] = {}
	_save_store()
	_operation_in_progress = false
	_render_transcript()
	_set_status("Forhandlingen er afsluttet. Refleksionen hentes nu …", "ok")
	await _request_reflection()


func _request_reflection() -> void:
	if _operation_in_progress or not _backend_ready or not _session_completed:
		return
	var record := _current_record()
	if record.is_empty():
		return
	var saved_reflection: Variant = record.get("reflection", {})
	var saved_summary := (
		_reflection_text(saved_reflection.get("summary"))
		if saved_reflection is Dictionary
		else ""
	)
	if (
		saved_reflection is Dictionary
		and str(saved_reflection.get("status", "")) == "ready"
		and not saved_summary.is_empty()
	):
		_reflection_retry_pending = false
		_reflection_failed_permanently = false
		_reflection_result = saved_reflection
		_render_results()
		_set_status("Den afsluttende refleksion er klar.", "ok")
		return
	if saved_reflection is Dictionary and str(saved_reflection.get("status", "")) == "ready":
		record["reflection"] = {}
		_reflection_result = {}
		_save_store()

	_reflection_loading = true
	_reflection_error = ""
	_operation_in_progress = true
	_update_controls()
	_render_results()
	_set_status("Henter den afsluttende refleksion …", "working")
	var session_id := str(record.get("session_id", ""))
	var response: Dictionary = await _api.call(
		"post_json",
		"/api/v1/sessions/%s/reflection" % session_id,
		null,
		str(record.get("capability", "")),
		{},
		REFLECTION_REQUEST_TIMEOUT_SECONDS
	)
	if not response.get("ok", false):
		var status_code := int(response.get("status", 0))
		_reflection_retry_pending = (
			status_code == 0 or status_code == 408 or status_code == 429 or status_code >= 500
		)
		_reflection_failed_permanently = not _reflection_retry_pending
		_reflection_error = str(response.get("error", "Ukendt fejl"))
		_reflection_loading = false
		var retry_message := " Du kan prøve igen." if _reflection_retry_pending else ""
		_set_status(
			"Den afsluttende refleksion kunne ikke hentes: %s.%s"
			% [response.get("error", "Ukendt fejl"), retry_message],
			"error"
		)
		_operation_in_progress = false
		_render_results()
		_update_controls()
		return

	var reflection_data: Variant = response.get("data", {})
	var reflection_summary := (
		_reflection_text(reflection_data.get("summary"))
		if reflection_data is Dictionary
		else ""
	)
	if (
		not reflection_data is Dictionary
		or str(reflection_data.get("status", "")) != "ready"
		or reflection_summary.is_empty()
	):
		_reflection_retry_pending = true
		_reflection_failed_permanently = false
		_reflection_loading = false
		_reflection_error = "Backend returnerede ikke en komplet refleksion."
		_set_status(
			"Backend returnerede ikke en komplet refleksion. Du kan prøve igen.",
			"error"
		)
		_operation_in_progress = false
		_render_results()
		_update_controls()
		return

	record["reflection"] = reflection_data
	_reflection_result = reflection_data
	_reflection_retry_pending = false
	_reflection_failed_permanently = false
	_reflection_loading = false
	_reflection_error = ""
	_save_store()
	_operation_in_progress = false
	_render_results()
	_set_status("Den afsluttende refleksion er klar.", "ok")
	_update_controls()
	if is_inside_tree():
		call_deferred("_scroll_results_to_end")


func _reflection_text(value: Variant) -> String:
	if not value is String:
		return ""
	var normalized_text := str(value).strip_edges()
	if normalized_text.to_lower() in ["<null>", "null", "none", "undefined"]:
		return ""
	return normalized_text


func _refresh_authoritative_state(
	record: Dictionary, settle_local_pending: bool = true
) -> bool:
	var session_id := str(record.get("session_id", ""))
	var capability := str(record.get("capability", ""))
	var session_response: Dictionary = await _api.call(
		"get_json",
		"/api/v1/sessions/" + session_id,
		capability
	)
	if not session_response.get("ok", false):
		_set_status("Sessionens status kunne ikke genindlæses.", "error")
		return false
	_session_snapshot = session_response.get("data", {})
	_current_turn_number = int(_session_snapshot.get("turn_number", 0))
	_session_completed = _session_snapshot.get("state", {}).get("completion_status") == "complete"

	var initialization: Dictionary = await _api.call(
		"get_json",
		"/api/v1/sessions/%s/initialization" % session_id,
		capability
	)
	if initialization.get("ok", false):
		var init_data: Dictionary = initialization.get("data", {})
		_opening = init_data.get("opening", {}) if init_data.get("opening") is Dictionary else {}

	var turns_response: Dictionary = await _api.call(
		"get_json",
		"/api/v1/sessions/%s/turns" % session_id,
		capability
	)
	if not turns_response.get("ok", false):
		_set_status("Samtalehistorikken kunne ikke genindlæses.", "error")
		return false
	_turns = turns_response.get("data", {}).get("turns", [])
	_update_briefing_labels()
	_update_issue_board()
	_update_session_label()
	_render_transcript()

	var pending: Dictionary = record.get("pending_turn", {})
	if (
		settle_local_pending
		and not pending.is_empty()
		and _current_turn_number > int(pending.get("expected_turn", -1))
	):
		_clear_pending_turn(record, true)
	return true


func _actor_display_name(actor_id: String) -> String:
	for actor in _scenario.get("actors", []):
		if actor is Dictionary and str(actor.get("id", "")) == actor_id:
			return str(actor.get("name", actor_id))
	for role in _scenario.get("roles", []):
		if role is Dictionary and str(role.get("actor_id", "")) == actor_id:
			return str(role.get("title", actor_id))
	return actor_id.replace("_", " ").capitalize()


func _render_transcript() -> void:
	if _transcript_column == null:
		return
	for child in _transcript_column.get_children():
		_transcript_column.remove_child(child)
		child.queue_free()

	if _opening.is_empty():
		_add_message(
			"VENTER PÅ ÅBNING",
			"Sessionen er oprettet. Backendens initialiseringsjob skal gøre åbningen klar.",
			"system"
		)
	else:
		var opening_title := str(_opening.get("title", "Åbning"))
		var opening_text := str(_opening.get("scene", ""))
		var tension := str(_opening.get("immediate_tension", ""))
		_add_message("ÅBNING · " + opening_title, opening_text, "system")
		if not tension.is_empty():
			_add_message("SITUATION", tension, "system")
		var disclaimer := str(
			_scenario.get("historical_context", {}).get("counterfactual_disclaimer", "")
		)
		if not disclaimer.is_empty():
			_add_message("KILDESTATUS", disclaimer, "system")

	if _turns.is_empty() and not _opening.is_empty():
		_add_message(
			"KLAR TIL FORHANDLING",
			str(_opening.get("player_prompt", "Skriv dit første indlæg, når du er klar.")),
			"system"
		)

	for turn in _turns:
		if not (turn is Dictionary):
			continue
		var player_text := str(turn.get("player_text", ""))
		var reply := str(turn.get("reply", ""))
		if not player_text.is_empty():
			_add_message("DIG", player_text, "player")
		var dialogue: Variant = turn.get("dialogue", [])
		if dialogue is Array:
			for line in dialogue:
				if not (line is Dictionary):
					continue
				var actor_id := str(line.get("actor_id", "")).strip_edges()
				if _delegate_players.has(actor_id):
					_active_delegate_id = actor_id
				var dialogue_text := str(line.get("text", "")).strip_edges()
				if not actor_id.is_empty() and not dialogue_text.is_empty():
					_add_message(
						_actor_display_name(actor_id) + " · SIMULERET",
						dialogue_text,
						"response"
					)
		if not reply.is_empty():
			_add_message("FORTÆLLER · SIMULERET", reply, "response")
		var outcome := str(turn.get("outcome_summary", ""))
		if not outcome.is_empty():
			_add_message("UDVIKLING", outcome, "system")

		var assessment: Variant = turn.get("negotiation_assessment", {})
		if assessment is Dictionary:
			var consequence := str(assessment.get("consequence", "")).strip_edges()
			var disagreement := str(assessment.get("remaining_disagreement", "")).strip_edges()
			var status_text := "Konsekvens: %s" % consequence if not consequence.is_empty() else ""
			if not disagreement.is_empty():
				if not status_text.is_empty():
					status_text += "\n\n"
				status_text += "Uenighed tilbage: " + disagreement
			if not status_text.is_empty():
				_add_message("FORHANDLINGSSTATUS · TUR %02d" % int(turn.get("turn_number", 0)), status_text, "system")

		var issue_updates: Variant = turn.get("issue_updates", [])
		if issue_updates is Array:
			for update_value in issue_updates:
				if not update_value is Dictionary:
					continue
				var update: Dictionary = update_value
				var issue_title := str(update.get("issue_id", "Forhandlingspunkt"))
				for issue_definition in _scenario.get("negotiation_issues", []):
					if issue_definition is Dictionary and str(issue_definition.get("id", "")) == str(update.get("issue_id", "")):
						issue_title = str(issue_definition.get("title", issue_title))
				var update_status := str(update.get("status", "proposed"))
				var status_label := "Foreslået"
				if update_status == "open":
					status_label = "Åben"
				elif update_status == "contested":
					status_label = "Omstridt"
				elif update_status == "agreed":
					status_label = "Foreløbig enighed (ikke bindende)"
				var update_lines := PackedStringArray()
				var update_prefix := (
					"Drøftelse (intet nyt vilkår): "
					if str(update.get("action_type", "proposal")) == "discussion"
					else "Rådgiverens forslag (ikke bindende): "
				)
				update_lines.append(update_prefix + str(update.get("recommendation", "")))
				var responses: Variant = update.get("responses", [])
				if responses is Array:
					for response_value in responses:
						if not response_value is Dictionary:
							continue
						var response: Dictionary = response_value
						var response_actor := str(response.get("actor_id", ""))
						var response_name := "Frankrig" if response_actor == "france" else "Kina" if response_actor == "china" else _actor_display_name(response_actor)
						var response_stance := str(response.get("stance", ""))
						match response_stance:
							"accept":
								response_stance = "accepterer foreløbigt"
							"counter":
								response_stance = "fremsætter modforslag"
							"reject":
								response_stance = "afviser"
							"defer":
								response_stance = "afventer"
						var response_text := "%s · %s" % [response_stance, str(response.get("position", ""))]
						if not str(response.get("counteroffer", "")).is_empty():
							response_text += " · Modforslag: " + str(response.get("counteroffer", ""))
						update_lines.append(response_name + ": " + response_text)
				update_lines.append("Status: " + status_label)
				_add_message("PUNKT · " + issue_title, "\n".join(update_lines), "system")

	if _session_completed:
		_next_prompt_label.text = "Forhandlingen er afsluttet. Se resultatet og refleksionen nedenfor."
	elif not _turns.is_empty():
		var latest: Dictionary = _turns[_turns.size() - 1]
		var next_prompt: Variant = latest.get("next_player_prompt")
		_next_prompt_label.text = (
			str(next_prompt).strip_edges()
			if next_prompt is String and not str(next_prompt).strip_edges().is_empty()
			else "Du kan fortsætte forhandlingen med et nyt indlæg."
		)
	elif not _opening.is_empty():
		_next_prompt_label.text = str(
			_opening.get("player_goal", "Skriv et indlæg for at fortsætte.")
		)
	else:
		_next_prompt_label.text = "Åbningen vises her, når backendens initialiseringsjob er færdigt."

	_update_session_label()
	if _composer_row != null:
		_composer_row.visible = not _session_completed
	_render_results()
	_update_controls()
	if is_inside_tree():
		call_deferred("_scroll_transcript_to_end")


func _add_message(speaker: String, message: String, tone: String) -> void:
	var card_color := Color(0.10, 0.12, 0.13, 0.90)
	var line_color := Color(0.34, 0.36, 0.34, 1.0)
	if tone == "player":
		card_color = Color(0.13, 0.14, 0.12, 0.94)
		line_color = Color(0.58, 0.48, 0.29, 1.0)
	elif tone == "response":
		card_color = Color(0.09, 0.12, 0.12, 0.94)
		line_color = Color(0.28, 0.49, 0.39, 1.0)
	elif tone == "system":
		card_color = Color(0.10, 0.105, 0.10, 0.88)
		line_color = Color(0.45, 0.39, 0.27, 1.0)

	var card := _make_panel(card_color, line_color)
	var accent_style := _make_style(card_color, line_color, 10)
	accent_style.border_width_left = 3
	card.add_theme_stylebox_override("panel", accent_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	column.add_child(_make_label(speaker, 11, COLOR_GOLD, true))
	var body := _make_label(message, 14, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	_transcript_column.add_child(card)


func _render_results() -> void:
	if _results_panel == null or _results_content == null:
		return
	_results_panel.visible = _session_completed
	for child in _results_content.get_children():
		_results_content.remove_child(child)
		child.queue_free()
	if not _session_completed:
		return

	var record := _current_record()
	var cached_reflection: Variant = record.get("reflection", {})
	var reflection := _reflection_result
	if (
		cached_reflection is Dictionary
		and str(cached_reflection.get("status", "")) == "ready"
		and not _reflection_text(cached_reflection.get("summary")).is_empty()
	):
		reflection = cached_reflection
		_reflection_result = cached_reflection
	var is_ready := str(reflection.get("status", "")) == "ready"
	if _reflection_loading:
		_results_status_label.text = "AFSLUTTET · HENTER REFLEKSION …"
	elif not _reflection_error.is_empty():
		_results_status_label.text = (
			"AFSLUTTET · REFLEKSIONEN KUNNE IKKE HENTES · PRØV IGEN"
			if _reflection_retry_pending
			else "AFSLUTTET · REFLEKSIONEN KUNNE IKKE HENTES"
		)
	elif is_ready:
		_results_status_label.text = "AFSLUTTET · KVALITATIV REFLEKSION · INGEN KARAKTER"
	else:
		_results_status_label.text = "AFSLUTTET · KVALITATIV REFLEKSION"

	var state: Dictionary = _session_snapshot.get("state", {})
	var completion_reason := str(state.get("completion_reason", ""))
	var completion_line := "Forhandlingen er afsluttet."
	if completion_reason == "player_end":
		completion_line = "Du valgte at afslutte forløbet."
	elif completion_reason == "objectives_complete":
		completion_line = "Scenariets afslutningsmål blev nået."
	elif completion_reason == "turn_limit":
		completion_line = "Scenariets turgrænse blev nået."
	var turn_count := int(_session_snapshot.get("turn_number", _current_turn_number))
	_add_result_section(
		"FORLØBETS AFSLUTNING",
		"%s Registrerede ture: %d." % [completion_line, turn_count]
	)
	if not _turns.is_empty():
		var final_turn: Variant = _turns[_turns.size() - 1]
		if final_turn is Dictionary:
			var final_reply := _reflection_text(final_turn.get("reply"))
			var final_summary := _reflection_text(final_turn.get("outcome_summary"))
			var ending_lines := PackedStringArray()
			if not final_reply.is_empty():
				ending_lines.append(final_reply)
			if not final_summary.is_empty():
				ending_lines.append(final_summary)
			if not ending_lines.is_empty():
				_add_result_section(
					"SIDSTE SVAR",
					"\n\n".join(ending_lines)
				)
	if not _reflection_error.is_empty():
		var error_text := _reflection_error
		if _reflection_retry_pending:
			error_text += "\nForsøget fejlede midlertidigt. Brug knappen nedenfor for at prøve igen."
		_add_result_section("REFLEKSION", error_text)
		return
	if not is_ready:
		_add_result_section("REFLEKSION", "Refleksionen vises her, når backend har færdiggjort den.")
		return

	var reflection_summary := _reflection_text(reflection.get("summary"))
	if not reflection_summary.is_empty():
		_add_result_section("REFLEKSION", reflection_summary)
	elif is_ready:
		_add_result_section(
			"REFLEKSION",
			"Resuméet mangler i refleksionssvaret. Du kan hente refleksionen igen."
		)

	var choices: Variant = reflection.get("player_choices", [])
	if choices is Array and not choices.is_empty():
		var choice_lines := PackedStringArray()
		for choice in choices:
			if not (choice is Dictionary):
				continue
			var action := _reflection_text(choice.get("action"))
			var choice_summary := _reflection_text(choice.get("summary"))
			var choice_line := "Tur %d" % int(choice.get("turn_number", 0))
			if not action.is_empty():
				choice_line += " · " + action
			if not choice_summary.is_empty():
				choice_line += "\n" + choice_summary
			choice_lines.append(choice_line)
		if not choice_lines.is_empty():
			_add_result_section("DINE VALG", "\n\n".join(choice_lines))

	var consequences: Variant = reflection.get("simulated_consequences", [])
	if consequences is Array and not consequences.is_empty():
		var consequence_lines := PackedStringArray()
		for consequence in consequences:
			if not (consequence is Dictionary):
				continue
			var details: Variant = consequence.get("details", {})
			if not (details is Dictionary):
				continue
			var detail := ""
			for detail_key in ["summary", "resolution", "reason"]:
				detail = _reflection_text(details.get(detail_key))
				if not detail.is_empty():
					break
			if not detail.is_empty():
				consequence_lines.append("Tur %d · %s" % [int(consequence.get("turn_number", 0)), detail])
		if not consequence_lines.is_empty():
			_add_result_section("SIMULEREDE FØLGER", "\n".join(consequence_lines))

	var objectives: Variant = reflection.get("objectives", [])
	if objectives is Array:
		var objective_lines := PackedStringArray()
		for objective in objectives:
			if not (objective is Dictionary):
				continue
			var objective_name := _reflection_text(objective.get("title"))
			if objective_name.is_empty():
				objective_name = _reflection_text(objective.get("id"))
			if objective_name.is_empty():
				objective_name = "Læringsmål"
			var feedback := _reflection_text(objective.get("reflection"))
			if not feedback.is_empty():
				objective_lines.append("%s\n%s" % [objective_name, feedback])
		if not objective_lines.is_empty():
			_add_result_section("LÆRINGSMÅL", "\n\n".join(objective_lines))

	var evidence_ids: Variant = reflection.get("historical_evidence_ids", [])
	var comparison := _reflection_text(reflection.get("historical_comparison"))
	if evidence_ids is Array and not evidence_ids.is_empty() and not comparison.is_empty():
		_add_result_section("HISTORISK SAMMENLIGNING", comparison)
		var source_titles := PackedStringArray()
		var sources: Variant = reflection.get("sources", [])
		if sources is Array:
			for source in sources:
				if source is Dictionary:
					var source_title := _reflection_text(source.get("source_title"))
					if not source_title.is_empty():
						source_titles.append(source_title)
		if not source_titles.is_empty():
			_add_result_section("KILDER", "\n".join(source_titles))
	else:
		var abstention := _reflection_text(reflection.get("historical_abstention"))
		if abstention.is_empty():
			match str(reflection.get("evidence_status", "")):
				"evidence_unavailable":
					abstention = "Der var ikke godkendt historisk belæg til en sammenligning."
				"retrieval_failure":
					abstention = "Kildesøgningen fejlede; den historiske sammenligning er uafklaret."
				_:
					abstention = "Ingen kildebaseret historisk sammenligning blev returneret."
		_add_result_section("KILDESTATUS", abstention)

	var uncertainty_notes: Variant = reflection.get("uncertainty_notes", [])
	if uncertainty_notes is Array and not uncertainty_notes.is_empty():
		var notes := PackedStringArray()
		for note in uncertainty_notes:
			var note_text := _reflection_text(note)
			if not note_text.is_empty():
				notes.append("• " + note_text)
		if not notes.is_empty():
			_add_result_section("USIKKERHED OG BEGRÆNSNINGER", "\n".join(notes))
	_add_result_section(
		"OM REFLEKSIONEN",
		"Dette er en kvalitativ refleksion over den simulerede forhandling. Den giver ingen karakter eller vurdering af mestring."
	)


func _add_result_section(heading: String, body: String) -> void:
	if body.strip_edges().is_empty():
		return
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.add_child(_make_label(heading, 11, COLOR_GOLD, true))
	var label := _make_label(body, 13, COLOR_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	_results_content.add_child(column)


func _scroll_results_to_end() -> void:
	await get_tree().process_frame
	if _results_scroll != null:
		_results_scroll.scroll_vertical = int(_results_scroll.get_v_scroll_bar().max_value)


func _scroll_transcript_to_end() -> void:
	await get_tree().process_frame
	if _transcript_column == null:
		return
	var scroll := _transcript_column.get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _update_briefing_labels() -> void:
	if _opening.is_empty():
		_briefing_tension_label.text = "Dit mål vises, når forhandlingen starter."
		_briefing_goal_label.text = ""
		_simulation_badge.text = "FIKTIV FORHANDLING"
		return
	var tension := str(_opening.get("immediate_tension", ""))
	var goal := str(_opening.get("player_goal", "")).strip_edges()
	goal = goal.trim_prefix("Dit mål:").strip_edges()
	_briefing_tension_label.text = tension if not tension.is_empty() else "Åbningen er klar."
	_briefing_goal_label.text = goal
	_simulation_badge.text = "FIKTIV DIALOG"


func _update_issue_board() -> void:
	if _issue_board_container == null:
		return
	for child in _issue_board_container.get_children():
		_issue_board_container.remove_child(child)
		child.queue_free()

	var session_state: Variant = _session_snapshot.get("state", {})
	var issue_list: Variant = (
		session_state.get("negotiation_issues", [])
		if session_state is Dictionary
		else []
	)
	if not issue_list is Array or issue_list.is_empty():
		issue_list = _scenario.get("negotiation_issues", [])
	if not issue_list is Array or issue_list.is_empty():
		_issue_board_container.add_child(
			_make_label("Forhandlingspunkterne vises, når scenariet er indlæst.", 11, COLOR_MUTED)
		)
		return

	for issue_value in issue_list:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		var status := str(issue.get("status", "open"))
		var status_text := "ÅBEN"
		var status_color := COLOR_MUTED
		match status:
			"proposed":
				status_text = "FORESLÅET"
				status_color = COLOR_AMBER
			"contested":
				status_text = "OMSTRIDT"
				status_color = COLOR_RED
			"agreed":
				status_text = "FORELØBIG ENIGHED"
				status_color = COLOR_GREEN

		var card := _make_panel(
			Color(0.055, 0.065, 0.065, 0.92),
			status_color.darkened(0.28)
		)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 9)
		margin.add_theme_constant_override("margin_top", 7)
		margin.add_theme_constant_override("margin_right", 9)
		margin.add_theme_constant_override("margin_bottom", 7)
		card.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		margin.add_child(column)

		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 5)
		column.add_child(heading)
		var title := _make_label(str(issue.get("title", "Forhandlingspunkt")), 12, COLOR_TEXT, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		var badge := _make_label(status_text, 9, status_color, true)
		badge.custom_minimum_size = Vector2(116, 0)
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		heading.add_child(badge)

		var recommendation := str(issue.get("current_recommendation", "")).strip_edges()
		var action_type := str(issue.get("last_action_type", "none"))
		if recommendation.is_empty():
			recommendation = str(issue.get("baseline_disagreement", issue.get("description", "")))
		else:
			var update_prefix := "Drøftelse: " if action_type == "discussion" else "Rådgiverens forslag: "
			recommendation = update_prefix + recommendation
		column.add_child(_make_label(_clip_board_text(recommendation, 170), 10, COLOR_TEXT))

		var responses: Variant = issue.get("responses", [])
		if responses is Array:
			for response_value in responses:
				if not response_value is Dictionary:
					continue
				var response: Dictionary = response_value
				var actor_id := str(response.get("actor_id", ""))
				var actor_name := "Frankrig" if actor_id == "france" else "Kina" if actor_id == "china" else _actor_display_name(actor_id)
				var stance := str(response.get("stance", "defer"))
				var stance_label := "accepterer foreløbigt"
				match stance:
					"counter":
						stance_label = "modforslag"
					"reject":
						stance_label = "afviser"
					"defer":
						stance_label = "afventer"
				var response_text := str(response.get("position", "")).strip_edges()
				if stance == "counter" and not str(response.get("counteroffer", "")).is_empty():
					response_text += " · " + str(response.get("counteroffer", ""))
				column.add_child(
					_make_label(
						_clip_board_text("%s %s: %s" % [actor_name, stance_label, response_text], 150),
						10,
					COLOR_MUTED
					)
				)

		var consequence := str(issue.get("last_consequence", "")).strip_edges()
		if not consequence.is_empty():
			column.add_child(
				_make_label("Følge: " + _clip_board_text(consequence, 110), 10, COLOR_MUTED)
			)
		var disagreement := str(issue.get("remaining_disagreement", "")).strip_edges()
		if not disagreement.is_empty():
			column.add_child(
				_make_label("Uenighed: " + _clip_board_text(disagreement, 110), 10, COLOR_AMBER)
			)
		_issue_board_container.add_child(card)


func _clip_board_text(value: String, limit: int) -> String:
	var text_value := value.strip_edges()
	if text_value.length() <= limit:
		return text_value
	return text_value.substr(0, limit - 1).strip_edges() + "…"


func _update_session_label() -> void:
	if _turn_status_label != null:
		if _session_completed:
			_turn_status_label.text = "FORHANDLINGEN ER AFSLUTTET"
		elif not _opening.is_empty():
			_turn_status_label.text = "RUNDE %02d · DIN TUR" % maxi(1, _current_turn_number + 1)
		elif not _backend_ready:
			_turn_status_label.text = "AFVENTER FORBINDELSE"
		else:
			_turn_status_label.text = "KLAR TIL AT STARTE"

	var record := _current_record()
	if record.is_empty():
		_session_id_label.text = "Ingen forhandling endnu"
		return
	var session_id := str(record.get("session_id", ""))
	if session_id.is_empty():
		_session_id_label.text = "Opretter forhandling …"
	else:
		_session_id_label.text = "Tur %d" % _current_turn_number


func _update_controls() -> void:
	if _connect_button == null:
		return
	_connect_button.disabled = _operation_in_progress
	if _endpoint_input != null:
		_endpoint_input.editable = not _operation_in_progress
	var record := _current_record()
	var has_record := not record.is_empty()
	var has_session := has_record and not str(record.get("session_id", "")).is_empty()
	_resume_button.visible = has_record
	_resume_button.disabled = _operation_in_progress or not _backend_ready
	_new_session_button.disabled = (
		_operation_in_progress
		or not _backend_ready
		or not _scenario_available
		or (has_record and not has_session)
	)
	_retry_opening_button.disabled = _operation_in_progress or not _backend_ready
	var external_retry_pending := (
		bool(record.get("pending_request_is_external", false))
		and bool(record.get("external_request_retryable", false))
	)
	_retry_turn_button.disabled = _operation_in_progress or not _backend_ready
	if _complete_button != null:
		var pending_completion: Variant = record.get("pending_completion", {})
		var completion_pending := false
		if pending_completion is Dictionary:
			completion_pending = not (pending_completion as Dictionary).is_empty()
		_complete_button.text = "Prøv igen" if completion_pending else "Afslut forhandling"
		_complete_button.disabled = (
			_operation_in_progress
			or not _backend_ready
			or not has_session
			or _opening.is_empty()
			or _session_completed
			or external_retry_pending
		)
	if _composer_row != null:
		_composer_row.visible = not _session_completed
	if _retry_reflection_button != null:
		_retry_reflection_button.visible = (
			_session_completed and _reflection_retry_pending and not _reflection_failed_permanently
		)
		_retry_reflection_button.disabled = _operation_in_progress or not _backend_ready
	if _send_button != null:
		_send_button.disabled = (
			_operation_in_progress
			or not _backend_ready
			or not has_session
			or _opening.is_empty()
			or _session_completed
			or external_retry_pending
		)
	if _composer != null:
		_composer.editable = (
			_backend_ready
			and has_session
			and not _opening.is_empty()
			and not _session_completed
			and not external_retry_pending
		)


func _set_busy(value: bool) -> void:
	_operation_in_progress = value
	_update_controls()


func _toggle_connection_details() -> void:
	if _connection_details == null:
		return
	_connection_details.visible = not _connection_details.visible
	_connection_toggle_button.text = (
		"Skjul forbindelse" if _connection_details.visible else "Forbindelse"
	)


func _set_status(message: String, state: String) -> void:
	if _header_status == null:
		return
	var color := COLOR_MUTED
	var short_status := "Venter"
	match state:
		"ok":
			color = COLOR_GREEN
			short_status = "Forbundet"
			_connect_button.text = "Tjek forbindelsen"
		"working":
			color = COLOR_AMBER
			short_status = "Arbejder …"
			_connect_button.text = "Forbind igen"
		"error":
			color = COLOR_RED
			short_status = "Noget gik galt"
			_connect_button.text = "Forbind igen"
	_header_status.text = short_status
	_header_status.tooltip_text = message
	_header_status.add_theme_color_override("font_color", color)
	if _sidebar_status != null:
		_sidebar_status.text = message
		_sidebar_status.add_theme_color_override("font_color", color)
	if _connection_toggle_button != null:
		_connection_toggle_button.tooltip_text = message
		_connection_toggle_button.add_theme_color_override("font_color", color)


func _set_actor_talking(talking: bool) -> void:
	for actor_id in _delegate_players:
		var player: AnimationPlayer = _delegate_players[actor_id]
		var clip := "SeatedTalking" if talking and actor_id == _active_delegate_id else "SeatedIdle"
		if player != null and player.has_animation(clip):
			player.play(clip, 0.25)


func _clear_pending_turn(record: Dictionary, clear_composer: bool) -> void:
	record["pending_turn"] = {}
	record["pending_request_id"] = ""
	record["pending_request_is_external"] = false
	record["external_request_retryable"] = false
	_latest_turn_request_id = ""
	_save_store()
	if clear_composer and _composer != null:
		_composer.text = ""


func _finish_external_request(record: Dictionary) -> void:
	record["pending_request_id"] = ""
	record["pending_request_is_external"] = false
	record["external_request_retryable"] = false
	_latest_turn_request_id = ""
	_rebase_pending_turn(record)
	_save_store()


func _rebase_pending_turn(record: Dictionary) -> void:
	var pending: Variant = record.get("pending_turn", {})
	if not (pending is Dictionary) or pending.is_empty():
		return
	var previous_expected := int(pending.get("expected_turn", -1))
	if previous_expected != _current_turn_number:
		pending["expected_turn"] = _current_turn_number
		pending["client_turn_id"] = _make_uuid()
		record["pending_turn"] = pending
		if _composer != null:
			_composer.text = str(pending.get("text", ""))


func _current_record() -> Dictionary:
	var current_id := str(_store.get("current_session_local_id", ""))
	var sessions: Array = _store.get("sessions", [])
	for record in sessions:
		if record is Dictionary and str(record.get("local_id", "")) == current_id:
			return record
	return {}


func _make_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		value.substr(0, 8),
		value.substr(8, 4),
		value.substr(12, 4),
		value.substr(16, 4),
		value.substr(20, 12),
	]


func _make_capability() -> String:
	var value := Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32))
	return value.replace("+", "-").replace("/", "_").replace("=", "")


func _api_get(path: String, capability: String = "") -> Dictionary:
	var result: Dictionary = await _api.call("get_json", path, capability)
	return result


func _is_valid_api_response(response: Dictionary) -> bool:
	return bool(response.get("ok", false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_store()
