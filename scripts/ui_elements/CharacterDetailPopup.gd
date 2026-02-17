extends PanelContainer
class_name CharacterDetailPopup

signal popup_closed

const ANIMATION_DURATION := 0.25

var character_data: CharacterData = null
var is_player_character: bool = true
var effect_manager: Node = null

@onready var name_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/NameLabel
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPContainer/HPLabel
@onready var buffs_container: VBoxContainer = $MarginContainer/VBoxContainer/BuffsSection/BuffsContainer
@onready var debuffs_container: VBoxContainer = $MarginContainer/VBoxContainer/DebuffsSection/DebuffsContainer
@onready var permanent_section: VBoxContainer = $MarginContainer/VBoxContainer/PermanentSection
@onready var permanent_container: VBoxContainer = $MarginContainer/VBoxContainer/PermanentSection/PermanentContainer
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/CloseButton

var _tween: Tween = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1500
	modulate.a = 0.0
	visible = false
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	_setup_style()

func _setup_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

func setup(char_data: CharacterData, is_player: bool, eff_manager: Node):
	character_data = char_data
	is_player_character = is_player
	effect_manager = eff_manager
	
	_update_display()

func _update_display():
	if not character_data:
		print("❌ CharacterDetailPopup: character_data es null")
		return
	
	print("📋 CharacterDetailPopup._update_display para: ", character_data.name)
	print("  effect_manager: ", effect_manager)
	
	# Update name
	if name_label:
		name_label.text = character_data.name

	# Update HP display with current/max (2 decimals)
	if hp_label:
		var current_hp = "%.2f" % character_data.hp
		var max_hp = "%.2f" % character_data.max_hp
		var hp_percent = (float(character_data.hp) / float(character_data.max_hp) * 100) if character_data.max_hp > 0 else 0.0
		hp_label.text = "❤️ %s / %s (%.1f%%)" % [current_hp, max_hp, hp_percent]
		# Color segun porcentaje de vida
		if hp_percent > 50:
			hp_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		elif hp_percent > 25:
			hp_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			hp_label.add_theme_color_override("font_color", Color.CORAL)
	
	# Clear existing entries
	_clear_container(buffs_container)
	_clear_container(debuffs_container)
	_clear_container(permanent_container)
	
	# Get active effects from EffectManager
	var active_effects: Array = []
	if effect_manager and effect_manager.has_method("get_character_effects"):
		active_effects = effect_manager.get_character_effects(character_data)
		print("  Efectos obtenidos para ", character_data.name, " (id:", character_data.id, "): ", active_effects.size())
		for eff in active_effects:
			print("    - ", eff.icon, " tipo:", eff.effect_type, " valor:", eff.value, " duración:", eff.duration)
	else:
		print("  ⚠️ No se pudo obtener efectos (effect_manager: ", effect_manager, ")")
	
	# Separate buffs and debuffs
	var buffs: Array = []
	var debuffs: Array = []
	
	for effect in active_effects:
		if effect.duration > 0:
			if _is_debuff(effect):
				debuffs.append(effect)
			else:
				buffs.append(effect)
	
	# Display buffs
	for buff in buffs:
		_add_effect_entry(buffs_container, buff, false)
	
	if buffs.is_empty():
		_add_empty_label(buffs_container, "Sin buffs activos")
	
	# Display debuffs
	for debuff in debuffs:
		_add_effect_entry(debuffs_container, debuff, true)
	
	if debuffs.is_empty():
		_add_empty_label(debuffs_container, "Sin debuffs activos")
	
	# Permanent buffs (only for player characters)
	if is_player_character and permanent_section:
		permanent_section.visible = true
		
		var permanent_buffs = character_data.permanent_buffs if character_data.get("permanent_buffs") else []
		
		for perm_buff in permanent_buffs:
			_add_permanent_entry(permanent_container, perm_buff)
		
		if permanent_buffs.is_empty():
			_add_empty_label(permanent_container, "Sin buffs permanentes")
	elif permanent_section:
		permanent_section.visible = false

