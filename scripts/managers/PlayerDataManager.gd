## PlayerDataManager.gd - Gestión de datos del jugador (inventario, personajes, gacha)
## Singleton Autoload
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal characters_loaded(characters: Array)
signal inventory_loaded(cristales: int)
signal gacha_result(results: Array, cristales: int, pity_counter: int)
signal gacha_failed(reason: String)
signal data_load_failed(reason: String)

# ============================================================================
# CONSTANTS
# ============================================================================

const PULL_COST_SINGLE: int = 100
const PULL_COST_MULTI: int = 900

# ============================================================================
# STATE
# ============================================================================

var _unlocked_characters: Array = []  # Array of dicts from backend
var _cristales: int = 0
var _is_loaded: bool = false

# ============================================================================
# PUBLIC
# ============================================================================

func get_cristales() -> int:
	return _cristales

func get_unlocked_characters() -> Array:
	return _unlocked_characters.duplicate()

func get_unlocked_character_ids() -> Array:
	var ids: Array = []
	for c in _unlocked_characters:
		ids.append(c.get("character_id", -1))
	return ids

func is_character_unlocked(character_id: int) -> bool:
	return character_id in get_unlocked_character_ids()

func is_loaded() -> bool:
	return _is_loaded

func can_pull_single() -> bool:
	return _cristales >= PULL_COST_SINGLE

func can_pull_multi() -> bool:
	return _cristales >= PULL_COST_MULTI

## Called after login to set initial data from login response
func set_initial_data(characters: Array, inventory: Dictionary) -> void:
	_unlocked_characters = characters if characters != null else []
	_cristales = inventory.get("cristales", 0) if inventory != null else 0
	_is_loaded = true
	characters_loaded.emit(_unlocked_characters)
	inventory_loaded.emit(_cristales)

## Fetch characters from backend
func fetch_characters() -> void:
	var url = Config.BACKEND_BASE_URL + "/player/characters"
	_make_auth_request(url, HTTPClient.METHOD_GET, "", "_on_characters_response")

## Fetch inventory from backend
func fetch_inventory() -> void:
	var url = Config.BACKEND_BASE_URL + "/player/inventory"
	_make_auth_request(url, HTTPClient.METHOD_GET, "", "_on_inventory_response")

## Pull gacha
func pull_gacha(count: int) -> void:
	var url = Config.BACKEND_BASE_URL + "/player/gacha/pull"
	var body = JSON.stringify({"count": count})
	_make_auth_request(url, HTTPClient.METHOD_POST, body, "_on_gacha_response")

# ============================================================================
# PRIVATE — HTTP
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
		data_load_failed.emit("Error de conexión")

func _on_characters_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		data_load_failed.emit("Error al obtener personajes")
		return
	var data = _parse_json(body)
	_unlocked_characters = data.get("characters", [])
	_is_loaded = true
	characters_loaded.emit(_unlocked_characters)

func _on_inventory_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if _result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		data_load_failed.emit("Error al obtener inventario")
		return
	var data = _parse_json(body)
	_cristales = data.get("cristales", 0)
	inventory_loaded.emit(_cristales)

func _on_gacha_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if _result != HTTPRequest.RESULT_SUCCESS:
		gacha_failed.emit("Error de conexión")
		return
	var data = _parse_json(body)
	if response_code != 200:
		gacha_failed.emit(data.get("error", "Error en el gacha"))
		return

	_cristales = data.get("cristales", _cristales)
	var results = data.get("results", [])
	var pity = data.get("pity_counter", 0)

	# Update local unlocked characters with new ones
	for r in results:
		if r.get("is_new", false):
			_unlocked_characters.append({
				"character_id": r.get("character_id"),
				"is_starter": false
			})

	inventory_loaded.emit(_cristales)
	gacha_result.emit(results, _cristales, pity)

func _parse_json(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	var result = JSON.parse_string(text)
	return result if result is Dictionary else {}
