extends Node

## Thin JSON client for the CASES v2 REST API. Session capabilities are sent only
## in Authorization headers and are never printed or included in URLs.

var base_url: String = "http://127.0.0.1:18081"

var _http: HTTPRequest
var _in_flight := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "HTTPRequest"
	_http.timeout = 20.0
	_http.max_redirects = 0
	add_child(_http)


func set_base_url(value: String) -> void:
	base_url = value.strip_edges().trim_suffix("/")


func get_json(path: String, bearer_token: String = "") -> Dictionary:
	return await request_json(HTTPClient.METHOD_GET, path, null, bearer_token)


func post_json(
	path: String,
	payload: Variant = null,
	bearer_token: String = "",
	extra_headers: Dictionary = {}
) -> Dictionary:
	return await request_json(
		HTTPClient.METHOD_POST,
		path,
		payload,
		bearer_token,
		extra_headers
	)


func request_json(
	method: int,
	path: String,
	payload: Variant = null,
	bearer_token: String = "",
	extra_headers: Dictionary = {}
) -> Dictionary:
	if _http == null:
		return _failure(0, "Netværksklienten er ikke startet.")
	if _in_flight:
		return _failure(0, "En anden netværksforespørgsel er stadig i gang.")

	var url := base_url.trim_suffix("/") + path
	var headers := PackedStringArray(["Accept: application/json"])
	var request_body := ""
	if payload != null:
		headers.append("Content-Type: application/json")
		request_body = JSON.stringify(payload)
	if not bearer_token.is_empty():
		headers.append("Authorization: Bearer " + bearer_token)
	for header_name in extra_headers:
		headers.append("%s: %s" % [str(header_name), str(extra_headers[header_name])])

	_in_flight = true
	var request_error := _http.request(url, headers, method, request_body)
	if request_error != OK:
		_in_flight = false
		return _failure(
			0,
			"Godot kunne ikke starte HTTP-forespørgslen (kode %d)." % request_error
		)

	var response: Array = await _http.request_completed
	_in_flight = false
	if response.size() < 4:
		return _failure(0, "Backend returnerede et ufuldstændigt HTTP-svar.")

	var transport_result := int(response[0])
	var response_code := int(response[1])
	var raw_body: PackedByteArray = response[3]
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return _failure(
			response_code,
			"Netværksfejl under kontakt med backend (Godot-kode %d)." % transport_result
		)

	var body_text := raw_body.get_string_from_utf8()
	var parsed: Variant = {}
	if not body_text.strip_edges().is_empty():
		parsed = JSON.parse_string(body_text)
		if parsed == null:
			parsed = {"raw": body_text}

	var succeeded := response_code >= 200 and response_code < 300
	return {
		"ok": succeeded,
		"status": response_code,
		"data": parsed,
		"error": "" if succeeded else _error_message(parsed, response_code),
	}


func _failure(response_code: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"status": response_code,
		"data": {},
		"error": message,
	}


func _error_message(data: Variant, response_code: int) -> String:
	if data is Dictionary:
		var detail: Variant = data.get("detail", data.get("message", ""))
		if detail is Dictionary:
			var code := str(detail.get("code", ""))
			var message := str(detail.get("message", ""))
			if not code.is_empty() and not message.is_empty():
				return "%s — %s" % [code, message]
			if not message.is_empty():
				return message
			if not code.is_empty():
				return code
			return "Backend afviste forespørgslen."
		if detail is String and not detail.strip_edges().is_empty():
			return detail
	return "Backend svarede med HTTP %d." % response_code
