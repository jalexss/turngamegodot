extends Control
class_name FloatingTextManager

# Variables
var text_pool: Array[Label] = []
var active_texts: Array[Label] = []

const PAUSE_DURATION = 1.0  # 1 segundo de pausa
const FADE_DURATION = 1.0   # 1 segundo de desvanecimiento
const FLOAT_HEIGHT = 80.0   # Altura del movimiento hacia arriba

func _ready() -> void:
	# Crear pool inicial de textos flotantes
	for i in range(10):
		var text = _create_floating_text()
		text_pool.append(text)

func _create_floating_text() -> Label:
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	
	# Configurar tamaño de fuente y colores usando theme overrides
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_color_override("outline_color", Color.BLACK)
	
	add_child(label)
	label.hide()
	return label

func spawn_floating_text(
	from_position: Vector2, 
	to_position: Vector2, 
	amount: int, 
	text_type: String = "damage",
	modifier_type: String = ""
) -> void:
	# Permitir amount == 0 para casos especiales (shield_blocked, etc)
	if amount < 0:
		return
	
	var label = _get_or_create_text()
	
	# Configurar texto y color según tipo
	_setup_text_style(label, amount, text_type, modifier_type)
	
	# Posicionar en la posición inicial (desde donde sufre el daño)
	label.global_position = from_position
	label.show()
	active_texts.append(label)
	
	# Iniciar animación
	_animate_text(label, from_position, to_position)

func _get_or_create_text() -> Label:
	if text_pool.size() > 0:
		return text_pool.pop_front()
	else:
		return _create_floating_text()

func _setup_text_style(
	label: Label, 
	amount: int, 
	text_type: String,
	modifier_type: String
) -> void:
	var color = Color.RED
	var text = str(amount)
	
	# Casos especiales (cuando amount es 0)
	if amount == 0 and modifier_type != "":
		match modifier_type:
			"shield_blocked":
				text = "🛡️ Blocked"
				color = Color.CYAN
			"poison":
				text = "☠️ Poison"
				color = Color.PURPLE
			"regeneration":
				text = "💚 Regen"
				color = Color.GREEN
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("outline_color", Color.BLACK)
		return
	
	match text_type:
		"damage":
			color = Color.RED
			text = "-" + str(amount)
		"heal":
			color = Color.GREEN
			text = "+" + str(amount)
		"shield":
			color = Color.CYAN
			text = "🛡️ " + str(amount)
	
	# Agregar modificador si existe
	if modifier_type != "":
		match modifier_type:
			"double_damage":
				text += " ⚡x2"
				color = Color.YELLOW
			"vulnerability":
				text += " 🎯"
				color = Color(1.0, 0.5, 0.0)  # Naranja
			"shield_blocked":
				text = "🛡️ Blocked"
				color = Color.CYAN
			"pressure":
				text = "💀 " + str(amount)
				color = Color.RED
			"poison":
				text += " ☠️"
				color = Color.PURPLE
			"regeneration":
				text += " 💚"
				color = Color.GREEN
	
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("outline_color", Color.BLACK)

func _animate_text(label: Label, from_pos: Vector2, to_pos: Vector2) -> void:
	# Primera fase: pausa de 1 segundo
	await get_tree().create_timer(PAUSE_DURATION).timeout
	
	# Segunda fase: movimiento y desvanecimiento de 1 segundo usando Tween
	var tween = create_tween()
	tween.set_parallel(true)  # Permitir animaciones paralelas
	
	# Animar posición (moverse hacia arriba ligeramente mientras se desvanece)
	tween.tween_property(label, "global_position", to_pos, FADE_DURATION)
	
	# Animar opacidad
	tween.tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	
	# Esperar a que termine la animación
	await tween.finished
	
	# Retornar al pool
	label.hide()
	label.modulate.a = 1.0  # Resetear alpha
	active_texts.erase(label)
	text_pool.append(label)

func clear_all() -> void:
	"""Limpia todos los textos activos"""
	for text in active_texts:
		text.hide()
		text_pool.append(text)
	active_texts.clear()
