extends Control

# Referencias a nodos hijos
@onready var match_timer_label: Label = $Content/LeftSection/MatchTimer
@onready var pressure_timer_label: Label = $Content/LeftSection/PressureSection/PressureTimer
@onready var pressure_timer_bar: ProgressBar = $Content/LeftSection/PressureSection/PressureBar
@onready var combat_log_button: Button = $Content/CombatLogButton
@onready var menu_button: Button = $Content/MenuButton

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
	
	print("✅ TopBar configurado correctamente")

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