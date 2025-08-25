extends Node
class_name Player

# --- VARIABLES DEL JUGADOR ---
var energy: int = 0
var max_energy: int = 3
var hand_cards: Array = []
var max_hand_size: int = 8
var discard_pile: Array = []

# Referencias
var game_node: Node = null
var ui_node: Control = null
var deck_node: Node = null

signal energy_changed(current: int, maximum: int)
signal hand_changed(cards: Array)
signal card_played(card_data)

func _ready() -> void:
	# Buscar referencias
	game_node = get_parent()
	ui_node = game_node.get_node("GameUI") if game_node else null
	deck_node = game_node.get_node("Deck") if game_node else null

# --- GESTIÓN DE ENERGÍA ---
func start_turn() -> void:
	"""Inicia el turno del jugador"""
	print("🎮 Iniciando turno del jugador")
	
	# Regenerar energía (respeta energía de testing)
	if energy < max_energy:
		energy = max_energy
		print("⚡ Energía regenerada a ", max_energy)
	else:
		print("⚡ Energía actual: ", energy, " (excede máximo normal)")
	
	energy_changed.emit(energy, max_energy)
	
	# Robar cartas
	_draw_cards(4)

func can_afford_card(cost: int) -> bool:
	"""Verifica si el jugador puede pagar una carta"""
	return energy >= cost

func use_energy(cost: int) -> bool:
	"""Usa energía para una carta"""
	if energy >= cost:
		energy -= cost
		energy_changed.emit(energy, max_energy)
		print("⚡ Energía usada: ", cost, " → Actual: ", energy, "/", max_energy)
		return true
	else:
		print("❌ Energía insuficiente: ", energy, "/", cost)
		return false

func add_energy(amount: int) -> void:
	"""Añade energía respetando límite"""
	energy = min(max_energy, energy + amount)
	energy_changed.emit(energy, max_energy)

func add_energy_test(amount: int) -> void:
	"""Añade energía sin límite (testing)"""
	energy = min(99, energy + amount)
	energy_changed.emit(energy, max_energy)
	print("🧪 Energía de prueba: ", energy, "/", max_energy)

# --- GESTIÓN DE CARTAS ---
func _draw_cards(count: int) -> void:
	"""Roba cartas del deck"""
	if not deck_node:
		print("❌ No hay deck disponible")
		return
	
	print("🃏 Robando ", count, " cartas...")
	for i in range(count):
		if hand_cards.size() >= max_hand_size:
			print("⚠️ Mano llena, no se pueden robar más cartas")
			break
		
		var card_data = deck_node.draw()
		if card_data:
			_add_card_to_hand(card_data)

func _add_card_to_hand(card_data) -> void:
	"""Añade una carta a la mano"""
	if hand_cards.size() >= max_hand_size:
		print("⚠️ Mano llena, descartando carta")
		discard_pile.append(card_data)
		return
	
	hand_cards.append(card_data)
	hand_changed.emit(hand_cards)
	print("🃏 Carta añadida: ", card_data.name, " (", hand_cards.size(), "/", max_hand_size, ")")

func play_card(card_data, _target_character = null) -> bool:
	"""Juega una carta"""
	if not can_afford_card(card_data.cost):
		print("❌ No se puede pagar la carta: ", card_data.name)
		return false
	
	if not use_energy(card_data.cost):
		return false
	
	# Remover carta de la mano
	var card_index = hand_cards.find(card_data)
	if card_index >= 0:
		hand_cards.remove_at(card_index)
		discard_pile.append(card_data)
		hand_changed.emit(hand_cards)
	
	card_played.emit(card_data)
	print("✅ Carta jugada: ", card_data.name)
	return true

func discard_card(card_data) -> void:
	"""Descarta una carta de la mano"""
	var card_index = hand_cards.find(card_data)
	if card_index >= 0:
		hand_cards.remove_at(card_index)
		discard_pile.append(card_data)
		hand_changed.emit(hand_cards)
		print("🗑️ Carta descartada: ", card_data.name)

func get_hand_size() -> int:
	return hand_cards.size()

func get_discard_size() -> int:
	return discard_pile.size()

func clear_hand() -> void:
	"""Limpia la mano (para nuevo turno)"""
	for card_data in hand_cards:
		discard_pile.append(card_data)
	hand_cards.clear()
	hand_changed.emit(hand_cards)

# --- GETTERS ---
func get_energy() -> int:
	return energy

func get_max_energy() -> int:
	return max_energy

func get_hand_cards() -> Array:
	return hand_cards.duplicate()
