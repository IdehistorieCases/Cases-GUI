extends Node

## First playable network path for the existing seated negotiator prototype.
## The backend remains authoritative for scenario state and generated dialogue.

const BACKEND_API_SCRIPT = preload("res://scripts/cases_backend_api.gd")
const SEATED_DEMO_SCENE: PackedScene = preload("res://scenes/seated_suit_demo.tscn")
const SCENARIO_SLUG := "versailles-1919"
const PLAYER_ROLE_ID := "british_adviser"
const NARRATOR_ID := "gpt6_luna_high"
const SESSION_STORE_PATH := "user://cases_sessions.json"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:18082"
const INITIALIZATION_POLL_LIMIT := 180
const TURN_POLL_LIMIT := 360

const COLOR_GOLD := Color(0.79, 0.64, 0.39, 1.0)
const COLOR_TEXT := Color(0.91, 0.89, 0.83, 1.0)
const COLOR_MUTED := Color(0.62, 0.65, 0.65, 1.0)
const COLOR_GREEN := Color(0.53, 0.78, 0.61, 1.0)
const COLOR_RED := Color(0.87, 0.49, 0.44, 1.0)
const COLOR_AMBER := Color(0.91, 0.72, 0.39, 1.0)

var _api: Node
var _store: Dictionary = {"sessions": [], "current_session_local_id": "", "base_url": ""}
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
var _transcript_column: VBoxContainer
var _next_prompt_label: Label
var _composer: TextEdit
var _connect_button: Button
var _new_session_button: Button
var _resume_button: Button
var _retry_opening_button: Button
var _retry_turn_button: Button
var _send_button: Button
var _simulation_badge: Label
var _latest_turn_request_id := ""


func _ready() -> void:
	var seated_demo: Node = SEATED_DEMO_SCENE.instantiate()
	seated_demo.name = "SeatedNegotiatorPreview"
	add_child(seated_demo)

	_api = BACKEND_API_SCRIPT.new()
	_api.name = "CasesBackendApi"
	add_child(_api)

	_load_store()
	_build_interface()
	_api.call("set_base_url", _api_base_url)
	_connect_backend()


func _load_store() -> void:
	if FileAccess.file_exists(SESSION_STORE_PATH):
		var file := FileAccess.open(SESSION_STORE_PATH, FileAccess.READ)
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
		_api_base_url = saved_url.trim_suffix("/") if not saved_url.is_empty() else DEFAULT_BACKEND_URL


func _save_store() -> void:
	_store["base_url"] = _api_base_url
	var file := FileAccess.open(SESSION_STORE_PATH, FileAccess.WRITE)
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
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(screen)

	var scrim := ColorRect.new()
	scrim.color = Color(0.025, 0.035, 0.043, 0.42)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(scrim)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 22)
	margins.add_theme_constant_override("margin_top", 18)
	margins.add_theme_constant_override("margin_right", 22)
	margins.add_theme_constant_override("margin_bottom", 18)
	screen.add_child(margins)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	margins.add_child(page)

	page.add_child(_build_header())
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	page.add_child(content)
	content.add_child(_build_sidebar())
	content.add_child(_build_conversation())

	_update_controls()


func _build_header() -> PanelContainer:
	var panel := _make_panel(Color(0.075, 0.09, 0.10, 0.96), COLOR_GOLD)
	panel.custom_minimum_size = Vector2(0, 66)
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
	brand.add_theme_constant_override("separation", 0)
	brand.add_child(_make_label("CASES", 20, COLOR_GOLD, true))
	brand.add_child(_make_label("PARIS · 1919", 11, COLOR_MUTED, true))
	row.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_header_status = _make_label("Forbinder …", 13, COLOR_AMBER, true)
	_header_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_header_status)

	_connect_button = _make_button("Forbind igen", false)
	_connect_button.custom_minimum_size = Vector2(138, 38)
	_connect_button.pressed.connect(_connect_backend)
	row.add_child(_connect_button)
	return panel


