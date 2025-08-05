extends Control


@onready var turn_label     = $MainVBox/HBoxContainer/TurnPanel/TurnLabel
@onready var energy_label   = $MainVBox/HBoxContainer/EnergyPanel/EnergyLabel
@onready var hand_container = $CardsContainer as Node2D

#contenedores
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer

var player_slots_nodes: Array = []
var enemy_slots_nodes: Array = []

# Variables para el sistema de cartas en media esfera
var hand_cards: Array = [] # Array para guardar las cartas de la mano
var hand_center_position: Vector2 = Vector2(600, 200) # Centro de la media esfera
var hand_radius: float = 450.0 # Radio de la media esfera (aumentado para más dispersión)
var hovered_card: Node2D = null # Carta actualmente con hover
var card_original_scales: Dictionary = {} # Guardar escalas originales para cada carta
# Ángulo máximo de separación en grados (total)
var max_spread_angle: float = 120.0  # Más dispersión para mejor separación
var max_cards_visible: int = 10       # Máximo de cartas visibles

const CharacterSlotScene = preload("res://scenes/ui_elements/CharacterSlot.tscn")

# Variables para detectar mouse manualmente
var last_hovered_card: Node2D = null

# Debug visual (opcional)
@export var debug_hover_areas: bool = false  # Activar en el inspector para ver áreas

func _ready() -> void:
	if not player_slots_container:
		push_error("GameUI: PlayerChars (player_slots_container) no encontrado. Verifica la ruta en @onready.")
	else:
		_initialize_character_slots(player_slots_container, player_slots_nodes, 3) # Max 3 jugadores

	if not enemy_slots_container:
		push_error("GameUI: EnemyChars (enemy_slots_container) no encontrado. Verifica la ruta en @onready.")
	else:
		_initialize_character_slots(enemy_slots_container, enemy_slots_nodes, 5) # Max 5 enemigos

# Procesar input del mouse manualmente
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.global_position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_click(event.global_position)

# Manejar movimiento del mouse
func _handle_mouse_motion(mouse_pos: Vector2) -> void:
	var current_top_card = _get_top_card_at_position(mouse_pos)
	
	# Si cambió la carta bajo el cursor
	if current_top_card != last_hovered_card:
		# Quitar hover de la carta anterior
		if last_hovered_card:
			_apply_hover_effect(last_hovered_card, false)
		
		# Aplicar hover a la nueva carta
		if current_top_card:
			_apply_hover_effect(current_top_card, true)
			# Debug info si está activo
			if debug_hover_areas:
				_debug_print_hover_info(current_top_card, mouse_pos)
		
		last_hovered_card = current_top_card

# Manejar click del mouse
func _handle_mouse_click(mouse_pos: Vector2) -> void:
	var clicked_card = _get_top_card_at_position(mouse_pos)
	if clicked_card:
		print("Carta seleccionada: ", clicked_card.data.name if clicked_card.data else "sin data")
		# Aquí puedes añadir lógica para jugar la carta

func _initialize_character_slots(container: HBoxContainer, slots_array: Array, count: int):
	if not container:
		# Este error ya se manejaría en _ready, pero es una doble comprobación.
		push_error("GameUI: Contenedor de slots no es válido en _initialize_character_slots")
		return
		
	# Limpiar slots anteriores del contenedor y del array
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	slots_array.clear()
	
	for i in range(count):
		var slot_instance = CharacterSlotScene.instantiate()
		container.add_child(slot_instance)
		slots_array.append(slot_instance)
		slot_instance.visible = false # Ocultar inicialmente

func set_turn(turn_num: int) -> void:
	if turn_label:
		turn_label.text = str(turn_num)
	else:
		push_error("GameUI: turn_label no está asignado.")

func set_energy(energy: int) -> void:
	if energy_label:
		energy_label.text = str(energy)
	else:
		push_error("GameUI: energy_label no está asignado.")

