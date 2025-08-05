extends Control

# --- NODOS DE LA ESCENA ---
# NOTA: Estas rutas asumen que los nodos son hijos directos de GameUi
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer
@onready var hand_container = $HandContainer # ¡Asegúrate que el nodo se llame así!

# --- VARIABLES DE ESTADO ---
var player_slots_nodes: Array = []
var enemy_slots_nodes: Array = []
var hovered_card: Node2D = null
var last_hovered_card: Node2D = null

const CharacterSlotScene = preload("res://scenes/ui_elements/CharacterSlot.tscn")

# --- FUNCIONES DEL MOTOR ---
func _ready() -> void:
	# Inicializar slots de personajes
	_initialize_character_slots(player_slots_container, player_slots_nodes, 3)
	_initialize_character_slots(enemy_slots_container, enemy_slots_nodes, 5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.global_position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.global_position)

# --- MANEJO DE INPUT Y HOVER ---
func _handle_mouse_motion(mouse_pos: Vector2) -> void:
	var current_top_card = _get_top_card_at_position(mouse_pos)
	
	if current_top_card != last_hovered_card:
		if last_hovered_card:
			_apply_hover_effect(last_hovered_card, false)
		
		if current_top_card:
			_apply_hover_effect(current_top_card, true)
		
		last_hovered_card = current_top_card

func _handle_mouse_click(mouse_pos: Vector2) -> void:
	var clicked_card = _get_top_card_at_position(mouse_pos)
	if clicked_card:
		print("Carta seleccionada: ", clicked_card.data.name if clicked_card.data else "sin data")

# --- GESTIÓN DE LA MANO (DELEGADA) ---
func clear_hand() -> void:
	hand_container.clear_cards()
	hovered_card = null
	last_hovered_card = null

func add_card_to_hand(card: Node2D) -> void:
	hand_container.add_card(card)
	card.scale = Vector2(0.8, 0.8)

# --- LÓGICA DE HOVER ---
func _get_top_card_at_position(global_pos: Vector2) -> Node2D:
	var top_card: Node2D = null
	var max_z = -1

	for card in hand_container.get_children():
		if card is Node2D and card.visible:
			var local_pos = card.to_local(global_pos)
			var card_rect = Rect2(Vector2(-100, -127), Vector2(200, 254))
			
			if card_rect.has_point(local_pos) and card.z_index > max_z:
				top_card = card
				max_z = card.z_index
	
	return top_card

func _apply_hover_effect(card: Node2D, is_hovered: bool) -> void:
	if not card: return
	
	var original_scale = Vector2(0.8, 0.8)
	var target_scale = original_scale * 1.15 if is_hovered else original_scale
	var target_z = card.z_index + (1000 if is_hovered else -1000)

	var tween = create_tween().set_parallel()
	tween.tween_property(card, "scale", target_scale, 0.15)
	card.z_index = target_z

# --- OTRAS FUNCIONES DE UI ---
func _initialize_character_slots(container: HBoxContainer, slots_array: Array, count: int):
	for child in container.get_children(): child.queue_free()
	slots_array.clear()
	for i in range(count):
		var slot_instance = CharacterSlotScene.instantiate()
		container.add_child(slot_instance)
		slots_array.append(slot_instance)
		slot_instance.visible = false

# Estas funciones ahora no hacen nada, ya que no tenemos los labels de Turno/Energía
# en esta versión simplificada. Puedes volver a añadirlos si lo necesitas.
func set_turn(turn_num: int):
	pass # print("Turno: ", turn_num)

func set_energy(energy: int):
	pass # print("Energía: ", energy)

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
