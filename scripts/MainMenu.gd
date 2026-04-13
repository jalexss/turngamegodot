extends Control
## MainMenu - Escena principal del menú del juego
## Permite seleccionar entre los 3 modos de juego
## Incluye funcionalidad de logout y perfil del usuario

# Referencias a nodos
@onready var roguelike_btn: Button = $CenterContainer/VBoxContainer/ModesContainer/RoguelikeBtn
@onready var adventure_btn: Button = $CenterContainer/VBoxContainer/ModesContainer/AdventureBtn
@onready var pvp_btn: Button = $CenterContainer/VBoxContainer/ModesContainer/PvPBtn
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitBtn

# Modal de selección de personajes
var character_select_modal: Control = null
const CharacterSelectModalScene = preload("res://scenes/CharacterSelectModal.tscn")

# Nodos de usuario
var _user_label: Label = null
var _logout_button: Button = null

func _ready() -> void:
	# Crear panel superior con información de usuario
	_create_user_panel()
	
	# Conectar botones
	roguelike_btn.pressed.connect(_on_roguelike_pressed)
	adventure_btn.pressed.connect(_on_adventure_pressed)
	pvp_btn.pressed.connect(_on_pvp_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Deshabilitar modos no implementados
	adventure_btn.disabled = true
	adventure_btn.tooltip_text = "Próximamente..."
	pvp_btn.disabled = true
	pvp_btn.tooltip_text = "Próximamente..."
	
	# Mostrar información del usuario autenticado
	_show_user_info()
	
	var auth_mgr = get_tree().root.get_node("AuthManager")
	print("🏠 MainMenu cargado - Usuario: %s" % auth_mgr.get_username())

func _create_user_panel() -> void:
	"""Crea panel superior con info de usuario y logout button"""
	var top_panel = Control.new()
	top_panel.name = "UserPanel"
	top_panel.custom_minimum_size = Vector2(0, 50)
	top_panel.anchor_right = 1.0
	add_child(top_panel)
	move_child(top_panel, 0)  # Mover al inicio
	
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 20)
	top_panel.add_child(hbox)
	
	# Label de usuario
	_user_label = Label.new()
	var auth_mgr = get_tree().root.get_node("AuthManager")
	_user_label.text = "Jugador: %s" % auth_mgr.get_username()
	_user_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(_user_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Botón de logout
	_logout_button = Button.new()
	_logout_button.text = "Cerrar Sesión"
	_logout_button.custom_minimum_size = Vector2(150, 40)
	_logout_button.pressed.connect(_on_logout_pressed)
	hbox.add_child(_logout_button)

func _show_user_info() -> void:
	"""Actualiza la información del usuario mostrada"""
	if _user_label:
		var auth_mgr = get_tree().root.get_node("AuthManager")
		_user_label.text = "Jugador: %s" % auth_mgr.get_username()

func _on_roguelike_pressed() -> void:
	print("🎮 Modo Roguelike seleccionado")
	_show_character_select_modal()

func _on_adventure_pressed() -> void:
	print("📖 Modo Aventura - No disponible")

func _on_pvp_pressed() -> void:
	print("⚔️ Modo PvP - No disponible")

func _on_quit_pressed() -> void:
	print("👋 Saliendo del juego...")
	get_tree().quit()

func _on_logout_pressed() -> void:
	"""Maneja el logout del usuario"""
	print("👉 [MainMenu] Logout solicitado")
	
	# Deshabilitar botón para evitar múltiples clicks
	if _logout_button:
		_logout_button.disabled = true
	
	# Cerrar sesión en AuthManager
	var auth_mgr = get_tree().root.get_node("AuthManager")
	auth_mgr.logout()
	
	# Esperar un frame y volver a Gateway
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/Gateway.tscn")

func _show_character_select_modal() -> void:
	"""Muestra el modal de selección de personajes"""
	if character_select_modal:
		character_select_modal.queue_free()
	
	character_select_modal = CharacterSelectModalScene.instantiate()
	character_select_modal.z_index = 1500
	add_child(character_select_modal)
	
	# Conectar señales del modal
	character_select_modal.selection_confirmed.connect(_on_characters_selected)
	character_select_modal.modal_closed.connect(_on_modal_closed)
	
	character_select_modal.show_modal()

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _on_characters_selected(characters: Array) -> void:
	"""Callback cuando se confirma la selección de personajes"""
	print("✅ Personajes seleccionados: ", characters.size())
	
	# Limpiar modal
	if character_select_modal:
		character_select_modal.queue_free()
		character_select_modal = null
	
	# Iniciar run de roguelike con los personajes seleccionados
	var gm = _get_game_manager()
	if gm:
		gm.start_roguelike_run(characters)

func _on_modal_closed() -> void:
	"""Callback cuando se cierra el modal sin seleccionar"""
	print("❌ Modal cerrado sin selección")
	if character_select_modal:
		character_select_modal.queue_free()
		character_select_modal = null