func _build_sidebar() -> PanelContainer:
	var panel := _make_panel(Color(0.075, 0.09, 0.10, 0.95), Color(0.35, 0.33, 0.27, 1.0))
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)

	column.add_child(_make_label("AKTIV SAG", 11, COLOR_GOLD, true))
	_scenario_title_label = _make_label("Parisfredskonferencen", 21, COLOR_TEXT, true)
	column.add_child(_scenario_title_label)
	_scenario_summary_label = _make_label(
		"Henter scenariet fra CASES-backend …",
		13,
		COLOR_MUTED
	)
	column.add_child(_scenario_summary_label)
	column.add_child(_make_separator())

	column.add_child(_make_label("FORBINDELSE", 11, COLOR_GOLD, true))
	column.add_child(_make_label("Backend-adresse", 12, COLOR_MUTED))
	_endpoint_input = LineEdit.new()
	_endpoint_input.text = _api_base_url
	_endpoint_input.placeholder_text = "https://server.example.dk"
	_endpoint_input.custom_minimum_size = Vector2(0, 38)
	_endpoint_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_endpoint_input)
	_sidebar_status = _make_label("Backend kontrolleres …", 12, COLOR_AMBER)
	column.add_child(_sidebar_status)
	_narrator_status_label = _make_label("ChatGPT 6 Luna: kontrolleres …", 12, COLOR_MUTED)
	column.add_child(_narrator_status_label)

	column.add_child(_make_separator())
	column.add_child(_make_label("DIN ROLLE", 11, COLOR_GOLD, true))
	_role_title_label = _make_label("Britisk rådgiver", 15, COLOR_TEXT, true)
	column.add_child(_role_title_label)
	_role_intro_label = _make_label(
		"Du er rådgiver ved fredsforhandlingerne. Spillets samtaler er en simulering.",
		13,
		COLOR_MUTED
	)
	column.add_child(_role_intro_label)

	column.add_child(_make_separator())
	_briefing_tension_label = _make_label(
		"Start en forhandling for at hente åbningen og din briefing.",
		13,
		COLOR_TEXT
	)
	column.add_child(_briefing_tension_label)
	_briefing_goal_label = _make_label("", 12, COLOR_MUTED)
	column.add_child(_briefing_goal_label)

	column.add_child(_make_separator())
	_session_id_label = _make_label("Ingen gemt session valgt", 11, COLOR_MUTED)
	column.add_child(_session_id_label)

	_new_session_button = _make_button("Start ny forhandling", true)
	_new_session_button.custom_minimum_size = Vector2(0, 42)
	_new_session_button.pressed.connect(_start_new_session)
	column.add_child(_new_session_button)

	_resume_button = _make_button("Genoptag gemt forhandling", false)
	_resume_button.custom_minimum_size = Vector2(0, 38)
	_resume_button.pressed.connect(_resume_saved_session)
	column.add_child(_resume_button)

	_retry_opening_button = _make_button("Prøv åbningen igen", false)
	_retry_opening_button.custom_minimum_size = Vector2(0, 36)
	_retry_opening_button.visible = false
	_retry_opening_button.pressed.connect(_retry_opening)
	column.add_child(_retry_opening_button)

	_retry_turn_button = _make_button("Prøv svaret igen", false)
	_retry_turn_button.custom_minimum_size = Vector2(0, 36)
	_retry_turn_button.visible = false
	_retry_turn_button.pressed.connect(_retry_turn)
	column.add_child(_retry_turn_button)
	return panel


func _build_conversation() -> PanelContainer:
	var panel := _make_panel(Color(0.075, 0.09, 0.10, 0.92), Color(0.35, 0.33, 0.27, 1.0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	title_block.add_theme_constant_override("separation", 1)
	title_block.add_child(_make_label("FORHANDLING", 14, COLOR_GOLD, true))
	title_block.add_child(_make_label("Dine indlæg og CASES-simuleringens svar", 12, COLOR_MUTED))
	top.add_child(title_block)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_simulation_badge = _make_label("SIMULATION", 11, COLOR_AMBER, true)
	_simulation_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_simulation_badge)

	var divider := _make_separator()
	column.add_child(divider)

	var transcript_scroll := ScrollContainer.new()
	transcript_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(transcript_scroll)

	_transcript_column = VBoxContainer.new()
	_transcript_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript_column.add_theme_constant_override("separation", 9)
	transcript_scroll.add_child(_transcript_column)
	_add_message(
		"VELKOMMEN",
		"Forbind til backend for at hente den aktive Versailles-sag. "
		+ "Når sessionen er klar, kan du skrive frit på dansk.",
		"system"
	)

	_next_prompt_label = _make_label(
		"Din næste handling bliver gemt som et idempotent indlæg og behandlet af backendens turn-worker.",
		12,
		COLOR_MUTED
	)
	_next_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_next_prompt_label)

	var composer_row := HBoxContainer.new()
	composer_row.add_theme_constant_override("separation", 10)
	column.add_child(composer_row)

	_composer = TextEdit.new()
	_composer.custom_minimum_size = Vector2(0, 96)
	_composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_composer.placeholder_text = "Skriv dit forslag, din indsigelse eller dit spørgsmål …"
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
	composer_row.add_child(_composer)

	_send_button = _make_button("Send\nindlæg", true)
	_send_button.custom_minimum_size = Vector2(112, 96)
	_send_button.pressed.connect(_submit_turn)
	composer_row.add_child(_send_button)
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
	panel.add_theme_stylebox_override("panel", _make_style(background, border, 12))
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
	_scenario_available = not _scenario.is_empty()
	_update_scenario_labels()

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
	_scenario_title_label.text = str(metadata.get("title", "Parisfredskonferencen"))
	_scenario_summary_label.text = str(
		metadata.get("summary", "Forhandlinger ved fredskonferencen i Paris i 1919.")
	)
	_player_role = {}
	var roles: Array = _scenario.get("roles", [])
	for role in roles:
		if role is Dictionary and role.get("id") == PLAYER_ROLE_ID:
			_player_role = role
			break
	if not _player_role.is_empty():
		_role_title_label.text = str(_player_role.get("title", "Britisk rådgiver"))
		_role_intro_label.text = str(
			_player_role.get(
				"introduction",
				"Du er rådgiver ved fredsforhandlingerne i Paris."
			)
		)
	else:
		_role_title_label.text = "Den faste britiske rolle mangler"
		_role_intro_label.text = "Backend-scenariet indeholder ikke den forventede spillerrolle."