func update_player_chars(chars_data: Array) -> void:
	if not player_slots_container or player_slots_nodes.is_empty():
		push_warning("GameUI: Player slots no están listos para actualizar (contenedor o nodos vacíos).")
		return
		
	for i in range(player_slots_nodes.size()):
		var slot_node = player_slots_nodes[i] # Esto es una instancia de CharacterSlot.tscn
		if i < chars_data.size():
			var d = chars_data[i] # Esto es CharacterData
			slot_node.visible = true
			
			if slot_node.has_method("set_character_data"):
				slot_node.set_character_data(d) 
			else:
				var vboxcont  = slot_node.get_node("VBoxContainer") as VBoxContainer 
				(vboxcont.get_node("Portrait") as TextureRect).texture = d.portrait 
				(vboxcont.get_node("NameLabel") as Label).text   = d.name
				var hp_bar = vboxcont.get_node("HPBar") as ProgressBar
				hp_bar.max_value = d.max_hp
				hp_bar.value     = d.hp
		else:
			slot_node.visible = false

func update_enemy_chars(chars_data: Array) -> void:
	if not enemy_slots_container or enemy_slots_nodes.is_empty():
		push_warning("GameUI: Enemy slots no están listos para actualizar (contenedor o nodos vacíos).")
		return

	for i in range(enemy_slots_nodes.size()):
		var slot_node = enemy_slots_nodes[i]
		if i < chars_data.size():
			var d = chars_data[i]
			slot_node.visible = true
			if slot_node.has_method("set_character_data"):
				slot_node.set_character_data(d)
			else:
				var vboxcont  = slot_node.get_node("VBoxContainer") as VBoxContainer
				(vboxcont.get_node("Portrait") as TextureRect).texture = d.portrait
				(vboxcont.get_node("NameLabel") as Label).text   = d.name
				var hp_bar = vboxcont.get_node("HPBar") as ProgressBar
				hp_bar.max_value = d.max_hp
				hp_bar.value     = d.hp
		else:
			slot_node.visible = false

func clear_hand() -> void:
	if not hand_container:
		push_error("GameUI: hand_container no está asignado.")
		return
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()
	hand_cards.clear()
	hovered_card = null
	last_hovered_card = null
	card_original_scales.clear()

func add_card_to_hand(card: Node2D) -> void:
	if not hand_container:
		push_error("GameUI: hand_container no está asignado.")
		return
	
	# Configurar propiedades básicas de la carta
	card.visible = true
	card.modulate = Color.WHITE
	card.z_index = 100 + hand_cards.size()  # Z-index incremental para prioridad hover
	
	# Configurar input para hover
	_setup_card_input(card)
	
	hand_container.add_child(card)
	hand_cards.append(card)
	_arrange_cards_in_hemisphere()

func _arrange_cards_in_hemisphere() -> void:
	var card_count = hand_cards.size()
	if card_count == 0:
		return
	
	# Ajustar el centro de la esfera según el tamaño de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	hand_center_position = Vector2(viewport_size.x / 2, viewport_size.y - 150)
	
	# Calcular el ángulo entre cartas
	var angle_step: float = 0.0
	var start_angle: float = 0.0
	
	if card_count == 1:
		# Una sola carta en el centro
		start_angle = 0.0
		angle_step = 0.0
	else:
		# Distribuir cartas en un arco - usar máxima dispersión disponible
		var current_spread: float
		if card_count <= max_cards_visible:
			# Para pocas cartas, usar dispersión máxima
			current_spread = max_spread_angle
		else:
			# Para muchas cartas, mantener separación mínima
			current_spread = max_spread_angle
		
		angle_step = current_spread / (card_count - 1)
		start_angle = -current_spread / 2.0
	
	# Posicionar cada carta
	for i in range(card_count):
		var card = hand_cards[i]
		var angle_rad = deg_to_rad(start_angle + i * angle_step)
		
		# Calcular posición en la media esfera
		var x_offset = sin(angle_rad) * hand_radius
		# Factor 0.3 hace la curva menos pronunciada (más plana)
		# Valores menores = más plano, valores mayores = más curvado
		var y_offset = -cos(angle_rad) * hand_radius * 0.3
		
		var target_position = hand_center_position + Vector2(x_offset, y_offset)
		
		# Animar la carta a su nueva posición
		var tween = create_tween()
		tween.tween_property(card, "position", target_position, 0.3)
		
		# Rotar ligeramente la carta para seguir la curvatura
		var rotation_angle = angle_rad * 0.5 # Factor 0.5 para una rotación más sutil
		tween.parallel().tween_property(card, "rotation", rotation_angle, 0.3)
		
		# Añadir un pequeño efecto de escala para dar profundidad
		var scale_factor = 0.9 + (cos(angle_rad) * 0.1) # Las cartas del centro ligeramente más grandes
		var final_scale = Vector2(scale_factor, scale_factor)
		tween.parallel().tween_property(card, "scale", final_scale, 0.3)
		
		# Guardar la escala original de esta carta para el hover
		card_original_scales[card] = final_scale
		
		# Actualizar z-index para prioridad de hover (cartas del centro más arriba)
		card.z_index = 100 + int((cos(angle_rad) + 1.0) * 50) + i

