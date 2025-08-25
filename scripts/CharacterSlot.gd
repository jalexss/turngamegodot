extends Control

# Señal que se emitirá cuando se haga clic en este personaje.
# Enviará sus propios datos para que el juego sepa quién fue clickeado.
signal character_clicked(character_data)

# Nodos de la escena
@onready var name_label = $VBoxContainer/NameLabel
@onready var health_bar = $VBoxContainer/HealthBar
@onready var portrait = $Portrait
@onready var hover_effect = $HoverEffect

var character_data: CharacterData
var is_targeting_highlight: bool = false
var is_dead: bool = false
var action_previews: Array = []  # Acciones enemigas pendientes

func _ready():
	# Conectar las señales del ratón a nuestras funciones
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)  # ¡Esta línea faltaba!
	
	# Ocultar el efecto de hover al inicio
	hover_effect.visible = false

# Función pública para que GameUI nos envíe los datos del personaje
func set_character_data(data: CharacterData):
	character_data = data
	
	# Actualizar la UI con los datos recibidos
	# NO actualizar name_label.text aquí para preservar las acciones
	# _update_action_display() se encargará del nombre + acciones
	health_bar.max_value = character_data.max_hp
	health_bar.value = character_data.hp
	
	# ¡Aquí está la clave para que el sprite aparezca!
	if character_data.portrait:
		portrait.texture = character_data.portrait
	else:
		portrait.texture = null # Limpiar si no hay retrato
	
	# Actualizar display de acciones (incluye el nombre)
	_update_action_display()
	
	# Verificar si está muerto
	if character_data.hp <= 0:
		set_dead_state(true)

# --- MANEJO DE INTERACTIVIDAD ---

# Se llama cuando el ratón entra en el área del Control
func _on_mouse_entered():
	if not is_targeting_highlight:
		hover_effect.visible = true
		hover_effect.modulate = Color.WHITE

# Se llama cuando el ratón sale del área
func _on_mouse_exited():
	if not is_targeting_highlight:
		hover_effect.visible = false

# Se llama para cualquier evento de input dentro del área del Control
func _on_gui_input(event: InputEvent):
	# Comprobar si el evento es un clic izquierdo del ratón
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Emitir la señal con nuestros datos
		emit_signal("character_clicked", character_data)

# --- SISTEMA DE TARGETING ---
func set_targeting_highlight(enabled: bool) -> void:
	"""Activa/desactiva el resaltado de targeting"""
	is_targeting_highlight = enabled
	
	if enabled:
		# Mostrar resaltado de targeting (diferente al hover)
		hover_effect.visible = true
		hover_effect.modulate = Color.YELLOW  # Color dorado para targeting
	else:
		# Solo ocultar si no hay hover normal
		if not _is_mouse_over():
			hover_effect.visible = false
			hover_effect.modulate = Color.WHITE

func set_targeting_hover(enabled: bool) -> void:
	"""Activa/desactiva el hover durante targeting"""
	if enabled:
		# Hover más intenso durante targeting
		hover_effect.visible = true
		hover_effect.modulate = Color.ORANGE  # Color naranja para hover de targeting

	else:
		# Volver al resaltado normal de targeting
		if is_targeting_highlight:
			hover_effect.modulate = Color.YELLOW
		else:
			hover_effect.visible = false
			hover_effect.modulate = Color.WHITE

func _is_mouse_over() -> bool:
	"""Verifica si el mouse está sobre este slot"""
	var mouse_pos = get_global_mouse_position()
	var rect = get_global_rect()
	return rect.has_point(mouse_pos)

# --- SISTEMA DE MUERTE ---
func set_dead_state(dead: bool) -> void:
	"""Marca el personaje como muerto o vivo"""
	is_dead = dead
	
	if dead:
		# Efecto visual de muerte
		portrait.modulate = Color(0.3, 0.3, 0.3, 0.7)  # Gris y semi-transparente
		name_label.modulate = Color.RED
		health_bar.modulate = Color.RED
		
		# Quitar cualquier highlight
		hover_effect.visible = false
		is_targeting_highlight = false
		
		# Limpiar acciones pendientes (los muertos no actúan)
		action_previews.clear()
		_update_action_display()
	else:
		# Restaurar colores normales
		portrait.modulate = Color(1, 1, 1, 0.666667)  # Color original
		name_label.modulate = Color.WHITE
		health_bar.modulate = Color.WHITE

# --- SISTEMA DE PREVIEW DE ACCIONES ---
func show_action_previews(actions: Array) -> void:
	"""Muestra las acciones que este enemigo va a realizar"""
	action_previews = actions.duplicate()
	_update_action_display()

func remove_action_preview(action: Dictionary) -> void:
	"""Remueve una acción específica del preview"""
	for i in range(action_previews.size()):
		if action_previews[i] == action:
			action_previews.remove_at(i)
			break
	_update_action_display()

func clear_action_previews() -> void:
	"""Limpia todas las acciones del preview"""
	action_previews.clear()
	_update_action_display()

func _update_action_display() -> void:
	"""Actualiza la visualización de las acciones pendientes"""
	if not character_data:
		# Si no hay character_data, limpiar el label
		name_label.text = ""
		return
	
	# Construir texto de acciones
	var action_text = ""
	for i in range(action_previews.size()):
		var action = action_previews[i]
		var action_str = ""
		
		match action.type:
			"ATTACK":
				action_str = "⚔️ " + str(action.value)
			"HEAL":
				action_str = "💚 " + str(action.value)
			"DEFEND":
				action_str = "🛡️ " + str(action.value)
			_:
				action_str = action.type + " " + str(action.value)
		
		action_text += action_str
		if i < action_previews.size() - 1:
			action_text += "\n"
	
	# Actualizar el nombre del personaje para incluir las acciones
	if action_text != "":
		name_label.text = character_data.name + "\n" + action_text
	else:
		name_label.text = character_data.name
	
	print("🎯 Actualizado display para ", character_data.name, " con ", action_previews.size(), " acciones")
