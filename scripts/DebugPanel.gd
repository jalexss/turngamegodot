extends Control
class_name DebugPanel

# Referencias internas
var panel_container: PanelContainer
var toggle_button: Button
var buttons_container: VBoxContainer
var is_expanded: bool = false

# Referencias a Game
var game_node: Node = null
var player_manager: Node = null

# Señales
signal debug_action_executed(action_name: String)

func _ready() -> void:
	_create_ui()
	_find_game_references()
	print("🔧 DebugPanel inicializado")

func _find_game_references() -> void:
	"""Busca las referencias al juego"""
	# Buscar hacia arriba en el árbol
	var parent = get_parent()
	while parent:
		if parent.has_method("_check_game_over"):
			game_node = parent
			break
		parent = parent.get_parent()
	
	if game_node:
		player_manager = game_node.get_node_or_null("Player")
		print("🔧 DebugPanel: Referencias encontradas")
	else:
		print("⚠️ DebugPanel: No se encontró Game node")

func _create_ui() -> void:
	"""Crea la interfaz del panel de debug"""
	# Configurar este Control para que cubra toda la pantalla pero no bloquee clicks
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Contenedor principal
	panel_container = PanelContainer.new()
	panel_container.name = "DebugPanelContainer"
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_container)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.8, 0.4, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel_container.add_theme_stylebox_override("panel", style)
	
	# VBox para contenido
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 5)
	panel_container.add_child(main_vbox)
	
	# Botón de toggle
	toggle_button = Button.new()
	toggle_button.text = "🔧 Debug"
	toggle_button.custom_minimum_size = Vector2(120, 30)
	toggle_button.pressed.connect(_on_toggle_pressed)
	var toggle_style = StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.8, 0.4, 0.1)
	toggle_style.set_corner_radius_all(4)
	toggle_button.add_theme_stylebox_override("normal", toggle_style)
	main_vbox.add_child(toggle_button)
	
	# Contenedor de botones (inicialmente oculto)
	buttons_container = VBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 4)
	buttons_container.visible = false
	main_vbox.add_child(buttons_container)
	
	# Crear los botones de debug
	_create_debug_buttons()
	
	# Posicionar debajo del TopBar (que tiene ~80px de alto)
	panel_container.position = Vector2(10, 90)

func _create_debug_buttons() -> void:
	"""Crea todos los botones de debug"""
	var buttons_data = [
		{"text": "⚡ +5 Energía", "callback": _on_add_energy, "color": Color(0.3, 0.6, 0.3)},
		{"text": "🗑️ Vaciar Mano", "callback": _on_clear_hand, "color": Color(0.6, 0.3, 0.3)},
		{"text": "🃏 +1 Carta Aleatoria", "callback": _on_add_random_card, "color": Color(0.3, 0.4, 0.6)},
		{"text": "☠️ Matar Enemigos", "callback": _on_kill_enemies, "color": Color(0.7, 0.2, 0.2)},
		{"text": "💚 Curar Enemigos", "callback": _on_heal_enemies, "color": Color(0.2, 0.5, 0.2)},
		{"text": "💖 Curar Aliados", "callback": _on_heal_allies, "color": Color(0.2, 0.6, 0.4)},
	]
	
	for data in buttons_data:
		var btn = Button.new()
		btn.text = data.text
		btn.custom_minimum_size = Vector2(160, 28)
		btn.pressed.connect(data.callback)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = data.color
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = data.color.lightened(0.2)
		hover_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
		
		buttons_container.add_child(btn)

func _on_toggle_pressed() -> void:
	"""Toggle para mostrar/ocultar botones de debug"""
	is_expanded = not is_expanded
	buttons_container.visible = is_expanded
	toggle_button.text = "🔧 Debug ▼" if is_expanded else "🔧 Debug"

func _on_add_energy() -> void:
	"""Agrega 5 de energía al jugador (sin límite)"""
	if player_manager:
		player_manager.energy += 5
		player_manager.energy_changed.emit(player_manager.energy, player_manager.max_energy)
		print("🔧 DEBUG: +5 Energía → Total: ", player_manager.energy)
		debug_action_executed.emit("add_energy")
	else:
		_find_game_references()
		push_warning("DebugPanel: No se encontró Player manager")