# Configurar input y hover para una carta
func _setup_card_input(_card: Node2D) -> void:
	# Para Node2D usaremos detección manual de mouse
	# No necesitamos configurar nada especial aquí
	pass

# Detectar la carta con mayor z-index bajo el cursor
func _get_top_card_at_position(global_pos: Vector2) -> Node2D:
	var top_card: Node2D = null
	var highest_z_index: int = -999999
	
	for card in hand_cards:
		if card and card.visible:
			# Convertir posición global a posición local del contenedor
			var local_pos = hand_container.to_local(global_pos)
			
			# Obtener el tamaño real de la carta considerando la escala
			var card_scale = card.scale
			var base_size = Vector2(200, 254)  # Tamaño base de la carta
			var scaled_size = base_size * card_scale
			
			# El centro de la carta está en card.position, crear rectángulo centrado
			var card_rect = Rect2(
				card.position - scaled_size / 2.0,  # Posición superior-izquierda
				scaled_size  # Tamaño del rectángulo
			)
			
			if card_rect.has_point(local_pos):
				if card.z_index > highest_z_index:
					highest_z_index = card.z_index
					top_card = card
	
	return top_card

# Debug visual simplificado - muestra info en consola
func _debug_print_hover_info(card: Node2D, mouse_pos: Vector2) -> void:
	if debug_hover_areas and card:
		var local_pos = hand_container.to_local(mouse_pos)
		var card_scale = card.scale
		var base_size = Vector2(200, 254)
		var scaled_size = base_size * card_scale
		var card_rect = Rect2(card.position - scaled_size / 2.0, scaled_size)
		
		print("Debug Hover - Carta: ", card.data.name if card.data else "sin data")
		print("  Posición mouse local: ", local_pos)
		print("  Rectángulo carta: ", card_rect)
		print("  Escala carta: ", card_scale)
		print("  ¿Mouse dentro?: ", card_rect.has_point(local_pos))

# Funciones de hover simplificadas (ahora manejadas por _input)

# Aplicar o quitar efecto de hover
func _apply_hover_effect(card: Node2D, is_hovered: bool) -> void:
	if not card:
		return
	
	if is_hovered and hovered_card != card:
		# Quitar hover de carta anterior
		if hovered_card:
			_remove_hover_visual(hovered_card)
		
		# Aplicar hover a nueva carta
		hovered_card = card
		_apply_hover_visual(card)
		
	elif not is_hovered and hovered_card == card:
		# Quitar hover si es la carta actualmente hovereada
		_remove_hover_visual(card)
		hovered_card = null

# Efectos visuales de hover
func _apply_hover_visual(card: Node2D) -> void:
	if not card_original_scales.has(card):
		# Si no tenemos la escala original, usar la actual como base
		card_original_scales[card] = card.scale
	
	var original_scale = card_original_scales[card]
	var hover_scale = original_scale * 1.1
	
	var tween = create_tween()
	tween.parallel().tween_property(card, "scale", hover_scale, 0.15)
	tween.parallel().tween_property(card, "modulate", Color(1.2, 1.2, 1.0), 0.15)
	card.z_index += 1000  # Elevar temporalmente por encima de todas

func _remove_hover_visual(card: Node2D) -> void:
	if not card_original_scales.has(card):
		# Fallback: usar escala actual dividida por 1.1
		card_original_scales[card] = card.scale / 1.1
	
	var original_scale = card_original_scales[card]
	
	var tween = create_tween()
	tween.parallel().tween_property(card, "scale", original_scale, 0.15)
	tween.parallel().tween_property(card, "modulate", Color.WHITE, 0.15)
	card.z_index -= 1000  # Restaurar z-index original
