extends Control
## CharacterSelectModal - Modal para seleccionar personajes antes de iniciar supervivencia
## Permite seleccionar hasta 3 personajes jugables

signal selection_confirmed(characters: Array)
signal modal_closed

const MAX_CHARACTERS = 3

# UI References
var background: ColorRect
var modal_panel: Panel
var title_label: Label
var close_btn: Button
var character_grid: GridContainer
var selected_label: Label
var confirm_btn: Button

# Estado
var selected_characters: Array = []  # Array de CharacterData
var character_slots: Array = []  # Referencias a los slots UI

func _ready() -> void:
	_create_ui()
	_load_characters()
	visible = false

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _create_ui() -> void:
	"""Crea la estructura de UI del modal"""
	# Configurar el control principal
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Fondo semi-transparente
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.gui_input.connect(_on_background_input)
	add_child(background)
	
	# Panel principal del modal
	modal_panel = Panel.new()
	modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	modal_panel.custom_minimum_size = Vector2(900, 600)
	modal_panel.position = -modal_panel.custom_minimum_size / 2
	add_child(modal_panel)
	
	# Contenedor principal
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.anchor_left = 0.02
	main_vbox.anchor_top = 0.02
	main_vbox.anchor_right = 0.98
	main_vbox.anchor_bottom = 0.98
	main_vbox.add_theme_constant_override("separation", 15)
	modal_panel.add_child(main_vbox)
	
	# Header con título y botón cerrar
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Selecciona tus Personajes (máx. 3)"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)
	
	# Separador
	var separator = HSeparator.new()
	main_vbox.add_child(separator)
	
	# ScrollContainer para la grid de personajes
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	# Grid de personajes
	character_grid = GridContainer.new()
	character_grid.columns = 3
	character_grid.add_theme_constant_override("h_separation", 20)
	character_grid.add_theme_constant_override("v_separation", 20)
	character_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(character_grid)
	
	# Footer con contador y botón confirmar
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	main_vbox.add_child(footer)
	
	selected_label = Label.new()
	selected_label.text = "Seleccionados: 0 / 3"
	selected_label.add_theme_font_size_override("font_size", 20)
	selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(selected_label)
	
	confirm_btn = Button.new()
	confirm_btn.text = "🎮 Iniciar Partida"
	confirm_btn.add_theme_font_size_override("font_size", 22)
	confirm_btn.custom_minimum_size = Vector2(200, 50)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm_pressed)
	footer.add_child(confirm_btn)

func _load_characters() -> void:
	"""Carga los personajes jugables desbloqueados desde GameManager"""
	var gm = _get_game_manager()
	if not gm:
		print("❌ GameManager no disponible")
		return
	
	var pdm = get_tree().root.get_node_or_null("PlayerDataManager")
	if not pdm:
		print("❌ PlayerDataManager no disponible")
		return

	# Wait for data if not loaded yet
	if not pdm.is_loaded():
		print("⏳ Esperando carga de datos del jugador...")
		var loading_label = Label.new()
		loading_label.name = "LoadingLabel"
		loading_label.text = "Cargando personajes..."
		loading_label.add_theme_font_size_override("font_size", 18)
		loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		character_grid.add_child(loading_label)
		await pdm.characters_loaded
		# Remove loading label
		if is_instance_valid(loading_label):
			loading_label.queue_free()

	var unlocked_ids: Array = pdm.get_unlocked_character_ids()
	print("📋 IDs desbloqueados: ", unlocked_ids)
	
	var playable_chars = gm.get_playable_characters()
	var filtered: Array = []
	for char_def in playable_chars:
		if char_def.get("id") in unlocked_ids:
			filtered.append(char_def)
	
	print("📋 Personajes desbloqueados para selección: ", filtered.size())
	
	if filtered.is_empty():
		var msg = Label.new()
		msg.text = "No tienes personajes desbloqueados.\nUsa el Gacha para obtenerlos."
		msg.add_theme_font_size_override("font_size", 18)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		character_grid.add_child(msg)
		return
	
	for char_def in filtered:
		_create_character_slot(char_def)

