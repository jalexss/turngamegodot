## Config.gd - Configuración centralizada y autoload
## Accesible globalmente como Config.property_name
extends Node

# ============================================================================
# NETWORK
# ============================================================================

# URL base del backend
const BACKEND_BASE_URL: String = "http://localhost:3000/api"
const BACKEND_AUTH_URL: String = BACKEND_BASE_URL + "/auth"
const BACKEND_USER_URL: String = BACKEND_BASE_URL + "/user"

# Timeouts (en segundos)
const HTTP_TIMEOUT: float = 10.0
const NETWORK_CHECK_INTERVAL: float = 5.0

# ============================================================================
# AUTHENTICATION
# ============================================================================

# Duración de tokens (para validación en cliente)
const ACCESS_TOKEN_EXPIRY: int = 15 * 60  # 15 minutos en segundos
const REFRESH_TOKEN_EXPIRY: int = 7 * 24 * 60 * 60  # 7 días en segundos

# Margen de seguridad para refrescar token antes de expirar (en segundos)
const TOKEN_REFRESH_MARGIN: int = 60  # Refrescar 1 min antes de expirar

# ============================================================================
# STEAM INTEGRATION
# ============================================================================

# App ID de Steam (480 para pruebas con Spacewar)
const STEAM_APP_ID: int = 480

# Habilitar/deshabilitar integración con Steam
const STEAM_ENABLED: bool = true

# Debug detallado para Steam API
const STEAM_DEBUG: bool = false

# Timeout para operaciones de Steam (en segundos)
const STEAM_TIMEOUT: float = 10.0

# ============================================================================
# DEBUG & TESTING
# ============================================================================

# Activar logs detallados de autenticación
const DEBUG_AUTH: bool = true

# ============================================================================
# PERSISTENCE
# ============================================================================

# Ruta para guardar sesión del usuario
const SESSION_FILE_PATH: String = "user://session.cfg"

# ============================================================================
# MÉTODOS AUXILIARES
# ============================================================================

func _ready() -> void:
	if DEBUG_AUTH:
		print("[Config] Inicializado - Backend URL: %s" % BACKEND_BASE_URL)

## Obtiene la duración del accessToken en segundos
func get_access_token_duration() -> int:
	return ACCESS_TOKEN_EXPIRY

## Obtiene la duración del refreshToken en segundos
func get_refresh_token_duration() -> int:
	return REFRESH_TOKEN_EXPIRY

## Calcula el timestamp de expiración de un token
## timestamp_created: cuando se recibió el token
## token_lifetime: duración en segundos del token
func calculate_expiry_timestamp(timestamp_created: float, token_lifetime: int) -> float:
	return timestamp_created + token_lifetime
