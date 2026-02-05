extends Control
## MainMenu - Escena principal del menú del juego
## Permite seleccionar entre los 3 modos de juego

# Referencias a nodos
@onready var roguelike_btn: Button = $CenterContainer/VBoxContainer/ModesContainer/RoguelikeBtn
@onready var adventure_btn: Button = $CenterContainer/VBoxContainer/ModesContainer/AdventureBtn
@onready var pvp_btn: Button = $CenterContainer/VBoxContainer/ModesContainer/PvPBtn
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitBtn

# Modal de selección de personajes
var character_select_modal: Control = null
const CharacterSelectModalScene = preload("res://scenes/CharacterSelectModal.tscn")

func _ready() -> void:
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
	
	print("🏠 MainMenu cargado")

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