func _create_character_slot(char_def: Dictionary) -> void:
	"""Crea un slot visual para un personaje"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(250, 280)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Contenedor vertical dentro del slot
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.anchor_left = 0.05
	vbox.anchor_top = 0.05
	vbox.anchor_right = 0.95
	vbox.anchor_bottom = 0.95
	vbox.add_theme_constant_override("separation", 10)
	slot.add_child(vbox)
	
	# Retrato del personaje
	var portrait_container = CenterContainer.new()
	portrait_container.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(portrait_container)
	
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var portrait_path = char_def.get("portrait", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	
	portrait_container.add_child(portrait)
	
	# Nombre del personaje
	var name_label = Label.new()
	name_label.text = char_def.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Rol del personaje
	var role_label = Label.new()
	role_label.text = char_def.get("role", "")
	role_label.add_theme_font_size_override("font_size", 14)
	role_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(role_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "HP: %d | ATK: %d | DEF: %d" % [
		char_def.get("hp", 0),
		char_def.get("attack", 0),
		char_def.get("defense", 0)
	]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	
	# Indicador de selección (checkbox visual)
	var select_indicator = Label.new()
	select_indicator.name = "SelectIndicator"
	select_indicator.text = "☐ Seleccionar"
	select_indicator.add_theme_font_size_override("font_size", 16)
	select_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(select_indicator)
	
	# Guardar referencia al char_def en el slot
	slot.set_meta("char_def", char_def)
	slot.set_meta("selected", false)
	slot.gui_input.connect(_on_slot_input.bind(slot))
	
	character_grid.add_child(slot)
	character_slots.append(slot)

func _on_slot_input(event: InputEvent, slot: Panel) -> void:
	"""Maneja clicks en un slot de personaje"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_character_selection(slot)

func _toggle_character_selection(slot: Panel) -> void:
	"""Alterna la selección de un personaje"""
	var is_selected = slot.get_meta("selected", false)
	var char_def = slot.get_meta("char_def")
	var select_indicator = slot.get_node("VBoxContainer/SelectIndicator") as Label
	
	if is_selected:
		# Deseleccionar
		slot.set_meta("selected", false)
		select_indicator.text = "☐ Seleccionar"
		slot.modulate = Color.WHITE
		
		# Remover de la lista
		for i in range(selected_characters.size()):
			if selected_characters[i].id == char_def.get("id"):
				selected_characters.remove_at(i)
				break
	else:
		# Verificar límite
		if selected_characters.size() >= MAX_CHARACTERS:
			print("⚠️ Máximo de personajes alcanzado")
			return
		
		# Seleccionar
		slot.set_meta("selected", true)
		select_indicator.text = "☑ Seleccionado"
		slot.modulate = Color(0.8, 1.0, 0.8)
		
		# Crear CharacterData y añadir a la lista
		var gm = _get_game_manager()
		if gm:
			var char_data = gm.create_character_data(char_def)
			selected_characters.append(char_data)
	
	_update_selection_ui()

func _update_selection_ui() -> void:
	"""Actualiza la UI según la selección actual"""
	selected_label.text = "Seleccionados: %d / %d" % [selected_characters.size(), MAX_CHARACTERS]
	confirm_btn.disabled = selected_characters.is_empty()
	
	if selected_characters.size() >= MAX_CHARACTERS:
		selected_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		selected_label.remove_theme_color_override("font_color")

func _on_background_input(event: InputEvent) -> void:
	"""Cierra el modal al hacer click en el fondo"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Solo cerrar si el click fue en el background, no en el panel
		var local_pos = background.get_local_mouse_position()
		var panel_rect = Rect2(modal_panel.position + modal_panel.custom_minimum_size / 2 + Vector2(450, 300), modal_panel.custom_minimum_size)
		if not panel_rect.has_point(local_pos):
			_close_modal()

func _on_close_pressed() -> void:
	"""Cierra el modal"""
	_close_modal()

func _on_confirm_pressed() -> void:
	"""Confirma la selección y emite señal"""
	if selected_characters.is_empty():
		return
	
	print("✅ Confirmando selección de ", selected_characters.size(), " personajes")
	selection_confirmed.emit(selected_characters.duplicate())
	hide()

func _close_modal() -> void:
	"""Cierra el modal sin selección"""
	modal_closed.emit()
	hide()

func show_modal() -> void:
	"""Muestra el modal y resetea la selección"""
	# Resetear selección
	selected_characters.clear()
	for slot in character_slots:
		slot.set_meta("selected", false)
		slot.modulate = Color.WHITE
		var indicator = slot.get_node_or_null("VBoxContainer/SelectIndicator")
		if indicator:
			indicator.text = "☐ Seleccionar"
	
	_update_selection_ui()
	visible = true

func _input(event: InputEvent) -> void:
	"""Maneja input global (ESC para cerrar)"""
	if visible and event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()
