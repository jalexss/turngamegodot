## NetworkValidator.gd - Detección de conectividad online/offline
## Realiza pings periódicos al backend para verificar disponibilidad
extends Node

# ============================================================================
# MIEMBROS
# ============================================================================

var _is_online: bool = true
var _is_checking: bool = false
var _http_request: HTTPRequest
var _check_timer: Timer

# Señales
signal connection_status_changed(is_online: bool)
signal check_completed(is_online: bool)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	var config = get_tree().root.get_node("Config")
	# Crear timer para chequeos periódicos
	_check_timer = Timer.new()
	add_child(_check_timer)
	_check_timer.wait_time = config.NETWORK_CHECK_INTERVAL
	_check_timer.timeout.connect(_on_check_timer_timeout)
	
	# Crear HTTPRequest
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_network_check_completed)
	
	# Iniciar chequeos periódicos pero con pequeño delay
	await get_tree().process_frame
	_check_network()
	_check_timer.start()
	
	if config.DEBUG_AUTH:
		print("🌐 [NetworkValidator] Inicializado")

func _exit_tree() -> void:
	if _check_timer:
		_check_timer.stop()
		_check_timer.queue_free()
	if _http_request:
		_http_request.queue_free()

# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================

## Obtiene el estado de conectividad actual
func is_online() -> bool:
	return _is_online

## Fuerza un chequeo inmediato
func check_now() -> void:
	_check_network()

## Detiene los chequeos automáticos
func stop_checking() -> void:
	if _check_timer:
		_check_timer.stop()

## Reanuda los chequeos automáticos
func resume_checking() -> void:
	if _check_timer:
		_check_timer.start()

# ============================================================================
# PRIVADOS
# ============================================================================

func _on_check_timer_timeout() -> void:
	_check_network()

func _check_network() -> void:
	var config = get_tree().root.get_node("Config")
	if _is_checking:
		return
	
	_is_checking = true
	
	# Intentar request simple al backend (health check endpoint)
	var url = config.BACKEND_BASE_URL + "/health"
	var headers = ["Content-Type: application/json"]
	var error = _http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		_is_checking = false
		_handle_connection_lost()

func _on_network_check_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_is_checking = false
	
	var was_online = _is_online
	var config = get_tree().root.get_node("Config")
	
	# Consideramos online si recibimos respuesta del servidor (cualquier código)
	_is_online = (_result == HTTPRequest.RESULT_SUCCESS)
	
	if config.DEBUG_AUTH:
		var status = "🟢 ONLINE" if _is_online else "🔴 OFFLINE"
		print("🌐 [NetworkValidator] Estado: %s (código HTTP: %d)" % [status, response_code])
	
	# Emitir señal si cambió el estado
	if was_online != _is_online:
		connection_status_changed.emit(_is_online)
	
	check_completed.emit(_is_online)

func _handle_connection_lost() -> void:
	var was_online = _is_online
	_is_online = false
	var config = get_tree().root.get_node("Config")
	
	if was_online:
		if config.DEBUG_AUTH:
			print("🔴 [NetworkValidator] Conexión perdida")
		connection_status_changed.emit(false)
