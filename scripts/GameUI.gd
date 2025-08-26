extends Control

# No necesitamos importar HandContainer ya que es una clase global

# --- NODOS DE LA ESCENA ---
# NOTA: Estas rutas asumen que los nodos son hijos directos de GameUi
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer
@onready var turn_label = get_node_or_null("MainVBox/HBoxContainer/TurnPanel/TurnLabel") as Label
@onready var energy_label = get_node_or_null("MainVBox/HBoxContainer/EnergyPanel/EnergyLabel") as Label
@onready var hand_container = get_node_or_null("HandContainer") as HandContainer
@onready var test_button = get_node_or_null("TestButton") as Button
@onready var discard_button = get_node_or_null("DiscardButton") as Button
@onready var energy_button = get_node_or_null("EnergyButton") as Button
@onready var end_turn_button = get_node_or_null("EndTurnButton") as Button
@onready var deck_button = get_node_or_null("DeckButton") as Button
@onready var overflow_button = get_node_or_null("OverflowButton") as Button

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

const CharacterSlotScene = preload("res://scenes/ui_elements/CharacterSlot.tscn")

# --- FUNCIONES DEL MOTOR ---
func _ready() -> void:
	# Crear nodos faltantes automáticamente
	_create_missing_nodes()
	
	# Inicializar slots de personajes
	_initialize_character_slots(player_slots_container, player_slots_nodes, 3)
	_initialize_character_slots(enemy_slots_container, enemy_slots_nodes, 5)
	
	# Configurar botón de pruebas
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
		test_button.text = "Añadir Carta (Test)"
	
	# Configurar botón de descarte
	if discard_button:
		_update_discard_button_display()
	
	# Crear nodos faltantes si es necesario
	_create_missing_nodes()

func _create_missing_nodes() -> void:
	# Crear HandContainer si no existe
	if not hand_container:
		print("DEBUG: Creando HandContainer automáticamente...")
		var new_hand_container = preload("res://scripts/HandContainer.gd").new()
		new_hand_container.name = "HandContainer"
		new_hand_container.position = Vector2(960, 700)  # Posición visible
		add_child(new_hand_container)
		hand_container = new_hand_container
		print("DEBUG: HandContainer creado en posición global: ", hand_container.global_position)
	
	# Crear TestButton si no existe
	if not test_button:
		print("DEBUG: Creando TestButton automáticamente...")
		var new_button = Button.new()
		new_button.name = "TestButton"
		new_button.text = "Añadir Carta (Test)"
		new_button.position = Vector2(50, 50)
		new_button.size = Vector2(200, 60)  # Más grande para ser más visible
		add_child(new_button)
		test_button = new_button
		# Conectar la señal aquí también
		test_button.pressed.connect(_on_test_button_pressed)
		print("DEBUG: TestButton creado y conectado")
	
	# Crear EnergyButton si no existe
	if not energy_button:
		print("DEBUG: Creando EnergyButton automáticamente...")
		var new_energy_button = Button.new()
		new_energy_button.name = "EnergyButton"
		new_energy_button.text = "+3 Energía (∞)"
		new_energy_button.position = Vector2(270, 50)  # Al lado del TestButton
		new_energy_button.size = Vector2(180, 60)
		add_child(new_energy_button)
		energy_button = new_energy_button
		# Conectar la señal
		energy_button.pressed.connect(_on_energy_button_pressed)
	
	# Crear EndTurnButton si no existe
	if not end_turn_button:
		print("DEBUG: Creando EndTurnButton automáticamente...")
		var new_end_turn_button = Button.new()
		new_end_turn_button.name = "EndTurnButton"
		new_end_turn_button.text = "🔄 TERMINAR TURNO"
		new_end_turn_button.position = Vector2(1500, 50)  # Esquina superior derecha
		new_end_turn_button.size = Vector2(200, 80)
		# Estilo llamativo
		new_end_turn_button.modulate = Color(1.2, 1.2, 0.8)  # Amarillo claro
		add_child(new_end_turn_button)
		end_turn_button = new_end_turn_button
		# Conectar la señal
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
		print("DEBUG: EndTurnButton creado y conectado")
	
	# Crear DeckButton si no existe
	if not deck_button:
		print("DEBUG: Creando DeckButton automáticamente...")
		var new_deck_button = Button.new()
		new_deck_button.name = "DeckButton"
		new_deck_button.text = "📚 20"
		new_deck_button.position = Vector2(50, 150)  # Debajo del TestButton
		new_deck_button.size = Vector2(100, 80)
		# Estilo del mazo
		new_deck_button.modulate = Color(0.8, 0.9, 1.0)  # Azul claro
		add_child(new_deck_button)
		deck_button = new_deck_button
		deck_button.pressed.connect(_on_deck_button_pressed)
		print("DEBUG: DeckButton creado y conectado")
	
	# Crear OverflowButton si no existe (inicialmente oculto)
	if not overflow_button:
		print("DEBUG: Creando OverflowButton automáticamente...")
		var new_overflow_button = Button.new()
		new_overflow_button.name = "OverflowButton"
		new_overflow_button.text = "📥 +0"
		new_overflow_button.position = Vector2(170, 150)  # Al lado del DeckButton
		new_overflow_button.size = Vector2(120, 80)
		# Estilo llamativo
		new_overflow_button.modulate = Color(1.2, 1.0, 0.8)  # Naranja claro
		new_overflow_button.visible = false  # Oculto por defecto
		add_child(new_overflow_button)
		overflow_button = new_overflow_button
		# Conectar la señal
		overflow_button.pressed.connect(_on_overflow_button_pressed)
		print("DEBUG: OverflowButton creado y conectado")
	
	# Conectar DiscardButton si existe en la escena
	if discard_button:
		print("DEBUG: DiscardButton encontrado en escena, conectando...")
		# Desconectar cualquier conexión previa para evitar duplicados
		if discard_button.pressed.is_connected(_on_discard_button_pressed):
			discard_button.pressed.disconnect(_on_discard_button_pressed)
		discard_button.pressed.connect(_on_discard_button_pressed)
		_update_discard_button_display()
		print("DEBUG: DiscardButton conectado exitosamente")
	else:
		print("DEBUG: Creando DiscardButton automáticamente...")
		var new_discard_button = Button.new()
		new_discard_button.name = "DiscardButton"
		new_discard_button.text = "0"
		new_discard_button.position = Vector2(1700, 50)
		new_discard_button.size = Vector2(150, 100)
		add_child(new_discard_button)
		discard_button = new_discard_button
		discard_button.pressed.connect(_on_discard_button_pressed)
		_update_discard_button_display()
		print("DEBUG: DiscardButton creado y conectado")

