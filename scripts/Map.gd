extends Control
## Map - Escena del mapa de supervivencia
## Muestra los nodos en un layout horizontal (izquierda a derecha) con ramificaciones verticales

# Referencias a nodos
var main_container: VBoxContainer
var scroll_container: ScrollContainer
var map_container: HBoxContainer
var back_btn: Button
var title_label: Label
var progress_label: Label
var gold_label: Label
var buffs_container: HBoxContainer

# Cache de tipos de nodo
var NodeType = {}

func _ready() -> void:
	_get_node_types()
	_create_ui()
	_generate_map_visuals()
	_update_gold_display()
	_update_buffs_display()
	_connect_signals()
	print("🗺️ Mapa cargado")

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _get_node_types():
	"""Obtiene los tipos de nodo del GameManager"""
	var gm = _get_game_manager()
	if gm:
		NodeType = gm.get_node_type_enum()

func _connect_signals():
	"""Conecta señales del GameManager"""
	var gm = _get_game_manager()
	if gm:
		if not gm.gold_changed.is_connected(_on_gold_changed):
			gm.gold_changed.connect(_on_gold_changed)
		if not gm.buffs_changed.is_connected(_on_buffs_changed):
			gm.buffs_changed.connect(_on_buffs_changed)

func _on_gold_changed(_new_gold: int):
	_update_gold_display()

func _on_buffs_changed():
	_update_buffs_display()

func _create_ui() -> void:
	"""Crea la estructura de UI del mapa"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.08, 0.12, 1)
	add_child(background)
	
	# Contenedor principal
	main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.anchor_left = 0.02
	main_container.anchor_top = 0.02
	main_container.anchor_right = 0.98
	main_container.anchor_bottom = 0.98
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Header
	var header = _create_header()
	main_container.add_child(header)
	
	# Separador
	var sep = HSeparator.new()
	main_container.add_child(sep)
	
	# Panel de oro y buffos
	var status_panel = _create_status_panel()
	main_container.add_child(status_panel)
	
	# Información de personajes
	var chars_info = _create_characters_info()
	main_container.add_child(chars_info)
	
	# Área del mapa con scroll horizontal (arrastrable)
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = true
	main_container.add_child(scroll_container)
	
	# Contenedor del mapa con márgenes para scroll
	var map_margin = MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 50)
	map_margin.add_theme_constant_override("margin_right", 100)
	map_margin.add_theme_constant_override("margin_top", 20)
	map_margin.add_theme_constant_override("margin_bottom", 20)
	scroll_container.add_child(map_margin)
	
	map_container = HBoxContainer.new()
	map_container.add_theme_constant_override("separation", 80)
	map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_margin.add_child(map_container)

func _create_header() -> Control:
	"""Crea el header con título y botones"""
	var header = HBoxContainer.new()
	
	back_btn = Button.new()
	back_btn.text = "← Menú"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.custom_minimum_size = Vector2(100, 35)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	title_label = Label.new()
	title_label.text = "🗺️ MAPA DE SUPERVIVENCIA"
	title_label.add_theme_font_size_override("font_size", 28)
	header.add_child(title_label)
	
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer2)
	
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 18)
	header.add_child(progress_label)
	
	return header

func _create_status_panel() -> Control:
	"""Crea el panel de estado (oro y buffos)"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 50)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.anchor_left = 0.02
	hbox.anchor_right = 0.98
	hbox.add_theme_constant_override("separation", 30)
	panel.add_child(hbox)
	
	# Oro
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(gold_label)
	
	# Separador vertical
	var vsep = VSeparator.new()
	hbox.add_child(vsep)
	
	# Label de buffos
	var buffs_label = Label.new()
	buffs_label.text = "Mejoras:"
	buffs_label.add_theme_font_size_override("font_size", 16)
	buffs_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(buffs_label)
	
	# Contenedor de buffos
	buffs_container = HBoxContainer.new()
	buffs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buffs_container.add_theme_constant_override("separation", 10)
	buffs_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(buffs_container)
	
	return panel

func _create_characters_info() -> Control:
	"""Crea el panel de información de personajes"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 90)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.anchor_left = 0.02
	hbox.anchor_right = 0.98
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = "Tu equipo:"
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(label)
	
	# Mostrar personajes
	var gm = _get_game_manager()
	if gm:
		var chars = gm.get_player_roster()
		for char_data in chars:
			var char_panel = _create_mini_character_panel(char_data)
			hbox.add_child(char_panel)
	
	return panel

func _create_mini_character_panel(char_data) -> Control:
	"""Crea un mini panel para un personaje"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(160, 70)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.anchor_left = 0.05
	hbox.anchor_right = 0.95
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	
	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(50, 50)
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
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	var hp_label = Label.new()
	hp_label.text = "❤️ %d/%d" % [char_data.hp, char_data.max_hp]
	hp_label.add_theme_font_size_override("font_size", 11)
	var hp_ratio = float(char_data.hp) / float(char_data.max_hp)
	if hp_ratio < 0.3:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif hp_ratio < 0.6:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	vbox.add_child(hp_label)
	
	var stats_label = Label.new()
	stats_label.text = "⚔️%d 🛡️%d" % [char_data.attack, char_data.defense]
	stats_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(stats_label)
	
	return panel

