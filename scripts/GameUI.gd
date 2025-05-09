extends Control

@onready var turn_label     = $TurnPanel/TurnLabel
@onready var energy_label   = $EnergyPanel/EnergyLabel
@onready var player_slots   = $PlayerChars.get_children()
@onready var enemy_slots    = $EnemyChars.get_children()
@onready var hand_container = $HandPanel/CardsContainer

func set_turn(turn_num: int) -> void:
	turn_label.text = str(turn_num)

func set_energy(energy: int) -> void:
	energy_label.text = str(energy)

func update_player_chars(chars: Array) -> void:
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		if i < chars.size():
			var d = chars[i]
			slot.visible = true
			slot.get_node("Portrait").texture = d["portrait"]
			slot.get_node("CharName").text   = d["name"]
			slot.get_node("HPBar").max_value = d["max_hp"]
			slot.get_node("HPBar").value     = d["hp"]
		else:
			slot.visible = false

func update_enemy_chars(chars: Array) -> void:
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		if i < chars.size():
			var d = chars[i]
			slot.visible = true
			slot.get_node("Portrait").texture = d["portrait"]
			slot.get_node("CharName").text   = d["name"]
			slot.get_node("HPBar").max_value = d["max_hp"]
			slot.get_node("HPBar").value     = d["hp"]
		else:
			slot.visible = false

func clear_hand() -> void:
	hand_container.clear()

func add_card_to_hand(card: Node2D) -> void:
	hand_container.add_child(card)
