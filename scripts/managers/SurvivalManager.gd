## SurvivalManager.gd - Gestión de partidas de supervivencia (save/resume)
## Singleton Autoload
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal run_started_remote(run_data: Dictionary)
signal run_saved
signal run_loaded(run_data: Dictionary)
signal run_ended_remote(result: String)
signal save_failed(reason: String)
signal request_failed(reason: String)

# ============================================================================
# STATE
# ============================================================================

var _active_run: Dictionary = {}
var _has_active_run: bool = false
var _saving: bool = false

# ============================================================================
# PUBLIC
# ============================================================================

func has_active_run() -> bool:
	return _has_active_run

func get_active_run_data() -> Dictionary:
	return _active_run.duplicate(true)

## Start a new run on the backend
func start_run(seed_val: int, characters: Array, map_data: Array) -> void:
	var url = Config.BACKEND_BASE_URL + "/survival/start"
	var body = JSON.stringify({
		"seed": seed_val,
		"characters": _serialize_characters(characters),
		"map_data": map_data
	})
	_make_auth_request(url, HTTPClient.METHOD_POST, body, "_on_start_run_response")

## Save progress after node reward selection
func save_progress(floor_idx: int, branch_idx: int, gold_val: int, characters: Array, buffs: Array, items: Array = [], map_data: Array = []) -> void:
	if _saving:
		print("⚠️ SurvivalManager: ya se está guardando, ignorando")
		return
	_saving = true
	var url = Config.BACKEND_BASE_URL + "/survival/save"
	var body = JSON.stringify({
		"current_floor": floor_idx,
		"current_branch": branch_idx,
		"gold": gold_val,
		"characters": _serialize_characters(characters),
		"run_buffs": buffs,
		"items": items,
		"map_data": map_data
	})
	_make_auth_request(url, HTTPClient.METHOD_PUT, body, "_on_save_progress_response")

## End the current run
func end_run(result: String, duration_seconds: int = 0) -> void:
	var url = Config.BACKEND_BASE_URL + "/survival/end"
	var body = JSON.stringify({
		"result": result,
		"duration_seconds": duration_seconds
	})
	_make_auth_request(url, HTTPClient.METHOD_PUT, body, "_on_end_run_response")

## Check for an active run on the backend
func check_active_run() -> void:
	var url = Config.BACKEND_BASE_URL + "/survival/active"
	_make_auth_request(url, HTTPClient.METHOD_GET, "", "_on_check_active_response")

## Fetch run history (paginated)
func fetch_run_history(page: int = 1, limit: int = 10) -> void:
	var url = Config.BACKEND_BASE_URL + "/survival/history?page=%d&limit=%d" % [page, limit]
	_make_auth_request(url, HTTPClient.METHOD_GET, "", "_on_history_response")

# ============================================================================
# RESUME LOGIC
# ============================================================================

## Resume an active run — restores GameManager state from backend data
func resume_run() -> void:
	if not _has_active_run:
		request_failed.emit("No hay partida activa para continuar")
		return

	var gm = get_tree().root.get_node("GameManager")
	if not gm:
		request_failed.emit("GameManager no disponible")
		return

	var run = _active_run

	# Restore GameManager state
	gm.current_mode = gm.GameMode.SURVIVAL
	gm.run_state = gm.RunState.IN_MAP
	gm.current_seed = int(run.get("seed", 0))
	gm.current_node_index = int(run.get("current_floor", 0))
	gm.current_branch_index = int(run.get("current_branch", 0))
	gm.gold = int(run.get("gold", 0))
	gm.run_buffs = run.get("run_buffs", [])

	# Restore map — fix types from JSON (floats → ints for enum matching)
	var map_data = run.get("map_data", [])
	gm.map_nodes = _fix_map_data_types(map_data)
	gm.total_nodes = gm.map_nodes.size()

	# Restore characters
	var chars_data = run.get("characters", [])
	gm.selected_characters.clear()
	for cdict in chars_data:
		var char_data = gm.create_character_data(cdict)
		# Override HP with saved HP
		char_data.hp = int(cdict.get("hp", char_data.max_hp))
		# Restore permanent buffs
		var saved_buffs = cdict.get("permanent_buffs", [])
		for buff in saved_buffs:
			char_data.apply_permanent_buff(buff.get("type", ""), int(buff.get("value", 0)), buff.get("source", "resume"))
		gm.selected_characters.append(char_data)

	gm.gold_changed.emit(gm.gold)
	gm.run_started.emit()

	print("🔄 Run restaurada — piso %d, oro %d, %d personajes" % [gm.current_node_index, gm.gold, gm.selected_characters.size()])

	# Navigate to map
	get_tree().change_scene_to_file(gm.MAP_SCENE)