func _input(event: InputEvent) -> void:
	# No procesar input de cartas si no son interactivas
	if not cards_interactive:
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
	"""Verifica si la posición está sobre el botón de descarte"""
	if not discard_button:
		return false
	
	var button_rect = discard_button.get_global_rect()
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
	
	# Crear carta de test especial (alterna entre tipos)
	var game_node = get_parent()
	if game_node and game_node.has_method("_create_test_card"):
		print("DEBUG: Creando carta de test...")
		var hand_count = get_hand_size()
		var use_damage_ally_card = (hand_count % 4 == 0)  # Cada 4 cartas, crear carta de daño a aliados
		var use_super_damage_card = (hand_count % 5 == 0)  # Cada 5 cartas, crear carta súper poderosa
		var use_super_heal_card = (hand_count % 6 == 0)    # Cada 6 cartas, crear carta súper curación
		var test_card = game_node._create_test_card(use_damage_ally_card, use_super_damage_card, use_super_heal_card)
		if test_card:
			print("DEBUG: Carta de test creada exitosamente")
			add_card_to_hand(test_card)
		else:
			print("DEBUG: ERROR - No se pudo crear carta de test")
	else:
		print("DEBUG: ERROR - No se encontró el método _create_test_card en el nodo padre")

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
	
	# Debug adicional
	if discard_button:
		print("✅ discard_button existe: ", discard_button.name)
		print("✅ discard_button visible: ", discard_button.visible)
		print("✅ discard_button disabled: ", discard_button.disabled)
	else:
		print("❌ discard_button es null!")
		return
	
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
	
	# Botones que se deshabilitan durante turno enemigo
	if test_button:
		test_button.disabled = not active
		test_button.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5)
	
	if energy_button:
		energy_button.disabled = not active
		energy_button.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5)
	
	if end_turn_button:
		end_turn_button.disabled = not active
		end_turn_button.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5)
	
	if overflow_button:
		overflow_button.disabled = not active
		overflow_button.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5)
	
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
	
	# Deshabilitar TODOS los botones excepto mazo y descarte
	if test_button:
		test_button.disabled = true
		test_button.modulate = Color(0.3, 0.3, 0.3)
	
	if energy_button:
		energy_button.disabled = true
		energy_button.modulate = Color(0.3, 0.3, 0.3)
	
	if end_turn_button:
		end_turn_button.disabled = true
		end_turn_button.modulate = Color(0.3, 0.3, 0.3)
	
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
	"""Muestra el modal con las cartas del mazo"""
	print("📚 Abriendo modal del mazo...")
	
	# Obtener cartas del mazo desde Game.gd
	var game_node = get_parent()
	if not game_node or not game_node.has_method("get_deck_cards"):
		print("❌ No se puede acceder a las cartas del mazo")
		return
	
	var deck_cards = game_node.get_deck_cards()
	var title = "📚 MAZO (" + str(deck_cards.size()) + " cartas)"
	
	var modal = _create_card_modal(title, deck_cards)
	_show_modal(modal)

