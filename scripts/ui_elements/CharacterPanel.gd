extends PanelContainer
class_name CharacterPanel

signal character_selected(character_data: CharacterData, is_player: bool)
signal detail_requested(character_data: CharacterData, is_player: bool, slot_node: Control)

const HOVER_DELAY := 0.5  # 500ms hover delay
const SLOT_SIZE := 60
const SLOT_SPACING := 10

var is_player_panel: bool = true
var characters: Array = []
var effect_manager: Node = null

var _slot_nodes: Array = []
var _hover_timer: Timer = null
var _hovered_slot: Control = null
var _selected_slot: Control = null

@onready var slots_container: VBoxContainer = $MarginContainer/SlotsContainer

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_setup_style()
	_setup_hover_timer()

func _setup_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

func _setup_hover_timer():
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(_hover_timer)

func setup(chars: Array, is_player: bool, eff_manager: Node):
	characters = chars
	is_player_panel = is_player
	effect_manager = eff_manager
	
	# Esperar a que el nodo esté listo si es necesario
	if not is_node_ready():
		await ready
	
	# Buscar el slots_container si no está asignado
	if not slots_container:
		slots_container = get_node_or_null("MarginContainer/SlotsContainer")
	
	_create_slots()
	update_display()

func _create_slots():
	# Clear existing slots
	for slot in _slot_nodes:
		if is_instance_valid(slot):
			slot.queue_free()
	_slot_nodes.clear()
	
	if not slots_container:
		print("❌ CharacterPanel: slots_container no encontrado")
		return
	
	print("🎭 CharacterPanel._create_slots: ", "Player" if is_player_panel else "Enemy", " - ", characters.size(), " personajes")
	
	# Create slot for each character
	for i in range(characters.size()):
		var char_data = characters[i]
		if not char_data:
			print("  ⚠️ Slot ", i, ": char_data es null")
			continue
		if char_data.hp <= 0:
			print("  💀 Slot ", i, ": ", char_data.name, " está muerto (HP: ", char_data.hp, ")")
			continue
		
		print("  ✅ Slot ", i, ": ", char_data.name, " HP: ", char_data.hp, "/", char_data.max_hp, " Role: ", char_data.role)
		var slot = _create_character_slot(char_data, i)
		slots_container.add_child(slot)
		_slot_nodes.append(slot)
	
	print("🎭 CharacterPanel: ", _slot_nodes.size(), " slots creados")

func _create_character_slot(char_data: CharacterData, index: int) -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.set_meta("character_data", char_data)
	slot.set_meta("slot_index", index)
	
	var char_color = _get_character_color(char_data)
	
	# Border (dark background) - MOUSE_FILTER_IGNORE para que no bloquee clicks
	var border = ColorRect.new()
	border.name = "Border"
	border.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	border.position = Vector2.ZERO
	border.color = Color(0.1, 0.1, 0.1, 1.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border)
	
	# Inner colored area (slightly smaller to show border)
	var inner = ColorRect.new()
	inner.name = "ColorBackground"
	inner.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
	inner.position = Vector2(3, 3)
	inner.color = char_color
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)
	
	# HP percentage overlay
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = _get_hp_percentage_text(char_data)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	hp_label.position = Vector2.ZERO
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hp_label.add_theme_constant_override("shadow_offset_x", 1)
	hp_label.add_theme_constant_override("shadow_offset_y", 1)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(hp_label)
	
	# Buff icons for enemies (shown inline)
	if not is_player_panel:
		var buff_icons = _create_buff_icons_label(char_data)
		buff_icons.position = Vector2(SLOT_SIZE + 4, SLOT_SIZE / 2 - 10)
		buff_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(buff_icons)
	
	# Connect mouse events
	slot.gui_input.connect(_on_slot_gui_input.bind(slot))
	slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
	slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
	
	return slot

func _get_character_color(char_data: CharacterData) -> Color:
	if is_player_panel:
		# Color by role: HEALER=green, TANK=blue, CARRY=orange
		match char_data.role.to_upper():
			"HEALER":
				return Color(0.2, 0.8, 0.3, 1.0)  # Green
			"TANK":
				return Color(0.3, 0.5, 0.9, 1.0)  # Blue
			"CARRY":
				return Color(0.95, 0.5, 0.2, 1.0)  # Orange
			_:
				return Color(0.6, 0.6, 0.6, 1.0)  # Gray default
	else:
		# Enemy: Red with opacity based on rarity
		var rarity = char_data.char_range if char_data.char_range != "" else "common"
		match rarity.to_lower():
			"boss":
				return Color(0.4, 0.1, 0.1, 1.0)  # Dark red
			"epic":
				return Color(0.6, 0.15, 0.15, 1.0)  # Medium red
			_:  # common
				return Color(0.8, 0.2, 0.2, 1.0)  # Light red

func _get_hp_percentage_text(char_data: CharacterData) -> String:
	if char_data.max_hp <= 0:
		return "0%"
	var percentage = int((float(char_data.hp) / float(char_data.max_hp)) * 100)
	return "%d%%" % percentage