func _add_effect_entry(container: VBoxContainer, effect, is_debuff: bool):
	if not container:
		return
	
	var entry = HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = effect.icon if effect.icon else ("⬇️" if is_debuff else "⬆️")
	icon_label.custom_minimum_size.x = 30
	entry.add_child(icon_label)
	
	# Name and value
	var name_value = Label.new()
	name_value.text = "%s: %+d" % [_get_effect_name(effect.effect_type), effect.value]
	name_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_value.add_theme_color_override("font_color", Color.CORAL if is_debuff else Color.LIGHT_GREEN)
	entry.add_child(name_value)
	
	# Duration
	var duration_label = Label.new()
	duration_label.text = "%d turnos" % effect.duration
	duration_label.add_theme_color_override("font_color", Color.GRAY)
	entry.add_child(duration_label)
	
	container.add_child(entry)

func _add_permanent_entry(container: VBoxContainer, perm_buff: Dictionary):
	if not container:
		return
	
	var entry = HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = "✨"
	icon_label.custom_minimum_size.x = 30
	entry.add_child(icon_label)
	
	# Type and value
	var type_str = perm_buff.get("type", "unknown")
	var value = perm_buff.get("value", 0)
	var source = perm_buff.get("source", "")
	
	var name_value = Label.new()
	name_value.text = "%s: %+d" % [type_str.capitalize(), value]
	name_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_value.add_theme_color_override("font_color", Color.GOLD)
	entry.add_child(name_value)
	
	# Source
	if source:
		var source_label = Label.new()
		source_label.text = "(%s)" % source
		source_label.add_theme_color_override("font_color", Color.GRAY)
		entry.add_child(source_label)
	
	container.add_child(entry)

func _add_empty_label(container: VBoxContainer, text: String):
	if not container:
		return
	
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.DARK_GRAY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)

func _clear_container(container: VBoxContainer):
	if not container:
		return
	
	for child in container.get_children():
		child.queue_free()

func _is_debuff(effect) -> bool:
	if not effect:
		return false
	
	var debuff_types = [
		"DEBUFF_ATTACK", "DEBUFF_DEFENSE", "DEBUFF_HP",
		"STUN", "POISON", "VULNERABILITY", "WEAKNESS",
		"ENERGY_DRAIN", "CARD_BLOCK", "HEAL_BLOCK"
	]
	
	var type_name = ""
	if effect.has_method("get_type_name"):
		type_name = effect.get_type_name()
	elif "effect_type" in effect:
		type_name = str(effect.effect_type)
	
	for debuff_type in debuff_types:
		if debuff_type in type_name.to_upper():
			return true
	
	return false

func _get_effect_name(effect_type) -> String:
	var type_str = str(effect_type)
	
	var names = {
		"0": "Ataque+",
		"1": "Ataque-",
		"2": "Defensa+",
		"3": "Defensa-",
		"4": "HP+",
		"5": "HP-",
		"6": "Aturdido",
		"7": "Veneno",
		"8": "Regeneración",
		"9": "Escudo",
		"10": "Vulnerabilidad",
		"11": "Fuerza",
		"12": "Debilidad",
		"13": "Energía+",
		"14": "Energía-",
		"15": "Robar carta",
		"16": "Bloqueo carta",
		"17": "Reflejar daño",
		"18": "Inmunidad",
		"19": "Daño doble",
		"20": "Bloqueo curación",
		"21": "Velocidad+",
		"22": "Personalizado"
	}
	
	return names.get(type_str, "Efecto")

func show_popup():
	visible = true
	
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	
	# Animate scale and alpha
	scale = Vector2(0.8, 0.8)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION)

func hide_popup():
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_BACK)
	
	_tween.parallel().tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION * 0.7)
	_tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION * 0.7)
	_tween.tween_callback(_on_hide_complete)

func _on_hide_complete():
	visible = false
	popup_closed.emit()

func _on_close_pressed():
	hide_popup()

func refresh():
	_update_display()