func _on_clear_hand() -> void:
	"""Elimina todas las cartas de la mano del jugador"""
	if player_manager:
		var cards_removed = player_manager.hand_cards.size()
		player_manager.hand_cards.clear()
		player_manager.hand_changed.emit(player_manager.hand_cards)
		print("🔧 DEBUG: Mano vaciada (", cards_removed, " cartas eliminadas)")
		debug_action_executed.emit("clear_hand")
		
		# Actualizar UI si existe
		var ui = game_node.get_node_or_null("GameUI") if game_node else null
		if ui and ui.has_method("_on_player_hand_changed"):
			ui._on_player_hand_changed(player_manager.hand_cards)
	else:
		_find_game_references()
		push_warning("DebugPanel: No se encontró Player manager")

func _on_add_random_card() -> void:
	"""Agrega una carta aleatoria a la mano"""
	if game_node:
		var deck = game_node.get_node_or_null("Deck")
		if deck and deck.has_method("get_all_card_definitions"):
			var all_cards = deck.get_all_card_definitions()
			if not all_cards.is_empty():
				var random_id = all_cards.keys()[randi() % all_cards.size()]
				var card = deck._create_card_from_id(random_id)
				if card and player_manager:
					player_manager.hand_cards.append(card)
					player_manager.hand_changed.emit(player_manager.hand_cards)
					print("🔧 DEBUG: Carta añadida - ", card.name)
					debug_action_executed.emit("add_card")
					
					# Actualizar UI
					var ui = game_node.get_node_or_null("GameUI")
					if ui and ui.has_method("_on_player_hand_changed"):
						ui._on_player_hand_changed(player_manager.hand_cards)
				return
		
		# Fallback: usar el método de testing si existe
		var ui = game_node.get_node_or_null("GameUI")
		if ui and ui.has_method("_add_test_card"):
			ui._add_test_card()
			print("🔧 DEBUG: Carta añadida via fallback")
			debug_action_executed.emit("add_card")
	else:
		_find_game_references()
		push_warning("DebugPanel: No se encontró Game node")

func _on_kill_enemies() -> void:
	"""Mata a todos los enemigos (victoria instantánea)"""
	if game_node and game_node.has_node("enemy_chars"):
		# Intentar acceder via propiedad
		pass
	
	if game_node:
		var enemy_chars = game_node.get("enemy_chars")
		if enemy_chars:
			for enemy in enemy_chars:
				enemy.hp = 0
			print("🔧 DEBUG: Todos los enemigos eliminados")
			debug_action_executed.emit("kill_enemies")
			
			# Verificar game over
			if game_node.has_method("_check_game_over"):
				game_node._check_game_over()
			
			# Actualizar UI
			var ui = game_node.get_node_or_null("GameUI")
			if ui and ui.has_method("update_enemy_slots"):
				ui.update_enemy_slots()
		else:
			push_warning("DebugPanel: No se encontró enemy_chars")
	else:
		_find_game_references()
		push_warning("DebugPanel: No se encontró Game node")

func _on_heal_enemies() -> void:
	"""Cura completamente a todos los enemigos"""
	if game_node:
		var enemy_chars = game_node.get("enemy_chars")
		if enemy_chars:
			for enemy in enemy_chars:
				enemy.hp = enemy.max_hp
			print("🔧 DEBUG: Todos los enemigos curados a full HP")
			debug_action_executed.emit("heal_enemies")
			
			# Actualizar UI
			var ui = game_node.get_node_or_null("GameUI")
			if ui and ui.has_method("update_enemy_slots"):
				ui.update_enemy_slots()
		else:
			push_warning("DebugPanel: No se encontró enemy_chars")
	else:
		_find_game_references()
		push_warning("DebugPanel: No se encontró Game node")

func _on_heal_allies() -> void:
	"""Cura completamente a todos los aliados"""
	if game_node:
		var player_chars = game_node.get("player_chars")
		if player_chars:
			for ally in player_chars:
				ally.hp = ally.max_hp
			print("🔧 DEBUG: Todos los aliados curados a full HP")
			debug_action_executed.emit("heal_allies")
			
			# Actualizar UI
			var ui = game_node.get_node_or_null("GameUI")
			if ui and ui.has_method("update_player_slots"):
				ui.update_player_slots()
		else:
			push_warning("DebugPanel: No se encontró player_chars")
	else:
		_find_game_references()
		push_warning("DebugPanel: No se encontró Game node")
