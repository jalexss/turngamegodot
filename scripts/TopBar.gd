extends Control

# Referencias a nodos hijos
@onready var match_timer_label: Label = $Content/LeftSection/MatchTimer
@onready var pressure_timer_label: Label = $Content/LeftSection/PressureSection/PressureTimer
@onready var pressure_timer_bar: ProgressBar = $Content/LeftSection/PressureSection/PressureBar
@onready var combat_log_button: Button = $Content/CombatLogButton
@onready var menu_button: Button = $Content/MenuButton

# Nodos dinámicos para oro y buffos
var gold_label: Label = null
var buffs_container: HBoxContainer = null

# Variables de cronómetros
var match_timer: float = 0.0
var pressure_timer: float = 15.0
var pressure_timer_max: float = 15.0

# Señales para comunicarse con GameUI
signal combat_log_requested
signal menu_requested
signal pressure_attack_triggered

func _ready() -> void:
	"""Inicializa el TopBar"""
	print("🔧 TopBar inicializado")
	
	# Configurar textos iniciales
	_update_match_timer_display()
	_update_pressure_timer_display()
	
	# Conectar señales de botones
	if combat_log_button:
		combat_log_button.pressed.connect(_on_combat_log_button_pressed)
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	
	# Crear elementos de oro y buffos si estamos en roguelike
	_create_roguelike_ui()
	_connect_game_manager_signals()
	
	print("✅ TopBar configurado correctamente")

func _get_game_manager():
	"""Obtiene referencia segura al GameManager"""
	return get_node_or_null("/root/GameManager")

func _create_roguelike_ui() -> void:
	"""Crea elementos de UI específicos del roguelike (oro y buffos)"""
	var gm = _get_game_manager()
	if not gm or not gm.is_roguelike_mode():
		return
	
	# Buscar o crear contenedor para elementos de roguelike
	var content = get_node_or_null("Content")
	if not content:
		return
	
	# Crear separador
	var sep = VSeparator.new()
	sep.name = "RoguelikeSep"
	content.add_child(sep)
	content.move_child(sep, 2)  # Después de LeftSection
	
	# Crear label de oro
	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(gold_label)
	content.move_child(gold_label, 3)
	
	# Crear contenedor de buffos
	buffs_container = HBoxContainer.new()
	buffs_container.name = "BuffsContainer"
	buffs_container.add_theme_constant_override("separation", 8)
	buffs_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(buffs_container)
	content.move_child(buffs_container, 4)
	
	# Actualizar displays iniciales
	_update_gold_display()
	_update_buffs_display()

func _connect_game_manager_signals() -> void:
	"""Conecta señales del GameManager"""
	var gm = _get_game_manager()
	if not gm:
		return
	
	if gm.has_signal("gold_changed") and not gm.gold_changed.is_connected(_on_gold_changed):
		gm.gold_changed.connect(_on_gold_changed)
	
	if gm.has_signal("buffs_changed") and not gm.buffs_changed.is_connected(_on_buffs_changed):
		gm.buffs_changed.connect(_on_buffs_changed)

func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()

func _on_buffs_changed() -> void:
	_update_buffs_display()

func _update_gold_display() -> void:
	"""Actualiza el display de oro"""
	if not gold_label:
		return
	
	var gm = _get_game_manager()
	if gm:
		gold_label.text = "🪙 %d" % gm.get_gold()

func _update_buffs_display() -> void:
	"""Actualiza el display compacto de buffos"""
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
		return
	
	# Mostrar icono indicador de buffos activos
	var buff_indicator = Label.new()
	buff_indicator.text = "✨%d" % buffs.size()
	buff_indicator.add_theme_font_size_override("font_size", 14)
	buff_indicator.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	buff_indicator.tooltip_text = _get_buffs_tooltip(buffs)
	buffs_container.add_child(buff_indicator)

