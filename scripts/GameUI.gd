extends Control


@onready var turn_label     = $MainVBox/HBoxContainer/TurnPanel/TurnLabel
@onready var energy_label   = $MainVBox/HBoxContainer/EnergyPanel/EnergyLabel
@onready var hand_container = $MainVBox/HandPanel/CardsContainer

#contenedores
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer

var player_slots_nodes: Array = []
var enemy_slots_nodes: Array = []

const CharacterSlotScene = preload("res://scenes/ui_elements/CharacterSlot.tscn")

func _ready() -> void:
	if not player_slots_container:
		push_error("GameUI: PlayerChars (player_slots_container) no encontrado. Verifica la ruta en @onready.")
	else:
		_initialize_character_slots(player_slots_container, player_slots_nodes, 3) # Max 3 jugadores

	if not enemy_slots_container:
		push_error("GameUI: EnemyChars (enemy_slots_container) no encontrado. Verifica la ruta en @onready.")
	else:
		_initialize_character_slots(enemy_slots_container, enemy_slots_nodes, 5) # Max 5 enemigos

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

func add_card_to_hand(card: Node2D) -> void:
	if not hand_container:
		push_error("GameUI: hand_container no está asignado.")
		return
	hand_container.add_child(card)
