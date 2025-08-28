extends Control

# No necesitamos importar HandContainer ya que es una clase global
# Importar clases necesarias
const EffectManagerClass = preload("res://scripts/EffectManager.gd")
const TopBarScene = preload("res://scenes/TopBar.tscn")
const ControlPanelScene = preload("res://scenes/ControlPanel.tscn")
const DeckModalScene = preload("res://scenes/DeckModal.tscn")
const DiscardModalScene = preload("res://scenes/DiscardModal.tscn")

# --- NODOS DE LA ESCENA ---
# NOTA: Estas rutas asumen que los nodos son hijos directos de GameUi
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer
@onready var turn_label = get_node_or_null("MainVBox/HBoxContainer/TurnPanel/TurnLabel") as Label
@onready var energy_label = get_node_or_null("MainVBox/HBoxContainer/EnergyPanel/EnergyLabel") as Label
@onready var hand_container = get_node_or_null("HandContainer") as HandContainer
# Botón de descarte ahora está en ControlPanel

# --- TOPBAR Y CONTROLPANEL ---
var topbar: Control = null
var control_panel: Control = null

# --- MODALES ---
var deck_modal: Control = null
var discard_modal: Control = null

# --- LOG DE COMBATE ---
var combat_log_panel: Panel = null
var combat_log_scroll: ScrollContainer = null
var combat_log_content: VBoxContainer = null
var combat_log_visible: bool = false

# --- NODOS DE GAME OVER ---
var game_over_overlay: Panel = null
var game_over_label: Label = null
var game_over_active: bool = false

# --- VARIABLES DE ESTADO ---
var player_slots_nodes: Array = []
var enemy_slots_nodes: Array = []
var hovered_card: Node2D = null
var last_hovered_card: Node2D = null
var cards_interactive: bool = true  # Controla si las cartas son interactivas

# Configuración de la mano
const MAX_HAND_SIZE: int = 8  # Reducido para mejor visibilidad

# Estados de targeting
enum TargetingState { NONE, WAITING_FOR_TARGET }
var targeting_state: TargetingState = TargetingState.NONE
var selected_card: Node2D = null
var hovered_target: Control = null  # Personaje bajo el cursor durante targeting

# Sistema de descarte
var discard_pile: Array[CardData] = []
var pending_cards: Array = []  # Cartas que no se pudieron añadir a la mano

# Sistema de drag & drop
var dragged_card: Node2D = null
var drag_start_position: Vector2 = Vector2.ZERO

# Sistema de log de combate
var combat_log_entries: Array[String] = []
const MAX_LOG_ENTRIES: int = 100  # Máximo de entradas en el log

# Sistema de cronómetros (ahora manejado por TopBar)
var pressure_attack_active: bool = false  # Si está ejecutándose el ataque de presión
var is_player_turn: bool = true  # Si es el turno del jugador (para pausar cronómetro de presión)

const CharacterSlotScene = preload("res://scenes/ui_elements/CharacterSlot.tscn")

# --- FUNCIONES DEL MOTOR ---
func _ready() -> void:
	# Crear topbar usando la nueva escena
	_setup_topbar()
	
	# Crear control panel usando la nueva escena
	_setup_control_panel()
	
	# Crear modales
	_setup_modals()
	
	# Crear pantalla de game over
	_create_game_over_overlay()
	
	# Crear nodos faltantes automáticamente
	_create_missing_nodes()
	
	# Inicializar slots de personajes
	print("DEBUG: Inicializando slots de personajes...")
	print("DEBUG: player_slots_container: ", player_slots_container)
	print("DEBUG: enemy_slots_container: ", enemy_slots_container)
	
	if player_slots_container:
		_initialize_character_slots(player_slots_container, player_slots_nodes, 3)
		print("DEBUG: Slots de jugador inicializados: ", player_slots_nodes.size())
	else:
		print("❌ ERROR: player_slots_container no encontrado")
	
	if enemy_slots_container:
		_initialize_character_slots(enemy_slots_container, enemy_slots_nodes, 5)
		print("DEBUG: Slots de enemigo inicializados: ", enemy_slots_nodes.size())
	else:
		print("❌ ERROR: enemy_slots_container no encontrado")
	
	# Los botones de control ahora están en ControlPanel
	
	# Botón de descarte ahora está en ControlPanel
	
	# Crear nodos faltantes si es necesario
	_create_missing_nodes()
	
	# Agregar entrada inicial al log
	add_combat_log_entry("🎮 ¡Combate iniciado!")

func _process(delta: float) -> void:
	"""Actualiza los cronómetros cada frame"""
	_update_timers(delta)

func _update_timers(_delta: float) -> void:
	"""Los cronómetros ahora son manejados por TopBar"""
	# No hacer nada aquí, TopBar maneja sus propios cronómetros
	pass

# --- SETUP DEL NUEVO TOPBAR ---
func _setup_topbar() -> void:
	"""Configura el nuevo TopBar usando la escena separada"""
	print("🔧 Configurando TopBar...")
	
	# Instanciar la escena TopBar
	topbar = TopBarScene.instantiate()
	topbar.name = "TopBar"
	
	# Configurar posición y tamaño
	topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topbar.size.y = 60
	topbar.z_index = 50
	
	# Agregar al GameUI
	add_child(topbar)
	
	# Conectar señales del TopBar
	if topbar.has_signal("combat_log_requested"):
		topbar.combat_log_requested.connect(_on_combat_log_button_pressed)
	
	if topbar.has_signal("menu_requested"):
		topbar.menu_requested.connect(_on_menu_button_pressed)
	
	if topbar.has_signal("pressure_attack_triggered"):
		topbar.pressure_attack_triggered.connect(_trigger_pressure_attack)
	
	# Crear el panel de log de combate
	_create_combat_log_panel()
	
	print("✅ TopBar configurado correctamente")

# --- SETUP DEL NUEVO CONTROLPANEL ---
func _setup_control_panel() -> void:
	"""Configura el nuevo ControlPanel usando la escena separada"""
	print("🎮 Configurando ControlPanel...")
	
	# Instanciar la escena ControlPanel
	control_panel = ControlPanelScene.instantiate()
	control_panel.name = "ControlPanel"
	
	# Configurar posición (esquina superior izquierda, debajo del topbar)
	control_panel.position = Vector2(20, 80)  # Debajo del TopBar
	control_panel.z_index = 40
	
	# Agregar al GameUI
	add_child(control_panel)
	
	# Conectar señales del ControlPanel
	if control_panel.has_signal("test_card_requested"):
		control_panel.test_card_requested.connect(_on_test_button_pressed)
	
	if control_panel.has_signal("energy_boost_requested"):
		control_panel.energy_boost_requested.connect(_on_energy_button_pressed)
	
	if control_panel.has_signal("end_turn_requested"):
		control_panel.end_turn_requested.connect(_on_end_turn_button_pressed)
	
	if control_panel.has_signal("deck_view_requested"):
		control_panel.deck_view_requested.connect(_on_deck_button_pressed)
	
	if control_panel.has_signal("overflow_cards_requested"):
		control_panel.overflow_cards_requested.connect(_on_overflow_button_pressed)
	
	if control_panel.has_signal("discard_view_requested"):
		control_panel.discard_view_requested.connect(_on_discard_button_pressed)
	
	print("✅ ControlPanel configurado correctamente")

func _setup_modals() -> void:
	"""Configura los modales usando las escenas separadas"""
	print("🎭 Configurando Modales...")
	
	# Instanciar DeckModal
	deck_modal = DeckModalScene.instantiate()
	deck_modal.name = "DeckModal"
	deck_modal.z_index = 200  # Por encima de todo
	add_child(deck_modal)
	
	# Conectar señales del DeckModal
	if deck_modal.has_signal("modal_closed"):
		deck_modal.modal_closed.connect(_on_deck_modal_closed)
	
	# Instanciar DiscardModal
	discard_modal = DiscardModalScene.instantiate()
	discard_modal.name = "DiscardModal"
	discard_modal.z_index = 200  # Por encima de todo
	add_child(discard_modal)
	
	# Conectar señales del DiscardModal
	if discard_modal.has_signal("modal_closed"):
		discard_modal.modal_closed.connect(_on_discard_modal_closed)
	
	if discard_modal.has_signal("card_selected"):
		discard_modal.card_selected.connect(_on_discard_card_selected)
	
	print("✅ Modales configurados correctamente")

# Funciones de display de cronómetros eliminadas - ahora manejadas por TopBar

func _create_missing_nodes() -> void:
	print("DEBUG: _create_missing_nodes iniciado")
	print("DEBUG: hand_container actual: ", hand_container)
	
	# Crear HandContainer si no existe
	if not hand_container:
		print("DEBUG: Creando HandContainer automáticamente...")
		var new_hand_container = preload("res://scripts/HandContainer.gd").new()
		new_hand_container.name = "HandContainer"
		new_hand_container.position = Vector2(960, 700)  # Posición visible
		add_child(new_hand_container)
		hand_container = new_hand_container
		print("DEBUG: HandContainer creado en posición global: ", hand_container.global_position)
		print("DEBUG: HandContainer tipo: ", typeof(hand_container))
	else:
		print("DEBUG: HandContainer ya existe: ", hand_container)
	
	# Crear contenedores de personajes si no existen
	if not player_slots_container:
		print("DEBUG: Creando PlayerChars container automáticamente...")
		var new_player_container = HBoxContainer.new()
		new_player_container.name = "PlayerChars"
		new_player_container.position = Vector2(100, 400)
		add_child(new_player_container)
		player_slots_container = new_player_container
		print("DEBUG: PlayerChars container creado")
	
	if not enemy_slots_container:
		print("DEBUG: Creando EnemyChars container automáticamente...")
		var new_enemy_container = HBoxContainer.new()
		new_enemy_container.name = "EnemyChars"
		new_enemy_container.position = Vector2(100, 200)
		add_child(new_enemy_container)
		enemy_slots_container = new_enemy_container
		print("DEBUG: EnemyChars container creado")
	
	# Los botones de control ahora están en ControlPanel.tscn