func _get_buffs_tooltip(buffs: Array) -> String:
	"""Genera tooltip con resumen de buffos"""
	var lines = ["=== Mejoras Activas ==="]
	
	var buffs_by_char = {}
	for buff in buffs:
		var char_name = buff.get("character_name", "???")
		if not buffs_by_char.has(char_name):
			buffs_by_char[char_name] = []
		buffs_by_char[char_name].append(buff)
	
	for char_name in buffs_by_char.keys():
		var char_buffs = buffs_by_char[char_name]
		var summary = _get_buff_summary_for_tooltip(char_buffs)
		lines.append("%s: %s" % [char_name, summary])
	
	return "\n".join(lines)

func _get_buff_summary_for_tooltip(buffs: Array) -> String:
	"""Genera resumen de buffos para tooltip"""
	var parts = []
	for buff in buffs:
		var stat = buff.get("buff_type", "")
		var value = buff.get("value", 0)
		var icon = ""
		match stat:
			"attack": icon = "⚔️"
			"defense": icon = "🛡️"
			"max_hp": icon = "❤️"
			"rate": icon = "⚡"
		if icon != "":
			parts.append("+%d%s" % [value, icon])
	return " ".join(parts)

func _process(delta: float) -> void:
	"""Actualiza los cronómetros cada frame"""
	_update_timers(delta)

func _update_timers(delta: float) -> void:
	"""Actualiza ambos cronómetros"""
	# Actualizar cronómetro de partida
	match_timer += delta
	_update_match_timer_display()
	
	# Actualizar cronómetro de presión
	if pressure_timer > 0:
		pressure_timer -= delta
		_update_pressure_timer_display()
		
		# Disparar ataque de presión cuando llegue a 0
		if pressure_timer <= 0:
			pressure_timer = pressure_timer_max  # Reiniciar
			pressure_attack_triggered.emit()

func _update_match_timer_display() -> void:
	"""Actualiza la visualización del cronómetro de partida"""
	if match_timer_label:
		var minutes = int(match_timer / 60)
		var seconds = int(match_timer) % 60
		match_timer_label.text = "⏱️ Partida: %02d:%02d" % [minutes, seconds]

func _update_pressure_timer_display() -> void:
	"""Actualiza la visualización del cronómetro de presión"""
	if pressure_timer_label:
		pressure_timer_label.text = "⚡ Presión: %ds" % int(max(0, pressure_timer))
	
	if pressure_timer_bar:
		var progress = (pressure_timer / pressure_timer_max) * 100.0
		pressure_timer_bar.value = max(0, progress)
		
		# Cambiar color según el tiempo restante
		if progress < 30:  # Menos de 30% = rojo intenso
			pressure_timer_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		elif progress < 60:  # Menos de 60% = amarillo
			pressure_timer_label.modulate = Color(1.0, 0.8, 0.4, 1.0)
		else:  # Más de 60% = normal
			pressure_timer_label.modulate = Color(1.0, 1.0, 0.5, 1.0)

# --- FUNCIONES PÚBLICAS PARA GAMEUI ---

func set_pressure_timer_duration(new_duration: float) -> void:
	"""Cambia la duración del cronómetro de presión"""
	pressure_timer_max = new_duration
	pressure_timer = new_duration
	print("⏱️ TopBar: Cronómetro de presión cambiado a ", new_duration, " segundos")

func reset_pressure_timer() -> void:
	"""Reinicia el cronómetro de presión"""
	pressure_timer = pressure_timer_max

func pause_timers() -> void:
	"""Pausa todos los cronómetros"""
	set_process(false)

func resume_timers() -> void:
	"""Reanuda todos los cronómetros"""
	set_process(true)

# --- CALLBACKS DE BOTONES ---

func _on_combat_log_button_pressed() -> void:
	"""Callback para el botón de log de combate"""
	print("📜 TopBar: Botón de log presionado")
	combat_log_requested.emit()

func _on_menu_button_pressed() -> void:
	"""Callback para el botón de menú"""
	print("☰ TopBar: Botón de menú presionado")
	menu_requested.emit()