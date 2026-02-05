extends Control
## Shop - Escena de tienda del roguelike
## Permite comprar buffos permanentes para los personajes

var shop_buffs: Array = []  # Buffos disponibles en esta tienda
var selected_buff: Dictionary = {}
var selected_character = null

# Referencias UI
var title_label: Label
var gold_label: Label
var buffs_container: VBoxContainer
var characters_container: HBoxContainer
var buy_button: Button
var continue_button: Button
var info_label: Label

func _ready() -> void:
	_create_ui()
	_load_shop_buffs()
	_update_gold_display()
	print("🛒 Tienda cargada")

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _create_ui() -> void:
	"""Crea la estructura de UI de la tienda"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.1, 0.08, 0.15, 1)
	add_child(background)
	
	# Contenedor principal
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.anchor_left = 0.05
	main_vbox.anchor_top = 0.05
	main_vbox.anchor_right = 0.95
	main_vbox.anchor_bottom = 0.95
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "🛒 TIENDA"
	title_label.add_theme_font_size_override("font_size", 36)
	header.add_child(title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	header.add_child(gold_label)
	
	# Separador
	var sep = HSeparator.new()
	main_vbox.add_child(sep)
	
	# Contenedor de 2 columnas
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(content_hbox)
	
	# Columna izquierda: Buffos disponibles
	var buffs_panel = _create_buffs_panel()
	buffs_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(buffs_panel)
	
	# Columna derecha: Selección de personaje
	var chars_panel = _create_characters_panel()
	chars_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(chars_panel)
	
	# Info y botones
	var bottom_panel = Panel.new()
	bottom_panel.custom_minimum_size = Vector2(0, 100)
	main_vbox.add_child(bottom_panel)
	
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_hbox.anchor_left = 0.02
	bottom_hbox.anchor_right = 0.98
	bottom_hbox.add_theme_constant_override("separation", 20)
	bottom_panel.add_child(bottom_hbox)
	
	info_label = Label.new()
	info_label.text = "Selecciona un objeto y un personaje"
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_hbox.add_child(info_label)
	
	buy_button = Button.new()
	buy_button.text = "💰 Comprar"
	buy_button.add_theme_font_size_override("font_size", 20)
	buy_button.custom_minimum_size = Vector2(150, 50)
	buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_hbox.add_child(buy_button)
	
	continue_button = Button.new()
	continue_button.text = "Continuar →"
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.custom_minimum_size = Vector2(150, 50)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_hbox.add_child(continue_button)

func _create_buffs_panel() -> Control:
	"""Crea el panel de buffos disponibles"""
	var panel = Panel.new()
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.anchor_left = 0.02
	vbox.anchor_top = 0.02
	vbox.anchor_right = 0.98
	vbox.anchor_bottom = 0.98
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "📦 Objetos Disponibles"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	buffs_container = VBoxContainer.new()
	buffs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buffs_container.add_theme_constant_override("separation", 8)
	scroll.add_child(buffs_container)
	
	return panel

func _create_characters_panel() -> Control:
	"""Crea el panel de selección de personaje"""
	var panel = Panel.new()
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.anchor_left = 0.02
	vbox.anchor_top = 0.02
	vbox.anchor_right = 0.98
	vbox.anchor_bottom = 0.98
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "👤 Seleccionar Personaje"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	
	characters_container = HBoxContainer.new()
	characters_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	characters_container.add_theme_constant_override("separation", 15)
	vbox.add_child(characters_container)
	
	# Cargar personajes del roster
	var gm = _get_game_manager()
	if gm:
		var chars = gm.get_player_roster()
		for char_data in chars:
			var char_btn = _create_character_button(char_data)
			characters_container.add_child(char_btn)
	
	return panel

func _create_character_button(char_data) -> Button:
	"""Crea un botón de selección de personaje"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 200)
	btn.toggle_mode = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.anchor_left = 0.05
	vbox.anchor_top = 0.05
	vbox.anchor_right = 0.95
	vbox.anchor_bottom = 0.95
	vbox.add_theme_constant_override("separation", 5)
	btn.add_child(vbox)
	
	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(100, 100)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if char_data.portrait:
		portrait.texture = char_data.portrait
	vbox.add_child(portrait)
	
	# Nombre
	var name_label = Label.new()
	name_label.text = char_data.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "ATK:%d DEF:%d" % [char_data.attack, char_data.defense]
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	
	btn.pressed.connect(_on_character_selected.bind(char_data, btn))
	
	return btn