func _generate_map_visuals() -> void:
	"""Genera los nodos visuales del mapa (horizontal: izquierda a derecha)"""
	var gm = _get_game_manager()
	if not gm:
		print("❌ GameManager no disponible")
		return
	
	var map_nodes = gm.get_map_nodes()
	var current_level = gm.get_current_node_index()
	var total_levels = gm.get_total_levels()
	
	progress_label.text = "%d / %d" % [current_level + 1, total_levels]
	
	# Limpiar mapa anterior
	for child in map_container.get_children():
		child.queue_free()
	
	# Usar seed para posiciones consistentes
	var rng = RandomNumberGenerator.new()
	rng.seed = gm.current_seed
	
	# Generar niveles (horizontal)
	for level_idx in range(map_nodes.size()):
		var level_nodes = map_nodes[level_idx]
		var level_container = _create_level_container(level_idx, level_nodes, current_level, rng)
		map_container.add_child(level_container)
		
		# Conexión visual entre niveles (línea punteada)
		if level_idx < map_nodes.size() - 1:
			var connector = _create_connector()
			map_container.add_child(connector)

func _create_connector() -> Control:
	"""Crea un conector visual entre niveles"""
	var connector = Control.new()
	connector.custom_minimum_size = Vector2(60, 0)
	connector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Línea visual
	var line = ColorRect.new()
	line.color = Color(0.3, 0.3, 0.35, 0.6)
	line.custom_minimum_size = Vector2(40, 3)
	line.set_anchors_preset(Control.PRESET_CENTER)
	line.position = Vector2(-20, 0)
	connector.add_child(line)
	
	return connector

func _create_level_container(level_idx: int, level_nodes: Array, current_level: int, rng: RandomNumberGenerator) -> Control:
	"""Crea un contenedor para los nodos de un nivel con posiciones más orgánicas"""
	var container = VBoxContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 15)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Añadir espaciado aleatorio arriba para variar la posición
	var top_spacer = Control.new()
	var random_offset = rng.randi_range(0, 40)
	top_spacer.custom_minimum_size = Vector2(0, random_offset)
	container.add_child(top_spacer)
	
	# Nodos del nivel
	for node_idx in range(level_nodes.size()):
		var node_data = level_nodes[node_idx]
		var node_btn = _create_node_button(level_idx, node_idx, node_data, current_level)
		container.add_child(node_btn)
	
	# Espaciador inferior para balance
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(bottom_spacer)
	
	return container