# --- SISTEMA DE LOG DE COMBATE ---

func _create_combat_log_panel() -> void:
	"""Crea el panel del log de combate"""
	combat_log_panel = Panel.new()
	combat_log_panel.name = "CombatLogPanel"
	combat_log_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	combat_log_panel.custom_minimum_size = Vector2(800, 400)
	combat_log_panel.visible = false
	combat_log_panel.z_index = 100  # Por encima de todo
	
	# Estilo del panel de log
	var log_panel_style = StyleBoxFlat.new()
	log_panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	log_panel_style.corner_radius_top_left = 12
	log_panel_style.corner_radius_top_right = 12
	log_panel_style.corner_radius_bottom_left = 12
	log_panel_style.corner_radius_bottom_right = 12
	log_panel_style.border_width_left = 2
	log_panel_style.border_width_right = 2
	log_panel_style.border_width_top = 2
	log_panel_style.border_width_bottom = 2
	log_panel_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	combat_log_panel.add_theme_stylebox_override("panel", log_panel_style)
	
	add_child(combat_log_panel)
	
	# VBoxContainer principal del log
	var log_vbox = VBoxContainer.new()
	log_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_vbox.add_theme_constant_override("separation", 10)
	combat_log_panel.add_child(log_vbox)
	
	# Header del log
	var log_header = HBoxContainer.new()
	log_header.custom_minimum_size = Vector2(0, 50)
	log_vbox.add_child(log_header)
	
	# Título del log
	var log_title = Label.new()
	log_title.text = "📜 LOG DE COMBATE"
	log_title.add_theme_font_size_override("font_size", 20)
	log_title.modulate = Color.WHITE
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_header.add_child(log_title)
	
	# Botón cerrar log
	var close_log_button = Button.new()
	close_log_button.text = "✕ CERRAR"
	close_log_button.custom_minimum_size = Vector2(100, 35)
	close_log_button.modulate = Color(1.2, 0.8, 0.8)
	close_log_button.pressed.connect(_on_close_combat_log_pressed)
	log_header.add_child(close_log_button)
	
	# ScrollContainer para el contenido del log
	combat_log_scroll = ScrollContainer.new()
	combat_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_vbox.add_child(combat_log_scroll)
	
	# VBoxContainer para las entradas del log
	combat_log_content = VBoxContainer.new()
	combat_log_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log_content.add_theme_constant_override("separation", 5)
	combat_log_scroll.add_child(combat_log_content)
	
	print("✅ Panel de log de combate creado")

func _create_game_over_overlay() -> void:
	"""Crea la pantalla de game over"""
	game_over_overlay = Panel.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.visible = false
	game_over_overlay.z_index = 200  # Por encima de todo
	
	# Fondo oscuro semi-transparente
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.8)  # Negro con 80% opacidad
	game_over_overlay.add_theme_stylebox_override("panel", overlay_style)
	
	add_child(game_over_overlay)
	
	# Container principal centrado
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.add_child(center_container)
	
	# VBox para organizar contenido verticalmente
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 30)
	center_container.add_child(content_vbox)
	
	# Label principal del resultado
	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Efecto de sombra para el texto
	game_over_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	game_over_label.add_theme_constant_override("shadow_offset_x", 4)
	game_over_label.add_theme_constant_override("shadow_offset_y", 4)
	
	content_vbox.add_child(game_over_label)
	
	# Label secundario con información adicional
	var info_label = Label.new()
	info_label.name = "GameOverInfoLabel"
	info_label.text = "Presiona ESC para continuar"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	content_vbox.add_child(info_label)
	
	print("✅ Pantalla de game over creada")