func show_discard_modal() -> void:
	"""Muestra el modal con las cartas de descarte"""
	print("🗑️ Abriendo modal de descarte...")
	
	# Obtener cartas de descarte desde Game.gd
	var game_node = get_parent()
	print("🔍 DEBUG: game_node = ", game_node)
	
	if not game_node:
		print("❌ game_node es null!")
		return
	
	if not game_node.has_method("get_discard_cards"):
		print("❌ game_node no tiene método get_discard_cards")
		print("🔍 Métodos disponibles en game_node: ", game_node.get_method_list())
		return
	
	print("✅ Llamando a game_node.get_discard_cards()...")
	var discard_cards = game_node.get_discard_cards()
	print("🔍 DEBUG: discard_cards recibidas: ", discard_cards.size())
	
	if discard_cards.is_empty():
		print("⚠️ No hay cartas en descarte para mostrar")
	
	var title = "🗑️ DESCARTE (" + str(discard_cards.size()) + " cartas)"
	print("🔍 DEBUG: Creando modal con título: ", title)
	
	var modal = _create_card_modal(title, discard_cards)
	print("🔍 DEBUG: Modal creado, mostrando...")
	_show_modal(modal)

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
	
	match card_data.card_type:
		CardData.CardType.ATTACK, CardData.CardType.DEBUFF:
			# Cartas ofensivas van a enemigos VIVOS
			valid_targets = enemy_slots_nodes.filter(func(slot): return slot.character_data != null and slot.character_data.hp > 0)
		CardData.CardType.HEAL, CardData.CardType.DEFENSE, CardData.CardType.BUFF:
			# Cartas defensivas/de apoyo van a aliados VIVOS
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
	print("  - Effects content: ", card_data.effects)
	
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
	
	if character.hp == 0:
		print("  ☠️ PERSONAJE DERROTADO!")
	
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
	
	print("💚 ", character.name, " se cura ", actual_heal, " HP → HP: ", character.hp, "/", character.max_hp)

func _apply_shield(character: CharacterData, shield: int) -> void:
	"""Aplica escudo a un personaje (por ahora solo aumenta defensa temporalmente)"""
	character.defense += shield
	print("🛡️ ", character.name, " gana ", shield, " de escudo (Defensa: ", character.defense, ")")

func _apply_buff(character: CharacterData, buff: int) -> void:
	"""Aplica buff a un personaje"""
	character.attack += buff
	print("⬆️ ", character.name, " gana ", buff, " de ataque (Ataque: ", character.attack, ")")

func _apply_debuff(character: CharacterData, debuff: int) -> void:
	"""Aplica debuff a un personaje"""
	character.attack = max(0, character.attack - debuff)
	print("⬇️ ", character.name, " pierde ", debuff, " de ataque (Ataque: ", character.attack, ")")