func _create_node_button(level_idx: int, node_idx: int, node_data: Dictionary, current_level: int) -> Button:
	"""Crea un botón de nodo con estilo mejorado"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(130, 70)
	
	var is_completed = node_data.get("completed", false)
	var node_type = node_data.get("type", NodeType.get("BATTLE", 0))
	var is_current_level = (level_idx == current_level)
	var is_past_level = (level_idx < current_level)
	
	# Icono según tipo
	var icon = _get_node_icon(node_type)
	var type_name = _get_node_type_display_name(node_type)
	
	# Estilo del botón
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	
	# Texto y estado del botón
	if is_completed:
		btn.text = "✅\n%s" % type_name
		btn.disabled = true
		style.bg_color = Color(0.15, 0.25, 0.15, 0.9)
		style.border_color = Color(0.3, 0.5, 0.3)
	elif is_past_level:
		btn.text = "%s\n%s" % [icon, type_name]
		btn.disabled = true
		style.bg_color = Color(0.12, 0.12, 0.12, 0.7)
		style.border_color = Color(0.25, 0.25, 0.25)
		btn.modulate = Color(0.5, 0.5, 0.5)
	elif is_current_level:
		btn.text = "%s\n%s" % [icon, type_name]
		var base_color = _get_node_color(node_type)
		style.bg_color = Color(base_color.r * 0.3, base_color.g * 0.3, base_color.b * 0.3, 0.95)
		style.border_color = base_color
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		btn.pressed.connect(_on_node_pressed.bind(node_idx))
	else:
		btn.text = "🔒\n%s" % type_name
		btn.disabled = true
		style.bg_color = Color(0.08, 0.08, 0.1, 0.8)
		style.border_color = Color(0.2, 0.2, 0.2)
		btn.modulate = Color(0.4, 0.4, 0.4)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_font_size_override("font_size", 14)
	
	return btn

func _get_node_icon(node_type) -> String:
	"""Retorna el icono del tipo de nodo"""
	if node_type == NodeType.get("BATTLE", 0): return "⚔️"
	if node_type == NodeType.get("BOSS", 1): return "💀"
	if node_type == NodeType.get("SHOP", 2): return "🛒"
	if node_type == NodeType.get("REST", 3): return "🏕️"
	if node_type == NodeType.get("TREASURE", 4): return "💰"
	if node_type == NodeType.get("RANDOM", 5): return "❓"
	return "❓"

func _get_node_type_display_name(node_type) -> String:
	"""Retorna el nombre del tipo de nodo"""
	if node_type == NodeType.get("BATTLE", 0): return "Batalla"
	if node_type == NodeType.get("BOSS", 1): return "BOSS"
	if node_type == NodeType.get("SHOP", 2): return "Tienda"
	if node_type == NodeType.get("REST", 3): return "Descanso"
	if node_type == NodeType.get("TREASURE", 4): return "Tesoro"
	if node_type == NodeType.get("RANDOM", 5): return "Evento"
	return "???"

func _get_node_color(node_type) -> Color:
	"""Retorna el color del nodo según tipo"""
	if node_type == NodeType.get("BATTLE", 0): return Color(1.0, 0.9, 0.7)
	if node_type == NodeType.get("BOSS", 1): return Color(1.0, 0.6, 0.6)
	if node_type == NodeType.get("SHOP", 2): return Color(0.7, 0.9, 1.0)
	if node_type == NodeType.get("REST", 3): return Color(0.7, 1.0, 0.7)
	if node_type == NodeType.get("TREASURE", 4): return Color(1.0, 0.9, 0.5)
	if node_type == NodeType.get("RANDOM", 5): return Color(0.9, 0.7, 1.0)
	return Color(1.0, 1.0, 1.0)

func _update_gold_display() -> void:
	"""Actualiza el display de oro"""
	var gm = _get_game_manager()
	if gm and gold_label:
		gold_label.text = "🪙 %d oro" % gm.get_gold()

func _update_buffs_display() -> void:
	"""Actualiza el display de buffos"""
	if not buffs_container:
		return
	
	# Limpiar
	for child in buffs_container.get_children():
		child.queue_free()
	
	var gm = _get_game_manager()
	if not gm:
		return
	
	var buffs = gm.get_run_buffs()
	
	if buffs.is_empty():
		var no_buffs = Label.new()
		no_buffs.text = "(ninguna)"
		no_buffs.add_theme_font_size_override("font_size", 14)
		no_buffs.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		buffs_container.add_child(no_buffs)
		return
	
	# Agrupar buffos por personaje
	var buffs_by_char = {}
	for buff in buffs:
		var char_name = buff.get("character_name", "???")
		if not buffs_by_char.has(char_name):
			buffs_by_char[char_name] = []
		buffs_by_char[char_name].append(buff)
	
	# Mostrar resumen por personaje
	for char_name in buffs_by_char.keys():
		var char_buffs = buffs_by_char[char_name]
		var summary = _get_buff_summary(char_buffs)
		
		var buff_label = Label.new()
		buff_label.text = "%s: %s" % [char_name, summary]
		buff_label.add_theme_font_size_override("font_size", 12)
		buff_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		buffs_container.add_child(buff_label)

func _get_buff_summary(buffs: Array) -> String:
	"""Genera un resumen de buffos"""
	var totals = {"attack": 0, "defense": 0, "max_hp": 0, "rate": 0}
	for buff in buffs:
		var stat = buff.get("buff_type", "")
		var value = buff.get("value", 0)
		if totals.has(stat):
			totals[stat] += value
	
	var parts = []
	if totals["attack"] > 0: parts.append("+%d⚔️" % totals["attack"])
	if totals["defense"] > 0: parts.append("+%d🛡️" % totals["defense"])
	if totals["max_hp"] > 0: parts.append("+%d❤️" % totals["max_hp"])
	if totals["rate"] > 0: parts.append("+%d⚡" % totals["rate"])
	
	if parts.is_empty():
		return ""
	return " ".join(parts)

func _on_node_pressed(node_idx: int) -> void:
	"""Maneja click en un nodo"""
	print("🎯 Nodo ", node_idx + 1, " seleccionado")
	
	var gm = _get_game_manager()
	if gm:
		gm.start_node(node_idx)

func _on_back_pressed() -> void:
	"""Vuelve al menú principal"""
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