func _input(event: InputEvent) -> void:
	# Manejar input de game over primero
	if game_over_active and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_game_over()
			return
	
	# No procesar input de cartas si no son interactivas o si hay game over
	if not cards_interactive or game_over_active:
		return
	
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.global_position)
		# Manejar drag durante movimiento
		if dragged_card and dragged_card.has_method("update_drag"):
			dragged_card.update_drag(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_press(event.global_position)
		else:
			_handle_mouse_release(event.global_position)

# --- MANEJO DE INPUT Y HOVER ---
func _handle_mouse_motion(mouse_pos: Vector2) -> void:
	if targeting_state == TargetingState.WAITING_FOR_TARGET:
		# Durante targeting, detectar personajes bajo el cursor
		_handle_targeting_hover(mouse_pos)
	else:
		# Comportamiento normal de hover en cartas
		var current_top_card = _get_top_card_at_position(mouse_pos)
		
		if current_top_card != last_hovered_card:
			if last_hovered_card:
				_apply_hover_effect(last_hovered_card, false)
			
			if current_top_card:
				_apply_hover_effect(current_top_card, true)
			
			# Si no hay targeting activo, limpiar highlights residuales
			if targeting_state == TargetingState.NONE:
				_clear_target_highlights()
			
			last_hovered_card = current_top_card

func _handle_mouse_press(mouse_pos: Vector2) -> void:
	"""Maneja cuando se presiona el botón del mouse"""
	if targeting_state == TargetingState.WAITING_FOR_TARGET:
		# Durante targeting, verificar si se clickeó un personaje
		var clicked_character_slot = _get_character_slot_at_position(mouse_pos)
		
		if clicked_character_slot and clicked_character_slot.character_data:
			_on_character_targeted(clicked_character_slot.character_data)
			return
		
		# Si no se clickeó un personaje, verificar si se clickeó la carta para cancelar
		var clicked_card_targeting = _get_top_card_at_position(mouse_pos)
		if clicked_card_targeting and selected_card == clicked_card_targeting:
			_cancel_targeting()
		return
	
	# Comportamiento normal cuando no hay targeting
	var clicked_card = _get_top_card_at_position(mouse_pos)
	if clicked_card and hand_container:
		# Iniciar drag
		_start_card_drag(clicked_card, mouse_pos)

func _handle_mouse_release(mouse_pos: Vector2) -> void:
	"""Maneja cuando se suelta el botón del mouse"""
	if dragged_card:
		_end_card_drag(mouse_pos)
	
# --- SISTEMA DE DRAG & DROP ---
func _start_card_drag(card: Node2D, mouse_pos: Vector2) -> void:
	"""Inicia el drag de una carta"""
	# Limpiar highlights al empezar drag
	_clear_target_highlights()
	
	dragged_card = card
	drag_start_position = card.global_position
	
	if card.has_method("start_drag"):
		card.start_drag(mouse_pos)
	
	print("🖱️ Iniciando drag de carta: ", card.data.name if card.data else "Sin datos")

func _end_card_drag(mouse_pos: Vector2) -> void:
	"""Termina el drag de una carta"""
	if not dragged_card:
		return
	
	var dropped_on_discard = _is_position_over_discard_button(mouse_pos)
	
	if dropped_on_discard:
		# Descartar carta
		print("🗑️ Carta descartada por drag & drop")
		_discard_card(dragged_card)
	else:
		# Activar targeting si no se descartó
		hand_container.focus_card(dragged_card)
		_start_targeting(dragged_card)
		
		# Restaurar posición original si no se descartó
		if dragged_card.has_method("end_drag"):
			dragged_card.end_drag()
		dragged_card.global_position = drag_start_position
	
	dragged_card = null

func _is_position_over_discard_button(pos: Vector2) -> bool:
	"""Verifica si la posición está sobre el botón de descarte del ControlPanel"""
	if not control_panel:
		return false
	
	# Buscar el botón de descarte dentro del ControlPanel
	var discard_btn = control_panel.get_node_or_null("ButtonsContainer/BottomRow/DiscardButton")
	if not discard_btn:
		return false
	
	var button_rect = discard_btn.get_global_rect()
	return button_rect.has_point(pos)

# --- GESTIÓN DE LA MANO (DELEGADA) ---
func clear_hand() -> void:
	if not hand_container:
		print("Warning: HandContainer no encontrado. Asegúrate de añadir el nodo HandContainer a GameUI.tscn")
		return
	hand_container.clear_cards()
	hovered_card = null
	last_hovered_card = null

func add_card_to_hand(card: Node2D) -> void:
	print("DEBUG: GameUI.add_card_to_hand() llamado con carta: ", card)
	
	# Limpiar highlights al añadir nueva carta
	_clear_target_highlights()
	
	if not hand_container:
		print("ERROR: HandContainer no encontrado. No se puede añadir carta.")
		card.queue_free()
		return
	
	print("DEBUG: HandContainer encontrado: ", hand_container)
		
	# Verificar límite máximo de cartas
	if get_hand_size() >= MAX_HAND_SIZE:
		print("¡Mano llena! Máximo ", MAX_HAND_SIZE, " cartas permitidas.")
		card.queue_free()  # Eliminar la carta si no se puede añadir
		return
	
	print("DEBUG: Enviando carta a HandContainer...")
	hand_container.add_card(card)
	print("DEBUG: Carta añadida. Cartas en mano: ", get_hand_size(), "/", MAX_HAND_SIZE)

func get_hand_size() -> int:
	if not hand_container:
		return 0
	return hand_container.get_card_count()

# --- FUNCIÓN DE PRUEBAS ---
func _on_test_button_pressed() -> void:
	print("DEBUG: Botón de test presionado!")
	print("DEBUG: Cartas actuales en mano: ", get_hand_size(), "/", MAX_HAND_SIZE)
	
	# Verificar si ya está llena la mano
	if get_hand_size() >= MAX_HAND_SIZE:
		print("DEBUG: Mano llena, no se puede añadir más cartas")
		return
	
	# Crear carta aleatoria del deck
	var game_node = get_parent()
	if game_node and game_node.has_method("_draw_and_show"):
		print("DEBUG: Robando carta del deck...")
		game_node._draw_and_show()
	else:
		print("DEBUG: ERROR - No se pudo robar carta del deck")

# --- FUNCIÓN DE ENERGÍA DE PRUEBA ---
func _on_energy_button_pressed() -> void:
	print("DEBUG: Botón de energía de prueba presionado!")
	
	# Obtener referencia al nodo Game
	var game_node = get_parent()
	if game_node and game_node.has_method("add_energy_test"):
		game_node.add_energy_test(3)
		print("DEBUG: 3 de energía de prueba añadida (puede exceder límite)")
	else:
		print("DEBUG: ERROR - No se encontró el método add_energy_test en el nodo padre")

# --- FUNCIÓN TERMINAR TURNO ---
func _on_end_turn_button_pressed() -> void:
	print("🔄 TERMINAR TURNO presionado!")
	
	# Cancelar cualquier targeting activo
	if targeting_state != TargetingState.NONE:
		_cancel_targeting()
	
	# Obtener referencia al nodo Game
	var game_node = get_parent()
	if game_node and game_node.has_method("end_player_turn"):
		game_node.end_player_turn()
		print("🔄 Turno del jugador terminado")
	else:
		print("DEBUG: ERROR - No se encontró el método end_player_turn en el nodo padre")

func _on_deck_button_pressed() -> void:
	"""Callback para el botón del mazo"""
	print("📚 Botón del mazo presionado")
	show_deck_modal()

func _on_discard_button_pressed() -> void:
	"""Callback para el botón de descarte"""
	print("🗑️ Botón de descarte presionado")
	print("🔍 DEBUG: Verificando conexión del botón de descarte...")
	
	# El botón de descarte ahora está en ControlPanel
	
	show_discard_modal()

# --- FUNCIÓN OVERFLOW BUTTON ---
func _on_overflow_button_pressed() -> void:
	print("📥 Botón de cartas pendientes presionado!")
	
	if pending_cards.is_empty():
		print("⚠️ No hay cartas pendientes")
		return
	
	# DEBUG CRÍTICO: Verificar estado actual
	var visual_hand_size = get_current_hand_size()
	var data_hand_size = _get_player_data_hand_size()
	
	print("🔍 ESTADO CRÍTICO:")
	print("  - Cartas visuales: ", visual_hand_size)
	print("  - Cartas en datos: ", data_hand_size)
	print("  - MAX_HAND_SIZE: ", MAX_HAND_SIZE)
	print("  - Cartas pendientes: ", pending_cards.size())
	
	# Calcular cuántas cartas se pueden añadir
	var available_space = MAX_HAND_SIZE - get_current_hand_size()
	var cards_to_add = min(available_space, pending_cards.size())
	
	print("📊 Espacio disponible: ", available_space, " | Cartas pendientes: ", pending_cards.size())
	
	# Añadir cartas a la mano
	for i in range(cards_to_add):
		var card_data = pending_cards.pop_front()
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(card_data)
		add_card_to_hand(card)
		print("📥 Carta añadida desde pendientes: ", card_data.name)
	
	# Actualizar displays
	update_overflow_count()
	
	# Ocultar mensaje de mano llena si ya no hay cartas pendientes
	if pending_cards.is_empty():
		hide_hand_full_message()

# --- CALLBACKS DEL TOPBAR Y LOG DE COMBATE ---
func _on_combat_log_button_pressed() -> void:
	"""Callback para mostrar/ocultar el log de combate"""
	print("📜 Botón de log de combate presionado")
	toggle_combat_log()

func _on_menu_button_pressed() -> void:
	"""Callback para el botón de menú"""
	print("☰ Botón de menú presionado")
	show_menu_modal()

func _on_close_combat_log_pressed() -> void:
	"""Callback para cerrar el log de combate"""
	print("✕ Cerrando log de combate")
	hide_combat_log()

func toggle_combat_log() -> void:
	"""Alterna la visibilidad del log de combate"""
	if combat_log_visible:
		hide_combat_log()
	else:
		show_combat_log()

func show_combat_log() -> void:
	"""Muestra el log de combate"""
	if combat_log_panel:
		combat_log_panel.visible = true
		combat_log_visible = true
		
		# Hacer scroll hacia abajo para mostrar las entradas más recientes
		if combat_log_scroll:
			await get_tree().process_frame  # Esperar un frame para que se actualice el layout
			combat_log_scroll.scroll_vertical = int(combat_log_scroll.get_v_scroll_bar().max_value)
		
		print("📜 Log de combate mostrado")

func hide_combat_log() -> void:
	"""Oculta el log de combate"""
	if combat_log_panel:
		combat_log_panel.visible = false
		combat_log_visible = false
		print("📜 Log de combate ocultado")

func add_combat_log_entry(message: String) -> void:
	"""Añade una entrada al log de combate"""
	# Agregar timestamp
	var time = Time.get_datetime_dict_from_system()
	var timestamp = "[%02d:%02d:%02d] " % [time.hour, time.minute, time.second]
	var full_message = timestamp + message
	
	# Añadir a la lista de entradas
	combat_log_entries.append(full_message)
	
	# Limitar el número de entradas
	if combat_log_entries.size() > MAX_LOG_ENTRIES:
		combat_log_entries.pop_front()
	
	# Crear label para la nueva entrada
	if combat_log_content:
		var entry_label = Label.new()
		entry_label.text = full_message
		entry_label.add_theme_font_size_override("font_size", 12)
		entry_label.modulate = Color.WHITE
		entry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Alternar colores de fondo para mejor legibilidad
		if combat_log_entries.size() % 2 == 0:
			entry_label.modulate = Color(0.9, 0.9, 0.9, 1.0)
		
		combat_log_content.add_child(entry_label)
		
		# Remover entradas viejas del UI si hay demasiadas
		var children = combat_log_content.get_children()
		if children.size() > MAX_LOG_ENTRIES:
			children[0].queue_free()
		
		# Auto-scroll hacia abajo si el log está visible
		if combat_log_visible and combat_log_scroll:
			await get_tree().process_frame
			combat_log_scroll.scroll_vertical = int(combat_log_scroll.get_v_scroll_bar().max_value)
	
	print("📝 Log: ", message)

func add_enemy_action_log(enemy_name: String, action_type: String, value: int, target_name: String = "") -> void:
	"""Función pública para que Enemy.gd pueda agregar entradas al log"""
	var action_text = ""
	match action_type:
		"ATTACK":
			action_text = "⚔️ " + enemy_name + " ataca a " + target_name + " por " + str(value) + " de daño"
		"HEAL":
			action_text = "💚 " + enemy_name + " se cura " + str(value) + " HP"
		"DEFEND":
			action_text = "🛡️ " + enemy_name + " se defiende, ganando " + str(value) + " de defensa"
		_:
			action_text = "🤖 " + enemy_name + " usa " + action_type + " (" + str(value) + ")"
	
	add_combat_log_entry(action_text)

# --- SISTEMA DE ATAQUE DE PRESIÓN ---
func _trigger_pressure_attack() -> void:
	"""Activa el ataque de presión cuando el cronómetro llega a 0"""
	print("⚡ ¡ATAQUE DE PRESIÓN ACTIVADO!")
	add_combat_log_entry("⚡ ¡ATAQUE DE PRESIÓN! El tiempo se ha agotado...")
	
	pressure_attack_active = true
	
	# Bloquear acciones del jugador
	_block_player_actions(true)
	
	# Ejecutar ataque a todos los personajes del jugador
	await _execute_pressure_attack()
	
	# Si el juego terminó durante el ataque, no continuar
	if game_over_active:
		print("⚡ Ataque de presión terminó el juego - no reiniciar cronómetro")
		pressure_attack_active = false
		return
	
	# Reiniciar cronómetro de presión solo si el juego continúa
	_reset_pressure_timer()
	
	# Desbloquear acciones del jugador
	_block_player_actions(false)
	
	pressure_attack_active = false
	
	add_combat_log_entry("⚡ Ataque de presión completado. El combate continúa...")
	print("⚡ Ataque de presión completado")

func _block_player_actions(blocked: bool) -> void:
	"""Bloquea/desbloquea las acciones del jugador durante el ataque de presión"""
	# Bloquear cartas
	_set_cards_interactive(not blocked)
	
	# Bloquear botones del ControlPanel (incluye descarte)
	if control_panel and control_panel.has_method("set_buttons_enabled"):
		control_panel.set_buttons_enabled(not blocked)
	
	print("🔒 Acciones del jugador ", "bloqueadas" if blocked else "desbloqueadas")

func _execute_pressure_attack() -> void:
	"""Ejecuta el ataque de presión a todos los personajes del jugador"""
	var game_node = get_parent()
	if not game_node or not game_node.has_method("get_player_characters"):
		print("❌ No se pudo obtener personajes del jugador")
		return
	
	var player_chars = game_node.get_player_characters()
	if player_chars.is_empty():
		print("❌ No hay personajes del jugador para atacar")
		return
	
	add_combat_log_entry("💀 Fuerzas oscuras atacan a todos los aliados...")
	
	# Atacar cada personaje vivo
	for character in player_chars:
		if character.hp > 0:
			_apply_pressure_damage_to_character(character)
			
			# Si el juego terminó durante el ataque, salir del bucle
			if game_over_active:
				print("🎮 Ataque de presión interrumpido por game over")
				break
				
			await get_tree().create_timer(0.5).timeout  # Pausa entre ataques para efecto dramático

func _apply_pressure_damage_to_character(character: CharacterData) -> void:
	"""Aplica daño de presión a un personaje específico"""
	# Calcular daño como porcentaje de HP máximo (5% a 30%)
	var damage_percentage = randf_range(0.05, 0.30)  # 5% a 30%
	var damage = int(character.max_hp * damage_percentage)
	damage = max(1, damage)  # Mínimo 1 de daño
	
	print("💀 Ataque de presión a ", character.name, ": ", damage, " de daño (", int(damage_percentage * 100), "% de HP máximo)")
	
	# Aplicar daño (ignora defensa para el ataque de presión)
	var old_hp = character.hp
	character.hp = max(0, character.hp - damage)
	var actual_damage = old_hp - character.hp
	
	# Log del ataque
	var damage_text = "💀 " + character.name + " recibe " + str(actual_damage) + " de daño de presión"
	damage_text += " (" + str(int(damage_percentage * 100)) + "% HP máximo)"
	damage_text += " → HP: " + str(character.hp) + "/" + str(character.max_hp)
	add_combat_log_entry(damage_text)
	
	# Actualizar display del personaje
	_update_character_display(character)
	
	# Verificar si el personaje murió
	if character.hp == 0:
		add_combat_log_entry("☠️ " + character.name + " ha caído por el ataque de presión!")
	
	# Verificar game over después de cada personaje
	var game_node = get_parent()
	if game_node and game_node.has_method("_check_game_over"):
		game_node._check_game_over()
		
		# Si el juego terminó, detener el ataque de presión inmediatamente
		if game_over_active:
			print("🎮 Game over detectado durante ataque de presión - deteniendo ataque")
			return

func _reset_pressure_timer() -> void:
	"""Reinicia el cronómetro de presión"""
	if topbar and topbar.has_method("reset_pressure_timer"):
		topbar.reset_pressure_timer()
		print("⚡ Cronómetro de presión reiniciado via TopBar")

func set_pressure_timer_duration(seconds: float) -> void:
	"""Configura la duración del cronómetro de presión"""
	if topbar and topbar.has_method("set_pressure_timer_duration"):
		topbar.set_pressure_timer_duration(seconds)
		print("⚡ Cronómetro de presión configurado a ", seconds, " segundos via TopBar")

func stop_match_timer() -> void:
	"""Detiene el cronómetro de partida (llamar cuando termine el juego)"""
	# El cronómetro ahora es manejado por TopBar
	if topbar and topbar.has_method("pause_timers"):
		topbar.pause_timers()
		add_combat_log_entry("⏱️ Cronómetros detenidos - Juego terminado")
		print("⏱️ Cronómetros detenidos via TopBar")

func pause_timers(paused: bool) -> void:
	"""Pausa/reanuda los cronómetros manualmente (para pausas del juego)"""
	# Esta función es diferente al sistema de turnos
	# Se usa para pausas manuales del juego completo
	if topbar:
		if paused:
			topbar.pause_timers()
			pressure_attack_active = true
			add_combat_log_entry("⏸️ Juego pausado - Cronómetros detenidos")
		else:
			topbar.resume_timers()
			pressure_attack_active = false
			add_combat_log_entry("▶️ Juego reanudado - Cronómetros activos")

# --- SISTEMA DE GAME OVER ---
func show_game_over(victory: bool) -> void:
	"""Muestra la pantalla de game over"""
	if not game_over_overlay or not game_over_label:
		print("❌ Pantalla de game over no está inicializada")
		return
	
	game_over_active = true
	
	# Detener ambos cronómetros inmediatamente
	pressure_attack_active = true  # Esto pausará ambos cronómetros
	stop_match_timer()  # Detener cronómetro de partida y registrar tiempo final
	
	# Configurar mensaje según resultado
	if victory:
		game_over_label.text = "¡GANASTE!"
		game_over_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2, 1.0))  # Verde brillante
		add_combat_log_entry("🎉 ¡VICTORIA! El jugador ha ganado la partida")
	else:
		game_over_label.text = "PERDISTE"
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))  # Rojo brillante
		add_combat_log_entry("💀 ¡DERROTA! El jugador ha perdido la partida")
	
	# Mostrar overlay
	game_over_overlay.visible = true
	
	# Deshabilitar todas las interacciones
	_set_cards_interactive(false)
	_block_player_actions(true)
	
	print("🎮 Game Over mostrado: ", "Victoria" if victory else "Derrota")

