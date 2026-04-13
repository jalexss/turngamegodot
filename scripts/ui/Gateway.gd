## Gateway.gd - Controlador principal: auto-login con Steam
## Si Steam falla o no se puede autenticar, el juego se cierra
extends Control

class_name GatewayScreen

# ============================================================================
# ENUMS
# ============================================================================

enum FlowState {
	SPLASH,          # Pantalla de carga / conectando
	AUTHENTICATING,  # Ticket o backend en proceso
	AUTHENTICATED    # Listo para transicionar a MainMenu
}

# ============================================================================
# NODOS
# ============================================================================

@onready var background = $Background
@onready var center_container = $CenterContainer
@onready var vbox_container = $CenterContainer/VBoxContainer

# Componentes de UI (splash only)
var _title_label: Label
var _status_label: Label
var _loading_spinner: Control
var _loading_label: Label

# ============================================================================
# MIEMBROS
# ============================================================================

var _current_flow_state: FlowState = FlowState.SPLASH
var _tween: Tween = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("[Gateway] Inicializando...")

	var auth_mgr = get_tree().root.get_node("AuthManager")
	var steam_mgr = get_tree().root.get_node("SteamManager")

	# Crear UI (solo splash + status)
	_create_ui_dynamically()
	_show_status("Conectando con Steam...")

	# Conectar señales de AuthManager
	auth_mgr.login_success.connect(_on_login_success)
	auth_mgr.login_failed.connect(_on_login_failed)
	auth_mgr.session_loaded.connect(_on_session_loaded)

	# Conectar señales de SteamManager
	steam_mgr.steam_ready.connect(_on_steam_ready)
	steam_mgr.steam_failed.connect(_on_steam_failed)
	steam_mgr.ticket_generated.connect(_on_steam_ticket_generated)
	steam_mgr.ticket_failed.connect(_on_steam_ticket_failed)

	# Si SteamManager ya falló antes de conectar señales, cerrar
	if steam_mgr._init_failed:
		_on_steam_failed(steam_mgr._init_failed_reason)
		return

	# Validar sesión previa (puede auto-login con token guardado)
	_validate_session()

func _exit_tree() -> void:
	if _tween:
		_tween.kill()

# ============================================================================
# INICIALIZACIÓN UI (solo splash)
# ============================================================================

func _create_ui_dynamically() -> void:
	var splash_vbox = VBoxContainer.new()
	splash_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	splash_vbox.add_theme_constant_override("separation", 20)
	vbox_container.add_child(splash_vbox)

	# Título
	_title_label = Label.new()
	_title_label.text = "TURN GAME"
	_title_label.add_theme_font_size_override("font_size", 60)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash_vbox.add_child(_title_label)

	# Spinner de carga
	if ClassDB.class_exists("LoadingSpinner"):
		_loading_spinner = LoadingSpinner.new()
		_loading_spinner.set_meta("is_spinner", true)
		_loading_spinner.spinner_size = 50.0
		_loading_spinner.rotation_speed = 2.5
		_loading_spinner.show_text = true
		_loading_spinner.spinner_text = "Conectando..."
		splash_vbox.add_child(_loading_spinner)
		if _loading_spinner.has_method("start_spinning"):
			_loading_spinner.start_spinning()
	else:
		_loading_label = Label.new()
		_loading_label.text = "Conectando..."
		_loading_label.add_theme_font_size_override("font_size", 20)
		_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		splash_vbox.add_child(_loading_label)

	# Status label (debajo del spinner)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash_vbox.add_child(_status_label)

# ============================================================================
# FLUJO: VALIDACIÓN Y AUTO-LOGIN
# ============================================================================

func _validate_session() -> void:
	print("[Gateway] Validando sesión previa...")
	var auth_mgr = get_tree().root.get_node("AuthManager")
	await auth_mgr.validate_and_load_session()

func _on_session_loaded(has_valid_session: bool) -> void:
	if has_valid_session:
		print("[Gateway] Sesión válida encontrada - cargando datos del jugador...")
		_show_status("Cargando datos del jugador...")
		_set_flow_state(FlowState.AUTHENTICATED)

		# Fetch player data before transitioning (session resume doesn't include it)
		var pdm = get_tree().root.get_node("PlayerDataManager")
		if not pdm.is_loaded():
			pdm.fetch_characters()
			pdm.fetch_inventory()
			# Wait for characters (critical path) with timeout
			var timeout_timer = get_tree().create_timer(8.0)
			var result = await _await_first([pdm.characters_loaded, pdm.data_load_failed, timeout_timer.timeout])
			if result == "data_load_failed" or result == "timeout":
				print("[Gateway] ⚠️ Error cargando datos — reintentando login con Steam")
				_show_status("Error de carga — reautenticando...")
				var auth_mgr = get_tree().root.get_node("AuthManager")
				auth_mgr.logout()
				_set_flow_state(FlowState.AUTHENTICATING)
				_start_steam_login()
				return

		_transition_to_main_menu()
		return

	# No hay sesión guardada: iniciar auto-login Steam
	print("[Gateway] Sin sesión guardada - iniciando Steam auto-login")
	_start_steam_login()

