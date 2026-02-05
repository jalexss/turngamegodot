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
var active_effects: Array = []   # Efectos de estado activos

func _ready():
	print("DEBUG: CharacterSlot._ready() - Verificando nodos...")
	print("DEBUG: name_label: ", name_label)
	print("DEBUG: health_bar: ", health_bar)
	print("DEBUG: portrait: ", portrait)
	print("DEBUG: hover_effect: ", hover_effect)
	
	# Conectar las señales del ratón a nuestras funciones
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)  # ¡Esta línea faltaba!
	
	# Ocultar el efecto de hover al inicio
	if hover_effect:
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
	print("DEBUG: CharacterSlot - Configurando portrait para ", character_data.name)
	print("DEBUG: portrait texture: ", character_data.portrait)
	print("DEBUG: sprite_path: ", character_data.sprite_path)
	
	if character_data.portrait:
		portrait.texture = character_data.portrait
		print("DEBUG: Portrait asignado exitosamente")
	else:
		portrait.texture = null # Limpiar si no hay retrato
		print("DEBUG: No hay portrait - texture = null")
	
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

# --- SISTEMA DE EFECTOS DE ESTADO ---
func update_status_effects() -> void:
	"""Actualiza los efectos de estado desde el EffectManager"""
	if not character_data:
		return
	
	# Obtener referencia al Game node y luego al EffectManager
	var game_ui = get_parent().get_parent()  # Asumiendo estructura: Game -> GameUI -> CharacterSlot
	if not game_ui:
		return
	
	var game_node = game_ui.get_parent()
	if not game_node or not game_node.has_method("get_effect_manager"):
		return
	
	var effect_manager = game_node.get_effect_manager()
	if not effect_manager:
		return
	
	# Obtener efectos activos del personaje
	active_effects = effect_manager.get_character_effects(character_data)
	_update_action_display()

func get_status_effects_text() -> String:
	"""Retorna el texto de los efectos de estado activos"""
	if active_effects.is_empty():
		return ""
	
	var effects_text = ""
	for i in range(active_effects.size()):
		var effect = active_effects[i]
		if effect and effect.has_method("get_display_text"):
			effects_text += effect.get_display_text()
			if i < active_effects.size() - 1:
				effects_text += "\n"
	
	return effects_text

func get_buff_icons_compact() -> String:
	"""Retorna los iconos de buffos en formato compacto"""
	if active_effects.is_empty():
		return ""
	
	var buffs_line = ""
	var debuffs_line = ""
	
	for effect in active_effects:
		if not effect:
			continue
		
		var icon_with_duration = effect.icon + str(effect.duration)
		
		# Separar buffos de debuffs
		if _is_debuff(effect):
			debuffs_line += icon_with_duration + " "
		else:
			buffs_line += icon_with_duration + " "
	
	var result = ""
	if buffs_line != "":
		result += "✨" + buffs_line.strip_edges()
	if debuffs_line != "":
		if result != "":
			result += "\n"
		result += "⚠️" + debuffs_line.strip_edges()
	
	return result

func _is_debuff(effect) -> bool:
	"""Determina si un efecto es negativo (debuff)"""
	if not effect:
		return false
	
	match effect.effect_type:
		StatusEffect.EffectType.DEBUFF_ATTACK, StatusEffect.EffectType.DEBUFF_DEFENSE, \
		StatusEffect.EffectType.DEBUFF_HP, StatusEffect.EffectType.STUN, \
		StatusEffect.EffectType.POISON, StatusEffect.EffectType.VULNERABILITY, \
		StatusEffect.EffectType.WEAKNESS, StatusEffect.EffectType.ENERGY_DRAIN, \
		StatusEffect.EffectType.CARD_BLOCK, StatusEffect.EffectType.HEAL_BLOCK:
			return true
		_:
			return false

func _update_action_display() -> void:
	"""Actualiza la visualización de las acciones pendientes y efectos de estado"""
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
			"DEBUFF":
				action_str = "⬇️ " + str(action.value)
			_:
				action_str = action.type + " " + str(action.value)
		
		action_text += action_str
		if i < action_previews.size() - 1:
			action_text += " "
	
	# Construir texto de efectos de estado (formato compacto)
	var effects_text = get_buff_icons_compact()
	
	# Combinar nombre, acciones y efectos
	var display_text = character_data.name
	
	# Mostrar stats de defensa temporal si hay efectos activos
	var defense_bonus = _get_defense_bonus_from_effects()
	if defense_bonus > 0:
		display_text += " [🛡️+" + str(defense_bonus) + "]"
	
	if action_text != "":
		display_text += "\n" + action_text
	
	if effects_text != "":
		display_text += "\n" + effects_text
	
	name_label.text = display_text
	
	# Cambiar color si tiene debuffs activos
	_update_name_color()
	
	print("🎯 Actualizado display para ", character_data.name, " con ", action_previews.size(), " acciones y ", active_effects.size(), " efectos")

func _get_defense_bonus_from_effects() -> int:
	"""Calcula el bonus de defensa de efectos activos"""
	var bonus = 0
	for effect in active_effects:
		if effect and effect.effect_type == StatusEffect.EffectType.BUFF_DEFENSE:
			bonus += effect.value
	return bonus

func _update_name_color() -> void:
	"""Actualiza el color del nombre según el estado del personaje"""
	if is_dead:
		name_label.modulate = Color.RED
		return
	
	var has_buffs = false
	var has_debuffs = false
	
	for effect in active_effects:
		if _is_debuff(effect):
			has_debuffs = true
		else:
			has_buffs = true
	
	if has_debuffs and has_buffs:
		name_label.modulate = Color.YELLOW  # Mezcla
	elif has_debuffs:
		name_label.modulate = Color(1.0, 0.6, 0.6)  # Rojizo para debuffs
	elif has_buffs:
		name_label.modulate = Color(0.6, 1.0, 0.6)  # Verdoso para buffs
	else:
		name_label.modulate = Color.WHITE
