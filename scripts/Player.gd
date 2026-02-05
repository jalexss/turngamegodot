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
	
	# Asegurar que ui_node está disponible
	if not ui_node:
		ui_node = game_node.get_node("GameUI") if game_node else null
		print("🔍 ui_node re-inicializado: ", ui_node)
	
	# Regenerar energía (respeta energía de testing)
	if energy < max_energy:
		energy = max_energy
		print("⚡ Energía regenerada a ", max_energy)
	else:
		print("⚡ Energía actual: ", energy, " (excede máximo normal)")
	
	energy_changed.emit(energy, max_energy)
	
	# Verificar si hay cartas pendientes antes de robar
	print("🃏 Mano actual: ", hand_cards.size(), " cartas")
	
	var has_pending = _has_pending_cards()
	print("🔍 ¿Hay cartas pendientes?: ", has_pending)
	
	if has_pending:
		print("⚠️ HAY CARTAS PENDIENTES - No se robarán cartas nuevas")
		print("📥 Usa el botón de overflow para añadir las cartas pendientes primero")
		
		# Mostrar feedback visual al jugador
		if ui_node and ui_node.has_method("show_overflow_blocking_message"):
			ui_node.show_overflow_blocking_message()
	else:
		print("✅ No hay cartas pendientes - Robando 2 cartas nuevas")
		_draw_cards(2)

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
	print("📊 Estado inicial - Mano: ", hand_cards.size(), "/", max_hand_size)
	
	var cards_drawn = 0
	var cards_pending = 0
	
	for i in range(count):
		var card_data = deck_node.draw()
		if not card_data:
			print("⚠️ No hay más cartas en el deck")
			break
		
		print("🔍 Carta ", i+1, ": ", card_data.name, " | Mano actual: ", hand_cards.size(), "/", max_hand_size)
		
		if hand_cards.size() >= max_hand_size:
			# Añadir a cartas pendientes
			print("📥 Mano llena, añadiendo a pendientes: ", card_data.name)
			_add_to_pending_cards(card_data)
			cards_pending += 1
		else:
			print("🃏 Añadiendo a mano: ", card_data.name)
			_add_card_to_hand(card_data)
			cards_drawn += 1
			print("📊 Mano después de añadir: ", hand_cards.size(), "/", max_hand_size)
	
	print("📊 Resultado final - Robadas: ", cards_drawn, " | Pendientes: ", cards_pending)
	print("📊 Mano final: ", hand_cards.size(), "/", max_hand_size)
	
	# Actualizar UI
	_update_deck_display()
	_update_overflow_display()
	
	# Mostrar mensaje si la mano está llena
	if cards_pending > 0:
		print("⚠️ Hay cartas pendientes, mostrando mensaje de mano llena")
		_show_hand_full_message()
	elif hand_cards.size() >= max_hand_size:
		print("⚠️ Mano llena (", hand_cards.size(), "/", max_hand_size, "), mostrando mensaje")
		_show_hand_full_message()
	else:
		print("✅ Mano no está llena (", hand_cards.size(), "/", max_hand_size, "), no mostrar mensaje")

func _add_to_pending_cards(card_data) -> void:
	"""Añade una carta a las cartas pendientes"""
	# Buscar referencia a UI
	if not ui_node:
		ui_node = game_node.get_node("GameUI") if game_node else null
	
	if ui_node and ui_node.has_method("add_pending_card"):
		ui_node.add_pending_card(card_data)
		print("📥 Carta añadida a pendientes: ", card_data.name)

func _update_deck_display() -> void:
	"""Actualiza el display del mazo"""
	if not ui_node:
		ui_node = game_node.get_node("GameUI") if game_node else null
	
	if ui_node and ui_node.has_method("update_deck_count"):
		var deck_size = deck_node.get_cards_remaining() if deck_node else 0
		ui_node.update_deck_count(deck_size)

func _update_overflow_display() -> void:
	"""Actualiza el display de cartas pendientes"""
	if not ui_node:
		ui_node = game_node.get_node("GameUI") if game_node else null
	
	if ui_node and ui_node.has_method("update_overflow_count"):
		ui_node.update_overflow_count()

func _show_hand_full_message() -> void:
	"""Muestra mensaje de mano llena"""
	if not ui_node:
		ui_node = game_node.get_node("GameUI") if game_node else null
	
	if ui_node and ui_node.has_method("show_hand_full_message"):
		ui_node.show_hand_full_message()
		print("⚠️ Mano llena - mensaje mostrado")