func _create_buff_icons_label(char_data: CharacterData) -> Label:
	var label = Label.new()
	label.name = "BuffIcons"
	label.add_theme_font_size_override("font_size", 12)
	
	var icons_text = ""
	
	if effect_manager and effect_manager.has_method("get_character_effects"):
		var effects = effect_manager.get_character_effects(char_data)
		for effect in effects:
			if effect.duration > 0:
				var icon = effect.icon if effect.icon else "●"
				icons_text += icon + " "
	
	label.text = icons_text.strip_edges()
	return label

func update_display():
	print("📊 CharacterPanel.update_display: ", "Player" if is_player_panel else "Enemy", " - ", _slot_nodes.size(), " slots")
	for slot in _slot_nodes:
		if not is_instance_valid(slot):
			continue
		
		var char_data = slot.get_meta("character_data")
		if not char_data:
			continue
		
		# Update HP label
		var hp_label = slot.get_node_or_null("HPLabel")
		if hp_label:
			var hp_text = _get_hp_percentage_text(char_data)
			hp_label.text = hp_text
			print("  ", char_data.name, ": ", hp_text, " (", char_data.hp, "/", char_data.max_hp, ")")
		
		# Update visibility based on alive status
		slot.visible = char_data.hp > 0
		
		# Update buff icons for enemies
		if not is_player_panel:
			var buff_label = slot.get_node_or_null("BuffIcons")
			if buff_label:
				var icons_text = ""
				if effect_manager and effect_manager.has_method("get_character_effects"):
					var effects = effect_manager.get_character_effects(char_data)
					for effect in effects:
						if effect.duration > 0:
							var icon = effect.icon if effect.icon else "●"
							icons_text += icon + " "
				buff_label.text = icons_text.strip_edges()

func refresh_characters(chars: Array):
	"""Actualiza los personajes y recrea los slots si es necesario"""
	characters = chars
	
	print("🔄 CharacterPanel.refresh_characters: ", "Player" if is_player_panel else "Enemy")
	
	# Contar personajes vivos en los nuevos datos
	var alive_chars: Array = []
	for char_data in characters:
		if char_data and char_data.hp > 0:
			alive_chars.append(char_data)
	
	print("  Personajes vivos: ", alive_chars.size(), " | Slots actuales: ", _slot_nodes.size())
	
	# Si el número de personajes vivos cambió, recrear los slots
	if alive_chars.size() != _slot_nodes.size():
		print("  ⚠️ Número de personajes cambió, recreando slots...")
		_create_slots()
	else:
		# Actualizar las referencias de char_data en los slots existentes
		# Emparejar por posición (slot 0 = primer vivo, slot 1 = segundo vivo, etc.)
		for i in range(_slot_nodes.size()):
			var slot = _slot_nodes[i]
			if not is_instance_valid(slot):
				continue
			if i < alive_chars.size():
				var new_char_data = alive_chars[i]
				slot.set_meta("character_data", new_char_data)
				print("  Slot ", i, ": ", new_char_data.name, " HP: ", new_char_data.hp, "/", new_char_data.max_hp)
	
	update_display()

func _on_slot_gui_input(event: InputEvent, slot: Control):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_hover_timer.stop()
			var char_data = slot.get_meta("character_data")
			if char_data:
				_selected_slot = slot
				detail_requested.emit(char_data, is_player_panel, slot)

func _on_slot_mouse_entered(slot: Control):
	_hovered_slot = slot
	_hover_timer.start(HOVER_DELAY)
	
	# Visual feedback
	var char_data = slot.get_meta("character_data")
	if char_data:
		_apply_hover_effect(slot, true)

func _on_slot_mouse_exited(slot: Control):
	if _hovered_slot == slot:
		_hovered_slot = null
		_hover_timer.stop()
	
	_apply_hover_effect(slot, false)

func _on_hover_timer_timeout():
	if _hovered_slot and is_instance_valid(_hovered_slot):
		var char_data = _hovered_slot.get_meta("character_data")
		if char_data:
			_selected_slot = _hovered_slot
			detail_requested.emit(char_data, is_player_panel, _hovered_slot)

func _apply_hover_effect(slot: Control, hovered: bool):
	# Simple scale effect on hover
	if hovered:
		var tween = create_tween()
		tween.tween_property(slot, "scale", Vector2(1.1, 1.1), 0.1)
		slot.pivot_offset = slot.size / 2
	else:
		var tween = create_tween()
		tween.tween_property(slot, "scale", Vector2.ONE, 0.1)

func get_slot_global_position(slot: Control) -> Vector2:
	if is_instance_valid(slot):
		return slot.global_position
	return Vector2.ZERO

func get_slot_for_character(char_data: CharacterData) -> Control:
	for slot in _slot_nodes:
		if is_instance_valid(slot) and slot.get_meta("character_data") == char_data:
			return slot
	return null

func clear_selection():
	_selected_slot = null