func hide_game_over() -> void:
	"""Oculta la pantalla de game over"""
	if game_over_overlay:
		game_over_overlay.visible = false
		game_over_active = false
		print("🎮 Pantalla de game over ocultada")

func is_game_over() -> bool:
	"""Retorna si el juego ha terminado"""
	return game_over_active

func get_current_hand_size() -> int:
	"""Obtiene el tamaño actual de la mano (visual)"""
	if hand_container:
		return hand_container.get_card_count()
	return 0

func _get_player_data_hand_size() -> int:
	"""Obtiene el tamaño de la mano según los datos del Player"""
	var game_node = get_parent()
	if game_node and game_node.has_method("get_player_hand_size"):
		return game_node.get_player_hand_size()
	return -1  # Error

# --- CONTROL DE ESTADO DE UI ---
func set_player_turn_active(active: bool) -> void:
	"""Habilita/deshabilita controles durante el turno del jugador"""
	print("🎮 Turno del jugador activo: ", active)
	
	# Actualizar estado del turno para los cronómetros
	is_player_turn = active
	
	# Gestión del cronómetro de presión según el turno
	if active:
		# Inicio del turno del jugador: resetear cronómetro de presión
		_reset_pressure_timer()
		add_combat_log_entry("🎮 Es el turno del jugador - ⚡ Cronómetro de presión reiniciado")
	else:
		# Inicio del turno enemigo: el cronómetro se pausa automáticamente
		add_combat_log_entry("🤖 Es el turno de los enemigos - ⚡ Cronómetro de presión pausado")
	
	# Botones del ControlPanel que se deshabilitan durante turno enemigo
	if control_panel and control_panel.has_method("set_buttons_enabled"):
		control_panel.set_buttons_enabled(active)
	
	# Las cartas también se deshabilitan
	_set_cards_interactive(active)
	
	print("✅ UI actualizada para turno ", "del jugador" if active else "enemigo")

func _set_cards_interactive(interactive: bool) -> void:
	"""Habilita/deshabilita interacción con cartas"""
	cards_interactive = interactive
	print("🃏 Cartas interactivas: ", interactive)
	
	# Si hay una carta en focus y se deshabilita, quitarla
	if not interactive and hand_container:
		hand_container.unfocus_card()

func set_game_over(player_defeated: bool) -> void:
	"""Deshabilita toda la UI cuando el juego termina"""
	print("💀 GAME OVER - Jugador derrotado: ", player_defeated)
	
	# Deshabilitar TODOS los botones del ControlPanel
	if control_panel and control_panel.has_method("set_buttons_enabled"):
		control_panel.set_buttons_enabled(false)
	
	# Deshabilitar cartas completamente
	_set_cards_interactive(false)
	
	print("💀 Toda la UI deshabilitada - GAME OVER")

func force_reorganize_hand() -> void:
	"""Fuerza la reorganización de las cartas en mano"""
	if hand_container:
		print("🔄 Forzando reorganización de cartas...")
		hand_container.call_deferred("_arrange_cards_in_hemisphere")

func get_pending_cards_count() -> int:
	"""Retorna la cantidad de cartas pendientes en overflow"""
	return pending_cards.size()

# --- SISTEMA DE MODALES ---
var modal_overlay: Control = null
var current_modal: Control = null

func _create_modal_overlay() -> Control:
	"""Crea el overlay oscuro para modales"""
	if modal_overlay:
		return modal_overlay
	
	modal_overlay = Control.new()
	modal_overlay.name = "ModalOverlay"
	modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_overlay.visible = false
	modal_overlay.z_index = 100  # Por encima de todo
	
	# Crear panel de fondo para capturar clicks
	var background = Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Crear StyleBox para el fondo oscuro
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # Fondo semi-transparente
	background.add_theme_stylebox_override("panel", style_box)
	
	modal_overlay.add_child(background)
	
	# Conectar click en fondo para cerrar modal
	background.gui_input.connect(_on_modal_background_clicked)
	
	add_child(modal_overlay)
	return modal_overlay

func _create_card_modal(title: String, cards: Array) -> Control:
	"""Crea un modal para mostrar cartas"""
	var modal = Panel.new()
	modal.name = "CardModal"
	modal.custom_minimum_size = Vector2(800, 600)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Crear StyleBox para el fondo del modal
	var modal_style = StyleBoxFlat.new()
	modal_style.bg_color = Color(0.2, 0.2, 0.3, 0.95)  # Fondo del modal
	modal_style.corner_radius_top_left = 10
	modal_style.corner_radius_top_right = 10
	modal_style.corner_radius_bottom_left = 10
	modal_style.corner_radius_bottom_right = 10
	modal_style.border_width_left = 2
	modal_style.border_width_right = 2
	modal_style.border_width_top = 2
	modal_style.border_width_bottom = 2
	modal_style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	modal.add_theme_stylebox_override("panel", modal_style)
	
	# Crear VBoxContainer principal
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	modal.add_child(vbox)
	
	# Header con título y botón cerrar
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(header)
	
	# Título
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.modulate = Color.WHITE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	# Botón cerrar
	var close_button = Button.new()
	close_button.text = "✕ CERRAR"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.modulate = Color(1.2, 0.8, 0.8)
	close_button.pressed.connect(_close_modal)
	header.add_child(close_button)
	
	# ScrollContainer para las cartas
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	# GridContainer para organizar las cartas
	var grid = GridContainer.new()
	grid.columns = 4  # 4 cartas por fila
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	
	# Añadir cartas al grid
	_populate_card_grid(grid, cards)
	
	return modal

