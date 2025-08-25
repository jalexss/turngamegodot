extends Control

# No necesitamos importar HandContainer ya que es una clase global

# --- NODOS DE LA ESCENA ---
# NOTA: Estas rutas asumen que los nodos son hijos directos de GameUi
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer
@onready var hand_container = $HandContainer as HandContainer
@onready var test_button = $TestButton as Button

# --- VARIABLES DE ESTADO ---
var player_slots_nodes: Array = []
var enemy_slots_nodes: Array = []
var hovered_card: Node2D = null
var last_hovered_card: Node2D = null

# Configuración de la mano
const MAX_HAND_SIZE: int = 8  # Reducido para mejor visibilidad

# Estados de targeting
enum TargetingState { NONE, WAITING_FOR_TARGET }
var targeting_state: TargetingState = TargetingState.NONE
var selected_card: Node2D = null
var hovered_target: Control = null  # Personaje bajo el cursor durante targeting

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.global_position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.global_position)
		# No consumir el evento para que los CharacterSlots también lo reciban
		# get_viewport().set_input_as_handled() # Comentado para permitir propagación

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
			
			last_hovered_card = current_top_card

func _handle_mouse_click(mouse_pos: Vector2) -> void:
	print("DEBUG: Click detectado en posición: ", mouse_pos)
	
	if targeting_state == TargetingState.WAITING_FOR_TARGET:
		# Durante targeting, verificar si se clickeó un personaje
		var clicked_character_slot = _get_character_slot_at_position(mouse_pos)
		print("DEBUG: Character slot clickeado: ", clicked_character_slot)
		
		if clicked_character_slot and clicked_character_slot.character_data:
			print("DEBUG: Enviando character_data a _on_character_targeted: ", clicked_character_slot.character_data.name)
			_on_character_targeted(clicked_character_slot.character_data)
			return
		
		# Si no se clickeó un personaje, verificar si se clickeó la carta para cancelar
		var clicked_card = _get_top_card_at_position(mouse_pos)
		if clicked_card and selected_card == clicked_card:
			_cancel_targeting()
		return
	
	# Comportamiento normal cuando no hay targeting
	var clicked_card = _get_top_card_at_position(mouse_pos)
	if clicked_card and hand_container:
		# Hacer focus Y activar targeting inmediatamente
		hand_container.focus_card(clicked_card)
		_start_targeting(clicked_card)
		print("🎯 Targeting activado para: ", clicked_card.data.name if clicked_card.data else "Sin datos")

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
	
	# Crear una carta de prueba aleatoria
	var game_node = get_parent()
	if game_node and game_node.has_method("_create_test_card"):
		print("DEBUG: Creando carta de test...")
		var test_card = game_node._create_test_card()
		if test_card:
			print("DEBUG: Carta de test creada exitosamente")
			add_card_to_hand(test_card)
		else:
			print("DEBUG: ERROR - No se pudo crear carta de test")
	else:
		print("DEBUG: ERROR - No se encontró el método _create_test_card en el nodo padre")

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
	
	selected_card = card
	targeting_state = TargetingState.WAITING_FOR_TARGET
	
	# Determinar qué personajes son válidos según el tipo de carta
	var valid_targets = _get_valid_targets_for_card(card.data)
	
	print("🎯 Targeting activado para: ", card.data.name)
	print("🎯 Tipo de carta: ", CardData.CardType.keys()[card.data.card_type])
	print("🎯 Targets válidos: ", valid_targets.size())
	
	# Cambiar cursor
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	print("DEBUG: Cursor cambiado a CROSS")
	
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
	print("DEBUG: Cursor restaurado a ARROW")
	
	# Quitar resaltado de todos los personajes
	_clear_target_highlights()
	
	# Quitar focus de carta si existe
	if hand_container:
		hand_container.unfocus_card()

func _get_valid_targets_for_card(card_data: CardData) -> Array:
	"""Determina qué personajes son targets válidos para una carta"""
	var valid_targets: Array = []
	
	match card_data.card_type:
		CardData.CardType.ATTACK, CardData.CardType.DEBUFF:
			# Cartas ofensivas van a enemigos
			valid_targets = enemy_slots_nodes.filter(func(slot): return slot.character_data != null)
		CardData.CardType.HEAL, CardData.CardType.DEFENSE, CardData.CardType.BUFF:
			# Cartas defensivas/de apoyo van a aliados
			valid_targets = player_slots_nodes.filter(func(slot): return slot.character_data != null)
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
				print("🎯 Apuntando a: ", current_target.character_data.name if current_target.character_data else "Sin datos")
			else:
				current_target = null  # No es válido, no hacer hover
		
		hovered_target = current_target

func _get_character_slot_at_position(global_pos: Vector2) -> Control:
	"""Obtiene el slot de personaje en la posición dada"""
	print("DEBUG: Buscando character slot en posición: ", global_pos)
	print("DEBUG: Player slots: ", player_slots_nodes.size(), " Enemy slots: ", enemy_slots_nodes.size())
	
	for slot in player_slots_nodes + enemy_slots_nodes:
		if slot.character_data:
			var rect = slot.get_global_rect()
			print("DEBUG: Slot ", slot.character_data.name, " rect: ", rect)
			if rect.has_point(global_pos):
				print("DEBUG: ¡Encontrado slot! ", slot.character_data.name)
				return slot
	
	print("DEBUG: No se encontró slot en esa posición")
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
	
	print("✅ Carta aplicada: ", selected_card.data.name, " → ", character_data.name)
	
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
	
	for effect in card_data.effects:
		if not effect is Dictionary:
			continue
			
		var effect_type = effect.get("type", "")
		var effect_value = effect.get("value", 0)
		
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
				print("⚠️ Efecto desconocido: ", effect_type)
	
	# Actualizar UI del personaje
	_update_character_display(target_character)

func _apply_damage(character: CharacterData, damage: int) -> void:
	"""Aplica daño a un personaje"""
	var actual_damage = max(0, damage - character.defense)
	character.hp = max(0, character.hp - actual_damage)
	print("💥 ", character.name, " recibe ", actual_damage, " de daño (HP: ", character.hp, "/", character.max_hp, ")")

func _apply_heal(character: CharacterData, heal: int) -> void:
	"""Cura a un personaje"""
	var old_hp = character.hp
	character.hp = min(character.max_hp, character.hp + heal)
	var actual_heal = character.hp - old_hp
	print("💚 ", character.name, " se cura ", actual_heal, " HP (HP: ", character.hp, "/", character.max_hp, ")")

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
			break

# --- SISTEMA DE DESCARTE ---
func _discard_card(card: Node2D) -> void:
	"""Remueve una carta de la mano y la añade al descarte"""
	if not card or not hand_container:
		return
	
	print("🗑️ Descartando carta: ", card.data.name if card.data else "Sin datos")
	
	# Remover de la mano
	hand_container.remove_child(card)
	card.queue_free()
	
	# TODO: Añadir a pila de descarte cuando se implemente
	print("📚 Carta añadida al descarte (sistema pendiente de implementar)")

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

# Estas funciones ahora no hacen nada, ya que no tenemos los labels de Turno/Energía
# en esta versión simplificada. Puedes volver a añadirlos si lo necesitas.
func set_turn(_turn_num: int):
	pass # print("Turno: ", _turn_num)

func set_energy(_energy: int):
	pass # print("Energía: ", _energy)

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
