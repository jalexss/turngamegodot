## AuthManager.gd - Gestor de autenticación centralizado (Singleton)
## Maneja login con Steam, refresh automático, persistencia de sesión
extends Node

# ============================================================================
# ENUMS
# ============================================================================

enum AuthState {
	IDLE,                 # Sin operación en curso
	LOGGING_IN,          # Login en proceso
	REFRESHING,          # Refresh token en proceso
	VALIDATING_SESSION,  # Validando sesión al cargar
	ERROR                # Error en última operación
}

# ============================================================================
# MIEMBROS
# ============================================================================

var _state: AuthState = AuthState.IDLE
var _player_data: Dictionary = {}
var _current_http_request: HTTPRequest = null
var _refresh_timer: Timer = null
var _last_error: String = ""

# Señales para la UI
signal login_success(user_data: Dictionary)
signal login_failed(error: String)
signal token_refreshed
signal token_refresh_failed
signal session_loaded(has_valid_session: bool)
signal logout_completed
signal state_changed(new_state: AuthState)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Crear timer para refresh automático
	_refresh_timer = Timer.new()
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_on_refresh_timer_timeout)

func _exit_tree() -> void:
	if _refresh_timer:
		_refresh_timer.stop()
		_refresh_timer.queue_free()
	
	if _current_http_request:
		_current_http_request.queue_free()

# ============================================================================
# ÁREA PÚBLICA: AUTENTICACIÓN
# ============================================================================

## Intenta hacer login con Steam usando ticket de sesión
func login_with_steam(ticket: String, steam_id: String, username: String) -> void:
	if _state == AuthState.LOGGING_IN:
		return

	_set_state(AuthState.LOGGING_IN)

	var config = get_tree().root.get_node("Config")
	var url = config.BACKEND_AUTH_URL + "/steam-login"
	var body = JSON.stringify({
		"ticket": ticket,
		"steamId": str(steam_id),
		"username": username
	})
	
	if config.DEBUG_AUTH:
		print("🔐 [AuthManager] Enviando login con Steam - URL: %s" % url)
		print("🔐 [AuthManager] Ticket: %s... SteamID: %s Username: %s" % [ticket.substr(0, 32), steam_id, username])
	
	_make_request(url, HTTPClient.METHOD_POST, body, "_on_login_completed")

## Intenta refrescar el token de forma manual
func refresh_token_manual() -> void:
	if _state == AuthState.REFRESHING:
		return

	_refresh_token_impl()

## Cierra sesión y limpia datos
func logout() -> void:
	_session_clear()
	_set_state(AuthState.IDLE)
	logout_completed.emit()

## Obtiene el estado actual de autenticación
func get_state() -> AuthState:
	return _state

## Obtiene si estamos en sesión válida
func is_authenticated() -> bool:
	var session_mgr = get_tree().root.get_node("SessionManager")
	return session_mgr.has_valid_session()

## Obtiene los datos del jugador
func get_player_data() -> Dictionary:
	return _player_data.duplicate()

## Obtiene solo el username
func get_username() -> String:
	return _player_data.get("username", "")

## Obtiene solo el email
func get_email() -> String:
	return _player_data.get("email", "")

## Obtiene el user ID
func get_user_id() -> int:
	return _player_data.get("id", -1)

# ============================================================================
# ÁREA PRIVADA: IMPLEMENTACIÓN
# ============================================================================

func _set_state(new_state: AuthState) -> void:
	if _state != new_state:
		_state = new_state
		state_changed.emit(new_state)
		
		var config = get_tree().root.get_node("Config")
		if config.DEBUG_AUTH:
			print("📍 [AuthManager] Estado: %s" % AuthState.keys()[new_state])

func _make_request(url: String, method: int, body: String, callback: String) -> void:
	# Limpiar request anterior si existe
	if _current_http_request and is_instance_valid(_current_http_request):
		_current_http_request.queue_free()
	
	_current_http_request = HTTPRequest.new()
	add_child(_current_http_request)
	_current_http_request.request_completed.connect(Callable(self, callback))
	
	var headers = ["Content-Type: application/json"]
	var error = _current_http_request.request(url, headers, method, body)
	
	if error != OK:
		push_error("❌ [AuthManager] Error al iniciar request HTTP: %d" % error)
		_set_state(AuthState.ERROR)
		_last_error = "Error de conexión"

func _on_login_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _current_http_request and is_instance_valid(_current_http_request):
		_current_http_request.queue_free()
		_current_http_request = null
	
	if _result != HTTPRequest.RESULT_SUCCESS:
		_handle_login_error("Servidores en mantenimiento")
		return
	
	var response = _parse_json_safe(body)
	
	if _response_code == 200:
		_handle_login_success(response)
	elif _response_code == 0:
		_handle_login_error("Servidores en mantenimiento")
	else:
		_handle_login_error(response.get("error", "Error desconocido"))

func _handle_login_success(response: Dictionary) -> void:
	var access_token = response.get("accessToken", "")
	var refresh_token = response.get("refreshToken", "")
	var user = response.get("user", {})
	
	if access_token.is_empty():
		_handle_login_error("Token no recibido del servidor")
		return
	
	_player_data = user
	
	# Guardar sesión
	var session_mgr = get_tree().root.get_node("SessionManager")
	session_mgr.save_session(
		access_token,
		refresh_token,
		user.get("id", -1),
		user.get("username", "") if user.get("username") != null else "",
		user.get("email", "") if user.get("email") != null else ""
	)
	
	_setup_token_refresh()
	_set_state(AuthState.IDLE)
	
	var config = get_tree().root.get_node("Config")
	if config.DEBUG_AUTH:
		print("✅ [AuthManager] Login exitoso: %s" % user.get("username", ""))
	
	login_success.emit(_player_data)