func _populate_card_grid(grid: GridContainer, cards: Array) -> void:
	"""Llena el grid con cartas"""
	print("📋 Poblando grid con ", cards.size(), " cartas")
	
	for card_data in cards:
		# Crear representación visual de la carta
		var card_panel = Panel.new()
		card_panel.custom_minimum_size = Vector2(150, 200)
		
		# Crear StyleBox para la carta
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.3, 0.3, 0.4, 0.8)
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.border_width_left = 1
		card_style.border_width_right = 1
		card_style.border_width_top = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.6, 0.6, 0.7, 1.0)
		card_panel.add_theme_stylebox_override("panel", card_style)
		
		# VBox para organizar contenido de la carta
		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_vbox.add_theme_constant_override("separation", 5)
		card_panel.add_child(card_vbox)
		
		# Nombre de la carta
		var name_label = Label.new()
		name_label.text = card_data.name
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.modulate = Color.WHITE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(name_label)
		
		# Costo de energía
		var cost_label = Label.new()
		cost_label.text = "⚡ " + str(card_data.cost)
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_label.modulate = Color.YELLOW
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(cost_label)
		
		# Poder/Efecto
		var power_label = Label.new()
		power_label.text = "💥 " + str(card_data.power)
		power_label.add_theme_font_size_override("font_size", 12)
		power_label.modulate = Color.ORANGE
		power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(power_label)
		
		# Descripción (si existe)
		if card_data.description != null and card_data.description != "":
			var desc_label = Label.new()
			desc_label.text = card_data.description
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.modulate = Color.LIGHT_GRAY
			desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_vbox.add_child(desc_label)
		
		grid.add_child(card_panel)

func _show_modal(modal: Control) -> void:
	"""Muestra un modal"""
	if current_modal:
		_close_modal()
	
	var overlay = _create_modal_overlay()
	overlay.add_child(modal)
	overlay.visible = true
	current_modal = modal
	
	print("📋 Modal mostrado: ", modal.name)

func _close_modal() -> void:
	"""Cierra el modal actual"""
	if current_modal:
		current_modal.queue_free()
		current_modal = null
	
	if modal_overlay:
		modal_overlay.visible = false
	
	print("📋 Modal cerrado")

