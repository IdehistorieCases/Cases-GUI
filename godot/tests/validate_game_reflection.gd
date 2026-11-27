extends SceneTree

class FakeApi extends Node:
	var next_response: Dictionary = {}
	var last_path := ""
	var last_get_path := ""

	func post_json(
		path: String,
		_payload: Variant = null,
		_bearer_token: String = "",
		_extra_headers: Dictionary = {},
		timeout_seconds: float = 20.0
	) -> Dictionary:
		last_path = path
		last_timeout_seconds = timeout_seconds
		post_requests.append(
			{
				"path": path,
				"payload": _payload.duplicate(true) if _payload is Dictionary else _payload,
				"headers": _extra_headers.duplicate(true),
			}
		)
		if not post_responses.is_empty():
			return post_responses.pop_front()
		return next_response.duplicate(true)

	func get_json(
		path: String, _bearer_token: String = "", _timeout_seconds: float = 20.0
	) -> Dictionary:
		last_get_path = path
		return get_responses.get(path, {"ok": false, "status": 404}).duplicate(true)

	var last_timeout_seconds := 0.0
	var post_requests: Array = []
	var post_responses: Array = []
	var get_responses: Dictionary = {}


var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var client_script: Script = load("res://scripts/game_client.gd")
	var client: Node = client_script.new()
	client.call("_build_interface")
	var fake_api := FakeApi.new()
	client.add_child(fake_api)
	client.set("_api", fake_api)

	var record := {
		"local_id": "reflection-test",
		"session_id": "completed-session",
		"capability": "test-capability",
		"reflection": {},
	}
	client.set(
		"_store",
		{
			"sessions": [record],
			"current_session_local_id": "reflection-test",
			"base_url": "http://127.0.0.1:18082",
		}
	)
	client.set("_backend_ready", true)
	client.set("_session_completed", false)
	client.call("_update_controls")
	var complete_button := client.get("_complete_button") as Button
	var composer_row := client.get("_composer_row") as Control
	var results_panel := client.get("_results_panel") as Control
	var retry_reflection_button := client.get("_retry_reflection_button") as Button
	_expect(complete_button != null, "Player can explicitly end a negotiation")
	_expect(composer_row != null, "Composer controls have a replaceable container")
	_expect(results_panel != null, "Completed sessions have a dedicated results/reflection panel")
	_expect(retry_reflection_button != null, "Reflection failure has a dedicated retry action")
	_expect(results_panel != null and not results_panel.visible, "Results stay hidden before completion")
	client.set("_session_completed", true)
	client.set("_opening", {"title": "Test", "scene": "Åbningstekst."})
	client.set("_turns", [{"next_player_prompt": null, "completion_reason": "player_end"}])
	client.set(
		"_session_snapshot",
		{"turn_number": 1, "state": {"completion_status": "complete", "completion_reason": "player_end"}}
	)
	client.call("_render_transcript")
	var prompt := client.get("_next_prompt_label") as Label
	_expect(
		prompt != null and prompt.text.to_lower().contains("afsluttet") and prompt.text != "<null>",
		"Completed sessions show a readable ending instead of a null prompt"
	)
	_expect(composer_row != null and not composer_row.visible, "Completion replaces the live composer")
	_expect(results_panel != null and results_panel.visible, "Completion opens the results/reflection panel")

	_expect(client.has_method("_request_reflection"), "Reflection request handler exists")
	if client.has_method("_request_reflection"):
		fake_api.next_response = {"ok": false, "status": 503, "error": "Temporary failure"}
		await client.call("_request_reflection")
		_expect(
			fake_api.last_path == "/api/v1/sessions/completed-session/reflection",
			"Reflection uses the completed session endpoint"
		)
		_expect(
			is_equal_approx(fake_api.last_timeout_seconds, 300.0),
			"Reflection requests allow time for the backend model response"
		)
		_expect(
			retry_reflection_button != null
				and retry_reflection_button.visible
				and not retry_reflection_button.disabled,
			"Temporary reflection failure leaves a retry action available"
		)

	var test_store_path := "user://cases_reflection_test_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	client.set("_session_store_path", test_store_path)
	client.set("_session_completed", false)
	client.set("_current_turn_number", 2)
	client.set("_opening", {"title": "Teståbning", "scene": "Åbningstekst."})
	client.set("_turns", [{"turn_number": 1, "player_text": "Et forslag", "reply": "Et svar."}])
	client.set("_reflection_error", "")
	client.set("_reflection_retry_pending", false)
	client.set("_reflection_failed_permanently", false)
	record["pending_completion"] = {}
	record["reflection"] = {}
	fake_api.next_response = {"ok": false, "status": 503, "error": "Temporary failure"}
	await client.call("_complete_session")
	var saved_completion: Dictionary = record.get("pending_completion", {})
	var failed_completion_request: Dictionary = fake_api.post_requests.back()
	var failed_payload: Dictionary = failed_completion_request.get("payload", {})
	var failed_headers: Dictionary = failed_completion_request.get("headers", {})
	_expect(
		failed_completion_request.get("path", "") == "/api/v1/sessions/completed-session/completion",
		"Player completion uses the completion endpoint"
	)
	_expect(
		not saved_completion.is_empty()
			and failed_payload.get("client_turn_id") == saved_completion.get("client_turn_id")
			and failed_headers.get("Idempotency-Key") == saved_completion.get("client_turn_id"),
		"A failed completion keeps its idempotency key for safe retry"
	)
	_expect(
		complete_button != null
			and complete_button.text == "Prøv igen"
			and not complete_button.disabled,
		"Temporary completion failure leaves a completion retry available"
	)

	var completion_request_start := fake_api.post_requests.size()
	var session_path := "/api/v1/sessions/completed-session"
	fake_api.get_responses = {
		session_path: {
			"ok": true,
			"data": {
				"turn_number": 3,
				"state": {"completion_status": "complete", "completion_reason": "player_end"},
			}
		},
		session_path + "/initialization": {
			"ok": true,
			"data": {"status": "ready", "opening": {"title": "Teståbning", "scene": "Åbningstekst."}},
		},
		session_path + "/turns": {
			"ok": true,
			"data": {"turns": [{"turn_number": 3, "player_text": "Afslut sagen.", "reply": "Forløbet afsluttes."}]},
		},
	}
	fake_api.post_responses = [
		{"ok": true, "status": 201, "data": {}},
		{
			"ok": true,
			"status": 200,
			"data": {
				"status": "ready",
				"summary": "En kvalitativ refleksion.",
				"player_choices": [],
				"simulated_consequences": [],
				"objectives": [],
				"evidence_status": "evidence_unavailable",
				"historical_evidence_ids": [],
				"historical_abstention": null,
				"uncertainty_notes": ["Ingen godkendte historiske passager."],
			},
		},
	]
	await client.call("_complete_session")
	var retried_completion_request: Dictionary = fake_api.post_requests[completion_request_start]
	var retried_payload: Dictionary = retried_completion_request.get("payload", {})
	_expect(
		retried_payload.get("client_turn_id") == saved_completion.get("client_turn_id"),
		"Completion retry reuses the original client turn ID"
	)
	_expect(
		bool(record.get("pending_completion", {}).is_empty())
			and str(record.get("reflection", {}).get("status", "")) == "ready"
			and results_panel != null
			and results_panel.visible
			and composer_row != null
			and not composer_row.visible,
		"Successful completion clears the pending request and opens the cached result view"
	)
	var completed_reflection_labels := _collect_label_texts(results_panel)
	_expect(
		not completed_reflection_labels.has("<null>"),
		"Nullable historical reflection fields are never rendered as the null token"
	)
	_expect(
		completed_reflection_labels.has("Der var ikke godkendt historisk belæg til en sammenligning."),
		"A null historical abstention uses the evidence-status explanation"
	)
	_expect(
		completed_reflection_labels.has("En kvalitativ refleksion."),
		"A ready reflection still displays its summary"
	)

	record["reflection"] = {}
	client.set("_reflection_result", {})
	client.set("_reflection_error", "")
	client.set("_reflection_retry_pending", false)
	fake_api.next_response = {
		"ok": true,
		"status": 200,
		"data": {"status": "ready", "summary": null},
	}
	await client.call("_request_reflection")
	var null_summary_labels := _collect_label_texts(results_panel)
	_expect(
		record.get("reflection", {}).is_empty(),
		"A reflection without a string summary is not cached as ready"
	)
	_expect(
		retry_reflection_button.visible and not retry_reflection_button.disabled,
		"A missing reflection summary leaves a retry action available"
	)
	_expect(
		not null_summary_labels.has("<null>"),
		"A missing reflection summary is never rendered as the null token"
	)

	record["reflection"] = {"status": "ready", "summary": "<null>"}
	client.set("_reflection_result", record["reflection"])
	client.set("_reflection_error", "")
	var reflection_request_count := fake_api.post_requests.size()
	fake_api.next_response = {
		"ok": true,
		"status": 200,
		"data": {
			"status": "ready",
			"completion": {},
			"summary": "Nyt resumé efter genhentning.",
			"player_choices": [],
			"simulated_consequences": [],
			"player_claims": [],
			"documented_history": [],
			"unsupported_historical_claim_count": 0,
			"objectives": [],
			"unknown_objective_observation_count": 0,
			"evidence_status": "evidence_unavailable",
			"historical_comparison": null,
			"historical_abstention": null,
			"historical_evidence_ids": [],
			"sources": [],
			"uncertainty_notes": ["Ingen godkendte historiske passager."],
			"provenance": {},
		},
	}
	await client.call("_request_reflection")
	_expect(
		fake_api.post_requests.size() == reflection_request_count + 1
			and str(record.get("reflection", {}).get("summary", "")) == "Nyt resumé efter genhentning.",
		"A cached null-token summary is discarded and fetched again"
	)

	var long_message := "En lang besked " + "ord ".repeat(80)
	client.call("_add_message", "TEST", long_message, "system")
	var transcript := client.get("_transcript_column") as VBoxContainer
	var last_card := transcript.get_child(transcript.get_child_count() - 1) as PanelContainer
	var body := last_card.get_child(0).get_child(0).get_child(1) as Label
	_expect(body != null and body.text == long_message, "Transcript retains the full supplied message")

	client.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_store_path))
	if failures.is_empty():
		print("GAME REFLECTION TESTS PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAME REFLECTION TESTS FAIL: %d" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _collect_label_texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	if node is Label:
		result.append((node as Label).text)
	for child in node.get_children():
		result.append_array(_collect_label_texts(child))
	return result
