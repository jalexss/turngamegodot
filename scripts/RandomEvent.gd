extends Control
## RandomEvent - Escena de evento aleatorio de supervivencia
## Puede ser: Recuperación, Tienda, Buffo gratis, o Oro aleatorio

enum EventType { HEAL, SHOP, FREE_BUFF, GOLD }

var event_type: EventType = EventType.HEAL
var selected_character = null
var free_buff: Dictionary = {}
var gold_reward: int = 0
var event_resolved: bool = false

# Referencias UI
var title_label: Label
var event_icon: Label
var description_label: Label
var content_container: Control
var action_button: Button
var continue_button: Button

func _ready() -> void:
	_roll_event()
	_create_ui()
	_display_event()
	print("❓ Evento aleatorio cargado: ", _get_event_name())

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _roll_event() -> void:
	"""Determina qué tipo de evento aleatorio ocurre"""
	var roll = randi() % 100
	
	if roll < 25:  # 25% curación
		event_type = EventType.HEAL
	elif roll < 45:  # 20% tienda
		event_type = EventType.SHOP
	elif roll < 70:  # 25% buffo gratis
		event_type = EventType.FREE_BUFF
		_roll_free_buff()
	else:  # 30% oro
		event_type = EventType.GOLD
		gold_reward = randi_range(25, 150)

func _roll_free_buff() -> void:
	"""Selecciona un buffo aleatorio para otorgar gratis"""
	var gm = _get_game_manager()
	if gm:
		var buffs = gm.get_random_shop_buffs(1)
		if buffs.size() > 0:
			free_buff = buffs[0]
		else:
			# Buffo por defecto
			free_buff = {
				"id": 0,
				"name": "Bendición",
				"description": "+3 a todos los stats",
				"stat": "attack",
				"value": 3,
				"icon": "✨"
			}

func _get_event_name() -> String:
	"""Retorna el nombre del tipo de evento"""
	match event_type:
		EventType.HEAL: return "Santuario de Curación"
		EventType.SHOP: return "Mercader Errante"
		EventType.FREE_BUFF: return "Bendición Divina"
		EventType.GOLD: return "Tesoro Oculto"
		_: return "Evento Misterioso"

func _get_event_icon() -> String:
	"""Retorna el icono del evento"""
	match event_type:
		EventType.HEAL: return "💚"
		EventType.SHOP: return "🛒"
		EventType.FREE_BUFF: return "✨"
		EventType.GOLD: return "💰"
		_: return "❓"

func _get_event_description() -> String:
	"""Retorna la descripción del evento"""
	match event_type:
		EventType.HEAL:
			return "Has encontrado un santuario antiguo.\nSelecciona un personaje para curar el 50% de su HP."
		EventType.SHOP:
			return "Un mercader misterioso aparece ante ti.\n¡Aprovecha sus ofertas!"
		EventType.FREE_BUFF:
			var icon = free_buff.get("icon", "✨")
			var name_text = free_buff.get("name", "Bendición")
			var desc = free_buff.get("description", "")
			return "Los dioses te sonríen.\nRecibes: %s %s\n%s\n\nSelecciona quién recibirá este don." % [icon, name_text, desc]
		EventType.GOLD:
			var message = _get_gold_message()
			return "%s\n\n¡Obtuviste 🪙 %d oro!" % [message, gold_reward]
		_:
			return "Algo misterioso ocurre..."

func _get_gold_message() -> String:
	"""Retorna un mensaje basado en la cantidad de oro"""
	if gold_reward >= 120:
		return "¡Increíble! Has descubierto un tesoro legendario\nescondido durante siglos."
	elif gold_reward >= 80:
		return "¡Excelente hallazgo! Un cofre lleno\nde monedas de oro brillante."
	elif gold_reward >= 50:
		return "Has encontrado una bolsa de monedas\nolvidada por algún viajero."
	else:
		return "Encuentras algunas monedas esparcidas\nen el suelo."