func _start_steam_login() -> void:
	_show_status("Obteniendo ticket de Steam...")
	_set_flow_state(FlowState.AUTHENTICATING)
	var steam_mgr = get_tree().root.get_node("SteamManager")
	if steam_mgr.is_steam_ready():
		steam_mgr.get_ticket()
	else:
		# SteamManager aún inicializando (call_deferred), esperar señal
		_show_status("Esperando inicialización de Steam...")

## Awaits the first of multiple signals and returns which one fired.
## Returns: "characters_loaded", "data_load_failed", or "timeout"
func _await_first(signals: Array) -> String:
	# signals = [characters_loaded, data_load_failed, timeout]
	var result := ""
	var signal_names := ["characters_loaded", "data_load_failed", "timeout"]

	for i in range(signals.size()):
		var sig = signals[i]
		var name = signal_names[i]
		sig.connect(func(_a = null, _b = null, _c = null):
			if result == "":
				result = name
		, CONNECT_ONE_SHOT)

	while result == "":
		await get_tree().process_frame

	return result

# ============================================================================
# TRANSICIONES
# ============================================================================

func _transition_to_main_menu() -> void:
	await get_tree().process_frame

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await _tween.finished

	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ============================================================================
# CALLBACKS: AUTHMANAGER
# ============================================================================

func _on_login_success(user_data: Dictionary) -> void:
	print("[Gateway] Login exitoso")
	_show_status("Cargando datos del jugador...")

	# Load player data into PlayerDataManager from login response
	var pdm = get_tree().root.get_node("PlayerDataManager")
	var chars = user_data.get("characters", [])
	var inv = user_data.get("inventory", {})
	if chars == null: chars = []
	if inv == null: inv = {}
	pdm.set_initial_data(chars, inv)

	_set_flow_state(FlowState.AUTHENTICATED)
	await get_tree().create_timer(0.3).timeout
	_transition_to_main_menu()

func _on_login_failed(error: String) -> void:
	print("[Gateway] Login fallido: %s" % error)
	_show_error_and_quit("Error de autenticación: " + error)

# ============================================================================
# CALLBACKS: STEAM
# ============================================================================

func _on_steam_ready() -> void:
	print("[Gateway] Steam listo")
	_show_status("Obteniendo ticket de Steam...")
	var steam_mgr = get_tree().root.get_node("SteamManager")
	steam_mgr.get_ticket()

func _on_steam_failed(reason: String) -> void:
	print("[Gateway] Falló inicialización de Steam: %s" % reason)
	_show_error_and_quit(reason)

func _on_steam_ticket_generated(ticket_hex: String, steam_id: String, persona_name: String) -> void:
	print("[Gateway] Ticket generado, enviando a backend...")
	_show_status("Autenticando con servidor...")
	var auth_mgr = get_tree().root.get_node("AuthManager")
	auth_mgr.login_with_steam(ticket_hex, steam_id, persona_name)

func _on_steam_ticket_failed(reason: String) -> void:
	print("[Gateway] Falló generación de ticket: %s" % reason)
	_show_error_and_quit("Error de Steam: " + reason)

# ============================================================================
# ERROR BLOCKING → QUIT
# ============================================================================

func _show_error_and_quit(message: String) -> void:
	var dialog = AcceptDialog.new()
	add_child(dialog)
	dialog.dialog_text = message
	dialog.get_ok_button().text = "Salir"
	dialog.popup_centered_clamped()
	dialog.confirmed.connect(_on_error_confirmed)
	dialog.canceled.connect(_on_error_confirmed)

func _on_error_confirmed() -> void:
	get_tree().quit()

# ============================================================================
# UTILIDADES
# ============================================================================

func _show_status(message: String) -> void:
	if _loading_spinner and is_instance_valid(_loading_spinner):
		_loading_spinner.visible = true
		if _loading_spinner.has_method("start_spinning"):
			_loading_spinner.start_spinning()
		if _loading_spinner.has_method("set"):
			_loading_spinner.set("spinner_text", message)
	elif _loading_label and is_instance_valid(_loading_label):
		_loading_label.visible = true
		_loading_label.text = message

	if _status_label and is_instance_valid(_status_label):
		_status_label.text = message

func _set_flow_state(new_state: FlowState) -> void:
	if _current_flow_state != new_state:
		_current_flow_state = new_state
		var config = get_tree().root.get_node("Config")
		if config.DEBUG_AUTH:
			print("[Gateway] Estado: %s" % FlowState.keys()[new_state])