func _on_modal_background_clicked(event: InputEvent) -> void:
	"""Maneja clicks en el fondo del modal"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_modal()

func show_deck_modal() -> void:
	"""Muestra el modal con las cartas del mazo usando el nuevo DeckModal"""
	print("📚 Abriendo modal del mazo...")
	
	# Obtener cartas del mazo desde Game.gd
	var game_node = get_parent()
	if not game_node or not game_node.has_method("get_deck_cards"):
		print("❌ No se puede acceder a las cartas del mazo")
		return
	
	var deck_cards = game_node.get_deck_cards()
	
	# Usar el nuevo modal
	if deck_modal and deck_modal.has_method("show_modal"):
		deck_modal.show_modal(deck_cards)
	else:
		print("❌ DeckModal no está disponible")

func show_discard_modal() -> void:
	"""Muestra el modal con las cartas de descarte usando el nuevo DiscardModal"""
	print("🗑️ Abriendo modal de descarte...")
	
	# Obtener cartas de descarte desde Game.gd
	var game_node = get_parent()
	if not game_node:
		print("❌ game_node es null!")
		return
	
	if not game_node.has_method("get_discard_cards"):
		print("❌ game_node no tiene método get_discard_cards")
		return
	
	var discard_cards = game_node.get_discard_cards()
	print("🔍 DEBUG: discard_cards recibidas: ", discard_cards.size())
	
	# Usar el nuevo modal
	if discard_modal and discard_modal.has_method("show_modal"):
		discard_modal.show_modal(discard_cards)
	else:
		print("❌ DiscardModal no está disponible")

func show_menu_modal() -> void:
	"""Muestra el modal de configuración del menú"""
	print("☰ Abriendo modal de menú...")
	
	# Crear el modal principal
	var modal = ColorRect.new()
	modal.name = "MenuModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0, 0, 0, 0.7)  # Fondo semi-transparente
	
	# Crear panel central
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 400) / 2,
		(get_viewport().get_visible_rect().size.y - 300) / 2
	)
	
	# Estilo del panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.3, 0.95)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.5, 0.7, 1.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Crear VBoxContainer para organizar elementos
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	
	# Título del menú
	var title_label = Label.new()
	title_label.text = "☰ CONFIGURACIÓN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(title_label)
	
	# Separador
	var separator1 = HSeparator.new()
	separator1.add_theme_color_override("separator", Color(0.5, 0.5, 0.7, 0.8))
	vbox.add_child(separator1)
	
	# Sección del cronómetro de presión
	var timer_section = VBoxContainer.new()
	timer_section.add_theme_constant_override("separation", 10)
	
	var timer_label = Label.new()
	timer_label.text = "⏱️ Duración del Ataque Cronometrado"
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	timer_section.add_child(timer_label)
	
	# Slider para el cronómetro
	var timer_hbox = HBoxContainer.new()
	timer_hbox.add_theme_constant_override("separation", 10)
	
	var timer_slider = HSlider.new()
	timer_slider.min_value = 15.0
	timer_slider.max_value = 30.0
	timer_slider.step = 1.0
	timer_slider.value = 15.0  # Valor por defecto
	timer_slider.custom_minimum_size = Vector2(200, 30)
	
	var timer_value_label = Label.new()
	timer_value_label.text = "15s"  # Valor por defecto
	timer_value_label.custom_minimum_size = Vector2(40, 30)
	timer_value_label.add_theme_color_override("font_color", Color(1, 1, 0.8, 1))
	
	# Conectar slider para actualizar valor en tiempo real
	timer_slider.value_changed.connect(func(value): 
		timer_value_label.text = str(int(value)) + "s"
		set_pressure_timer_duration(value)
		add_combat_log_entry("⏱️ Cronómetro cambiado a " + str(int(value)) + " segundos")
	)
	
	timer_hbox.add_child(timer_slider)
	timer_hbox.add_child(timer_value_label)
	timer_section.add_child(timer_hbox)
	
	vbox.add_child(timer_section)
	
	# Separador
	var separator2 = HSeparator.new()
	separator2.add_theme_color_override("separator", Color(0.5, 0.5, 0.7, 0.8))
	vbox.add_child(separator2)
	
	# Botones de acción
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 20)
	
	# Botón para cerrar el juego
	var quit_button = Button.new()
	quit_button.text = "🚪 SALIR DEL JUEGO"
	quit_button.custom_minimum_size = Vector2(150, 40)
	
	# Estilo del botón de salir
	var quit_style = StyleBoxFlat.new()
	quit_style.bg_color = Color(0.8, 0.3, 0.3, 0.9)
	quit_style.corner_radius_top_left = 5
	quit_style.corner_radius_top_right = 5
	quit_style.corner_radius_bottom_left = 5
	quit_style.corner_radius_bottom_right = 5
	quit_button.add_theme_stylebox_override("normal", quit_style)
	
	var quit_hover_style = quit_style.duplicate()
	quit_hover_style.bg_color = Color(1.0, 0.4, 0.4, 1.0)
	quit_button.add_theme_stylebox_override("hover", quit_hover_style)
	
	quit_button.pressed.connect(func(): 
		print("🚪 Cerrando el juego...")
		get_tree().quit()
	)
	
	# Botón para cerrar el modal
	var close_button = Button.new()
	close_button.text = "✕ CERRAR"
	close_button.custom_minimum_size = Vector2(100, 40)
	
	# Estilo del botón de cerrar
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.4, 0.4, 0.5, 0.9)
	close_style.corner_radius_top_left = 5
	close_style.corner_radius_top_right = 5
	close_style.corner_radius_bottom_left = 5
	close_style.corner_radius_bottom_right = 5
	close_button.add_theme_stylebox_override("normal", close_style)
	
	var close_hover_style = close_style.duplicate()
	close_hover_style.bg_color = Color(0.5, 0.5, 0.6, 1.0)
	close_button.add_theme_stylebox_override("hover", close_hover_style)
	
	close_button.pressed.connect(func(): 
		print("✕ Cerrando modal de menú")
		modal.queue_free()
	)
	
	buttons_hbox.add_child(quit_button)
	buttons_hbox.add_child(close_button)
	vbox.add_child(buttons_hbox)
	
	# Ensamblar modal
	panel.add_child(vbox)
	modal.add_child(panel)
	
	# Agregar al árbol de escena
	add_child(modal)
	
	print("✅ Modal de menú creado y mostrado")

# --- LÓGICA DE HOVER ---
func _get_top_card_at_position(global_pos: Vector2) -> Node2D:
	if not hand_container:
		return null
	return hand_container.get_card_at_position(global_pos)

func _apply_hover_effect(card: Node2D, is_hovered: bool) -> void:
	if not card or not hand_container: 
		return
	
	# Delegar el hover al HandContainer que maneja el z-index correctamente
	hand_container.apply_hover_effect(card, is_hovered)

# --- SISTEMA DE TARGETING ---
func _start_targeting(card: Node2D) -> void:
	"""Inicia el modo de targeting para una carta"""
	if not card or not card.data:
		return
	
	# NO verificar energía aquí - solo permitir zoom y targeting
	# La verificación de energía se hace al aplicar la carta
	
	# Limpiar highlights previos antes de empezar
	_clear_target_highlights()
	
	selected_card = card
	targeting_state = TargetingState.WAITING_FOR_TARGET
	
	# Determinar qué personajes son válidos según el tipo de carta
	var valid_targets = _get_valid_targets_for_card(card.data)
	
	var card_cost = card.data.cost
	print("🎯 Targeting activado para: ", card.data.name, " (Coste: ", card_cost, ")")
	print("🎯 Tipo de carta: ", CardData.CardType.keys()[card.data.card_type])
	print("🎯 Targets válidos: ", valid_targets.size())
	
	# Cambiar cursor
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	
	# Resaltar targets válidos
	_highlight_valid_targets(valid_targets)

func _cancel_targeting() -> void:
	"""Cancela el modo de targeting"""
	print("❌ Targeting cancelado")
	targeting_state = TargetingState.NONE
	selected_card = null
	hovered_target = null
	
	# Restaurar cursor normal
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	# Quitar resaltado de todos los personajes
	_clear_target_highlights()
	
	# Quitar focus de carta si existe
	if hand_container:
		hand_container.unfocus_card()

func _get_valid_targets_for_card(card_data: CardData) -> Array:
	"""Determina qué personajes son targets válidos para una carta"""
	var valid_targets: Array = []
	
	# Cartas especiales de prueba
	if card_data.id == 999:
		print("🔍 Carta especial detectada - puede atacar aliados")
		valid_targets = player_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
		return valid_targets
	elif card_data.id == 997:
		print("🔍 Carta súper curación detectada - cura aliados")
		valid_targets = player_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
		return valid_targets
	
	# Verificar propiedades específicas de targeting de la carta
	if card_data.has_method("can_target_enemies") and card_data.has_method("can_target_allies"):
		if card_data.can_target_enemies:
			var enemy_targets = enemy_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
			valid_targets.append_array(enemy_targets)
		
		if card_data.can_target_allies:
			var ally_targets = player_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
			valid_targets.append_array(ally_targets)
		
		if not valid_targets.is_empty():
			return valid_targets
	
	# Fallback al sistema tradicional basado en tipo de carta
	match card_data.card_type:
		CardData.CardType.ATTACK, CardData.CardType.DEBUFF:
			# Cartas ofensivas van a enemigos VIVOS
			valid_targets = enemy_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
		CardData.CardType.HEAL, CardData.CardType.DEFENSE, CardData.CardType.BUFF:
			# Cartas defensivas/de apoyo van a aliados VIVOS
			valid_targets = player_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
		CardData.CardType.STATUS:
			# Cartas de estado: verificar si pueden targetear enemigos o aliados
			if card_data.has_status_effects():
				# Por defecto, cartas de estado ofensivas van a enemigos
				var first_effect = card_data.status_effects[0] if not card_data.status_effects.is_empty() else {}
				var effect_type = first_effect.get("effect_type", "")
				
				if effect_type in ["DEBUFF_ATTACK", "DEBUFF_DEFENSE", "POISON", "STUN", "VULNERABILITY", "HEAL_BLOCK"]:
					valid_targets = enemy_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
				else:
					valid_targets = player_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
		_:
			# Otros tipos por ahora no tienen targeting específico
			pass
	
	return valid_targets

func _highlight_valid_targets(targets: Array) -> void:
	"""Resalta los targets válidos"""
	for slot in targets:
		if slot.has_method("set_targeting_highlight"):
			slot.set_targeting_highlight(true)

func _clear_target_highlights() -> void:
	"""Quita el resaltado de todos los targets"""
	for slot in player_slots_nodes + enemy_slots_nodes:
		if slot.has_method("set_targeting_highlight"):
			slot.set_targeting_highlight(false)
		if slot.has_method("set_targeting_hover"):
			slot.set_targeting_hover(false)
	
	# Limpiar variable de hover target
	hovered_target = null

func _handle_targeting_hover(mouse_pos: Vector2) -> void:
	"""Maneja el hover durante el targeting"""
	var current_target = _get_character_slot_at_position(mouse_pos)
	
	if current_target != hovered_target:
		# Quitar hover del target anterior
		if hovered_target and hovered_target.has_method("set_targeting_hover"):
			hovered_target.set_targeting_hover(false)
		
		# Aplicar hover al nuevo target
		if current_target and current_target.has_method("set_targeting_hover"):
			# Verificar si es un target válido
			var valid_targets = _get_valid_targets_for_card(selected_card.data)
			if current_target in valid_targets:
				current_target.set_targeting_hover(true)

			else:
				current_target = null  # No es válido, no hacer hover
		
		hovered_target = current_target

func _get_character_slot_at_position(global_pos: Vector2) -> Control:
	"""Obtiene el slot de personaje en la posición dada"""
	for slot in player_slots_nodes + enemy_slots_nodes:
		if slot.character_data and slot.get_global_rect().has_point(global_pos):
			return slot
	return null

func _on_character_targeted(character_data: CharacterData) -> void:
	"""Maneja cuando se selecciona un personaje durante el targeting"""
	if targeting_state != TargetingState.WAITING_FOR_TARGET or not selected_card:
		return
	
	# Verificar si es un target válido
	var valid_targets = _get_valid_targets_for_card(selected_card.data)
	var target_slot = null
	
	# Buscar el slot del personaje seleccionado
	for slot in player_slots_nodes + enemy_slots_nodes:
		if slot.character_data == character_data:
			target_slot = slot
			break
	
	if not target_slot or target_slot not in valid_targets:
		print("❌ Target inválido para esta carta")
		return
	
	# Verificar si hay suficiente energía
	var card_cost = selected_card.data.cost
	var game_node = get_parent()
	
	if not game_node or not game_node.has_method("can_afford_card"):
		print("❌ ERROR - No se puede verificar energía")
		_cancel_targeting()
		return
	
	if not game_node.can_afford_card(card_cost):
		print("❌ Energía insuficiente para usar ", selected_card.data.name, " (Coste: ", card_cost, ")")
		_cancel_targeting()
		return
	
	# Usar energía
	if not game_node.use_energy(card_cost):
		print("❌ Error al usar energía")
		_cancel_targeting()
		return
	
	print("✅ Carta aplicada: ", selected_card.data.name, " → ", character_data.name, " (Coste: ", card_cost, ")")
	
	# Agregar al log de combate
	add_combat_log_entry("🃏 Jugador usa " + selected_card.data.name + " en " + character_data.name + " (⚡" + str(card_cost) + ")")
	
	# Aplicar efectos de la carta
	_apply_card_effects(selected_card.data, character_data)
	
	# Guardar referencia a la carta antes de limpiar targeting
	var card_to_discard = selected_card
	
	# Limpiar targeting (esto quita el focus automáticamente)
	_cancel_targeting()
	
	# Remover carta de la mano
	_discard_card(card_to_discard)

# --- SISTEMA DE EFECTOS DE CARTAS ---
func _apply_card_effects(card_data: CardData, target_character: CharacterData) -> void:
	"""Aplica los efectos de una carta a un personaje"""
	print("🎴 Aplicando efectos de ", card_data.name, " a ", target_character.name)
	print("🔍 DEBUG EFECTOS:")
	print("  - Carta ID: ", card_data.id)
	print("  - Power: ", card_data.power)
	print("  - Effects array size: ", card_data.effects.size())
	print("  - Status effects size: ", card_data.status_effects.size())
	print("  - Effects content: ", card_data.effects)
	
	# Obtener referencia al EffectManager
	var game_node = get_parent()
	var effect_manager = null
	if game_node and game_node.has_method("get_effect_manager"):
		effect_manager = game_node.get_effect_manager()
	
	# Aplicar efectos de estado primero
	if card_data.has_status_effects() and effect_manager:
		print("🔮 Aplicando efectos de estado...")
		for status_effect_data in card_data.status_effects:
			_apply_status_effect(target_character, status_effect_data, effect_manager)
	
	# Aplicar efectos tradicionales
	if card_data.effects.is_empty():
		print("⚠️ ADVERTENCIA: La carta no tiene efectos definidos!")
		print("  - Usando power como daño por defecto: ", card_data.power)
		if card_data.card_type == CardData.CardType.ATTACK:
			_apply_damage(target_character, card_data.power)
		elif card_data.card_type == CardData.CardType.HEAL:
			_apply_heal(target_character, card_data.power)
		else:
			print("  - Tipo de carta no soportado para fallback: ", card_data.card_type)
	else:
		for i in range(card_data.effects.size()):
			var effect = card_data.effects[i]
			print("  - Efecto ", i, ": ", effect)
			
			if not effect is Dictionary:
				print("    ⚠️ Efecto no es Dictionary, omitiendo")
				continue
				
			var effect_type = effect.get("type", "")
			var effect_value = effect.get("value", 0)
			print("    - Tipo: ", effect_type, " Valor: ", effect_value)
			
			match effect_type:
				"DAMAGE":
					_apply_damage(target_character, effect_value)
				"HEAL":
					_apply_heal(target_character, effect_value)
				"SHIELD":
					_apply_shield(target_character, effect_value)
				"BUFF":
					_apply_buff(target_character, effect_value)
				"DEBUFF":
					_apply_debuff(target_character, effect_value)
				"APPLY_STATUS":
					if effect_manager:
						_apply_status_effect_from_effect(target_character, effect, effect_manager)
				_:
					print("    ⚠️ Efecto desconocido: ", effect_type)
	
	# Actualizar UI del personaje
	_update_character_display(target_character)

func _apply_damage(character: CharacterData, damage: int) -> void:
	"""Aplica daño a un personaje"""
	print("🔍 DEBUG DAÑO:")
	print("  - Personaje: ", character.name)
	print("  - HP inicial: ", character.hp, "/", character.max_hp)
	print("  - Daño base: ", damage)
	print("  - Defensa: ", character.defense)
	
	var actual_damage = max(0, damage - character.defense)
	print("  - Daño real (después de defensa): ", actual_damage)
	
	var old_hp = character.hp
	character.hp = max(0, character.hp - actual_damage)
	var hp_lost = old_hp - character.hp
	
	print("  - HP perdido: ", hp_lost)
	print("  - HP final: ", character.hp, "/", character.max_hp)
	
	# Agregar al log de combate
	if actual_damage > 0:
		var damage_text = "💥 " + character.name + " recibe " + str(actual_damage) + " de daño"
		if character.defense > 0:
			damage_text += " (" + str(damage) + " - " + str(character.defense) + " defensa)"
		damage_text += " → HP: " + str(character.hp) + "/" + str(character.max_hp)
		add_combat_log_entry(damage_text)
	else:
		add_combat_log_entry("🛡️ " + character.name + " bloquea todo el daño con su defensa")
	
	if character.hp == 0:
		print("  ☠️ PERSONAJE DERROTADO!")
		add_combat_log_entry("☠️ " + character.name + " ha sido derrotado!")
	
	print("💥 ", character.name, " recibe ", actual_damage, " de daño → HP: ", character.hp, "/", character.max_hp)
	
	# Verificar game over después de aplicar daño
	var game_node = get_parent()
	if game_node and game_node.has_method("_check_game_over"):
		game_node._check_game_over()

func _apply_heal(character: CharacterData, heal: int) -> void:
	"""Cura a un personaje"""
	print("🔍 DEBUG CURACIÓN:")
	print("  - Personaje: ", character.name)
	print("  - HP inicial: ", character.hp, "/", character.max_hp)
	print("  - Curación base: ", heal)
	
	var old_hp = character.hp
	character.hp = min(character.max_hp, character.hp + heal)
	var actual_heal = character.hp - old_hp
	var overheal = heal - actual_heal
	
	print("  - HP curado real: ", actual_heal)
	if overheal > 0:
		print("  - Sobrecuración (desperdiciada): ", overheal)
	print("  - HP final: ", character.hp, "/", character.max_hp)
	
	# Agregar al log de combate
	if actual_heal > 0:
		add_combat_log_entry("💚 " + character.name + " se cura " + str(actual_heal) + " HP → HP: " + str(character.hp) + "/" + str(character.max_hp))
	else:
		add_combat_log_entry("💚 " + character.name + " ya tiene HP completo")
	
	print("💚 ", character.name, " se cura ", actual_heal, " HP → HP: ", character.hp, "/", character.max_hp)

func _apply_shield(character: CharacterData, shield: int) -> void:
	"""Aplica escudo a un personaje (por ahora solo aumenta defensa temporalmente)"""
	character.defense += shield
	add_combat_log_entry("🛡️ " + character.name + " gana " + str(shield) + " de escudo (Defensa: " + str(character.defense) + ")")
	print("🛡️ ", character.name, " gana ", shield, " de escudo (Defensa: ", character.defense, ")")

func _apply_buff(character: CharacterData, buff: int) -> void:
	"""Aplica buff a un personaje"""
	character.attack += buff
	print("⬆️ ", character.name, " gana ", buff, " de ataque (Ataque: ", character.attack, ")")

func _apply_debuff(character: CharacterData, debuff: int) -> void:
	"""Aplica debuff a un personaje"""
	character.attack = max(0, character.attack - debuff)
	print("⬇️ ", character.name, " pierde ", debuff, " de ataque (Ataque: ", character.attack, ")")

func _apply_status_effect(character: CharacterData, status_data: Dictionary, effect_manager: EffectManagerClass) -> void:
	"""Aplica un efecto de estado desde los datos de la carta"""
	var effect_type_str = status_data.get("effect_type", "")
	var modifier_type_str = status_data.get("modifier_type", "FLAT")
	var value = status_data.get("value", 0)
	var duration = status_data.get("duration", 1)
	
	# Convertir string a enum
	var effect_type = _string_to_status_effect_type(effect_type_str)
	var modifier_type = StatusEffect.ModifierType.FLAT
	if modifier_type_str == "PERCENTAGE":
		modifier_type = StatusEffect.ModifierType.PERCENTAGE
	
	# Crear el StatusEffect
	var status_effect = StatusEffect.new(effect_type, value, duration)
	status_effect.modifier_type = modifier_type
	status_effect.source_name = "Carta"
	
	# Aplicar el efecto
	effect_manager.apply_effect(character, status_effect)
	
	# Agregar al log de combate
	add_combat_log_entry("🔮 " + character.name + " recibe efecto: " + status_effect.get_display_text())
	
	print("🔮 Efecto de estado aplicado: ", status_effect.get_display_text())

func _apply_status_effect_from_effect(character: CharacterData, effect_data: Dictionary, effect_manager: EffectManagerClass) -> void:
	"""Aplica un efecto de estado desde un efecto tradicional"""
	var status_type_str = effect_data.get("status_type", "")
	var value = effect_data.get("value", 0)
	var duration = effect_data.get("duration", 1)
	
	# Convertir string a enum
	var effect_type = _string_to_status_effect_type(status_type_str)
	
	# Crear el StatusEffect
	var status_effect = StatusEffect.new(effect_type, value, duration)
	status_effect.source_name = "Carta"
	
	# Aplicar el efecto
	effect_manager.apply_effect(character, status_effect)
	print("🔮 Efecto de estado aplicado desde efecto: ", status_effect.get_display_text())

func _string_to_status_effect_type(type_str: String) -> StatusEffect.EffectType:
	"""Convierte un string a StatusEffect.EffectType"""
	match type_str:
		"BUFF_ATTACK":
			return StatusEffect.EffectType.BUFF_ATTACK
		"DEBUFF_ATTACK":
			return StatusEffect.EffectType.DEBUFF_ATTACK
		"BUFF_DEFENSE":
			return StatusEffect.EffectType.BUFF_DEFENSE
		"DEBUFF_DEFENSE":
			return StatusEffect.EffectType.DEBUFF_DEFENSE
		"STUN":
			return StatusEffect.EffectType.STUN
		"POISON":
			return StatusEffect.EffectType.POISON
		"REGENERATION":
			return StatusEffect.EffectType.REGENERATION
		"SHIELD":
			return StatusEffect.EffectType.SHIELD
		"VULNERABILITY":
			return StatusEffect.EffectType.VULNERABILITY
		"STRENGTH":
			return StatusEffect.EffectType.STRENGTH
		"WEAKNESS":
			return StatusEffect.EffectType.WEAKNESS
		"DOUBLE_DAMAGE":
			return StatusEffect.EffectType.DOUBLE_DAMAGE
		"HEAL_BLOCK":
			return StatusEffect.EffectType.HEAL_BLOCK
		_:
			print("⚠️ Tipo de efecto desconocido: ", type_str)
			return StatusEffect.EffectType.BUFF_ATTACK  # Default

func _update_character_display(character: CharacterData) -> void:
	"""Actualiza la visualización de un personaje"""
	# Buscar el slot del personaje y actualizar su display
	for slot in player_slots_nodes + enemy_slots_nodes:
		if slot.character_data == character:
			slot.set_character_data(character)  # Esto debería actualizar la UI
			
			# Actualizar efectos de estado
			if slot.has_method("update_status_effects"):
				slot.update_status_effects()
			
			# Marcar como muerto si HP = 0
			if character.hp <= 0 and slot.has_method("set_dead_state"):
				slot.set_dead_state(true)
				print("☠️ ", character.name, " ha sido marcado como muerto en la UI")
			break

# --- SISTEMA DE PREVIEW DE ACCIONES ENEMIGAS ---
func show_enemy_action_previews(actions: Array) -> void:
	"""Muestra las acciones que los enemigos van a realizar"""
	print("📋 Mostrando preview de ", actions.size(), " acciones enemigas")
	
	# Limpiar previews anteriores
	_clear_enemy_action_previews()
	
	# Agrupar acciones por enemigo
	var actions_by_enemy = {}
	for action in actions:
		var enemy_index = action.enemy_index
		if not actions_by_enemy.has(enemy_index):
			actions_by_enemy[enemy_index] = []
		actions_by_enemy[enemy_index].append(action)
	
	# Mostrar acciones en cada slot enemigo (ya vienen combinadas desde Enemy.gd)
	for enemy_index in actions_by_enemy.keys():
		if enemy_index < enemy_slots_nodes.size():
			var slot = enemy_slots_nodes[enemy_index]
			var enemy_actions = actions_by_enemy[enemy_index]
			slot.show_action_previews(enemy_actions)

func remove_enemy_action_preview(action: Dictionary) -> void:
	"""Remueve una acción específica del preview"""
	var enemy_index = action.enemy_index
	if enemy_index < enemy_slots_nodes.size():
		var slot = enemy_slots_nodes[enemy_index]
		slot.remove_action_preview(action)

func _clear_enemy_action_previews() -> void:
	"""Limpia todos los previews de acciones enemigas"""
	for slot in enemy_slots_nodes:
		slot.clear_action_previews()

# --- SISTEMA DE MAZO Y CARTAS PENDIENTES ---
func add_pending_card(card_data) -> void:
	"""Añade una carta a las cartas pendientes"""
	pending_cards.append(card_data)
	update_overflow_count()
	print("📥 Carta añadida a pendientes: ", card_data.name, " (Total: ", pending_cards.size(), ")")

func update_deck_count(count: int) -> void:
	"""Actualiza el contador del mazo"""
	if control_panel and control_panel.has_method("update_deck_count"):
		control_panel.update_deck_count(count)
		print("📚 Mazo actualizado: ", count, " cartas")

func update_overflow_count() -> void:
	"""Actualiza el contador de cartas pendientes"""
	if control_panel and control_panel.has_method("update_overflow_count"):
		var count = pending_cards.size()
		control_panel.update_overflow_count(count)
		print("📥 Cartas pendientes: ", count)

func show_hand_full_message() -> void:
	"""Muestra mensaje de mano llena"""
	# Crear label temporal si no existe
	var message_label = get_node_or_null("HandFullMessage")
	if not message_label:
		message_label = Label.new()
		message_label.name = "HandFullMessage"
		message_label.text = "⚠️ MANO LLENA"
		message_label.position = Vector2(400, 100)
		message_label.size = Vector2(200, 50)
		message_label.modulate = Color.YELLOW
		message_label.add_theme_font_size_override("font_size", 20)
		add_child(message_label)
	
	message_label.visible = true
	print("⚠️ Mensaje de mano llena mostrado")

func hide_hand_full_message() -> void:
	"""Oculta mensaje de mano llena"""
	var message_label = get_node_or_null("HandFullMessage")
	if message_label:
		message_label.visible = false
		print("✅ Mensaje de mano llena ocultado")

func show_overflow_blocking_message() -> void:
	"""Muestra mensaje cuando el overflow bloquea el robo de cartas"""
	# El mensaje visual ahora se maneja en ControlPanel
	add_combat_log_entry("📥 ¡Hay cartas pendientes! Usa el botón de overflow para añadirlas")
	
	print("⚠️ Overflow bloqueando robo de cartas - Botón parpadeando")

# --- SISTEMA DE DESCARTE ---
func _discard_card(card: Node2D) -> void:
	"""Remueve una carta de la mano y la añade al descarte"""
	if not card or not hand_container:
		return
	
	print("🗑️ Descartando carta: ", card.data.name if card.data else "Sin datos")
	
	# Remover de la mano de datos en Player.gd PRIMERO
	if card.data:
		var game_node = get_parent()
		print("🔍 DEBUG: game_node = ", game_node)
		
		if game_node and game_node.has_method("get_player_manager"):
			var player_manager = game_node.get_player_manager()
			print("🔍 DEBUG: player_manager = ", player_manager)
			
			if player_manager and player_manager.has_method("discard_card"):
				print("🔍 DEBUG: Llamando player_manager.discard_card() con: ", card.data.name)
				player_manager.discard_card(card.data)
				print("✅ DEBUG: Descarte completado en Player.gd")
			else:
				print("❌ player_manager no tiene método discard_card")
				print("🔍 Métodos disponibles: ", player_manager.get_method_list() if player_manager else "player_manager es null")
		else:
			print("❌ game_node no tiene método get_player_manager")
		
		# Añadir al descarte local (para compatibilidad)
		discard_pile.append(card.data)
		_update_discard_count_display()
	
	# Remover de la mano visual
	hand_container.remove_child(card)
	card.queue_free()

func _update_discard_count_display() -> void:
	"""Actualiza el contador de descarte en el ControlPanel"""
	print("🔍 DEBUG: _update_discard_count_display() llamado")
	
	if control_panel and control_panel.has_method("update_discard_count"):
		# Obtener el tamaño real del descarte desde Player.gd
		var game_node = get_parent()
		var real_discard_size = 0
		
		print("🔍 DEBUG: Obteniendo tamaño real del descarte...")
		if game_node and game_node.has_method("get_discard_cards"):
			var discard_cards = game_node.get_discard_cards()
			real_discard_size = discard_cards.size()
			print("🔍 DEBUG: Cartas reales en descarte: ", real_discard_size)
		else:
			# Fallback al sistema local si no hay acceso al Player
			real_discard_size = discard_pile.size()
			print("🔍 DEBUG: Usando descarte local: ", real_discard_size)
		
		control_panel.update_discard_count(real_discard_size)
		print("✅ DEBUG: Contador de descarte actualizado a: ", real_discard_size)
	else:
		print("❌ DEBUG: control_panel no disponible o no tiene update_discard_count")

func get_discard_pile_size() -> int:
	"""Retorna el tamaño de la pila de descarte"""
	return discard_pile.size()

func clear_discard_pile() -> void:
	"""Limpia la pila de descarte"""
	discard_pile.clear()
	_update_discard_count_display()

# --- OTRAS FUNCIONES DE UI ---
func _initialize_character_slots(container: HBoxContainer, slots_array: Array, count: int):
	print("DEBUG: _initialize_character_slots - container: ", container, " count: ", count)
	
	for child in container.get_children(): 
		print("DEBUG: Eliminando hijo existente: ", child)
		child.queue_free()
	slots_array.clear()
	
	for i in range(count):
		print("DEBUG: Creando slot ", i)
		var slot_instance = CharacterSlotScene.instantiate()
		print("DEBUG: Slot creado: ", slot_instance)

		# Conectar la señal del slot a una función del nodo Game
		# Asumimos que GameUI es hijo de Game
		var game_node = get_parent()
		if game_node and game_node.has_method("_on_character_selected"):
			slot_instance.character_clicked.connect(game_node._on_character_selected)
			print("DEBUG: Señal conectada para slot ", i)

		container.add_child(slot_instance)
		slots_array.append(slot_instance)
		slot_instance.visible = false
		print("DEBUG: Slot ", i, " añadido al contenedor y array")

# --- FUNCIONES DE UI DISPLAY ---
func set_turn(turn_num: int):
	"""Actualiza el display del turno"""
	if turn_label:
		turn_label.text = "Turno " + str(turn_num)
		print("🔄 Turno actualizado: ", turn_num)
		add_combat_log_entry("🔄 Turno " + str(turn_num) + " iniciado")
	else:
		print("⚠️ TurnLabel no encontrado para actualizar display")

func set_energy(current_energy: int, max_energy: int = 3):
	"""Actualiza el display de energía"""
	if energy_label:
		energy_label.text = "⚡ " + str(current_energy) + "/" + str(max_energy)
		print("⚡ Display actualizado: ", current_energy, "/", max_energy)
	else:
		print("⚠️ EnergyLabel no encontrado para actualizar display")
		print("⚠️ Ruta intentada: MainVBox/HBoxContainer/EnergyPanel/EnergyLabel")

func update_player_chars(chars_data: Array):
	print("DEBUG: update_player_chars llamado con ", chars_data.size(), " personajes")
	print("DEBUG: player_slots_nodes disponibles: ", player_slots_nodes.size())
	_update_character_slots(player_slots_nodes, chars_data)
	_update_all_status_effects(player_slots_nodes)

func update_enemy_chars(chars_data: Array):
	print("DEBUG: update_enemy_chars llamado con ", chars_data.size(), " personajes")
	print("DEBUG: enemy_slots_nodes disponibles: ", enemy_slots_nodes.size())
	_update_character_slots(enemy_slots_nodes, chars_data)
	_update_all_status_effects(enemy_slots_nodes)

func _update_character_slots(slots: Array, data: Array):
	print("DEBUG: _update_character_slots - slots: ", slots.size(), " data: ", data.size())
	for i in range(slots.size()):
		var slot_node = slots[i]
		if i < data.size():
			var d = data[i]
			print("DEBUG: Configurando slot ", i, " con personaje: ", d.name, " HP: ", d.hp)
			slot_node.visible = true
			if slot_node.has_method("set_character_data"):
				slot_node.set_character_data(d)
				print("DEBUG: Slot ", i, " configurado exitosamente")
			else:
				print("❌ ERROR: Slot ", i, " no tiene método set_character_data")
		else:
			print("DEBUG: Ocultando slot ", i, " (sin datos)")
			slot_node.visible = false

func _update_all_status_effects(slots: Array) -> void:
	"""Actualiza los efectos de estado para todos los slots"""
	for slot in slots:
		if slot.visible and slot.has_method("update_status_effects"):
			slot.update_status_effects()

# --- CALLBACKS DE MODALES ---

func _on_deck_modal_closed() -> void:
	"""Callback cuando se cierra el modal del mazo"""
	print("📚 Modal del mazo cerrado")

func _on_discard_modal_closed() -> void:
	"""Callback cuando se cierra el modal de descarte"""
	print("🗑️ Modal de descarte cerrado")

func _on_discard_card_selected(card_data) -> void:
	"""Callback cuando se selecciona una carta del descarte para recuperar"""
	print("🗑️ Carta seleccionada del descarte: ", card_data.name if card_data.has_method("get") else str(card_data))
	
	# Lógica para recuperar carta del descarte
	var game_node = get_parent()
	if game_node and game_node.has_method("recover_card_from_discard"):
		game_node.recover_card_from_discard(card_data)
		add_combat_log_entry("🔄 Carta recuperada del descarte: " + str(card_data.name if card_data.has_method("get") else card_data))
	else:
		print("❌ No se puede recuperar carta - método no disponible")