func _load_shop_buffs() -> void:
	"""Carga buffos aleatorios para esta tienda"""
	var gm = _get_game_manager()
	if gm:
		shop_buffs = gm.get_random_shop_buffs(4)
	
	_display_buffs()

func _display_buffs() -> void:
	"""Muestra los buffos en la UI"""
	# Limpiar contenedor
	for child in buffs_container.get_children():
		child.queue_free()
	
	var gm = _get_game_manager()
	
	for buff in shop_buffs:
		var buff_btn = Button.new()
		buff_btn.custom_minimum_size = Vector2(0, 70)
		buff_btn.toggle_mode = true
		
		# Verificar si ya fue comprado
		var is_purchased = false
		if gm:
			is_purchased = gm.is_buff_purchased_in_current_shop(buff.get("id", -1))
		
		var icon = buff.get("icon", "📦")
		var name_text = buff.get("name", "Objeto")
		var desc = buff.get("description", "")
		var cost = buff.get("cost", 0)
		
		if is_purchased:
			buff_btn.text = "%s %s\n%s\n✅ COMPRADO" % [icon, name_text, desc]
			buff_btn.disabled = true
			buff_btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			buff_btn.text = "%s %s\n%s\n💰 %d oro" % [icon, name_text, desc, cost]
		
		buff_btn.add_theme_font_size_override("font_size", 14)
		buff_btn.pressed.connect(_on_buff_selected.bind(buff, buff_btn))
		
		buffs_container.add_child(buff_btn)

func _on_buff_selected(buff: Dictionary, btn: Button) -> void:
	"""Callback cuando se selecciona un buff"""
	# Deseleccionar otros buffos
	for child in buffs_container.get_children():
		if child is Button and child != btn:
			child.button_pressed = false
	
	selected_buff = buff
	_update_buy_button()
	
	var icon = buff.get("icon", "📦")
	var name_text = buff.get("name", "Objeto")
	info_label.text = "Seleccionado: %s %s" % [icon, name_text]

func _on_character_selected(char_data, btn: Button) -> void:
	"""Callback cuando se selecciona un personaje"""
	# Deseleccionar otros personajes
	for child in characters_container.get_children():
		if child is Button and child != btn:
			child.button_pressed = false
	
	selected_character = char_data
	_update_buy_button()
	
	if not selected_buff.is_empty():
		info_label.text = "Aplicar a: " + char_data.name

func _update_buy_button() -> void:
	"""Actualiza el estado del botón comprar"""
	var gm = _get_game_manager()
	if not gm:
		buy_button.disabled = true
		return
	
	var has_selection = not selected_buff.is_empty() and selected_character != null
	var can_afford = gm.get_gold() >= selected_buff.get("cost", 999999)
	
	buy_button.disabled = not (has_selection and can_afford)
	
	if has_selection and not can_afford:
		info_label.text = "❌ Oro insuficiente"

func _update_gold_display() -> void:
	"""Actualiza el display de oro"""
	var gm = _get_game_manager()
	if gm:
		gold_label.text = "🪙 %d oro" % gm.get_gold()

func _on_buy_pressed() -> void:
	"""Compra el buff seleccionado"""
	var gm = _get_game_manager()
	if not gm:
		return
	
	var cost = selected_buff.get("cost", 0)
	
	if gm.spend_gold(cost):
		# Aplicar buff al personaje
		var stat = selected_buff.get("stat", "attack")
		var value = selected_buff.get("value", 0)
		var buff_name = selected_buff.get("name", "Objeto")
		
		gm.apply_buff_to_character(selected_character.id, stat, value, "Tienda: " + buff_name)
		gm.mark_buff_purchased_in_current_shop(selected_buff.get("id", -1))
		
		# Actualizar UI
		_update_gold_display()
		_display_buffs()
		_refresh_characters_display()
		
		# Resetear selección
		selected_buff = {}
		selected_character = null
		buy_button.disabled = true
		info_label.text = "✅ ¡Compra exitosa!"
	else:
		info_label.text = "❌ Oro insuficiente"

func _refresh_characters_display() -> void:
	"""Refresca el display de personajes"""
	# Limpiar y recrear
	for child in characters_container.get_children():
		child.queue_free()
	
	var gm = _get_game_manager()
	if gm:
		var chars = gm.get_player_roster()
		for char_data in chars:
			var char_btn = _create_character_button(char_data)
			characters_container.add_child(char_btn)

func _on_continue_pressed() -> void:
	"""Continúa al mapa"""
	var gm = _get_game_manager()
	if gm:
		gm.on_event_completed()