func _start_new_session() -> void:
	if _operation_in_progress or not _backend_ready or not _scenario_available:
		return
	if not _current_record().is_empty() and str(_current_record().get("session_id", "")).is_empty():
		_set_status("Genoptag først den igangværende oprettelse.", "error")
		return

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
	_current_turn_number = int(_session_snapshot.get("turn_number", 0))

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
		_set_status("Forhandlingen er afsluttet.", "ok")
		_operation_in_progress = false
		_update_controls()
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

	if not _turns.is_empty():
		var latest: Dictionary = _turns[_turns.size() - 1]
		_next_prompt_label.text = str(
			latest.get(
				"next_player_prompt",
				"Du kan fortsætte forhandlingen med et nyt indlæg."
			)
		)
	elif not _opening.is_empty():
		_next_prompt_label.text = str(
			_opening.get("player_goal", "Skriv et indlæg for at fortsætte.")
		)
	else:
		_next_prompt_label.text = "Åbningen vises her, når backendens initialiseringsjob er færdigt."

	_update_controls()


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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	column.add_child(_make_label(speaker, 10, COLOR_GOLD, true))
	var body := _make_label(message, 13, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	_transcript_column.add_child(card)


func _update_briefing_labels() -> void:
	if _opening.is_empty():
		_briefing_tension_label.text = "Start en forhandling for at hente åbningen og din briefing."
		_briefing_goal_label.text = ""
		_simulation_badge.text = "SIMULATION"
		return
	var tension := str(_opening.get("immediate_tension", ""))
	var goal := str(_opening.get("player_goal", ""))
	_briefing_tension_label.text = tension if not tension.is_empty() else "Åbningen er klar."
	_briefing_goal_label.text = "Dit mål: " + goal if not goal.is_empty() else ""
	_simulation_badge.text = "SIMULERET · IKKE HISTORISK CITAT"


func _update_session_label() -> void:
	var record := _current_record()
	if record.is_empty():
		_session_id_label.text = "Ingen gemt session valgt"
		return
	var session_id := str(record.get("session_id", ""))
	if session_id.is_empty():
		_session_id_label.text = "Session-oprettelse kan genoptages"
	else:
		_session_id_label.text = "Session · %s · tur %d" % [
			session_id.substr(0, mini(8, session_id.length())),
			_current_turn_number,
		]


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


func _set_status(message: String, state: String) -> void:
	if _header_status == null:
		return
	_header_status.text = message
	var color := COLOR_MUTED
	match state:
		"ok":
			color = COLOR_GREEN
		"working":
			color = COLOR_AMBER
		"error":
			color = COLOR_RED
	_header_status.add_theme_color_override("font_color", color)
	if _sidebar_status != null:
		_sidebar_status.text = message
		_sidebar_status.add_theme_color_override("font_color", color)


func _set_actor_talking(talking: bool) -> void:
	var preview := get_node_or_null("SeatedNegotiatorPreview")
	if preview == null or not preview.has_method("set_animation"):
		return
	preview.call("set_animation", "SeatedTalking" if talking else "SeatedIdle")


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