func _handle_login_error(error_msg: String) -> void:
	_last_error = error_msg
	_set_state(AuthState.ERROR)
	
	var config = get_tree().root.get_node("Config")
	if config.DEBUG_AUTH:
		print("❌ [AuthManager] Login fallido: %s" % error_msg)
	
	login_failed.emit(error_msg)

func _refresh_token_impl() -> void:
	_set_state(AuthState.REFRESHING)
	
	var session_mgr = get_tree().root.get_node("SessionManager")
	var refresh_token = session_mgr.get_refresh_token()
	if refresh_token.is_empty():
		_handle_refresh_error("No hay refresh token disponible")
		return
	
	var config = get_tree().root.get_node("Config")
	var url = config.BACKEND_AUTH_URL + "/refresh"
	var body = JSON.stringify({
		"refreshToken": refresh_token
	})
	
	_make_request(url, HTTPClient.METHOD_POST, body, "_on_refresh_completed")

func _on_refresh_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _current_http_request and is_instance_valid(_current_http_request):
		_current_http_request.queue_free()
		_current_http_request = null
	
	if _result != HTTPRequest.RESULT_SUCCESS:
		_handle_refresh_error("Error de conexión con el servidor")
		return
	
	var response = _parse_json_safe(body)
	
	if _response_code == 200:
		_handle_refresh_success(response)
	else:
		_handle_refresh_error(response.get("error", "Token inválido o expirado"))

func _handle_refresh_success(response: Dictionary) -> void:
	var access_token = response.get("accessToken", "")
	var refresh_token = response.get("refreshToken", "")
	
	if access_token.is_empty():
		_handle_refresh_error("Token no recibido del servidor")
		return
	
	var session_mgr = get_tree().root.get_node("SessionManager")
	session_mgr.update_access_token(access_token, refresh_token)
	_setup_token_refresh()
	_set_state(AuthState.IDLE)
	
	var config = get_tree().root.get_node("Config")
	if config.DEBUG_AUTH:
		print("🔄 [AuthManager] Token refrescado exitosamente")
	
	token_refreshed.emit()

func _handle_refresh_error(error_msg: String) -> void:
	_last_error = error_msg
	_set_state(AuthState.ERROR)
	
	var config = get_tree().root.get_node("Config")
	if config.DEBUG_AUTH:
		print("❌ [AuthManager] Refresh fallido: %s" % error_msg)
	
	# Si falla el refresh, limpar sesión
	_session_clear()
	token_refresh_failed.emit()

func _session_clear() -> void:
	_player_data.clear()
	var session_mgr = get_tree().root.get_node("SessionManager")
	session_mgr.clear_session()
	
	if _refresh_timer:
		_refresh_timer.stop()

# ============================================================================
# REFRESH AUTOMÁTICO
# ============================================================================

func _setup_token_refresh() -> void:
	if not _refresh_timer:
		return
	
	var session_mgr = get_tree().root.get_node("SessionManager")
	var remaining_time = session_mgr.get_access_token_remaining_time()
	
	var config = get_tree().root.get_node("Config")
	# Configurar timer para refrescar antes de que expire
	if remaining_time > 0:
		_refresh_timer.wait_time = remaining_time - config.TOKEN_REFRESH_MARGIN
		_refresh_timer.start()
		
		if config.DEBUG_AUTH:
			print("⏱️  [AuthManager] Token refresh programado en %.0f segundos" % _refresh_timer.wait_time)

func _on_refresh_timer_timeout() -> void:
	var config = get_tree().root.get_node("Config")
	if config.DEBUG_AUTH:
		print("⏱️  [AuthManager] Ejecutando refresh automático...")
	
	_refresh_token_impl()

# ============================================================================
# UTILIDADES
# ============================================================================

func _parse_json_safe(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	var result = JSON.parse_string(text)
	return result if result is Dictionary else {}

## Valida y carga sesión previa al iniciar (llamado desde Gateway)
func validate_and_load_session() -> bool:
	_set_state(AuthState.VALIDATING_SESSION)
	
	var session_mgr = get_tree().root.get_node("SessionManager")
	# Esperar a que SessionManager esté cargado
	while not session_mgr.is_loaded():
		await get_tree().process_frame
	
	if session_mgr.has_valid_session():
		# Cargar datos de sesión
		_player_data = {
			"id": session_mgr.get_user_id(),
			"username": session_mgr.get_username(),
			"email": session_mgr.get_email()
		}
		
		# Verificar si token necesita refresh
		if session_mgr.is_access_token_expired():
			var config = get_tree().root.get_node("Config")
			if config.DEBUG_AUTH:
				print("⏱️  [AuthManager] Token expirado, intentando refresh...")
			_refresh_token_impl()
			# Esperar resultado del refresh
			await token_refreshed
		else:
			_setup_token_refresh()
		
		_set_state(AuthState.IDLE)
		session_loaded.emit(true)
		return true
	else:
		_set_state(AuthState.IDLE)
		session_loaded.emit(false)
		return false
