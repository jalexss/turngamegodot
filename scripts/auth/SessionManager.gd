## SessionManager.gd - Manejo de persistencia de sesión
## Guarda/carga tokens de forma asíncrona
extends Node

# ============================================================================
# TIPOS
# ============================================================================

## Estructura de una sesión guardada
class SessionData:
	var accessToken: String = ""
	var refreshToken: String = ""
	var userId: int = -1
	var username: String = ""
	var createdAt: float = 0.0  # timestamp de creación de la sesión

# ============================================================================
# MIEMBROS
# ============================================================================

var _session: SessionData = SessionData.new()
var _config_file: ConfigFile
var _is_loaded: bool = false

# Señales
signal session_loaded
signal session_saved
signal session_cleared

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_config_file = ConfigFile.new()
	load_session()

# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================

## Carga la sesión desde el archivo guardado
## Retorna true si se cargó exitosamente
func load_session() -> bool:
	var config = get_tree().root.get_node("Config")
	var error = _config_file.load(config.SESSION_FILE_PATH)
	
	if error != OK:
		if config.DEBUG_AUTH:
			print("ℹ️  [SessionManager] No hay sesión previa guardada")
		_is_loaded = true
		session_loaded.emit()
		return false
	
	# Leer datos de la sesión
	_session.accessToken = _config_file.get_value("session", "access_token", "")
	_session.refreshToken = _config_file.get_value("session", "refresh_token", "")
	_session.userId = _config_file.get_value("session", "user_id", -1)
	_session.username = _config_file.get_value("session", "username", "")
	_session.createdAt = _config_file.get_value("session", "created_at", 0.0)
	
	_is_loaded = true
	
	if config.DEBUG_AUTH:
		print("✅ [SessionManager] Sesión cargada: usuario %s (ID: %d)" % [_session.username, _session.userId])
	
	session_loaded.emit()
	return true

## Guarda la sesión en archivo
func save_session(access_token: String, refresh_token: String, user_id: int, username: String) -> bool:
	_session.accessToken = access_token
	_session.refreshToken = refresh_token
	_session.userId = user_id
	_session.username = username
	_session.createdAt = Time.get_unix_time_from_system()  # timestamp UNIX real
	
	_config_file.set_value("session", "access_token", access_token)
	_config_file.set_value("session", "refresh_token", refresh_token)
	_config_file.set_value("session", "user_id", user_id)
	_config_file.set_value("session", "username", username)
	_config_file.set_value("session", "created_at", _session.createdAt)
	
	var config = get_tree().root.get_node("Config")
	var error = _config_file.save(config.SESSION_FILE_PATH)
	if error != OK:
		push_error("❌ [SessionManager] Error al guardar sesión: código %d" % error)
		return false
	
	if config.DEBUG_AUTH:
		print("✅ [SessionManager] Sesión guardada para usuario: %s" % username)
	
	session_saved.emit()
	return true

## Actualiza solo el accessToken (cuando se refresca)
func update_access_token(new_token: String, refresh_token: String) -> void:
	_session.accessToken = new_token
	_session.refreshToken = refresh_token
	
	_config_file.set_value("session", "access_token", new_token)
	_config_file.set_value("session", "refresh_token", refresh_token)
	var config = get_tree().root.get_node("Config")
	_config_file.save(config.SESSION_FILE_PATH)
	
	if config.DEBUG_AUTH:
		print("🔄 [SessionManager] AccessToken actualizado")

## Limpia la sesión completamente
func clear_session() -> void:
	_session = SessionData.new()
	
	var config = get_tree().root.get_node("Config")
	# Eliminar archivo de sesión
	if FileAccess.file_exists(config.SESSION_FILE_PATH):
		var dir = DirAccess.open(config.SESSION_FILE_PATH.get_base_dir())
		if dir:
			dir.remove(config.SESSION_FILE_PATH.get_file())
	
	if config.DEBUG_AUTH:
		print("🗑️  [SessionManager] Sesión eliminada")
	
	session_cleared.emit()

## Retorna la sesión actual
func get_session() -> SessionData:
	return _session

## Retorna el accessToken actual
func get_access_token() -> String:
	return _session.accessToken

## Retorna el refreshToken actual
func get_refresh_token() -> String:
	return _session.refreshToken

## Retorna el ID del usuario
func get_user_id() -> int:
	return _session.userId

## Retorna el nombre de usuario
func get_username() -> String:
	return _session.username

## Verifica si hay una sesión activa
func has_valid_session() -> bool:
	return _session.accessToken != "" and _session.userId > 0

## Verifica si el token ha expirado localmente
## accessTokenExpiry: duración en segundos del token
func is_access_token_expired(access_token_duration: int = -1) -> bool:
	if not has_valid_session():
		return true
	
	var config = get_tree().root.get_node("Config")
	if access_token_duration == -1:
		access_token_duration = config.ACCESS_TOKEN_EXPIRY
	
	var current_time = Time.get_unix_time_from_system()
	var expiry_time = _session.createdAt + access_token_duration
	
	# Refresca si le queda menos tiempo que el margen de seguridad
	return current_time >= (expiry_time - config.TOKEN_REFRESH_MARGIN)

## Retorna tiempo restante del accessToken en segundos (0 si expirado)
func get_access_token_remaining_time(access_token_duration: int = -1) -> float:
	if not has_valid_session():
		return 0.0
	
	var config = get_tree().root.get_node("Config")
	if access_token_duration == -1:
		access_token_duration = config.ACCESS_TOKEN_EXPIRY
	
	var current_time = Time.get_unix_time_from_system()
	var expiry_time = _session.createdAt + access_token_duration
	var remaining = expiry_time - current_time
	
	return maxf(0.0, remaining)

## Verifica si la sesión fue cargada
func is_loaded() -> bool:
	return _is_loaded
