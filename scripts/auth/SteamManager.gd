## SteamManager.gd - Gestor de integración con Steamworks API
## Singleton Autoload que maneja la inicialización de Steam y generación de tickets de sesión
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal steam_ready
signal steam_failed(reason: String)
signal ticket_generated(ticket_hex: String, steam_id: String, persona_name: String)
signal ticket_failed(reason: String)

# ============================================================================
# PROPERTIES
# ============================================================================

var _steam_id: String = ""
var _persona_name: String = ""
var _is_initialized: bool = false
var _init_failed: bool = false
var _init_failed_reason: String = ""
var _ticket_retry_count: int = 0
const MAX_TICKET_RETRIES: int = 1

func _ready() -> void:
	if not Config.STEAM_ENABLED:
		if Config.STEAM_DEBUG:
			print("Steam integration disabled in config")
		_init_failed = true
		_init_failed_reason = "Steam deshabilitado en configuración"
		return

	# Defer initialization so Gateway has time to connect signals
	call_deferred("_initialize_steam")

func _process(_delta: float) -> void:
	if _is_initialized:
		Steam.run_callbacks()

func _initialize_steam() -> void:
	if Config.STEAM_DEBUG:
		print("[SteamManager] Inicializando Steam...")

	if not Steam.isSteamRunning():
		_init_failed = true
		_init_failed_reason = "Steam no está ejecutándose. Abre Steam e intenta de nuevo."
		steam_failed.emit(_init_failed_reason)
		return

	var init_result: Dictionary = Steam.steamInitEx()
	if Config.STEAM_DEBUG:
		print("[SteamManager] steamInitEx resultado: ", init_result)

	if init_result["status"] != 0:
		_init_failed = true
		_init_failed_reason = init_result.get("verbal", "No se pudo inicializar Steam")
		steam_failed.emit(_init_failed_reason)
		return

	_is_initialized = true
	_steam_id = str(Steam.getSteamID())
	_persona_name = Steam.getPersonaName()

	Steam.get_ticket_for_web_api.connect(_on_get_ticket_for_web_api)

	if Config.STEAM_DEBUG:
		print("[SteamManager] Steam listo - ID: %s, Nombre: %s" % [_steam_id, _persona_name])

	steam_ready.emit()

func get_ticket() -> void:
	if not _is_initialized:
		ticket_failed.emit("Steam no inicializado")
		return

	Steam.getAuthTicketForWebApi("turngamegodot")

func _on_get_ticket_for_web_api(auth_ticket: int, result: int, ticket_size: int, ticket_buffer: Array) -> void:
	if Config.STEAM_DEBUG:
		print("[SteamManager] Web API Ticket response - handle: %s, result: %s, size: %s" % [auth_ticket, result, ticket_size])

	if result != 1 or ticket_size <= 0:
		if _ticket_retry_count < MAX_TICKET_RETRIES:
			_ticket_retry_count += 1
			get_ticket()
			return
		else:
			_ticket_retry_count = 0
			ticket_failed.emit("No se pudo generar el ticket")
			return

	_ticket_retry_count = 0
	var ticket_hex := ""
	for b in ticket_buffer:
		ticket_hex += "%02x" % b

	ticket_generated.emit(ticket_hex, _steam_id, _persona_name)

func generate_session_ticket() -> void:
	get_ticket()

func is_steam_ready() -> bool:
	return _is_initialized

func get_persona_name() -> String:
	return _persona_name
