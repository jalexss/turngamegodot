extends Control
## Rest - Escena de descanso/recuperación de supervivencia
## Permite curar a un personaje

var selected_character = null
var heal_percentage: float = 0.4  # 40% de HP máximo

# Referencias UI
var title_label: Label
var characters_container: HBoxContainer
var rest_button: Button
var continue_button: Button
var info_label: Label

func _ready() -> void:
	_create_ui()
	print("🏕️ Área de descanso cargada")

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _create_ui() -> void:
	"""Crea la estructura de UI del descanso"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.12, 0.08, 1)
	add_child(background)
	
	# Contenedor principal
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.anchor_left = 0.1
	main_vbox.anchor_top = 0.1
	main_vbox.anchor_right = 0.9
	main_vbox.anchor_bottom = 0.9
	main_vbox.add_theme_constant_override("separation", 30)
	add_child(main_vbox)
	
	# Título
	title_label = Label.new()
	title_label.text = "🏕️ ÁREA DE DESCANSO"
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)
	
	# Descripción
	var desc_label = Label.new()
	desc_label.text = "Selecciona un personaje para restaurar el 40% de su HP máximo"
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	main_vbox.add_child(desc_label)
	
	# Separador
	var sep = HSeparator.new()
	main_vbox.add_child(sep)
	
	# Contenedor de personajes centrado
	var center = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(center)
	
	characters_container = HBoxContainer.new()
	characters_container.add_theme_constant_override("separation", 30)
	center.add_child(characters_container)
	
	# Cargar personajes
	_load_characters()
	
	# Panel inferior
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
	info_label.text = "Selecciona un personaje para descansar"
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_hbox.add_child(info_label)
	
	rest_button = Button.new()
	rest_button.text = "🔥 Descansar"
	rest_button.add_theme_font_size_override("font_size", 20)
	rest_button.custom_minimum_size = Vector2(180, 50)
	rest_button.disabled = true
	rest_button.pressed.connect(_on_rest_pressed)
	rest_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_hbox.add_child(rest_button)
	
	continue_button = Button.new()
	continue_button.text = "Continuar →"
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.custom_minimum_size = Vector2(150, 50)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_hbox.add_child(continue_button)

func _load_characters() -> void:
	"""Carga los personajes del roster"""
	var gm = _get_game_manager()
	if not gm:
		return
	
	var chars = gm.get_player_roster()
	for char_data in chars:
		var char_panel = _create_character_panel(char_data)
		characters_container.add_child(char_panel)

func _create_character_panel(char_data) -> Button:
	"""Crea un panel de personaje seleccionable"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(180, 280)
	btn.toggle_mode = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.anchor_left = 0.05
	vbox.anchor_top = 0.05
	vbox.anchor_right = 0.95
	vbox.anchor_bottom = 0.95
	vbox.add_theme_constant_override("separation", 10)
	btn.add_child(vbox)
	
	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if char_data.portrait:
		portrait.texture = char_data.portrait
	vbox.add_child(portrait)
	
	# Nombre
	var name_label = Label.new()
	name_label.text = char_data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# HP actual
	var hp_label = Label.new()
	hp_label.text = "❤️ %d / %d" % [char_data.hp, char_data.max_hp]
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Color según HP
	var hp_ratio = float(char_data.hp) / float(char_data.max_hp)
	if hp_ratio < 0.3:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif hp_ratio < 0.6:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	vbox.add_child(hp_label)
	
	# Curación potencial
	var heal_amount = int(char_data.max_hp * heal_percentage)
	var new_hp = min(char_data.hp + heal_amount, char_data.max_hp)
	var actual_heal = new_hp - char_data.hp
	
	var heal_label = Label.new()
	if actual_heal > 0:
		heal_label.text = "+%d HP" % actual_heal
		heal_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		heal_label.text = "HP Completo"
		heal_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	heal_label.add_theme_font_size_override("font_size", 14)
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heal_label)
	
	btn.pressed.connect(_on_character_selected.bind(char_data, btn))
	
	return btn

func _on_character_selected(char_data, btn: Button) -> void:
	"""Callback cuando se selecciona un personaje"""
	# Deseleccionar otros
	for child in characters_container.get_children():
		if child is Button and child != btn:
			child.button_pressed = false
	
	selected_character = char_data
	
	var heal_amount = int(char_data.max_hp * heal_percentage)
	var new_hp = min(char_data.hp + heal_amount, char_data.max_hp)
	var actual_heal = new_hp - char_data.hp
	
	if actual_heal > 0:
		info_label.text = "%s recuperará %d HP" % [char_data.name, actual_heal]
		rest_button.disabled = false
	else:
		info_label.text = "%s ya tiene HP completo" % char_data.name
		rest_button.disabled = true

func _on_rest_pressed() -> void:
	"""Aplica la curación al personaje seleccionado"""
	if not selected_character:
		return
	
	var heal_amount = int(selected_character.max_hp * heal_percentage)
	var old_hp = selected_character.hp
	selected_character.hp = min(selected_character.hp + heal_amount, selected_character.max_hp)
	var actual_heal = selected_character.hp - old_hp
	
	print("🏕️ ", selected_character.name, " recuperó ", actual_heal, " HP")
	
	info_label.text = "✅ %s recuperó %d HP (%d → %d)" % [selected_character.name, actual_heal, old_hp, selected_character.hp]
	rest_button.disabled = true
	rest_button.text = "✅ Descansado"
	
	# Refrescar display
	_refresh_characters()

func _refresh_characters() -> void:
	"""Refresca el display de personajes"""
	for child in characters_container.get_children():
		child.queue_free()
	
	selected_character = null
	_load_characters()

func _on_continue_pressed() -> void:
	"""Continúa al mapa"""
	var gm = _get_game_manager()
	if gm:
		gm.on_event_completed()