func _update_character_display(character: CharacterData) -> void:
	"""Actualiza la visualización de un personaje"""
	# Buscar el slot del personaje y actualizar su display
	for slot in player_slots_nodes + enemy_slots_nodes:
		if slot.character_data == character:
			slot.set_character_data(character)  # Esto debería actualizar la UI
			
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
	
	# Mostrar acciones en cada slot enemigo
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
	if deck_button:
		deck_button.text = "📚 " + str(count)
		print("📚 Mazo actualizado: ", count, " cartas")

func update_overflow_count() -> void:
	"""Actualiza el contador de cartas pendientes"""
	if overflow_button:
		var count = pending_cards.size()
		overflow_button.text = "📥 +" + str(count)
		overflow_button.visible = count > 0
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
	if overflow_button:
		# Hacer que el botón parpadee para llamar la atención
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(overflow_button, "modulate", Color.YELLOW, 0.3)
		tween.tween_property(overflow_button, "modulate", Color(1.2, 1.0, 0.8), 0.3)
	
	print("⚠️ Overflow bloqueando robo de cartas - Botón parpadeando")

# --- SISTEMA DE DESCARTE ---
func _discard_card(card: Node2D) -> void:
	"""Remueve una carta de la mano y la añade al descarte"""
	if not card or not hand_container:
		return
	
	print("🗑️ Descartando carta: ", card.data.name if card.data else "Sin datos")
	
	# Añadir a la pila de descarte (tanto local como en Player.gd)
	if card.data:
		# Añadir al descarte local (para compatibilidad)
		discard_pile.append(card.data)
		
		# Añadir al descarte del Player.gd (sistema principal)
		var game_node = get_parent()
		if game_node and game_node.has_method("discard_card_from_hand"):
			print("🔍 DEBUG: Notificando descarte a Player.gd")
			game_node.discard_card_from_hand(card.data)
		else:
			print("⚠️ No se pudo notificar descarte a Player.gd")
		
		_update_discard_button_display()
	
	# Remover de la mano
	hand_container.remove_child(card)
	card.queue_free()

func _update_discard_button_display() -> void:
	"""Actualiza el display del botón de descarte"""
	if discard_button:
		# Obtener el tamaño real del descarte desde Player.gd
		var game_node = get_parent()
		var real_discard_size = 0
		
		if game_node and game_node.has_method("get_discard_cards"):
			var discard_cards = game_node.get_discard_cards()
			real_discard_size = discard_cards.size()
			print("🔍 DEBUG: Actualizando botón descarte - Cartas reales: ", real_discard_size)
		else:
			# Fallback al sistema local si no hay acceso al Player
			real_discard_size = discard_pile.size()
			print("🔍 DEBUG: Usando descarte local: ", real_discard_size)
		
		discard_button.text = str(real_discard_size)

func get_discard_pile_size() -> int:
	"""Retorna el tamaño de la pila de descarte"""
	return discard_pile.size()

func clear_discard_pile() -> void:
	"""Limpia la pila de descarte"""
	discard_pile.clear()
	_update_discard_button_display()

# --- OTRAS FUNCIONES DE UI ---
func _initialize_character_slots(container: HBoxContainer, slots_array: Array, count: int):
	for child in container.get_children(): child.queue_free()
	slots_array.clear()
	for i in range(count):
		var slot_instance = CharacterSlotScene.instantiate()

		# Conectar la señal del slot a una función del nodo Game
		# Asumimos que GameUI es hijo de Game
		var game_node = get_parent()
		if game_node and game_node.has_method("_on_character_selected"):
			slot_instance.character_clicked.connect(game_node._on_character_selected)

		container.add_child(slot_instance)
		slots_array.append(slot_instance)
		slot_instance.visible = false

# --- FUNCIONES DE UI DISPLAY ---
func set_turn(turn_num: int):
	"""Actualiza el display del turno"""
	if turn_label:
		turn_label.text = "Turno " + str(turn_num)
		print("🔄 Turno actualizado: ", turn_num)
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
	_update_character_slots(player_slots_nodes, chars_data)

func update_enemy_chars(chars_data: Array):
	_update_character_slots(enemy_slots_nodes, chars_data)

func _update_character_slots(slots: Array, data: Array):
	for i in range(slots.size()):
		var slot_node = slots[i]
		if i < data.size():
			var d = data[i]
			slot_node.visible = true
			if slot_node.has_method("set_character_data"):
				slot_node.set_character_data(d)
		else:
			slot_node.visible = false
