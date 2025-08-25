extends Control

# No necesitamos importar HandContainer ya que es una clase global

# --- NODOS DE LA ESCENA ---
# NOTA: Estas rutas asumen que los nodos son hijos directos de GameUi
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer
@onready var hand_container = $HandContainer as HandContainer
@onready var test_button = $TestButton as Button
@onready var discard_button = $DiscardButton as Button

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

# Sistema de descarte
var discard_pile: Array[CardData] = []

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
	
	# Crear DiscardButton si no existe
	if not discard_button:
		print("DEBUG: Creando DiscardButton automáticamente...")
		var new_discard_button = Button.new()
		new_discard_button.name = "DiscardButton"
		new_discard_button.text = "0"
		new_discard_button.position = Vector2(1700, 50)
		new_discard_button.size = Vector2(150, 100)
		add_child(new_discard_button)
		discard_button = new_discard_button
		_update_discard_button_display()
		print("DEBUG: DiscardButton creado")

func _input(event: InputEvent) -> void:
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
		var clicked_card = _get_top_card_at_position(mouse_pos)
		if clicked_card and selected_card == clicked_card:
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

# --- SISTEMA DE DESCARTE ---
func _discard_card(card: Node2D) -> void:
	"""Remueve una carta de la mano y la añade al descarte"""
	if not card or not hand_container:
		return
	
	print("🗑️ Descartando carta: ", card.data.name if card.data else "Sin datos")
	
	# Añadir a la pila de descarte
	if card.data:
		discard_pile.append(card.data)
		_update_discard_button_display()
	
	# Remover de la mano
	hand_container.remove_child(card)
	card.queue_free()

func _update_discard_button_display() -> void:
	"""Actualiza el display del botón de descarte"""
	if discard_button:
		discard_button.text = str(discard_pile.size())

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