func _create_ui() -> void:
	"""Crea la estructura de UI"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.1, 0.08, 0.12, 1)
	add_child(background)
	
	# Contenedor principal
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	center.add_child(main_vbox)
	
	# Título
	title_label = Label.new()
	title_label.text = "❓ EVENTO ALEATORIO"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)
	
	# Icono del evento
	event_icon = Label.new()
	event_icon.add_theme_font_size_override("font_size", 80)
	event_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(event_icon)
	
	# Descripción
	description_label = Label.new()
	description_label.add_theme_font_size_override("font_size", 20)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(description_label)
	
	# Contenedor de contenido específico
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_container)
	
	# Botones
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(buttons_hbox)
	
	action_button = Button.new()
	action_button.add_theme_font_size_override("font_size", 20)
	action_button.custom_minimum_size = Vector2(200, 50)
	action_button.pressed.connect(_on_action_pressed)
	buttons_hbox.add_child(action_button)
	
	continue_button = Button.new()
	continue_button.text = "Continuar →"
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.custom_minimum_size = Vector2(180, 50)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	buttons_hbox.add_child(continue_button)

func _display_event() -> void:
	"""Muestra el contenido del evento"""
	title_label.text = _get_event_icon() + " " + _get_event_name().to_upper()
	event_icon.text = _get_event_icon()
	description_label.text = _get_event_description()
	
	# Limpiar contenido anterior
	for child in content_container.get_children():
		child.queue_free()
	
	match event_type:
		EventType.HEAL:
			_display_heal_content()
			action_button.text = "💚 Curar"
			action_button.disabled = true
		EventType.SHOP:
			action_button.text = "🛒 Ir a la Tienda"
			action_button.disabled = false
		EventType.FREE_BUFF:
			_display_buff_content()
			action_button.text = "✨ Aplicar Bendición"
			action_button.disabled = true
		EventType.GOLD:
			action_button.text = "💰 Recoger Oro"
			action_button.disabled = false

func _display_heal_content() -> void:
	"""Muestra el contenido de curación"""
	var chars_hbox = HBoxContainer.new()
	chars_hbox.add_theme_constant_override("separation", 20)
	chars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_child(chars_hbox)
	
	var gm = _get_game_manager()
	if gm:
		var chars = gm.get_player_roster()
		for char_data in chars:
			var char_btn = _create_character_button(char_data, true)
			chars_hbox.add_child(char_btn)

func _display_buff_content() -> void:
	"""Muestra el contenido de buffo gratis"""
	var chars_hbox = HBoxContainer.new()
	chars_hbox.add_theme_constant_override("separation", 20)
	chars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_child(chars_hbox)
	
	var gm = _get_game_manager()
	if gm:
		var chars = gm.get_player_roster()
		for char_data in chars:
			var char_btn = _create_character_button(char_data, false)
			chars_hbox.add_child(char_btn)

func _create_character_button(char_data, show_heal: bool) -> Button:
	"""Crea un botón de personaje"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 180)
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
	portrait.custom_minimum_size = Vector2(80, 80)
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
	
	if show_heal:
		# HP y curación potencial
		var hp_label = Label.new()
		hp_label.text = "❤️ %d/%d" % [char_data.hp, char_data.max_hp]
		hp_label.add_theme_font_size_override("font_size", 12)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hp_label)
		
		var heal_amount = int(char_data.max_hp * 0.5)
		var actual_heal = min(heal_amount, char_data.max_hp - char_data.hp)
		
		var heal_label = Label.new()
		if actual_heal > 0:
			heal_label.text = "+%d HP" % actual_heal
			heal_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			heal_label.text = "HP Completo"
			heal_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		heal_label.add_theme_font_size_override("font_size", 11)
		heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(heal_label)
	else:
		# Stats actuales
		var stats_label = Label.new()
		stats_label.text = "ATK:%d DEF:%d" % [char_data.attack, char_data.defense]
		stats_label.add_theme_font_size_override("font_size", 10)
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_label)
	
	btn.pressed.connect(_on_character_selected.bind(char_data, btn))
	
	return btn

func _on_character_selected(char_data, btn: Button) -> void:
	"""Callback cuando se selecciona un personaje"""
	# Deseleccionar otros
	for child in content_container.get_children():
		if child is HBoxContainer:
			for c in child.get_children():
				if c is Button and c != btn:
					c.button_pressed = false
	
	selected_character = char_data
	action_button.disabled = false

func _on_action_pressed() -> void:
	"""Ejecuta la acción del evento"""
	if event_resolved:
		return
	
	var gm = _get_game_manager()
	
	match event_type:
		EventType.HEAL:
			if selected_character:
				var heal_amount = int(selected_character.max_hp * 0.5)
				var old_hp = selected_character.hp
				selected_character.hp = min(selected_character.hp + heal_amount, selected_character.max_hp)
				var actual_heal = selected_character.hp - old_hp
				
				description_label.text = "✅ %s recuperó %d HP!" % [selected_character.name, actual_heal]
				event_resolved = true
				
		EventType.SHOP:
			# Ir directamente a la tienda
			if gm:
				get_tree().change_scene_to_file("res://scenes/Shop.tscn")
			return
			
		EventType.FREE_BUFF:
			if selected_character and gm:
				var stat = free_buff.get("stat", "attack")
				var value = free_buff.get("value", 3)
				var buff_name = free_buff.get("name", "Bendición")
				
				gm.apply_buff_to_character(selected_character.id, stat, value, "Evento: " + buff_name)
				
				description_label.text = "✅ %s recibió %s!" % [selected_character.name, buff_name]
				event_resolved = true
				
		EventType.GOLD:
			if gm:
				gm.add_gold(gold_reward)
				description_label.text = "✅ ¡Obtuviste %d oro!" % gold_reward
				event_resolved = true
	
	if event_resolved:
		action_button.visible = false
		continue_button.visible = true
		
		# Limpiar contenido
		for child in content_container.get_children():
			child.queue_free()

func _on_continue_pressed() -> void:
	"""Continúa al mapa"""
	var gm = _get_game_manager()
	if gm:
		gm.on_event_completed()
