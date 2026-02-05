extends Control
## Map - Escena del mapa del roguelike
## Muestra los nodos de batalla en un layout horizontal

# Referencias a nodos
var nodes_container: HBoxContainer
var back_btn: Button
var title_label: Label
var progress_label: Label

# Nodos visuales del mapa
var map_node_buttons: Array = []

func _ready() -> void:
	_create_ui()
	_generate_map_visuals()
	print("🗺️ Mapa cargado")

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _create_ui() -> void:
	"""Crea la estructura de UI del mapa"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.08, 0.12, 1)
	add_child(background)
	
	# Contenedor principal
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.anchor_left = 0.05
	main_vbox.anchor_top = 0.05
	main_vbox.anchor_right = 0.95
	main_vbox.anchor_bottom = 0.95
	main_vbox.add_theme_constant_override("separation", 30)
	add_child(main_vbox)
	
	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	back_btn = Button.new()
	back_btn.text = "← Menú"
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	title_label = Label.new()
	title_label.text = "🗺️ MAPA DEL ROGUELIKE"
	title_label.add_theme_font_size_override("font_size", 36)
	header.add_child(title_label)
	
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer2)
	
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 20)
	header.add_child(progress_label)
	
	# Separador
	var sep = HSeparator.new()
	main_vbox.add_child(sep)
	
	# Información de personajes seleccionados
	var chars_info = _create_characters_info()
	main_vbox.add_child(chars_info)
	
	# Área central del mapa
	var map_area = CenterContainer.new()
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(map_area)
	
	# Contenedor de nodos del mapa (horizontal)
	nodes_container = HBoxContainer.new()
	nodes_container.add_theme_constant_override("separation", 80)
	map_area.add_child(nodes_container)

func _create_characters_info() -> Control:
	"""Crea el panel de información de personajes seleccionados"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 100)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.anchor_left = 0.02
	hbox.anchor_right = 0.98
	hbox.add_theme_constant_override("separation", 30)
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = "Tu equipo:"
	label.add_theme_font_size_override("font_size", 20)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(label)
	
	# Mostrar personajes seleccionados
	var gm = _get_game_manager()
	if gm:
		var chars = gm.get_player_roster()
		for char_data in chars:
			var char_panel = _create_mini_character_panel(char_data)
			hbox.add_child(char_panel)
	
	return panel

func _create_mini_character_panel(char_data) -> Control:
	"""Crea un mini panel para mostrar un personaje"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 80)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.anchor_left = 0.05
	hbox.anchor_right = 0.95
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	# Portrait pequeño
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(60, 60)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if char_data.portrait:
		portrait.texture = char_data.portrait
	hbox.add_child(portrait)
	
	# Info
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = char_data.name
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [char_data.hp, char_data.max_hp]
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	vbox.add_child(hp_label)
	
	return panel

func _generate_map_visuals() -> void:
	"""Genera los nodos visuales del mapa basado en GameManager"""
	var gm = _get_game_manager()
	if not gm:
		print("❌ GameManager no disponible")
		return
	
	var map_nodes = gm.get_map_nodes()
	var current_index = gm.get_current_node_index()
	
	progress_label.text = "Nodo: %d / %d" % [current_index + 1, map_nodes.size()]
	
	map_node_buttons.clear()
	
	for i in range(map_nodes.size()):
		var node_data = map_nodes[i]
		var node_btn = _create_map_node(i, node_data)
		nodes_container.add_child(node_btn)
		map_node_buttons.append(node_btn)
		
		# Añadir flecha entre nodos (excepto el último)
		if i < map_nodes.size() - 1:
			var arrow = Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 48)
			arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nodes_container.add_child(arrow)

func _create_map_node(index: int, node_data: Dictionary) -> Control:
	"""Crea un nodo visual del mapa"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(180, 180)
	
	var is_completed = node_data.get("completed", false)
	var is_current = node_data.get("current", false)
	var node_type = node_data.get("type", "battle")
	var difficulty = node_data.get("difficulty", "common")
	
	# Icono según tipo
	var icon = "⚔️"
	if node_type == "boss":
		icon = "💀"
	elif difficulty == "epic":
		icon = "⚔️"
	
	# Texto del botón
	var text = ""
	if is_completed:
		text = "✅\n%s\nCompletado" % icon
		btn.disabled = true
		btn.modulate = Color(0.5, 0.7, 0.5)
	elif is_current:
		text = "%s\nNodo %d\n¡Entrar!" % [icon, index + 1]
		if node_type == "boss":
			text = "%s\n¡BOSS!\n¡Entrar!" % icon
			btn.modulate = Color(1.0, 0.7, 0.7)
		else:
			btn.modulate = Color(1.0, 1.0, 0.7)
	else:
		text = "🔒\nNodo %d\nBloqueado" % [index + 1]
		btn.disabled = true
		btn.modulate = Color(0.4, 0.4, 0.4)
	
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	
	# Conectar click solo para nodo actual
	if is_current:
		btn.pressed.connect(_on_node_pressed.bind(index))
	
	return btn

func _on_node_pressed(index: int) -> void:
	"""Maneja click en un nodo del mapa"""
	print("🎯 Nodo ", index + 1, " seleccionado - Iniciando batalla...")
	
	var gm = _get_game_manager()
	if gm:
		gm.start_node_battle()

func _on_back_pressed() -> void:
	"""Vuelve al menú principal"""
	print("🔙 Volviendo al menú...")
	
	# Mostrar confirmación
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "¿Abandonar la run actual y volver al menú?"
	confirm.confirmed.connect(_confirm_back_to_menu)
	add_child(confirm)
	confirm.popup_centered()

func _confirm_back_to_menu() -> void:
	"""Confirma volver al menú"""
	var gm = _get_game_manager()
	if gm:
		gm.return_to_main_menu()
