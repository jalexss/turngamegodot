extends Control
## Treasure - Escena de tesoro del roguelike
## Otorga oro al jugador

var gold_reward: int = 0
var reward_collected: bool = false

# Referencias UI
var title_label: Label
var treasure_icon: Label
var reward_label: Label
var continue_button: Button
var collect_button: Button

func _ready() -> void:
	_create_ui()
	_calculate_reward()
	print("💰 Nodo de tesoro cargado")

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _create_ui() -> void:
	"""Crea la estructura de UI del tesoro"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.15, 0.12, 0.05, 1)
	add_child(background)
	
	# Contenedor principal centrado
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 30)
	center.add_child(main_vbox)
	
	# Título
	title_label = Label.new()
	title_label.text = "💰 ¡TESORO ENCONTRADO!"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	main_vbox.add_child(title_label)
	
	# Icono de cofre
	treasure_icon = Label.new()
	treasure_icon.text = "🎁"
	treasure_icon.add_theme_font_size_override("font_size", 120)
	treasure_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(treasure_icon)
	
	# Recompensa
	reward_label = Label.new()
	reward_label.add_theme_font_size_override("font_size", 36)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	main_vbox.add_child(reward_label)
	
	# Botones
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(buttons_hbox)
	
	collect_button = Button.new()
	collect_button.text = "✨ Recoger Tesoro"
	collect_button.add_theme_font_size_override("font_size", 24)
	collect_button.custom_minimum_size = Vector2(250, 60)
	collect_button.pressed.connect(_on_collect_pressed)
	buttons_hbox.add_child(collect_button)
	
	continue_button = Button.new()
	continue_button.text = "Continuar →"
	continue_button.add_theme_font_size_override("font_size", 24)
	continue_button.custom_minimum_size = Vector2(200, 60)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	buttons_hbox.add_child(continue_button)

func _calculate_reward() -> void:
	"""Calcula la recompensa de oro"""
	var gm = _get_game_manager()
	if gm:
		var node = gm.get_current_node()
		gold_reward = node.get("gold_reward", randi_range(30, 60))
	else:
		gold_reward = randi_range(30, 60)
	
	reward_label.text = "🪙 %d oro" % gold_reward

func _on_collect_pressed() -> void:
	"""Recoge el tesoro"""
	if reward_collected:
		return
	
	reward_collected = true
	
	var gm = _get_game_manager()
	if gm:
		gm.add_gold(gold_reward)
	
	# Animación simple - cambiar textos
	title_label.text = "✅ ¡TESORO RECOGIDO!"
	treasure_icon.text = "💎"
	reward_label.text = "¡Obtuviste 🪙 %d oro!" % gold_reward
	
	collect_button.visible = false
	continue_button.visible = true
	
	print("💰 Tesoro recogido: ", gold_reward, " oro")

func _on_continue_pressed() -> void:
	"""Continúa al mapa"""
	var gm = _get_game_manager()
	if gm:
		gm.on_event_completed()