# ============================================================================
# TYPE CONVERSION (JSON floats → ints)
# ============================================================================

## GDScript's JSON.parse_string converts all numbers to float.
## GDScript match is type-strict (0.0 != 0), so we must cast back to int.
func _fix_map_data_types(map_data) -> Array:
	if not map_data is Array:
		return []
	var fixed: Array = []
	for level in map_data:
		if not level is Array:
			fixed.append(level)
			continue
		var fixed_level: Array = []
		for node in level:
			if node is Dictionary:
				fixed_level.append(_fix_node_types(node))
			else:
				fixed_level.append(node)
		fixed.append(fixed_level)
	return fixed

func _fix_node_types(node: Dictionary) -> Dictionary:
	var fixed = node.duplicate(true)
	# Only "type" must be int for match/enum comparison in GameManager
	if fixed.has("type") and fixed["type"] is float:
		fixed["type"] = int(fixed["type"])
	return fixed

# ============================================================================
# SERIALIZATION
# ============================================================================

func _serialize_characters(characters: Array) -> Array:
	var result: Array = []
	for c in characters:
		if c is CharacterData:
			result.append({
				"id": c.id,
				"name": c.name,
				"description": c.description,
				"hp": c.hp,
				"max_hp": c.max_hp,
				"attack": c.attack,
				"defense": c.defense,
				"rate": c.rate,
				"role": c.role,
				"deck_id": c.deck_id,
				"range": c.char_range,
				"portrait": c.sprite_path,
				"idle": c.idle,
				"base_attack": c.base_attack,
				"base_defense": c.base_defense,
				"base_max_hp": c.base_max_hp,
				"base_rate": c.base_rate,
				"permanent_buffs": c.permanent_buffs.duplicate(true)
			})
		elif c is Dictionary:
			result.append(c)
	return result

# ============================================================================
# HTTP
# ============================================================================

func _make_auth_request(url: String, method: int, body: String, callback: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(Callable(self, callback).bind(http))

	var session_mgr = get_tree().root.get_node("SessionManager")
	var token = session_mgr.get_access_token()
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]

	var error: int
	if body.is_empty():
		error = http.request(url, headers, method)
	else:
		error = http.request(url, headers, method, body)

	if error != OK:
		http.queue_free()
		request_failed.emit("Error de conexión")

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_start_run_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	var data = _parse_json(body)
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 201:
		request_failed.emit(data.get("error", "Error al iniciar partida"))
		return
	_active_run = data.get("run", {})
	_has_active_run = true
	print("✅ Run iniciada en backend — ID: ", _active_run.get("id", "?"))
	run_started_remote.emit(_active_run)

func _on_save_progress_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	_saving = false
	var data = _parse_json(body)
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		save_failed.emit(data.get("error", "Error al guardar progreso"))
		return
	# Merge response into cached run (don't replace — response may be partial)
	var save_data = data.get("run", {})
	for key in save_data.keys():
		_active_run[key] = save_data[key]
	print("💾 Progreso guardado — piso ", _active_run.get("current_floor", "?"))
	run_saved.emit()

func _on_end_run_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	var data = _parse_json(body)
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		request_failed.emit(data.get("error", "Error al finalizar partida"))
		return
	_active_run = {}
	_has_active_run = false
	var result_str = data.get("result", "unknown")
	print("🏁 Run finalizada — resultado: ", result_str)
	run_ended_remote.emit(result_str)

func _on_check_active_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	var data = _parse_json(body)
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_has_active_run = false
		request_failed.emit("Error al verificar partida activa")
		return
	_has_active_run = data.get("has_active_run", false)
	if _has_active_run:
		_active_run = data.get("run", {})
		print("🔄 Partida activa encontrada — piso ", _active_run.get("current_floor", 0))
		run_loaded.emit(_active_run)
	else:
		_active_run = {}
		print("ℹ️ No hay partida activa")

func _on_history_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	# History is informational; just print for now
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var data = _parse_json(body)
	print("📜 Historial: ", data.get("runs", []).size(), " runs")

func _parse_json(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	var result = JSON.parse_string(text)
	return result if result is Dictionary else {}