func _add_card_to_hand(card_data) -> void:
	"""Añade una carta a la mano"""
	print("🔍 _add_card_to_hand() - Carta: ", card_data.name)
	print("🔍 Estado antes: hand_cards.size() = ", hand_cards.size(), " | max_hand_size = ", max_hand_size)
	
	if hand_cards.size() >= max_hand_size:
		print("⚠️ Mano llena, descartando carta: ", card_data.name)
		discard_pile.append(card_data)
		return
	
	hand_cards.append(card_data)
	print("🔍 Estado después: hand_cards.size() = ", hand_cards.size())
	print("📡 Emitiendo hand_changed con ", hand_cards.size(), " cartas")
	hand_changed.emit(hand_cards)
	print("🃏 Carta añadida exitosamente: ", card_data.name, " (", hand_cards.size(), "/", max_hand_size, ")")

func play_card(card_data, _target_character = null) -> bool:
	"""Juega una carta"""
	print("🎴 JUGANDO CARTA: ", card_data.name)
	print("🔍 Mano antes de jugar: ", hand_cards.size(), "/", max_hand_size)
	
	if not can_afford_card(card_data.cost):
		print("❌ No se puede pagar la carta: ", card_data.name)
		return false
	
	if not use_energy(card_data.cost):
		return false
	
	# Remover carta de la mano
	var card_index = hand_cards.find(card_data)
	if card_index >= 0:
		print("🗑️ Removiendo carta de la mano: ", card_data.name, " (índice: ", card_index, ")")
		hand_cards.remove_at(card_index)
		discard_pile.append(card_data)
		print("📡 Emitiendo hand_changed después de jugar carta")
		hand_changed.emit(hand_cards)
		print("🔍 Mano después de jugar: ", hand_cards.size(), "/", max_hand_size)
	else:
		print("⚠️ Carta no encontrada en la mano: ", card_data.name)
	
	card_played.emit(card_data)
	print("✅ Carta jugada: ", card_data.name)
	return true

func discard_card(card_data) -> void:
	"""Descarta una carta de la mano"""
	print("🗑️ DESCARTANDO CARTA: ", card_data.name)
	print("🔍 Mano antes de descartar: ", hand_cards.size(), "/", max_hand_size)
	
	var card_index = hand_cards.find(card_data)
	if card_index >= 0:
		hand_cards.remove_at(card_index)
		discard_pile.append(card_data)
		print("📡 Emitiendo hand_changed después de descartar")
		hand_changed.emit(hand_cards)
		print("🔍 Mano después de descartar: ", hand_cards.size(), "/", max_hand_size)
		print("🗑️ Carta descartada exitosamente: ", card_data.name)
	else:
		print("⚠️ Carta no encontrada para descartar: ", card_data.name)

func add_to_discard_pile(card_data) -> void:
	"""Añade una carta al descarte sin removerla de la mano"""
	print("🗑️ AÑADIENDO AL DESCARTE: ", card_data.name)
	discard_pile.append(card_data)
	print("📊 Descarte actualizado: ", discard_pile.size(), " cartas")

func get_hand_size() -> int:
	return hand_cards.size()

func get_discard_size() -> int:
	return discard_pile.size()

func clear_hand() -> void:
	"""Limpia la mano (para nuevo turno)"""
	print("🧹 LIMPIANDO MANO COMPLETA")
	print("🔍 Mano antes de limpiar: ", hand_cards.size(), "/", max_hand_size)
	
	for card_data in hand_cards:
		discard_pile.append(card_data)
		print("🗑️ Moviendo a descarte: ", card_data.name)
	
	hand_cards.clear()
	print("📡 Emitiendo hand_changed después de limpiar")
	hand_changed.emit(hand_cards)
	print("🔍 Mano después de limpiar: ", hand_cards.size(), "/", max_hand_size)

# --- GETTERS ---
func get_energy() -> int:
	return energy

func get_max_energy() -> int:
	return max_energy

func get_hand_cards() -> Array:
	return hand_cards.duplicate()

func get_discard_pile() -> Array:
	return discard_pile.duplicate()

func _has_pending_cards() -> bool:
	"""Verifica si hay cartas pendientes en overflow"""
	if not ui_node:
		ui_node = game_node.get_node("GameUI") if game_node else null
		print("🔍 ui_node re-obtenido en _has_pending_cards: ", ui_node)
	
	if not ui_node:
		print("❌ ui_node es null en _has_pending_cards!")
		return false
	
	if not ui_node.has_method("get_pending_cards_count"):
		print("❌ GameUI no tiene método get_pending_cards_count!")
		return false
	
	var pending_count = ui_node.get_pending_cards_count()
	print("🔍 Cartas pendientes en UI: ", pending_count)
	return pending_count > 0
